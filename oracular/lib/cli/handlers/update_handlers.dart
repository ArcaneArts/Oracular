import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../../models/setup_config.dart';
import '../../models/template_info.dart';
import '../../services/intellij_run_config_generator.dart';
import '../../utils/user_prompt.dart';

/// Handle `oracular update runs [--port NNNN] [--output-dir <path>]`.
///
/// Adds (or refreshes) IntelliJ / Android Studio run configurations
/// for an Oracular project, in two flavors:
///
/// 1. **`Deploy All`** at the project root — `oracular deploy all`.
///    Always emitted (template-agnostic). Lives in
///    `<output-dir>/.idea/runConfigurations/Deploy_All.run.xml`.
///
/// 2. **`Serve` / `Build` / `Killall :PORT`** for every Jaspr web
///    package found under `output-dir`. Lives in
///    `<package>/.idea/runConfigurations/`. Skipped if no Jaspr
///    packages are detected.
///
/// Why this command exists: a project scaffolded by Oracular < 3.4.0
/// won't have these configs, and the wizard's full rebuild
/// (`oracular rebuild`) is too heavy-handed when the user only wants
/// the IDE wiring back. This command is the fast, surgical update.
///
/// Detection strategy for Jaspr packages (in order):
///
///   1. Load `<output-dir>/config/setup_config.env` if it exists. If the
///      saved template is a Jaspr template, use [SetupConfig.webPackageName]
///      as the canonical target — even if other Jaspr-like packages
///      coexist in the tree.
///   2. Otherwise (no setup_config.env, or non-Jaspr template), scan
///      [output-dir] one level deep for any folder whose `pubspec.yaml`
///      declares a `jaspr:` dependency. Each matching folder becomes a
///      target.
///   3. As a last resort, if [output-dir] itself is a Jaspr package,
///      treat it as the single target.
///
/// All configs are idempotent on re-run.
Future<void> handleUpdateRuns(Map<String, dynamic> args) async {
  // darted_cli has an internal bug: it strips hyphens from arg names
  // when parsing input, but then re-builds `--<name>` to match against
  // the original input — dropping any arg whose name contains a hyphen.
  // Workaround: name our flags without hyphens (`dir` instead of
  // `output-dir`) and accept multiple aliases below for robustness.
  final String? rawDir = (args['dir'] as String?) ??
      (args['d'] as String?) ??
      (args['output-dir'] as String?) ??
      (args['outputdir'] as String?);
  final String outputDir = (rawDir != null && rawDir.trim().isNotEmpty)
      ? rawDir.trim()
      : Directory.current.path;
  final int port = _parsePort(args['port'] ?? args['p']);

  print('');
  UserPrompt.printDivider(title: 'Update IntelliJ run configurations');

  // ── Step 1: project-root "Deploy All" config ──────────────────────────
  //
  // Template-agnostic — emit unconditionally for any directory the user
  // points us at. Even if the dir isn't an Oracular project, the user
  // may want a `oracular deploy all` button (e.g., they're about to run
  // `oracular create`).
  int deployWrittenCount = 0;
  try {
    final List<String> deployWritten =
        await IntellijRunConfigGenerator.generateDeploy(
      projectDir: outputDir,
    );
    deployWrittenCount = deployWritten.length;
    if (deployWritten.isNotEmpty) {
      info(
        '  ./ + ${p.basename(deployWritten.first)} '
        '(oracular deploy all)',
      );
    }
  } catch (e) {
    warn('Failed to write project-level Deploy All config: $e');
  }

  // ── Step 2: per-Jaspr-package Serve / Build / Killall configs ─────────
  final List<_JasprTarget> targets = await _resolveTargets(outputDir);
  if (targets.isEmpty) {
    if (deployWrittenCount == 0) {
      // Neither Deploy nor Jaspr configs were emitted — nothing to do.
      // This is genuinely unexpected because the Deploy generator is
      // unconditional, so log a hint rather than a hard failure.
      error(
        'No run configs emitted for $outputDir.',
      );
      return;
    }
    print('');
    success(
      'Wrote project-level "Deploy All" run config '
      '(no Jaspr packages found — Serve/Build/Killall skipped).',
    );
    print('');
    UserPrompt.printList(<String>[
      'Open the project in IntelliJ / Android Studio.',
      'You should see "Deploy All" in the run configurations dropdown',
      '(top-right corner). Click ▶ to run `oracular deploy all`.',
    ]);
    return;
  }

  info(
    'Found ${targets.length} Jaspr package'
    '${targets.length == 1 ? '' : 's'} — writing Serve/Build/Killall '
    'configs (port: $port)...',
  );

  int totalWritten = 0;
  int totalPruned = 0;
  for (final _JasprTarget target in targets) {
    info('  ${target.relativePath}/');
    final List<String> deleted =
        await IntellijRunConfigGenerator.pruneStaleKillallConfigs(
      packageDir: target.absolutePath,
      currentPort: port,
    );
    if (deleted.isNotEmpty) {
      verbose(
        '    Pruned ${deleted.length} stale Killall config(s) for '
        'previous port(s).',
      );
      totalPruned += deleted.length;
    }
    final List<String> written = await IntellijRunConfigGenerator.generate(
      packageDir: target.absolutePath,
      port: port,
    );
    for (final String f in written) {
      verbose('    + ${p.basename(f)}');
    }
    totalWritten += written.length;
  }

  print('');
  success(
    'Updated ${totalWritten + deployWrittenCount} run config'
    '${(totalWritten + deployWrittenCount) == 1 ? '' : 's'} '
    '($deployWrittenCount project-level Deploy + $totalWritten Jaspr '
    'across ${targets.length} package'
    '${targets.length == 1 ? '' : 's'})'
    '${totalPruned > 0 ? ' (pruned $totalPruned stale)' : ''}.',
  );
  print('');
  UserPrompt.printList(<String>[
    'Open the project in IntelliJ / Android Studio.',
    'You should see "Deploy All" plus "Serve", "Build", and ',
    '"Killall :$port" in the run configurations dropdown (top-right).',
    'Re-run with --port NNNN to change the Jaspr port; the killall',
    'config will auto-prune the previous port file.',
  ]);
}

