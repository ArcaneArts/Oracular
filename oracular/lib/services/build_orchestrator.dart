import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../models/setup_config.dart';
import '../models/template_info.dart';
import '../utils/process_runner.dart' show ProcessResult, ProcessRunner;

/// Outcome of a single build step inside [BuildOrchestrator].
enum BuildStepStatus { success, skipped, failed }

/// Logical category of a build step. Used in [BuildReport] summaries and
/// in the per-mode integration tests so we can assert "the orchestrator
/// ran *exactly* these kinds of steps".
enum BuildStepKind {
  /// `flutter build <platform> --release` for a Flutter app.
  flutterPlatform,

  /// `jaspr build` (any render mode) for a Jaspr web app.
  jasprSite,

  /// `flutter build web --release` for the Flutter web guest that lives
  /// inside `arcane_jaspr_flutter_embed`. Distinct from
  /// [flutterPlatform] so the report can call out the embed flow.
  embedFlutterGuest,

  /// `docker build -f Dockerfile.jaspr …` to package the SSR/hybrid
  /// Jaspr server entrypoint into a Cloud Run image. The actual push +
  /// deploy lives in `JasprServerDeployer`.
  jasprServerImage,

  /// `dart compile exe` for `arcane_cli_app`. Build-only — CLI is
  /// explicitly out of scope for deploy by user request.
  dartCli,
}

/// Result of one [BuildOrchestrator] step.
class BuildStepResult {
  final BuildStepKind kind;
  final String label;
  final BuildStepStatus status;
  final String message;

  /// Absolute path to the artifact produced by this step, when
  /// applicable. Empty on skip/failure or for steps that don't produce
  /// a single discoverable artifact.
  final String outputPath;

  const BuildStepResult({
    required this.kind,
    required this.label,
    required this.status,
    this.message = '',
    this.outputPath = '',
  });

  factory BuildStepResult.success(
    BuildStepKind kind,
    String label, {
    String outputPath = '',
    String message = '',
  }) {
    return BuildStepResult(
      kind: kind,
      label: label,
      status: BuildStepStatus.success,
      message: message,
      outputPath: outputPath,
    );
  }

  factory BuildStepResult.skipped(
    BuildStepKind kind,
    String label, {
    String reason = '',
  }) {
    return BuildStepResult(
      kind: kind,
      label: label,
      status: BuildStepStatus.skipped,
      message: reason,
    );
  }

  factory BuildStepResult.failed(
    BuildStepKind kind,
    String label, {
    String reason = '',
  }) {
    return BuildStepResult(
      kind: kind,
      label: label,
      status: BuildStepStatus.failed,
      message: reason,
    );
  }
}

/// Aggregated outcome of one [BuildOrchestrator.buildAll] invocation.
///
/// Mirrors `OrchestratorReport` from `firebase_setup_orchestrator.dart`
/// so the rest of the codebase (and tests) can rely on the same shape.
class BuildReport {
  final List<BuildStepResult> results;

  const BuildReport(this.results);

  int get succeededCount =>
      results.where((BuildStepResult r) => r.status == BuildStepStatus.success).length;
  int get skippedCount =>
      results.where((BuildStepResult r) => r.status == BuildStepStatus.skipped).length;
  int get failedCount =>
      results.where((BuildStepResult r) => r.status == BuildStepStatus.failed).length;

  bool get allSucceeded => failedCount == 0 && succeededCount > 0;
  bool get anyFailed => failedCount > 0;

  /// First failure (if any), useful when surfacing a short error in
  /// the CLI summary.
  BuildStepResult? get firstFailure {
    for (final BuildStepResult r in results) {
      if (r.status == BuildStepStatus.failed) return r;
    }
    return null;
  }
}

