import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../models/setup_config.dart';
import '../utils/process_runner.dart' show ProcessResult, ProcessRunner;
import 'cloud_run_preflight.dart';

/// Service for server setup and deployment
class ServerSetup {
  final SetupConfig config;
  final ProcessRunner _runner;

  ServerSetup(this.config, {ProcessRunner? runner})
    : _runner = runner ?? ProcessRunner();

  /// Get the server project path
  String get serverPath => p.join(config.outputDir, config.serverPackageName);

  /// Generate production Dockerfile
  Future<void> generateDockerfile() async {
    if (!config.createServer) return;

    info('Generating Dockerfile...');

    final String content =
        '''
# Production Dockerfile for ${config.serverPackageName}
# Multi-stage build for minimal image size
#
# Build context: the server package directory (e.g. ${config.serverPackageName}/).
# Oracular copies the sibling models package into this directory before
# `docker build` so `${config.modelsPackageName}/` is available at the
# root of the context. The pubspec.yaml inside /app references models
# via `path: ../${config.modelsPackageName}`, which resolves to the
# /${config.modelsPackageName}/ directory placed alongside /app below.

# Build stage
FROM ubuntu:22.04 AS build

# Install dependencies
# `flutter build linux --release` requires the full Flutter Linux desktop
# toolchain — clang, cmake, ninja-build, pkg-config, libgtk-3-dev,
# liblzma-dev, libstdc++-12-dev — in addition to the base curl/git/zip
# utilities. Without these the build fails with `CMake is required for
# Linux development.` See:
# https://docs.flutter.dev/get-started/install/linux/desktop#additional-linux-requirements
RUN apt-get update && apt-get install -y \\
    curl \\
    git \\
    unzip \\
    xz-utils \\
    zip \\
    libglu1-mesa \\
    clang \\
    cmake \\
    ninja-build \\
    pkg-config \\
    libgtk-3-dev \\
    liblzma-dev \\
    libstdc++-12-dev \\
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git /flutter
ENV PATH="/flutter/bin:\$PATH"
RUN git config --global --add safe.directory /flutter
RUN flutter doctor
RUN flutter config --enable-linux-desktop

# Copy the models package alongside /app so the relative path
# `../${config.modelsPackageName}` in pubspec.yaml resolves correctly.
COPY ${config.modelsPackageName}/ /${config.modelsPackageName}/

# Copy server source (everything in the build context) into /app.
WORKDIR /app
COPY . /app/

# Get dependencies and build
RUN flutter pub get
RUN flutter build linux --release

# Runtime stage
FROM ubuntu:22.04

# `flutter build linux --release` produces a Flutter *desktop* binary that
# links against GTK and tries to open an X11 display on startup
# (`Gtk-WARNING **: cannot open display:`). On Cloud Run there is no display,
# so we start Xvfb manually and point DISPLAY at it before launching the
# binary.
#
# We do this with a small shell wrapper instead of the canonical `xvfb-run`
# helper because `xvfb-run` on Ubuntu 22.04 hangs forever in `wait` waiting
# for an Xvfb-sent SIGUSR1 that the modern Xvfb doesn't emit reliably,
# leaving the container stuck before the binary ever runs (and Cloud Run
# then fails the deploy with "container failed to start and listen on the
# port"). The manual `Xvfb :99 & sleep && exec …` pattern is what every
# headless-Flutter-on-Cloud-Run example actually uses in production.
#
# Packages:
#   - xvfb        - virtual framebuffer X server
#   - libgtk-3-0  - GTK runtime the Flutter shell links against
#   - libegl1 / libgles2 - OpenGL drivers Flutter shell needs even headless
#   - libblkid1 / liblzma5 - misc transitive runtime deps
RUN apt-get update && apt-get install -y \\
    xvfb \\
    libgtk-3-0 \\
    libegl1 \\
    libgles2 \\
    libblkid1 \\
    liblzma5 \\
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the Flutter desktop bundle from the build stage. We keep the
# `bundle/` subdirectory layout (rather than flattening into /app) so that
# Flutter's relative asset / library lookups (./data, ./lib/*.so) resolve
# the way they do during local `flutter run`.
COPY --from=build /app/build/linux/x64/release/bundle/ ./bundle/

# Copy service account key (lives at the root of the build context).
COPY *.json ./

# Expose port
EXPOSE 8080

# Launch the binary with a manually-managed Xvfb backing DISPLAY=:99.
# `exec` replaces the shell so the binary becomes PID 1 and receives
# SIGTERM cleanly when Cloud Run scales the instance down.
CMD ["sh", "-c", "Xvfb :99 -screen 0 800x600x16 & export DISPLAY=:99 && sleep 1 && exec ./bundle/\$SERVER_NAME"]
'''
            .replaceAll('\$SERVER_NAME', config.serverPackageName);

    final File file = File(p.join(serverPath, 'Dockerfile'));
    await file.writeAsString(content);
    success('Generated: ${config.serverPackageName}/Dockerfile');
  }

