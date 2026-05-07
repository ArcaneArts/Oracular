import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../models/setup_config.dart';

/// Service for replacing placeholders in template files
///
/// Templates use canonical names (arcane_app, arcane_cli_app, etc.) that are
/// replaced with the user's actual app name when scaffolding a new project.
class PlaceholderReplacer {
  final SetupConfig config;

  PlaceholderReplacer(this.config);

  /// File extensions that should have placeholder replacement applied
  static const List<String> textFileExtensions = <String>[
    '.dart',
    '.yaml',
    '.yml',
    '.json',
    '.md',
    '.txt',
    '.sh',
    '.xml',
    '.plist',
    '.xcconfig',
    '.xcscheme',
    '.pbxproj',
    '.swift',
    '.kt',
    '.kts',
    '.gradle',
    '.properties',
    '.cc',
    '.h',
    '.cmake',
    '.html',
    '.js',
    '.css',
    '.entitlements',
    '.storyboard',
    '.xib',
    '.xcworkspacedata',
  ];

  /// Check if a file should have placeholders replaced
  bool shouldProcessFile(String path) {
    final String ext = p.extension(path).toLowerCase();
    return textFileExtensions.contains(ext);
  }

  /// Replace all placeholders in a string
  /// Templates use real working names that get replaced with user's names
  String replaceInContent(String content) {
    String result = content;

    // 1. Replace class names first (PascalCase patterns) to avoid double replacement
    // ArcaneServer -> MyAppServer
    result = result.replaceAll('ArcaneServer', config.serverClassName);

    // ArcaneRunner -> MyAppRunner
    result = result.replaceAll('ArcaneRunner', config.runnerClassName);

    // ArcaneJasprApp -> MyAppWeb (for Jaspr templates)
    result = result.replaceAll('ArcaneJasprApp', config.webClassName);

    // 2. Replace package imports - order matters, longer names first
    // Jaspr docs template (must be before arcane_jaspr_app)
    // package:arcane_jaspr_docs/ -> package:my_app_web/
    result = result.replaceAll(
      'package:arcane_jaspr_docs/',
      'package:${config.webPackageName}/',
    );
    // Jaspr web template
    // package:arcane_jaspr_app/ -> package:my_app_web/
    result = result.replaceAll(
      'package:arcane_jaspr_app/',
      'package:${config.webPackageName}/',
    );
    // Flutter templates
    // package:arcane_beamer_app/ -> package:my_app/
    result = result.replaceAll(
      'package:arcane_beamer_app/',
      'package:${config.appName}/',
    );
    // package:arcane_dock_app/ -> package:my_app/
    result = result.replaceAll(
      'package:arcane_dock_app/',
      'package:${config.appName}/',
    );
    // package:arcane_cli_app/ -> package:my_app/
    result = result.replaceAll(
      'package:arcane_cli_app/',
      'package:${config.appName}/',
    );
    // package:arcane_app/ -> package:my_app/
    result = result.replaceAll(
      'package:arcane_app/',
      'package:${config.appName}/',
    );

    // 3. Replace models package references
    result = result.replaceAll(
      'package:arcane_models/',
      'package:${config.modelsPackageName}/',
    );
    result = result.replaceAll('arcane_models', config.modelsPackageName);

    // 4. Replace server package references
    result = result.replaceAll('arcane_server', config.serverPackageName);

    // 5. Replace app names in various contexts (order matters - longer names first)
    // Jaspr docs template - must be before arcane_jaspr_app
    result = result.replaceAll('arcane_jaspr_docs', config.webPackageName);
    // Jaspr web template - must be before other arcane_ patterns
    result = result.replaceAll('arcane_jaspr_app', config.webPackageName);
    // These are the canonical template names
    // Flutter templates
    result = result.replaceAll('arcane_beamer_app', config.appName);
    result = result.replaceAll('arcane_dock_app', config.appName);
    result = result.replaceAll('arcane_cli_app', config.appName);
    result = result.replaceAll('arcane_app', config.appName);

    // 6. Replace Firebase project ID
    if (config.firebaseProjectId != null) {
      result = result.replaceAll(
        'FIREBASE_PROJECT_ID',
        config.firebaseProjectId!,
      );
    }

    // 7. Replace organization domain patterns
    // art.arcane.template -> com.example.myapp
    result = result.replaceAll(
      'art.arcane.template',
      '${config.orgDomain}.${config.appName.replaceAll('_', '')}',
    );
    result = result.replaceAll('ORG_DOMAIN', config.orgDomain);

    // 8. Replace display names in platform configs (e.g., Windows, Linux titles)
    // These show up in window titles, app manifests, etc.
    result = result.replaceAll('Arcane Template', config.baseClassName);
    result = result.replaceAll('Arcane Beamer', config.baseClassName);
    result = result.replaceAll('Arcane Dock', config.baseClassName);
    result = result.replaceAll('Arcane CLI', config.baseClassName);
    result = result.replaceAll('Arcane Jaspr Docs', config.baseClassName);
    result = result.replaceAll('Arcane Jaspr', config.baseClassName);

    return result;
  }

