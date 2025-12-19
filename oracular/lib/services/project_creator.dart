import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../models/setup_config.dart';
import '../models/template_info.dart';
import '../utils/process_runner.dart' show ProcessResult, ProcessRunner;

/// Service for creating Flutter/Dart projects
class ProjectCreator {
  final SetupConfig config;
  final ProcessRunner _runner;

  ProjectCreator(this.config, {ProcessRunner? runner})
    : _runner = runner ?? ProcessRunner();

  /// Create a Flutter app project
  Future<bool> createFlutterApp() async {
    if (!config.template.isFlutterApp) {
      return false;
    }

    final String projectPath = p.join(config.outputDir, config.appName);

    info('Creating Flutter app: ${config.appName}');

    // Build flutter create command
    final List<String> args = <String>[
      'create',
      '--org',
      config.orgDomain,
      '--project-name',
      config.appName,
    ];

    // Add platforms from config (user may have selected subset)
    if (config.platforms.isNotEmpty) {
      args.addAll(<String>['--platforms', config.platforms.join(',')]);
    }

    // Add the project path
    args.add(projectPath);

    final ProcessResult? result = await _runner.runWithRetry(
      'flutter',
      args,
      operationName: 'Flutter create',
    );

    if (result == null || !result.success) {
      error('Failed to create Flutter app');
      return false;
    }

    success('Flutter app created at: $projectPath');
    return true;
  }

  /// Create a Dart CLI project
  Future<bool> createDartCli() async {
    if (config.template != TemplateType.arcaneCli) {
      return false;
    }

    final String projectPath = p.join(config.outputDir, config.appName);

    info('Creating Dart CLI: ${config.appName}');

    // Use dart create for CLI projects
    final List<String> args = <String>['create', '-t', 'console', projectPath];

    final ProcessResult? result = await _runner.runWithRetry(
      'dart',
      args,
      operationName: 'Dart create',
    );

    if (result == null || !result.success) {
      error('Failed to create Dart CLI');
      return false;
    }

    // dart create generates default files that we'll replace with our template
    // Delete the generated lib and bin folders to replace with template
    final Directory libDir = Directory(p.join(projectPath, 'lib'));
    final Directory binDir = Directory(p.join(projectPath, 'bin'));

    if (libDir.existsSync()) {
      await libDir.delete(recursive: true);
    }
    if (binDir.existsSync()) {
      await binDir.delete(recursive: true);
    }

    success('Dart CLI created at: $projectPath');
    return true;
  }

  /// Create a models package
  Future<bool> createModelsPackage() async {
    if (!config.createModels) {
      return false;
    }

    final String projectPath = p.join(config.outputDir, config.modelsPackageName);

    info('Creating models package: ${config.modelsPackageName}');

    // Use flutter create -t package for models
    final List<String> args = <String>[
      'create',
      '-t',
      'package',
      '--project-name',
      config.modelsPackageName,
      projectPath,
    ];

    final result = await _runner.runWithRetry(
      'flutter',
      args,
      operationName: 'Create models package',
    );

    if (result == null || !result.success) {
      error('Failed to create models package');
      return false;
    }

    // Delete the generated lib folder to replace with template
    final libDir = Directory(p.join(projectPath, 'lib'));
    if (libDir.existsSync()) {
      await libDir.delete(recursive: true);
    }

    success('Models package created at: $projectPath');
    return true;
  }

  /// Create a server app
  Future<bool> createServerApp() async {
    if (!config.createServer) {
      return false;
    }

    final projectPath = p.join(config.outputDir, config.serverPackageName);

    info('Creating server app: ${config.serverPackageName}');

    // Use flutter create with linux only for server
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

    final result = await _runner.runWithRetry(
      'flutter',
      args,
      operationName: 'Create server app',
    );

    if (result == null || !result.success) {
      error('Failed to create server app');
      return false;
    }

    // Delete the generated lib folder to replace with template
    final libDir = Directory(p.join(projectPath, 'lib'));
    if (libDir.existsSync()) {
      await libDir.delete(recursive: true);
    }

    success('Server app created at: $projectPath');
    return true;
  }

  /// Create all projects based on config
  Future<bool> createAllProjects() async {
    info('Creating projects...');

    // Create main app based on template type
    if (config.template.isFlutterApp) {
      if (!await createFlutterApp()) {
        return false;
      }
    } else if (config.template.isDartCli) {
      if (!await createDartCli()) {
        return false;
      }
    }

    // Create models package if enabled
    if (config.createModels) {
      if (!await createModelsPackage()) {
        return false;
      }
    }

    // Create server app if enabled
    if (config.createServer) {
      if (!await createServerApp()) {
        return false;
      }
    }

    success('All projects created successfully!');
    return true;
  }

  /// Delete test folders from created projects
  Future<void> deleteTestFolders() async {
    info('Cleaning up test folders...');

    final projectPaths = [
      p.join(config.outputDir, config.appName),
      if (config.createModels)
        p.join(config.outputDir, config.modelsPackageName),
      if (config.createServer)
        p.join(config.outputDir, config.serverPackageName),
    ];

    for (final projectPath in projectPaths) {
      final testDir = Directory(p.join(projectPath, 'test'));
      if (testDir.existsSync()) {
        await testDir.delete(recursive: true);
        verbose('  Deleted test folder in: ${p.basename(projectPath)}');
      }
    }
  }
}
