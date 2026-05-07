import 'dart:io';

import 'package:oracular/models/setup_config.dart';
import 'package:oracular/models/template_info.dart';
import 'package:oracular/utils/project_config_loader.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ProjectConfigLoader', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('oracular_loader_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('loads config from generated root', () async {
      final SetupConfig config = SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.example',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneTemplate,
        outputDir: tempDir.path,
      );

      final Directory configDir = Directory(p.join(tempDir.path, 'config'));
      await configDir.create(recursive: true);
      await config.saveToFile(p.join(configDir.path, 'setup_config.env'));

      final SetupConfig? loaded = await ProjectConfigLoader.load(
        startDir: tempDir.path,
      );

      expect(loaded, isNotNull);
      expect(loaded!.appName, equals('my_app'));
    });

    test('loads config from inside main app folder', () async {
      final SetupConfig config = SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.example',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneTemplate,
        outputDir: tempDir.path,
      );

      final Directory configDir = Directory(p.join(tempDir.path, 'config'));
      final Directory appDir = Directory(p.join(tempDir.path, 'my_app'));
      await configDir.create(recursive: true);
      await appDir.create(recursive: true);
      await config.saveToFile(p.join(configDir.path, 'setup_config.env'));

      final SetupConfig? loaded = await ProjectConfigLoader.load(
        startDir: appDir.path,
      );

      expect(loaded, isNotNull);
      expect(loaded!.outputDir, equals(tempDir.path));
    });

    test('loads config from nested project folders', () async {
      final SetupConfig config = SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.example',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneTemplate,
        outputDir: tempDir.path,
      );

      final Directory configDir = Directory(p.join(tempDir.path, 'config'));
      final Directory nestedDir = Directory(
        p.join(tempDir.path, 'my_app', 'lib', 'screens'),
      );
      await configDir.create(recursive: true);
      await nestedDir.create(recursive: true);
      await config.saveToFile(p.join(configDir.path, 'setup_config.env'));

      final SetupConfig? loaded = await ProjectConfigLoader.load(
        startDir: nestedDir.path,
      );

      expect(loaded, isNotNull);
      expect(loaded!.appName, equals('my_app'));
    });
  });
}