  /// Get the new filename after placeholder replacement
  String replaceInFilename(String filename) {
    String result = filename;

    // arcane_models.dart -> my_app_models.dart
    result = result.replaceAll('arcane_models', config.modelsPackageName);

    // Jaspr docs template (must be before arcane_jaspr_app)
    // arcane_jaspr_docs.dart -> my_app_web.dart
    result = result.replaceAll('arcane_jaspr_docs', config.webPackageName);

    // Jaspr web template (must be before arcane_app)
    // arcane_jaspr_app.dart -> my_app_web.dart
    result = result.replaceAll('arcane_jaspr_app', config.webPackageName);

    // Flutter templates
    // arcane_cli_app.dart -> my_app.dart (and .g.dart files)
    result = result.replaceAll('arcane_cli_app', config.appName);
    result = result.replaceAll('arcane_beamer_app', config.appName);
    result = result.replaceAll('arcane_dock_app', config.appName);
    result = result.replaceAll('arcane_app', config.appName);

    return result;
  }

  /// Process a single file - replace placeholders in content and rename if needed
  Future<void> processFile(File file) async {
    final String path = file.path;

    if (shouldProcessFile(path)) {
      // Read and replace content
      String content = await file.readAsString();
      final String newContent = replaceInContent(content);

      if (content != newContent) {
        await file.writeAsString(newContent);
        verbose('  Replaced placeholders in: ${p.basename(path)}');
      }
    }

    // Check if filename needs replacing
    final String filename = p.basename(path);
    final String newFilename = replaceInFilename(filename);

    if (filename != newFilename) {
      final String newPath = p.join(p.dirname(path), newFilename);
      await file.rename(newPath);
      verbose('  Renamed: $filename -> $newFilename');
    }
  }

  /// Process all files in a directory recursively
  Future<void> processDirectory(Directory dir) async {
    info('Processing placeholders in: ${dir.path}');

    await for (final FileSystemEntity entity in dir.list(recursive: true)) {
      if (entity is File) {
        await processFile(entity);
      } else if (entity is Directory) {
        // Check if directory name needs replacing
        final String dirName = p.basename(entity.path);
        final String newDirName = replaceInFilename(dirName);

        if (dirName != newDirName) {
          final String newPath = p.join(p.dirname(entity.path), newDirName);
          await entity.rename(newPath);
          verbose('  Renamed directory: $dirName -> $newDirName');
        }
      }
    }
  }

  /// Handle conditional imports in CLI template
  /// Uncomments lines based on configuration
  Future<void> processConditionalImports(File file) async {
    if (!file.existsSync()) return;

    String content = await file.readAsString();
    bool modified = false;

    // Handle Firebase imports
    if (config.useFirebase) {
      final RegExp firebasePattern = RegExp(r'// FIREBASE_IMPORT: (.+)');
      content = content.replaceAllMapped(firebasePattern, (Match match) {
        modified = true;
        return match.group(1)!;
      });
    }

    // Handle server command imports
    if (config.createServer) {
      final RegExp serverPattern = RegExp(r'// SERVER_COMMAND_IMPORT: (.+)');
      content = content.replaceAllMapped(serverPattern, (Match match) {
        modified = true;
        return match.group(1)!;
      });
    }

    // Handle models imports
    if (config.createModels) {
      final RegExp modelsPattern = RegExp(r'// MODELS_IMPORT: (.+)');
      content = content.replaceAllMapped(modelsPattern, (Match match) {
        modified = true;
        return match.group(1)!;
      });
    }

    if (modified) {
      await file.writeAsString(content);
      verbose('  Processed conditional imports in: ${p.basename(file.path)}');
    }
  }

