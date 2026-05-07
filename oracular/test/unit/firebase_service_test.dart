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
        runner.runResults.add(
          ProcessResult(
            exitCode: 1,
            stdout:
                "Error: Firebase Storage has not been set up on project 'test-project'.",
            stderr: '',
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
        runner.runResults.add(
          ProcessResult(
            exitCode: 1,
            stdout:
                "Error: Firebase Storage has not been set up on project 'test-project'.",
            stderr: '',
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
}
