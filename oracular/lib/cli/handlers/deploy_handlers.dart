import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../../models/setup_config.dart';
import '../../services/config_generator.dart';
import '../../services/firebase_service.dart';
import '../../services/server_setup.dart';
import '../../utils/user_prompt.dart';

/// Load configuration from project directory
/// Searches in multiple locations to handle different working directories
Future<SetupConfig?> _loadConfig() async {
  final currentDir = Directory.current.path;

  // List of potential config locations to search
  final searchPaths = <String>[
    // Direct location in current directory
    p.join(currentDir, 'config', 'setup_config.env'),
    // Parent directory (if running from within app folder)
    p.join(currentDir, '..', 'config', 'setup_config.env'),
    // Check if we're in a nested project folder
    p.join(currentDir, '..', '..', 'config', 'setup_config.env'),
  ];

  for (final path in searchPaths) {
    final normalizedPath = p.normalize(path);
    final config = await SetupConfig.loadFromFile(normalizedPath);
    if (config != null) {
      verbose('Loaded config from: $normalizedPath');
      return config;
    }
  }

  return null;
}

/// Deploy Firestore rules and indexes
Future<void> handleDeployFirestore() async {
  final config = await _loadConfig();
  if (config == null) {
    error('No configuration found. Run "oracular create" first.');
    return;
  }

  if (!config.useFirebase) {
    error('Firebase is not enabled for this project.');
    return;
  }

  final firebase = FirebaseService(config);
  if (await firebase.deployFirestore()) {
    success('Firestore deployed successfully');
  } else {
    error('Firestore deployment failed');
  }
}

/// Deploy Storage rules
Future<void> handleDeployStorage() async {
  final config = await _loadConfig();
  if (config == null) {
    error('No configuration found. Run "oracular create" first.');
    return;
  }

  if (!config.useFirebase) {
    error('Firebase is not enabled for this project.');
    return;
  }

  final firebase = FirebaseService(config);
  if (await firebase.deployStorage()) {
    success('Storage rules deployed successfully');
  } else {
    error('Storage deployment failed');
  }
}

/// Deploy to Firebase Hosting (release)
Future<void> handleDeployHosting() async {
  final config = await _loadConfig();
  if (config == null) {
    error('No configuration found. Run "oracular create" first.');
    return;
  }

  if (!config.useFirebase) {
    error('Firebase is not enabled for this project.');
    return;
  }

  final firebase = FirebaseService(config);

  // Build first
  if (!await firebase.buildWeb()) {
    error('Web build failed');
    return;
  }

  if (await firebase.deployHostingRelease()) {
    success('Hosting deployed successfully');
  } else {
    error('Hosting deployment failed');
  }
}

/// Deploy to Firebase Hosting (beta)
Future<void> handleDeployHostingBeta() async {
  final config = await _loadConfig();
  if (config == null) {
    error('No configuration found. Run "oracular create" first.');
    return;
  }

  if (!config.useFirebase) {
    error('Firebase is not enabled for this project.');
    return;
  }

  final firebase = FirebaseService(config);

  // Build first
  if (!await firebase.buildWeb()) {
    error('Web build failed');
    return;
  }

  if (await firebase.deployHostingBeta()) {
    success('Beta hosting deployed successfully');
  } else {
    error('Beta hosting deployment failed');
  }
}

/// Deploy all Firebase resources
Future<void> handleDeployAll() async {
  final config = await _loadConfig();
  if (config == null) {
    error('No configuration found. Run "oracular create" first.');
    return;
  }

  if (!config.useFirebase) {
    error('Firebase is not enabled for this project.');
    return;
  }

  final firebase = FirebaseService(config);
  if (await firebase.deployAll()) {
    success('All Firebase resources deployed');
  } else {
    error('Some deployments failed');
  }
}

/// Setup Firebase for a new project
Future<void> handleFirebaseSetup() async {
  final config = await _loadConfig();
  if (config == null) {
    error('No configuration found. Run "oracular create" first.');
    return;
  }

  if (!config.useFirebase || config.firebaseProjectId == null) {
    error('Firebase is not enabled or project ID not set.');
    return;
  }

  final firebase = FirebaseService(config);
  final configGen = ConfigGenerator(config);

  // Step 1: Login to Firebase
  info('Step 1: Firebase Login');
  if (!await firebase.login()) {
    warn('Firebase login may have failed. Continue anyway? [y/N]');
    if (!await UserPrompt.askYesNo('Continue?', defaultValue: false)) {
      return;
    }
  }

  // Step 2: Login to gcloud (for Cloud Run)
  if (config.setupCloudRun) {
    info('Step 2: Google Cloud Login');
    if (!await firebase.gcloudLogin()) {
      warn('gcloud login may have failed');
    }
  }

  // Step 3: Configure FlutterFire
  info('Step 3: FlutterFire Configuration');
  if (!await firebase.configureFlutterFire()) {
    error('FlutterFire configuration failed');
    return;
  }

  // Step 4: Generate configuration files
  info('Step 4: Generating configuration files');
  await configGen.generateAll();

  // Step 5: Enable Google APIs if Cloud Run is enabled
  if (config.setupCloudRun) {
    info('Step 5: Enabling Google Cloud APIs');
    await firebase.enableGoogleApis();
  }

  success('Firebase setup complete!');
  print('');
  print('Next steps:');
  print('  1. Review generated rules in config/');
  print('  2. Deploy with: oracular deploy all');
}

/// Generate Firebase configuration files
Future<void> handleGenerateConfigs() async {
  final config = await _loadConfig();
  if (config == null) {
    error('No configuration found. Run "oracular create" first.');
    return;
  }

  final configGen = ConfigGenerator(config);
  await configGen.generateAll();
}

/// Setup server for deployment
Future<void> handleServerSetup() async {
  final config = await _loadConfig();
  if (config == null) {
    error('No configuration found. Run "oracular create" first.');
    return;
  }

  if (!config.createServer) {
    error('Server is not enabled for this project.');
    return;
  }

  final server = ServerSetup(config);
  await server.generateAll();
}

/// Build server Docker image
Future<void> handleServerBuild() async {
  final config = await _loadConfig();
  if (config == null) {
    error('No configuration found. Run "oracular create" first.');
    return;
  }

  if (!config.createServer) {
    error('Server is not enabled for this project.');
    return;
  }

  final server = ServerSetup(config);
  if (await server.buildDockerImage()) {
    success('Server Docker image built successfully');
  } else {
    error('Docker build failed');
  }
}
