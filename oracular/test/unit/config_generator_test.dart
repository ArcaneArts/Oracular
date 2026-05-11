import 'dart:convert';
import 'dart:io';

import 'package:oracular/models/setup_config.dart';
import 'package:oracular/models/template_info.dart';
import 'package:oracular/services/config_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ConfigGenerator.generateFirebaseJson', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('oracular_cfg_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    /// Decode the generated firebase.json and return the `rewrites`
    /// array from the named hosting target (`release` or `beta`). The
    /// two targets are expected to share the same rewrites array — the
    /// shared assertion lives in [_assertReleaseAndBetaMatch].
    Future<List<Object?>> rewritesFor(
      Directory dir, {
      String target = 'release',
    }) async {
      final File firebaseJson = File(p.join(dir.path, 'firebase.json'));
      final Map<String, Object?> decoded =
          jsonDecode(await firebaseJson.readAsString()) as Map<String, Object?>;
      final List<Object?> hosting = decoded['hosting']! as List<Object?>;
      final Map<String, Object?> selected = hosting
          .cast<Map<String, Object?>>()
          .firstWhere((Map<String, Object?> t) => t['target'] == target);
      return selected['rewrites']! as List<Object?>;
    }

    /// Make sure the release and beta hosting blocks always emit the
    /// same rewrites — the CLI deploys them from a single source of
    /// truth, and any drift would silently break preview deploys.
    Future<void> assertReleaseAndBetaMatch(Directory dir) async {
      final List<Object?> release = await rewritesFor(dir, target: 'release');
      final List<Object?> beta = await rewritesFor(dir, target: 'beta');
      expect(jsonEncode(release), equals(jsonEncode(beta)),
          reason: 'release and beta rewrites must match');
    }

    test('uses Flutter hosting output path for Flutter templates', () async {
      final SetupConfig config = SetupConfig(
        appName: 'flutter_app',
        orgDomain: 'com.test',
        baseClassName: 'FlutterApp',
        template: TemplateType.arcaneTemplate,
        outputDir: tempDir.path,
        useFirebase: true,
        firebaseProjectId: 'test-project',
      );

      final ConfigGenerator generator = ConfigGenerator(config);
      await generator.generateFirebaseJson();

      final File firebaseJson = File(p.join(tempDir.path, 'firebase.json'));
      expect(firebaseJson.existsSync(), isTrue);

      final String content = await firebaseJson.readAsString();
      expect(content, contains('"public": "flutter_app/build/web"'));
    });

    test('uses Jaspr hosting output path for Jaspr templates', () async {
      final SetupConfig config = SetupConfig(
        appName: 'jaspr_docs',
        orgDomain: 'com.test',
        baseClassName: 'JasprDocs',
        template: TemplateType.arcaneJasprDocs,
        outputDir: tempDir.path,
        useFirebase: true,
        firebaseProjectId: 'test-project',
      );

      final ConfigGenerator generator = ConfigGenerator(config);
      await generator.generateFirebaseJson();

      final File firebaseJson = File(p.join(tempDir.path, 'firebase.json'));
      expect(firebaseJson.existsSync(), isTrue);

      final String content = await firebaseJson.readAsString();
      expect(content, contains('"public": "jaspr_docs_web/build/jaspr"'));
    });

    // ─── Render-mode-aware rewrites (plan §4.7) ──────────────────────────
    //
    // The hosting `rewrites` array varies by JasprRenderMode and the
    // generator must emit exactly the expected shape for each mode. These
    // tests are the contract for the firebase.json front-end of the
    // build/deploy pipeline — if any of them go red, the wrong requests
    // will hit Cloud Run (or none will), which silently breaks SSR /
    // hybrid in production.

    test('Flutter web (non-Jaspr) emits a single SPA fallback rewrite',
        () async {
      final SetupConfig config = SetupConfig(
        appName: 'flutter_app',
        orgDomain: 'com.test',
        baseClassName: 'FlutterApp',
        template: TemplateType.arcaneTemplate,
        outputDir: tempDir.path,
        useFirebase: true,
        firebaseProjectId: 'test-project',
      );

      await ConfigGenerator(config).generateFirebaseJson();
      await assertReleaseAndBetaMatch(tempDir);

      final List<Object?> rewrites = await rewritesFor(tempDir);
      expect(rewrites.length, equals(1));
      final Map<String, Object?> rule = rewrites.first as Map<String, Object?>;
      expect(rule['source'], equals('**'));
      expect(rule['destination'], equals('/index.html'));
    });

    test('CSR Jaspr emits a single SPA fallback rewrite', () async {
      final SetupConfig config = SetupConfig(
        appName: 'csr_site',
        orgDomain: 'com.test',
        baseClassName: 'CsrSite',
        template: TemplateType.arcaneJaspr,
        outputDir: tempDir.path,
        useFirebase: true,
        firebaseProjectId: 'test-project',
        jasprRenderMode: JasprRenderMode.csr,
      );

      await ConfigGenerator(config).generateFirebaseJson();
      await assertReleaseAndBetaMatch(tempDir);

      final List<Object?> rewrites = await rewritesFor(tempDir);
      expect(rewrites.length, equals(1));
      final Map<String, Object?> rule = rewrites.first as Map<String, Object?>;
      expect(rule['source'], equals('**'));
      expect(rule['destination'], equals('/index.html'));
    });

    test('SSG Jaspr emits an empty rewrites array (prerendered files only)',
        () async {
      final SetupConfig config = SetupConfig(
        appName: 'ssg_site',
        orgDomain: 'com.test',
        baseClassName: 'SsgSite',
        template: TemplateType.arcaneJaspr,
        outputDir: tempDir.path,
        useFirebase: true,
        firebaseProjectId: 'test-project',
        jasprRenderMode: JasprRenderMode.ssg,
      );

      await ConfigGenerator(config).generateFirebaseJson();
      await assertReleaseAndBetaMatch(tempDir);

      final List<Object?> rewrites = await rewritesFor(tempDir);
      expect(rewrites, isEmpty);
    });

    test('SSR Jaspr emits a single ** → run:<service> rewrite', () async {
      final SetupConfig config = SetupConfig(
        appName: 'ssr_site',
        orgDomain: 'com.test',
        baseClassName: 'SsrSite',
        template: TemplateType.arcaneJaspr,
        outputDir: tempDir.path,
        useFirebase: true,
        firebaseProjectId: 'test-project',
        jasprRenderMode: JasprRenderMode.ssr,
      );

      await ConfigGenerator(config).generateFirebaseJson();
      await assertReleaseAndBetaMatch(tempDir);

      final List<Object?> rewrites = await rewritesFor(tempDir);
      expect(rewrites.length, equals(1));
      final Map<String, Object?> rule = rewrites.first as Map<String, Object?>;
      expect(rule['source'], equals('**'));
      final Map<String, Object?> run = rule['run']! as Map<String, Object?>;
      expect(run['serviceId'], equals('ssr-site-web'));
      expect(run['region'], equals('us-central1'));
      expect(rule.containsKey('destination'), isFalse,
          reason: 'SSR rewrites must NOT carry a static destination');
    });

    test(
      'Hybrid Jaspr emits one Cloud Run rewrite per dynamic prefix '
      'followed by the SPA fallback',
      () async {
        final SetupConfig config = SetupConfig(
          appName: 'hybrid_site',
          orgDomain: 'com.test',
          baseClassName: 'HybridSite',
          template: TemplateType.arcaneJaspr,
          outputDir: tempDir.path,
          useFirebase: true,
          firebaseProjectId: 'test-project',
          jasprRenderMode: JasprRenderMode.hybrid,
          hybridDynamicPrefixes: const <String>['/api', 'auth', '/admin/'],
        );

        await ConfigGenerator(config).generateFirebaseJson();
        await assertReleaseAndBetaMatch(tempDir);

        final List<Object?> rewrites = await rewritesFor(tempDir);
        // 3 Cloud Run rewrites + 1 SPA fallback = 4.
        expect(rewrites.length, equals(4));

        final Map<String, Object?> api =
            rewrites[0] as Map<String, Object?>;
        final Map<String, Object?> auth =
            rewrites[1] as Map<String, Object?>;
        final Map<String, Object?> admin =
            rewrites[2] as Map<String, Object?>;
        final Map<String, Object?> spa =
            rewrites[3] as Map<String, Object?>;

        // All three accepted prefix forms ('/api', 'auth', '/admin/')
        // must normalize to '/<prefix>/**'.
        expect(api['source'], equals('/api/**'));
        expect(auth['source'], equals('/auth/**'));
        expect(admin['source'], equals('/admin/**'));

        // Each one routes to the same Cloud Run service.
        for (final Map<String, Object?> rule in <Map<String, Object?>>[
          api,
          auth,
          admin,
        ]) {
          final Map<String, Object?> run = rule['run']! as Map<String, Object?>;
          expect(run['serviceId'], equals('hybrid-site-web'));
          expect(run['region'], equals('us-central1'));
        }

        // SPA fallback last — critical: Hosting evaluates top-down, so a
        // catch-all before the Cloud Run rules would hijack every request.
        expect(spa['source'], equals('**'));
        expect(spa['destination'], equals('/index.html'));
      },
    );

    test('Embed Jaspr emits Flutter mount SPA + Jaspr SPA fallback', () async {
      final SetupConfig config = SetupConfig(
        appName: 'embed_site',
        orgDomain: 'com.test',
        baseClassName: 'EmbedSite',
        template: TemplateType.arcaneJasprFlutterEmbed,
        outputDir: tempDir.path,
        useFirebase: true,
        firebaseProjectId: 'test-project',
        embeddedFlutterMount: '/app',
      );

      await ConfigGenerator(config).generateFirebaseJson();
      await assertReleaseAndBetaMatch(tempDir);

      final List<Object?> rewrites = await rewritesFor(tempDir);
      expect(rewrites.length, equals(2));

      final Map<String, Object?> flutterMount =
          rewrites[0] as Map<String, Object?>;
      final Map<String, Object?> jasprSpa =
          rewrites[1] as Map<String, Object?>;

      // Flutter routes go to the Flutter shell, NOT the Jaspr shell.
      expect(flutterMount['source'], equals('/app/**'));
      expect(flutterMount['destination'], equals('/app/index.html'));
      // Everything else falls back to Jaspr.
      expect(jasprSpa['source'], equals('**'));
      expect(jasprSpa['destination'], equals('/index.html'));
    });

    test('Embed mount normalizes (e.g. "app" → "/app/**")', () async {
      final SetupConfig config = SetupConfig(
        appName: 'embed_norm',
        orgDomain: 'com.test',
        baseClassName: 'EmbedNorm',
        template: TemplateType.arcaneJasprFlutterEmbed,
        outputDir: tempDir.path,
        useFirebase: true,
        firebaseProjectId: 'test-project',
        embeddedFlutterMount: 'app', // missing leading slash
      );

      await ConfigGenerator(config).generateFirebaseJson();
      final List<Object?> rewrites = await rewritesFor(tempDir);
      final Map<String, Object?> flutterMount =
          rewrites[0] as Map<String, Object?>;
      expect(flutterMount['source'], equals('/app/**'));
      expect(flutterMount['destination'], equals('/app/index.html'));
    });
  });
}
