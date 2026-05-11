#!/usr/bin/env dart
// ignore_for_file: avoid_print
//
// setup.dart — standalone wizard-replacement for Oracular templates.
//
// Ships inside every `<template>-vX.Y.Z.zip` Release asset. Given a few
// CLI flags (`--name`, `--org`, etc.) it produces the same on-disk
// result that `oracular create -y -t <template> -n <name>` produces.
//
// Zero external dependencies — only the Dart SDK (3.0+) is required.
// Do NOT add `package:` imports here; this file must `dart run` from a
// freshly-extracted ZIP before `pub get` has populated `.dart_tool/`.
//
// This file is hand-ported from:
//   * oracular/lib/services/placeholder_replacer.dart:54-227
//   * oracular/lib/services/template_copier.dart:282-502
//   * oracular/lib/utils/validators.dart:23-203
//   * oracular/lib/utils/string_utils.dart:5-22
//
// Keep in sync. `oracular/test/unit/setup_script_parity_test.dart`
// (T3.1) fails CI when the rules drift.

library;

import 'dart:async';
import 'dart:io';

// ─────────────────────────────────────────────────────────────────────
// 1. Constants populated by `scripts/generate_setup_script.dart` when
//    the file is emitted to `dist/setup.dart`. The skeleton values are
//    placeholders so the file is still runnable as-is for testing.
// ─────────────────────────────────────────────────────────────────────

// __GENERATED:ORACULAR_VERSION__
const String kOracularVersionDefault = 'dev';

// __GENERATED:BUILD_ID__
const String kBuildIdDefault = 'dev+unknown';

// __GENERATED:TEMPLATE_NAME_DEFAULT__
const String kTemplateNameDefault = '';

// ─────────────────────────────────────────────────────────────────────
// 2. Tiny helpers (replace `package:path` / `package:fast_log` deps).
// ─────────────────────────────────────────────────────────────────────

final String _sep = Platform.pathSeparator;

String pJoin(String a, [String? b, String? c, String? d]) {
  final List<String> parts = <String>[a, ?b, ?c, ?d];
  return parts
      .map((String s) => s.replaceAll('/', _sep))
      .where((String s) => s.isNotEmpty)
      .reduce((String acc, String x) {
    if (acc.endsWith(_sep)) return acc + x;
    return '$acc$_sep$x';
  });
}

String pBasename(String path) {
  final String normalized = path.replaceAll('/', _sep);
  final int idx = normalized.lastIndexOf(_sep);
  return idx < 0 ? normalized : normalized.substring(idx + 1);
}

String pDirname(String path) {
  final String normalized = path.replaceAll('/', _sep);
  final int idx = normalized.lastIndexOf(_sep);
  if (idx < 0) return '.';
  if (idx == 0) return _sep;
  return normalized.substring(0, idx);
}

String pExtension(String path) {
  final String base = pBasename(path);
  final int idx = base.lastIndexOf('.');
  if (idx <= 0) return ''; // leading dot = hidden file, no extension
  return base.substring(idx);
}

String pNormalize(String path) {
  final List<String> parts = path
      .replaceAll('/', _sep)
      .split(_sep)
      .where((String s) => s.isNotEmpty)
      .toList();
  final List<String> out = <String>[];
  for (final String part in parts) {
    if (part == '.') continue;
    if (part == '..' && out.isNotEmpty && out.last != '..') {
      out.removeLast();
    } else {
      out.add(part);
    }
  }
  final bool isAbsolute = path.startsWith(_sep) || path.startsWith('/');
  return (isAbsolute ? _sep : '') + out.join(_sep);
}

// ─────────────────────────────────────────────────────────────────────
// 3. Logging — colored when stdout is a terminal.
// ─────────────────────────────────────────────────────────────────────

bool _useColor = stdout.hasTerminal && !Platform.environment.containsKey('NO_COLOR');

String _ansi(String code, String text) =>
    _useColor ? '\x1b[${code}m$text\x1b[0m' : text;

void logInfo(String msg) => print(_ansi('36', '[i] ') + msg);
void logSuccess(String msg) => print(_ansi('32', '[\u2713] ') + msg);
void logWarn(String msg) => print(_ansi('33', '[!] ') + msg);
void logError(String msg) => stderr.writeln(_ansi('31', '[\u2717] ') + msg);
void logVerbose(String msg) {
  if (SetupOptions.current?.verbose ?? false) {
    print(_ansi('90', '    ') + msg);
  }
}

// ─────────────────────────────────────────────────────────────────────
// 4. CLI argument parsing — hand-rolled (no `args` package).
// ─────────────────────────────────────────────────────────────────────

const Map<String, String> _shortToLong = <String, String>{
  'n': 'name',
  'o': 'org',
  'c': 'class-name',
  'd': 'output-dir',
  't': 'template',
  'R': 'render-mode',
  'm': 'with-models',
  's': 'with-server',
  'f': 'with-firebase',
  'p': 'firebase-project-id',
  'P': 'platforms',
  'y': 'yes',
  'h': 'help',
  'v': 'verbose',
};

const Set<String> _flagNames = <String>{
  'with-models',
  'with-server',
  'with-firebase',
  'no-pub-get',
  'install-oracular',
  'no-install-oracular',
  'dry-run',
  'yes',
  'help',
  'verbose',
  'no-color',
};

Map<String, dynamic> parseArgs(List<String> rawArgs) {
  final Map<String, dynamic> out = <String, dynamic>{};
  final List<String> remaining = <String>[];

  for (int i = 0; i < rawArgs.length; i++) {
    String arg = rawArgs[i];

    // Long form: --name value, --name=value, or boolean --flag
    if (arg.startsWith('--')) {
      final String body = arg.substring(2);
      String key;
      String? value;
      if (body.contains('=')) {
        final int eq = body.indexOf('=');
        key = body.substring(0, eq);
        value = body.substring(eq + 1);
      } else {
        key = body;
        value = null;
      }
      if (_flagNames.contains(key)) {
        out[key] = value == null ? true : (value.toLowerCase() == 'true');
      } else {
        if (value == null && i + 1 < rawArgs.length) {
          value = rawArgs[++i];
        }
        if (value == null) {
          throw FormatException('Flag --$key requires a value');
        }
        out[key] = value;
      }
      continue;
    }

    // Short form: -y or -n value
    if (arg.startsWith('-') && arg.length > 1) {
      final String letter = arg.substring(1, 2);
      final String? long = _shortToLong[letter];
      if (long == null) {
        throw FormatException('Unknown short flag: -$letter');
      }
      // Remainder after letter is either '=value' or attached value
      String? attached;
      if (arg.length > 2) {
        attached = arg.substring(2);
        if (attached.startsWith('=')) attached = attached.substring(1);
      }
      if (_flagNames.contains(long)) {
        out[long] = true;
      } else {
        String? value = attached;
        if (value == null && i + 1 < rawArgs.length) {
          value = rawArgs[++i];
        }
        if (value == null) {
          throw FormatException('Flag -$letter requires a value');
        }
        out[long] = value;
      }
      continue;
    }

    remaining.add(arg);
  }

  if (remaining.isNotEmpty) {
    out['_remaining'] = remaining;
  }
  return out;
}

void printHelp() {
  final String tpl =
      kTemplateNameDefault.isEmpty ? '<template>' : kTemplateNameDefault;
  print('''
setup.dart — Oracular template setup ($tpl, oracular v$kOracularVersionDefault)

USAGE
  dart run setup.dart --name <snake_case> --org <com.example> [options]

REQUIRED
  -n, --name <snake_case>          Project name (lowercase, snake_case)
  -o, --org <reverse.domain>       Organization domain (e.g. com.example)

OPTIONAL
  -c, --class-name <PascalCase>    Base class name (auto from --name)
  -d, --output-dir <path>          Where to write the project (default: .)
  -t, --template <name>            Override auto-detected template
  -R, --render-mode <mode>         Jaspr: csr|ssg|ssr|hybrid|embed
  -m, --with-models                Add models package alongside
  -s, --with-server                Add server package alongside
  -f, --with-firebase              Uncomment Firebase deps
  -p, --firebase-project-id <id>   Required when --with-firebase is set
  -P, --platforms <a,b,c>          Flutter platforms (default: template max)
      --no-pub-get                 Skip running pub get at the end
      --install-oracular           Install oracular CLI without prompting
      --no-install-oracular        Skip the oracular install offer
      --dry-run                    Show what would happen; touch nothing
  -y, --yes                        Accept all defaults / non-interactive
  -v, --verbose                    Print every file touched
      --no-color                   Disable ANSI colors
  -h, --help                       This help

EXAMPLES
  dart run setup.dart -n my_app -o com.example
  dart run setup.dart -n my_app -o com.example -m -s -y
  dart run setup.dart -n my_site -o com.example -R ssr
  dart run setup.dart -n my_site -o com.example -R hybrid --install-oracular

See SETUP_USAGE.md inside this ZIP for a full reference.
''');
}

