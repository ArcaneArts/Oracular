import 'dart:io';

import 'package:oracular/models/setup_config.dart';
import 'package:oracular/models/template_info.dart';
import 'package:oracular/services/server_setup.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ServerSetup.copyServiceAccountKey', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('oracular_server_setup_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('rotates service-account backups and keeps only 2', () async {
      final File sourceKey = File(p.join(tempDir.path, 'new-service-account.json'));
      await sourceKey.writeAsString('new-key');

      final SetupConfig config = SetupConfig(
        appName: 'test_app',
        orgDomain: 'com.test',
        baseClassName: 'TestApp',
        template: TemplateType.arcaneTemplate,
        outputDir: tempDir.path,
        createServer: true,
        serviceAccountKeyPath: sourceKey.path,
      );

      final String serverPath = p.join(tempDir.path, config.serverPackageName);
      await Directory(serverPath).create(recursive: true);

      final File currentKey = File(p.join(serverPath, 'service-account.json'));
      final File backup1 = File('${currentKey.path}.bak.1');
      final File backup2 = File('${currentKey.path}.bak.2');

      await currentKey.writeAsString('current-key');
      await backup1.writeAsString('older-key');
      await backup2.writeAsString('oldest-key');

      final ServerSetup setup = ServerSetup(config);
      await setup.copyServiceAccountKey();

      expect(await currentKey.readAsString(), equals('new-key'));
      expect(await backup1.readAsString(), equals('current-key'));
      expect(await backup2.readAsString(), equals('older-key'));
    });

    test('deploy script uses Artifact Registry image names', () async {
      final SetupConfig config = SetupConfig(
        appName: 'test_app',
        orgDomain: 'com.test',
        baseClassName: 'TestApp',
        template: TemplateType.arcaneTemplate,
        outputDir: tempDir.path,
        createServer: true,
        firebaseProjectId: 'test-project',
      );

      final String serverPath = p.join(tempDir.path, config.serverPackageName);
      await Directory(serverPath).create(recursive: true);

      final ServerSetup setup = ServerSetup(config);
      await setup.generateDeployScript();

      final File script = File(p.join(serverPath, 'script_deploy.sh'));
      final String content = await script.readAsString();

      expect(content, contains('gcloud artifacts repositories create'));
      expect(content, contains(r'$REGION-docker.pkg.dev'));
      expect(content, isNot(contains('gcr.io')));
    });
  });
}