/// Resolve the list of Jaspr packages under [outputDir] using the
/// detection strategy described in [handleUpdateRuns].
Future<List<_JasprTarget>> _resolveTargets(String outputDir) async {
  final Directory root = Directory(outputDir);
  if (!root.existsSync()) {
    return <_JasprTarget>[];
  }

  // Strategy 1: setup_config.env points us at the canonical web package.
  final File configFile =
      File(p.join(outputDir, 'config', 'setup_config.env'));
  if (configFile.existsSync()) {
    try {
      final SetupConfig? config = await SetupConfig.loadFromFile(configFile.path);
      if (config != null && config.template.isJasprApp) {
        // Jaspr scaffolds use `<appName>_web` for the package name.
        final String webDir = p.join(outputDir, config.webPackageName);
        if (Directory(webDir).existsSync()) {
          return <_JasprTarget>[
            _JasprTarget(
              absolutePath: webDir,
              relativePath: p.relative(webDir, from: outputDir),
            ),
          ];
        }
      }
    } catch (e) {
      verbose('  Failed to load setup_config.env: $e — falling back to scan.');
    }
  }

  // Strategy 2: scan one level deep for pubspec.yaml files with `jaspr:`.
  final List<_JasprTarget> found = <_JasprTarget>[];
  await for (final FileSystemEntity entity
      in root.list(followLinks: false)) {
    if (entity is! Directory) continue;
    if (_isHiddenDir(entity)) continue;
    if (await _hasJasprDependency(entity)) {
      found.add(_JasprTarget(
        absolutePath: entity.path,
        relativePath: p.relative(entity.path, from: outputDir),
      ));
    }
  }
  if (found.isNotEmpty) return found;

  // Strategy 3: outputDir itself is a Jaspr package.
  if (await _hasJasprDependency(root)) {
    return <_JasprTarget>[
      _JasprTarget(
        absolutePath: outputDir,
        relativePath: '.',
      ),
    ];
  }

  return <_JasprTarget>[];
}

bool _isHiddenDir(Directory dir) {
  final String name = p.basename(dir.path);
  if (name.startsWith('.')) return true;
  // Skip transient/never-Jaspr directories. Faster than reading their
  // pubspec.yaml.
  const Set<String> skip = <String>{
    'build',
    'node_modules',
    'config',
    '.oracular_deps',
    '.dart_tool',
    'assets',
    'reference',
  };
  return skip.contains(name);
}

/// `true` iff [dir]/pubspec.yaml exists and declares any `jaspr*`
/// dependency. We don't parse YAML — a substring match is sufficient
/// because no other ecosystem package starts with "jaspr".
Future<bool> _hasJasprDependency(Directory dir) async {
  final File pubspec = File(p.join(dir.path, 'pubspec.yaml'));
  if (!pubspec.existsSync()) return false;
  try {
    final String content = await pubspec.readAsString();
    final RegExp jasprDep = RegExp(r'^\s*jaspr\s*:', multiLine: true);
    return jasprDep.hasMatch(content);
  } catch (_) {
    return false;
  }
}

/// Parse the CLI port argument with a sane default. Accepts strings
/// because `darted_cli` returns everything as `String` from `args`.
int _parsePort(Object? raw) {
  if (raw is int) return raw;
  if (raw is String && raw.trim().isNotEmpty) {
    final int? parsed = int.tryParse(raw.trim());
    if (parsed != null && parsed > 0 && parsed < 65536) {
      return parsed;
    }
    warn('Invalid --port value "$raw"; using default 8080.');
  }
  return IntellijRunConfigGenerator.defaultPort;
}

/// Internal record of a Jaspr package target — both its absolute path
/// (for file I/O) and a display-friendly relative path (for logs).
class _JasprTarget {
  final String absolutePath;
  final String relativePath;
  const _JasprTarget({
    required this.absolutePath,
    required this.relativePath,
  });
}
