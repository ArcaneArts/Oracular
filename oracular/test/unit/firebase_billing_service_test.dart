import 'package:oracular/services/firebase_billing_service.dart';
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
  group('FirebaseBillingService.checkBlazeStatus', () {
    test('returns enabled when billingEnabled=true', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(
          exitCode: 0,
          stdout:
              '{"name":"projects/demo/billingInfo","projectId":"demo","billingAccountName":"billingAccounts/AAAAAA-BBBBBB-CCCCCC","billingEnabled":true}',
          stderr: '',
        ),
      ]);
      final svc = FirebaseBillingService('demo', runner: runner);

      final BillingCheckResult result = await svc.checkBlazeStatus();

      expect(result.status, BlazeStatus.enabled);
      expect(result.isBlaze, isTrue);
      expect(result.billingAccountName,
          equals('billingAccounts/AAAAAA-BBBBBB-CCCCCC'));
      expect(runner.calls, hasLength(1));
      expect(runner.calls.first.executable, equals('gcloud'));
      expect(
        runner.calls.first.arguments,
        equals(<String>[
          'beta',
          'billing',
          'projects',
          'describe',
          'demo',
          '--format=json',
        ]),
      );
    });

    test('returns notEnabled when billingEnabled=false', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(
          exitCode: 0,
          stdout:
              '{"name":"projects/demo/billingInfo","projectId":"demo","billingEnabled":false}',
          stderr: '',
        ),
      ]);
      final svc = FirebaseBillingService('demo', runner: runner);

      final BillingCheckResult result = await svc.checkBlazeStatus();

      expect(result.status, BlazeStatus.notEnabled);
      expect(result.isBlaze, isFalse);
      expect(result.billingAccountName, isNull);
    });

    test('returns notEnabled when billingEnabled is missing', () async {
      // gcloud sometimes returns just the project echo for Spark accounts.
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(
          exitCode: 0,
          stdout: '{"name":"projects/demo/billingInfo","projectId":"demo"}',
          stderr: '',
        ),
      ]);
      final svc = FirebaseBillingService('demo', runner: runner);

      final BillingCheckResult result = await svc.checkBlazeStatus();

      expect(result.status, BlazeStatus.notEnabled);
    });

    test('returns unknown on permission denied', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(
          exitCode: 1,
          stdout: '',
          stderr:
              'ERROR: (gcloud.beta.billing.projects.describe) PERMISSION_DENIED: The caller does not have permission',
        ),
      ]);
      final svc = FirebaseBillingService('demo', runner: runner);

      final BillingCheckResult result = await svc.checkBlazeStatus();

      expect(result.status, BlazeStatus.unknown);
      expect(result.message, contains('roles/billing.viewer'));
    });

    test('returns unknown on project not found', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(
          exitCode: 1,
          stdout: '',
          stderr:
              'ERROR: (gcloud.beta.billing.projects.describe) NOT_FOUND: Could not find project demo',
        ),
      ]);
      final svc = FirebaseBillingService('demo', runner: runner);

      final BillingCheckResult result = await svc.checkBlazeStatus();

      expect(result.status, BlazeStatus.unknown);
      expect(result.message, contains('Project demo was not found'));
    });

    test('returns unknown on malformed JSON', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(
          exitCode: 0,
          stdout: 'not-json-at-all',
          stderr: '',
        ),
      ]);
      final svc = FirebaseBillingService('demo', runner: runner);

      final BillingCheckResult result = await svc.checkBlazeStatus();

      expect(result.status, BlazeStatus.unknown);
      expect(result.message, contains('Could not parse billing JSON'));
    });

    test('returns unknown when no project id was provided', () async {
      final runner = _ScriptedRunner();
      final svc = FirebaseBillingService('', runner: runner);

      final BillingCheckResult result = await svc.checkBlazeStatus();

      expect(result.status, BlazeStatus.unknown);
      expect(runner.calls, isEmpty);
    });
  });

  group('FirebaseBillingService.upgradeUrl', () {
    test('uses the Firebase usage console URL', () {
      expect(
        FirebaseBillingService.upgradeUrl('demo'),
        equals('https://console.firebase.google.com/project/demo/usage/details'),
      );
    });

    test('GCP billing URL includes project query parameter', () {
      expect(
        FirebaseBillingService.gcpBillingUrl('demo'),
        equals(
          'https://console.cloud.google.com/billing/linkedaccount?project=demo',
        ),
      );
    });
  });

  group('FirebaseBillingService.guideUpgrade (non-interactive)', () {
    test('returns unknown without prompting in non-interactive mode',
        () async {
      final runner = _ScriptedRunner();
      final svc = FirebaseBillingService('demo', runner: runner);

      final BillingCheckResult result =
          await svc.guideUpgrade(interactive: false);

      expect(result.status, BlazeStatus.unknown);
      expect(result.message, contains('oracular check billing'));
      // No gcloud calls should have been made.
      expect(runner.calls, isEmpty);
    });
  });
}
