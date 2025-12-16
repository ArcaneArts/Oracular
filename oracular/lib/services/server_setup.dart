import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../models/setup_config.dart';
import '../utils/process_runner.dart' show ProcessResult, ProcessRunner;

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

# Build stage
FROM ubuntu:22.04 AS build

# Install dependencies
RUN apt-get update && apt-get install -y \\
    curl \\
    git \\
    unzip \\
    xz-utils \\
    zip \\
    libglu1-mesa \\
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git /flutter
ENV PATH="/flutter/bin:\$PATH"
RUN flutter doctor
RUN flutter config --enable-linux-desktop

# Set up work directory
WORKDIR /app

# Copy models if it exists
COPY ${config.modelsPackageName}/ /${config.modelsPackageName}/

# Copy server source
COPY ${config.serverPackageName}/ /app/

# Get dependencies and build
RUN flutter pub get
RUN flutter build linux --release

# Runtime stage
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \\
    libgtk-3-0 \\
    libblkid1 \\
    liblzma5 \\
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy built binary from build stage
COPY --from=build /app/build/linux/x64/release/bundle/ ./

# Copy service account key
COPY ${config.serverPackageName}/*.json ./

# Expose port
EXPOSE 8080

# Run the server
CMD ["./\$SERVER_NAME"]
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

FROM ubuntu:22.04

# Install dependencies
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
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git /flutter
ENV PATH="/flutter/bin:\$PATH"
RUN flutter doctor
RUN flutter config --enable-linux-desktop

# Set up work directory
WORKDIR /app

# Copy models if it exists
COPY ${config.modelsPackageName}/ /${config.modelsPackageName}/

# Copy server source
COPY ${config.serverPackageName}/ /app/

# Get dependencies
RUN flutter pub get

# Copy service account key
COPY ${config.serverPackageName}/*.json ./

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

set -e

PROJECT_ID="${config.firebaseProjectId}"
REGION="us-central1"
SERVICE_NAME="${config.serverPackageName.replaceAll('_', '-')}"
IMAGE_NAME="gcr.io/\$PROJECT_ID/\$SERVICE_NAME"

echo "Building Docker image..."
docker build --platform linux/amd64 -t \$IMAGE_NAME .

echo "Pushing to Container Registry..."
docker push \$IMAGE_NAME

echo "Deploying to Cloud Run..."
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

echo "Deployment complete!"
echo "Service URL: https://\$SERVICE_NAME-\$PROJECT_ID.\$REGION.run.app"
''';

    final File file3 = File(p.join(serverPath, 'script_deploy.sh'));
    await file3.writeAsString(content);

    // Make executable
    await _runner.run('chmod', <String>['+x', file3.path]);

    success('Generated: ${config.serverPackageName}/script_deploy.sh');
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

  /// Build the server Docker image
  Future<bool> buildDockerImage() async {
    if (!config.createServer) return false;

    info('Building Docker image...');

    // Copy models to server directory for Docker context
    if (config.createModels) {
      final String modelsPath = p.join(config.outputDir, config.modelsPackageName);
      final String targetPath = p.join(serverPath, config.modelsPackageName);

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