/// Central "what does building this project mean?" service.
///
/// Reads [SetupConfig] and produces an ordered list of build steps. Every
/// other build entry point in Oracular (CLI `oracular build …`,
/// `oracular deploy hosting`, the Cloud Run deploy flow, the integration
/// tests) routes through here so that the answer is single-sourced.
///
/// Design notes:
/// - This service is *build only*. It never pushes images, never deploys.
///   That keeps it composable with the existing `FirebaseService` and the
///   new `JasprServerDeployer`.
/// - Every method returns a [BuildStepResult] instead of `bool` so
///   callers can assemble a full [BuildReport] with diagnostics.
/// - All paths are derived from [SetupConfig] (never from `cwd`), so the
///   orchestrator works the same way whether it's invoked from the
///   project root, from CI, or from a unit test.
class BuildOrchestrator {
  final SetupConfig config;
  final ProcessRunner _runner;

  BuildOrchestrator(this.config, {ProcessRunner? runner})
    : _runner = runner ??
          ProcessRunner(
            // Build steps are non-interactive by design: if a `flutter
            // build web` or `jaspr build` fails, surface the error and
            // bail. Prompting on stdin would deadlock CI and the unit
            // test harness.
            interactive: false,
          );

  // ─── Path helpers ──────────────────────────────────────────────────────

  /// Project directory for the primary Flutter app
  /// (`arcaneTemplate` / `arcaneBeamer` / `arcaneDock`).
  String get _flutterAppPath => p.join(config.outputDir, config.appName);

  /// Project directory for the Jaspr host (every Jaspr template).
  String get _jasprAppPath => p.join(config.outputDir, config.webPackageName);

  /// Project directory for the Flutter web guest inside the
  /// `arcaneJasprFlutterEmbed` template.
  String get _embeddedFlutterPath =>
      p.join(config.outputDir, config.embeddedFlutterPackageName);

  /// Project directory for the Dart CLI app (`arcaneCli`).
  String get _dartCliPath => p.join(config.outputDir, config.appName);

  // ─── Public surface ────────────────────────────────────────────────────

  /// Build every artifact this project is meant to produce, in order.
  ///
  /// Order is fixed so deploy steps further downstream see consistent
  /// artifacts:
  ///   1. Primary app (Flutter platforms / Jaspr site / CLI binary).
  ///   2. For embed: Flutter guest is folded into [buildJaspr] (so the
  ///      Jaspr `web/app/` contents land before `jaspr build` runs).
  ///   3. For SSR/Hybrid: the Cloud Run image follows the Jaspr build.
  Future<BuildReport> buildAll() async {
    final List<BuildStepResult> results = <BuildStepResult>[];

    // Primary app
    if (config.template.isFlutterApp) {
      for (final String platform in config.platforms) {
        results.add(await buildFlutter(platform: platform));
      }
    } else if (config.template.isJasprApp) {
      results.add(await buildJaspr());
    } else if (config.template.isDartCli) {
      results.add(await buildDartCli());
    }

    // Jaspr server image (SSR/hybrid). Distinct step from the Jaspr
    // build itself because it requires docker + Dockerfile.jaspr, which
    // SSR/hybrid projects ship but CSR/SSG/embed projects do not.
    if (config.hasJasprServer) {
      results.add(await buildJasprServerImage());
    }

    return BuildReport(results);
  }

  /// `flutter build <platform> --release` inside the Flutter app
  /// project. Returns [BuildStepResult.skipped] when the platform is
  /// not in `config.platforms` (defensive — `buildAll` filters by the
  /// list, but a direct invocation might pass anything).
  Future<BuildStepResult> buildFlutter({required String platform}) async {
    final String label = 'Flutter build $platform';

    if (!config.template.isFlutterApp) {
      return BuildStepResult.skipped(
        BuildStepKind.flutterPlatform,
        label,
        reason: 'Template ${config.template.displayName} is not a Flutter app.',
      );
    }

    if (!config.template.supportedPlatforms.contains(platform)) {
      return BuildStepResult.skipped(
        BuildStepKind.flutterPlatform,
        label,
        reason: 'Platform "$platform" is not supported by '
            '${config.template.displayName}.',
      );
    }

    if (!config.platforms.contains(platform)) {
      return BuildStepResult.skipped(
        BuildStepKind.flutterPlatform,
        label,
        reason: 'Platform "$platform" is not enabled in setup_config.env.',
      );
    }

    final Directory projectDir = Directory(_flutterAppPath);
    if (!projectDir.existsSync()) {
      return BuildStepResult.failed(
        BuildStepKind.flutterPlatform,
        label,
        reason: 'Project directory not found: ${projectDir.path}',
      );
    }

    info('Building Flutter $platform...');

    final ProcessResult? result = await _runner.runWithRetry(
      'flutter',
      <String>['build', platform, '--release'],
      workingDirectory: projectDir.path,
      operationName: 'flutter build $platform',
    );

    if (result == null || !result.success) {
      return BuildStepResult.failed(
        BuildStepKind.flutterPlatform,
        label,
        reason: result?.stderr.trim() ?? 'flutter build $platform failed.',
      );
    }

    final String outputPath = p.join(projectDir.path, 'build', platform);
    return BuildStepResult.success(
      BuildStepKind.flutterPlatform,
      label,
      outputPath: outputPath,
    );
  }

