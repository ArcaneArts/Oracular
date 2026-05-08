import 'dart:io';

import 'package:oracular/models/setup_config.dart';
import 'package:oracular/models/template_info.dart';
import 'package:oracular/services/server_setup.dart';
import 'package:oracular/utils/process_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Test double — captures `run` / `runWithRetry` invocations and replays
/// scripted [ProcessResult]s in order. Used to test [ServerSetup.deployToCloudRun]
/// without shelling out to gcloud / docker.
class _CapturingRunner extends ProcessRunner {
  final List<ProcessResult> results;
  final List<List<String>> invocations = <List<String>>[];

  _CapturingRunner(this.results) : super(showVerbose: false);

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool inheritStdio = false,
  }) async {
    invocations.add(<String>[executable, ...arguments]);
    if (results.isEmpty) {
      return ProcessResult(exitCode: 1, stdout: '', stderr: 'no scripted result');
    }
    return results.removeAt(0);
  }

  @override
  Future<ProcessResult?> runWithRetry(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    String? operationName,
    bool? interactive,
  }) async {
    return run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
  }
}

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

    test(
      'deploy script embeds cleanup blocks driven by SetupConfig retention values',
      () async {
        final SetupConfig config = SetupConfig(
          appName: 'test_app',
          orgDomain: 'com.test',
          baseClassName: 'TestApp',
          template: TemplateType.arcaneTemplate,
          outputDir: tempDir.path,
          createServer: true,
          firebaseProjectId: 'cleanup-project',
          artifactKeepRecent: 7,
          artifactDeleteOlderDays: 45,
          cloudRunKeepRevisions: 2,
        );

        final String serverPath = p.join(
          tempDir.path,
          config.serverPackageName,
        );
        await Directory(serverPath).create(recursive: true);

        final ServerSetup setup = ServerSetup(config);
        await setup.generateDeployScript();

        final File script = File(p.join(serverPath, 'script_deploy.sh'));
        final String content = await script.readAsString();

        // Tunables sourced from SetupConfig
        expect(content, contains('ARTIFACT_KEEP_RECENT="7"'));
        expect(content, contains('ARTIFACT_DELETE_OLDER_DAYS="45"'));
        expect(content, contains('CLOUD_RUN_KEEP_REVISIONS="2"'));

        // Cleanup commands present
        expect(
          content,
          contains('gcloud artifacts repositories set-cleanup-policies'),
        );
        expect(content, contains('gcloud run revisions list'));
        expect(content, contains('gcloud run revisions delete'));
        expect(
          content,
          contains(r'$(dirname "$0")/cleanup-policy.json'),
        );
      },
    );

    test(
      'generateDeployScript writes cleanup-policy.json with config retention',
      () async {
        final SetupConfig config = SetupConfig(
          appName: 'test_app',
          orgDomain: 'com.test',
          baseClassName: 'TestApp',
          template: TemplateType.arcaneTemplate,
          outputDir: tempDir.path,
          createServer: true,
          firebaseProjectId: 'policy-project',
          artifactKeepRecent: 9,
          artifactDeleteOlderDays: 60,
        );

        final String serverPath = p.join(
          tempDir.path,
          config.serverPackageName,
        );
        await Directory(serverPath).create(recursive: true);

        final ServerSetup setup = ServerSetup(config);
        await setup.generateDeployScript();

        final File policy = File(p.join(serverPath, 'cleanup-policy.json'));
        expect(policy.existsSync(), isTrue);

        final String body = await policy.readAsString();
        expect(body, contains('"keepCount": 9'));
        expect(body, contains('"olderThan": "60d"'));
        expect(body, contains('"name": "keep-recent"'));
        expect(body, contains('"name": "delete-stale"'));
      },
    );

    test(
      'generateDeployScript leaves a customized cleanup-policy.json untouched',
      () async {
        final SetupConfig config = SetupConfig(
          appName: 'test_app',
          orgDomain: 'com.test',
          baseClassName: 'TestApp',
          template: TemplateType.arcaneTemplate,
          outputDir: tempDir.path,
          createServer: true,
          firebaseProjectId: 'preserve-project',
        );

        final String serverPath = p.join(
          tempDir.path,
          config.serverPackageName,
        );
        await Directory(serverPath).create(recursive: true);

        // Pre-write a customized cleanup-policy.json the user "edited".
        final File policy = File(p.join(serverPath, 'cleanup-policy.json'));
        const String userContent = '[]  // user edited';
        await policy.writeAsString(userContent);

        final ServerSetup setup = ServerSetup(config);
        await setup.generateDeployScript();

        expect(await policy.readAsString(), equals(userContent));
      },
    );
  });

  // ─── deployToCloudRun ─────────────────────────────────────────────────────
  //
  // These tests verify the end-to-end Cloud Run deploy pipeline that was
  // added so `oracular deploy all` covers the SSR / hydration server. Each
  // test scripts the exact ProcessResult sequence the deploy will see and
  // asserts the right gcloud / docker invocations fire in the right order.
  group('ServerSetup.deployToCloudRun', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp
          .createTemp('oracular_server_deploy_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    SetupConfig _config({
      bool createModels = false,
      String? projectId = 'test-project',
    }) {
      return SetupConfig(
        appName: 'test_app',
        orgDomain: 'com.test',
        baseClassName: 'TestApp',
        template: TemplateType.arcaneTemplate,
        outputDir: tempDir.path,
        createServer: true,
        createModels: createModels,
        firebaseProjectId: projectId,
      );
    }

    Future<void> _scaffoldServer(SetupConfig cfg) async {
      final String serverPath = p.join(cfg.outputDir, cfg.serverPackageName);
      await Directory(serverPath).create(recursive: true);
      // Drop a Dockerfile in so deployToCloudRun doesn't regenerate one
      // (which would shell out and confuse the captured invocations).
      await File(p.join(serverPath, 'Dockerfile')).writeAsString('FROM dart');
    }

    test('returns null when createServer is false', () async {
      final SetupConfig cfg = SetupConfig(
        appName: 'test_app',
        orgDomain: 'com.test',
        baseClassName: 'TestApp',
        template: TemplateType.arcaneTemplate,
        outputDir: tempDir.path,
        // createServer defaults to false
      );
      final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[]);
      final ServerSetup setup = ServerSetup(cfg, runner: runner);

      final String? url = await setup.deployToCloudRun();

      expect(url, isNull);
      expect(runner.invocations, isEmpty,
          reason: 'should not shell out when server is disabled');
    });

    test('returns null when firebaseProjectId is missing', () async {
      final SetupConfig cfg = _config(projectId: null);
      await _scaffoldServer(cfg);
      final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[]);
      final ServerSetup setup = ServerSetup(cfg, runner: runner);

      final String? url = await setup.deployToCloudRun();

      expect(url, isNull);
      expect(runner.invocations, isEmpty);
    });

    test('returns null when server package directory is missing', () async {
      final SetupConfig cfg = _config();
      // Intentionally do NOT scaffold the server dir.
      final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[]);
      final ServerSetup setup = ServerSetup(cfg, runner: runner);

      final String? url = await setup.deployToCloudRun();

      expect(url, isNull);
      expect(runner.invocations, isEmpty);
    });

    test(
      'invokes auth → build → push → deploy → describe in order on success',
      () async {
        final SetupConfig cfg = _config();
        await _scaffoldServer(cfg);
        final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[
          // 1. gcloud auth configure-docker
          ProcessResult(exitCode: 0, stdout: '', stderr: ''),
          // 2. docker build
          ProcessResult(exitCode: 0, stdout: '', stderr: ''),
          // 3. docker push
          ProcessResult(exitCode: 0, stdout: '', stderr: ''),
          // 4. gcloud run deploy
          ProcessResult(exitCode: 0, stdout: '', stderr: ''),
          // 5. gcloud run services describe
          ProcessResult(
            exitCode: 0,
            stdout:
                'https://test-app-server-abc123-uc.a.run.app\n',
            stderr: '',
          ),
        ]);
        final ServerSetup setup = ServerSetup(cfg, runner: runner);

        final String? url = await setup.deployToCloudRun();

        expect(url, equals('https://test-app-server-abc123-uc.a.run.app'),
            reason: 'should return the URL gcloud reported, not the synthetic one');
        expect(runner.invocations, hasLength(5));

        expect(runner.invocations[0].sublist(0, 3),
            equals(<String>['gcloud', 'auth', 'configure-docker']));
        expect(runner.invocations[1].sublist(0, 2),
            equals(<String>['docker', 'build']));
        expect(runner.invocations[2].sublist(0, 2),
            equals(<String>['docker', 'push']));
        expect(runner.invocations[3].sublist(0, 3),
            equals(<String>['gcloud', 'run', 'deploy']));
        expect(runner.invocations[3], contains('test-app-server'),
            reason: 'service name = serverPackageName with underscores');
        expect(runner.invocations[4].sublist(0, 4),
            equals(<String>['gcloud', 'run', 'services', 'describe']));
      },
    );

    test('falls back to synthetic URL when describe fails', () async {
      final SetupConfig cfg = _config();
      await _scaffoldServer(cfg);
      final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[
        ProcessResult(exitCode: 0, stdout: '', stderr: ''), // auth
        ProcessResult(exitCode: 0, stdout: '', stderr: ''), // build
        ProcessResult(exitCode: 0, stdout: '', stderr: ''), // push
        ProcessResult(exitCode: 0, stdout: '', stderr: ''), // deploy
        ProcessResult(exitCode: 1, stdout: '', stderr: 'permission denied'),
      ]);
      final ServerSetup setup = ServerSetup(cfg, runner: runner);

      final String? url = await setup.deployToCloudRun();

      // Synthetic URL is technically wrong (Cloud Run uses a hash), but
      // it's better than null when deploy itself succeeded — the user
      // can find the real URL in the console.
      expect(url, isNotNull);
      expect(url!, contains('test-app-server'));
    });

    test('short-circuits when docker auth fails', () async {
      final SetupConfig cfg = _config();
      await _scaffoldServer(cfg);
      final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[
        ProcessResult(exitCode: 1, stdout: '', stderr: 'auth failed'),
      ]);
      final ServerSetup setup = ServerSetup(cfg, runner: runner);

      final String? url = await setup.deployToCloudRun();

      expect(url, isNull);
      expect(runner.invocations, hasLength(1),
          reason: 'should not attempt build/push/deploy after auth failure');
    });

    test('short-circuits when docker build fails', () async {
      final SetupConfig cfg = _config();
      await _scaffoldServer(cfg);
      final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[
        ProcessResult(exitCode: 0, stdout: '', stderr: ''), // auth
        ProcessResult(exitCode: 1, stdout: '', stderr: 'build error'),
      ]);
      final ServerSetup setup = ServerSetup(cfg, runner: runner);

      final String? url = await setup.deployToCloudRun();

      expect(url, isNull);
      expect(runner.invocations, hasLength(2),
          reason: 'should not attempt push/deploy after build failure');
    });

    test('short-circuits when docker push fails', () async {
      final SetupConfig cfg = _config();
      await _scaffoldServer(cfg);
      final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[
        ProcessResult(exitCode: 0, stdout: '', stderr: ''), // auth
        ProcessResult(exitCode: 0, stdout: '', stderr: ''), // build
        ProcessResult(exitCode: 1, stdout: '', stderr: 'push denied'),
      ]);
      final ServerSetup setup = ServerSetup(cfg, runner: runner);

      final String? url = await setup.deployToCloudRun();

      expect(url, isNull);
      expect(runner.invocations, hasLength(3),
          reason: 'should not attempt deploy after push failure');
    });

    test('short-circuits when gcloud run deploy fails', () async {
      final SetupConfig cfg = _config();
      await _scaffoldServer(cfg);
      final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[
        ProcessResult(exitCode: 0, stdout: '', stderr: ''), // auth
        ProcessResult(exitCode: 0, stdout: '', stderr: ''), // build
        ProcessResult(exitCode: 0, stdout: '', stderr: ''), // push
        ProcessResult(exitCode: 1, stdout: '', stderr: 'IAM denied'),
      ]);
      final ServerSetup setup = ServerSetup(cfg, runner: runner);

      final String? url = await setup.deployToCloudRun();

      expect(url, isNull);
      expect(runner.invocations, hasLength(4),
          reason: 'should not attempt describe after deploy failure');
    });

    test(
      'snapshots models package into Docker context when createModels=true',
      () async {
        final SetupConfig cfg = _config(createModels: true);
        await _scaffoldServer(cfg);
        // Create the models package so cp has something to copy.
        final String modelsPath = p.join(cfg.outputDir, cfg.modelsPackageName);
        await Directory(modelsPath).create(recursive: true);
        await File(p.join(modelsPath, 'pubspec.yaml'))
            .writeAsString('name: ${cfg.modelsPackageName}');

        final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[
          ProcessResult(exitCode: 0, stdout: '', stderr: ''), // cp -r
          ProcessResult(exitCode: 0, stdout: '', stderr: ''), // auth
          ProcessResult(exitCode: 0, stdout: '', stderr: ''), // build
          ProcessResult(exitCode: 0, stdout: '', stderr: ''), // push
          ProcessResult(exitCode: 0, stdout: '', stderr: ''), // deploy
          ProcessResult(
            exitCode: 0,
            stdout: 'https://x.run.app',
            stderr: '',
          ), // describe
        ]);
        final ServerSetup setup = ServerSetup(cfg, runner: runner);

        final String? url = await setup.deployToCloudRun();

        expect(url, equals('https://x.run.app'));
        expect(runner.invocations.first.first, equals('cp'),
            reason: 'should copy models snapshot first');
        expect(runner.invocations.first,
            contains(modelsPath));
      },
    );

    test('aborts when models snapshot copy fails', () async {
      final SetupConfig cfg = _config(createModels: true);
      await _scaffoldServer(cfg);
      final String modelsPath = p.join(cfg.outputDir, cfg.modelsPackageName);
      await Directory(modelsPath).create(recursive: true);

      final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[
        ProcessResult(exitCode: 1, stdout: '', stderr: 'permission denied'),
      ]);
      final ServerSetup setup = ServerSetup(cfg, runner: runner);

      final String? url = await setup.deployToCloudRun();

      expect(url, isNull);
      expect(runner.invocations, hasLength(1),
          reason: 'should not continue past models copy failure');
    });
  });
}