// ─────────────────────────────────────────────────────────────────────
// 5. Validation (ported from oracular/lib/utils/validators.dart).
// ─────────────────────────────────────────────────────────────────────

const List<String> _dartReservedWords = <String>[
  'abstract', 'as', 'assert', 'async', 'await', 'break', 'case',
  'catch', 'class', 'const', 'continue', 'covariant', 'default',
  'deferred', 'do', 'dynamic', 'else', 'enum', 'export', 'extends',
  'extension', 'external', 'factory', 'false', 'final', 'finally',
  'for', 'function', 'get', 'hide', 'if', 'implements', 'import', 'in',
  'interface', 'is', 'late', 'library', 'mixin', 'new', 'null', 'on',
  'operator', 'part', 'required', 'rethrow', 'return', 'set', 'show',
  'static', 'super', 'switch', 'sync', 'this', 'throw', 'true', 'try',
  'typedef', 'var', 'void', 'while', 'with', 'yield',
];

String? validateAppName(String name) {
  if (name.isEmpty) return 'App name cannot be empty';
  if (name.contains(' ')) return 'App name cannot contain spaces';
  if (name != name.toLowerCase()) return 'App name must be lowercase';
  if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
    return 'App name must start with a letter and contain only lowercase '
        'letters, numbers, and underscores';
  }
  if (_dartReservedWords.contains(name)) {
    return '"$name" is a Dart reserved word';
  }
  return null;
}

String? validateOrgDomain(String domain) {
  if (domain.isEmpty) return 'Organization domain cannot be empty';
  if (domain.contains(' ')) return 'Organization domain cannot contain spaces';
  if (!RegExp(r'^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$')
      .hasMatch(domain.toLowerCase())) {
    return 'Organization domain should be in reverse notation '
        '(e.g., com.example, art.arcane)';
  }
  return null;
}

String? validateFirebaseProjectId(String id) {
  if (id.isEmpty) return 'Firebase project ID cannot be empty';
  if (id.contains(' ')) return 'Firebase project ID cannot contain spaces';
  if (id.length < 6 || id.length > 30) {
    return 'Firebase project ID must be between 6 and 30 characters';
  }
  if (!RegExp(r'^[a-z][a-z0-9-]*[a-z0-9]$').hasMatch(id)) {
    return 'Firebase project ID must start with a letter, contain only '
        'lowercase letters, numbers, and hyphens';
  }
  return null;
}