  /// Update pubspec.yaml with correct name and optional dependencies
  Future<void> updatePubspec(File pubspecFile, String packageName) async {
    if (!pubspecFile.existsSync()) return;

    String content = await pubspecFile.readAsString();

    // Update package name
    content = content.replaceFirst(
      RegExp(r'^name: .+$', multiLine: true),
      'name: $packageName',
    );

    // Handle conditional dependencies
    if (config.createModels) {
      // Uncomment models dependency
      content = content.replaceAll(
        RegExp(r'#\s*${config.modelsPackageName}:'),
        '${config.modelsPackageName}:',
      );
    }

    // Handle Firebase dependencies
    if (config.useFirebase) {
      // Uncomment Firebase packages. We deliberately exclude
      // `arcane_auth_jaspr` here: it's pinned to `jaspr ^0.22.0` while the
      // Jaspr template uses `jaspr ^0.23.0`, so auto-uncommenting it would
      // make pub resolution fail. Auth is opt-in and documented per-template.
      final List<String> firebasePackages = <String>[
        'firebase_core',
        'firebase_auth',
        'cloud_firestore',
        'firebase_storage',
        'firebase_dart',
        'arcane_fluf',
        'arcane_auth',
        'fire_crud',
      ];
      for (final String pkg in firebasePackages) {
        content = content.replaceAll(RegExp(r'#\s*' + pkg + r':'), '$pkg:');
      }
    }

    await pubspecFile.writeAsString(content);
    verbose('  Updated pubspec.yaml for: $packageName');
  }

  /// Add models dependency to a project's pubspec.yaml
  Future<void> addModelsDependency(File pubspecFile) async {
    if (!pubspecFile.existsSync()) return;

    String content = await pubspecFile.readAsString();

    // Check if dependency already exists as a real (uncommented) dependency.
    // We can't use a simple `contains()` check because the template may
    // already mention the dependency in a comment.
    final List<String> lines = content.split('\n');
    final String escaped = RegExp.escape(config.modelsPackageName);
    final RegExp realDep = RegExp('^\\s+$escaped:');
    final bool hasReal = lines.any(
      (String line) =>
          realDep.hasMatch(line) && !line.trimLeft().startsWith('#'),
    );
    if (hasReal) {
      return;
    }

    // Find the dependencies section and add models dependency
    final RegExp dependenciesPattern = RegExp(
      r'^dependencies:\s*$',
      multiLine: true,
    );
    final RegExpMatch? match = dependenciesPattern.firstMatch(content);

    if (match != null) {
      final int insertPosition = match.end;
      final String modelsDep =
          '''

  ${config.modelsPackageName}:
    path: ../${config.modelsPackageName}
''';
      content =
          content.substring(0, insertPosition) +
          modelsDep +
          content.substring(insertPosition);

      await pubspecFile.writeAsString(content);
      verbose('  Added models dependency to: ${p.basename(pubspecFile.path)}');
    }
  }

  /// Inject a `dependency_overrides` entry that points `jpatch` at the
  /// vendored pure-Dart shim under `<outputDir>/.oracular_deps/jpatch`.
  ///
  /// If a `dependency_overrides:` block already exists, the entry is appended
  /// to it. Otherwise a new block is added at the bottom of the file. The
  /// method is idempotent — repeated calls are safe and no-op once the
  /// override is in place.
  Future<void> addJpatchOverride(File pubspecFile) async {
    if (!pubspecFile.existsSync()) return;

    String content = await pubspecFile.readAsString();

    // If `jpatch:` already appears in a (real) dependency_overrides line, bail.
    final List<String> existingLines = content.split('\n');
    bool inOverrides = false;
    for (final String line in existingLines) {
      if (line.trimLeft().startsWith('#')) continue;
      if (RegExp(r'^dependency_overrides:\s*$').hasMatch(line)) {
        inOverrides = true;
        continue;
      }
      // Top-level key resets context.
      if (inOverrides && RegExp(r'^[a-zA-Z_]').hasMatch(line)) {
        inOverrides = false;
      }
      if (inOverrides && RegExp(r'^\s+jpatch:').hasMatch(line)) {
        return;
      }
    }

    const String overrideEntry =
        '  jpatch:\n'
        '    path: ../.oracular_deps/jpatch\n';

    final RegExp overridesHeader = RegExp(
      r'^dependency_overrides:\s*$',
      multiLine: true,
    );
    final RegExpMatch? headerMatch = overridesHeader.firstMatch(content);

    if (headerMatch != null) {
      final int insertPosition = headerMatch.end;
      content =
          '${content.substring(0, insertPosition)}\n'
          '$overrideEntry'
          '${content.substring(insertPosition)}';
    } else {
      if (!content.endsWith('\n')) content += '\n';
      content += '\ndependency_overrides:\n$overrideEntry';
    }

    await pubspecFile.writeAsString(content);
    verbose(
      '  Added jpatch dependency_overrides to: '
      '${p.basename(pubspecFile.path)}',
    );
  }
}
