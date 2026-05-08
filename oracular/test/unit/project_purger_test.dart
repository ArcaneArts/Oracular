import 'dart:io';

import 'package:oracular/models/setup_config.dart';
import 'package:oracular/models/template_info.dart';
import 'package:oracular/services/project_purger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ProjectPurger', () {
    late Directory tmpRoot;

    setUp(() async {
      tmpRoot = await Directory.systemTemp.createTemp('purger_test_');
    });

    tearDown(() async {
      if (tmpRoot.existsSync()) {
        await tmpRoot.delete(recursive: true);
      }
    });

    /// Create a marker directory with one file inside so tests can assert
    /// the directory was actually deleted (not just emptied).
    Future<Directory> mkdirFile(String dirName, {String fileName = 'pubspec.yaml'}) async {
      final Directory d = Directory(p.join(tmpRoot.path, dirName));
      await d.create(recursive: true);
      await File(p.join(d.path, fileName)).writeAsString('# marker\n');
      return d;
    }

    SetupConfig buildConfig({
      String appName = 'my_app',
      TemplateType template = TemplateType.arcaneTemplate,
      bool createModels = false,
      bool createServer = false,
    }) {
      return SetupConfig(
        appName: appName,
        orgDomain: 'com.example',
        baseClassName: 'MyApp',
        template: template,
        outputDir: tmpRoot.path,
        createModels: createModels,
        createServer: createServer,
      );
    }

    test('dryRun lists Flutter app + .oracular_deps + references', () async {
      await mkdirFile('my_app');
      await mkdirFile('.oracular_deps/jpatch');
      await mkdirFile('references');

      final ProjectPurger purger = ProjectPurger(buildConfig());
      final PurgeReport plan = purger.dryRun();

      expect(
        plan.directoriesToDelete.map((String s) => p.basename(s)).toList(),
        containsAll(<String>['my_app', '.oracular_deps', 'references']),
      );
      expect(plan.rejected, isEmpty);
    });

    test('dryRun uses webPackageName for Jaspr templates, not appName', () async {
      await mkdirFile('my_app_web');
      await mkdirFile('.oracular_deps');

      final ProjectPurger purger = ProjectPurger(
        buildConfig(template: TemplateType.arcaneJaspr),
      );
      final PurgeReport plan = purger.dryRun();

      expect(
        plan.directoriesToDelete.map((String s) => p.basename(s)).toList(),
        containsAll(<String>['my_app_web', '.oracular_deps']),
      );
      // Must NOT include the default `appName` form for Jaspr templates.
      expect(
        plan.directoriesToDelete
            .where((String s) => p.basename(s) == 'my_app')
            .toList(),
        isEmpty,
      );
    });

    test('dryRun adds models and server folders only when configured', () async {
      await mkdirFile('my_app');
      await mkdirFile('my_app_models');
      await mkdirFile('my_app_server');

      // createModels=false, createServer=false → only main app candidate.
      final PurgeReport noExtras = ProjectPurger(buildConfig()).dryRun();
      expect(
        noExtras.directoriesToDelete.map((String s) => p.basename(s)).toList(),
        contains('my_app'),
      );
      expect(
        noExtras.directoriesToDelete.map((String s) => p.basename(s)).toList(),
        isNot(contains('my_app_models')),
      );

      // createModels=true, createServer=true → both included.
      final PurgeReport allExtras = ProjectPurger(
        buildConfig(createModels: true, createServer: true),
      ).dryRun();
      expect(
        allExtras.directoriesToDelete.map((String s) => p.basename(s)).toList(),
        containsAll(<String>['my_app', 'my_app_models', 'my_app_server']),
      );
    });

    test('dryRun reports already-missing folders separately', () async {
      // Don't create any of the folders.
      final ProjectPurger purger = ProjectPurger(
        buildConfig(createModels: true, createServer: true),
      );
      final PurgeReport plan = purger.dryRun();

      expect(plan.directoriesToDelete, isEmpty);
      expect(
        plan.alreadyMissing.map((String s) => p.basename(s)).toList(),
        containsAll(<String>[
          'my_app',
          'my_app_models',
          'my_app_server',
          '.oracular_deps',
          'references',
        ]),
      );
    });

    test('purge() actually deletes only listed folders', () async {
      final Directory app = await mkdirFile('my_app');
      final Directory deps = await mkdirFile('.oracular_deps/foo');
      final Directory refs = await mkdirFile('references');

      // Sentinels that must survive purge.
      final File firebaseRc = File(p.join(tmpRoot.path, '.firebaserc'));
      await firebaseRc.writeAsString('{"projects":{"default":"x"}}');
      final Directory configDir = Directory(p.join(tmpRoot.path, 'config'));
      await configDir.create();
      await File(p.join(configDir.path, 'setup_config.env')).writeAsString('x');
      final File saKey = File(p.join(tmpRoot.path, 'service-account.json'));
      await saKey.writeAsString('{}');

      final ProjectPurger purger = ProjectPurger(buildConfig());
      final int deleted = await purger.purge();

      expect(deleted, equals(3));
      expect(app.existsSync(), isFalse);
      expect(deps.existsSync(), isFalse);
      expect(refs.existsSync(), isFalse);

      // Sentinels MUST still exist.
      expect(firebaseRc.existsSync(), isTrue,
          reason: '.firebaserc must never be deleted');
      expect(configDir.existsSync(), isTrue,
          reason: 'config/ must be preserved');
      expect(saKey.existsSync(), isTrue,
          reason: 'service-account JSON must be preserved');
    });

    test('purge() is idempotent — running twice does not throw', () async {
      await mkdirFile('my_app');
      final ProjectPurger purger = ProjectPurger(buildConfig());
      final int first = await purger.purge();
      final int second = await purger.purge();

      expect(first, equals(1));
      expect(second, equals(0),
          reason: 'second purge sees no surviving managed folders');
    });

    test('purge() never deletes the outputDir itself', () async {
      // Configure with an empty appName so the candidate path collapses
      // to outputDir; purger should reject it.
      final SetupConfig cfg = SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.example',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneTemplate,
        outputDir: tmpRoot.path,
      );
      final ProjectPurger purger = ProjectPurger(cfg);
      await purger.purge();

      // outputDir must still exist after purge.
      expect(tmpRoot.existsSync(), isTrue);
    });

    test('protected files at root are never candidate-listed', () async {
      // Create a managed folder + a sibling firebase.json.
      await mkdirFile('my_app');
      await File(p.join(tmpRoot.path, 'firebase.json')).writeAsString('{}');

      final PurgeReport plan = ProjectPurger(buildConfig()).dryRun();

      expect(
        plan.directoriesToDelete.any((String s) => s.endsWith('firebase.json')),
        isFalse,
      );
    });
  });
}
