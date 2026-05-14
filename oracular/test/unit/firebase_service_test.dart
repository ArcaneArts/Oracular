import 'dart:io';

import 'package:oracular/models/setup_config.dart';
import 'package:oracular/models/template_info.dart';
import 'package:oracular/services/firebase_service.dart';
import 'package:oracular/utils/process_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class _CapturedCall {
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String>? environment;

  _CapturedCall({
    required this.executable,
    required this.arguments,
    this.workingDirectory,
    this.environment,
  });
}

class _CapturingRunner extends ProcessRunner {
  final List<_CapturedCall> runCalls = <_CapturedCall>[];
  final List<_CapturedCall> retryCalls = <_CapturedCall>[];
  final List<_CapturedCall> streamingCalls = <_CapturedCall>[];
  final List<ProcessResult?> retryResults = <ProcessResult?>[];
  final List<ProcessResult> runResults = <ProcessResult>[];

  _CapturingRunner() : super(maxAutoRetries: 0, showVerbose: false);

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool inheritStdio = false,
  }) async {
    runCalls.add(
      _CapturedCall(
        executable: executable,
        arguments: List<String>.from(arguments),
        workingDirectory: workingDirectory,
        environment: environment == null
            ? null
            : Map<String, String>.from(environment),
      ),
    );
    if (runResults.isNotEmpty) {
      return runResults.removeAt(0);
    }
    return ProcessResult(exitCode: 0, stdout: '', stderr: '');
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
    retryCalls.add(
      _CapturedCall(
        executable: executable,
        arguments: List<String>.from(arguments),
        workingDirectory: workingDirectory,
        environment: environment == null
            ? null
            : Map<String, String>.from(environment),
      ),
    );
    if (retryResults.isNotEmpty) {
      return retryResults.removeAt(0);
    }
    return ProcessResult(exitCode: 0, stdout: '', stderr: '');
  }

  @override
  Future<int> runStreaming(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    streamingCalls.add(
      _CapturedCall(
        executable: executable,
        arguments: List<String>.from(arguments),
        workingDirectory: workingDirectory,
        environment: environment == null
            ? null
            : Map<String, String>.from(environment),
      ),
    );
    return 0;
  }
}

