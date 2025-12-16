import 'dart:async';
import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../models/wizard_config.dart';

/// Log entry for the creation process
class LogEntry {
  final String message;
  final LogLevel level;
  final DateTime timestamp;

  LogEntry(this.message, this.level) : timestamp = DateTime.now();
}

enum LogLevel { info, success, warning, error, verbose }

/// Service for creating projects
class ProjectService {
  /// Stream controller for log messages
  final _logController = StreamController<LogEntry>.broadcast();

  /// Get the log stream
  Stream<LogEntry> get logStream => _logController.stream;

  /// Current progress (0-100)
  double progress = 0;

  /// Whether the process is running
  bool isRunning = false;

  /// Progress change notifier
  final _progressController = StreamController<double>.broadcast();
  Stream<double> get progressStream => _progressController.stream;

  /// Log a message
  void _log(String message, LogLevel level) {
    _logController.add(LogEntry(message, level));
    switch (level) {
      case LogLevel.info:
        info(message);
        break;
      case LogLevel.success:
        success(message);
        break;
      case LogLevel.warning:
        warn(message);
        break;
      case LogLevel.error:
        error(message);
        break;
      case LogLevel.verbose:
        verbose(message);
        break;
    }
  }

  void _setProgress(double value) {
    progress = value;
    _progressController.add(value);
  }

