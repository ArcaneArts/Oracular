#!/usr/bin/env dart
// ignore_for_file: avoid_print
//
// generate_setup_script.dart — emits `dist/setup.dart` from the skeleton
// at `scripts/setup_template_template.dart`.
//
// What it does:
//   1. Reads the skeleton (default `scripts/setup_template_template.dart`)
//   2. Substitutes `__GENERATED:*__`-marked default constants with the
//      values from `--version` / `--build-id` / `--template-name`
//   3. Writes the result to `dist/setup.dart` (or `--out` target)
//   4. Optionally runs `dart analyze` over the output to verify it still
//      compiles cleanly
//
// Per the plan §4.3, this is the v1 fallback: hand-ported skeleton +
// substitution generator. The skeleton's correctness is enforced by
// `oracular/test/unit/setup_script_parity_test.dart` (T3.1), which
// diffs the relevant function bodies against the canonical
// `PlaceholderReplacer` source and fails CI on drift.
//
// CLI:
//   dart run scripts/generate_setup_script.dart \
//     --version 3.5.0 \
//     --build-id 3.5.0+20260511T143022Z-c7bcf2a \
//     [--template-name arcane_app] \
//     [--in  scripts/setup_template_template.dart] \
//     [--out dist/setup.dart] \
//     [--no-analyze] \
//     [--verbose]
//
// When `--version` is omitted the script reads
// `oracular/pubspec.yaml` and uses its `version:` line as the source
// of truth (matches plan §5.1).
//
// When `--build-id` is omitted the script synthesises
// `<version>+devlocal-<short-utc>` so local invocations are usable.

import 'dart:io';

const String _kDefaultIn = 'scripts/setup_template_template.dart';
const String _kDefaultOut = 'dist/setup.dart';

class _Args {
  String? version;
  String? buildId;
  String? templateName;
  String inputPath = _kDefaultIn;
  String outputPath = _kDefaultOut;
  bool analyze = true;
  bool verbose = false;
  bool help = false;
}

void _printHelp() {
  print('''
generate_setup_script.dart — bake setup.dart from skeleton

USAGE
  dart run scripts/generate_setup_script.dart [options]

OPTIONS
  --version <X.Y.Z>            Oracular release version (default: read
                               from oracular/pubspec.yaml).
  --build-id <id>              Build identifier embedded in the ZIP's
                               VERSION file (default: synthesized).
  --template-name <name>       Bake a default template name into the
                               script. (Optional; if omitted, setup.dart
                               auto-detects from the VERSION file in the
                               ZIP root at runtime.)
  --in <path>                  Skeleton input (default: $_kDefaultIn).
  --out <path>                 Output file (default: $_kDefaultOut).
  --no-analyze                 Skip running `dart analyze` over the
                               generated file.
  -v, --verbose                Verbose logging.
  -h, --help                   This help.

EXAMPLES
  dart run scripts/generate_setup_script.dart
  dart run scripts/generate_setup_script.dart --version 3.5.0 \\
      --build-id '3.5.0+20260511T143022Z-c7bcf2a'
''');
}

_Args _parseArgs(List<String> raw) {
  final _Args a = _Args();
  for (int i = 0; i < raw.length; i++) {
    final String arg = raw[i];
    String? takeNext(String flag) {
      if (i + 1 >= raw.length) {
        throw FormatException('$flag requires a value');
      }
      return raw[++i];
    }

    switch (arg) {
      case '--version':
        a.version = takeNext(arg);
      case '--build-id':
        a.buildId = takeNext(arg);
      case '--template-name':
        a.templateName = takeNext(arg);
      case '--in':
        a.inputPath = takeNext(arg)!;
      case '--out':
        a.outputPath = takeNext(arg)!;
      case '--no-analyze':
        a.analyze = false;
      case '-v':
      case '--verbose':
        a.verbose = true;
      case '-h':
      case '--help':
        a.help = true;
      default:
        if (arg.startsWith('--version=')) {
          a.version = arg.substring('--version='.length);
        } else if (arg.startsWith('--build-id=')) {
          a.buildId = arg.substring('--build-id='.length);
        } else if (arg.startsWith('--template-name=')) {
          a.templateName = arg.substring('--template-name='.length);
        } else if (arg.startsWith('--in=')) {
          a.inputPath = arg.substring('--in='.length);
        } else if (arg.startsWith('--out=')) {
          a.outputPath = arg.substring('--out='.length);
        } else {
          throw FormatException('Unknown argument: $arg');
        }
    }
  }
  return a;
}

/// Reads `oracular/pubspec.yaml` from the repo root and extracts
/// `version: X.Y.Z`. The pubspec is the authoritative source per §5.1.
String _readPubspecVersion() {
  final List<String> candidates = <String>[
    'oracular/pubspec.yaml',
    '../oracular/pubspec.yaml',
  ];
  File? found;
  for (final String p in candidates) {
    final File f = File(p);
    if (f.existsSync()) {
      found = f;
      break;
    }
  }
  if (found == null) {
    throw StateError(
        'Could not find oracular/pubspec.yaml. Run from repo root or pass --version.');
  }
  final List<String> lines = found.readAsLinesSync();
  for (final String line in lines) {
    final RegExpMatch? m =
        RegExp(r'^version:\s*([^\s#]+)').firstMatch(line);
    if (m != null) {
      return m.group(1)!;
    }
  }
  throw StateError('No `version:` line found in ${found.path}.');
}