String snakeToPascal(String snake) {
  if (snake.isEmpty) return snake;
  return snake
      .split('_')
      .map((String w) => w.isEmpty
          ? ''
          : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join();
}

// ─────────────────────────────────────────────────────────────────────
// 6. Setup options — single source of truth, populated from CLI args.
// ─────────────────────────────────────────────────────────────────────

enum InstallOfferDecision { prompt, yes, no }

enum JasprRenderMode { csr, ssg, ssr, hybrid, embed }

JasprRenderMode? parseRenderMode(String? value) {
  if (value == null) return null;
  switch (value.trim().toLowerCase()) {
    case 'csr':
    case 'client':
      return JasprRenderMode.csr;
    case 'ssg':
    case 'static':
      return JasprRenderMode.ssg;
    case 'ssr':
    case 'server':
      return JasprRenderMode.ssr;
    case 'hybrid':
    case 'mixed':
      return JasprRenderMode.hybrid;
    case 'embed':
    case 'flutter-embed':
    case 'flutter_embed':
      return JasprRenderMode.embed;
  }
  return null;
}

String renderModeToYaml(JasprRenderMode m) {
  switch (m) {
    case JasprRenderMode.csr:
      return 'client';
    case JasprRenderMode.ssg:
    case JasprRenderMode.embed:
      return 'static';
    case JasprRenderMode.ssr:
    case JasprRenderMode.hybrid:
      return 'server';
  }
}

class SetupOptions {
  static SetupOptions? current;

  final String appName;
  final String orgDomain;
  final String baseClassName;
  final String outputDir;
  final String template;
  final JasprRenderMode? renderMode;
  final bool withModels;
  final bool withServer;
  final bool withFirebase;
  final String? firebaseProjectId;
  final List<String>? platforms;
  final bool noPubGet;
  final bool dryRun;
  final bool yes;
  final bool verbose;
  final InstallOfferDecision installOffer;
  final String oracularVersion;
  final String templateName;

  SetupOptions({
    required this.appName,
    required this.orgDomain,
    required this.baseClassName,
    required this.outputDir,
    required this.template,
    required this.renderMode,
    required this.withModels,
    required this.withServer,
    required this.withFirebase,
    required this.firebaseProjectId,
    required this.platforms,
    required this.noPubGet,
    required this.dryRun,
    required this.yes,
    required this.verbose,
    required this.installOffer,
    required this.oracularVersion,
    required this.templateName,
  });

  // Derived names — mirror SetupConfig getters in
  // oracular/lib/models/setup_config.dart:381-403.
  String get webPackageName => '${appName}_web';
  String get modelsPackageName => '${appName}_models';
  String get serverPackageName => '${appName}_server';
  String get embeddedFlutterPackageName => '${appName}_app';
  String get webClassName => '${baseClassName}Web';
  String get serverClassName => '${baseClassName}Server';
  String get runnerClassName => '${baseClassName}Runner';
  String get embeddedFlutterClassName => '${baseClassName}App';

  bool get isJasprTemplate =>
      template == 'arcane_jaspr_app' ||
      template == 'arcane_jaspr_docs' ||
      template == 'arcane_jaspr_flutter_embed';

  bool get isJasprFlutterEmbed => template == 'arcane_jaspr_flutter_embed';

  bool get isFlutterApp =>
      template == 'arcane_app' ||
      template == 'arcane_beamer_app' ||
      template == 'arcane_dock_app';

  bool get isDartCli => template == 'arcane_cli_app';

  bool get isStandaloneModels => template == 'arcane_models';

  bool get isStandaloneServer => template == 'arcane_server';

  /// Name + class for the *primary* package this ZIP produces. For most
  /// templates that's the app/web package, but the standalone
  /// `arcane_models` and `arcane_server` ZIPs produce a single
  /// companion-style package — name it accordingly.
  String get primaryPackageName {
    if (isStandaloneModels) return modelsPackageName;
    if (isStandaloneServer) return serverPackageName;
    if (isJasprTemplate) return webPackageName;
    return appName;
  }
}

// ─────────────────────────────────────────────────────────────────────
// 7. Template-name detection. Reads the `VERSION` file that the
//    packager (T1.4) drops into every ZIP's root.
// ─────────────────────────────────────────────────────────────────────

class VersionFile {
  final String oracularVersion;
  final String buildId;
  final String templateName;
  VersionFile(this.oracularVersion, this.buildId, this.templateName);

  static VersionFile? readFromCwd() {
    final File f = File('VERSION');
    if (!f.existsSync()) return null;
    final List<String> lines =
        f.readAsLinesSync().where((String l) => l.trim().isNotEmpty).toList();
    final Map<String, String> kv = <String, String>{};
    for (final String line in lines) {
      final int eq = line.indexOf('=');
      if (eq <= 0) continue;
      kv[line.substring(0, eq).trim()] = line.substring(eq + 1).trim();
    }
    return VersionFile(
      kv['ORACULAR_VERSION'] ?? kOracularVersionDefault,
      kv['BUILD_ID'] ?? kBuildIdDefault,
      kv['TEMPLATE'] ?? kTemplateNameDefault,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 8. Placeholder replacer — ported from
//    oracular/lib/services/placeholder_replacer.dart:54-227.
//    ORDER MATTERS. Longer / more specific tokens are replaced first
//    so they never get partially clobbered by a later rule.
// ─────────────────────────────────────────────────────────────────────

const List<String> _textFileExtensions = <String>[
  '.dart', '.yaml', '.yml', '.json', '.md', '.txt', '.sh',
  '.xml', '.plist', '.xcconfig', '.xcscheme', '.pbxproj',
  '.swift', '.kt', '.kts', '.gradle', '.properties',
  '.cc', '.h', '.cmake', '.html', '.js', '.css',
  '.entitlements', '.storyboard', '.xib', '.xcworkspacedata',
];

bool _shouldProcessTextFile(String path) =>
    _textFileExtensions.contains(pExtension(path).toLowerCase());

String replaceInContent(String content, SetupOptions o) {
  String r = content;

  // 1. PascalCase class names — longest first so embed-template names
  //    don't get half-touched by generic ArcaneJasprApp.
  r = r.replaceAll('ArcaneJasprFlutterEmbedWeb', o.webClassName);
  r = r.replaceAll('ArcaneJasprFlutterEmbedApp', o.embeddedFlutterClassName);
  r = r.replaceAll('ArcaneServer', o.serverClassName);
  r = r.replaceAll('ArcaneRunner', o.runnerClassName);
  r = r.replaceAll('ArcaneJasprApp', o.webClassName);

  // 2. Package imports — longest first.
  r = r.replaceAll('package:arcane_jaspr_flutter_embed_web/',
      'package:${o.webPackageName}/');
  r = r.replaceAll('package:arcane_jaspr_flutter_embed_app/',
      'package:${o.embeddedFlutterPackageName}/');
  r = r.replaceAll('package:arcane_jaspr_docs/', 'package:${o.webPackageName}/');
  r = r.replaceAll('package:arcane_jaspr_app/', 'package:${o.webPackageName}/');
  r = r.replaceAll('package:arcane_beamer_app/', 'package:${o.appName}/');
  r = r.replaceAll('package:arcane_dock_app/', 'package:${o.appName}/');
  r = r.replaceAll('package:arcane_cli_app/', 'package:${o.appName}/');
  r = r.replaceAll('package:arcane_app/', 'package:${o.appName}/');

  // 3. Models package refs.
  r = r.replaceAll('package:arcane_models/', 'package:${o.modelsPackageName}/');
  r = r.replaceAll('arcane_models', o.modelsPackageName);

  // 4. Server package refs.
  r = r.replaceAll('arcane_server', o.serverPackageName);

  // 5. App name in identifiers / strings — longest first.
  r = r.replaceAll('arcane_jaspr_flutter_embed_web', o.webPackageName);
  r = r.replaceAll('arcane_jaspr_flutter_embed_app',
      o.embeddedFlutterPackageName);
  r = r.replaceAll('arcane_jaspr_docs', o.webPackageName);
  r = r.replaceAll('arcane_jaspr_app', o.webPackageName);
  r = r.replaceAll('arcane_beamer_app', o.appName);
  r = r.replaceAll('arcane_dock_app', o.appName);
  r = r.replaceAll('arcane_cli_app', o.appName);
  r = r.replaceAll('arcane_app', o.appName);

  // 6. Firebase project id.
  if (o.firebaseProjectId != null) {
    r = r.replaceAll('FIREBASE_PROJECT_ID', o.firebaseProjectId!);
  }

  // 7. Org domain.
  r = r.replaceAll(
      'art.arcane.template', '${o.orgDomain}.${o.appName.replaceAll('_', '')}');
  r = r.replaceAll('ORG_DOMAIN', o.orgDomain);

  // 8. Display names. Embed must precede generic Jaspr.
  r = r.replaceAll('Arcane Jaspr Flutter Embed', o.baseClassName);
  r = r.replaceAll('Arcane Template', o.baseClassName);
  r = r.replaceAll('Arcane Beamer', o.baseClassName);
  r = r.replaceAll('Arcane Dock', o.baseClassName);
  r = r.replaceAll('Arcane CLI', o.baseClassName);
  r = r.replaceAll('Arcane Jaspr Docs', o.baseClassName);
  r = r.replaceAll('Arcane Jaspr', o.baseClassName);

  return r;
}

String replaceInFilename(String filename, SetupOptions o) {
  String r = filename;
  r = r.replaceAll('arcane_models', o.modelsPackageName);
  r = r.replaceAll('arcane_jaspr_flutter_embed_web', o.webPackageName);
  r = r.replaceAll('arcane_jaspr_flutter_embed_app',
      o.embeddedFlutterPackageName);
  r = r.replaceAll('arcane_jaspr_docs', o.webPackageName);
  r = r.replaceAll('arcane_jaspr_app', o.webPackageName);
  r = r.replaceAll('arcane_cli_app', o.appName);
  r = r.replaceAll('arcane_beamer_app', o.appName);
  r = r.replaceAll('arcane_dock_app', o.appName);
  r = r.replaceAll('arcane_app', o.appName);
  return r;
}

Future<void> processFile(File file, SetupOptions o) async {
  final String path = file.path;

  if (_shouldProcessTextFile(path)) {
    final String content = await file.readAsString();
    final String next = replaceInContent(content, o);
    if (content != next && !o.dryRun) {
      await file.writeAsString(next);
      logVerbose('Replaced placeholders in: ${pBasename(path)}');
    }
  }

  final String fn = pBasename(path);
  final String newFn = replaceInFilename(fn, o);
  if (fn != newFn && !o.dryRun) {
    final String newPath = pJoin(pDirname(path), newFn);
    await file.rename(newPath);
    logVerbose('Renamed: $fn -> $newFn');
  }
}

Future<void> processDirectory(Directory dir, SetupOptions o) async {
  logInfo('Processing placeholders in: ${dir.path}');
  await for (final FileSystemEntity entity in dir.list(recursive: true)) {
    if (entity is File) {
      await processFile(entity, o);
    } else if (entity is Directory) {
      final String dn = pBasename(entity.path);
      final String newDn = replaceInFilename(dn, o);
      if (dn != newDn && !o.dryRun) {
        final String newPath = pJoin(pDirname(entity.path), newDn);
        await entity.rename(newPath);
        logVerbose('Renamed dir: $dn -> $newDn');
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// 9. Pubspec patcher — ported from PlaceholderReplacer.updatePubspec /
//    addModelsDependency / addVendoredOverride.
// ─────────────────────────────────────────────────────────────────────

Future<void> updatePubspec(File pubspecFile, String packageName,
    SetupOptions o) async {
  if (!pubspecFile.existsSync()) return;
  String content = await pubspecFile.readAsString();
  content = content.replaceFirst(
    RegExp(r'^name: .+$', multiLine: true),
    'name: $packageName',
  );

  // NOTE: We deliberately do NOT uncomment the templated `# <name>_models:`
  // hint block here. The CLI's PlaceholderReplacer.updatePubspec attempts
  // the same uncomment with a buggy *raw-string* regex
  // (`r'#\s*${config.modelsPackageName}:'` — `${...}` is literal in raw
  // strings, so the regex never matches). The effective CLI behavior is
  // "leave the commented hint alone; rely on `addModelsDependency` to
  // inject an active block at the top of `dependencies:`". We match that
  // effective behavior here. If we DID uncomment, `addModelsDependency`'s
  // `hasReal` check would short-circuit and we'd lose the path resolution.

  // Uncomment Firebase deps when --with-firebase. (The CLI uses string
  // concatenation here, which works correctly, so we mirror it.)
  if (o.withFirebase) {
    const List<String> firebasePackages = <String>[
      'firebase_core', 'firebase_auth', 'cloud_firestore',
      'firebase_storage', 'firebase_dart', 'arcane_fluf',
      'arcane_auth', 'fire_crud',
    ];
    for (final String pkg in firebasePackages) {
      content = content.replaceAll(RegExp(r'#\s*' + pkg + r':'), '$pkg:');
    }
  }

  if (!o.dryRun) await pubspecFile.writeAsString(content);
  logVerbose('Updated pubspec.yaml -> $packageName');
}

Future<void> addModelsDependency(File pubspecFile, SetupOptions o) async {
  if (!pubspecFile.existsSync()) return;
  String content = await pubspecFile.readAsString();
  final List<String> lines = content.split('\n');
  final String escaped = RegExp.escape(o.modelsPackageName);
  final RegExp realDep = RegExp('^\\s+$escaped:');
  if (lines.any((String l) =>
      realDep.hasMatch(l) && !l.trimLeft().startsWith('#'))) {
    return;
  }
  final RegExp deps = RegExp(r'^dependencies:\s*$', multiLine: true);
  final RegExpMatch? m = deps.firstMatch(content);
  if (m == null) return;
  final String entry =
      '\n\n  ${o.modelsPackageName}:\n    path: ../${o.modelsPackageName}\n';
  content = content.substring(0, m.end) + entry + content.substring(m.end);
  if (!o.dryRun) await pubspecFile.writeAsString(content);
  logVerbose('Added models path dep to ${pBasename(pubspecFile.path)}');
}

/// Inject a *commented-out* models dependency block.
///
/// Used when `--with-models` was requested but the models template isn't
/// bundled in the current ZIP (the per-template ZIP case — only the
/// bundle ZIP ships every template together). Writes:
///
/// ```yaml
/// dependencies:
///
///   # <name>_models:
///   #   path: ../<name>_models
/// ```
///
/// The user can extract `arcane_models-vX.Y.Z.zip` separately, scaffold
/// it as a sibling, and just uncomment two lines instead of editing
/// the pubspec from scratch. This keeps `pub get` green out of the box.
Future<void> addCommentedModelsDependency(
    File pubspecFile, SetupOptions o) async {
  if (!pubspecFile.existsSync()) return;
  String content = await pubspecFile.readAsString();
  final List<String> lines = content.split('\n');
  final String escaped = RegExp.escape(o.modelsPackageName);
  // Skip if the name already appears anywhere (active OR commented) —
  // idempotent re-runs and templates that already ship the
  // commented-out hint don't duplicate.
  final RegExp anyForm = RegExp('$escaped:');
  if (lines.any((String l) => anyForm.hasMatch(l))) {
    logVerbose(
        '${o.modelsPackageName} already referenced in ${pBasename(pubspecFile.path)} — skip commented hint');
    return;
  }
  final RegExp deps = RegExp(r'^dependencies:\s*$', multiLine: true);
  final RegExpMatch? m = deps.firstMatch(content);
  if (m == null) return;
  final String entry =
      '\n\n  # ${o.modelsPackageName}:\n  #   path: ../${o.modelsPackageName}\n';
  content = content.substring(0, m.end) + entry + content.substring(m.end);
  if (!o.dryRun) await pubspecFile.writeAsString(content);
  logVerbose('Added commented models hint to ${pBasename(pubspecFile.path)}');
}

Future<void> addVendoredOverride(
  File pubspecFile, {
  required String packageName,
  required String relativeShimPath,
  required SetupOptions opts,
}) async {
  if (!pubspecFile.existsSync()) return;
  String content = await pubspecFile.readAsString();
  // Idempotent check.
  final List<String> lines = content.split('\n');
  bool inOverrides = false;
  final RegExp entry = RegExp('^\\s+${RegExp.escape(packageName)}:');
  for (final String line in lines) {
    if (line.trimLeft().startsWith('#')) continue;
    if (RegExp(r'^dependency_overrides:\s*$').hasMatch(line)) {
      inOverrides = true;
      continue;
    }
    if (inOverrides && RegExp(r'^[a-zA-Z_]').hasMatch(line)) {
      inOverrides = false;
    }
    if (inOverrides && entry.hasMatch(line)) return;
  }
  final String addition =
      '  $packageName:\n    path: $relativeShimPath\n';
  final RegExp header = RegExp(r'^dependency_overrides:\s*$', multiLine: true);
  final RegExpMatch? h = header.firstMatch(content);
  if (h != null) {
    content = '${content.substring(0, h.end)}\n$addition${content.substring(h.end)}';
  } else {
    if (!content.endsWith('\n')) content += '\n';
    content += '\ndependency_overrides:\n$addition';
  }
  if (!opts.dryRun) await pubspecFile.writeAsString(content);
}

// ─────────────────────────────────────────────────────────────────────
// 10. Jaspr render-mode patcher — ported from
//     oracular/lib/services/template_copier.dart:282-392.
// ─────────────────────────────────────────────────────────────────────

Future<void> patchJasprYamlMode(Directory targetDir, SetupOptions o) async {
  if (o.renderMode == null) return;
  final String desired = renderModeToYaml(o.renderMode!);

  // 1) pubspec.yaml jaspr.mode is authoritative for jaspr_cli 0.20+.
  final File pubspec = File(pJoin(targetDir.path, 'pubspec.yaml'));
  if (pubspec.existsSync()) {
    final String original = await pubspec.readAsString();
    final String patched = _rewritePubspecJasprMode(original, desired);
    if (patched != original && !o.dryRun) {
      await pubspec.writeAsString(patched);
      logVerbose('Patched pubspec.yaml jaspr.mode -> $desired');
    }
  }

  // 2) jaspr.yaml — cosmetic mirror.
  final File jasprYaml = File(pJoin(targetDir.path, 'jaspr.yaml'));
  if (!jasprYaml.existsSync()) return;
  final String content = await jasprYaml.readAsString();
  final RegExp modeLine = RegExp(r'^mode:\s*\S+\s*$', multiLine: true);
  final String patched = modeLine.hasMatch(content)
      ? content.replaceFirst(modeLine, 'mode: $desired')
      : 'mode: $desired\n$content';
  if (patched != content && !o.dryRun) {
    await jasprYaml.writeAsString(patched);
    logVerbose('Patched jaspr.yaml mode -> $desired (cosmetic)');
  }
}

String _rewritePubspecJasprMode(String content, String desiredMode) {
  final List<String> lines = content.split('\n');
  int jasprBlockStart = -1;
  int modeLineIndex = -1;
  for (int i = 0; i < lines.length; i++) {
    final String line = lines[i];
    if (jasprBlockStart < 0 && RegExp(r'^jaspr:\s*(#.*)?$').hasMatch(line)) {
      jasprBlockStart = i;
      continue;
    }
    if (jasprBlockStart >= 0 &&
        RegExp(r'^\s{2,}mode:\s*\S+').hasMatch(line) &&
        modeLineIndex < 0) {
      modeLineIndex = i;
      break;
    }
    if (jasprBlockStart >= 0 &&
        line.isNotEmpty &&
        !line.startsWith(' ') &&
        !line.startsWith('#') &&
        i > jasprBlockStart) {
      break;
    }
  }
  if (modeLineIndex >= 0) {
    lines[modeLineIndex] = lines[modeLineIndex]
        .replaceFirst(RegExp(r'mode:\s*\S+'), 'mode: $desiredMode');
    return lines.join('\n');
  }
  if (jasprBlockStart >= 0) {
    lines.insert(jasprBlockStart + 1, '  mode: $desiredMode');
    return lines.join('\n');
  }
  final int depsIndex = lines.indexWhere(
      (String l) => RegExp(r'^dependencies:\s*$').hasMatch(l));
  final List<String> block = <String>[
    '',
    '# Jaspr CLI configuration — render mode is read from this block.',
    'jaspr:',
    '  mode: $desiredMode',
    '',
  ];
  if (depsIndex < 0) {
    lines.addAll(block);
  } else {
    lines.insertAll(depsIndex, block);
  }
  return lines.join('\n');
}

// ─────────────────────────────────────────────────────────────────────
// 11. Vendor shims — ported from
//     oracular/lib/services/template_copier.dart:415-502.
//
//     The ZIP packager (T1.4) ships `_vendor/<shim>/` directories
//     alongside the template. setup.dart moves them to
//     `<outputDir>/.oracular_deps/<shim>/` and injects a
//     `dependency_overrides` entry in each affected pubspec.
// ─────────────────────────────────────────────────────────────────────

Future<void> _copyDirectoryRaw(Directory source, Directory target) async {
  if (!target.existsSync()) await target.create(recursive: true);
  await for (final FileSystemEntity e in source.list(recursive: false)) {
    final String tp = pJoin(target.path, pBasename(e.path));
    if (e is Directory) {
      final String dn = pBasename(e.path);
      if (_shouldSkipDir(dn)) continue;
      await _copyDirectoryRaw(e, Directory(tp));
    } else if (e is File) {
      final String fn = pBasename(e.path);
      if (_shouldSkipFile(fn)) continue;
      await e.copy(tp);
    }
  }
}

bool _shouldSkipDir(String name) => const <String>{
      '.dart_tool', '.idea', '.git', 'build', '.gradle', 'Pods',
    }.contains(name);

bool _shouldSkipFile(String name) {
  if (name.endsWith('.g.dart')) return true;
  return const <String>{
    '.DS_Store', 'pubspec.lock', '.flutter-plugins',
    '.flutter-plugins-dependencies', '.packages', '.metadata',
  }.contains(name);
}

Future<void> vendorShimsIfNeeded(
  Directory zipRoot,
  Directory outputDir,
  SetupOptions o,
) async {
  final Directory vendorDir = Directory(pJoin(zipRoot.path, '_vendor'));
  if (!vendorDir.existsSync()) return; // Flutter templates ship no shims.

  final Directory depsRoot =
      Directory(pJoin(outputDir.path, '.oracular_deps'));

  Future<void> ensureShim(String name) async {
    final Directory src = Directory(pJoin(vendorDir.path, name));
    if (!src.existsSync()) return;
    // Lazy-create the deps root only when we actually have a shim to
    // vendor — keeps the output dir clean when no `--with-models` is
    // requested for cli/jaspr/server templates whose ZIPs ship shims.
    if (!depsRoot.existsSync() && !o.dryRun) {
      await depsRoot.create(recursive: true);
    }
    final Directory dst = Directory(pJoin(depsRoot.path, name));
    if (!dst.existsSync() && !o.dryRun) {
      await _copyDirectoryRaw(src, dst);
      logVerbose('Vendored $name -> ${dst.path}');
    }
  }

  // Pure-Dart targets need jpatch shim.
  if (o.withModels && !o.isFlutterApp) {
    await ensureShim('jpatch');
  }
  // Jaspr targets need the analyzer-10 shim pair when models is on.
  if (o.withModels && o.isJasprTemplate) {
    await ensureShim('artifact_gen');
    await ensureShim('fire_crud_gen');
  }
}

Future<void> injectOverridesIfNeeded(File pubspec, SetupOptions o) async {
  if (o.withModels && !o.isFlutterApp) {
    await addVendoredOverride(pubspec,
        packageName: 'jpatch',
        relativeShimPath: '../.oracular_deps/jpatch',
        opts: o);
  }
  if (o.withModels && o.isJasprTemplate) {
    await addVendoredOverride(pubspec,
        packageName: 'artifact_gen',
        relativeShimPath: '../.oracular_deps/artifact_gen',
        opts: o);
    await addVendoredOverride(pubspec,
        packageName: 'fire_crud_gen',
        relativeShimPath: '../.oracular_deps/fire_crud_gen',
        opts: o);
  }
}

// ─────────────────────────────────────────────────────────────────────
// 12. Stage template files from ZIP root to <outputDir>/<project>.
//     Skips meta files (`setup.dart`, `README.md`, `VERSION`,
//     `LICENSE`, `_vendor/`) — those are setup.dart's own scaffolding,
//     not user project content.
// ─────────────────────────────────────────────────────────────────────

const Set<String> _zipMetaNames = <String>{
  'setup.dart',
  'README.md',
  'VERSION',
  'LICENSE',
  'SETUP_USAGE.md',
};

Future<void> stageTemplate({
  required Directory zipRoot,
  required Directory targetDir,
  required SetupOptions opts,
}) async {
  if (!targetDir.existsSync() && !opts.dryRun) {
    await targetDir.create(recursive: true);
  }
  // Defense-in-depth: even though the orchestrator refuses
  // overlapping --output-dir up front (see _run), guard against any
  // future caller that bypasses that check by skipping any source
  // entry whose canonical absolute path is equal to or below the
  // target. Prevents infinite self-recursion. resolveSymbolicLinksSync
  // handles macOS `/tmp -> /private/tmp` rewrites.
  String entryCanon(FileSystemEntity e) {
    try {
      return e.resolveSymbolicLinksSync();
    } on FileSystemException {
      return pNormalize(e.absolute.path);
    }
  }

  String targetCanonical;
  try {
    targetCanonical = targetDir.resolveSymbolicLinksSync();
  } on FileSystemException {
    targetCanonical = pNormalize(targetDir.absolute.path);
  }
  final String sep = Platform.pathSeparator;
  await for (final FileSystemEntity e in zipRoot.list(recursive: false)) {
    final String name = pBasename(e.path);
    if (name == '_vendor') continue; // Handled separately.
    if (e is File && _zipMetaNames.contains(name)) continue;
    // Skip if this source entry IS the target or lives below it.
    final String entryCanonical = entryCanon(e);
    if (entryCanonical == targetCanonical ||
        entryCanonical.startsWith('$targetCanonical$sep')) {
      logVerbose('Skipping $entryCanonical (would self-recurse into target)');
      continue;
    }
    final String dst = pJoin(targetDir.path, name);
    if (e is Directory) {
      if (_shouldSkipDir(name)) continue;
      await _copyDirectoryRaw(e, Directory(dst));
    } else if (e is File) {
      if (_shouldSkipFile(name)) continue;
      if (!opts.dryRun) await e.copy(dst);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// 13. Pub-get runner. Skips when --no-pub-get / --dry-run.
// ─────────────────────────────────────────────────────────────────────

Future<void> runPubGet(Directory dir, {required bool flutter}) async {
  final String exec = flutter ? 'flutter' : 'dart';
  logInfo('Running $exec pub get in ${pBasename(dir.path)}...');
  final ProcessResult r =
      await Process.run(exec, <String>['pub', 'get'], workingDirectory: dir.path);
  if (r.exitCode != 0) {
    logWarn('$exec pub get failed (${r.exitCode}). Continuing.');
    if ((r.stderr as String).isNotEmpty) {
      logVerbose((r.stderr as String).trim());
    }
  }
}

bool _hasFlutterDep(File pubspec) {
  if (!pubspec.existsSync()) return false;
  final String content = pubspec.readAsStringSync();
  return content.contains(RegExp(r'^\s+flutter:\s*\n\s+sdk:\s*flutter',
      multiLine: true));
}

// ─────────────────────────────────────────────────────────────────────
// 14. Oracular install offer (plan §4.4).
//     The contract:
//       - Detect existing install (`which oracular` / `where oracular`).
//       - Compare detected version against o.oracularVersion.
//       - For TTY + neither flag set: prompt [Y/n].
//       - For piped stdin + neither flag: skip silently (CI-safe).
//       - `--install-oracular` or `--yes`: install without prompting.
//       - `--no-install-oracular`: skip without prompting.
//       - Run `dart pub global activate oracular <version>` pinned.
//       - On success, validate with `oracular version`.
//       - On failure, print retry hint but exit 0 (project is scaffolded).
//       - Print shell-aware PATH hint when ~/.pub-cache/bin isn't on PATH.
// ─────────────────────────────────────────────────────────────────────

// __INSTALL_OFFER_BEGIN__

class _InstallDetection {
  final bool installed;
  final String? path;
  final String? version;
  _InstallDetection({required this.installed, this.path, this.version});
}

/// Test-only override hooks. Production users never set these. Their
/// only purpose is to keep
/// `oracular/test/integration/setup_install_offer_test.dart` from
/// having to spawn real `dart pub global activate` calls.
///
///   ORACULAR_INSTALL_DETECT_OVERRIDE
///     - `missing`     → never installed
///     - `<X.Y.Z>`     → installed at this version
///     - `unknown`     → installed, version undetectable
///
///   ORACULAR_INSTALL_DART_CMD
///     - absolute path used in place of `dart` when running
///       `pub global activate`. Defaults to `dart` (PATH lookup).
///
///   ORACULAR_INSTALL_SIMULATE_TTY
///     - `1` / `true`  → pretend stdin.hasTerminal == true regardless
///                       of the actual stdin state.
///     - `0` / unset   → use the real stdin.hasTerminal value.

bool _fakeHasTerminal() {
  final String? v =
      Platform.environment['ORACULAR_INSTALL_SIMULATE_TTY']?.toLowerCase();
  if (v == '1' || v == 'true' || v == 'yes') return true;
  return stdin.hasTerminal;
}

Future<_InstallDetection> _detectOracular() async {
  final String? ov =
      Platform.environment['ORACULAR_INSTALL_DETECT_OVERRIDE'];
  if (ov != null && ov.isNotEmpty) {
    if (ov == 'missing') return _InstallDetection(installed: false);
    if (ov == 'unknown') {
      return _InstallDetection(installed: true, path: '/fake/oracular');
    }
    return _InstallDetection(
      installed: true,
      path: '/fake/oracular',
      version: ov,
    );
  }

  // Prefer `which`/`where` for path resolution.
  final String resolver = Platform.isWindows ? 'where' : 'which';
  ProcessResult? r;
  try {
    r = await Process.run(resolver, <String>['oracular']);
  } catch (_) {
    return _InstallDetection(installed: false);
  }
  if (r.exitCode != 0) {
    return _InstallDetection(installed: false);
  }
  final String path = (r.stdout as String).split(RegExp(r'[\r\n]+')).first.trim();
  if (path.isEmpty) return _InstallDetection(installed: false);

  // Try `oracular version` to extract semver. Tolerate any output
  // shape; we just want X.Y.Z if it's in there.
  String? version;
  try {
    final ProcessResult vr =
        await Process.run('oracular', <String>['version']);
    final String combined = (vr.stdout as String) + (vr.stderr as String);
    final RegExpMatch? m =
        RegExp(r'(\d+\.\d+\.\d+)').firstMatch(combined);
    version = m?.group(1);
  } catch (_) {
    // ignore — we still know it's installed.
  }
  return _InstallDetection(installed: true, path: path, version: version);
}

int _compareSemver(String a, String b) {
  final List<int> as =
      a.split('.').map((String s) => int.tryParse(s) ?? 0).toList();
  final List<int> bs =
      b.split('.').map((String s) => int.tryParse(s) ?? 0).toList();
  for (int i = 0; i < 3; i++) {
    final int ai = i < as.length ? as[i] : 0;
    final int bi = i < bs.length ? bs[i] : 0;
    if (ai != bi) return ai - bi;
  }
  return 0;
}

bool _isPubCacheBinOnPath() {
  final String? home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'];
  if (home == null) return true; // best-effort
  final String expected = pJoin(home, '.pub-cache', 'bin');
  final String pathEnv =
      Platform.environment['PATH'] ?? Platform.environment['Path'] ?? '';
  final String sep = Platform.isWindows ? ';' : ':';
  return pathEnv
      .split(sep)
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty)
      .any((String s) => pNormalize(s) == pNormalize(expected));
}

void _printPubCachePathHint() {
  if (_isPubCacheBinOnPath()) return;
  print('');
  logWarn('`~/.pub-cache/bin` is not on your PATH.');
  if (Platform.isWindows) {
    logInfo('PowerShell: \$env:PATH += ";\$HOME\\.pub-cache\\bin"');
    logInfo('Add the same to your \$PROFILE to make it permanent.');
    return;
  }
  final String shell = Platform.environment['SHELL'] ?? '';
  if (shell.endsWith('/fish')) {
    logInfo('Fish:');
    logInfo('  set -U fish_user_paths "\$HOME/.pub-cache/bin" \$fish_user_paths');
  } else if (shell.endsWith('/zsh')) {
    logInfo('Zsh — add to ~/.zshrc:');
    logInfo('  export PATH="\$HOME/.pub-cache/bin:\$PATH"');
  } else if (shell.endsWith('/bash')) {
    logInfo('Bash — add to ~/.bashrc or ~/.bash_profile:');
    logInfo('  export PATH="\$HOME/.pub-cache/bin:\$PATH"');
  } else {
    logInfo('POSIX shells — add to your shell rc file:');
    logInfo('  export PATH="\$HOME/.pub-cache/bin:\$PATH"');
    logInfo('Fish:');
    logInfo('  set -U fish_user_paths "\$HOME/.pub-cache/bin" \$fish_user_paths');
    logInfo('PowerShell:');
    logInfo('  \$env:PATH += ";\$HOME\\.pub-cache\\bin"');
  }
}

/// Prompt the user; respect [stdin.hasTerminal] (or
/// `ORACULAR_INSTALL_SIMULATE_TTY` in test mode). Returns true for any
/// of (empty, y, yes); false for (n, no, anything else).
bool _promptYesNo(String question, {bool defaultYes = true}) {
  if (!_fakeHasTerminal()) return false;
  final String suffix = defaultYes ? '[Y/n]' : '[y/N]';
  stdout.write('$question $suffix ');
  final String? raw = stdin.readLineSync();
  if (raw == null) return defaultYes;
  final String t = raw.trim().toLowerCase();
  if (t.isEmpty) return defaultYes;
  if (t == 'y' || t == 'yes') return true;
  return false;
}

Future<bool> _runPubGlobalActivate(String version,
    {required bool verbose}) async {
  final String dartCmd =
      Platform.environment['ORACULAR_INSTALL_DART_CMD'] ?? 'dart';
  final List<String> argv = <String>[
    'pub',
    'global',
    'activate',
    'oracular',
    version,
  ];
  logInfo('$dartCmd ${argv.join(' ')}');
  final Process proc = await Process.start(
    dartCmd,
    argv,
    mode: ProcessStartMode.inheritStdio,
  );
  final int code = await proc.exitCode;
  return code == 0;
}

Future<void> offerOracularInstall(SetupOptions o) async {
  // 1. Resolve decision.
  bool shouldOffer;
  switch (o.installOffer) {
    case InstallOfferDecision.no:
      logInfo('Skipped oracular install (--no-install-oracular).');
      return;
    case InstallOfferDecision.yes:
      shouldOffer = true;
    case InstallOfferDecision.prompt:
      shouldOffer = _fakeHasTerminal();
  }
  if (!shouldOffer) {
    logInfo('Skipped oracular install (no TTY).');
    return;
  }

  // 2. Detect existing install.
  final _InstallDetection det = await _detectOracular();
  final String target = o.oracularVersion;

  // 2a. Already installed at target version → quick exit.
  if (det.installed && det.version == target) {
    print('');
    logSuccess('oracular v$target already installed (at ${det.path}).');
    return;
  }

  // 3. Decide message + default depending on state.
  String headline;
  String subhead;
  bool defaultYes = true;
  if (!det.installed) {
    headline = 'Install the oracular CLI for ongoing work?';
    subhead =
        '  - Pins to v$target so it matches this template release.\n'
        '  - Adds `oracular build`, `oracular deploy`, `oracular open`, etc.\n'
        '  - Reversible: `dart pub global deactivate oracular`.';
  } else if (det.version == null) {
    headline = 'oracular is installed but its version could not be detected.\n'
        'Reinstall it pinned to v$target?';
    subhead = '  - Existing binary at: ${det.path}';
  } else if (_compareSemver(det.version!, target) < 0) {
    headline = 'Upgrade oracular ${det.version} → $target?';
    subhead = '  - Matches the template release you just extracted.';
  } else {
    // detected > target: don't downgrade silently.
    headline = 'oracular ${det.version} is newer than this template '
        '(v$target). Downgrade?';
    subhead = '  - Optional. Most users prefer to keep the newer install.';
    defaultYes = false;
  }

  // 4. Prompt or auto-accept.
  bool doInstall;
  if (o.installOffer == InstallOfferDecision.yes) {
    doInstall = true;
    print('');
    logInfo(headline.replaceAll('\n', ' '));
  } else {
    print('');
    print(_ansi('1;36', headline));
    print(subhead);
    print('');
    doInstall = _promptYesNo('Continue?', defaultYes: defaultYes);
  }
  if (!doInstall) {
    logInfo('Skipped oracular install. Re-run with --install-oracular '
        'when you change your mind.');
    return;
  }

  // 5. Activate.
  final bool ok = await _runPubGlobalActivate(target, verbose: o.verbose);
  if (!ok) {
    logWarn('`dart pub global activate oracular $target` failed.');
    logInfo('Your project is already scaffolded; this step is optional.');
    logInfo('Retry manually with:');
    logInfo('  dart pub global activate oracular $target');
    return;
  }

  // 6. Validate + PATH hint.
  _InstallDetection postDet;
  try {
    postDet = await _detectOracular();
  } catch (_) {
    postDet = _InstallDetection(installed: false);
  }
  if (postDet.installed && postDet.version == target) {
    logSuccess('Installed oracular v$target at ${postDet.path}.');
  } else if (postDet.installed) {
    logSuccess('oracular installed (reported version: '
        '${postDet.version ?? "unknown"}).');
  } else {
    logWarn('Activated oracular but the binary is not on PATH yet.');
  }
  _printPubCachePathHint();
}
// __INSTALL_OFFER_END__

// ─────────────────────────────────────────────────────────────────────
// 15. Main flow.
// ─────────────────────────────────────────────────────────────────────

Future<int> _run(List<String> rawArgs) async {
  Map<String, dynamic> args;
  try {
    args = parseArgs(rawArgs);
  } on FormatException catch (e) {
    logError(e.message);
    printHelp();
    return 64;
  }

  if (args['help'] == true || args['_remaining'] != null) {
    printHelp();
    return args['help'] == true ? 0 : 64;
  }
  if (args['no-color'] == true) _useColor = false;

  // Read VERSION file (written by packager).
  final VersionFile? vfile = VersionFile.readFromCwd();
  final String oracularVersion =
      vfile?.oracularVersion ?? kOracularVersionDefault;
  final String templateName = (args['template'] as String?) ??
      vfile?.templateName ??
      kTemplateNameDefault;
  if (templateName.isEmpty) {
    logError('Could not detect template. Pass --template <name> or run '
        'setup.dart from the extracted ZIP root (with VERSION file).');
    return 64;
  }

  // Required.
  final String? name = args['name'] as String?;
  final String? org = args['org'] as String?;
  if (name == null || org == null) {
    logError('--name and --org are required.');
    printHelp();
    return 64;
  }
  final String? nameErr = validateAppName(name);
  if (nameErr != null) {
    logError('--name: $nameErr');
    return 64;
  }
  final String? orgErr = validateOrgDomain(org);
  if (orgErr != null) {
    logError('--org: $orgErr');
    return 64;
  }
  final String className = (args['class-name'] as String?) ?? snakeToPascal(name);
  final String outputDir = (args['output-dir'] as String?) ?? '.';

  // Optional values.
  final JasprRenderMode? rmode = parseRenderMode(args['render-mode'] as String?);
  if (args['render-mode'] != null && rmode == null) {
    logError('Unknown --render-mode "${args['render-mode']}". '
        'Valid: csr|ssg|ssr|hybrid|embed.');
    return 64;
  }
  final bool withModels = args['with-models'] == true;
  final bool withServer = args['with-server'] == true;
  final bool withFirebase = args['with-firebase'] == true;
  final String? fbId = args['firebase-project-id'] as String?;
  if (withFirebase && (fbId == null || fbId.isEmpty)) {
    logError('--with-firebase requires --firebase-project-id.');
    return 64;
  }
  if (fbId != null && fbId.isNotEmpty) {
    final String? e = validateFirebaseProjectId(fbId);
    if (e != null) {
      logError('--firebase-project-id: $e');
      return 64;
    }
  }
  final List<String>? platforms =
      (args['platforms'] as String?)?.split(',').map((String s) => s.trim())
          .where((String s) => s.isNotEmpty)
          .toList();
  final bool noPubGet = args['no-pub-get'] == true;
  final bool dryRun = args['dry-run'] == true;
  final bool yes = args['yes'] == true;
  final bool verbose = args['verbose'] == true;

  InstallOfferDecision offer;
  if (args['install-oracular'] == true) {
    offer = InstallOfferDecision.yes;
  } else if (args['no-install-oracular'] == true) {
    offer = InstallOfferDecision.no;
  } else if (yes) {
    offer = InstallOfferDecision.yes;
  } else {
    offer = InstallOfferDecision.prompt;
  }

  final SetupOptions opts = SetupOptions(
    appName: name,
    orgDomain: org,
    baseClassName: className,
    outputDir: outputDir,
    template: templateName,
    renderMode: rmode,
    withModels: withModels,
    withServer: withServer,
    withFirebase: withFirebase,
    firebaseProjectId: fbId,
    platforms: platforms,
    noPubGet: noPubGet,
    dryRun: dryRun,
    yes: yes,
    verbose: verbose,
    installOffer: offer,
    oracularVersion: oracularVersion,
    templateName: templateName,
  );
  SetupOptions.current = opts;

  return await orchestrate(opts);
}

Future<int> orchestrate(SetupOptions o) async {
  print('');
  print(_ansi('1;36',
      'Oracular template setup — ${o.template} (oracular v${o.oracularVersion})'));
  print('');
  logInfo('App name: ${o.appName}');
  logInfo('Org: ${o.orgDomain}');
  logInfo('Class: ${o.baseClassName}');
  logInfo('Output: ${o.outputDir}');
  if (o.renderMode != null) {
    logInfo('Jaspr render mode: ${o.renderMode!.name}');
  }
  if (o.withModels) logInfo('+ models package');
  if (o.withServer) logInfo('+ server package');
  if (o.withFirebase) logInfo('+ firebase deps');
  print('');

  final Directory zipRoot = Directory.current;
  final Directory outDir = Directory(o.outputDir);
  if (!outDir.existsSync() && !o.dryRun) {
    await outDir.create(recursive: true);
  }

  // Refuse if --output-dir overlaps with the ZIP root in any way that
  // would cause stageTemplate / _copyDirectoryRaw to recurse over its
  // own output. Three cases caught:
  //   1. outputDir == zipRoot (e.g. `--output-dir .` from inside the
  //      ZIP).
  //   2. outputDir is INSIDE zipRoot (e.g. `--output-dir ./myapp`
  //      from inside the ZIP) — staging lists zipRoot's children, sees
  //      the `myapp/` we just created, and infinite-recurses.
  //   3. outputDir is the parent of zipRoot AND would re-include it
  //      (rare, but explicit refusal is friendlier than crashing).
  //
  // resolveSymbolicLinksSync() is critical on macOS where
  // `/tmp -> /private/tmp` causes naive string-prefix checks to miss
  // genuinely-nested directories.
  String canon(Directory d) {
    try {
      return d.resolveSymbolicLinksSync();
    } on FileSystemException {
      return pNormalize(d.absolute.path);
    }
  }

  final String zipRootCanonical = canon(zipRoot);
  final String outDirCanonical = canon(outDir);
  final String sep = Platform.pathSeparator;
  final String zipRootWithSep = '$zipRootCanonical$sep';
  if (outDirCanonical == zipRootCanonical) {
    logError('Refusing to write into the ZIP root '
        '(${zipRoot.absolute.path}). Choose --output-dir pointing '
        'elsewhere (e.g. `--output-dir ../my_app`).');
    return 64;
  }
  if (outDirCanonical.startsWith(zipRootWithSep)) {
    logError('Refusing to use --output-dir "${outDir.absolute.path}" '
        'because it is inside the ZIP root '
        '(${zipRoot.absolute.path}). Staging would copy the ZIP into '
        'itself. Move --output-dir to a sibling (e.g. '
        '`--output-dir ../my_app`) or `cd` to a neutral parent first.');
    return 64;
  }
  // Case 3: zipRoot inside outputDir. Allowed but warn — the user will
  // see <zipRoot> as a sibling of the staged project. Not destructive,
  // just confusing. Don't refuse; just inform.
  if (zipRootCanonical.startsWith('$outDirCanonical$sep')) {
    logWarn('--output-dir "${outDir.absolute.path}" is a parent of the '
        'ZIP root. Staging will succeed but the ZIP contents will sit '
        'alongside the new project. Consider extracting the ZIP to a '
        'sibling dir instead.');
  }

  // 1. Stage primary project.
  final String primary = o.primaryPackageName;
  final Directory primaryDir = Directory(pJoin(outDir.path, primary));
  logInfo('Staging $primary...');
  await stageTemplate(zipRoot: zipRoot, targetDir: primaryDir, opts: o);

  // 1a. Embed template: also stage the Flutter guest.
  Directory? embedGuestDir;
  if (o.isJasprFlutterEmbed) {
    // The embed ZIP ships dual-package; the staging in step 1 dropped
    // both `_web/` and `_app/` siblings inside primaryDir. Lift `_app`
    // up to outputDir/embeddedFlutterPackageName/.
    final Directory innerApp = Directory(
        pJoin(primaryDir.path, 'arcane_jaspr_flutter_embed_app'));
    if (innerApp.existsSync()) {
      embedGuestDir =
          Directory(pJoin(outDir.path, o.embeddedFlutterPackageName));
      if (!embedGuestDir.existsSync() && !o.dryRun) {
        await innerApp.rename(embedGuestDir.path);
        logVerbose('Lifted embed guest -> ${embedGuestDir.path}');
      }
    }
    // The host content inside primaryDir is in
    // `arcane_jaspr_flutter_embed_web/`; lift it up.
    final Directory innerWeb = Directory(
        pJoin(primaryDir.path, 'arcane_jaspr_flutter_embed_web'));
    if (innerWeb.existsSync() && !o.dryRun) {
      // Move contents up one level, then drop the inner dir.
      await for (final FileSystemEntity e in innerWeb.list(recursive: false)) {
        final String to = pJoin(primaryDir.path, pBasename(e.path));
        if (e is Directory) {
          await e.rename(to);
        } else if (e is File) {
          await e.rename(to);
        }
      }
      await innerWeb.delete(recursive: true);
    }
  }

  // 2. Process placeholders in primary.
  await processDirectory(primaryDir, o);

  // 3. Update pubspec name + flags in primary.
  final File primaryPubspec = File(pJoin(primaryDir.path, 'pubspec.yaml'));
  await updatePubspec(primaryPubspec, primary, o);

  // 4. Jaspr-mode patching.
  if (o.isJasprTemplate) {
    await patchJasprYamlMode(primaryDir, o);
  }

  // 5. Companion models package (when --with-models AND a sibling
  //    `arcane_models/` exists inside the ZIP — that's the bundle-ZIP
  //    case; standalone ZIPs print an advisory).
  //    Track whether models actually got staged so we only inject the
  //    `<name>_models: { path: ../<name>_models }` dep when there's a
  //    real package to point at — otherwise `pub get` would fail with
  //    "could not find package <name>_models".
  bool modelsStaged = false;
  if (o.withModels) {
    final Directory modelsSrc =
        Directory(pJoin(zipRoot.path, 'arcane_models'));
    if (modelsSrc.existsSync()) {
      final Directory modelsTgt =
          Directory(pJoin(outDir.path, o.modelsPackageName));
      logInfo('Staging ${o.modelsPackageName}...');
      await stageTemplate(
          zipRoot: modelsSrc, targetDir: modelsTgt, opts: o);
      await processDirectory(modelsTgt, o);
      await updatePubspec(
          File(pJoin(modelsTgt.path, 'pubspec.yaml')),
          o.modelsPackageName,
          o);
      modelsStaged = true;
    } else {
      logWarn('--with-models requested but no models template is bundled '
          'in this ZIP.');
      logInfo('Download arcane_models-v${o.oracularVersion}.zip from the '
          'same Release, extract its content into ${pJoin(outDir.path, o.modelsPackageName)}, '
          'and then uncomment the `${o.modelsPackageName}:` entry in your '
          'pubspec.yaml.');
    }
    if (modelsStaged) {
      await addModelsDependency(primaryPubspec, o);
    } else {
      await addCommentedModelsDependency(primaryPubspec, o);
    }
  }

  // 6. Companion server package.
  if (o.withServer) {
    final Directory serverSrc =
        Directory(pJoin(zipRoot.path, 'arcane_server'));
    if (serverSrc.existsSync()) {
      final Directory serverTgt =
          Directory(pJoin(outDir.path, o.serverPackageName));
      logInfo('Staging ${o.serverPackageName}...');
      await stageTemplate(
          zipRoot: serverSrc, targetDir: serverTgt, opts: o);
      await processDirectory(serverTgt, o);
      final File serverPubspec =
          File(pJoin(serverTgt.path, 'pubspec.yaml'));
      await updatePubspec(serverPubspec, o.serverPackageName, o);
      if (o.withModels) {
        await addModelsDependency(serverPubspec, o);
      }
    } else {
      logWarn('--with-server requested but no server template is bundled '
          'in this ZIP.');
      logInfo('Download arcane_server-v${o.oracularVersion}.zip from the '
          'same Release, extract, and run its setup.dart separately.');
    }
  }

  // 7. Embed guest processing.
  if (embedGuestDir != null) {
    await processDirectory(embedGuestDir, o);
    await updatePubspec(
        File(pJoin(embedGuestDir.path, 'pubspec.yaml')),
        o.embeddedFlutterPackageName,
        o);
    if (o.withModels) {
      // Same gating logic as primary pubspec — only inject the active
      // `path:` dep if the models package actually got staged on disk.
      if (modelsStaged) {
        await addModelsDependency(
            File(pJoin(embedGuestDir.path, 'pubspec.yaml')), o);
      } else {
        await addCommentedModelsDependency(
            File(pJoin(embedGuestDir.path, 'pubspec.yaml')), o);
      }
    }
  }

  // 8. Vendor shims (jpatch / artifact_gen / fire_crud_gen).
  await vendorShimsIfNeeded(zipRoot, outDir, o);
  await injectOverridesIfNeeded(primaryPubspec, o);

  // 9. pub get.
  if (!o.noPubGet && !o.dryRun) {
    final bool flutter = _hasFlutterDep(primaryPubspec);
    await runPubGet(primaryDir, flutter: flutter);
    if (embedGuestDir != null) {
      await runPubGet(embedGuestDir, flutter: true);
    }
    if (o.withModels) {
      final Directory mDir =
          Directory(pJoin(outDir.path, o.modelsPackageName));
      if (mDir.existsSync()) await runPubGet(mDir, flutter: false);
    }
    if (o.withServer) {
      final Directory sDir =
          Directory(pJoin(outDir.path, o.serverPackageName));
      if (sDir.existsSync()) await runPubGet(sDir, flutter: true);
    }
  }

  // 10. Install offer.
  await offerOracularInstall(o);

  // 11. Done.
  print('');
  logSuccess('Setup complete!');
  logInfo('Project: ${primaryDir.path}');
  if (embedGuestDir != null) {
    logInfo('Embed guest: ${embedGuestDir.path}');
  }
  print('');
  return 0;
}

Future<void> main(List<String> args) async {
  // ───────────────────────────────────────────────────────────────────
  // Hidden internal self-test hook.
  //
  // When `ORACULAR_SETUP_INTERNAL_TEST_REPLACE` is set, the script
  // reads the file path from the env var, treats its contents as a
  // template fixture, runs `replaceInContent` against a fixed
  // SetupOptions taken from `ORACULAR_SETUP_INTERNAL_TEST_OPTS`
  // (key=value;key=value semicolon-separated), and writes the
  // result to stdout.
  //
  // Consumed by `oracular/test/unit/setup_script_parity_test.dart`
  // (plan T3.1) to verify the skeleton stays semantically aligned
  // with `PlaceholderReplacer`. This hook is intentionally
  // undocumented — production users have no reason to use it.
  // ───────────────────────────────────────────────────────────────────
  final String? testReplacePath =
      Platform.environment['ORACULAR_SETUP_INTERNAL_TEST_REPLACE'];
  if (testReplacePath != null && testReplacePath.isNotEmpty) {
    await _runInternalReplaceTest(testReplacePath);
    return;
  }

  final int code = await _run(args);
  if (code != 0) exitCode = code;
}

/// Reads an `appName=X;orgDomain=Y;...` style env var, builds a
/// minimal [SetupOptions], runs [replaceInContent] on the file at
/// [fixturePath], and prints the result to stdout. Exits non-zero on
/// any parse failure.
Future<void> _runInternalReplaceTest(String fixturePath) async {
  final File fixture = File(fixturePath);
  if (!fixture.existsSync()) {
    stderr.writeln('internal-test: fixture not found: $fixturePath');
    exitCode = 66;
    return;
  }
  final Map<String, String> opts = <String, String>{};
  final String optStr =
      Platform.environment['ORACULAR_SETUP_INTERNAL_TEST_OPTS'] ?? '';
  for (final String pair in optStr.split(';')) {
    final int eq = pair.indexOf('=');
    if (eq <= 0) continue;
    opts[pair.substring(0, eq).trim()] = pair.substring(eq + 1).trim();
  }
  final SetupOptions o = SetupOptions(
    appName: opts['appName'] ?? 'sample_app',
    orgDomain: opts['orgDomain'] ?? 'com.example',
    baseClassName: opts['baseClassName'] ?? 'SampleApp',
    outputDir: '.',
    template: opts['template'] ?? 'arcane_app',
    renderMode: null,
    withModels: false,
    withServer: false,
    withFirebase: false,
    firebaseProjectId: opts['firebaseProjectId'],
    platforms: null,
    noPubGet: true,
    dryRun: true,
    yes: true,
    verbose: false,
    installOffer: InstallOfferDecision.no,
    oracularVersion: kOracularVersionDefault,
    templateName: opts['template'] ?? 'arcane_app',
  );
  final String input = await fixture.readAsString();
  stdout.write(replaceInContent(input, o));
}
