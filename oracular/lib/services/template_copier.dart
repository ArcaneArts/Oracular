import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../models/setup_config.dart';
import '../models/template_info.dart';
import '../utils/user_prompt.dart';
import 'intellij_run_config_generator.dart';
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
    final String templatesPath = await _findTemplatesPath(
      onProgress: onProgress,
    );
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
    // arcaneJasprFlutterEmbed is a dual-package template: it ships a Jaspr
    // host (_web) AND a Flutter web guest (_app) under one parent dir.
    // Route the copy through the dedicated helper so each sub-package
    // lands in its own scaffolded directory.
    if (config.template == TemplateType.arcaneJasprFlutterEmbed) {
      await _copyJasprFlutterEmbedTemplate();
      return;
    }

    final Directory templateDir = Directory(
      getTemplatePath(config.template.directoryName),
    );

    // For Jaspr templates, use webPackageName; for others, use appName
    final String targetName = config.template.isJasprApp
        ? config.webPackageName
        : config.appName;
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

      // Pure-Dart targets (Jaspr, Dart CLI) cannot resolve `arcane_models`
      // out of the box because `artifact -> json_compress -> jpatch` pulls in
      // the Flutter SDK via jpatch's pubspec. Vendor a pure-Dart jpatch shim
      // and inject a `dependency_overrides` so the project resolves cleanly.
      if (!config.template.isFlutterApp) {
        await _vendorJpatchOverride(pubspecFile);
      }

      // Jaspr targets (web app + docs) bring in `jaspr_builder` (analyzer
      // ^10.0.0). The published `artifact_gen` and `fire_crud_gen` packages
      // pin `analyzer ^8.0.0`, which makes `pub get` impossible to resolve
      // when both are present. Vendor pure-shim drop-ins for the gen
      // packages so build_runner can satisfy `auto_apply: dependents` in the
      // upstream `artifact` and `fire_crud` `build.yaml` files without
      // dragging analyzer 8 into the resolution. The actual model
      // generation still happens in the dedicated models package (which
      // does NOT depend on jaspr_builder), so the web app only consumes
      // the already-generated `.g.dart` files.
      if (config.template.isJasprApp) {
        await _vendorJasprBuilderShims(pubspecFile);
      }
    }

    if (config.template.isJasprDocs) {
      await _prepareJasprDocsDependencies();
    }

    // Patch jaspr.yaml mode for Jaspr templates so the user's selected
    // render mode (CSR / SSG / SSR / Hybrid) lands in the generated
    // project. Without this, every project would inherit the template's
    // default mode (client) regardless of what the user picked.
    if (config.template.isJasprApp) {
      await _patchJasprYamlMode(targetDir);
    }

    // Emit IntelliJ run configurations (Serve / Build / Killall) for
    // every Jaspr web target so a fresh `oracular` scaffold drops the
    // user straight into a clickable dev loop in IntelliJ /
    // Android Studio. No-op for Flutter/Dart-CLI templates — they have
    // their own (Flutter-native) run configs created by `flutter
    // create`.
    if (config.template.isJasprApp) {
      try {
        final List<String> written =
            await IntellijRunConfigGenerator.generate(
          packageDir: targetDir.path,
          port: IntellijRunConfigGenerator.defaultPort,
        );
        if (written.isNotEmpty) {
          verbose(
            '  Generated ${written.length} IntelliJ run config(s) in '
            '${p.join(targetDir.path, '.idea', 'runConfigurations')}',
          );
        }
      } catch (e) {
        // Non-fatal — the project is still usable, the user just has
        // to add run configs manually (or run `oracular update runs`).
        warn('Failed to generate IntelliJ run configs: $e');
      }
    }

    success('App template copied to: ${targetDir.path}');
  }

  /// Copy the arcane_jaspr_flutter_embed template, which is a dual-package
  /// scaffold (Jaspr host + Flutter web guest).
  ///
  /// Lands two sub-packages:
  ///   * `<outputDir>/<webPackageName>/` — Jaspr static host
  ///     (from `templates/arcane_jaspr_flutter_embed/arcane_jaspr_flutter_embed_web/`)
  ///   * `<outputDir>/<embeddedFlutterPackageName>/` — Flutter web app
  ///     (from `templates/arcane_jaspr_flutter_embed/arcane_jaspr_flutter_embed_app/`)
  Future<void> _copyJasprFlutterEmbedTemplate() async {
    final Directory parentTemplate = Directory(
      getTemplatePath('arcane_jaspr_flutter_embed'),
    );
    if (!parentTemplate.existsSync()) {
      throw Exception('Template not found: ${parentTemplate.path}');
    }

    info('Copying ${config.template.displayName} template (dual-package)...');

    // ── Host (_web) ────────────────────────────────────────────────────
    final Directory webSource = Directory(
      p.join(parentTemplate.path, 'arcane_jaspr_flutter_embed_web'),
    );
    if (!webSource.existsSync()) {
      throw Exception('Embed host template not found: ${webSource.path}');
    }
    final Directory webTarget = Directory(
      p.join(config.outputDir, config.webPackageName),
    );
    await _copyDirectory(webSource, webTarget);
    await _replacer.processDirectory(webTarget);
    final File webPubspec = File(p.join(webTarget.path, 'pubspec.yaml'));
    await _replacer.updatePubspec(webPubspec, config.webPackageName);

    if (config.createModels) {
      await _replacer.addModelsDependency(webPubspec);
      // Pure-Dart host needs the jpatch + jaspr-builder shims, same as
      // the regular Jaspr templates do.
      await _vendorJpatchOverride(webPubspec);
      await _vendorJasprBuilderShims(webPubspec);
    }

    await _patchJasprYamlMode(webTarget);

    try {
      final List<String> written =
          await IntellijRunConfigGenerator.generate(
        packageDir: webTarget.path,
        port: IntellijRunConfigGenerator.defaultPort,
      );
      if (written.isNotEmpty) {
        verbose(
          '  Generated ${written.length} IntelliJ run config(s) in '
          '${p.join(webTarget.path, '.idea', 'runConfigurations')}',
        );
      }
    } catch (e) {
      warn('Failed to generate IntelliJ run configs for host: $e');
    }

    // ── Guest (_app) ───────────────────────────────────────────────────
    final Directory appSource = Directory(
      p.join(parentTemplate.path, 'arcane_jaspr_flutter_embed_app'),
    );
    if (!appSource.existsSync()) {
      throw Exception('Embed guest template not found: ${appSource.path}');
    }
    final Directory appTarget = Directory(
      p.join(config.outputDir, config.embeddedFlutterPackageName),
    );
    await _copyDirectory(appSource, appTarget);
    await _replacer.processDirectory(appTarget);
    final File appPubspec = File(p.join(appTarget.path, 'pubspec.yaml'));
    await _replacer.updatePubspec(appPubspec, config.embeddedFlutterPackageName);

    if (config.createModels) {
      await _replacer.addModelsDependency(appPubspec);
    }

    success(
      'Embed scaffold copied: ${webTarget.path} + ${appTarget.path}',
    );
  }

  /// Rewrite the Jaspr render mode in the copied project so the user's
  /// selected `JasprRenderMode` (CSR / SSG / SSR / Hybrid / Embed) lands
  /// everywhere Jaspr might look for it. Two files are touched:
  ///
  ///   1. `pubspec.yaml` — the **authoritative** source-of-truth for
  ///      `jaspr.mode` ever since `jaspr_cli` 0.20+. The CLI reads
  ///      `pubspec.yaml.jaspr.mode` (see
  ///      `jaspr_cli/lib/src/project.dart#requireMode`) and outright
  ///      ignores `jaspr.yaml`.
  ///   2. `jaspr.yaml` — kept in sync purely so humans browsing the
  ///      project see the same mode regardless of which file they open.
  ///
  /// Silently no-ops on missing files (defensive) and is idempotent: a
  /// second call with the same render mode is a no-op.
  Future<void> _patchJasprYamlMode(Directory targetDir) async {
    final String desiredMode = config.jasprRenderMode.jasprYamlMode;

    // 1) pubspec.yaml — authoritative.
    final File pubspec = File(p.join(targetDir.path, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      final String original = await pubspec.readAsString();
      final String patched = _rewritePubspecJasprMode(original, desiredMode);
      if (patched != original) {
        await pubspec.writeAsString(patched);
        verbose(
          '  Patched pubspec.yaml jaspr.mode to "$desiredMode" '
          '(${config.jasprRenderMode.displayName}).',
        );
      }
    } else {
      verbose('  pubspec.yaml not found in ${targetDir.path}; skipping jaspr.mode patch');
    }

    // 2) jaspr.yaml — cosmetic / docs-only.
    final File jasprYaml = File(p.join(targetDir.path, 'jaspr.yaml'));
    if (!jasprYaml.existsSync()) {
      return;
    }

    final String content = await jasprYaml.readAsString();
    final RegExp modeLine = RegExp(r'^mode:\s*\S+\s*$', multiLine: true);
    final String patched;
    if (modeLine.hasMatch(content)) {
      patched = content.replaceFirst(modeLine, 'mode: $desiredMode');
    } else {
      patched = 'mode: $desiredMode\n$content';
    }

    if (patched != content) {
      await jasprYaml.writeAsString(patched);
      verbose('  Patched jaspr.yaml mode to "$desiredMode" (cosmetic).');
    }
  }

  /// Rewrites `pubspec.yaml.jaspr.mode` to [desiredMode]. If the
  /// `jaspr:` block is missing entirely, prepends a minimal one before
  /// `dependencies:`. The implementation is intentionally line-based
  /// (rather than full YAML re-emission) so user comments, ordering,
  /// and whitespace are preserved.
  String _rewritePubspecJasprMode(String content, String desiredMode) {
    final List<String> lines = content.split('\n');
    int jasprBlockStart = -1;
    int modeLineIndex = -1;

    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i];
      if (jasprBlockStart < 0 &&
          RegExp(r'^jaspr:\s*(#.*)?$').hasMatch(line)) {
        jasprBlockStart = i;
        continue;
      }
      if (jasprBlockStart >= 0 && i == jasprBlockStart + 1) {
        // First line after `jaspr:` — could be `  mode: …` or another
        // nested key. Scan a small window for the mode line.
      }
      if (jasprBlockStart >= 0 &&
          RegExp(r'^\s{2,}mode:\s*\S+').hasMatch(line) &&
          modeLineIndex < 0) {
        // Make sure we're still inside the jaspr: block (i.e. the line
        // is indented).
        modeLineIndex = i;
        break;
      }
      if (jasprBlockStart >= 0 &&
          line.isNotEmpty &&
          !line.startsWith(' ') &&
          !line.startsWith('#') &&
          i > jasprBlockStart) {
        // Left the jaspr: block without finding a mode line.
        break;
      }
    }

    if (modeLineIndex >= 0) {
      lines[modeLineIndex] = lines[modeLineIndex].replaceFirst(
        RegExp(r'mode:\s*\S+'),
        'mode: $desiredMode',
      );
      return lines.join('\n');
    }

    if (jasprBlockStart >= 0) {
      // Block exists but no mode key — insert one immediately after.
      lines.insert(jasprBlockStart + 1, '  mode: $desiredMode');
      return lines.join('\n');
    }

    // No jaspr: block at all — prepend a minimal one above `dependencies:`.
    final int depsIndex = lines.indexWhere(
      (String l) => RegExp(r'^dependencies:\s*$').hasMatch(l),
    );
    final List<String> jasprBlock = <String>[
      '',
      '# Jaspr CLI configuration — render mode is read from this block.',
      'jaspr:',
      '  mode: $desiredMode',
      '',
    ];
    if (depsIndex < 0) {
      lines.addAll(jasprBlock);
    } else {
      lines.insertAll(depsIndex, jasprBlock);
    }
    return lines.join('\n');
  }

  /// Docs template no longer requires the legacy `.oracular_deps/arcane_*`
  /// vendoring step because its pubspec now references the upstream packages
  /// via git directly. Kept as a no-op for forward compatibility — extra
  /// docs-specific setup can be added here later if needed.
  Future<void> _prepareJasprDocsDependencies() async {}

  /// Vendor a pure-Dart `jpatch` shim into the project so that pure-Dart
  /// targets (Jaspr web apps, Dart CLIs) can consume `arcane_models` without
  /// dragging in the Flutter SDK.
  ///
  /// The published `jpatch 1.0.1` declares a Flutter SDK dependency in its
  /// pubspec even though every line of its source is pure Dart. That single
  /// declaration cascades through `artifact -> json_compress -> jpatch` and
  /// blocks resolution for any non-Flutter consumer.
  ///
  /// This method:
  ///   1. Copies `templates/_vendor/jpatch/` into
  ///      `<outputDir>/.oracular_deps/jpatch/` (idempotent — does nothing if
  ///      already vendored).
  ///   2. Adds a `dependency_overrides` entry to [pubspecFile] so that the
  ///      vendored copy wins over the published one during pub resolution.
  Future<void> _vendorJpatchOverride(File pubspecFile) async {
    final Directory shimSource = Directory(
      p.join(templatesBasePath, '_vendor', 'jpatch'),
    );
    if (!shimSource.existsSync()) {
      warn(
        'jpatch shim not found at ${shimSource.path}; '
        'skipping pure-Dart override (Jaspr+models may fail to resolve)',
      );
      return;
    }

    final Directory depsRoot = Directory(
      p.join(config.outputDir, '.oracular_deps'),
    );
    final Directory shimTarget = Directory(p.join(depsRoot.path, 'jpatch'));
    if (!shimTarget.existsSync()) {
      await shimTarget.create(recursive: true);
      await _copyDirectory(shimSource, shimTarget);
      verbose('  Vendored pure-Dart jpatch shim to: ${shimTarget.path}');
    }

    await _replacer.addJpatchOverride(pubspecFile);
  }

  /// Vendor pure-shim drop-ins for `artifact_gen` and `fire_crud_gen` so a
  /// Jaspr web app (or docs site) can consume `arcane_models` while also
  /// using `jaspr_builder`.
  ///
  /// **Why this is necessary**
  ///
  /// Published `artifact_gen` and `fire_crud_gen` pin `analyzer ^8.0.0`.
  /// `jaspr_builder` (transitively required by every Jaspr template via
  /// `dev_dependencies`) pins `analyzer ^10.0.0`. Those constraints are
  /// disjoint — `pub get` cannot resolve them in the same project.
  ///
  /// Model generation already happens in the dedicated models package,
  /// which does NOT depend on `jaspr_builder`. The web app only ever
  /// imports the already-generated `.g.dart` files; it never needs to
  /// re-run those builders. But the upstream `artifact` and `fire_crud`
  /// packages declare their builders with `auto_apply: dependents` — that
  /// means `build_runner` tries to load
  /// `package:artifact_gen/artifact_gen.dart` and
  /// `package:fire_crud_gen/crud_builder.dart` for any package that depends
  /// on `artifact` / `fire_crud` — including the web. Without something
  /// providing those imports, `pub get` fails.
  ///
  /// This method:
  ///   1. Copies `templates/_vendor/artifact_gen/` and
  ///      `templates/_vendor/fire_crud_gen/` (no-op shim packages whose
  ///      Builders produce zero output) into
  ///      `<outputDir>/.oracular_deps/`.
  ///   2. Adds `dependency_overrides` entries for both shims so they win
  ///      over the published versions during pub resolution.
  Future<void> _vendorJasprBuilderShims(File pubspecFile) async {
    const List<String> shimNames = <String>['artifact_gen', 'fire_crud_gen'];

    for (final String shimName in shimNames) {
      final Directory shimSource = Directory(
        p.join(templatesBasePath, '_vendor', shimName),
      );
      if (!shimSource.existsSync()) {
        warn(
          '$shimName shim not found at ${shimSource.path}; '
          'skipping Jaspr builder override (web build may fail with '
          'analyzer version conflict between artifact_gen ^8.0.0 and '
          'jaspr_builder ^10.0.0)',
        );
        continue;
      }

      final Directory depsRoot = Directory(
        p.join(config.outputDir, '.oracular_deps'),
      );
      final Directory shimTarget = Directory(p.join(depsRoot.path, shimName));
      if (!shimTarget.existsSync()) {
        await shimTarget.create(recursive: true);
        await _copyDirectory(shimSource, shimTarget);
        verbose('  Vendored $shimName shim to: ${shimTarget.path}');
      }

      await _replacer.addVendoredOverride(
        pubspecFile,
        packageName: shimName,
        relativeShimPath: '../.oracular_deps/$shimName',
      );
    }
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
    final Directory targetDir = Directory(
      p.join(config.outputDir, 'references'),
    );

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
    final List<(String, Future<void> Function())> templates =
        <(String, Future<void> Function())>[('Main app', copyAppTemplate)];

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
    UserPrompt.showProgress(
      templates.length,
      templates.length,
      'All templates copied',
    );

    // Emit the project-level "Deploy All" IntelliJ run configuration.
    //
    // Lives at the project ROOT (not in any individual sub-package) so
    // it's discoverable when the user opens the multi-package workspace
    // in IntelliJ / Android Studio. Template-agnostic — every Oracular
    // project benefits from a one-click `oracular deploy all` button.
    //
    // Non-fatal on failure: the project is still usable, the user just
    // has to add the run config manually (or run `oracular update runs`).
    try {
      final List<String> deployWritten =
          await IntellijRunConfigGenerator.generateDeploy(
        projectDir: config.outputDir,
      );
      if (deployWritten.isNotEmpty) {
        verbose(
          '  Generated project-level "Deploy All" run config in '
          '${p.join(config.outputDir, '.idea', 'runConfigurations')}',
        );
      }
    } catch (e) {
      warn('Failed to generate "Deploy All" IntelliJ run config: $e');
    }
  }

  /// Get list of files that would be copied (dry run)
  Future<List<String>> getFilesToCopy() async {
    final List<String> files = <String>[];

    // Main app
    final Directory appTemplate = Directory(
      getTemplatePath(config.template.directoryName),
    );
    if (appTemplate.existsSync()) {
      await for (final FileSystemEntity entity in appTemplate.list(
        recursive: true,
      )) {
        if (entity is File) {
          files.add(p.relative(entity.path, from: appTemplate.path));
        }
      }
    }

    return files;
  }
}
