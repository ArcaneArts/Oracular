#!/usr/bin/env dart
// ignore_for_file: avoid_print
//
// package_template.dart — zip a single template directory into the
// `<template>-v<X.Y.Z>.zip` Release asset.
//
// This script is the matrix worker for `.github/workflows/templates-release.yml`'s
// `package-templates` job. It runs once per template, in parallel
// with its siblings.
//
// What it does (per plan §6, §3.4, §9):
//   1. Validate that templates/<template>/ exists
//   2. Stage it to a temp directory, applying skip rules from
//      oracular/lib/services/template_copier.dart:614-643
//   3. Conditionally vendor the right `_vendor/<shim>/` subdirs based
//      on template type (Jaspr / CLI / Server vs Flutter apps)
//   4. Drop the pre-generated `setup.dart` at staging root
//   5. Drop README.md (rendered from RELEASE_README_TEMPLATE.md with
//      {{TEMPLATE_NAME}} / {{VERSION}} substitutions)
//   6. Drop VERSION (key=value lines)
//   7. Drop LICENSE (copy of oracular/LICENSE)
//   8. Touch every staged file to a fixed timestamp derived from the
//      build-id (so the resulting ZIP is bit-stable across reruns at
//      the same build-id)
//   9. Zip staging → <out>/<template>-v<version>.zip
//
// CLI:
//   dart run scripts/package_template.dart \
//     --template arcane_app \
//     --version 3.5.0 \
//     --build-id '3.5.0+20260511T143022Z-c7bcf2a' \
//     --setup-script dist/setup.dart \
//     --out dist/ \
//     [--readme-template templates/RELEASE_README_TEMPLATE.md] \
//     [--license oracular/LICENSE] \
//     [--templates-root templates/] \
//     [--keep-staging] \
//     [-v|--verbose]

import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

// ─────────────────────────────────────────────────────────────────────
// Template taxonomy. Drives which `_vendor/` shims to include.
// Mirrors SetupOptions getters in setup_template_template.dart and the
// jpatch / jaspr-builder logic in
// oracular/lib/services/template_copier.dart:415-502.
// ─────────────────────────────────────────────────────────────────────

const Set<String> _kKnownTemplates = <String>{
  'arcane_app',
  'arcane_beamer_app',
  'arcane_dock_app',
  'arcane_cli_app',
  'arcane_jaspr_app',
  'arcane_jaspr_docs',
  'arcane_jaspr_flutter_embed',
  'arcane_models',
  'arcane_server',
};

const Set<String> _kJasprTemplates = <String>{
  'arcane_jaspr_app',
  'arcane_jaspr_docs',
  'arcane_jaspr_flutter_embed',
};

/// Which vendor shims to include in this template's ZIP. Pre-bundling
/// them lets `setup.dart` activate them at extract time without a
/// network round-trip (plan §3.4 Option A).
List<String> _vendorShimsFor(String template) {
  if (_kJasprTemplates.contains(template)) {
    return <String>['jpatch', 'artifact_gen', 'fire_crud_gen'];
  }
  if (template == 'arcane_cli_app' || template == 'arcane_server') {
    return <String>['jpatch'];
  }
  // Flutter apps + models: no vendoring needed.
  return <String>[];
}

// ─────────────────────────────────────────────────────────────────────
// Args.
// ─────────────────────────────────────────────────────────────────────

class _Args {
  String? template;
  String? version;
  String? buildId;
  String? setupScriptPath;
  String outDir = 'dist';
  String readmeTemplatePath = 'templates/RELEASE_README_TEMPLATE.md';
  String licensePath = 'oracular/LICENSE';
  String templatesRoot = 'templates';
  bool keepStaging = false;
  bool verbose = false;
  bool help = false;
}

void _printHelp() {
  print('''
package_template.dart — zip one template into <template>-v<X.Y.Z>.zip

USAGE
  dart run scripts/package_template.dart \\
    --template <name> --version <X.Y.Z> --build-id <id> \\
    --setup-script <path> [--out <dir>]

REQUIRED
  --template <name>           One of: ${(_kKnownTemplates.toList()..sort()).join(", ")}
  --version <X.Y.Z>           Release version (matches oracular/pubspec.yaml).
  --build-id <id>             Build identifier for the embedded VERSION file.
  --setup-script <path>       Path to the baked setup.dart from
                              `dart run scripts/generate_setup_script.dart`.

OPTIONAL
  --out <dir>                 Output directory (default: dist).
  --readme-template <path>    README seed (default: templates/RELEASE_README_TEMPLATE.md).
                              If missing, a one-paragraph fallback is generated.
  --license <path>            LICENSE file to embed (default: oracular/LICENSE).
  --templates-root <path>     Where to find templates/ (default: templates).
  --keep-staging              Do NOT delete the temp staging dir; useful for debugging.
  -v, --verbose               Verbose logging.
  -h, --help                  This help.
''');
}