  /// Generate development Dockerfile
  Future<void> generateDockerfileDev() async {
    if (!config.createServer) return;

    info('Generating Dockerfile-dev...');

    final String content =
        '''
# Development Dockerfile for ${config.serverPackageName}
# Includes Flutter SDK for debugging
#
# Build context: the server package directory (e.g. ${config.serverPackageName}/).
# Oracular copies the sibling models package into this directory before
# `docker build` so `${config.modelsPackageName}/` is available at the
# root of the context.

FROM ubuntu:22.04

# Install dependencies
# `flutter build linux --release` requires the full Flutter Linux desktop
# toolchain (clang, cmake, ninja-build, pkg-config, libgtk-3-dev,
# liblzma-dev, libstdc++-12-dev). The runtime libraries (libgtk-3-0,
# libblkid1, liblzma5) come along automatically as transitive deps.
RUN apt-get update && apt-get install -y \\
    curl \\
    git \\
    unzip \\
    xz-utils \\
    zip \\
    libglu1-mesa \\
    libgtk-3-0 \\
    libblkid1 \\
    liblzma5 \\
    clang \\
    cmake \\
    ninja-build \\
    pkg-config \\
    libgtk-3-dev \\
    liblzma-dev \\
    libstdc++-12-dev \\
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git /flutter
ENV PATH="/flutter/bin:\$PATH"
RUN git config --global --add safe.directory /flutter
RUN flutter doctor
RUN flutter config --enable-linux-desktop

# Copy the models package alongside /app so the relative path
# `../${config.modelsPackageName}` in pubspec.yaml resolves correctly.
COPY ${config.modelsPackageName}/ /${config.modelsPackageName}/

# Copy server source (everything in the build context) into /app.
WORKDIR /app
COPY . /app/

# Get dependencies
RUN flutter pub get

# Copy service account key (lives at the root of the build context).
COPY *.json ./

# Expose port
EXPOSE 8080

# Run the server in development mode
CMD ["flutter", "run", "-d", "linux"]
''';

    final File file2 = File(p.join(serverPath, 'Dockerfile-dev'));
    await file2.writeAsString(content);
    success('Generated: ${config.serverPackageName}/Dockerfile-dev');
  }

