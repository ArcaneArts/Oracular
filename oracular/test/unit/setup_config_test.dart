import 'dart:io';

import 'package:oracular/models/setup_config.dart';
import 'package:oracular/models/template_info.dart';
import 'package:oracular/version.dart';
import 'package:test/test.dart';

void main() {
  group('SetupConfig', () {
    test('creates with required parameters', () {
      final config = SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.example',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneTemplate,
        outputDir: '/tmp/test',
      );

      expect(config.appName, equals('my_app'));
      expect(config.orgDomain, equals('com.example'));
      expect(config.baseClassName, equals('MyApp'));
      expect(config.template, equals(TemplateType.arcaneTemplate));
      expect(config.templateVersion, equals(oracularVersion));
      expect(config.outputDir, equals('/tmp/test'));
    });

    test('defaults optional parameters', () {
      final config = SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.example',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneTemplate,
        outputDir: '/tmp/test',
      );

      expect(config.createModels, isFalse);
      expect(config.createServer, isFalse);
      expect(config.useFirebase, isFalse);
      expect(config.firebaseProjectId, isNull);
      expect(config.setupCloudRun, isFalse);
    });

    test('defaults end-to-end Firebase fields for Flutter web', () {
      final config = SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.example',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneTemplate,
        outputDir: '/tmp/test',
      );

      // Flutter template defaults to all platforms including web.
      expect(config.supportsWebHosting, isTrue);
      expect(config.deployHostingRelease, isTrue);
      expect(config.deployHostingBeta, isTrue);
      expect(config.firestoreRegion, equals('nam5'));
      expect(config.initializeFirestore, isTrue);
      expect(config.initializeStorage, isTrue);
      expect(config.enableEmailAuth, isTrue);
      expect(config.enableGoogleAuth, isTrue);
      expect(config.requireBlaze, isFalse);
      expect(config.setupArtifactCleanup, isFalse);
      expect(config.artifactKeepRecent, equals(5));
      expect(config.artifactDeleteOlderDays, equals(30));
      expect(config.cloudRunKeepRevisions, equals(3));
    });

    test('hosting defaults are true for Jaspr docs (static)', () {
      final config = SetupConfig(
        appName: 'docs_site',
        orgDomain: 'com.example',
        baseClassName: 'DocsSite',
        template: TemplateType.arcaneJasprDocs,
        outputDir: '/tmp/test',
      );

      expect(config.supportsWebHosting, isTrue);
      expect(config.deployHostingRelease, isTrue);
      expect(config.deployHostingBeta, isTrue);
    });

    test('hosting defaults are true for Jaspr client (SPA)', () {
      final config = SetupConfig(
        appName: 'web_app',
        orgDomain: 'com.example',
        baseClassName: 'WebApp',
        template: TemplateType.arcaneJaspr,
        outputDir: '/tmp/test',
      );

      expect(config.supportsWebHosting, isTrue);
      expect(config.deployHostingRelease, isTrue);
      expect(config.deployHostingBeta, isTrue);
    });

    test('hosting defaults are false for CLI / desktop-only', () {
      final cli = SetupConfig(
        appName: 'cli_app',
        orgDomain: 'com.example',
        baseClassName: 'CliApp',
        template: TemplateType.arcaneCli,
        outputDir: '/tmp/test',
        platforms: const <String>[],
      );
      expect(cli.supportsWebHosting, isFalse);
      expect(cli.deployHostingRelease, isFalse);
      expect(cli.deployHostingBeta, isFalse);

      final dock = SetupConfig(
        appName: 'dock_app',
        orgDomain: 'com.example',
        baseClassName: 'DockApp',
        template: TemplateType.arcaneDock,
        outputDir: '/tmp/test',
        platforms: const <String>['linux', 'macos', 'windows'],
      );
      expect(dock.supportsWebHosting, isFalse);
      expect(dock.deployHostingRelease, isFalse);
      expect(dock.deployHostingBeta, isFalse);
    });

    test('requireBlaze auto-enables when server or Cloud Run is enabled', () {
      final withServer = SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.example',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneTemplate,
        outputDir: '/tmp/test',
        createServer: true,
      );
      expect(withServer.requireBlaze, isTrue);
      expect(withServer.setupArtifactCleanup, isFalse);

      final withCloudRun = SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.example',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneTemplate,
        outputDir: '/tmp/test',
        createServer: true,
        setupCloudRun: true,
      );
      expect(withCloudRun.requireBlaze, isTrue);
      expect(withCloudRun.setupArtifactCleanup, isTrue);
    });

    test('generates correct package names', () {
      final config = SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.example',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneTemplate,
        outputDir: '/tmp/test',
      );

      expect(config.modelsPackageName, equals('my_app_models'));
      expect(config.serverPackageName, equals('my_app_server'));
      expect(config.serverClassName, equals('MyAppServer'));
      expect(config.runnerClassName, equals('MyAppRunner'));
    });

    test('copyWith creates modified copy', () {
      final original = SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.example',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneTemplate,
        outputDir: '/tmp/test',
      );

      final modified = original.copyWith(
        appName: 'new_app',
        createModels: true,
      );

      expect(modified.appName, equals('new_app'));
      expect(modified.createModels, isTrue);
      expect(modified.orgDomain, equals('com.example')); // Unchanged
      expect(
        modified.template,
        equals(TemplateType.arcaneTemplate),
      ); // Unchanged
    });

    test('toDisplayMap returns correct values', () {
      final config = SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.example',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneBeamer,
        outputDir: '/tmp/test',
        createModels: true,
        createServer: true,
        useFirebase: true,
        firebaseProjectId: 'my-project',
      );

      final map = config.toDisplayMap();

      expect(map['App Name'], equals('my_app'));
      expect(map['Organization'], equals('com.example'));
      expect(map['Template'], equals('Arcane Beamer (With Navigation)'));
      expect(map['Template Version'], equals(oracularVersion));
      expect(map['Models Package'], equals('Yes'));
      expect(map['Server App'], equals('Yes'));
      expect(map['Firebase'], equals('Yes'));
      expect(map['Firebase Project'], equals('my-project'));
    });
  });

  group('SetupConfig serialization', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('oracular_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('saves and loads configuration', () async {
      final config = SetupConfig(
        appName: 'test_app',
        orgDomain: 'com.test',
        baseClassName: 'TestApp',
        template: TemplateType.arcaneBeamer,
        outputDir: tempDir.path,
        createModels: true,
        createServer: true,
        useFirebase: true,
        firebaseProjectId: 'test-project',
        setupCloudRun: true,
      );

      final configPath = '${tempDir.path}/config.env';
      await config.saveToFile(configPath);

      final loaded = await SetupConfig.loadFromFile(configPath);

      expect(loaded, isNotNull);
      expect(loaded!.appName, equals('test_app'));
      expect(loaded.orgDomain, equals('com.test'));
      expect(loaded.baseClassName, equals('TestApp'));
      expect(loaded.template, equals(TemplateType.arcaneBeamer));
      expect(loaded.templateVersion, equals(oracularVersion));
      expect(loaded.createModels, isTrue);
      expect(loaded.createServer, isTrue);
      expect(loaded.useFirebase, isTrue);
      expect(loaded.firebaseProjectId, equals('test-project'));
      expect(loaded.setupCloudRun, isTrue);
    });

    test('returns null for non-existent file', () async {
      final loaded = await SetupConfig.loadFromFile(
        '${tempDir.path}/nonexistent.env',
      );
      expect(loaded, isNull);
    });

    test('loads empty platform list for non-Flutter templates', () async {
      final configPath = '${tempDir.path}/config.env';
      await File(configPath).writeAsString('''
APP_NAME=docs_site
ORG_DOMAIN=com.test
BASE_CLASS_NAME=DocsSite
TEMPLATE_NAME=arcaneJasprDocs
OUTPUT_DIR=${tempDir.path}
PLATFORMS=
''');

      final loaded = await SetupConfig.loadFromFile(configPath);

      expect(loaded, isNotNull);
      expect(loaded!.template, equals(TemplateType.arcaneJasprDocs));
      expect(loaded.templateVersion, equals(oracularVersion));
      expect(loaded.platforms, isEmpty);
    });

    test('preserves explicit template version pins', () async {
      final config = SetupConfig(
        appName: 'test_app',
        orgDomain: 'com.test',
        baseClassName: 'TestApp',
        template: TemplateType.arcaneTemplate,
        templateVersion: '3.5.1',
        outputDir: tempDir.path,
      );

      final configPath = '${tempDir.path}/config.env';
      await config.saveToFile(configPath);

      final content = await File(configPath).readAsString();
      final loaded = await SetupConfig.loadFromFile(configPath);

      expect(content, contains('TEMPLATE_VERSION=3.5.1'));
      expect(loaded, isNotNull);
      expect(loaded!.templateVersion, equals('3.5.1'));
      expect(
        loaded.copyWith(appName: 'other_app').templateVersion,
        equals('3.5.1'),
      );
    });
  });

  group('JasprRenderMode (added 2026-05-10)', () {
    test('enum exposes display names + descriptions for every value', () {
      for (final JasprRenderMode mode in JasprRenderMode.values) {
        expect(mode.displayName, isNotEmpty);
        expect(mode.description, isNotEmpty);
      }
    });

    test('jasprYamlMode maps modes to the right Jaspr CLI mode value', () {
      expect(JasprRenderMode.csr.jasprYamlMode, equals('client'));
      expect(JasprRenderMode.ssg.jasprYamlMode, equals('static'));
      expect(JasprRenderMode.embed.jasprYamlMode, equals('static'));
      expect(JasprRenderMode.ssr.jasprYamlMode, equals('server'));
      expect(JasprRenderMode.hybrid.jasprYamlMode, equals('server'));
    });

    test('requiresCloudRun is true only for ssr + hybrid', () {
      expect(JasprRenderMode.csr.requiresCloudRun, isFalse);
      expect(JasprRenderMode.ssg.requiresCloudRun, isFalse);
      expect(JasprRenderMode.embed.requiresCloudRun, isFalse);
      expect(JasprRenderMode.ssr.requiresCloudRun, isTrue);
      expect(JasprRenderMode.hybrid.requiresCloudRun, isTrue);
    });

    test('needsServerEntrypoint is true for everything except csr', () {
      expect(JasprRenderMode.csr.needsServerEntrypoint, isFalse);
      expect(JasprRenderMode.ssg.needsServerEntrypoint, isTrue);
      expect(JasprRenderMode.ssr.needsServerEntrypoint, isTrue);
      expect(JasprRenderMode.hybrid.needsServerEntrypoint, isTrue);
      expect(JasprRenderMode.embed.needsServerEntrypoint, isTrue);
    });

    test('parse accepts canonical names + common aliases', () {
      expect(
        JasprRenderModeExtension.parse('csr'),
        equals(JasprRenderMode.csr),
      );
      expect(
        JasprRenderModeExtension.parse('client'),
        equals(JasprRenderMode.csr),
      );
      expect(
        JasprRenderModeExtension.parse('ssg'),
        equals(JasprRenderMode.ssg),
      );
      expect(
        JasprRenderModeExtension.parse('static'),
        equals(JasprRenderMode.ssg),
      );
      expect(
        JasprRenderModeExtension.parse('ssr'),
        equals(JasprRenderMode.ssr),
      );
      expect(
        JasprRenderModeExtension.parse('server'),
        equals(JasprRenderMode.ssr),
      );
      expect(
        JasprRenderModeExtension.parse('hybrid'),
        equals(JasprRenderMode.hybrid),
      );
      expect(
        JasprRenderModeExtension.parse('mixed'),
        equals(JasprRenderMode.hybrid),
      );
      expect(
        JasprRenderModeExtension.parse('embed'),
        equals(JasprRenderMode.embed),
      );
      expect(
        JasprRenderModeExtension.parse('flutter-embed'),
        equals(JasprRenderMode.embed),
      );
    });

    test('parse handles null / empty / unknown by returning null', () {
      expect(JasprRenderModeExtension.parse(null), isNull);
      expect(JasprRenderModeExtension.parse(''), isNull);
      expect(JasprRenderModeExtension.parse('   '), isNull);
      expect(JasprRenderModeExtension.parse('nonsense'), isNull);
    });
  });

  group('SetupConfig render-mode + embed fields (added 2026-05-10)', () {
    test('default render mode is csr for arcaneJaspr', () {
      final config = SetupConfig(
        appName: 'web_app',
        orgDomain: 'com.example',
        baseClassName: 'WebApp',
        template: TemplateType.arcaneJaspr,
        outputDir: '/tmp/test',
      );
      expect(config.jasprRenderMode, equals(JasprRenderMode.csr));
      expect(config.hasJasprServer, isFalse);
      expect(config.hasEmbeddedFlutter, isFalse);
    });

    test('default render mode is ssg for arcaneJasprDocs', () {
      final config = SetupConfig(
        appName: 'docs',
        orgDomain: 'com.example',
        baseClassName: 'Docs',
        template: TemplateType.arcaneJasprDocs,
        outputDir: '/tmp/test',
      );
      expect(config.jasprRenderMode, equals(JasprRenderMode.ssg));
      expect(config.hasJasprServer, isFalse);
      expect(config.hasEmbeddedFlutter, isFalse);
    });

    test('default render mode is embed for arcaneJasprFlutterEmbed', () {
      final config = SetupConfig(
        appName: 'demo',
        orgDomain: 'com.example',
        baseClassName: 'Demo',
        template: TemplateType.arcaneJasprFlutterEmbed,
        outputDir: '/tmp/test',
      );
      expect(config.jasprRenderMode, equals(JasprRenderMode.embed));
      expect(config.hasJasprServer, isFalse);
      expect(config.hasEmbeddedFlutter, isTrue);
    });

    test('ssr / hybrid configs report hasJasprServer = true', () {
      final ssr = SetupConfig(
        appName: 'demo',
        orgDomain: 'com.example',
        baseClassName: 'Demo',
        template: TemplateType.arcaneJaspr,
        outputDir: '/tmp/test',
        jasprRenderMode: JasprRenderMode.ssr,
      );
      expect(ssr.hasJasprServer, isTrue);

      final hybrid = ssr.copyWith(jasprRenderMode: JasprRenderMode.hybrid);
      expect(hybrid.hasJasprServer, isTrue);
    });

    test(
      'effectiveJasprServerServiceName replaces underscores with dashes',
      () {
        final config = SetupConfig(
          appName: 'my_app',
          orgDomain: 'com.example',
          baseClassName: 'MyApp',
          template: TemplateType.arcaneJaspr,
          outputDir: '/tmp/test',
          jasprRenderMode: JasprRenderMode.ssr,
        );
        // Default fallback: <appName>_web → my_app_web → my-app-web.
        expect(config.effectiveJasprServerServiceName, equals('my-app-web'));

        final renamed = config.copyWith(
          jasprServerServiceName: 'custom_service',
        );
        expect(
          renamed.effectiveJasprServerServiceName,
          equals('custom-service'),
        );
      },
    );

    test(
      'embedded package + class names derive from appName + baseClassName',
      () {
        final config = SetupConfig(
          appName: 'my_app',
          orgDomain: 'com.example',
          baseClassName: 'MyApp',
          template: TemplateType.arcaneJasprFlutterEmbed,
          outputDir: '/tmp/test',
        );
        expect(config.embeddedFlutterPackageName, equals('my_app_app'));
        expect(config.embeddedFlutterClassName, equals('MyAppApp'));
        expect(config.embeddedFlutterMount, equals('/app'));
      },
    );

    test('hybridDynamicPrefixes defaults to [/api, /auth]', () {
      final config = SetupConfig(
        appName: 'demo',
        orgDomain: 'com.example',
        baseClassName: 'Demo',
        template: TemplateType.arcaneJaspr,
        outputDir: '/tmp/test',
        jasprRenderMode: JasprRenderMode.hybrid,
      );
      expect(config.hybridDynamicPrefixes, equals(<String>['/api', '/auth']));
    });

    test('toDisplayMap shows render-mode rows only for Jaspr templates', () {
      final flutter = SetupConfig(
        appName: 'demo',
        orgDomain: 'com.example',
        baseClassName: 'Demo',
        template: TemplateType.arcaneTemplate,
        outputDir: '/tmp/test',
      );
      expect(flutter.toDisplayMap().containsKey('Render Mode'), isFalse);

      final ssr = SetupConfig(
        appName: 'demo',
        orgDomain: 'com.example',
        baseClassName: 'Demo',
        template: TemplateType.arcaneJaspr,
        outputDir: '/tmp/test',
        jasprRenderMode: JasprRenderMode.ssr,
      );
      final map = ssr.toDisplayMap();
      expect(map['Render Mode'], equals('SSR'));
      expect(map['Jaspr Cloud Run Service'], isNotNull);
    });

    test('saves and loads render-mode + embed + hybrid prefixes', () async {
      final tempDir = await Directory.systemTemp.createTemp('oracular_rm_');
      try {
        final config = SetupConfig(
          appName: 'demo',
          orgDomain: 'com.example',
          baseClassName: 'Demo',
          template: TemplateType.arcaneJaspr,
          outputDir: tempDir.path,
          jasprRenderMode: JasprRenderMode.hybrid,
          jasprServerServiceName: 'demo_web_service',
          embeddedFlutterMount: '/embedded',
          hybridDynamicPrefixes: const <String>['/api', '/admin', '/auth'],
        );

        final configPath = '${tempDir.path}/config.env';
        await config.saveToFile(configPath);
        final loaded = await SetupConfig.loadFromFile(configPath);

        expect(loaded, isNotNull);
        expect(loaded!.jasprRenderMode, equals(JasprRenderMode.hybrid));
        expect(loaded.jasprServerServiceName, equals('demo_web_service'));
        expect(
          loaded.effectiveJasprServerServiceName,
          equals('demo-web-service'),
        );
        expect(loaded.embeddedFlutterMount, equals('/embedded'));
        expect(
          loaded.hybridDynamicPrefixes,
          equals(<String>['/api', '/admin', '/auth']),
        );
      } finally {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test(
      'loadFromFile falls back gracefully when JASPR_RENDER_MODE is missing',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('oracular_rm_');
        try {
          final configPath = '${tempDir.path}/config.env';
          await File(configPath).writeAsString('''
APP_NAME=legacy_app
ORG_DOMAIN=com.example
BASE_CLASS_NAME=LegacyApp
TEMPLATE_NAME=arcaneJaspr
OUTPUT_DIR=${tempDir.path}
PLATFORMS=
''');
          final loaded = await SetupConfig.loadFromFile(configPath);
          expect(loaded, isNotNull);
          // Falls back to the template-derived default (csr for arcaneJaspr).
          expect(loaded!.jasprRenderMode, equals(JasprRenderMode.csr));
          expect(loaded.embeddedFlutterMount, equals('/app'));
          expect(
            loaded.hybridDynamicPrefixes,
            equals(<String>['/api', '/auth']),
          );
        } finally {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        }
      },
    );
  });
}