/// Sanity-check that `oracular/lib/version.dart` matches the pubspec
/// version. Per plan §5.4, the workflow must fail fast on a mismatch.
void _verifyMirrorVersion(String pubspecVersion) {
  final List<String> candidates = <String>[
    'oracular/lib/version.dart',
    '../oracular/lib/version.dart',
  ];
  File? f;
  for (final String p in candidates) {
    final File c = File(p);
    if (c.existsSync()) {
      f = c;
      break;
    }
  }
  if (f == null) return; // Mirror file optional in local-only runs.
  final String content = f.readAsStringSync();
  final RegExpMatch? m =
      RegExp(r"oracularVersion\s*=\s*'([^']+)'").firstMatch(content);
  if (m == null) return;
  final String mirror = m.group(1)!;
  if (mirror != pubspecVersion) {
    throw StateError(
        'Version mismatch: oracular/pubspec.yaml=$pubspecVersion '
        'but oracular/lib/version.dart=$mirror. Bring them in sync.');
  }
}

String _utcStamp() {
  final DateTime now = DateTime.now().toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${now.year}'
      '${two(now.month)}${two(now.day)}'
      'T${two(now.hour)}${two(now.minute)}${two(now.second)}Z';
}

/// Replace the literal string immediately after a `// __GENERATED:KEY__`
/// marker. Specifically: each marker is followed on the next line by a
/// `const String kFoo = '...';` declaration, and we rewrite the `...`.
String _substituteMarker(String source, String key, String newValue) {
  final RegExp marker = RegExp(
    '(^// __GENERATED:${RegExp.escape(key)}__\n'
    r"^const String \w+ = ')([^']*)(';\s*$)",
    multiLine: true,
  );
  final RegExpMatch? m = marker.firstMatch(source);
  if (m == null) {
    throw StateError(
        'Marker __GENERATED:${key}__ not found in skeleton or '
        'declaration not on the next line.');
  }
  return source.replaceFirstMapped(marker, (Match match) {
    return '${match.group(1)}$newValue${match.group(3)}';
  });
}

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

  // 1. Resolve version.
  final String version;
  try {
    version = args.version ?? _readPubspecVersion();
    _verifyMirrorVersion(version);
  } on StateError catch (e) {
    stderr.writeln('[\u2717] ${e.message}');
    return 65;
  }

  // 2. Resolve build id.
  final String buildId = args.buildId ?? '$version+devlocal-${_utcStamp()}';

  // 3. Resolve template name (allowed to be empty; auto-detected at runtime).
  final String templateName = args.templateName ?? '';

  // 4. Read skeleton.
  final File inFile = File(args.inputPath);
  if (!inFile.existsSync()) {
    stderr.writeln('Skeleton not found at: ${args.inputPath}');
    return 66;
  }
  String src = inFile.readAsStringSync();

  if (args.verbose) {
    print('[i] Skeleton: ${args.inputPath} (${src.length} chars)');
    print('[i] Version : $version');
    print('[i] BuildId : $buildId');
    print('[i] Template: ${templateName.isEmpty ? "(auto)" : templateName}');
  }

  // 5. Substitute markers.
  src = _substituteMarker(src, 'ORACULAR_VERSION', version);
  src = _substituteMarker(src, 'BUILD_ID', buildId);
  src = _substituteMarker(src, 'TEMPLATE_NAME_DEFAULT', templateName);

  // 6. Emit.
  final File outFile = File(args.outputPath);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(src);

  // Make it executable on POSIX so users can `./setup.dart` if they want.
  if (!Platform.isWindows) {
    try {
      Process.runSync('chmod', <String>['+x', outFile.path]);
    } catch (_) {
      // best-effort
    }
  }

  print('[\u2713] Wrote ${outFile.path} (${src.length} chars)');

  // 7. Optional analyze.
  if (args.analyze) {
    final ProcessResult r = await Process.run(
        'dart', <String>['analyze', outFile.path]);
    final String stdoutStr = (r.stdout as String).trim();
    final String stderrStr = (r.stderr as String).trim();
    if (r.exitCode != 0) {
      stderr.writeln('[\u2717] dart analyze failed on generated file:');
      if (stdoutStr.isNotEmpty) stderr.writeln(stdoutStr);
      if (stderrStr.isNotEmpty) stderr.writeln(stderrStr);
      return r.exitCode;
    }
    if (args.verbose && stdoutStr.isNotEmpty) {
      print(stdoutStr);
    }
    print('[\u2713] dart analyze: clean');
  }

  return 0;
}

Future<void> main(List<String> args) async {
  final int code = await _run(args);
  if (code != 0) exitCode = code;
}
