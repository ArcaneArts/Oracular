// Parity test for `scripts/setup_template_template.dart` (T3.1).
//
// The standalone `setup.dart` script that ships in every template ZIP
// is hand-ported from `oracular/lib/services/placeholder_replacer.dart`.
// This test wires both implementations through the same set of
// fixtures and verifies their outputs are byte-identical.
//
// How it works:
//
//   1. For each (fixture, SetupConfig) pair below, build the
//      canonical `expected` output by calling
//      `PlaceholderReplacer.replaceInContent` directly.
//   2. Spawn `dart run scripts/setup_template_template.dart` with two
//      env vars:
//        - `ORACULAR_SETUP_INTERNAL_TEST_REPLACE=<fixture file path>`
//        - `ORACULAR_SETUP_INTERNAL_TEST_OPTS=appName=...;orgDomain=...;...`
//      and capture stdout as `actual`.
//   3. `expect(actual, equals(expected))` — byte-for-byte.
//
// The hidden hook is defined at
// `scripts/setup_template_template.dart:1502-1554`.
//
// When this test fails, one of two things is wrong:
//   - The skeleton drifted from `PlaceholderReplacer` (the more likely
//     cause; fix the skeleton).
//   - `PlaceholderReplacer` gained new rules (port them into the
//     skeleton, then update this test with new fixtures).
//
// This test is INTENTIONALLY tied to the skeleton, not to a generated
// `dist/setup.dart`. The skeleton holds the canonical placeholder logic
// and the generator only substitutes `__GENERATED:...__` markers,
// which do not affect `replaceInContent`.

import 'dart:io';

import 'package:oracular/models/setup_config.dart';
import 'package:oracular/models/template_info.dart';
import 'package:oracular/services/placeholder_replacer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Returns the absolute path to the skeleton script. The test runs from
/// `oracular/`, so the skeleton lives in `../scripts/`.
String _skeletonScriptPath() {
  // `Directory.current` is the oracular package dir when invoked via
  // `dart test`. The repo root is one level up.
  final Directory repoRoot = Directory.current.path.endsWith('oracular')
      ? Directory.current.parent
      : Directory.current;
  return p.join(
    repoRoot.path,
    'scripts',
    'setup_template_template.dart',
  );
}

/// Encode a SetupConfig into the `key=value;key=value` form that the
/// internal hook accepts (see `_runInternalReplaceTest`).
String _encodeOpts(SetupConfig c) {
  final Map<String, String> kv = <String, String>{
    'appName': c.appName,
    'orgDomain': c.orgDomain,
    'baseClassName': c.baseClassName,
    'template': c.template.directoryName,
    if (c.firebaseProjectId != null)
      'firebaseProjectId': c.firebaseProjectId!,
  };
  return kv.entries.map((MapEntry<String, String> e) => '${e.key}=${e.value}').join(';');
}

/// Run the skeleton against [fixture] with the given config and return
/// what the skeleton wrote to stdout.
Future<String> _runSkeleton(String fixture, SetupConfig c) async {
  final Directory tmp = await Directory.systemTemp.createTemp('oracular_parity_');
  try {
    final File f = File(p.join(tmp.path, 'fixture.dart'));
    await f.writeAsString(fixture);

    final ProcessResult r = await Process.run(
      'dart',
      <String>['run', _skeletonScriptPath()],
      environment: <String, String>{
        'ORACULAR_SETUP_INTERNAL_TEST_REPLACE': f.path,
        'ORACULAR_SETUP_INTERNAL_TEST_OPTS': _encodeOpts(c),
        // Make stdout deterministic.
        'NO_COLOR': '1',
      },
    );

    if (r.exitCode != 0) {
      fail(
        'setup_template_template.dart exited ${r.exitCode}.\n'
        'stdout:\n${r.stdout}\n'
        'stderr:\n${r.stderr}',
      );
    }
    return r.stdout as String;
  } finally {
    await tmp.delete(recursive: true);
  }
}