  /// `jaspr build` inside the Jaspr project, dispatched per
  /// [SetupConfig.jasprRenderMode]:
  ///   * `csr`    — runs `jaspr build` (`mode: client` from jaspr.yaml).
  ///   * `ssg`    — runs `jaspr build` (`mode: static`); prerender pass
  ///                fires inside the Jaspr CLI itself via
  ///                `lib/main.server.dart`.
  ///   * `ssr`    — runs `jaspr build` (`mode: server`); the Dart
  ///                entrypoint is emitted to `build/jaspr/`, which the
  ///                Dockerfile then turns into a Cloud Run image (see
  ///                [buildJasprServerImage]).
  ///   * `hybrid` — same as `ssr`; static prerenders are produced as a
  ///                side-effect of the `@StaticRoute` annotations in
  ///                `lib/routes/`.
  ///   * `embed`  — builds the Flutter guest first via
  ///                [buildEmbeddedFlutter], then `jaspr build`.
  Future<BuildStepResult> buildJaspr() async {
    final String label = 'Jaspr build (${config.jasprRenderMode.displayName})';

    if (!config.template.isJasprApp) {
      return BuildStepResult.skipped(
        BuildStepKind.jasprSite,
        label,
        reason: 'Template ${config.template.displayName} is not a Jaspr app.',
      );
    }

    final Directory projectDir = Directory(_jasprAppPath);
    if (!projectDir.existsSync()) {
      return BuildStepResult.failed(
        BuildStepKind.jasprSite,
        label,
        reason: 'Jaspr project directory not found: ${projectDir.path}',
      );
    }

    // Embed: build the Flutter guest into <host>/web/app first so it's
    // included in the `jaspr build` output bundle. Bail early if the
    // guest build fails — there's no point producing a Jaspr build that
    // links to a missing Flutter app.
    if (config.jasprRenderMode == JasprRenderMode.embed) {
      final BuildStepResult guest = await buildEmbeddedFlutter();
      if (guest.status == BuildStepStatus.failed) {
        return BuildStepResult.failed(
          BuildStepKind.jasprSite,
          label,
          reason: 'Embedded Flutter build failed: ${guest.message}',
        );
      }
    }

    info('Running jaspr build (${config.jasprRenderMode.displayName})...');

    final ProcessResult? result = await _runner.runWithRetry(
      'jaspr',
      <String>['build'],
      workingDirectory: projectDir.path,
      operationName: 'jaspr build',
    );

    if (result == null || !result.success) {
      return BuildStepResult.failed(
        BuildStepKind.jasprSite,
        label,
        reason: result?.stderr.trim() ?? 'jaspr build failed.',
      );
    }

    final String outputPath = p.join(projectDir.path, 'build', 'jaspr');
    return BuildStepResult.success(
      BuildStepKind.jasprSite,
      label,
      outputPath: outputPath,
    );
  }