  /// Run a command and return success/failure
  Future<bool> _runCommand(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    String? operationName,
  }) async {
    final opName = operationName ?? '$executable ${arguments.join(' ')}';
    _log('Running: $opName', LogLevel.verbose);

    try {
      final result = await Process.run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        runInShell: Platform.isWindows,
      );

      if (result.exitCode == 0) {
        return true;
      } else {
        _log('$opName failed: ${result.stderr}', LogLevel.warning);
        return false;
      }
    } catch (e) {
      _log('$opName error: $e', LogLevel.error);
      return false;
    }
  }

  /// Create all projects based on configuration
  Future<bool> createProject(WizardConfig config) async {
    isRunning = true;
    _setProgress(0);

    try {
      // Step 1: Create main app (20%)
      _log('Creating main application...', LogLevel.info);
      if (!await _createMainApp(config)) {
        _log('Failed to create main application', LogLevel.error);
        return false;
      }
      _setProgress(20);

      // Step 2: Create models package if enabled (35%)
      if (config.createModels) {
        _log('Creating models package...', LogLevel.info);
        if (!await _createModelsPackage(config)) {
          _log('Failed to create models package', LogLevel.warning);
        }
      }
      _setProgress(35);

      // Step 3: Create server if enabled (50%)
      if (config.createServer) {
        _log('Creating server application...', LogLevel.info);
        if (!await _createServerApp(config)) {
          _log('Failed to create server application', LogLevel.warning);
        }
      }
      _setProgress(50);

      // Step 4: Copy template files (65%)
      _log('Copying template files...', LogLevel.info);
      await _copyTemplateFiles(config);
      _setProgress(65);

      // Step 5: Link models if created (70%)
      if (config.createModels) {
        _log('Linking models package...', LogLevel.info);
        await _linkModelsToProjects(config);
      }
      _setProgress(70);

      // Step 6: Get dependencies (85%)
      _log('Installing dependencies...', LogLevel.info);
      await _getDependencies(config);
      _setProgress(85);

      // Step 7: Run build_runner (95%)
      _log('Running code generation...', LogLevel.info);
      await _runBuildRunners(config);
      _setProgress(95);

      // Step 8: Save configuration (100%)
      _log('Saving configuration...', LogLevel.info);
      await _saveConfiguration(config);
      _setProgress(100);

      _log('Project created successfully!', LogLevel.success);
      return true;
    } catch (e) {
      _log('Error creating project: $e', LogLevel.error);
      return false;
    } finally {
      isRunning = false;
    }
  }

  Future<bool> _createMainApp(WizardConfig config) async {
    final projectPath = p.join(config.outputDir, config.appName);

    if (config.template.isFlutter) {
      final args = [
        'create',
        '--org',
        config.orgDomain,
        '--project-name',
        config.appName,
      ];

      // Use selected platforms (user may have deselected some)
      if (config.selectedPlatforms.isNotEmpty) {
        args.addAll(['--platforms', config.selectedPlatforms.join(',')]);
      }

      args.add(projectPath);

      return await _runCommand('flutter', args, operationName: 'Flutter create');
    } else {
      // Dart CLI
      final args = ['create', '-t', 'console', projectPath];
      return await _runCommand('dart', args, operationName: 'Dart create');
    }
  }

  Future<bool> _createModelsPackage(WizardConfig config) async {
    final projectPath = p.join(config.outputDir, config.modelsPackageName);
    final args = [
      'create',
      '-t',
      'package',
      '--project-name',
      config.modelsPackageName,
      projectPath,
    ];
    return await _runCommand('flutter', args, operationName: 'Create models package');
  }

  Future<bool> _createServerApp(WizardConfig config) async {
    final projectPath = p.join(config.outputDir, config.serverPackageName);
    final args = [
      'create',
      '--org',
      config.orgDomain,
      '--project-name',
      config.serverPackageName,
      '--platforms',
      'linux',
      projectPath,
    ];
    return await _runCommand('flutter', args, operationName: 'Create server app');
  }

  Future<void> _copyTemplateFiles(WizardConfig config) async {
    _log('Template copying would happen here (delegated to CLI)', LogLevel.verbose);
  }

  Future<void> _linkModelsToProjects(WizardConfig config) async {
    if (!config.createModels) return;

    final modelsPath = '../${config.modelsPackageName}';

    // Link to main app
    final appPubspec = File(p.join(config.outputDir, config.appName, 'pubspec.yaml'));
    await _addPathDependency(appPubspec, config.modelsPackageName, modelsPath);

    // Link to server
    if (config.createServer) {
      final serverPubspec = File(
        p.join(config.outputDir, config.serverPackageName, 'pubspec.yaml'),
      );
      await _addPathDependency(serverPubspec, config.modelsPackageName, modelsPath);
    }
  }

  Future<void> _addPathDependency(
    File pubspecFile,
    String packageName,
    String relativePath,
  ) async {
    if (!pubspecFile.existsSync()) return;

    var content = await pubspecFile.readAsString();
    if (content.contains('$packageName:')) return;

    final dependenciesMatch =
        RegExp(r'^dependencies:\s*$', multiLine: true).firstMatch(content);
    if (dependenciesMatch != null) {
      final insertPoint = dependenciesMatch.end;
      final dependencyLine = '\n  $packageName:\n    path: $relativePath\n';
      content = content.substring(0, insertPoint) +
          dependencyLine +
          content.substring(insertPoint);
      await pubspecFile.writeAsString(content);
    }
  }

  Future<void> _getDependencies(WizardConfig config) async {
    // Models first
    if (config.createModels) {
      final modelsPath = p.join(config.outputDir, config.modelsPackageName);
      await _runCommand('dart', ['pub', 'get'],
          workingDirectory: modelsPath, operationName: 'dart pub get (models)');
    }

    // Main app
    final appPath = p.join(config.outputDir, config.appName);
    if (config.template.isFlutter) {
      await _runCommand('flutter', ['pub', 'get'],
          workingDirectory: appPath, operationName: 'flutter pub get (app)');
    } else {
      await _runCommand('dart', ['pub', 'get'],
          workingDirectory: appPath, operationName: 'dart pub get (app)');
    }

    // Server
    if (config.createServer) {
      final serverPath = p.join(config.outputDir, config.serverPackageName);
      await _runCommand('flutter', ['pub', 'get'],
          workingDirectory: serverPath, operationName: 'flutter pub get (server)');
    }
  }

  Future<void> _runBuildRunners(WizardConfig config) async {
    final buildRunnerArgs = ['run', 'build_runner', 'build', '--delete-conflicting-outputs'];

    // Models
    if (config.createModels) {
      final modelsPath = p.join(config.outputDir, config.modelsPackageName);
      await _runCommand('dart', buildRunnerArgs,
          workingDirectory: modelsPath, operationName: 'build_runner (models)');
    }

    // CLI apps
    if (config.template.isDartCli) {
      final appPath = p.join(config.outputDir, config.appName);
      await _runCommand('dart', buildRunnerArgs,
          workingDirectory: appPath, operationName: 'build_runner (cli)');
    }
  }

  Future<void> _saveConfiguration(WizardConfig config) async {
    final configDir = Directory(p.join(config.outputDir, 'config'));
    if (!configDir.existsSync()) {
      await configDir.create(recursive: true);
    }

    final configContent = '''
# Oracular Setup Configuration
# Generated: ${DateTime.now().toIso8601String()}

APP_NAME=${config.appName}
ORG_DOMAIN=${config.orgDomain}
BASE_CLASS_NAME=${config.baseClassName}
TEMPLATE_NAME=${config.template.name}
OUTPUT_DIR=${config.outputDir}
PLATFORMS=${config.selectedPlatforms.join(',')}
CREATE_MODELS=${config.createModels ? 'yes' : 'no'}
CREATE_SERVER=${config.createServer ? 'yes' : 'no'}
USE_FIREBASE=${config.useFirebase ? 'yes' : 'no'}
${config.firebaseProjectId != null ? 'FIREBASE_PROJECT_ID=${config.firebaseProjectId}' : '# FIREBASE_PROJECT_ID='}
SETUP_CLOUD_RUN=${config.setupCloudRun ? 'yes' : 'no'}
''';

    await File(p.join(configDir.path, 'setup_config.env')).writeAsString(configContent);
  }

  /// Dispose resources
  void dispose() {
    _logController.close();
    _progressController.close();
  }
}
