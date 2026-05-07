import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../../models/setup_config.dart';
import '../../services/config_generator.dart';
import '../../services/firebase_service.dart';
import '../../services/server_setup.dart';
import '../../utils/project_config_loader.dart';
import '../../utils/setup_guidance.dart';
import '../../utils/user_prompt.dart';

void _printFirebaseDisabledHelp(SetupConfig config) {
  error('Firebase is not enabled for this project.');
  print('');
  UserPrompt.printList(<String>[
    'Edit ${p.join(config.outputDir, 'config', 'setup_config.env')} and set:',
    '  USE_FIREBASE=yes',
    '  FIREBASE_PROJECT_ID=<your-project-id>',
    'Then run: oracular deploy firebase-setup',
    SetupGuidance.linkLine(
      'Firebase console',
      'https://console.firebase.google.com',
    ),
  ]);
}

/// Deploy Firestore rules and indexes
Future<void> handleDeployFirestore() async {
  final config = await ProjectConfigLoader.load();
  if (config == null) {
    ProjectConfigLoader.printMissingConfigHelp();
    return;
  }

  if (!config.useFirebase) {
    _printFirebaseDisabledHelp(config);
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
  final config = await ProjectConfigLoader.load();
  if (config == null) {
    ProjectConfigLoader.printMissingConfigHelp();
    return;
  }

  if (!config.useFirebase) {
    _printFirebaseDisabledHelp(config);
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
  final config = await ProjectConfigLoader.load();
  if (config == null) {
    ProjectConfigLoader.printMissingConfigHelp();
    return;
  }

  if (!config.useFirebase) {
    _printFirebaseDisabledHelp(config);
    return;
  }

  if (!SetupGuidance.supportsWebHosting(config)) {
    error('This project is not configured for web hosting.');
    print('');
    UserPrompt.printList(<String>[
      'To add web support:',
      '  cd ${SetupGuidance.mainProjectPath(config)}',
      '  flutter create --platforms=web .',
      'Then retry: oracular deploy hosting',
      SetupGuidance.linkLine(
        'Flutter web deployment docs',
        'https://docs.flutter.dev/deployment/web',
      ),
    ]);
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
    SetupGuidance.printHostingSuccess(config, beta: false);
  } else {
    error('Hosting deployment failed');
  }
}

/// Deploy to Firebase Hosting (beta)
Future<void> handleDeployHostingBeta() async {
  final config = await ProjectConfigLoader.load();
  if (config == null) {
    ProjectConfigLoader.printMissingConfigHelp();
    return;
  }

  if (!config.useFirebase) {
    _printFirebaseDisabledHelp(config);
    return;
  }

  if (!SetupGuidance.supportsWebHosting(config)) {
    error('This project is not configured for web hosting.');
    print('');
    UserPrompt.printList(<String>[
      'To add web support:',
      '  cd ${SetupGuidance.mainProjectPath(config)}',
      '  flutter create --platforms=web .',
      'Then retry: oracular deploy hosting-beta',
      SetupGuidance.linkLine(
        'Flutter web deployment docs',
        'https://docs.flutter.dev/deployment/web',
      ),
    ]);
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
    SetupGuidance.printHostingSuccess(config, beta: true);
  } else {
    error('Beta hosting deployment failed');
    if (config.firebaseProjectId != null) {
      SetupGuidance.printBetaSiteHint(config.firebaseProjectId!);
    }
  }
}

/// Deploy all Firebase resources
Future<void> handleDeployAll() async {
  final config = await ProjectConfigLoader.load();
  if (config == null) {
    ProjectConfigLoader.printMissingConfigHelp();
    return;
  }

  if (!config.useFirebase) {
    _printFirebaseDisabledHelp(config);
    return;
  }

  final firebase = FirebaseService(config);
  if (await firebase.deployAll()) {
    success('All Firebase resources deployed');
    if (config.firebaseProjectId != null &&
        SetupGuidance.supportsWebHosting(config)) {
      SetupGuidance.printHostingSuccess(config, beta: false);
    }
  } else {
    error('Some deployments failed');
  }
}

/// Setup Firebase for a new project
Future<void> handleFirebaseSetup() async {
  final config = await ProjectConfigLoader.load();
  if (config == null) {
    ProjectConfigLoader.printMissingConfigHelp();
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
  UserPrompt.printNumberedList(<String>[
    'Review generated rules in ${p.join(config.outputDir, 'config')}',
    'Run: oracular deploy all',
    if (SetupGuidance.supportsWebHosting(config))
      'Run: oracular deploy hosting',
    if (SetupGuidance.supportsWebHosting(config))
      'Run: oracular deploy hosting-beta',
  ]);

  if (config.firebaseProjectId != null) {
    print('');
    print('Helpful links:');
    UserPrompt.printList(<String>[
      SetupGuidance.linkLine(
        'Firebase project overview',
        SetupGuidance.firebaseOverviewUrl(config.firebaseProjectId!),
      ),
      SetupGuidance.linkLine(
        'Hosting console',
        SetupGuidance.firebaseHostingConsoleUrl(config.firebaseProjectId!),
      ),
      SetupGuidance.linkLine(
        'Firebase Hosting docs',
        'https://firebase.google.com/docs/hosting',
      ),
    ]);
  }
}

/// Generate Firebase configuration files
Future<void> handleGenerateConfigs() async {
  final config = await ProjectConfigLoader.load();
  if (config == null) {
    ProjectConfigLoader.printMissingConfigHelp();
    return;
  }

  final configGen = ConfigGenerator(config);
  await configGen.generateAll();
}

/// Setup server for deployment
Future<void> handleServerSetup() async {
  final config = await ProjectConfigLoader.load();
  if (config == null) {
    ProjectConfigLoader.printMissingConfigHelp();
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
  final config = await ProjectConfigLoader.load();
  if (config == null) {
    ProjectConfigLoader.printMissingConfigHelp();
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
