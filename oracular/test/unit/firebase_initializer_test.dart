import 'package:oracular/services/firebase_initializer.dart';
import 'package:oracular/utils/process_runner.dart';
import 'package:test/test.dart';

class _CapturedCall {
  _CapturedCall(this.executable, List<String> arguments)
      : arguments = List<String>.unmodifiable(arguments);

  final String executable;
  final List<String> arguments;
}

class _ScriptedRunner extends ProcessRunner {
  _ScriptedRunner({this.results = const <ProcessResult>[]})
      : super(maxAutoRetries: 0);

  List<ProcessResult> results;
  final List<_CapturedCall> calls = <_CapturedCall>[];
  int _cursor = 0;

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool inheritStdio = false,
  }) async {
    calls.add(_CapturedCall(executable, arguments));
    if (_cursor >= results.length) {
      return ProcessResult(exitCode: 0, stdout: '', stderr: '');
    }
    return results[_cursor++];
  }
}

void main() {
  group('FirebaseInitializer.ensureFirestoreDatabase', () {
    test('returns existed=true when describe succeeds', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(
          exitCode: 0,
          stdout: '{"name":"projects/demo/databases/(default)","locationId":"nam5","type":"FIRESTORE_NATIVE"}',
          stderr: '',
        ),
      ]);
      final init = FirebaseInitializer('demo', runner: runner);

      final FirestoreInitResult result = await init.ensureFirestoreDatabase();

      expect(result.success, isTrue);
      expect(result.existed, isTrue);
      expect(result.created, isFalse);
      expect(result.region, equals('nam5'));
      // Only one call (describe); no create issued.
      expect(runner.calls, hasLength(1));
      expect(runner.calls.single.arguments,
          containsAll(<String>['firestore', 'databases', 'describe']));
    });

    test('creates database when describe returns NOT_FOUND', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(
          exitCode: 1,
          stdout: '',
          stderr:
              'ERROR: (gcloud.firestore.databases.describe) NOT_FOUND: The project demo does not exist or has no Firestore database',
        ),
        ProcessResult(exitCode: 0, stdout: '{}', stderr: ''),
      ]);
      final init = FirebaseInitializer('demo', runner: runner);

      final FirestoreInitResult result =
          await init.ensureFirestoreDatabase(region: 'eur3');

      expect(result.success, isTrue);
      expect(result.created, isTrue);
      expect(result.region, equals('eur3'));
      expect(runner.calls, hasLength(2));
      // Second call is the create.
      expect(
        runner.calls[1].arguments,
        containsAll(<String>[
          'firestore',
          'databases',
          'create',
          '--location=eur3',
        ]),
      );
    });

    test('surfaces error message on permission denied', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(
          exitCode: 1,
          stdout: '',
          stderr: 'PERMISSION_DENIED: caller does not have permission',
        ),
      ]);
      final init = FirebaseInitializer('demo', runner: runner);

      final FirestoreInitResult result = await init.ensureFirestoreDatabase();

      expect(result.success, isFalse);
      expect(result.message, contains('PERMISSION_DENIED'));
      // Only describe was called; no create attempted on auth errors.
      expect(runner.calls, hasLength(1));
    });

    test('surfaces error when create fails', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(
          exitCode: 1,
          stdout: '',
          stderr: 'ERROR: NOT_FOUND',
        ),
        ProcessResult(
          exitCode: 1,
          stdout: '',
          stderr: 'INVALID_ARGUMENT: location nam99 not supported',
        ),
      ]);
      final init = FirebaseInitializer('demo', runner: runner);

      final FirestoreInitResult result =
          await init.ensureFirestoreDatabase(region: 'nam99');

      expect(result.success, isFalse);
      expect(result.created, isFalse);
      expect(result.message, contains('INVALID_ARGUMENT'));
    });

    test('returns failure when project id is empty', () async {
      final runner = _ScriptedRunner();
      final init = FirebaseInitializer('', runner: runner);

      final FirestoreInitResult result = await init.ensureFirestoreDatabase();

      expect(result.success, isFalse);
      expect(runner.calls, isEmpty);
    });
  });

  group('FirebaseInitializer.ensureStorageBucket', () {
    test('returns existed=true when modern .firebasestorage.app bucket exists', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(
          exitCode: 0,
          stdout: '{"name":"demo.firebasestorage.app","location":"US"}',
          stderr: '',
        ),
      ]);
      final init = FirebaseInitializer('demo', runner: runner);

      final StorageInitResult result = await init.ensureStorageBucket();

      expect(result.success, isTrue);
      expect(result.existed, isTrue);
      expect(result.created, isFalse);
      expect(result.bucketName, equals('demo.firebasestorage.app'));
      // Only the first candidate is probed because it returned success.
      expect(runner.calls, hasLength(1));
    });

    test('falls back to legacy .appspot.com bucket when modern not found', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        // First probe: .firebasestorage.app — 404
        ProcessResult(
          exitCode: 1,
          stdout: '',
          stderr:
              'ERROR: (gcloud.storage.buckets.describe) HTTPError 404: bucket gs://demo.firebasestorage.app not found',
        ),
        // Second probe: .appspot.com — exists
        ProcessResult(
          exitCode: 0,
          stdout: '{"name":"demo.appspot.com","location":"US"}',
          stderr: '',
        ),
      ]);
      final init = FirebaseInitializer('demo', runner: runner);

      final StorageInitResult result = await init.ensureStorageBucket();

      expect(result.success, isTrue);
      expect(result.existed, isTrue);
      expect(result.bucketName, equals('demo.appspot.com'));
      expect(runner.calls, hasLength(2));
    });

    test('routes to needsFirebaseInit when neither candidate exists', () async {
      // Default Firebase Storage buckets cannot be created via gcloud
      // (reserved domains); when both candidates return 404 we surface the
      // console hand-off URL instead of attempting a doomed `buckets create`.
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(
          exitCode: 1,
          stdout: '',
          stderr:
              'ERROR: (gcloud.storage.buckets.describe) HTTPError 404: bucket gs://demo.firebasestorage.app not found',
        ),
        ProcessResult(
          exitCode: 1,
          stdout: '',
          stderr:
              'ERROR: (gcloud.storage.buckets.describe) HTTPError 404: bucket gs://demo.appspot.com not found',
        ),
      ]);
      final init = FirebaseInitializer('demo', runner: runner);

      final StorageInitResult result = await init.ensureStorageBucket();

      expect(result.success, isFalse);
      expect(result.needsFirebaseInit, isTrue);
      expect(result.getStartedUrl, contains('demo'));
      expect(result.getStartedUrl, contains('storage'));
      expect(result.bucketName, equals('demo.firebasestorage.app'));
      expect(result.message, contains('Get started'));
      // Both candidates probed, no `buckets create` attempted.
      expect(runner.calls, hasLength(2));
      for (final call in runner.calls) {
        expect(call.arguments, isNot(contains('create')));
      }
    });

    test('surfaces console URL when describe permission denied', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(
          exitCode: 1,
          stdout: '',
          stderr:
              'PERMISSION_DENIED: caller does not have storage.buckets.get',
        ),
        ProcessResult(
          exitCode: 1,
          stdout: '',
          stderr:
              'PERMISSION_DENIED: caller does not have storage.buckets.get',
        ),
      ]);
      final init = FirebaseInitializer('demo', runner: runner);

      final StorageInitResult result = await init.ensureStorageBucket();

      expect(result.success, isFalse);
      expect(result.needsFirebaseInit, isTrue);
      expect(result.getStartedUrl, contains('demo'));
      expect(result.getStartedUrl, contains('storage'));
    });

    test('returns failure when project id is empty', () async {
      final runner = _ScriptedRunner();
      final init = FirebaseInitializer('', runner: runner);

      final StorageInitResult result = await init.ensureStorageBucket();

      expect(result.success, isFalse);
      expect(runner.calls, isEmpty);
    });
  });

  group('FirebaseInitializer URLs', () {
    test('Storage console URL matches Firebase Console layout', () {
      expect(
        FirebaseInitializer.getStartedUrl('demo'),
        equals('https://console.firebase.google.com/project/demo/storage'),
      );
    });

    test('Firestore console URL matches Firebase Console layout', () {
      expect(
        FirebaseInitializer.firestoreConsoleUrl('demo'),
        equals('https://console.firebase.google.com/project/demo/firestore'),
      );
    });

    test('Auth providers console URL matches Firebase Console layout', () {
      expect(
        FirebaseInitializer.authProvidersConsoleUrl('demo'),
        equals(
          'https://console.firebase.google.com/project/demo/authentication/providers',
        ),
      );
    });

    test('Auth domains URL matches Firebase Console layout', () {
      expect(
        FirebaseInitializer.authDomainsConsoleUrl('demo'),
        equals(
          'https://console.firebase.google.com/project/demo/authentication/settings',
        ),
      );
    });

    test('OAuth consent URL targets Google Cloud console', () {
      expect(
        FirebaseInitializer.oauthConsentUrl('demo'),
        equals(
          'https://console.cloud.google.com/apis/credentials/consent?project=demo',
        ),
      );
    });
  });

  group('FirebaseInitializer.enableAuthProviders (non-interactive)', () {
    test('skips silently when interactive=false and reports providers',
        () async {
      final runner = _ScriptedRunner();
      final init = FirebaseInitializer('demo', runner: runner);

      final AuthProvidersResult result = await init.enableAuthProviders(
        providers: <AuthProvider>{
          AuthProvider.emailPassword,
          AuthProvider.google,
        },
        interactive: false,
      );

      expect(result.requested, hasLength(2));
      expect(result.automated, isEmpty);
      expect(result.handedOff, isEmpty);
      expect(result.success, isFalse);
      expect(result.message, contains('oracular deploy auth-providers'));
      // No shell calls should have been made.
      expect(runner.calls, isEmpty);
    });

    test('returns empty result when no providers requested', () async {
      final runner = _ScriptedRunner();
      final init = FirebaseInitializer('demo', runner: runner);

      final AuthProvidersResult result = await init.enableAuthProviders(
        providers: <AuthProvider>{},
        interactive: false,
      );

      expect(result.requested, isEmpty);
      expect(result.success, isTrue);
    });

    test('returns failure when project id is empty', () async {
      final runner = _ScriptedRunner();
      final init = FirebaseInitializer('', runner: runner);

      final AuthProvidersResult result = await init.enableAuthProviders(
        providers: <AuthProvider>{AuthProvider.emailPassword},
        interactive: false,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('No Firebase project ID'));
    });
  });

  group('AuthProvider labels', () {
    test('Email/Password label', () {
      expect(AuthProvider.emailPassword.label, equals('Email / Password'));
    });

    test('Google label', () {
      expect(AuthProvider.google.label, equals('Google sign-in'));
    });
  });
}
