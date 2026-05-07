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
  });
}