  /// Generate deployment script
  Future<void> generateDeployScript() async {
    if (!config.createServer) return;
    if (config.firebaseProjectId == null) {
      warn('Firebase project ID not set, skipping deploy script');
      return;
    }

    info('Generating deploy script...');

    final String content =
        '''
#!/bin/bash
# Deployment script for ${config.serverPackageName}
#
# Generated by Oracular. Idempotent: every gcloud step gracefully handles
# already-existing resources. Cleanup steps at the end keep Artifact
# Registry storage and Cloud Run revision counts bounded.

set -e

PROJECT_ID="${config.firebaseProjectId}"
REGION="us-central1"
SERVICE_NAME="${config.serverPackageName.replaceAll('_', '-')}"
REPOSITORY="oracular"
IMAGE_NAME="\$REGION-docker.pkg.dev/\$PROJECT_ID/\$REPOSITORY/\$SERVICE_NAME"

# Cleanup tunables — keep in sync with oracular/lib/models/setup_config.dart
ARTIFACT_KEEP_RECENT="${config.artifactKeepRecent}"
ARTIFACT_DELETE_OLDER_DAYS="${config.artifactDeleteOlderDays}"
CLOUD_RUN_KEEP_REVISIONS="${config.cloudRunKeepRevisions}"

echo "==> Ensuring Artifact Registry repository exists..."
gcloud artifacts repositories create \$REPOSITORY \\
    --repository-format=docker \\
    --location \$REGION \\
    --project \$PROJECT_ID || true

echo "==> Configuring Docker auth for Artifact Registry..."
gcloud auth configure-docker "\$REGION-docker.pkg.dev" --quiet

echo "==> Building Docker image..."
docker build --platform linux/amd64 -t \$IMAGE_NAME .

echo "==> Pushing to Artifact Registry..."
docker push \$IMAGE_NAME

echo "==> Deploying to Cloud Run..."
gcloud run deploy \$SERVICE_NAME \\
    --image \$IMAGE_NAME \\
    --platform managed \\
    --region \$REGION \\
    --project \$PROJECT_ID \\
    --allow-unauthenticated \\
    --port 8080 \\
    --memory 512Mi \\
    --cpu 1 \\
    --min-instances 0 \\
    --max-instances 10

# ─── Cleanup: Artifact Registry image versions ──────────────────────────────
# Apply the cleanup-policy.json shipped alongside this script. Keeps the
# N most-recent versions and deletes anything older than D days.
if [ -f "\$(dirname "\$0")/cleanup-policy.json" ]; then
  echo "==> Applying Artifact Registry cleanup policy..."
  gcloud artifacts repositories set-cleanup-policies \$REPOSITORY \\
      --location \$REGION \\
      --project \$PROJECT_ID \\
      --policy "\$(dirname "\$0")/cleanup-policy.json" || \\
    echo "WARNING: cleanup policy not applied (gcloud >= 444.0.0 required)"
else
  echo "WARNING: cleanup-policy.json not found alongside script — skipping AR cleanup"
fi

# ─── Cleanup: Cloud Run revisions ───────────────────────────────────────────
# Keep the latest \$CLOUD_RUN_KEEP_REVISIONS revisions and delete anything
# older that is not currently routing traffic.
echo "==> Pruning old Cloud Run revisions for \$SERVICE_NAME (keep latest \$CLOUD_RUN_KEEP_REVISIONS)..."
ALL_REVS=\$(gcloud run revisions list \\
    --service=\$SERVICE_NAME \\
    --region=\$REGION \\
    --project=\$PROJECT_ID \\
    --sort-by="~creationTimestamp" \\
    --format="value(metadata.name)" 2>/dev/null || true)

if [ -n "\$ALL_REVS" ]; then
  TRAFFIC_REVS=\$(gcloud run services describe \$SERVICE_NAME \\
      --region=\$REGION \\
      --project=\$PROJECT_ID \\
      --format="value(status.traffic.revisionName)" 2>/dev/null || true)

  COUNT=0
  for REV in \$ALL_REVS; do
    COUNT=\$((COUNT+1))
    if [ "\$COUNT" -le "\$CLOUD_RUN_KEEP_REVISIONS" ]; then
      continue
    fi
    if echo "\$TRAFFIC_REVS" | grep -q "\$REV"; then
      echo "  Skipping \$REV (serving traffic)"
      continue
    fi
    echo "  Deleting old revision: \$REV"
    gcloud run revisions delete \$REV \\
        --region=\$REGION \\
        --project=\$PROJECT_ID \\
        --quiet || echo "  WARNING: could not delete \$REV"
  done
else
  echo "WARNING: could not list Cloud Run revisions — skipping prune"
fi

echo ""
echo "Deployment complete!"
echo "Service URL: https://\$SERVICE_NAME-\$PROJECT_ID.\$REGION.run.app"
''';

    final File file3 = File(p.join(serverPath, 'script_deploy.sh'));
    await file3.writeAsString(content);

    // Make executable
    await _runner.run('chmod', <String>['+x', file3.path]);

    success('Generated: ${config.serverPackageName}/script_deploy.sh');

    // Also drop the cleanup-policy.json next to the script so the script
    // can find it without depending on the templates directory at runtime.
    await _ensureCleanupPolicyFile();
  }

  /// Write a cleanup policy JSON next to the deploy script. Idempotent: if
  /// the file already exists (e.g. user customized it) we leave it alone.
  Future<void> _ensureCleanupPolicyFile() async {
    final File policyFile = File(p.join(serverPath, 'cleanup-policy.json'));
    if (policyFile.existsSync()) {
      info(
        'Existing cleanup-policy.json detected — leaving user customizations untouched.',
      );
      return;
    }

    final String content =
        '''
[
  {
    "name": "keep-recent",
    "action": { "type": "Keep" },
    "mostRecentVersions": {
      "keepCount": ${config.artifactKeepRecent},
      "packageNamePrefixes": []
    }
  },
  {
    "name": "delete-stale",
    "action": { "type": "Delete" },
    "condition": {
      "olderThan": "${config.artifactDeleteOlderDays}d"
    }
  }
]
''';

    await policyFile.writeAsString(content);
    success('Generated: ${config.serverPackageName}/cleanup-policy.json');
  }

