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

    /// Three scripted successes for the precondition gcloud calls that
    /// run AFTER `gcloud auth configure-docker` and BEFORE `docker build`:
    ///
    ///   1. `gcloud services enable artifactregistry.googleapis.com`
    ///   2. `gcloud services enable run.googleapis.com`
    ///   3. `gcloud artifacts repositories describe …` (success → skip
    ///      the conditional `repositories create` call)
    ///
    /// Tests that previously expected only `docker build/push/deploy`
    /// must thread these three results in between the auth call and the
    /// docker build call.
    List<ProcessResult> _preconditionSuccesses() => <ProcessResult>[
          ProcessResult(exitCode: 0, stdout: '', stderr: ''),
          ProcessResult(exitCode: 0, stdout: '', stderr: ''),
          ProcessResult(exitCode: 0, stdout: '{}', stderr: ''),
        ];

    /// One scripted success for the preflight `gcloud config get-value
    /// account` call that `deployToCloudRun` runs before *anything* else
    /// (auth, build, push, deploy). Returning `(unset)` makes the
    /// preflight a no-op (no active account → assume the user knows what
    /// they're doing and let downstream commands fail with their own
    /// clear errors). Every test that expects to reach the auth /
    /// docker / gcloud-run pipeline must prepend this.
    ProcessResult _unsetGcloudPreflight() =>
        ProcessResult(exitCode: 0, stdout: '(unset)', stderr: '');

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
      'invokes preflight → auth → prereqs → build → push → deploy → describe in order on success',
      () async {
        final SetupConfig cfg = _config();
        await _scaffoldServer(cfg);
        final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[
          // 1. preflight: gcloud config get-value account → (unset) → no-op
          _unsetGcloudPreflight(),
          // 2. gcloud auth configure-docker
          ProcessResult(exitCode: 0, stdout: '', stderr: ''),
          // 3-5. precondition APIs + repo describe (success short-circuits create)
          ..._preconditionSuccesses(),
          // 6. docker build
          ProcessResult(exitCode: 0, stdout: '', stderr: ''),
          // 7. docker push
          ProcessResult(exitCode: 0, stdout: '', stderr: ''),
          // 8. gcloud run deploy
          ProcessResult(exitCode: 0, stdout: '', stderr: ''),
          // 9. gcloud run services describe
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
        expect(runner.invocations, hasLength(9));

        expect(runner.invocations[0].sublist(0, 4),
            equals(<String>['gcloud', 'config', 'get-value', 'account']),
            reason: 'preflight: detect stale active gcloud account');
        expect(runner.invocations[1].sublist(0, 3),
            equals(<String>['gcloud', 'auth', 'configure-docker']));
        expect(runner.invocations[2].sublist(0, 3),
            equals(<String>['gcloud', 'services', 'enable']),
            reason: 'precondition: enable Artifact Registry API');
        expect(runner.invocations[2],
            contains('artifactregistry.googleapis.com'));
        expect(runner.invocations[3].sublist(0, 3),
            equals(<String>['gcloud', 'services', 'enable']),
            reason: 'precondition: enable Cloud Run API');
        expect(runner.invocations[3], contains('run.googleapis.com'));
        expect(runner.invocations[4].sublist(0, 4),
            equals(<String>['gcloud', 'artifacts', 'repositories', 'describe']),
            reason: 'precondition: describe AR repo (success skips create)');
        expect(runner.invocations[5].sublist(0, 2),
            equals(<String>['docker', 'build']));
        expect(runner.invocations[6].sublist(0, 2),
            equals(<String>['docker', 'push']));
        expect(runner.invocations[7].sublist(0, 3),
            equals(<String>['gcloud', 'run', 'deploy']));
        expect(runner.invocations[7], contains('test-app-server'),
            reason: 'service name = serverPackageName with underscores');
        expect(runner.invocations[8].sublist(0, 4),
            equals(<String>['gcloud', 'run', 'services', 'describe']));
      },
    );

    test('falls back to synthetic URL when describe fails', () async {
      final SetupConfig cfg = _config();
      await _scaffoldServer(cfg);
      final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[
        _unsetGcloudPreflight(),                            // preflight
        ProcessResult(exitCode: 0, stdout: '', stderr: ''), // auth
        ..._preconditionSuccesses(),                       // APIs + repo describe
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
        _unsetGcloudPreflight(),                                 // preflight
        ProcessResult(exitCode: 1, stdout: '', stderr: 'auth failed'),
      ]);
      final ServerSetup setup = ServerSetup(cfg, runner: runner);

      final String? url = await setup.deployToCloudRun();

      expect(url, isNull);
      expect(runner.invocations, hasLength(2),
          reason:
              'should not attempt build/push/deploy after auth failure '
              '(preflight + auth = 2 calls)');
    });

    test('short-circuits when docker build fails', () async {
      final SetupConfig cfg = _config();
      await _scaffoldServer(cfg);
      final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[
        _unsetGcloudPreflight(),                            // preflight
        ProcessResult(exitCode: 0, stdout: '', stderr: ''), // auth
        ..._preconditionSuccesses(),                       // APIs + repo describe
        ProcessResult(exitCode: 1, stdout: '', stderr: 'build error'),
      ]);
      final ServerSetup setup = ServerSetup(cfg, runner: runner);

      final String? url = await setup.deployToCloudRun();

      expect(url, isNull);
      expect(runner.invocations, hasLength(6),
          reason:
              'should not attempt push/deploy after build failure '
              '(preflight + auth + 3 preconditions + build = 6 calls)');
    });

    test('short-circuits when docker push fails', () async {
      final SetupConfig cfg = _config();
      await _scaffoldServer(cfg);
      final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[
        _unsetGcloudPreflight(),                            // preflight
        ProcessResult(exitCode: 0, stdout: '', stderr: ''), // auth
        ..._preconditionSuccesses(),                       // APIs + repo describe
        ProcessResult(exitCode: 0, stdout: '', stderr: ''), // build
        ProcessResult(exitCode: 1, stdout: '', stderr: 'push denied'),
      ]);
      final ServerSetup setup = ServerSetup(cfg, runner: runner);

      final String? url = await setup.deployToCloudRun();

      expect(url, isNull);
      expect(runner.invocations, hasLength(7),
          reason:
              'should not attempt deploy after push failure '
              '(preflight + auth + 3 preconditions + build + push = 7 calls)');
    });

    test('short-circuits when gcloud run deploy fails', () async {
      final SetupConfig cfg = _config();
      await _scaffoldServer(cfg);
      final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[
        _unsetGcloudPreflight(),                            // preflight
        ProcessResult(exitCode: 0, stdout: '', stderr: ''), // auth
        ..._preconditionSuccesses(),                       // APIs + repo describe
        ProcessResult(exitCode: 0, stdout: '', stderr: ''), // build
        ProcessResult(exitCode: 0, stdout: '', stderr: ''), // push
        ProcessResult(exitCode: 1, stdout: '', stderr: 'IAM denied'),
      ]);
      final ServerSetup setup = ServerSetup(cfg, runner: runner);

      final String? url = await setup.deployToCloudRun();

      expect(url, isNull);
      expect(runner.invocations, hasLength(8),
          reason:
              'should not attempt describe after deploy failure '
              '(preflight + auth + 3 preconditions + build + push + deploy '
              '= 8 calls)');
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
          // The preflight gcloud-account check runs FIRST, before models
          // copy / docker auth / build / push / deploy. Cleanup before
          // `cp -r` happens via Dart's `Directory.delete()`, NOT via
          // `rm` shelled out through the runner — so it does not appear
          // in `runner.invocations`.
          _unsetGcloudPreflight(),                            // preflight
          ProcessResult(exitCode: 0, stdout: '', stderr: ''), // cp -r
          ProcessResult(exitCode: 0, stdout: '', stderr: ''), // auth
          ..._preconditionSuccesses(),                       // APIs + repo describe
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
        // [0] is the preflight `gcloud config get-value account`, [1]
        // is the `cp -r` for the models snapshot.
        expect(runner.invocations[1].first, equals('cp'),
            reason: 'should copy models snapshot before docker auth');
        expect(runner.invocations[1],
            contains(modelsPath));
      },
    );

    test('aborts when models snapshot copy fails', () async {
      final SetupConfig cfg = _config(createModels: true);
      await _scaffoldServer(cfg);
      final String modelsPath = p.join(cfg.outputDir, cfg.modelsPackageName);
      await Directory(modelsPath).create(recursive: true);

      final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[
        _unsetGcloudPreflight(),                                 // preflight
        ProcessResult(exitCode: 1, stdout: '', stderr: 'permission denied'),
      ]);
      final ServerSetup setup = ServerSetup(cfg, runner: runner);

      final String? url = await setup.deployToCloudRun();

      expect(url, isNull);
      expect(runner.invocations, hasLength(2),
          reason:
              'should not continue past models copy failure '
              '(preflight + cp = 2 calls)');
      // Suppress unused-variable lint for `modelsPath` — kept intentionally
      // so the scaffolded directory survives the test.
      expect(modelsPath, isNotEmpty);
    });
    test(
      'preflight aborts when active gcloud account is a SA from a different project',
      () async {
        // Simulates the exact MyRHE-Budget bug: user previously ran an
        // oracular flow against `oraculartestdeployments` and gcloud
        // kept that SA as the active account. When they re-run against
        // `test-project`, downstream `gcloud services enable` calls
        // would fail with PERMISSION_DENIED — but the preflight catches
        // it first.
        final SetupConfig cfg = _config();
        await _scaffoldServer(cfg);
        final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[
          // 1. preflight: get active account → SA from a *different* project
          ProcessResult(
            exitCode: 0,
            stdout:
                'firebase-adminsdk-fbsvc@oraculartestdeployments.iam.gserviceaccount.com\n',
            stderr: '',
          ),
          // 2. preflight: list credentialed accounts (so the error
          //    message can suggest a better candidate). One of them is
          //    the matching SA for `test-project`.
          ProcessResult(
            exitCode: 0,
            stdout: <String>[
              'firebase-adminsdk-fbsvc@oraculartestdeployments.iam.gserviceaccount.com',
              'firebase-adminsdk-fbsvc@test-project.iam.gserviceaccount.com',
              'owner@example.com',
            ].join('\n'),
            stderr: '',
          ),
        ]);
        final ServerSetup setup = ServerSetup(cfg, runner: runner);

        final String? url = await setup.deployToCloudRun();

        expect(url, isNull,
            reason: 'preflight should abort the deploy on SA mismatch');
        expect(runner.invocations, hasLength(2),
            reason:
                'should NOT continue past preflight when active SA is '
                'from the wrong project (preflight detect + auth list = '
                '2 calls, no docker / gcloud-run calls)');
        expect(runner.invocations[0].sublist(0, 4),
            equals(<String>['gcloud', 'config', 'get-value', 'account']));
        expect(runner.invocations[1].sublist(0, 3),
            equals(<String>['gcloud', 'auth', 'list']));
      },
    );

    test(
      'preflight allows non-SA user accounts even if they look unusual',
      () async {
        // User accounts like `brian@myrhe.net` cannot be parsed as
        // service-account emails (no `<sa>@<project>.iam.gserviceaccount.
        // com` pattern), and could in principle have IAM bindings on
        // any project. The preflight must let them through.
        final SetupConfig cfg = _config();
        await _scaffoldServer(cfg);
        final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[
          // preflight: returns a user-account email → no-op, proceed
          ProcessResult(
            exitCode: 0,
            stdout: 'brian@myrhe.net\n',
            stderr: '',
          ),
          ProcessResult(exitCode: 0, stdout: '', stderr: ''), // auth
          ..._preconditionSuccesses(),                       // APIs + repo describe
          ProcessResult(exitCode: 0, stdout: '', stderr: ''), // build
          ProcessResult(exitCode: 0, stdout: '', stderr: ''), // push
          ProcessResult(exitCode: 0, stdout: '', stderr: ''), // deploy
          ProcessResult(
            exitCode: 0,
            stdout: 'https://test-app-server.run.app\n',
            stderr: '',
          ), // describe
        ]);
        final ServerSetup setup = ServerSetup(cfg, runner: runner);

        final String? url = await setup.deployToCloudRun();

        expect(url, equals('https://test-app-server.run.app'),
            reason: 'user-account preflight should be a pass-through');
        expect(runner.invocations, hasLength(9));
      },
    );

    test(
      'preflight allows SA matching the target project',
      () async {
        // The SA `<sa>@<projectId>.iam.gserviceaccount.com` is the
        // canonical "this project's own SA" — must be allowed through.
        final SetupConfig cfg = _config();
        await _scaffoldServer(cfg);
        final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[
          ProcessResult(
            exitCode: 0,
            stdout:
                'firebase-adminsdk-fbsvc@test-project.iam.gserviceaccount.com\n',
            stderr: '',
          ), // preflight: matching SA
          ProcessResult(exitCode: 0, stdout: '', stderr: ''), // auth
          ..._preconditionSuccesses(),                       // APIs + repo describe
          ProcessResult(exitCode: 0, stdout: '', stderr: ''), // build
          ProcessResult(exitCode: 0, stdout: '', stderr: ''), // push
          ProcessResult(exitCode: 0, stdout: '', stderr: ''), // deploy
          ProcessResult(
            exitCode: 0,
            stdout: 'https://test-app-server.run.app\n',
            stderr: '',
          ), // describe
        ]);
        final ServerSetup setup = ServerSetup(cfg, runner: runner);

        final String? url = await setup.deployToCloudRun();

        expect(url, equals('https://test-app-server.run.app'),
            reason: 'matching-project SA preflight should be a pass-through');
        expect(runner.invocations, hasLength(9));
      },
    );
  });
}
