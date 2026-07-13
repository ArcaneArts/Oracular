import 'dart:io';

import 'package:oracular/models/setup_config.dart';
import 'package:oracular/models/template_info.dart';
import 'package:oracular/services/docs_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('DocsGenerator', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('oracular_docs_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'documents companion commands and omits Flutter build_runner script',
      () async {
        final config = SetupConfig(
          appName: 'my_app',
          orgDomain: 'com.example',
          baseClassName: 'MyApp',
          template: TemplateType.arcaneTemplate,
          outputDir: tempDir.path,
          platforms: const <String>['web'],
        );

        await DocsGenerator.write(config);
        final commands = await File(
          p.join(tempDir.path, 'docs', '02-commands.md'),
        ).readAsString();
        final development = await File(
          p.join(tempDir.path, 'docs', '04-development.md'),
        ).readAsString();

        expect(commands, contains('oracular new <app_name>'));
        expect(commands, contains('oracular next'));
        expect(commands, contains('oracular verify'));
        expect(commands, contains('| `dev` | `flutter run` |'));
        expect(commands, isNot(contains('### Models scripts')));
        expect(development, contains('No code generation is required'));
      },
    );

    test('uses Flutter commands for generated server package checks', () async {
      final config = SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.example',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneTemplate,
        outputDir: tempDir.path,
        createServer: true,
        createModels: true,
        platforms: const <String>['web'],
      );

      await DocsGenerator.write(config);
      final gettingStarted = await File(
        p.join(tempDir.path, 'docs', '01-getting-started.md'),
      ).readAsString();
      final commands = await File(
        p.join(tempDir.path, 'docs', '02-commands.md'),
      ).readAsString();

      expect(
        gettingStarted,
        contains('cd ../${config.serverPackageName} && flutter pub get'),
      );
      expect(
        commands,
        contains('| `deploy` | `oracular deploy arcane-server` |'),
      );
      expect(commands, contains('| `test` | `flutter test` |'));
      expect(commands, contains('### Models scripts'));
    });
  });
}
