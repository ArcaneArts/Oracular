import 'dart:io';

import 'package:oracular/models/setup_config.dart';
import 'package:oracular/models/template_info.dart';
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
  });
}