  /// Build the Flutter web guest used by `arcane_jaspr_flutter_embed`.
  ///
  /// Steps:
  ///   1. `flutter build web --release --base-href=<mount>/` in the
  ///      `<embeddedFlutterPackageName>/` directory.
  ///   2. Copy `build/web/**` from the guest into
  ///      `<webPackageName>/web<mount>/` so it ships with the Jaspr
  ///      build.
  ///   3. Uncomment the Flutter-bootstrap script tag in the host's
  ///      `web/index.html` (idempotent — finds the
  ///      `ORACULAR_FLUTTER_BOOTSTRAP_BEGIN` / `END` markers and
  ///      replaces the commented block in between).
  Future<BuildStepResult> buildEmbeddedFlutter() async {
    final String label =
        'Flutter web build for embed (mount: ${config.embeddedFlutterMount})';

    if (config.template != TemplateType.arcaneJasprFlutterEmbed &&
        config.jasprRenderMode != JasprRenderMode.embed) {
      return BuildStepResult.skipped(
        BuildStepKind.embedFlutterGuest,
        label,
        reason: 'Project does not use the Jaspr+Flutter embed template.',
      );
    }

    final Directory guestDir = Directory(_embeddedFlutterPath);
    if (!guestDir.existsSync()) {
      return BuildStepResult.failed(
        BuildStepKind.embedFlutterGuest,
        label,
        reason: 'Embedded Flutter project not found: ${guestDir.path}',
      );
    }

    // Flutter's `--base-href` must start AND end with `/`. Normalize the
    // user-configured mount (e.g. `/app`, `app`, `/app/`) to the
    // canonical `/app/` form.
    final String baseHref = _normalizedBaseHref(config.embeddedFlutterMount);
    info('Building Flutter web guest with --base-href=$baseHref...');

    final ProcessResult? buildResult = await _runner.runWithRetry(
      'flutter',
      <String>['build', 'web', '--release', '--base-href=$baseHref'],
      workingDirectory: guestDir.path,
      operationName: 'flutter build web (embed)',
    );

    if (buildResult == null || !buildResult.success) {
      return BuildStepResult.failed(
        BuildStepKind.embedFlutterGuest,
        label,
        reason: buildResult?.stderr.trim() ?? 'flutter build web failed.',
      );
    }

    // Copy the Flutter web bundle into the Jaspr host's `web/<mount>/`.
    final Directory guestBuild =
        Directory(p.join(guestDir.path, 'build', 'web'));
    if (!guestBuild.existsSync()) {
      return BuildStepResult.failed(
        BuildStepKind.embedFlutterGuest,
        label,
        reason: 'Flutter web build did not emit ${guestBuild.path}.',
      );
    }

    final String mount = baseHref.substring(1, baseHref.length - 1);
    final Directory hostMount =
        Directory(p.join(_jasprAppPath, 'web', mount));

    try {
      if (hostMount.existsSync()) {
        await hostMount.delete(recursive: true);
      }
      await hostMount.create(recursive: true);
      await _copyDirectoryRecursive(guestBuild, hostMount);
    } on FileSystemException catch (e) {
      return BuildStepResult.failed(
        BuildStepKind.embedFlutterGuest,
        label,
        reason: 'Copy of Flutter build into Jaspr host failed: ${e.message}',
      );
    }

    // Make the bootstrap script visible in the Jaspr index.html.
    try {
      await _enableFlutterBootstrapScript(mount: mount);
    } on FileSystemException catch (e) {
      // Non-fatal: the bundle is in place, the user can manually edit
      // index.html. Surface as a warning in the report.
      warn('Failed to enable Flutter bootstrap injection: ${e.message}');
      return BuildStepResult(
        kind: BuildStepKind.embedFlutterGuest,
        label: label,
        status: BuildStepStatus.success,
        message:
            'Flutter web bundle copied, but index.html bootstrap edit failed: '
            '${e.message}',
        outputPath: hostMount.path,
      );
    }

    return BuildStepResult.success(
      BuildStepKind.embedFlutterGuest,
      label,
      outputPath: hostMount.path,
    );
  }

