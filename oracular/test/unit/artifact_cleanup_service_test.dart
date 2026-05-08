import 'dart:convert';

import 'package:oracular/services/artifact_cleanup_service.dart';
import 'package:oracular/utils/process_runner.dart';
import 'package:test/test.dart';

class _CapturedCall {
  _CapturedCall(this.executable, List<String> arguments, this.workingDirectory)
      : arguments = List<String>.unmodifiable(arguments);

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
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
    calls.add(_CapturedCall(executable, arguments, workingDirectory));
    if (_cursor >= results.length) {
      return ProcessResult(exitCode: 0, stdout: '', stderr: '');
    }
    return results[_cursor++];
  }
}

void main() {
  group('ArtifactCleanupService.ensureRepository', () {
    test('returns existed when describe succeeds', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(
          exitCode: 0,
          stdout: '{"name":"projects/demo/locations/us-central1/repositories/oracular"}',
          stderr: '',
        ),
      ]);
      final svc = ArtifactCleanupService('demo', runner: runner);

      final RepositoryEnsureResult result = await svc.ensureRepository(
        repository: 'oracular',
      );

      expect(result.success, isTrue);
      expect(result.outcome, RepositoryEnsureOutcome.existed);
      expect(result.repository, equals('oracular'));
      expect(result.region, equals('us-central1'));
      expect(runner.calls, hasLength(1));
      expect(runner.calls.single.arguments,
          containsAll(<String>['repositories', 'describe', 'oracular']));
    });

    test('creates the repository when describe returns NOT_FOUND', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(
          exitCode: 1,
          stdout: '',
          stderr: 'NOT_FOUND: The repository does not exist',
        ),
        ProcessResult(exitCode: 0, stdout: 'Created.', stderr: ''),
      ]);
      final svc = ArtifactCleanupService('demo', runner: runner);

      final RepositoryEnsureResult result = await svc.ensureRepository(
        repository: 'oracular',
      );

      expect(result.outcome, RepositoryEnsureOutcome.created);
      expect(result.success, isTrue);
      expect(result.changed, isTrue);
      expect(runner.calls, hasLength(2));
      expect(
        runner.calls[1].arguments,
        containsAll(<String>[
          'repositories',
          'create',
          'oracular',
          '--repository-format=docker',
        ]),
      );
    });

    test('treats 409 ALREADY_EXISTS during create as existed', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(exitCode: 1, stdout: '', stderr: 'NOT_FOUND'),
        ProcessResult(
          exitCode: 1,
          stdout: '',
          stderr: 'ALREADY_EXISTS: Resource already exists in the project',
        ),
      ]);
      final svc = ArtifactCleanupService('demo', runner: runner);

      final RepositoryEnsureResult result = await svc.ensureRepository(
        repository: 'oracular',
      );

      expect(result.outcome, RepositoryEnsureOutcome.existed);
      expect(result.success, isTrue);
    });

    test('returns failed when create fails for any other reason', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(exitCode: 1, stdout: '', stderr: 'NOT_FOUND'),
        ProcessResult(
          exitCode: 1,
          stdout: '',
          stderr: 'PERMISSION_DENIED: caller missing artifactregistry.repositories.create',
        ),
      ]);
      final svc = ArtifactCleanupService('demo', runner: runner);

      final RepositoryEnsureResult result = await svc.ensureRepository(
        repository: 'oracular',
      );

      expect(result.outcome, RepositoryEnsureOutcome.failed);
      expect(result.success, isFalse);
      expect(result.message, contains('PERMISSION_DENIED'));
    });

    test('honors region override', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(exitCode: 0, stdout: '{}', stderr: ''),
      ]);
      final svc = ArtifactCleanupService('demo', runner: runner);

      await svc.ensureRepository(
        repository: 'oracular',
        region: 'europe-west1',
      );

      expect(
        runner.calls.single.arguments,
        contains('--location=europe-west1'),
      );
    });

    test('returns failed when project id is empty', () async {
      final runner = _ScriptedRunner();
      final svc = ArtifactCleanupService('', runner: runner);

      final RepositoryEnsureResult result = await svc.ensureRepository(
        repository: 'oracular',
      );

      expect(result.outcome, RepositoryEnsureOutcome.failed);
      expect(runner.calls, isEmpty);
    });

    test('returns failed on a non-NOT_FOUND describe error', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(
          exitCode: 1,
          stdout: '',
          stderr: 'PERMISSION_DENIED: artifactregistry.repositories.get',
        ),
      ]);
      final svc = ArtifactCleanupService('demo', runner: runner);

      final RepositoryEnsureResult result = await svc.ensureRepository(
        repository: 'oracular',
      );

      expect(result.outcome, RepositoryEnsureOutcome.failed);
      expect(result.message, contains('PERMISSION_DENIED'));
      // Did not attempt create.
      expect(runner.calls, hasLength(1));
    });
  });

  group('ArtifactCleanupService.applyCleanupPolicies', () {
    test('writes a 2-rule policy and invokes set-cleanup-policies', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(exitCode: 0, stdout: 'Policy applied', stderr: ''),
      ]);
      final svc = ArtifactCleanupService('demo', runner: runner);

      final CleanupPolicyResult result = await svc.applyCleanupPolicies(
        repository: 'oracular',
        keepRecent: 5,
        deleteOlderDays: 30,
      );

      expect(result.success, isTrue);
      expect(result.applied, isTrue);
      expect(result.policyCount, equals(2));
      expect(runner.calls, hasLength(1));
      expect(
        runner.calls.single.arguments,
        containsAll(<String>[
          'repositories',
          'set-cleanup-policies',
          'oracular',
        ]),
      );
      // The last argument should be `--policy=<temp-file>` ending in .json.
      expect(
        runner.calls.single.arguments.any(
          (String a) => a.startsWith('--policy=') && a.endsWith('.json'),
        ),
        isTrue,
      );
    });

    test('rejects keepRecent < 1 without invoking gcloud', () async {
      final runner = _ScriptedRunner();
      final svc = ArtifactCleanupService('demo', runner: runner);

      final CleanupPolicyResult result = await svc.applyCleanupPolicies(
        repository: 'oracular',
        keepRecent: 0,
        deleteOlderDays: 30,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('keepRecent'));
      expect(runner.calls, isEmpty);
    });

    test('rejects deleteOlderDays < 1 without invoking gcloud', () async {
      final runner = _ScriptedRunner();
      final svc = ArtifactCleanupService('demo', runner: runner);

      final CleanupPolicyResult result = await svc.applyCleanupPolicies(
        repository: 'oracular',
        keepRecent: 5,
        deleteOlderDays: 0,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('deleteOlderDays'));
      expect(runner.calls, isEmpty);
    });

    test('returns failed on gcloud error and includes the message', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(
          exitCode: 1,
          stdout: '',
          stderr: 'INVALID_ARGUMENT: invalid policy format',
        ),
      ]);
      final svc = ArtifactCleanupService('demo', runner: runner);

      final CleanupPolicyResult result = await svc.applyCleanupPolicies(
        repository: 'oracular',
      );

      expect(result.success, isFalse);
      expect(result.message, contains('INVALID_ARGUMENT'));
    });

    test('returns failed when project id is empty', () async {
      final runner = _ScriptedRunner();
      final svc = ArtifactCleanupService('', runner: runner);

      final CleanupPolicyResult result = await svc.applyCleanupPolicies(
        repository: 'oracular',
      );

      expect(result.success, isFalse);
      expect(runner.calls, isEmpty);
    });
  });

  group('ArtifactCleanupService.buildPolicy', () {
    test('emits a Keep + Delete pair with the supplied parameters', () {
      final List<Map<String, Object?>> policy =
          ArtifactCleanupService.buildPolicy(
        keepRecent: 7,
        deleteOlderDays: 14,
      );

      expect(policy, hasLength(2));
      expect(policy[0]['name'], equals('keep-recent'));
      expect((policy[0]['action'] as Map<String, Object?>)['type'],
          equals('Keep'));
      expect(
        (policy[0]['mostRecentVersions'] as Map<String, Object?>)['keepCount'],
        equals(7),
      );
      expect(policy[1]['name'], equals('delete-stale'));
      expect((policy[1]['action'] as Map<String, Object?>)['type'],
          equals('Delete'));
      expect(
        (policy[1]['condition'] as Map<String, Object?>)['olderThan'],
        equals('14d'),
      );

      // Ensure the structure round-trips through JSON without exceptions.
      expect(() => jsonEncode(policy), returnsNormally);
    });
  });

  group('ArtifactCleanupService.parseRevisionList', () {
    test('extracts revision names from a Cloud Run list payload', () {
      const String stdout =
          '[{"metadata":{"name":"svc-00003-abc"}},{"metadata":{"name":"svc-00002-def"}},{"metadata":{"name":"svc-00001-ghi"}}]';

      final List<String>? out =
          ArtifactCleanupService.parseRevisionList(stdout);

      expect(out,
          equals(<String>['svc-00003-abc', 'svc-00002-def', 'svc-00001-ghi']));
    });

    test('returns empty list on empty stdout', () {
      expect(
        ArtifactCleanupService.parseRevisionList(''),
        equals(<String>[]),
      );
    });

    test('returns null on non-list payload', () {
      expect(
        ArtifactCleanupService.parseRevisionList('"not-a-list"'),
        isNull,
      );
    });

    test('returns null on invalid JSON', () {
      expect(
        ArtifactCleanupService.parseRevisionList('{not json'),
        isNull,
      );
    });

    test('skips entries missing metadata.name', () {
      const String stdout =
          '[{"metadata":{}},{"foo":"bar"},{"metadata":{"name":"keep-me"}}]';

      expect(
        ArtifactCleanupService.parseRevisionList(stdout),
        equals(<String>['keep-me']),
      );
    });
  });

  group('ArtifactCleanupService.parseTrafficRevisions', () {
    test('extracts revisionName from status.traffic', () {
      const String stdout =
          '{"status":{"traffic":[{"revisionName":"svc-00003-abc","percent":80},{"revisionName":"svc-00002-def","percent":20}]}}';

      expect(
        ArtifactCleanupService.parseTrafficRevisions(stdout),
        equals(<String>{'svc-00003-abc', 'svc-00002-def'}),
      );
    });

    test('returns empty set when status.traffic is missing', () {
      expect(
        ArtifactCleanupService.parseTrafficRevisions('{"status":{}}'),
        isEmpty,
      );
    });

    test('returns empty set on invalid JSON', () {
      expect(
        ArtifactCleanupService.parseTrafficRevisions('not json'),
        isEmpty,
      );
    });

    test('returns empty set on empty stdout', () {
      expect(
        ArtifactCleanupService.parseTrafficRevisions(''),
        isEmpty,
      );
    });
  });

  group('ArtifactCleanupService.capCloudRunRevisions', () {
    test('no-ops when revision count is at or below keepRevisions', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        // list revisions: 2 revisions
        ProcessResult(
          exitCode: 0,
          stdout: '[{"metadata":{"name":"r1"}},{"metadata":{"name":"r2"}}]',
          stderr: '',
        ),
      ]);
      final svc = ArtifactCleanupService('demo', runner: runner);

      final RevisionPruneResult result = await svc.capCloudRunRevisions(
        service: 'svc',
        keepRevisions: 3,
      );

      expect(result.success, isTrue);
      expect(result.deleted, equals(0));
      expect(result.skipped, equals(0));
      // Only the list call was made; no traffic-describe + no delete calls.
      expect(runner.calls, hasLength(1));
    });

    test('deletes revisions beyond the keep window', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        // list revisions: r1 (newest) -> r4 (oldest)
        ProcessResult(
          exitCode: 0,
          stdout:
              '[{"metadata":{"name":"r1"}},{"metadata":{"name":"r2"}},{"metadata":{"name":"r3"}},{"metadata":{"name":"r4"}}]',
          stderr: '',
        ),
        // traffic-describe: r1 takes 100% of traffic
        ProcessResult(
          exitCode: 0,
          stdout: '{"status":{"traffic":[{"revisionName":"r1","percent":100}]}}',
          stderr: '',
        ),
        // delete r3 — succeeds
        ProcessResult(exitCode: 0, stdout: 'Deleted r3', stderr: ''),
        // delete r4 — succeeds
        ProcessResult(exitCode: 0, stdout: 'Deleted r4', stderr: ''),
      ]);
      final svc = ArtifactCleanupService('demo', runner: runner);

      final RevisionPruneResult result = await svc.capCloudRunRevisions(
        service: 'svc',
        keepRevisions: 2, // keep r1, r2
      );

      expect(result.success, isTrue);
      expect(result.deleted, equals(2));
      expect(result.skipped, equals(0));
      expect(result.deletedRevisions, equals(<String>['r3', 'r4']));
      // 1 list + 1 describe + 2 deletes = 4
      expect(runner.calls, hasLength(4));
    });

    test('preserves traffic-serving revisions even outside the keep window',
        () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(
          exitCode: 0,
          stdout:
              '[{"metadata":{"name":"r1"}},{"metadata":{"name":"r2"}},{"metadata":{"name":"r3"}},{"metadata":{"name":"r4"}}]',
          stderr: '',
        ),
        // r4 (oldest) currently serving 100% traffic — must NOT be deleted
        ProcessResult(
          exitCode: 0,
          stdout:
              '{"status":{"traffic":[{"revisionName":"r4","percent":100}]}}',
          stderr: '',
        ),
        // delete r3 — succeeds
        ProcessResult(exitCode: 0, stdout: 'Deleted r3', stderr: ''),
      ]);
      final svc = ArtifactCleanupService('demo', runner: runner);

      final RevisionPruneResult result = await svc.capCloudRunRevisions(
        service: 'svc',
        keepRevisions: 2, // keep r1, r2 + protect r4
      );

      expect(result.success, isTrue);
      expect(result.deleted, equals(1));
      expect(result.deletedRevisions, equals(<String>['r3']));
      // No delete attempt for r4.
      expect(
        runner.calls.where((c) =>
            c.arguments.contains('delete') && c.arguments.contains('r4')),
        isEmpty,
      );
    });

    test('classifies "serving traffic" delete failures as skipped', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(
          exitCode: 0,
          stdout: '[{"metadata":{"name":"r1"}},{"metadata":{"name":"r2"}},{"metadata":{"name":"r3"}}]',
          stderr: '',
        ),
        ProcessResult(
          exitCode: 0,
          stdout: '{"status":{"traffic":[{"revisionName":"r1","percent":100}]}}',
          stderr: '',
        ),
        ProcessResult(
          exitCode: 1,
          stdout: '',
          stderr:
              'Cannot delete revision r3: revision is serving traffic',
        ),
      ]);
      final svc = ArtifactCleanupService('demo', runner: runner);

      final RevisionPruneResult result = await svc.capCloudRunRevisions(
        service: 'svc',
        keepRevisions: 2,
      );

      expect(result.success, isTrue);
      expect(result.deleted, equals(0));
      expect(result.skipped, equals(1));
      expect(result.skippedRevisions, equals(<String>['r3']));
    });

    test('returns success=false when a delete fails for another reason',
        () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(
          exitCode: 0,
          stdout: '[{"metadata":{"name":"r1"}},{"metadata":{"name":"r2"}},{"metadata":{"name":"r3"}}]',
          stderr: '',
        ),
        ProcessResult(
          exitCode: 0,
          stdout: '{"status":{"traffic":[{"revisionName":"r1","percent":100}]}}',
          stderr: '',
        ),
        ProcessResult(
          exitCode: 1,
          stdout: '',
          stderr: 'PERMISSION_DENIED: run.revisions.delete',
        ),
      ]);
      final svc = ArtifactCleanupService('demo', runner: runner);

      final RevisionPruneResult result = await svc.capCloudRunRevisions(
        service: 'svc',
        keepRevisions: 2,
      );

      expect(result.success, isFalse);
      expect(result.failedRevisions, equals(<String>['r3']));
    });

    test('skips when revision list call fails', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(
          exitCode: 1,
          stdout: '',
          stderr: 'PERMISSION_DENIED: run.revisions.list',
        ),
      ]);
      final svc = ArtifactCleanupService('demo', runner: runner);

      final RevisionPruneResult result = await svc.capCloudRunRevisions(
        service: 'svc',
        keepRevisions: 2,
      );

      // Cannot determine state, so we don't try anything destructive.
      expect(result.success, isTrue);
      expect(result.deleted, equals(0));
      expect(result.skipped, equals(0));
      expect(result.message, contains('skipping prune'));
      expect(runner.calls, hasLength(1));
    });

    test('rejects keepRevisions < 1 without invoking gcloud', () async {
      final runner = _ScriptedRunner();
      final svc = ArtifactCleanupService('demo', runner: runner);

      final RevisionPruneResult result = await svc.capCloudRunRevisions(
        service: 'svc',
        keepRevisions: 0,
      );

      expect(result.success, isTrue); // no failed deletes
      expect(result.deleted, equals(0));
      expect(result.message, contains('keepRevisions'));
      expect(runner.calls, isEmpty);
    });

    test('returns failed when project id is empty', () async {
      final runner = _ScriptedRunner();
      final svc = ArtifactCleanupService('', runner: runner);

      final RevisionPruneResult result = await svc.capCloudRunRevisions(
        service: 'svc',
      );

      expect(result.deleted, equals(0));
      expect(result.message, contains('No Firebase'));
      expect(runner.calls, isEmpty);
    });
  });
}