_Args _parseArgs(List<String> raw) {
  final _Args a = _Args();
  for (int i = 0; i < raw.length; i++) {
    final String arg = raw[i];
    String takeNext(String flag) {
      if (i + 1 >= raw.length) {
        throw FormatException('$flag requires a value');
      }
      return raw[++i];
    }

    if (arg.startsWith('--') && arg.contains('=')) {
      final int eq = arg.indexOf('=');
      final String key = arg.substring(2, eq);
      final String val = arg.substring(eq + 1);
      _assign(a, '--$key', val);
      continue;
    }

    switch (arg) {
      case '--template':
        a.template = takeNext(arg);
      case '--version':
        a.version = takeNext(arg);
      case '--build-id':
        a.buildId = takeNext(arg);
      case '--setup-script':
        a.setupScriptPath = takeNext(arg);
      case '--out':
        a.outDir = takeNext(arg);
      case '--readme-template':
        a.readmeTemplatePath = takeNext(arg);
      case '--license':
        a.licensePath = takeNext(arg);
      case '--templates-root':
        a.templatesRoot = takeNext(arg);
      case '--keep-staging':
        a.keepStaging = true;
      case '-v':
      case '--verbose':
        a.verbose = true;
      case '-h':
      case '--help':
        a.help = true;
      default:
        throw FormatException('Unknown argument: $arg');
    }
  }
  return a;
}

void _assign(_Args a, String key, String value) {
  switch (key) {
    case '--template':
      a.template = value;
    case '--version':
      a.version = value;
    case '--build-id':
      a.buildId = value;
    case '--setup-script':
      a.setupScriptPath = value;
    case '--out':
      a.outDir = value;
    case '--readme-template':
      a.readmeTemplatePath = value;
    case '--license':
      a.licensePath = value;
    case '--templates-root':
      a.templatesRoot = value;
    default:
      throw FormatException('Unknown argument: $key');
  }
}

// ─────────────────────────────────────────────────────────────────────
// Skip rules — mirror oracular/lib/services/template_copier.dart:614-643.
// ─────────────────────────────────────────────────────────────────────

bool _shouldSkipDir(String name) => const <String>{
      '.dart_tool',
      '.idea',
      '.git',
      'build',
      '.gradle',
      'Pods',
    }.contains(name);

bool _shouldSkipFile(String name) {
  if (name.endsWith('.g.dart')) return true;
  return const <String>{
    '.DS_Store',
    'pubspec.lock',
    '.flutter-plugins',
    '.flutter-plugins-dependencies',
    '.packages',
    '.metadata',
  }.contains(name);
}

// ─────────────────────────────────────────────────────────────────────
// Recursive copy with skip rules.
// ─────────────────────────────────────────────────────────────────────

bool _verbose = false;

void _vlog(String msg) {
  if (_verbose) print('    $msg');
}