  /// `docker build -f Dockerfile.jaspr -t <image> .` for SSR / hybrid
  /// Jaspr projects. Pushes are **not** performed here; see
  /// `JasprServerDeployer` for the push + Cloud Run deploy.
  ///
  /// The image is tagged with both `latest` and (when git is available)
  /// the current commit SHA so the registry retains traceable
  /// per-revision images for cleanup policies.
  Future<BuildStepResult> buildJasprServerImage() async {
    const String label = 'Docker build Jaspr server image';

    if (!config.hasJasprServer) {
      return BuildStepResult.skipped(
        BuildStepKind.jasprServerImage,
        label,
        reason: 'Render mode ${config.jasprRenderMode.displayName} does not '
            'produce a Cloud Run image.',
      );
    }

    final Directory projectDir = Directory(_jasprAppPath);
    final File dockerfile = File(p.join(projectDir.path, 'Dockerfile.jaspr'));
    if (!dockerfile.existsSync()) {
      return BuildStepResult.failed(
        BuildStepKind.jasprServerImage,
        label,
        reason:
            'Dockerfile.jaspr not found at ${dockerfile.path}. Scaffold the '
            'project with a SSR/hybrid render mode to get the file generated.',
      );
    }

    final String? projectId = config.firebaseProjectId;
    final String service = config.effectiveJasprServerServiceName;
    const String region = 'us-central1';
    const String repository = 'oracular';

    // Use Artifact Registry path when we have a Firebase project (so the
    // image can be pushed via `oracular deploy jaspr-server`), otherwise
    // fall back to a local-only `oracular/<service>` tag. The local tag
    // makes `oracular build jaspr-image` useful in CI / offline / pre-
    // Firebase-setup workflows.
    final String imageBase = (projectId != null && projectId.isNotEmpty)
        ? '$region-docker.pkg.dev/$projectId/$repository/$service'
        : 'oracular/$service';

    if (projectId == null || projectId.isEmpty) {
      info(
        'No Firebase project ID configured; building local-only image '
        '"$imageBase:latest". Configure Firebase first if you intend to push.',
      );
    }

    info('Building Jaspr Cloud Run image $imageBase:latest...');

    final List<String> tagArgs = <String>['-t', '$imageBase:latest'];
    final String? gitSha = await _readGitSha(projectDir.path);
    if (gitSha != null && gitSha.isNotEmpty) {
      tagArgs
        ..add('-t')
        ..add('$imageBase:$gitSha');
    }

    final ProcessResult? result = await _runner.runWithRetry(
      'docker',
      <String>[
        'build',
        '--platform',
        'linux/amd64',
        '-f',
        'Dockerfile.jaspr',
        ...tagArgs,
        '.',
      ],
      workingDirectory: projectDir.path,
      operationName: 'docker build Jaspr server',
    );

    if (result == null || !result.success) {
      return BuildStepResult.failed(
        BuildStepKind.jasprServerImage,
        label,
        reason: result?.stderr.trim() ?? 'docker build failed.',
      );
    }

    return BuildStepResult.success(
      BuildStepKind.jasprServerImage,
      label,
      outputPath: '$imageBase:latest',
    );
  }

  /// `dart compile exe bin/<appName>.dart` for the `arcaneCli` template.
  /// Build-only — `arcane_cli_app` has no deploy target by design.
  Future<BuildStepResult> buildDartCli() async {
    const String label = 'Dart CLI compile';

    if (!config.template.isDartCli) {
      return BuildStepResult.skipped(
        BuildStepKind.dartCli,
        label,
        reason: 'Template ${config.template.displayName} is not a Dart CLI.',
      );
    }

    final Directory projectDir = Directory(_dartCliPath);
    final File entry =
        File(p.join(projectDir.path, 'bin', '${config.appName}.dart'));
    if (!entry.existsSync()) {
      return BuildStepResult.failed(
        BuildStepKind.dartCli,
        label,
        reason: 'CLI entrypoint not found at ${entry.path}.',
      );
    }

    info('Compiling Dart CLI binary...');
    final ProcessResult? result = await _runner.runWithRetry(
      'dart',
      <String>['compile', 'exe', 'bin/${config.appName}.dart'],
      workingDirectory: projectDir.path,
      operationName: 'dart compile exe',
    );

    if (result == null || !result.success) {
      return BuildStepResult.failed(
        BuildStepKind.dartCli,
        label,
        reason: result?.stderr.trim() ?? 'dart compile failed.',
      );
    }

    return BuildStepResult.success(
      BuildStepKind.dartCli,
      label,
      outputPath: p.join(projectDir.path, 'bin', '${config.appName}.exe'),
    );
  }