  /// Copy service account key to server
  Future<void> copyServiceAccountKey() async {
    if (!config.createServer) return;
    if (config.serviceAccountKeyPath == null) {
      warn('No service account key path provided');
      return;
    }

    final File sourceFile = File(config.serviceAccountKeyPath!);
    if (!sourceFile.existsSync()) {
      error('Service account key not found: ${config.serviceAccountKeyPath}');
      return;
    }

    info('Copying service account key...');

    final String destPath = p.join(serverPath, 'service-account.json');
    final String sourcePath = p.normalize(sourceFile.path);
    final String normalizedDestPath = p.normalize(destPath);

    if (sourcePath == normalizedDestPath) {
      info('Service account key already in place: $destPath');
      return;
    }

    final File destFile = File(destPath);
    if (destFile.existsSync()) {
      await _rotateServiceAccountBackups(destFile);
    }

    await sourceFile.copy(destPath);

    // Add to gitignore
    final File gitignore = File(p.join(serverPath, '.gitignore'));
    if (gitignore.existsSync()) {
      String content = await gitignore.readAsString();
      if (!content.contains('*.json')) {
        content += '\n# Service account keys\n*.json\n';
        await gitignore.writeAsString(content);
      }
    }

    success('Service account key copied');
  }

  Future<void> _rotateServiceAccountBackups(File currentKeyFile) async {
    final File backup1 = File('${currentKeyFile.path}.bak.1');
    final File backup2 = File('${currentKeyFile.path}.bak.2');

    if (backup2.existsSync()) {
      await backup2.delete();
    }
    if (backup1.existsSync()) {
      await backup1.rename(backup2.path);
    }

    await currentKeyFile.copy(backup1.path);
    info(
      'Existing service-account.json backed up to ${p.basename(backup1.path)} (retaining 2 backups)',
    );
  }

  /// Build the server Docker image
  Future<bool> buildDockerImage() async {
    if (!config.createServer) return false;

    info('Building Docker image...');

    // Copy models to server directory for Docker context. Idempotent:
    // delete the previous copy first so a second run does NOT end up with
    // `<server>/<models>/<models>/` (cp -r merges-into-existing-dir
    // semantics on macOS / GNU coreutils).
    if (config.createModels) {
      final String modelsPath = p.join(config.outputDir, config.modelsPackageName);
      final String targetPath = p.join(serverPath, config.modelsPackageName);
      final Directory target = Directory(targetPath);
      if (target.existsSync()) {
        try {
          await target.delete(recursive: true);
        } catch (_) {
          // Best-effort cleanup; cp -r will overwrite.
        }
      }

      await _runner.run('cp', <String>['-r', modelsPath, targetPath]);
    }

    final ProcessResult? result = await _runner.runWithRetry(
      'docker',
      <String>[
        'build',
        '--platform',
        'linux/amd64',
        '-t',
        config.serverPackageName,
        '.',
      ],
      workingDirectory: serverPath,
      operationName: 'Docker build',
    );

    return result != null && result.success;
  }

  /// Cloud Run service name (`serverPackageName` with underscores replaced
  /// by hyphens to satisfy Cloud Run naming rules).
  String get serverServiceName => config.serverPackageName.replaceAll('_', '-');

  /// Build the fully-qualified Artifact Registry image tag for this server.
  ///
  /// Format: `<region>-docker.pkg.dev/<project>/<repository>/<service>:latest`.
  /// Mirrors `script_deploy.sh` so re-deploys land on the same tag.
  String _imageTag({required String region, required String repository}) {
    final String projectId = config.firebaseProjectId ?? '';
    return '$region-docker.pkg.dev/$projectId/$repository/$serverServiceName:latest';
  }

