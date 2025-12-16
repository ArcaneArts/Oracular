@TestOn('vm')
import 'dart:io';

import 'package:oracular/models/setup_config.dart';
import 'package:oracular/models/template_info.dart';
import 'package:oracular/services/placeholder_replacer.dart';
import 'package:oracular/services/template_copier.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late SetupConfig config;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('oracular_integration_');
    config = SetupConfig(
      appName: 'test_app',
      orgDomain: 'com.test',
      baseClassName: 'TestApp',
      template: TemplateType.arcaneTemplate,
      outputDir: tempDir.path,
      createModels: true,
      createServer: false,
      useFirebase: true,
      firebaseProjectId: 'test-project',
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('TemplateCopier', () {
    test('finds templates directory', () {
      final copier = TemplateCopier(config);
      expect(copier.templatesBasePath, isNotEmpty);
      expect(Directory(copier.templatesBasePath).existsSync(), isTrue);
    });

    test('getTemplatePath returns correct path', () {
      final copier = TemplateCopier(config);
      final path = copier.getTemplatePath('arcane_app');
      expect(path, contains('arcane_app'));
    });

    test('templates directory contains expected subdirectories', () {
      final copier = TemplateCopier(config);
      final templatesDir = Directory(copier.templatesBasePath);

      expect(
        Directory(p.join(templatesDir.path, 'arcane_app')).existsSync(),
        isTrue,
        reason: 'arcane_app should exist',
      );
      expect(
        Directory(p.join(templatesDir.path, 'arcane_beamer_app')).existsSync(),
        isTrue,
        reason: 'arcane_beamer_app should exist',
      );
      expect(
        Directory(p.join(templatesDir.path, 'arcane_dock_app')).existsSync(),
        isTrue,
        reason: 'arcane_dock_app should exist',
      );
      expect(
        Directory(p.join(templatesDir.path, 'arcane_cli_app')).existsSync(),
        isTrue,
        reason: 'arcane_cli_app should exist',
      );
      expect(
        Directory(p.join(templatesDir.path, 'arcane_models')).existsSync(),
        isTrue,
        reason: 'arcane_models should exist',
      );
      expect(
        Directory(p.join(templatesDir.path, 'arcane_server')).existsSync(),
        isTrue,
        reason: 'arcane_server should exist',
      );
    });
  });

  group('PlaceholderReplacer file processing', () {
    test('processes Dart file content with new canonical names', () async {
      final replacer = PlaceholderReplacer(config);

      // Create a test file with new canonical names
      final testFile = File(p.join(tempDir.path, 'test.dart'));
      await testFile.writeAsString('''
import 'package:arcane_app/main.dart';

class ArcaneServer {
  final String name = 'arcane_app';
  final String project = 'FIREBASE_PROJECT_ID';
}
''');

      await replacer.processFile(testFile);

      final content = await testFile.readAsString();
      expect(content, contains("package:test_app/main.dart"));
      expect(content, contains('class TestAppServer'));
      expect(content, contains("name = 'test_app'"));
      expect(content, contains("project = 'test-project'"));
    });

    test('renames files with canonical names', () async {
      final replacer = PlaceholderReplacer(config);

      // Create a test file with canonical name
      final testFile = File(p.join(tempDir.path, 'arcane_models.dart'));
      await testFile.writeAsString('// Test file');

      await replacer.processFile(testFile);

      // Original file should be renamed
      expect(testFile.existsSync(), isFalse);

      // New file should exist
      final renamedFile = File(p.join(tempDir.path, 'test_app_models.dart'));
      expect(renamedFile.existsSync(), isTrue);
    });

    test('renames arcane_cli_app files', () async {
      final cliConfig = SetupConfig(
        appName: 'my_cli',
        orgDomain: 'com.test',
        baseClassName: 'MyCli',
        template: TemplateType.arcaneCli,
        outputDir: tempDir.path,
      );
      final replacer = PlaceholderReplacer(cliConfig);

      final testFile = File(p.join(tempDir.path, 'arcane_cli_app.dart'));
      await testFile.writeAsString('// Test file');

      await replacer.processFile(testFile);

      expect(testFile.existsSync(), isFalse);
      final renamedFile = File(p.join(tempDir.path, 'my_cli.dart'));
      expect(renamedFile.existsSync(), isTrue);
    });

    test('preserves binary files', () async {
      final replacer = PlaceholderReplacer(config);

      // Create a mock "binary" file (PNG header bytes)
      final pngFile = File(p.join(tempDir.path, 'icon.png'));
      await pngFile.writeAsBytes([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);

      // Should not process binary files
      expect(replacer.shouldProcessFile(pngFile.path), isFalse);
    });
  });

  group('Template directory structure', () {
    test('arcane_app exists and has required files', () {
      final copier = TemplateCopier(config);
      final templateDir = Directory(copier.getTemplatePath('arcane_app'));

      if (templateDir.existsSync()) {
        // Check for key files
        final pubspec = File(p.join(templateDir.path, 'pubspec.yaml'));
        final libDir = Directory(p.join(templateDir.path, 'lib'));

        expect(pubspec.existsSync(), isTrue);
        expect(libDir.existsSync(), isTrue);
      }
    });

    test('arcane_models exists and has required files', () {
      final copier = TemplateCopier(config);
      final templateDir = Directory(copier.getTemplatePath('arcane_models'));

      if (templateDir.existsSync()) {
        final pubspec = File(p.join(templateDir.path, 'pubspec.yaml'));
        final libDir = Directory(p.join(templateDir.path, 'lib'));

        expect(pubspec.existsSync(), isTrue);
        expect(libDir.existsSync(), isTrue);
      }
    });

    test('arcane_server exists and has required files', () {
      final copier = TemplateCopier(config);
      final templateDir = Directory(copier.getTemplatePath('arcane_server'));

      if (templateDir.existsSync()) {
        final pubspec = File(p.join(templateDir.path, 'pubspec.yaml'));
        final libDir = Directory(p.join(templateDir.path, 'lib'));

        expect(pubspec.existsSync(), isTrue);
        expect(libDir.existsSync(), isTrue);
      }
    });
  });

  group('Template content validation', () {
    test('arcane_app pubspec has correct name', () async {
      final copier = TemplateCopier(config);
      final pubspec =
          File(p.join(copier.getTemplatePath('arcane_app'), 'pubspec.yaml'));

      if (pubspec.existsSync()) {
        final content = await pubspec.readAsString();
        expect(content, contains('name: arcane_app'));
      }
    });

    test('arcane_cli_app pubspec has correct name', () async {
      final copier = TemplateCopier(config);
      final pubspec = File(
          p.join(copier.getTemplatePath('arcane_cli_app'), 'pubspec.yaml'));

      if (pubspec.existsSync()) {
        final content = await pubspec.readAsString();
        expect(content, contains('name: arcane_cli_app'));
      }
    });

    test('arcane_models pubspec has correct name', () async {
      final copier = TemplateCopier(config);
      final pubspec =
          File(p.join(copier.getTemplatePath('arcane_models'), 'pubspec.yaml'));

      if (pubspec.existsSync()) {
        final content = await pubspec.readAsString();
        expect(content, contains('name: arcane_models'));
      }
    });

    test('arcane_server pubspec has correct name', () async {
      final copier = TemplateCopier(config);
      final pubspec =
          File(p.join(copier.getTemplatePath('arcane_server'), 'pubspec.yaml'));

      if (pubspec.existsSync()) {
        final content = await pubspec.readAsString();
        expect(content, contains('name: arcane_server'));
      }
    });
  });
}
