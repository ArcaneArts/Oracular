import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../models/setup_config.dart';
import '../models/template_info.dart';
import '../utils/process_runner.dart' show ProcessResult, ProcessRunner;
import '../utils/user_prompt.dart';

/// Service for managing project dependencies
class DependencyManager {
  final SetupConfig config;
  final ProcessRunner _runner;

  DependencyManager(this.config, {ProcessRunner? runner})
    : _runner = runner ?? ProcessRunner();

  /// Run flutter pub get in a project
  Future<bool> flutterPubGet(String projectPath) async {
    info('Getting dependencies for: ${p.basename(projectPath)}');

    final ProcessResult? result = await _runner.runWithRetry(
      'flutter',
      <String>['pub', 'get'],
      workingDirectory: projectPath,
      operationName: 'flutter pub get (${p.basename(projectPath)})',
    );

    return result != null && result.success;
  }

  /// Run dart pub get in a project
  Future<bool> dartPubGet(String projectPath) async {
    info('Getting dependencies for: ${p.basename(projectPath)}');

    final ProcessResult? result = await _runner.runWithRetry(
      'dart',
      <String>['pub', 'get'],
      workingDirectory: projectPath,
      operationName: 'dart pub get (${p.basename(projectPath)})',
    );

    return result != null && result.success;
  }

  /// Add a dependency to a project using flutter pub add
  Future<bool> addDependency(
    String projectPath,
    String package, {
    bool isDev = false,
  }) async {
    info('Adding dependency: $package to ${p.basename(projectPath)}');

    final List<String> args = <String>['pub', 'add'];
    if (isDev) {
      args.add('--dev');
    }
    args.add(package);

    final ProcessResult? result = await _runner.runWithRetry(
      'flutter',
      args,
      workingDirectory: projectPath,
      operationName: 'flutter pub add $package',
    );

    return result != null && result.success;
  }

  /// Add multiple dependencies to a project
  Future<bool> addDependencies(
    String projectPath,
    List<String> packages, {
    bool isDev = false,
  }) async {
    for (final String package in packages) {
      if (!await addDependency(projectPath, package, isDev: isDev)) {
        warn('Failed to add: $package');
        // Continue with other packages
      }
    }
    return true;
  }

  /// Get dependencies for the main app
  Future<bool> getAppDependencies() async {
    final String projectPath = p.join(config.outputDir, config.appName);

    if (config.template == TemplateType.arcaneCli) {
      return await dartPubGet(projectPath);
    } else {
      return await flutterPubGet(projectPath);
    }
  }

  /// Get dependencies for the models package
  Future<bool> getModelsDependencies() async {
    if (!config.createModels) return true;

    final String projectPath = p.join(config.outputDir, config.modelsPackageName);
    return await dartPubGet(projectPath);
  }

  /// Get dependencies for the server app
  Future<bool> getServerDependencies() async {
    if (!config.createServer) return true;

    final String projectPath = p.join(config.outputDir, config.serverPackageName);
    return await flutterPubGet(projectPath);
  }

  /// Get dependencies for all projects with progress tracking
  Future<bool> getAllDependencies() async {
    // Build list of packages to process
    final List<(String, Future<bool> Function())> packages = <(String, Future<bool> Function())>[];

    if (config.createModels) {
      packages.add(('Models', getModelsDependencies));
    }
    packages.add(('Main app', getAppDependencies));
    if (config.createServer) {
      packages.add(('Server', getServerDependencies));
    }

    // Process each package with progress
    for (int i = 0; i < packages.length; i++) {
      final (name, getter) = packages[i];
      UserPrompt.showProgress(i, packages.length, 'Getting $name dependencies...');
      if (!await getter()) {
        warn('Failed to get $name dependencies');
      }
    }
    UserPrompt.showProgress(packages.length, packages.length, 'All dependencies retrieved');

    return true;
  }

  /// Run build_runner in a project
  Future<bool> runBuildRunner(String projectPath) async {
    info('Running build_runner in: ${p.basename(projectPath)}');

    final ProcessResult? result = await _runner.runWithRetry(
      'dart',
      <String>['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
      workingDirectory: projectPath,
      operationName: 'build_runner (${p.basename(projectPath)})',
    );

    return result != null && result.success;
  }

  /// Run build_runner for all projects that need it with progress
  Future<bool> runAllBuildRunners() async {
    // Build list of projects needing build_runner
    final List<(String, String)> projects = <(String, String)>[];

    // Models package needs build_runner for serialization
    if (config.createModels) {
      projects.add(('Models', p.join(config.outputDir, config.modelsPackageName)));
    }

    // CLI apps need build_runner for cli_gen
    if (config.template == TemplateType.arcaneCli) {
      projects.add(('CLI app', p.join(config.outputDir, config.appName)));
    }

    if (projects.isEmpty) {
      return true;
    }

    // Run build_runner for each project with progress
    for (int i = 0; i < projects.length; i++) {
      final (name, path) = projects[i];
      UserPrompt.showProgress(i, projects.length, 'Running build_runner for $name...');
      if (!await runBuildRunner(path)) {
        warn('Failed to run build_runner for $name');
      }
    }
    UserPrompt.showProgress(projects.length, projects.length, 'Code generation complete');

    return true;
  }

  /// Link models package to other projects by adding path dependency
  Future<void> linkModelsToProjects() async {
    if (!config.createModels) return;

    info('Linking models package to other projects...');

    final String modelsPath = '../${config.modelsPackageName}';

    // Link to main app
    final File appPubspec = File(
      p.join(config.outputDir, config.appName, 'pubspec.yaml'),
    );
    await _addPathDependency(appPubspec, config.modelsPackageName, modelsPath);

    // Link to server
    if (config.createServer) {
      final File serverPubspec = File(
        p.join(config.outputDir, config.serverPackageName, 'pubspec.yaml'),
      );
      await _addPathDependency(
        serverPubspec,
        config.modelsPackageName,
        modelsPath,
      );
    }

    success('Models package linked to projects');
  }

  /// Add a path dependency to a pubspec.yaml file
  Future<void> _addPathDependency(
    File pubspecFile,
    String packageName,
    String relativePath,
  ) async {
    if (!pubspecFile.existsSync()) {
      warn('pubspec.yaml not found: ${pubspecFile.path}');
      return;
    }

    String content = await pubspecFile.readAsString();

    // Check if dependency already exists
    if (content.contains('$packageName:')) {
      verbose('  $packageName already in pubspec');
      return;
    }

    // Find dependencies: section and add after it
    final RegExpMatch? dependenciesMatch = RegExp(
      r'^dependencies:\s*$',
      multiLine: true,
    ).firstMatch(content);
    if (dependenciesMatch != null) {
      final int insertPoint = dependenciesMatch.end;
      final String dependencyLine = '\n  $packageName:\n    path: $relativePath\n';
      content =
          content.substring(0, insertPoint) +
          dependencyLine +
          content.substring(insertPoint);
      await pubspecFile.writeAsString(content);
      verbose('  Added $packageName to ${p.basename(pubspecFile.parent.path)}');
    }
  }
}
