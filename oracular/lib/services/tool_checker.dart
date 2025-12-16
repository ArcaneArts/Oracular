import 'dart:io';

import '../models/tool_status.dart';
import '../utils/process_runner.dart' show ProcessResult, ProcessRunner;
import '../utils/user_prompt.dart';

/// Service for checking CLI tool availability
class ToolChecker {
  final ProcessRunner _runner;

  ToolChecker({ProcessRunner? runner}) : _runner = runner ?? ProcessRunner();

  /// Check if Flutter is installed and get version
  Future<ToolStatus> checkFlutter() async {
    final bool exists = await _runner.commandExists('flutter');
    if (!exists) {
      return ToolStatus.missing(
        'Flutter',
        'https://docs.flutter.dev/get-started/install',
        isRequired: true,
      );
    }

    final String? version = await _runner.getCommandVersion('flutter');
    return ToolStatus.installed(
      'Flutter',
      version ?? 'unknown',
      isRequired: true,
    );
  }

  /// Check if Dart is installed and get version
  Future<ToolStatus> checkDart() async {
    final bool exists = await _runner.commandExists('dart');
    if (!exists) {
      return ToolStatus.missing(
        'Dart',
        'Installed with Flutter, run: flutter doctor',
        isRequired: true,
      );
    }

    final String? version = await _runner.getCommandVersion('dart');
    return ToolStatus.installed('Dart', version ?? 'unknown', isRequired: true);
  }

  /// Check if Firebase CLI is installed
  Future<ToolStatus> checkFirebase() async {
    final bool exists = await _runner.commandExists('firebase');
    if (!exists) {
      return ToolStatus.missing(
        'Firebase CLI',
        'npm install -g firebase-tools',
        isRequired: false,
      );
    }

    final String? version = await _runner.getCommandVersion('firebase');
    return ToolStatus.installed(
      'Firebase CLI',
      version ?? 'unknown',
      isRequired: false,
    );
  }

  /// Check if FlutterFire CLI is installed
  Future<ToolStatus> checkFlutterFire() async {
    final bool exists = await _runner.commandExists('flutterfire');
    if (!exists) {
      return ToolStatus.missing(
        'FlutterFire CLI',
        'dart pub global activate flutterfire_cli',
        isRequired: false,
      );
    }

    final String? version = await _runner.getCommandVersion('flutterfire');
    return ToolStatus.installed(
      'FlutterFire CLI',
      version ?? 'unknown',
      isRequired: false,
    );
  }

  /// Check if gcloud is installed
  Future<ToolStatus> checkGcloud() async {
    final bool exists = await _runner.commandExists('gcloud');
    if (!exists) {
      return ToolStatus.missing(
        'Google Cloud SDK',
        'https://cloud.google.com/sdk/docs/install',
        isRequired: false,
      );
    }

    final String? version = await _runner.getCommandVersion(
      'gcloud',
      versionArgs: <String>['--version'],
    );
    // Extract just the first line with version info
    final String versionLine = version?.split('\n').first ?? 'unknown';
    return ToolStatus.installed(
      'Google Cloud SDK',
      versionLine,
      isRequired: false,
    );
  }

  /// Check if Docker is installed
  Future<ToolStatus> checkDocker() async {
    final bool exists = await _runner.commandExists('docker');
    if (!exists) {
      return ToolStatus.missing(
        'Docker',
        'https://docs.docker.com/get-docker/',
        isRequired: false,
      );
    }

    final String? version = await _runner.getCommandVersion('docker');
    return ToolStatus.installed(
      'Docker',
      version ?? 'unknown',
      isRequired: false,
    );
  }

  /// Check if npm is installed (needed for Firebase CLI)
  Future<ToolStatus> checkNpm() async {
    final bool exists = await _runner.commandExists('npm');
    if (!exists) {
      return ToolStatus.missing(
        'npm',
        'https://nodejs.org/',
        isRequired: false,
      );
    }

    final String? version = await _runner.getCommandVersion('npm');
    return ToolStatus.installed('npm', version ?? 'unknown', isRequired: false);
  }