  /// Build, push, and deploy the server to Google Cloud Run.
  ///
  /// This is the Dart-side equivalent of the generated `script_deploy.sh`
  /// shell script and is what `oracular deploy all` calls when
  /// [SetupConfig.createServer] is true. The end-to-end flow is:
  ///
  ///   1. **Models snapshot** (`cp -r [modelsDir] [serverDir]/[modelsDir]/`)
  ///      — only when [SetupConfig.createModels] is true. The Docker build
  ///      context needs the models package alongside the server source.
  ///   2. **Docker auth** (configure-docker against the regional
  ///      `*-docker.pkg.dev` host).
  ///   3. **Docker build** (`docker build --platform linux/amd64 -t
  ///      `[imageTag]` .` from the server directory).
  ///   4. **Docker push** of [imageTag].
  ///   5. **Cloud Run deploy** of [imageTag] to [serviceName].
  ///
  /// Failures short-circuit and return `false`. Each step uses
  /// `_runner.runWithRetry` so transient docker/network errors get the
  /// same retry semantics as everything else in Oracular.
  ///
  /// Returns the live Cloud Run URL on success; null on failure.
  Future<String?> deployToCloudRun({
    String repository = 'oracular',
    String region = 'us-central1',
  }) async {
    if (!config.createServer) {
      warn('Server is not enabled for this project — skipping Cloud Run '
          'deploy.');
      return null;
    }
    final String? projectId = config.firebaseProjectId;
    if (projectId == null || projectId.trim().isEmpty) {
      error('No Firebase / GCP project ID configured — cannot deploy to '
          'Cloud Run. Set FIREBASE_PROJECT_ID in config/setup_config.env '
          'and re-run.');
      return null;
    }

    final Directory serverDir = Directory(serverPath);
    if (!serverDir.existsSync()) {
      error('Server package not found at $serverPath. Run '
          '`oracular deploy server-setup` first.');
      return null;
    }
    final File dockerfile = File(p.join(serverPath, 'Dockerfile'));
    if (!dockerfile.existsSync()) {
      warn('No Dockerfile found at ${dockerfile.path} — generating one '
          'before deploy.');
      await generateDockerfile();
    }

    // Preflight: detect the most common dev-environment foot-gun BEFORE
    // we shell out to gcloud / docker. The user typically has multiple
    // credentialed gcloud accounts (personal + per-project SAs), and
    // `gcloud config set account …` from a previous oracular run leaves
    // a *different* project's service account active. Catching that here
    // turns a confusing cascade of "PERMISSION_DENIED enabling
    // artifactregistry.googleapis.com" warnings deep in the deploy into
    // one clear actionable error up front. Runs AFTER the cheap path
    // checks above so that "config wrong" errors don't waste a gcloud
    // round-trip.
    final CloudRunPreflight preflight = CloudRunPreflight(runner: _runner);
    if (!await preflight.verifyActiveGcloudAccount(projectId: projectId)) {
      return null;
    }

    final String imageTag = _imageTag(region: region, repository: repository);

    // 1. Copy models snapshot for the Docker build context. Idempotent:
    // we delete the previous copy first so old model files can't hang
    // around and confuse the build.
    if (config.createModels) {
      final String modelsPath =
          p.join(config.outputDir, config.modelsPackageName);
      final String targetPath =
          p.join(serverPath, config.modelsPackageName);
      final Directory target = Directory(targetPath);
      if (target.existsSync()) {
        try {
          await target.delete(recursive: true);
        } catch (_) {
          // Best-effort cleanup; cp -r will overwrite.
        }
      }
      info('Copying models snapshot for Docker context...');
      final ProcessResult cp = await _runner.run(
        'cp',
        <String>['-r', modelsPath, targetPath],
      );
      if (!cp.success) {
        error('Failed to copy models package into server build context: '
            '${cp.stderr.trim()}');
        return null;
      }
    }

    // 2. Configure Docker auth for Artifact Registry.
    info('Configuring Docker auth for $region-docker.pkg.dev...');
    final ProcessResult? auth = await _runner.runWithRetry(
      'gcloud',
      <String>[
        'auth',
        'configure-docker',
        '$region-docker.pkg.dev',
        '--quiet',
      ],
      operationName: 'gcloud auth configure-docker',
    );
    if (auth == null || !auth.success) {
      error('Failed to configure Docker auth for Artifact Registry. '
          'Run `gcloud auth login` and retry.');
      return null;
    }

    // 2b. Ensure the GCP services we need (Artifact Registry + Cloud Run)
    // are enabled. On a fresh project these are off by default and the
    // docker push will fail with `Artifact Registry API has not been used
    // in project … before or it is disabled`. Enabling here is idempotent
    // (gcloud reports success when the API is already enabled) and runs
    // synchronously enough that propagation typically lands before the
    // push step a few seconds later.
    if (!await preflight.ensureCloudRunPrerequisiteApis(projectId: projectId)) {
      // Non-fatal: we still attempt the push because the API may have
      // been enabled in a prior run. The push itself will surface a
      // clear error if it really isn't enabled.
      warn('Could not confirm Artifact Registry / Cloud Run APIs are '
          'enabled. Continuing — push will fail with a clear error if '
          'they really are off.');
    }

    // 2c. Ensure the Artifact Registry repository (`<region>/<repository>`)
    // exists. Without this, `docker push` fails with NOT_FOUND because
    // the registry path doesn't resolve to an existing repo. Idempotent:
    // we treat 409 / "already exists" as success.
    if (!await preflight.ensureArtifactRegistryRepository(
      projectId: projectId,
      repository: repository,
      region: region,
    )) {
      error('Could not ensure Artifact Registry repository '
          '`$repository` in $region exists. Push will fail without it.');
      return null;
    }

    // 3. Build Docker image with the AR-qualified tag so we can push
    // directly without a separate `docker tag` step.
    info('Building Docker image $imageTag...');
    final ProcessResult? build = await _runner.runWithRetry(
      'docker',
      <String>[
        'build',
        '--platform',
        'linux/amd64',
        '-t',
        imageTag,
        '.',
      ],
      workingDirectory: serverPath,
      operationName: 'Docker build',
    );
    if (build == null || !build.success) {
      error('Docker build failed for $serverServiceName.');
      return null;
    }

    // 4. Push image to Artifact Registry.
    info('Pushing image to Artifact Registry...');
    final ProcessResult? push = await _runner.runWithRetry(
      'docker',
      <String>['push', imageTag],
      workingDirectory: serverPath,
      operationName: 'Docker push',
    );
    if (push == null || !push.success) {
      error('Docker push failed. Verify the Artifact Registry repository '
          '`$repository` exists in $region (run '
          '`oracular deploy server-setup` to create it via gcloud).');
      return null;
    }

    // 5. Deploy to Cloud Run.
    info('Deploying $serverServiceName to Cloud Run ($region)...');
    final ProcessResult? deploy = await _runner.runWithRetry(
      'gcloud',
      <String>[
        'run',
        'deploy',
        serverServiceName,
        '--image=$imageTag',
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
      operationName: 'gcloud run deploy',
    );
    if (deploy == null || !deploy.success) {
      error('gcloud run deploy failed for service $serverServiceName.');
      return null;
    }

    // Cloud Run URLs are not predictable from project-id alone (they
    // embed a per-project hash, e.g. `<service>-<hash>-uc.a.run.app`),
    // so we ask gcloud for the current URL after the deploy succeeds.
    String url = 'https://$serverServiceName-$projectId.$region.run.app';
    final ProcessResult describe = await _runner.run(
      'gcloud',
      <String>[
        'run',
        'services',
        'describe',
        serverServiceName,
        '--region=$region',
        '--project=$projectId',
        '--format=value(status.url)',
      ],
    );
    final String describedUrl = describe.stdout.trim();
    if (describe.success && describedUrl.isNotEmpty) {
      url = describedUrl;
    }
    success('Server deployed to Cloud Run.');
    info('  Service URL: $url');
    return url;
  }

  /// Run the server locally with Docker
  Future<bool> runDockerDev() async {
    if (!config.createServer) return false;

    info('Running server in Docker (development)...');

    final int result = await _runner.runStreaming('docker', <String>[
      'run',
      '-p',
      '8080:8080',
      '-v',
      '$serverPath:/app',
      config.serverPackageName,
    ]);

    return result == 0;
  }

  /// Generate all server files
  Future<void> generateAll() async {
    if (!config.createServer) {
      warn('Server not enabled, skipping server setup');
      return;
    }

    info('Setting up server deployment files...');

    await generateDockerfile();
    await generateDockerfileDev();
    await generateDeployScript();
    await copyServiceAccountKey();

    success('Server setup complete');
  }
}