Future<void> _copyDirRecursive(Directory src, Directory dst) async {
  if (!dst.existsSync()) await dst.create(recursive: true);
  await for (final FileSystemEntity e
      in src.list(recursive: false, followLinks: false)) {
    final String name = p.basename(e.path);
    final String dstPath = p.join(dst.path, name);
    if (e is Directory) {
      if (_shouldSkipDir(name)) continue;
      await _copyDirRecursive(e, Directory(dstPath));
    } else if (e is File) {
      if (_shouldSkipFile(name)) continue;
      await e.copy(dstPath);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// README seed.
// ─────────────────────────────────────────────────────────────────────

String _renderReadme({
  required String templatePath,
  required String templateName,
  required String version,
  required String buildId,
  required List<String> vendoredShims,
  required Set<String> companions,
}) {
  String body;
  final File t = File(templatePath);
  if (t.existsSync()) {
    body = t.readAsStringSync();
  } else {
    body = _fallbackReadme();
  }
  body = body
      .replaceAll('{{TEMPLATE_NAME}}', templateName)
      .replaceAll('{{VERSION}}', version)
      .replaceAll('{{BUILD_ID}}', buildId)
      .replaceAll('{{VENDORED_SHIMS}}',
          vendoredShims.isEmpty ? '(none)' : vendoredShims.join(', '))
      .replaceAll('{{COMPANIONS}}',
          companions.isEmpty ? '(none)' : (companions.toList()..sort()).join(', '));
  return body;
}

String _fallbackReadme() => '''
# {{TEMPLATE_NAME}}

Oracular template release **v{{VERSION}}** (build `{{BUILD_ID}}`).

## Quick start

```bash
unzip {{TEMPLATE_NAME}}-v{{VERSION}}.zip -d /tmp/{{TEMPLATE_NAME}}-extract
cd /tmp/{{TEMPLATE_NAME}}-extract
dart run setup.dart --name my_project --org com.example --output-dir ../my_project
cd ../my_project
```

Run `dart run setup.dart --help` for the full flag list, or see
`SETUP_USAGE.md` shipped alongside this README.

## What's inside

| Path | Purpose |
|---|---|
| `setup.dart` | Wizard-equivalent setup script. Zero deps; needs Dart SDK 3.0+. |
| `SETUP_USAGE.md` | Detailed flag reference. |
| `VERSION` | Build manifest (version, build-id, template name). |
| `LICENSE` | Oracular license. |
| `_vendor/` | Optional shim packages: {{VENDORED_SHIMS}}. Used when `--with-models` is passed. |
| (everything else) | The template payload itself. |

## Companion templates

This template supports companion packages: {{COMPANIONS}}.

Pass `--with-models` / `--with-server` to `setup.dart` when invoking;
if those companion ZIPs are downloaded into the same staging directory
alongside this one, the script wires them up automatically. Otherwise
`setup.dart` prints a hint pointing at their Release URL.

## Bugs

File issues at https://github.com/ArcaneArts/oracular/issues.
''';

// ─────────────────────────────────────────────────────────────────────
// Companion-package set per template (informational; printed in README).
// ─────────────────────────────────────────────────────────────────────

Set<String> _companionsFor(String template) {
  if (template == 'arcane_models' || template == 'arcane_server') {
    return <String>{};
  }
  return <String>{'arcane_models', 'arcane_server'};
}

// ─────────────────────────────────────────────────────────────────────
// Touch every file under [dir] to [mtime] for ZIP determinism.
// ─────────────────────────────────────────────────────────────────────

Future<void> _touchAll(Directory dir, DateTime mtime) async {
  await for (final FileSystemEntity e in dir.list(recursive: true)) {
    if (e is File) {
      try {
        await e.setLastModified(mtime);
      } catch (_) {
        // best-effort: some filesystems don't allow setting mtime on
        // certain extensions (e.g. symlinks). Determinism is a nicety.
      }
    }
  }
}

/// Parse the UTC ISO 8601 stamp out of a build-id like
/// `3.5.0+20260511T143022Z-c7bcf2a`. Returns null if the format
/// doesn't match (e.g. `3.5.0+devlocal-...`).
DateTime? _utcFromBuildId(String buildId) {
  final RegExpMatch? m = RegExp(
          r'\+(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z')
      .firstMatch(buildId);
  if (m == null) return null;
  return DateTime.utc(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
    int.parse(m.group(4)!),
    int.parse(m.group(5)!),
    int.parse(m.group(6)!),
  );
}

// ─────────────────────────────────────────────────────────────────────
// Main flow.
// ─────────────────────────────────────────────────────────────────────

Future<int> _run(List<String> rawArgs) async {
  _Args args;
  try {
    args = _parseArgs(rawArgs);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    _printHelp();
    return 64;
  }

  if (args.help) {
    _printHelp();
    return 0;
  }

  _verbose = args.verbose;

  // Required.
  if (args.template == null ||
      args.version == null ||
      args.buildId == null ||
      args.setupScriptPath == null) {
    stderr.writeln(
        'Error: --template, --version, --build-id, and --setup-script are required.');
    _printHelp();
    return 64;
  }

  final String template = args.template!;
  final String version = args.version!;
  final String buildId = args.buildId!;
  final String setupScript = args.setupScriptPath!;

  if (!_kKnownTemplates.contains(template)) {
    stderr.writeln(
        'Error: unknown template "$template". Known: ${(_kKnownTemplates.toList()..sort()).join(", ")}');
    return 64;
  }

  final Directory tplDir =
      Directory(p.join(args.templatesRoot, template));
  if (!tplDir.existsSync()) {
    stderr.writeln('Error: template directory not found: ${tplDir.path}');
    return 66;
  }

  final File setupScriptFile = File(setupScript);
  if (!setupScriptFile.existsSync()) {
    stderr.writeln('Error: setup script not found: $setupScript');
    return 66;
  }

  // Staging.
  final Directory outDir = Directory(args.outDir);
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  final Directory stagingRoot = Directory(p.join(outDir.path, '_staging'));
  if (stagingRoot.existsSync()) stagingRoot.deleteSync(recursive: true);
  stagingRoot.createSync(recursive: true);
  final Directory stage = Directory(p.join(stagingRoot.path, template));
  stage.createSync(recursive: true);

  print('Packaging $template v$version...');
  _vlog('Staging at ${stage.path}');

  // 1. Copy template files.
  await _copyDirRecursive(tplDir, stage);

  // 2. Vendor shims (only for templates that need them).
  final List<String> shims = _vendorShimsFor(template);
  if (shims.isNotEmpty) {
    final Directory vendorSrc =
        Directory(p.join(args.templatesRoot, '_vendor'));
    if (!vendorSrc.existsSync()) {
      stderr.writeln(
          'Warning: ${vendorSrc.path} missing; skipping vendor shims.');
    } else {
      final Directory vendorDst =
          Directory(p.join(stage.path, '_vendor'));
      vendorDst.createSync(recursive: true);
      for (final String shim in shims) {
        final Directory src = Directory(p.join(vendorSrc.path, shim));
        if (!src.existsSync()) {
          stderr.writeln('Warning: vendor shim missing: ${src.path}');
          continue;
        }
        final Directory dst = Directory(p.join(vendorDst.path, shim));
        await _copyDirRecursive(src, dst);
        _vlog('Vendored $shim');
      }
    }
  }

  // 3. setup.dart at staging root.
  final File stagedSetup = File(p.join(stage.path, 'setup.dart'));
  setupScriptFile.copySync(stagedSetup.path);

  // We need to bake the template name into THIS copy of setup.dart so
  // that the runtime detection works even if the user invokes it
  // without the VERSION file (e.g. they moved the script to a sibling
  // dir). The substitution is idempotent and the same pattern the
  // generator uses, so we can do it inline.
  String setupSrc = stagedSetup.readAsStringSync();
  setupSrc = _bakeTemplateNameInto(setupSrc, template);
  stagedSetup.writeAsStringSync(setupSrc);

  // 4. README.
  final Set<String> companions = _companionsFor(template);
  final String readme = _renderReadme(
    templatePath: args.readmeTemplatePath,
    templateName: template,
    version: version,
    buildId: buildId,
    vendoredShims: shims,
    companions: companions,
  );
  File(p.join(stage.path, 'README.md')).writeAsStringSync(readme);

  // 5. VERSION file (consumed by setup.dart's VersionFile.readFromCwd).
  final StringBuffer ver = StringBuffer()
    ..writeln('ORACULAR_VERSION=$version')
    ..writeln('BUILD_ID=$buildId')
    ..writeln('TEMPLATE=$template');
  File(p.join(stage.path, 'VERSION')).writeAsStringSync(ver.toString());

  // 6. LICENSE.
  final File licenseSrc = File(args.licensePath);
  if (licenseSrc.existsSync()) {
    licenseSrc.copySync(p.join(stage.path, 'LICENSE'));
  } else {
    stderr.writeln(
        'Warning: ${args.licensePath} not found; LICENSE not included.');
  }

  // 7. SETUP_USAGE.md (optional; ships if the source file exists).
  final File usageSrc = File('templates/SETUP_USAGE.md');
  if (usageSrc.existsSync()) {
    usageSrc.copySync(p.join(stage.path, 'SETUP_USAGE.md'));
  }

  // 8. Touch for determinism.
  final DateTime mtime = _utcFromBuildId(buildId) ?? DateTime.utc(2020, 1, 1);
  await _touchAll(stage, mtime);

  // 9. Zip.
  final String zipName = '$template-v$version.zip';
  final String zipPath = p.join(outDir.path, zipName);
  final ZipFileEncoder encoder = ZipFileEncoder();
  try {
    await encoder.zipDirectory(
      stage,
      filename: zipPath,
      modified: mtime,
    );
  } finally {
    // ZipFileEncoder.close is invoked inside zipDirectory; no extra
    // cleanup needed here.
  }
  final int sizeKb = (File(zipPath).lengthSync() / 1024).round();
  print('[\u2713] $zipPath ($sizeKb KB)');

  // 10. Cleanup.
  if (!args.keepStaging) {
    stagingRoot.deleteSync(recursive: true);
  } else {
    _vlog('Kept staging at ${stagingRoot.path}');
  }

  return 0;
}

/// Replace `kTemplateNameDefault = '...'` with the given template name.
/// Idempotent — if it's already baked, this is a no-op.
String _bakeTemplateNameInto(String setupSrc, String templateName) {
  final RegExp re = RegExp(
    r"(const String kTemplateNameDefault = ')([^']*)(')",
  );
  return setupSrc.replaceFirst(
    re,
    "const String kTemplateNameDefault = '$templateName'",
  );
}

Future<void> main(List<String> args) async {
  final int code = await _run(args);
  if (code != 0) exitCode = code;
}