  /// Check if CocoaPods is installed (macOS only)
  Future<ToolStatus> checkCocoaPods() async {
    if (!Platform.isMacOS) {
      return ToolStatus(
        name: 'CocoaPods',
        isInstalled: true,
        version: 'N/A (not macOS)',
        isRequired: false,
      );
    }

    final bool exists = await _runner.commandExists('pod');
    if (!exists) {
      return ToolStatus.missing(
        'CocoaPods',
        'brew install cocoapods',
        isRequired: false,
      );
    }

    final String? version = await _runner.getCommandVersion('pod');
    return ToolStatus.installed(
      'CocoaPods',
      version ?? 'unknown',
      isRequired: false,
    );
  }

  /// Check if Homebrew is installed (macOS only)
  Future<ToolStatus> checkHomebrew() async {
    if (!Platform.isMacOS) {
      return ToolStatus(
        name: 'Homebrew',
        isInstalled: true,
        version: 'N/A (not macOS)',
        isRequired: false,
      );
    }

    final bool exists = await _runner.commandExists('brew');
    if (!exists) {
      return ToolStatus.missing(
        'Homebrew',
        '/bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"',
        isRequired: false,
      );
    }

    final String? version = await _runner.getCommandVersion('brew');
    return ToolStatus.installed(
      'Homebrew',
      version ?? 'unknown',
      isRequired: false,
    );
  }

  /// Check all required tools with spinner
  Future<ToolCheckResult> checkRequired() async {
    return await UserPrompt.withSpinner(
      'Checking required tools...',
      () async {
        final List<ToolStatus> tools = await Future.wait(<Future<ToolStatus>>[checkFlutter(), checkDart()]);
        return ToolCheckResult(tools: tools);
      },
      doneMessage: '✓ Tool check complete',
    );
  }

  /// Check all tools (required and optional) with progress
  Future<ToolCheckResult> checkAll() async {
    final List<(String, Future<ToolStatus> Function())> toolCheckers = <(String, Future<ToolStatus> Function())>[
      ('Flutter', checkFlutter),
      ('Dart', checkDart),
      ('Firebase CLI', checkFirebase),
      ('FlutterFire CLI', checkFlutterFire),
      ('Google Cloud SDK', checkGcloud),
      ('Docker', checkDocker),
      ('npm', checkNpm),
      ('CocoaPods', checkCocoaPods),
      ('Homebrew', checkHomebrew),
    ];

    final List<ToolStatus> tools = <ToolStatus>[];

    // Show progress for each tool check
    for (int i = 0; i < toolCheckers.length; i++) {
      final (String name, Future<ToolStatus> Function() checker) = toolCheckers[i];
      UserPrompt.showProgress(i, toolCheckers.length, 'Checking $name...');
      tools.add(await checker());
    }
    UserPrompt.showProgress(
      toolCheckers.length,
      toolCheckers.length,
      'All tools checked!',
    );

    return ToolCheckResult(tools: tools);
  }

  /// Check tools needed for Firebase with spinner
  Future<ToolCheckResult> checkFirebaseTools() async {
    return await UserPrompt.withSpinner(
      'Checking Firebase tools...',
      () async {
        final List<ToolStatus> tools = await Future.wait(<Future<ToolStatus>>[
          checkFirebase(),
          checkFlutterFire(),
          checkNpm(),
        ]);
        return ToolCheckResult(tools: tools);
      },
      doneMessage: '✓ Firebase tools checked',
    );
  }

  /// Check tools needed for server deployment with spinner
  Future<ToolCheckResult> checkServerTools() async {
    return await UserPrompt.withSpinner(
      'Checking server deployment tools...',
      () async {
        final List<ToolStatus> tools = await Future.wait(<Future<ToolStatus>>[checkDocker(), checkGcloud()]);
        return ToolCheckResult(tools: tools);
      },
      doneMessage: '✓ Server tools checked',
    );
  }

  /// Run flutter doctor with spinner and return the output
  Future<String> runFlutterDoctor() async {
    return await UserPrompt.withSpinner(
      'Running flutter doctor (this may take a moment)...',
      () async {
        final ProcessResult result = await _runner.run('flutter', <String>['doctor', '-v']);
        return result.stdout;
      },
      doneMessage: '✓ Flutter doctor complete',
    );
  }
}