void main() {
  group('FirebaseService auth + deploy behavior', () {
    late Directory tempDir;
    late File serviceAccountFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('oracular_firebase_');
      serviceAccountFile = File(p.join(tempDir.path, 'service-account.json'));
      await serviceAccountFile.writeAsString('{}');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    SetupConfig baseConfig() {
      return SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.test',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneTemplate,
        outputDir: tempDir.path,
        useFirebase: true,
        firebaseProjectId: 'test-project',
        serviceAccountKeyPath: serviceAccountFile.path,
      );
    }

    test(
      'deployFirestore passes project and service-account environment',
      () async {
        final _CapturingRunner runner = _CapturingRunner();
        final FirebaseService service = FirebaseService(
          baseConfig(),
          runner: runner,
        );

        final bool success = await service.deployFirestore();
        expect(success, isTrue);
        expect(runner.retryCalls, isNotEmpty);

        final _CapturedCall call = runner.retryCalls.last;
        expect(call.executable, equals('firebase'));
        expect(
          call.arguments,
          containsAll(<String>['--project', 'test-project']),
        );
        expect(
          call.environment?['GOOGLE_APPLICATION_CREDENTIALS'],
          equals(serviceAccountFile.path),
        );
      },
    );

    test(
      'gcloudLogin uses service account activation when key is configured',
      () async {
        final _CapturingRunner runner = _CapturingRunner();
        final FirebaseService service = FirebaseService(
          baseConfig(),
          runner: runner,
        );

        final bool success = await service.gcloudLogin();
        expect(success, isTrue);
        expect(runner.runCalls, isNotEmpty);

        final _CapturedCall call = runner.runCalls.last;
        expect(call.executable, equals('gcloud'));
        expect(call.arguments, contains('activate-service-account'));
        expect(
          call.arguments,
          containsAll(<String>['--project', 'test-project']),
        );
      },
    );

    test(
      'gcloudUserLogin always opens an interactive user-account login',
      () async {
        final _CapturingRunner runner = _CapturingRunner();
        final FirebaseService service = FirebaseService(
          baseConfig(),
          runner: runner,
        );

        final bool success = await service.gcloudUserLogin();
        expect(success, isTrue);
        expect(runner.runCalls, isEmpty);
        expect(runner.streamingCalls, hasLength(1));

        final _CapturedCall call = runner.streamingCalls.single;
        expect(call.executable, equals('gcloud'));
        expect(
          call.arguments,
          equals(<String>['auth', 'login', '--update-adc']),
        );
      },
    );

    test(
      'permission recovery never logs out Firebase CLI accounts automatically',
      () async {
        await serviceAccountFile.writeAsString(
          '{"client_email":"firebase-adminsdk@test-project.iam.gserviceaccount.com"}',
        );
        final Directory webDir = Directory(
          p.join(tempDir.path, 'my_app_web', 'web'),
        );
        await webDir.create(recursive: true);
        await File(
          p.join(webDir.path, 'index.html'),
        ).writeAsString('<html><head></head><body></body></html>');

        final _CapturingRunner runner = _CapturingRunner();
        runner.runResults.addAll(<ProcessResult>[
          ProcessResult(
            exitCode: 1,
            stdout:
                '{"status":"error","error":"PERMISSION_DENIED: caller missing firebase.apps.list"}',
            stderr: '',
          ),
          ProcessResult(
            exitCode: 0,
            stdout:
                '{"status":"success","result":[{"user":{"email":"brian@example.com"}}]}',
            stderr: '',
          ),
          ProcessResult(exitCode: 0, stdout: '(unset)\n', stderr: ''),
          ProcessResult(
            exitCode: 0,
            stdout:
                '{"status":"success","result":[{"user":{"email":"brian@example.com"}}]}',
            stderr: '',
          ),
        ]);

        final FirebaseService service = FirebaseService(
          SetupConfig(
            appName: 'my_app',
            orgDomain: 'com.test',
            baseClassName: 'MyApp',
            template: TemplateType.arcaneJaspr,
            outputDir: tempDir.path,
            useFirebase: true,
            firebaseProjectId: 'test-project',
            serviceAccountKeyPath: serviceAccountFile.path,
          ),
          runner: runner,
        );

        final bool success = await service.configureFlutterFire();

        expect(success, isFalse);
        expect(
          runner.runCalls.any(
            (_CapturedCall call) => call.arguments.contains('logout'),
          ),
          isFalse,
        );
        expect(
          runner.runCalls.where(
            (_CapturedCall call) => call.executable == 'firebase',
          ),
          hasLength(3),
        );
      },
    );

    test(
      'configureFlutterFire filters desktop platforms before Firebase app creation',
      () async {
        final Directory projectDir = Directory(p.join(tempDir.path, 'my_app'));
        await projectDir.create(recursive: true);
        await File(p.join(projectDir.path, 'pubspec.yaml')).writeAsString('''
name: my_app
dependencies:
  flutter:
    sdk: flutter
''');

        final _CapturingRunner runner = _CapturingRunner();
        runner.runResults.addAll(<ProcessResult>[
          ProcessResult(
            exitCode: 0,
            stdout: '{"status":"success","result":[]}',
            stderr: '',
          ),
          ProcessResult(
            exitCode: 0,
            stdout:
                '{"status":"success","result":{"appId":"android-app","platform":"ANDROID"}}',
            stderr: '',
          ),
          ProcessResult(
            exitCode: 0,
            stdout:
                '{"status":"success","result":{"appId":"ios-app","platform":"IOS"}}',
            stderr: '',
          ),
          ProcessResult(
            exitCode: 0,
            stdout:
                '{"status":"success","result":{"appId":"web-app","platform":"WEB"}}',
            stderr: '',
          ),
        ]);

        final FirebaseService service = FirebaseService(
          baseConfig(),
          runner: runner,
        );

        final bool success = await service.configureFlutterFire();

        expect(success, isTrue);

        final List<String> createdPlatforms = runner.runCalls
            .where(
              (_CapturedCall call) =>
                  call.executable == 'firebase' &&
                  call.arguments.contains('apps:create'),
            )
            .map((_CapturedCall call) => call.arguments[1])
            .toList(growable: false);
        expect(createdPlatforms, equals(<String>['ANDROID', 'IOS', 'WEB']));

        final List<String> configuredPlatforms = <String>[];
        final List<String> args = runner.retryCalls.single.arguments;
        for (int i = 0; i < args.length - 1; i++) {
          if (args[i] == '--platforms') {
            configuredPlatforms.add(args[i + 1]);
          }
        }
        expect(configuredPlatforms, equals(<String>['android', 'ios', 'web']));
        expect(args, isNot(contains('linux')));
        expect(args, isNot(contains('macos')));
        expect(args, isNot(contains('windows')));
      },
    );

    test(
      'login uses service account auth check instead of interactive login',
      () async {
        final _CapturingRunner runner = _CapturingRunner();
        final FirebaseService service = FirebaseService(
          baseConfig(),
          runner: runner,
        );

        final bool success = await service.login();
        expect(success, isTrue);
        expect(runner.runCalls, isNotEmpty);
        expect(runner.streamingCalls, isEmpty);

        final _CapturedCall call = runner.runCalls.first;
        expect(call.executable, equals('firebase'));
        expect(call.arguments, contains('projects:list'));
        expect(
          call.environment?['GOOGLE_APPLICATION_CREDENTIALS'],
          equals(serviceAccountFile.path),
        );
      },
    );

    test(
      'deployHostingRelease falls back to default hosting when release target fails',
      () async {
        final _CapturingRunner runner = _CapturingRunner();
        runner.retryResults.addAll(<ProcessResult?>[
          ProcessResult(
            exitCode: 1,
            stdout: '',
            stderr: 'release target failed',
          ),
          ProcessResult(exitCode: 0, stdout: '', stderr: ''),
        ]);

        final FirebaseService service = FirebaseService(
          baseConfig(),
          runner: runner,
        );

        final bool success = await service.deployHostingRelease();
        expect(success, isTrue);
        expect(runner.retryCalls.length, equals(2));
        expect(runner.retryCalls.first.arguments, contains('hosting:release'));
        expect(runner.retryCalls.last.arguments, contains('hosting'));
      },
    );

    test(
      'deployStorage can be treated as optional when Firebase Storage is not initialized',
      () async {
        final _CapturingRunner runner = _CapturingRunner();
        // 1) initial firebase deploy --only storage fails with the
        //    "not set up" message
        runner.runResults.add(
          ProcessResult(
            exitCode: 1,
            stdout:
                "Error: Firebase Storage has not been set up on project 'test-project'.",
            stderr: '',
          ),
        );
        // 2) FirebaseInitializer.ensureStorageBucket probes BOTH candidates
        //    (.firebasestorage.app then .appspot.com). Both fail with a
        //    permission error so init returns success=false and the deploy
        //    falls through to the allowNotInitialized=true branch.
        runner.runResults.add(
          ProcessResult(
            exitCode: 1,
            stdout: '',
            stderr: 'PERMISSION_DENIED: caller missing storage.buckets.get',
          ),
        );
        runner.runResults.add(
          ProcessResult(
            exitCode: 1,
            stdout: '',
            stderr: 'PERMISSION_DENIED: caller missing storage.buckets.get',
          ),
        );

        final FirebaseService service = FirebaseService(
          baseConfig(),
          runner: runner,
        );

        final bool success = await service.deployStorage(
          allowNotInitialized: true,
        );
        expect(success, isTrue);
      },
    );

    test(
      'deployStorage fails when Firebase Storage is not initialized and optional mode is off',
      () async {
        final _CapturingRunner runner = _CapturingRunner();
        // 1) initial firebase deploy --only storage fails with the
        //    "not set up" message
        runner.runResults.add(
          ProcessResult(
            exitCode: 1,
            stdout:
                "Error: Firebase Storage has not been set up on project 'test-project'.",
            stderr: '',
          ),
        );
        // 2) FirebaseInitializer.ensureStorageBucket probes both candidates;
        //    both fail → init returns success=false → deploy falls through
        //    to the allowNotInitialized=false branch and returns false.
        runner.runResults.add(
          ProcessResult(
            exitCode: 1,
            stdout: '',
            stderr: 'PERMISSION_DENIED: caller missing storage.buckets.get',
          ),
        );
        runner.runResults.add(
          ProcessResult(
            exitCode: 1,
            stdout: '',
            stderr: 'PERMISSION_DENIED: caller missing storage.buckets.get',
          ),
        );

        final FirebaseService service = FirebaseService(
          baseConfig(),
          runner: runner,
        );

        final bool success = await service.deployStorage(
          allowNotInitialized: false,
        );
        expect(success, isFalse);
      },
    );

    test(
      'deployStorage retries after detecting the default Storage bucket',
      () async {
        // Default Firebase Storage buckets cannot be created via gcloud
        // (reserved domains). The deploy-retry path triggers when the
        // first `firebase deploy` reports "not set up" but the bucket
        // actually does exist (e.g. the user just clicked "Get started"
        // in the console between the deploy attempt and the probe).
        final _CapturingRunner runner = _CapturingRunner();
        // 1) initial firebase deploy fails with not-set-up
        runner.runResults.add(
          ProcessResult(
            exitCode: 1,
            stdout:
                "Error: Firebase Storage has not been set up on project 'test-project'.",
            stderr: '',
          ),
        );
        // 2) gcloud storage buckets describe gs://test-project.firebasestorage.app
        //    → success (bucket exists)
        runner.runResults.add(
          ProcessResult(
            exitCode: 0,
            stdout:
                '{"name":"test-project.firebasestorage.app","location":"US"}',
            stderr: '',
          ),
        );
        // 3) firebase deploy --only storage retry → success
        runner.runResults.add(
          ProcessResult(exitCode: 0, stdout: 'OK', stderr: ''),
        );

        final FirebaseService service = FirebaseService(
          baseConfig(),
          runner: runner,
        );

        final bool success = await service.deployStorage(
          allowNotInitialized: false,
        );
        expect(success, isTrue);
      },
    );

    test(
      'login auto-discovers outputDir service-account.json when config path is unset',
      () async {
        final _CapturingRunner runner = _CapturingRunner();
        final SetupConfig configWithoutExplicitKey = SetupConfig(
          appName: 'my_app',
          orgDomain: 'com.test',
          baseClassName: 'MyApp',
          template: TemplateType.arcaneTemplate,
          outputDir: tempDir.path,
          useFirebase: true,
          firebaseProjectId: 'test-project',
        );

        final FirebaseService service = FirebaseService(
          configWithoutExplicitKey,
          runner: runner,
        );

        final bool success = await service.login();
        expect(success, isTrue);
        expect(runner.runCalls, isNotEmpty);
        expect(runner.streamingCalls, isEmpty);
        expect(
          runner.runCalls.first.environment?['GOOGLE_APPLICATION_CREDENTIALS'],
          equals(serviceAccountFile.path),
        );
      },
    );
  });

  group('FirebaseService IAM gate helpers', () {
    late Directory tempDir;
    late File serviceAccountFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('oracular_iam_gate_');
      serviceAccountFile = File(p.join(tempDir.path, 'service-account.json'));
      // Write a realistic SA JSON so `serviceAccountEmail` can parse
      // `client_email`. The other fields are not used by the gate.
      await serviceAccountFile.writeAsString(
        '{"type":"service_account",'
        '"project_id":"test-project",'
        '"client_email":"firebase-adminsdk@test-project.iam.gserviceaccount.com"}',
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    SetupConfig baseConfig() {
      return SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.test',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneTemplate,
        outputDir: tempDir.path,
        useFirebase: true,
        firebaseProjectId: 'test-project',
        serviceAccountKeyPath: serviceAccountFile.path,
      );
    }

    test('serviceAccountEmail extracts client_email from JSON', () {
      final FirebaseService service = FirebaseService(baseConfig());
      expect(
        service.serviceAccountEmail,
        equals('firebase-adminsdk@test-project.iam.gserviceaccount.com'),
      );
    });

    test('serviceAccountEmail returns null when JSON is malformed', () async {
      // Overwrite the SA file with garbage to confirm we don't crash.
      await serviceAccountFile.writeAsString('not-valid-json{');
      final FirebaseService service = FirebaseService(baseConfig());
      expect(service.serviceAccountEmail, isNull);
    });

    test('serviceAccountKeyPath returns the resolved path', () {
      final FirebaseService service = FirebaseService(baseConfig());
      expect(service.serviceAccountKeyPath, equals(serviceAccountFile.path));
    });

    test(
      'canEnableServices builds gcloud command without --account by default',
      () async {
        final _CapturingRunner runner = _CapturingRunner();
        final FirebaseService service = FirebaseService(
          baseConfig(),
          runner: runner,
        );

        final bool ok = await service.canEnableServices();
        expect(ok, isTrue);
        expect(runner.runCalls, hasLength(1));

        final _CapturedCall call = runner.runCalls.single;
        expect(call.executable, equals('gcloud'));
        expect(call.arguments, contains('services'));
        expect(call.arguments, contains('enable'));
        expect(call.arguments, contains('serviceusage.googleapis.com'));
        expect(
          call.arguments,
          containsAll(<String>['--project', 'test-project']),
        );
        // No --account flag when caller did not specify one.
        expect(
          call.arguments.any((String a) => a.startsWith('--account=')),
          isFalse,
        );
      },
    );

    test(
      'canEnableServices(account: foo) appends --account=foo to gcloud',
      () async {
        final _CapturingRunner runner = _CapturingRunner();
        final FirebaseService service = FirebaseService(
          baseConfig(),
          runner: runner,
        );

        final bool ok = await service.canEnableServices(
          account: 'firebase-adminsdk@test-project.iam.gserviceaccount.com',
        );
        expect(ok, isTrue);

        final _CapturedCall call = runner.runCalls.single;
        expect(
          call.arguments,
          contains(
            '--account=firebase-adminsdk@test-project.iam.gserviceaccount.com',
          ),
        );
      },
    );

    test(
      'canEnableServices returns false when gcloud exits non-zero',
      () async {
        final _CapturingRunner runner = _CapturingRunner();
        runner.runResults.add(
          ProcessResult(exitCode: 1, stdout: '', stderr: 'PERMISSION_DENIED'),
        );
        final FirebaseService service = FirebaseService(
          baseConfig(),
          runner: runner,
        );

        final bool ok = await service.canEnableServices();
        expect(ok, isFalse);
      },
    );

    test(
      'getActiveGcloudAccount parses gcloud config get-value output',
      () async {
        final _CapturingRunner runner = _CapturingRunner();
        runner.runResults.add(
          ProcessResult(exitCode: 0, stdout: 'brian@example.com\n', stderr: ''),
        );
        final FirebaseService service = FirebaseService(
          baseConfig(),
          runner: runner,
        );

        final String? active = await service.getActiveGcloudAccount();
        expect(active, equals('brian@example.com'));

        final _CapturedCall call = runner.runCalls.single;
        expect(call.executable, equals('gcloud'));
        expect(
          call.arguments,
          equals(<String>['config', 'get-value', 'account']),
        );
      },
    );

    test(
      'getActiveGcloudAccount returns null when value is "(unset)"',
      () async {
        final _CapturingRunner runner = _CapturingRunner();
        runner.runResults.add(
          ProcessResult(exitCode: 0, stdout: '(unset)\n', stderr: ''),
        );
        final FirebaseService service = FirebaseService(
          baseConfig(),
          runner: runner,
        );

        final String? active = await service.getActiveGcloudAccount();
        expect(active, isNull);
      },
    );

    test(
      'getCredentialedAccounts parses one-account-per-line output',
      () async {
        final _CapturingRunner runner = _CapturingRunner();
        runner.runResults.add(
          ProcessResult(
            exitCode: 0,
            stdout:
                'brian@example.com\n'
                'firebase-adminsdk@test-project.iam.gserviceaccount.com\n'
                'alice@example.com\n',
            stderr: '',
          ),
        );
        final FirebaseService service = FirebaseService(
          baseConfig(),
          runner: runner,
        );

        final List<String> accounts = await service.getCredentialedAccounts();
        expect(accounts, hasLength(3));
        expect(accounts, contains('brian@example.com'));
        expect(
          accounts,
          contains('firebase-adminsdk@test-project.iam.gserviceaccount.com'),
        );
        expect(accounts, contains('alice@example.com'));
      },
    );

    test(
      'addProjectIamBinding builds the canonical add-iam-policy-binding command',
      () async {
        final _CapturingRunner runner = _CapturingRunner();
        final FirebaseService service = FirebaseService(
          baseConfig(),
          runner: runner,
        );

        final ({bool success, String error})
        result = await service.addProjectIamBinding(
          projectId: 'test-project',
          member:
              'serviceAccount:firebase-adminsdk@test-project.iam.gserviceaccount.com',
          role: 'roles/serviceusage.serviceUsageAdmin',
        );

        expect(result.success, isTrue);
        expect(result.error, isEmpty);

        final _CapturedCall call = runner.runCalls.single;
        expect(call.executable, equals('gcloud'));
        expect(
          call.arguments,
          equals(<String>[
            'projects',
            'add-iam-policy-binding',
            'test-project',
            '--member=serviceAccount:firebase-adminsdk@test-project.iam.gserviceaccount.com',
            '--role=roles/serviceusage.serviceUsageAdmin',
            '--condition=None',
            '--quiet',
          ]),
        );
      },
    );

    test(
      'addProjectIamBinding can target a selected account without switching gcloud config',
      () async {
        final _CapturingRunner runner = _CapturingRunner();
        final FirebaseService service = FirebaseService(
          baseConfig(),
          runner: runner,
        );

        final ({bool success, String error}) result = await service
            .addProjectIamBinding(
              projectId: 'test-project',
              member: 'serviceAccount:foo@bar.iam.gserviceaccount.com',
              role: 'roles/firebase.admin',
              account: 'owner@example.com',
            );

        expect(result.success, isTrue);
        final _CapturedCall call = runner.runCalls.single;
        expect(call.executable, equals('gcloud'));
        expect(call.arguments, contains('--account=owner@example.com'));
        expect(call.arguments, isNot(contains('config')));
        expect(call.arguments, isNot(contains('set')));
      },
    );

    test('addProjectIamBinding surfaces stderr when gcloud fails', () async {
      final _CapturingRunner runner = _CapturingRunner();
      runner.runResults.add(
        ProcessResult(
          exitCode: 1,
          stdout: '',
          stderr: 'PERMISSION_DENIED: caller cannot setIamPolicy',
        ),
      );
      final FirebaseService service = FirebaseService(
        baseConfig(),
        runner: runner,
      );

      final ({bool success, String error}) result = await service
          .addProjectIamBinding(
            projectId: 'test-project',
            member: 'serviceAccount:foo@bar.iam.gserviceaccount.com',
            role: 'roles/owner',
          );

      expect(result.success, isFalse);
      expect(result.error, contains('PERMISSION_DENIED'));
    });
  });

  // ─── auto-recovery: error classification + firebase-debug.log parsing ────
  //
  // Step 5.5 (Configure Firebase client wiring) regresses on fresh projects
  // because `firebase apps:list WEB` returns "see firebase-debug.log for more
  // info" with no actionable hint. The recovery loop reads firebase-debug.log
  // and classifies the underlying error so we can auto-enable APIs, retry
  // transient failures, or surface a clean IAM message instead of bouncing
  // the user out to `oracular deploy firebase-setup-full`.
  //
  // These tests pin down the classifier behavior so future regressions are
  // caught in CI rather than at user runtime.
  group('FirebaseService.classifyFirebaseErrorForTest', () {
    test('returns serviceDisabled for SERVICE_DISABLED phrasing', () {
      const String raw =
          'PRECONDITION_FAILED: Firebase Management API '
          '(firebase.googleapis.com) has not been used in project test-project '
          'before or it is disabled. Enable it by visiting '
          'https://console.developers.google.com/apis/api/firebase.googleapis.com/overview '
          'then retry. SERVICE_DISABLED';
      expect(
        FirebaseService.classifyFirebaseErrorForTest(raw),
        equals(FirebaseFailureKind.serviceDisabled),
      );
    });

    test('returns serviceDisabled when only the API hostname is mentioned', () {
      const String raw =
          'Error: api firebase.googleapis.com is not enabled for project';
      expect(
        FirebaseService.classifyFirebaseErrorForTest(raw),
        equals(FirebaseFailureKind.serviceDisabled),
      );
    });

    test('returns permissionDenied for caller-missing-permission phrasing', () {
      const String raw =
          'PERMISSION_DENIED: The caller does not have permission to '
          'firebase.apps.list on project test-project';
      expect(
        FirebaseService.classifyFirebaseErrorForTest(raw),
        equals(FirebaseFailureKind.permissionDenied),
      );
    });

    test('returns permissionDenied for HTTP 403 / forbidden', () {
      const String raw = 'HTTP Error: 403, The caller is forbidden';
      expect(
        FirebaseService.classifyFirebaseErrorForTest(raw),
        equals(FirebaseFailureKind.permissionDenied),
      );
    });

    test('returns transient for 5xx / unavailable', () {
      const String raw =
          'HTTP Error: 503, Service Unavailable. '
          'Please try again later.';
      expect(
        FirebaseService.classifyFirebaseErrorForTest(raw),
        equals(FirebaseFailureKind.transient),
      );
    });

    test('returns transient for DEADLINE_EXCEEDED', () {
      const String raw = 'DEADLINE_EXCEEDED: deadline exceeded after 60s';
      expect(
        FirebaseService.classifyFirebaseErrorForTest(raw),
        equals(FirebaseFailureKind.transient),
      );
    });

    test('returns transient for socket / connection errors', () {
      expect(
        FirebaseService.classifyFirebaseErrorForTest('socket hang up'),
        equals(FirebaseFailureKind.transient),
      );
      expect(
        FirebaseService.classifyFirebaseErrorForTest('ETIMEDOUT'),
        equals(FirebaseFailureKind.transient),
      );
      expect(
        FirebaseService.classifyFirebaseErrorForTest('ECONNRESET'),
        equals(FirebaseFailureKind.transient),
      );
    });

    test('returns unknown for unrelated errors', () {
      expect(
        FirebaseService.classifyFirebaseErrorForTest(
          'Something happened that we did not anticipate',
        ),
        equals(FirebaseFailureKind.unknown),
      );
    });

    test('returns unknown for empty string', () {
      expect(
        FirebaseService.classifyFirebaseErrorForTest(''),
        equals(FirebaseFailureKind.unknown),
      );
    });
  });

  group('FirebaseService.firebaseErrorForTest', () {
    test('extracts JSON envelope error string', () {
      final ProcessResult result = ProcessResult(
        exitCode: 1,
        stdout: '{"status":"error","error":"firebase apps:list failed"}',
        stderr: '',
      );
      expect(
        FirebaseService.firebaseErrorForTest(result),
        equals('firebase apps:list failed'),
      );
    });

    test('extracts JSON envelope error.message', () {
      final ProcessResult result = ProcessResult(
        exitCode: 1,
        stdout:
            '{"status":"error","error":{"message":"caller missing permission","code":7}}',
        stderr: '',
      );
      expect(
        FirebaseService.firebaseErrorForTest(result),
        equals('caller missing permission'),
      );
    });

    test('falls back to stderr when JSON has no error field', () {
      final ProcessResult result = ProcessResult(
        exitCode: 1,
        stdout: '',
        stderr: 'gcloud: command not found',
      );
      expect(
        FirebaseService.firebaseErrorForTest(result),
        equals('gcloud: command not found'),
      );
    });

    test('falls back to exit-code message when stdout/stderr are empty', () {
      final ProcessResult result = ProcessResult(
        exitCode: 9,
        stdout: '',
        stderr: '',
      );
      expect(
        FirebaseService.firebaseErrorForTest(result),
        equals('Firebase command failed with exit code 9'),
      );
    });

    test('strips ANSI escape codes from spinner-prefixed JSON', () {
      // Firebase CLI prefixes JSON with a spinner control sequence that the
      // parser used to choke on; firebaseErrorForTest must still surface the
      // structured error message after stripping.
      const String spinnerEscape = '\x1B[2K\x1B[1G';
      final ProcessResult result = ProcessResult(
        exitCode: 1,
        stdout:
            '$spinnerEscape{"status":"error","error":"propagation in progress"}',
        stderr: '',
      );
      expect(
        FirebaseService.firebaseErrorForTest(result),
        equals('propagation in progress'),
      );
    });
  });

  // ─── canListFirebaseApps gate-probe semantics ──────────────────────────
  //
  // The IAM gate calls `canListFirebaseApps()` BEFORE step 5.4 enables
  // `firebase.googleapis.com`, so on a brand-new project the API may not
  // be enabled yet. The probe must return `true` in that case (so the
  // gate doesn't trigger an unnecessary auto-grant) and only return
  // `false` on real PERMISSION_DENIED errors.
  group('FirebaseService.canListFirebaseApps gate-probe semantics', () {
    late Directory tempDir;
    late File serviceAccountFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('oracular_can_list_');
      serviceAccountFile = File(p.join(tempDir.path, 'service-account.json'));
      await serviceAccountFile.writeAsString('{}');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    SetupConfig probeConfig() => SetupConfig(
      appName: 'my_app',
      orgDomain: 'com.test',
      baseClassName: 'MyApp',
      template: TemplateType.arcaneTemplate,
      outputDir: tempDir.path,
      useFirebase: true,
      firebaseProjectId: 'test-project',
      serviceAccountKeyPath: serviceAccountFile.path,
    );

    test('returns true on success', () async {
      final _CapturingRunner runner = _CapturingRunner();
      runner.runResults.add(
        ProcessResult(
          exitCode: 0,
          stdout: '{"status":"success","result":[]}',
          stderr: '',
        ),
      );
      final FirebaseService service = FirebaseService(
        probeConfig(),
        runner: runner,
      );
      expect(await service.canListFirebaseApps(), isTrue);
    });

    test('returns false on PERMISSION_DENIED (real IAM gap)', () async {
      final _CapturingRunner runner = _CapturingRunner();
      runner.runResults.add(
        ProcessResult(
          exitCode: 1,
          stdout:
              '{"status":"error","error":"PERMISSION_DENIED: '
              'caller does not have permission firebase.apps.list"}',
          stderr: '',
        ),
      );
      final FirebaseService service = FirebaseService(
        probeConfig(),
        runner: runner,
      );
      expect(await service.canListFirebaseApps(), isFalse);
    });

    test(
      'returns true on SERVICE_DISABLED (API not enabled — not a gate failure)',
      () async {
        // Brand-new project: firebase.googleapis.com hasn't been enabled
        // yet. The IAM gate runs BEFORE step 5.4 enables APIs, so this
        // is the expected path on a fresh project. The gate must NOT
        // fail in this case — that would force an unnecessary auto-grant
        // for a role the SA may already have.
        final _CapturingRunner runner = _CapturingRunner();
        runner.runResults.add(
          ProcessResult(
            exitCode: 1,
            stdout:
                '{"status":"error","error":'
                '"SERVICE_DISABLED: firebase.googleapis.com has not been used"}',
            stderr: '',
          ),
        );
        final FirebaseService service = FirebaseService(
          probeConfig(),
          runner: runner,
        );
        expect(await service.canListFirebaseApps(), isTrue);
      },
    );

    test('returns true on transient errors (5xx, deadline-exceeded)', () async {
      // Don't punish the SA for a propagation lag — let step 5.4 run
      // and surface the actual problem if it persists.
      final _CapturingRunner runner = _CapturingRunner();
      runner.runResults.add(
        ProcessResult(
          exitCode: 1,
          stdout:
              '{"status":"error","error":'
              '"DEADLINE_EXCEEDED: backend timeout"}',
          stderr: '',
        ),
      );
      final FirebaseService service = FirebaseService(
        probeConfig(),
        runner: runner,
      );
      expect(await service.canListFirebaseApps(), isTrue);
    });

    test('returns false when projectId is null', () async {
      final _CapturingRunner runner = _CapturingRunner();
      final SetupConfig noProject = SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.test',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneTemplate,
        outputDir: tempDir.path,
        useFirebase: true,
        firebaseProjectId: null,
        serviceAccountKeyPath: serviceAccountFile.path,
      );
      final FirebaseService service = FirebaseService(
        noProject,
        runner: runner,
      );
      expect(await service.canListFirebaseApps(), isFalse);
    });

    test('passes --account flag when account is provided', () async {
      final _CapturingRunner runner = _CapturingRunner();
      runner.runResults.add(
        ProcessResult(
          exitCode: 0,
          stdout: '{"status":"success","result":[]}',
          stderr: '',
        ),
      );
      final FirebaseService service = FirebaseService(
        probeConfig(),
        runner: runner,
      );
      await service.canListFirebaseApps(
        account: 'sa@proj.iam.gserviceaccount.com',
      );
      expect(runner.runCalls, isNotEmpty);
      final _CapturedCall call = runner.runCalls.last;
      expect(
        call.arguments,
        contains('--account=sa@proj.iam.gserviceaccount.com'),
      );
    });
  });
}
