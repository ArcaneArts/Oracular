import 'dart:io' show Directory;

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../models/setup_config.dart';
import '../utils/process_runner.dart' show ProcessResult, ProcessRunner;
import 'build_orchestrator.dart';
import 'cloud_run_preflight.dart';

/// Outcome of a [JasprServerDeployer.deploy] call.
class JasprServerDeployResult {
  /// Whether the full build + push + Cloud Run deploy succeeded.
  final bool success;

  /// Live Cloud Run service URL on success; `null` on failure.
  final String? serviceUrl;

  /// Fully-qualified Artifact Registry image tag that was deployed.
  final String? imageTag;

  /// Cloud Run service name that was deployed.
  final String? serviceName;

  /// Cloud Run region the deploy targeted.
  final String? region;

  /// Failure reason (empty on success).
  final String message;

  const JasprServerDeployResult({
    required this.success,
    this.serviceUrl,
    this.imageTag,
    this.serviceName,
    this.region,
    this.message = '',
  });

  factory JasprServerDeployResult.failure(String reason) =>
      JasprServerDeployResult(success: false, message: reason);
}

/// Deploys the Jaspr server binary (SSR / hybrid render modes) to
/// Google Cloud Run.
///
/// This is the Jaspr-side counterpart to
/// `ServerSetup.deployToCloudRun` for the arcane_server template.
/// Both services can run side-by-side in the same project — they push
/// to different Cloud Run service names (the arcane_server uses
/// `<appName>-server`; the Jaspr binary uses
/// [SetupConfig.effectiveJasprServerServiceName], which defaults to
/// `<appName>-web`).
///
/// End-to-end flow:
///
///   1. **Preflight** ([CloudRunPreflight]):
///      - Verify the active gcloud account belongs to the target project.
///      - Enable Artifact Registry + Cloud Run APIs (idempotent).
///      - Ensure the `oracular` Artifact Registry repo exists.
///   2. **Build** the Jaspr server image via
///      [BuildOrchestrator.buildJasprServerImage] (`docker build -f
///      Dockerfile.jaspr -t IMAGE:latest [-t IMAGE:SHA] .`).
///   3. **Push** the `:latest` tag to Artifact Registry. The optional
///      `:SHA` tag is pushed too, so the AR cleanup policy can keep
///      traceable per-revision images.
///   4. **Deploy** to Cloud Run (`gcloud run deploy`) using the same
///      Cloud Run knobs as arcane_server (port 8080, 512Mi memory,
///      0..10 instances, `--allow-unauthenticated`).
///
/// Skipped when [SetupConfig.hasJasprServer] is false (i.e. the project
/// is using a static render mode like CSR / SSG / embed).
class JasprServerDeployer {
  final SetupConfig config;
  final ProcessRunner _runner;
  final BuildOrchestrator _builder;
  final CloudRunPreflight _preflight;

  JasprServerDeployer(
    this.config, {
    ProcessRunner? runner,
    BuildOrchestrator? builder,
    CloudRunPreflight? preflight,
  })  : _runner = runner ?? ProcessRunner(),
        _builder = builder ?? BuildOrchestrator(config, runner: runner),
        _preflight = preflight ?? CloudRunPreflight(runner: runner);

  /// Project directory for the Jaspr host (where Dockerfile.jaspr lives).
  String get _jasprAppPath => p.join(config.outputDir, config.webPackageName);

  /// Cloud Run service name for the Jaspr server. Defaults to
  /// `<appName>-web` so it never collides with arcane_server's
  /// `<appName>-server`.
  String get serviceName => config.effectiveJasprServerServiceName;

  /// Fully-qualified `:latest` image tag for the Jaspr server.
  String imageTag({
    required String projectId,
    required String region,
    required String repository,
  }) {
    return '$region-docker.pkg.dev/$projectId/$repository/$serviceName:latest';
  }

