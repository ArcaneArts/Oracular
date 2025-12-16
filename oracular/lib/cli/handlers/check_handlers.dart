import 'package:fast_log/fast_log.dart';

import '../../services/tool_checker.dart';

final _checker = ToolChecker();

/// Check all tools (required and optional)
Future<void> handleCheckTools() async {
  final result = await _checker.checkAll();
  result.printSummary();

  if (!result.allRequiredInstalled) {
    error('Some required tools are missing. Please install them before continuing.');
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
