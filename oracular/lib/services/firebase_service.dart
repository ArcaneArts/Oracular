import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../models/setup_config.dart';
import '../utils/process_runner.dart' show ProcessResult, ProcessRunner;

/// Service for Firebase operations
class FirebaseService {
  final SetupConfig config;
  final ProcessRunner _runner;

  FirebaseService(this.config, {ProcessRunner? runner})
    : _runner = runner ?? ProcessRunner();

  /// Login to Firebase CLI
  Future<bool> login() async {
    info('Logging in to Firebase...');

    final int result = await _runner.runStreaming('firebase', <String>['login']);
    return result == 0;
  }

  /// Login to gcloud
  Future<bool> gcloudLogin() async {
    info('Logging in to Google Cloud...');

    final int result = await _runner.runStreaming('gcloud', <String>['auth', 'login']);
    return result == 0;
  }

  /// Configure FlutterFire for the project
  Future<bool> configureFlutterFire() async {
    if (config.firebaseProjectId == null) {
      error('Firebase project ID not set');
      return false;
    }

    final String projectPath = p.join(config.outputDir, config.appName);

    info('Configuring FlutterFire...');

    final List<String> args = <String>['configure', '--project', config.firebaseProjectId!];

    // Add platforms based on template
    for (final String platform in config.platforms) {
      args.add('--platforms');
      args.add(platform);
    }

    final ProcessResult? result = await _runner.runWithRetry(
      'flutterfire',
      args,
      workingDirectory: projectPath,
      operationName: 'FlutterFire configure',
    );

    return result != null && result.success;
  }

  /// Deploy Firestore rules
  Future<bool> deployFirestore() async {
    info('Deploying Firestore rules...');

    final ProcessResult? result = await _runner.runWithRetry(
      'firebase',
      <String>['deploy', '--only', 'firestore:rules,firestore:indexes'],
      workingDirectory: config.outputDir,
      operationName: 'Deploy Firestore',
    );

    return result != null && result.success;
  }

  /// Deploy Storage rules
  Future<bool> deployStorage() async {
    info('Deploying Storage rules...');

    final ProcessResult? result = await _runner.runWithRetry(
      'firebase',
      <String>['deploy', '--only', 'storage'],
      workingDirectory: config.outputDir,
      operationName: 'Deploy Storage',
    );

    return result != null && result.success;
  }

  /// Build web app
  Future<bool> buildWeb() async {
    final String projectPath = p.join(config.outputDir, config.appName);

    info('Building web app...');

    final ProcessResult? result = await _runner.runWithRetry(
      'flutter',
      <String>['build', 'web', '--release'],
      workingDirectory: projectPath,
      operationName: 'Flutter build web',
    );

    return result != null && result.success;
  }

  /// Deploy to Firebase Hosting (release target)
  Future<bool> deployHostingRelease() async {
    info('Deploying to Firebase Hosting (release)...');

    final ProcessResult? result = await _runner.runWithRetry(
      'firebase',
      <String>['deploy', '--only', 'hosting:release'],
      workingDirectory: config.outputDir,
      operationName: 'Deploy Hosting (release)',
    );

    return result != null && result.success;
  }

  /// Deploy to Firebase Hosting (beta target)
  Future<bool> deployHostingBeta() async {
    info('Deploying to Firebase Hosting (beta)...');

    final ProcessResult? result = await _runner.runWithRetry(
      'firebase',
      <String>['deploy', '--only', 'hosting:beta'],
      workingDirectory: config.outputDir,
      operationName: 'Deploy Hosting (beta)',
    );

    return result != null && result.success;
  }

  /// Deploy all Firebase resources
  Future<bool> deployAll() async {
    info('Deploying all Firebase resources...');

    // Deploy in order
    if (!await deployFirestore()) {
      warn('Firestore deployment failed');
    }

    if (!await deployStorage()) {
      warn('Storage deployment failed');
    }

    if (!await buildWeb()) {
      error('Web build failed');
      return false;
    }

    if (!await deployHostingRelease()) {
      warn('Hosting deployment failed');
    }

    success('Firebase deployment complete');
    return true;
  }

  /// Enable Google Cloud APIs needed for deployment
  Future<bool> enableGoogleApis() async {
    if (config.firebaseProjectId == null) {
      error('Firebase project ID not set');
      return false;
    }

    info('Enabling Google Cloud APIs...');

    // Enable Artifact Registry
    ProcessResult result = await _runner.run('gcloud', <String>[
      'services',
      'enable',
      'artifactregistry.googleapis.com',
      '--project',
      config.firebaseProjectId!,
    ]);

    if (!result.success) {
      warn('Failed to enable Artifact Registry API');
    }

    // Enable Cloud Run
    result = await _runner.run('gcloud', <String>[
      'services',
      'enable',
      'run.googleapis.com',
      '--project',
      config.firebaseProjectId!,
    ]);

    if (!result.success) {
      warn('Failed to enable Cloud Run API');
    }

    return true;
  }
}