SetupConfig _cfg({
  String appName = 'my_app',
  String orgDomain = 'com.example',
  String baseClassName = 'MyApp',
  TemplateType template = TemplateType.arcaneTemplate,
  String? firebaseProjectId,
}) {
  return SetupConfig(
    appName: appName,
    orgDomain: orgDomain,
    baseClassName: baseClassName,
    template: template,
    outputDir: '/tmp/parity',
    useFirebase: firebaseProjectId != null,
    firebaseProjectId: firebaseProjectId,
  );
}

/// One parity case. `name` is used in the test description; `fixture`
/// is the input string fed to both implementations; `config` carries
/// the substitutions.
class _Case {
  final String name;
  final String fixture;
  final SetupConfig config;
  const _Case(this.name, this.fixture, this.config);
}

void main() {
  // Spawning `dart run` per case dominates wall time; bump timeout.
  final Timeout testTimeout = const Timeout(Duration(minutes: 2));

  // ───────────────────────────────────────────────────────────────────
  // Fixtures — cover every rule branch in
  // PlaceholderReplacer.replaceInContent (lines 54-188).
  // ───────────────────────────────────────────────────────────────────

  final List<_Case> cases = <_Case>[
    // 1. PascalCase class names — generic + embed-specific.
    _Case(
      'class names: embed web + app + server + runner',
      "class ArcaneJasprFlutterEmbedWeb {}\n"
          "class ArcaneJasprFlutterEmbedApp {}\n"
          "class ArcaneServer {}\n"
          "class ArcaneRunner {}\n"
          "class ArcaneJasprApp {}\n",
      _cfg(template: TemplateType.arcaneJasprFlutterEmbed),
    ),

    // 2a. Package imports (longest-first).
    _Case(
      'package imports: embed web + embed app',
      "import 'package:arcane_jaspr_flutter_embed_web/foo.dart';\n"
          "import 'package:arcane_jaspr_flutter_embed_app/bar.dart';\n",
      _cfg(template: TemplateType.arcaneJasprFlutterEmbed),
    ),
    _Case(
      'package imports: jaspr docs + jaspr app',
      "import 'package:arcane_jaspr_docs/main.dart';\n"
          "import 'package:arcane_jaspr_app/main.dart';\n",
      _cfg(template: TemplateType.arcaneJaspr),
    ),
    _Case(
      'package imports: flutter templates (beamer, dock, cli, base)',
      "import 'package:arcane_beamer_app/x.dart';\n"
          "import 'package:arcane_dock_app/x.dart';\n"
          "import 'package:arcane_cli_app/x.dart';\n"
          "import 'package:arcane_app/x.dart';\n",
      _cfg(template: TemplateType.arcaneTemplate),
    ),

    // 3. Models package refs.
    _Case(
      'models package: import + bare token',
      "import 'package:arcane_models/m.dart';\n"
          "name: arcane_models\n",
      _cfg(),
    ),

    // 4. Server package refs.
    _Case(
      'server package: bare token',
      'name: arcane_server\n',
      _cfg(),
    ),

    // 5. App-name tokens in non-package contexts — checks ordering so
    //    `arcane_jaspr_app` is not partially clobbered by `arcane_app`.
    _Case(
      'app-name tokens: jaspr permutations (no package: prefix)',
      'A: arcane_jaspr_flutter_embed_web\n'
          'B: arcane_jaspr_flutter_embed_app\n'
          'C: arcane_jaspr_docs\n'
          'D: arcane_jaspr_app\n',
      _cfg(template: TemplateType.arcaneJaspr),
    ),
    _Case(
      'app-name tokens: flutter permutations (no package: prefix)',
      'A: arcane_beamer_app\n'
          'B: arcane_dock_app\n'
          'C: arcane_cli_app\n'
          'D: arcane_app\n',
      _cfg(),
    ),

    // 6. Firebase project id.
    _Case(
      'firebase project id substitution',
      'FIREBASE_PROJECT_ID: FIREBASE_PROJECT_ID\n',
      _cfg(firebaseProjectId: 'my-firebase-project'),
    ),
    _Case(
      'firebase project id substitution: no firebase configured',
      'FIREBASE_PROJECT_ID: FIREBASE_PROJECT_ID\n',
      _cfg(), // no firebase → token stays untouched
    ),

    // 7. Org domain rewrites.
    _Case(
      'org domain: art.arcane.template + ORG_DOMAIN',
      'CFBundleIdentifier: art.arcane.template\n'
          'ORG_DOMAIN: ORG_DOMAIN\n',
      _cfg(appName: 'my_app', orgDomain: 'com.example'),
    ),
    _Case(
      'org domain: underscored app name strips underscores',
      'CFBundleIdentifier: art.arcane.template\n',
      _cfg(appName: 'multi_word_app', orgDomain: 'com.example'),
    ),

    // 8. Display names — embed precedes generic Jaspr.
    _Case(
      'display names: all variants in one fixture',
      'A: Arcane Jaspr Flutter Embed\n'
          'B: Arcane Template\n'
          'C: Arcane Beamer\n'
          'D: Arcane Dock\n'
          'E: Arcane CLI\n'
          'F: Arcane Jaspr Docs\n'
          'G: Arcane Jaspr\n',
      _cfg(baseClassName: 'MyApp'),
    ),

    // Multi-rule fixtures — verify combined ordering doesn't double-fire.
    _Case(
      'full pubspec fragment',
      'name: arcane_app\n'
          'description: Arcane Template app\n'
          'dependencies:\n'
          '  arcane_models:\n'
          "    path: ../arcane_models\n",
      _cfg(),
    ),
    _Case(
      'jaspr full fragment',
      'name: arcane_jaspr_app\n'
          "import 'package:arcane_jaspr_app/main.dart';\n"
          'class ArcaneJasprApp {}\n'
          'description: Arcane Jaspr web app\n',
      _cfg(template: TemplateType.arcaneJaspr),
    ),
    _Case(
      'jaspr docs fragment must not be eaten by jaspr',
      'name: arcane_jaspr_docs\n'
          "import 'package:arcane_jaspr_docs/main.dart';\n"
          'description: Arcane Jaspr Docs site\n',
      _cfg(template: TemplateType.arcaneJasprDocs),
    ),
    _Case(
      'embed fragment must not be eaten by jaspr',
      'name: arcane_jaspr_flutter_embed_web\n'
          'guest: arcane_jaspr_flutter_embed_app\n'
          "import 'package:arcane_jaspr_flutter_embed_web/h.dart';\n"
          "import 'package:arcane_jaspr_flutter_embed_app/g.dart';\n"
          'class ArcaneJasprFlutterEmbedWeb {}\n'
          'class ArcaneJasprFlutterEmbedApp {}\n',
      _cfg(template: TemplateType.arcaneJasprFlutterEmbed),
    ),
  ];

  // ───────────────────────────────────────────────────────────────────
  // Generate one test per case.
  // ───────────────────────────────────────────────────────────────────

  group('setup.dart parity with PlaceholderReplacer', () {
    setUpAll(() {
      final File skeleton = File(_skeletonScriptPath());
      if (!skeleton.existsSync()) {
        fail(
          'Skeleton script not found at ${skeleton.path}. '
          'The parity test must run from the repo root or oracular/ subdir.',
        );
      }
    });

    for (final _Case c in cases) {
      test(c.name, () async {
        final PlaceholderReplacer replacer = PlaceholderReplacer(c.config);
        final String expected = replacer.replaceInContent(c.fixture);
        final String actual = await _runSkeleton(c.fixture, c.config);
        expect(
          actual,
          equals(expected),
          reason:
              'Skeleton output diverged from PlaceholderReplacer for case '
              '"${c.name}". Sync `scripts/setup_template_template.dart` '
              'with `oracular/lib/services/placeholder_replacer.dart`.',
        );
      }, timeout: testTimeout);
    }
  });
}
