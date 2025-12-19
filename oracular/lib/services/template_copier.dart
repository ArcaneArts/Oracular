import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../models/setup_config.dart';
import '../models/template_info.dart';
import '../utils/user_prompt.dart';
import 'placeholder_replacer.dart';
import 'template_downloader.dart';

/// Service for copying and customizing templates
class TemplateCopier {
  final SetupConfig config;
  late final PlaceholderReplacer _replacer;

  /// Path to the templates directory
  final String templatesBasePath;

  /// Private constructor - use create() factory
  TemplateCopier._(this.config, this.templatesBasePath) {
    _replacer = PlaceholderReplacer(config);
  }

  /// Create a TemplateCopier with a known templates path (for testing)
  TemplateCopier.withPath(this.config, this.templatesBasePath) {
    _replacer = PlaceholderReplacer(config);
  }

  /// Create a TemplateCopier with templates ready
  /// This will download templates from GitHub if not available locally
  static Future<TemplateCopier> create(
    SetupConfig config, {
    void Function(String message)? onProgress,
  }) async {
    final String templatesPath = await _findTemplatesPath(onProgress: onProgress);
    return TemplateCopier._(config, templatesPath);
  }

  /// Find the templates directory
  /// First checks local development paths, then downloads from GitHub
  static Future<String> _findTemplatesPath({
    void Function(String message)? onProgress,
  }) async {
    // Try to find templates relative to the script (for local development)
    final String scriptPath = Platform.script.toFilePath();
    final String scriptDir = p.dirname(scriptPath);

    // Check various possible locations for local development
    final List<String> possiblePaths = <String>[
      // When running locally with dart run from oracular/ directory
      p.join(scriptDir, '..', '..', 'templates'),
      // When running from the oracular package directory
      p.join(Directory.current.path, '..', 'templates'),
      // When running from the Oracular monorepo root
      p.join(Directory.current.path, 'templates'),
    ];

    for (final String path in possiblePaths) {
      final String normalizedPath = p.normalize(path);
      if (Directory(normalizedPath).existsSync()) {
        verbose('Found local templates at: $normalizedPath');
        return normalizedPath;
      }
    }

    // No local templates found - download from GitHub
    onProgress?.call('Downloading templates from GitHub...');
    return await TemplateDownloader.ensureTemplates(onProgress: onProgress);
  }

  /// Get the path to a specific template
  String getTemplatePath(String templateName) {
    return p.join(templatesBasePath, templateName);
  }

  /// Copy the main app template to the output directory
  Future<void> copyAppTemplate() async {
    final Directory templateDir = Directory(
      getTemplatePath(config.template.directoryName),
    );

    // For Jaspr templates, use webPackageName; for others, use appName
    final String targetName =
        config.template.isJasprApp ? config.webPackageName : config.appName;
    final Directory targetDir = Directory(p.join(config.outputDir, targetName));

    if (!templateDir.existsSync()) {
      throw Exception('Template not found: ${templateDir.path}');
    }

    info('Copying ${config.template.displayName} template...');

    // Copy template files
    await _copyDirectory(templateDir, targetDir);

    // Process placeholders
    await _replacer.processDirectory(targetDir);

    // Update pubspec with correct package name
    final File pubspecFile = File(p.join(targetDir.path, 'pubspec.yaml'));
    await _replacer.updatePubspec(pubspecFile, targetName);

    // Add models dependency if needed
    if (config.createModels) {
      await _replacer.addModelsDependency(pubspecFile);
    }

    success('App template copied to: ${targetDir.path}');
  }

  /// Copy the models template
  Future<void> copyModelsTemplate() async {
    if (!config.createModels) return;

    final Directory templateDir = Directory(getTemplatePath('arcane_models'));
    final Directory targetDir = Directory(
      p.join(config.outputDir, config.modelsPackageName),
    );

    if (!templateDir.existsSync()) {
      throw Exception('Models template not found: ${templateDir.path}');
    }

    info('Copying models template...');

    // Copy template files
    await _copyDirectory(templateDir, targetDir);

    // Process placeholders
    await _replacer.processDirectory(targetDir);

    // Update pubspec
    final File pubspecFile = File(p.join(targetDir.path, 'pubspec.yaml'));
    await _replacer.updatePubspec(pubspecFile, config.modelsPackageName);

    success('Models package created at: ${targetDir.path}');
  }