  // ─── Internals ─────────────────────────────────────────────────────────

  /// Normalize a user-provided mount path (`'/app'`, `'app'`,
  /// `'/app/'`) to Flutter's required `--base-href` form
  /// (`'/app/'`).
  static String _normalizedBaseHref(String mount) {
    String value = mount.trim();
    if (value.isEmpty) value = '/app';
    if (!value.startsWith('/')) value = '/$value';
    if (!value.endsWith('/')) value = '$value/';
    return value;
  }

  /// Copy [source] into [target] recursively, creating directories on
  /// demand. Skips `.DS_Store` and lock files the same way
  /// `TemplateCopier` does.
  static Future<void> _copyDirectoryRecursive(
    Directory source,
    Directory target,
  ) async {
    if (!target.existsSync()) {
      await target.create(recursive: true);
    }
    await for (final FileSystemEntity entity in source.list(recursive: false)) {
      final String basename = p.basename(entity.path);
      if (basename == '.DS_Store' || basename == 'pubspec.lock') continue;

      final String dest = p.join(target.path, basename);
      if (entity is Directory) {
        await _copyDirectoryRecursive(entity, Directory(dest));
      } else if (entity is File) {
        await entity.copy(dest);
      }
    }
  }

  /// Read the current git SHA in [workingDir]. Returns `null` when
  /// `git` is unavailable or the directory is not a git repo — both
  /// are normal cases (the build still succeeds with just `:latest`).
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

  /// Uncomment the Flutter bootstrap `<script>` tag inside the Jaspr
  /// host's `web/index.html`.
  ///
  /// Finds the block:
  /// ```
  /// <!-- ORACULAR_FLUTTER_BOOTSTRAP_BEGIN -->
  /// <!-- <script src="..." async></script> -->
  /// <!-- ORACULAR_FLUTTER_BOOTSTRAP_END -->
  /// ```
  /// and replaces it with the same block where the inner line is no
  /// longer wrapped in `<!-- … -->`. Idempotent — when the inner line
  /// is already uncommented, nothing changes.
  Future<void> _enableFlutterBootstrapScript({required String mount}) async {
    final File indexFile = File(p.join(_jasprAppPath, 'web', 'index.html'));
    if (!indexFile.existsSync()) {
      verbose(
        '  index.html not found at ${indexFile.path}; '
        'skipping Flutter bootstrap injection.',
      );
      return;
    }

    final String content = await indexFile.readAsString();
    final RegExp block = RegExp(
      r'<!-- ORACULAR_FLUTTER_BOOTSTRAP_BEGIN -->'
      r'[\s\S]*?'
      r'<!-- ORACULAR_FLUTTER_BOOTSTRAP_END -->',
    );
    if (!block.hasMatch(content)) {
      verbose(
        '  ORACULAR_FLUTTER_BOOTSTRAP markers not found in '
        '${indexFile.path}; appending bootstrap tag instead.',
      );
      // Fallback: append the script tag just before </body>.
      final String tag = '<script src="/$mount/flutter_bootstrap.js" async>'
          '</script>';
      final String patched = content.replaceFirst(
        '</body>',
        '  $tag\n</body>',
      );
      if (patched != content) {
        await indexFile.writeAsString(patched);
      }
      return;
    }

    final String replacement = '<!-- ORACULAR_FLUTTER_BOOTSTRAP_BEGIN -->\n'
        '  <script src="/$mount/flutter_bootstrap.js" async></script>\n'
        '  <!-- ORACULAR_FLUTTER_BOOTSTRAP_END -->';

    final String patched = content.replaceFirst(block, replacement);
    if (patched != content) {
      await indexFile.writeAsString(patched);
      verbose(
        '  Uncommented Flutter bootstrap script in ${indexFile.path} '
        '(mount=/$mount/).',
      );
    }
  }
}
