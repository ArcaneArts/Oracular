import 'package:fast_log/fast_log.dart';

import '../../services/firebase_billing_service.dart';
import '../../services/tool_checker.dart';
import '../../utils/user_prompt.dart';
import 'setup_config_requirements.dart';

final _checker = ToolChecker();

/// Check all tools (required and optional)
Future<void> handleCheckTools() async {
  final result = await _checker.checkAll();
  result.printSummary();

  if (!result.allRequiredInstalled) {
    error(
      'Some required tools are missing. Please install them before continuing.',
    );
  } else {
    success('All required tools are installed!');
  }
}

/// Check Flutter installation
Future<void> handleCheckFlutter() async {
  final status = await _checker.checkFlutter();
  print('');
  print('Flutter Status:');
  print('\u2500' * 40);

  if (status.isInstalled) {
    success('Flutter is installed');
    print('Version: ${status.version}');
  } else {
    error('Flutter is not installed');
    print('Install: ${status.installInstructions}');
  }
}

/// Check Firebase CLI tools
Future<void> handleCheckFirebase() async {
  final result = await _checker.checkFirebaseTools();
  result.printSummary();
}

/// Check Docker installation
Future<void> handleCheckDocker() async {
  final status = await _checker.checkDocker();
  print('');
  print('Docker Status:');
  print('\u2500' * 40);

  if (status.isInstalled) {
    success('Docker is installed');
    print('Version: ${status.version}');
  } else {
    warn('Docker is not installed (needed for server deployment)');
    print('Install: ${status.installInstructions}');
  }
}

/// Check Google Cloud SDK
Future<void> handleCheckGcloud() async {
  final status = await _checker.checkGcloud();
  print('');
  print('Google Cloud SDK Status:');
  print('\u2500' * 40);

  if (status.isInstalled) {
    success('Google Cloud SDK is installed');
    print('Version: ${status.version}');
  } else {
    warn('Google Cloud SDK is not installed (needed for Cloud Run deployment)');
    print('Install: ${status.installInstructions}');
  }
}

/// Run flutter doctor
Future<void> handleDoctor() async {
  info('Running flutter doctor...');
  print('');

  final output = await _checker.runFlutterDoctor();
  print(output);
}

/// Check server deployment tools
Future<void> handleCheckServer() async {
  final result = await _checker.checkServerTools();
  result.printSummary();
}

/// Check Firebase billing plan (Spark vs Blaze).
///
/// Implemented in T3 (FirebaseBillingService); the orchestrator gates
/// Cloud Run / cleanup steps on the result via [BlazeStatus.enabled].
Future<void> handleCheckBilling() async {
  final config = await requireFirebaseProjectConfig();
  if (config == null) return;

  final FirebaseBillingService billing = FirebaseBillingService(
    config.firebaseProjectId!,
  );

  info('Checking billing for ${config.firebaseProjectId}...');
  final BillingCheckResult result = await billing.checkBlazeStatus();

  switch (result.status) {
    case BlazeStatus.enabled:
      success('Project is on Blaze (pay-as-you-go).');
      if (result.billingAccountName != null) {
        print('Linked account: ${result.billingAccountName}');
      }
      break;
    case BlazeStatus.notEnabled:
      warn('Project is on Spark. Cloud Run / cleanup features are gated.');
      print('');
      UserPrompt.printList(<String>[
        'Upgrade at: '
            '${FirebaseBillingService.upgradeUrl(config.firebaseProjectId!)}',
        'Spark covers Hosting, Firestore (small), Auth, Storage (small).',
        'Blaze is required for Cloud Run, Artifact Registry cleanup,',
        '  scheduled jobs, and most production workloads.',
      ]);
      break;
    case BlazeStatus.unknown:
      error(
        'Could not determine billing status: ${result.message ?? 'unknown error'}',
      );
      print('');
      UserPrompt.printList(<String>[
        'Verify gcloud is installed and authenticated: `gcloud auth login`',
        'Check the project ID in config/setup_config.env',
        'You can still continue; Blaze-gated steps will simply be skipped.',
      ]);
      break;
  }
}