  /// Copy the server template
  Future<void> copyServerTemplate() async {
    if (!config.createServer) return;

    final Directory templateDir = Directory(getTemplatePath('arcane_server'));
    final Directory targetDir = Directory(
      p.join(config.outputDir, config.serverPackageName),
    );

    if (!templateDir.existsSync()) {
      throw Exception('Server template not found: ${templateDir.path}');
    }

    info('Copying server template...');

    // Copy template files
    await _copyDirectory(templateDir, targetDir);

    // Process placeholders
    await _replacer.processDirectory(targetDir);

    // Update pubspec
    final File pubspecFile = File(p.join(targetDir.path, 'pubspec.yaml'));
    await _replacer.updatePubspec(pubspecFile, config.serverPackageName);

    // Add models dependency if needed
    if (config.createModels) {
      await _replacer.addModelsDependency(pubspecFile);
    }

    success('Server app created at: ${targetDir.path}');
  }

  /// Copy the references folder
  Future<void> copyReferences() async {
    final Directory templateDir = Directory(getTemplatePath('references'));
    final Directory targetDir = Directory(p.join(config.outputDir, 'references'));

    if (!templateDir.existsSync()) {
      warn('References directory not found, skipping');
      return;
    }

    info('Copying references...');

    await _copyDirectory(templateDir, targetDir);

    success('References copied to: ${targetDir.path}');
  }

  /// Copy a directory recursively
  Future<void> _copyDirectory(Directory source, Directory target) async {
    if (!target.existsSync()) {
      await target.create(recursive: true);
    }

    await for (final FileSystemEntity entity in source.list(recursive: false)) {
      final String targetPath = p.join(target.path, p.basename(entity.path));

      if (entity is Directory) {
        // Skip certain directories
        final String dirName = p.basename(entity.path);
        if (_shouldSkipDirectory(dirName)) {
          continue;
        }

        final Directory newDirectory = Directory(targetPath);
        await _copyDirectory(entity, newDirectory);
      } else if (entity is File) {
        // Skip certain files
        final String fileName = p.basename(entity.path);
        if (_shouldSkipFile(fileName)) {
          continue;
        }

        await entity.copy(targetPath);
      }
    }
  }

  /// Check if a directory should be skipped during copy
  bool _shouldSkipDirectory(String dirName) {
    const List<String> skipDirs = <String>[
      '.dart_tool',
      '.idea',
      '.git',
      'build',
      '.gradle',
      'Pods',
    ];

    return skipDirs.contains(dirName);
  }

  /// Check if a file should be skipped during copy
  bool _shouldSkipFile(String fileName) {
    const List<String> skipFiles = <String>[
      '.DS_Store',
      'pubspec.lock',
      '.flutter-plugins',
      '.flutter-plugins-dependencies',
      '.packages',
      '.metadata',
    ];

    // Skip generated dart files
    if (fileName.endsWith('.g.dart')) return true;

    return skipFiles.contains(fileName);
  }

  /// Copy all templates based on config with progress tracking
  Future<void> copyAll() async {
    // Create output directory if needed
    final Directory outputDir = Directory(config.outputDir);
    if (!outputDir.existsSync()) {
      await outputDir.create(recursive: true);
    }

    // Build list of templates to copy
    final List<(String, Future<void> Function())> templates = <(String, Future<void> Function())>[
      ('Main app', copyAppTemplate),
    ];

    if (config.createModels) {
      templates.add(('Models package', copyModelsTemplate));
    }
    if (config.createServer) {
      templates.add(('Server app', copyServerTemplate));
    }
    templates.add(('References', copyReferences));

    // Copy each template with progress
    for (int i = 0; i < templates.length; i++) {
      final (String name, Future<void> Function() copier) = templates[i];
      UserPrompt.showProgress(i, templates.length, 'Copying $name...');
      await copier();
    }
    UserPrompt.showProgress(templates.length, templates.length, 'All templates copied');
  }

  /// Get list of files that would be copied (dry run)
  Future<List<String>> getFilesToCopy() async {
    final List<String> files = <String>[];

    // Main app
    final Directory appTemplate = Directory(
      getTemplatePath(config.template.directoryName),
    );
    if (appTemplate.existsSync()) {
      await for (final FileSystemEntity entity in appTemplate.list(recursive: true)) {
        if (entity is File) {
          files.add(p.relative(entity.path, from: appTemplate.path));
        }
      }
    }

    return files;
  }
}