  /// End-to-end: build, push, and deploy the Jaspr server to Cloud Run.
  ///
  /// Returns a [JasprServerDeployResult] describing the outcome. Never
  /// throws on shell failures — every step short-circuits with a
  /// descriptive [JasprServerDeployResult.message] so the CLI can render
  /// a clean summary.
  Future<JasprServerDeployResult> deploy({
    String repository = 'oracular',
    String region = 'us-central1',
  }) async {
    // ── Gate: only run when the project produces a Jaspr server image.
    if (!config.hasJasprServer) {
      return JasprServerDeployResult.failure(
        'Render mode ${config.jasprRenderMode.displayName} does not '
        'produce a Cloud Run image — nothing to deploy.',
      );
    }

    final String? projectId = config.firebaseProjectId;
    if (projectId == null || projectId.trim().isEmpty) {
      return JasprServerDeployResult.failure(
        'No Firebase / GCP project ID configured. Set '
        'FIREBASE_PROJECT_ID in config/setup_config.env and retry.',
      );
    }

    // The Jaspr host must exist on disk — without it there's nothing to
    // build. The Dockerfile.jaspr check is delegated to
    // BuildOrchestrator.buildJasprServerImage.
    if (!Directory(_jasprAppPath).existsSync()) {
      return JasprServerDeployResult.failure(
        'Jaspr project not found at $_jasprAppPath. Re-scaffold with '
        '`oracular create` to generate it.',
      );
    }

    // ── 1. Preflight (active account / APIs / AR repo) ────────────────
    if (!await _preflight.runAll(
      projectId: projectId,
      repository: repository,
      region: region,
    )) {
      return JasprServerDeployResult.failure(
        'Cloud Run preflight failed. See errors above.',
      );
    }

    // ── 2. Build via BuildOrchestrator ────────────────────────────────
    // Routes through the orchestrator so the `oracular build
    // jaspr-server` CLI entry point and this deploy hit identical
    // docker-build invocations. The orchestrator handles git-SHA
    // tagging and Dockerfile.jaspr discovery.
    info('Building Jaspr Cloud Run image for $serviceName...');
    final BuildStepResult build = await _builder.buildJasprServerImage();
    if (build.status != BuildStepStatus.success) {
      return JasprServerDeployResult.failure(
        'docker build failed: ${build.message}',
      );
    }

    // ── 3. Push every tag we built (`:latest` + optional `:<sha>`) ────
    // The orchestrator records the `:latest` tag in `outputPath` but the
    // git-sha tag is implicit; we re-derive both here.
    final String latestTag =
        imageTag(projectId: projectId, region: region, repository: repository);

    info('Pushing image to Artifact Registry...');
    final ProcessResult? push = await _runner.runWithRetry(
      'docker',
      <String>['push', latestTag],
      workingDirectory: _jasprAppPath,
      operationName: 'docker push (Jaspr server)',
    );
    if (push == null || !push.success) {
      return JasprServerDeployResult.failure(
        'docker push failed. Verify the Artifact Registry repository '
        '`$repository` exists in $region and that you are authenticated '
        '(`gcloud auth configure-docker $region-docker.pkg.dev`).',
      );
    }

    // Best-effort: push the git-sha tag if BuildOrchestrator added one.
    // `docker push` with the per-image base tag pushes *that tag*, so we
    // explicitly ask for the SHA-tagged variant when we can read git.
    final String? gitSha = await _readGitSha(_jasprAppPath);
    if (gitSha != null && gitSha.isNotEmpty) {
      final String shaTag =
          '$region-docker.pkg.dev/$projectId/$repository/$serviceName:$gitSha';
      info('Pushing image SHA tag $shaTag...');
      final ProcessResult? pushSha = await _runner.runWithRetry(
        'docker',
        <String>['push', shaTag],
        workingDirectory: _jasprAppPath,
        operationName: 'docker push (Jaspr server SHA tag)',
      );
      if (pushSha == null || !pushSha.success) {
        // Non-fatal: the `:latest` push already succeeded.
        warn('Could not push SHA tag $shaTag '
            '(continuing — :latest is in place).');
      }
    }

    // ── 4. gcloud run deploy ──────────────────────────────────────────
    info('Deploying $serviceName to Cloud Run ($region)...');
    final ProcessResult? deployResult = await _runner.runWithRetry(
      'gcloud',
      <String>[
        'run',
        'deploy',
        serviceName,
        '--image=$latestTag',
        '--platform=managed',
        '--region=$region',
        '--project=$projectId',
        '--allow-unauthenticated',
        '--port=8080',
        '--memory=512Mi',
        '--cpu=1',
        '--min-instances=0',
        '--max-instances=10',
      ],
      operationName: 'gcloud run deploy (Jaspr server)',
    );
    if (deployResult == null || !deployResult.success) {
      return JasprServerDeployResult.failure(
        'gcloud run deploy failed for service $serviceName.',
      );
    }

    // Cloud Run service URLs embed a per-project hash; ask gcloud rather
    // than guessing.
    String url = 'https://$serviceName-$projectId.$region.run.app';
    final ProcessResult describe = await _runner.run(
      'gcloud',
      <String>[
        'run',
        'services',
        'describe',
        serviceName,
        '--region=$region',
        '--project=$projectId',
        '--format=value(status.url)',
      ],
    );
    final String describedUrl = describe.stdout.trim();
    if (describe.success && describedUrl.isNotEmpty) {
      url = describedUrl;
    }

    success('Jaspr server deployed to Cloud Run.');
    info('  Service: $serviceName');
    info('  URL:     $url');

    return JasprServerDeployResult(
      success: true,
      serviceUrl: url,
      imageTag: latestTag,
      serviceName: serviceName,
      region: region,
    );
  }

  /// Read the current git SHA in [workingDir]. Returns `null` when git
  /// is unavailable or the directory is not a git repo (both are normal
  /// cases — we still get a successful deploy with just `:latest`).
  Future<String?> _readGitSha(String workingDir) async {
    try {
      final ProcessResult result = await _runner.run(
        'git',
        <String>['rev-parse', '--short', 'HEAD'],
        workingDirectory: workingDir,
      );
      if (!result.success) return null;
      final String sha = result.stdout.trim();
      return sha.isEmpty ? null : sha;
    } catch (_) {
      return null;
    }
  }
}

