import 'package:oracular/services/hosting_site_manager.dart';
import 'package:oracular/utils/process_runner.dart';
import 'package:test/test.dart';

class _CapturedCall {
  _CapturedCall(this.executable, List<String> arguments, this.workingDirectory,
      this.environment)
      : arguments = List<String>.unmodifiable(arguments);

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String>? environment;
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
    calls.add(_CapturedCall(executable, arguments, workingDirectory,
        environment == null ? null : Map<String, String>.from(environment)));
    if (_cursor >= results.length) {
      return ProcessResult(exitCode: 0, stdout: '', stderr: '');
    }
    return results[_cursor++];
  }
}

void main() {
  group('HostingSiteManager.listSites', () {
    test('parses the standard Firebase CLI JSON envelope', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(
          exitCode: 0,
          stdout: '{"status":"success","result":{"sites":[{"name":"projects/123/sites/demo","siteId":"demo","type":"DEFAULT_SITE"},{"name":"projects/123/sites/demo-beta","siteId":"demo-beta","type":"USER_SITE"}]}}',
          stderr: '',
        ),
      ]);
      final manager = HostingSiteManager('demo',
          workingDirectory: '/tmp', runner: runner);

      final List<String>? sites = await manager.listSites();

      expect(sites, isNotNull);
      expect(sites, containsAll(<String>['demo', 'demo-beta']));
      expect(runner.calls.single.arguments,
          containsAll(<String>['hosting:sites:list', '--json']));
    });

    test('falls back to parsing `name` when `siteId` is missing', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(
          exitCode: 0,
          stdout: '{"status":"success","result":{"sites":[{"name":"projects/123/sites/x"},{"name":"projects/123/sites/y"}]}}',
          stderr: '',
        ),
      ]);
      final manager = HostingSiteManager('demo',
          workingDirectory: '/tmp', runner: runner);

      final List<String>? sites = await manager.listSites();

      expect(sites, equals(<String>['x', 'y']));
    });

    test('returns null on non-JSON output', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(exitCode: 0, stdout: 'not-json', stderr: ''),
      ]);
      final manager = HostingSiteManager('demo',
          workingDirectory: '/tmp', runner: runner);

      expect(await manager.listSites(), isNull);
    });

    test('returns null when the CLI fails', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(exitCode: 1, stdout: '', stderr: 'auth required'),
      ]);
      final manager = HostingSiteManager('demo',
          workingDirectory: '/tmp', runner: runner);

      expect(await manager.listSites(), isNull);
    });
  });

  group('HostingSiteManager.ensureBetaSite', () {
    test('returns existed when list shows the site', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(
          exitCode: 0,
          stdout: '{"status":"success","result":{"sites":[{"siteId":"demo-beta"}]}}',
          stderr: '',
        ),
      ]);
      final manager = HostingSiteManager('demo',
          workingDirectory: '/tmp', runner: runner);

      final SiteEnsureResult result = await manager.ensureBetaSite();

      expect(result.success, isTrue);
      expect(result.outcome, SiteEnsureOutcome.existed);
      expect(result.siteId, equals('demo-beta'));
      // Only the list call was made; no create attempted.
      expect(runner.calls, hasLength(1));
    });

    test('creates the site when not in the list', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        // 1) list returns no beta site
        ProcessResult(
          exitCode: 0,
          stdout: '{"status":"success","result":{"sites":[{"siteId":"demo"}]}}',
          stderr: '',
        ),
        // 2) create succeeds
        ProcessResult(exitCode: 0, stdout: '✔ Site created', stderr: ''),
      ]);
      final manager = HostingSiteManager('demo',
          workingDirectory: '/tmp', runner: runner);

      final SiteEnsureResult result = await manager.ensureBetaSite();

      expect(result.success, isTrue);
      expect(result.outcome, SiteEnsureOutcome.created);
      expect(result.siteId, equals('demo-beta'));
      expect(runner.calls, hasLength(2));
      expect(runner.calls[1].arguments,
          containsAll(<String>['hosting:sites:create', 'demo-beta']));
    });

    test('treats ALREADY_EXISTS during create as existed', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        // 1) list call fails so we fall through to optimistic create
        ProcessResult(exitCode: 1, stdout: '', stderr: 'list failed'),
        // 2) create returns ALREADY_EXISTS
        ProcessResult(
          exitCode: 1,
          stdout: '',
          stderr:
              'HTTP Error: 409, Site `demo-beta` already exists in this project.',
        ),
      ]);
      final manager = HostingSiteManager('demo',
          workingDirectory: '/tmp', runner: runner);

      final SiteEnsureResult result = await manager.ensureBetaSite();

      expect(result.outcome, SiteEnsureOutcome.existed);
      expect(result.success, isTrue);
    });

    test('returns failed when create fails for any other reason', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(exitCode: 1, stdout: '', stderr: 'list failed'),
        ProcessResult(
          exitCode: 1,
          stdout: '',
          stderr: 'PERMISSION_DENIED: caller missing firebase.sites.create',
        ),
      ]);
      final manager = HostingSiteManager('demo',
          workingDirectory: '/tmp', runner: runner);

      final SiteEnsureResult result = await manager.ensureBetaSite();

      expect(result.outcome, SiteEnsureOutcome.failed);
      expect(result.success, isFalse);
      expect(result.message, contains('PERMISSION_DENIED'));
    });

    test('returns failed when project id is empty', () async {
      final runner = _ScriptedRunner();
      final manager = HostingSiteManager('',
          workingDirectory: '/tmp', runner: runner);

      final SiteEnsureResult result = await manager.ensureBetaSite();

      expect(result.outcome, SiteEnsureOutcome.failed);
      expect(runner.calls, isEmpty);
    });
  });

  group('HostingSiteManager.applyTargets', () {
    test('runs target:apply for both release and beta', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(exitCode: 0, stdout: '', stderr: ''),
        ProcessResult(exitCode: 0, stdout: '', stderr: ''),
      ]);
      final manager = HostingSiteManager('demo',
          workingDirectory: '/tmp/proj', runner: runner);

      final ApplyTargetsResult result = await manager.applyTargets();

      expect(result.success, isTrue);
      expect(runner.calls, hasLength(2));
      expect(
        runner.calls[0].arguments,
        containsAll(<String>['target:apply', 'hosting', 'release', 'demo']),
      );
      expect(
        runner.calls[1].arguments,
        containsAll(<String>['target:apply', 'hosting', 'beta', 'demo-beta']),
      );
      expect(runner.calls[0].workingDirectory, equals('/tmp/proj'));
    });

    test('reports per-target failures', () async {
      final runner = _ScriptedRunner(results: <ProcessResult>[
        ProcessResult(exitCode: 0, stdout: '', stderr: ''),
        ProcessResult(exitCode: 1, stdout: '', stderr: 'site not found'),
      ]);
      final manager = HostingSiteManager('demo',
          workingDirectory: '/tmp/proj', runner: runner);

      final ApplyTargetsResult result = await manager.applyTargets();

      expect(result.success, isFalse);
      expect(result.releaseApplied, isTrue);
      expect(result.betaApplied, isFalse);
      expect(result.message, contains('site not found'));
    });

    test('returns failure when project id is empty', () async {
      final runner = _ScriptedRunner();
      final manager = HostingSiteManager('',
          workingDirectory: '/tmp/proj', runner: runner);

      final ApplyTargetsResult result = await manager.applyTargets();

      expect(result.success, isFalse);
      expect(runner.calls, isEmpty);
    });
  });

  group('HostingSiteManager URLs', () {
    test('webAppUrl uses .web.app domain', () {
      const result = SiteEnsureResult(
        siteId: 'demo-beta',
        outcome: SiteEnsureOutcome.existed,
      );
      expect(result.webAppUrl, equals('https://demo-beta.web.app'));
      expect(result.firebaseAppUrl,
          equals('https://demo-beta.firebaseapp.com'));
    });

    test('webAppUrl is null on failure', () {
      const result = SiteEnsureResult(
        siteId: 'demo-beta',
        outcome: SiteEnsureOutcome.failed,
        message: 'boom',
      );
      expect(result.webAppUrl, isNull);
      expect(result.firebaseAppUrl, isNull);
    });
  });

  group('HostingSiteManager auth env propagation', () {
    test(
      'listSites passes the configured environment to firebase',
      () async {
        final runner = _ScriptedRunner(results: <ProcessResult>[
          ProcessResult(
            exitCode: 0,
            stdout: '{"status":"success","result":{"sites":[]}}',
            stderr: '',
          ),
        ]);
        final manager = HostingSiteManager(
          'demo',
          workingDirectory: '/tmp/proj',
          environment: const <String, String>{
            'GOOGLE_APPLICATION_CREDENTIALS': '/abs/sa.json',
          },
          runner: runner,
        );

        await manager.listSites();

        expect(runner.calls.single.environment, isNotNull);
        expect(
          runner.calls.single.environment!['GOOGLE_APPLICATION_CREDENTIALS'],
          equals('/abs/sa.json'),
        );
        expect(runner.calls.single.workingDirectory, equals('/tmp/proj'));
      },
    );

    test(
      'ensureBetaSite passes env to both list and create calls',
      () async {
        final runner = _ScriptedRunner(results: <ProcessResult>[
          ProcessResult(
            exitCode: 0,
            stdout: '{"status":"success","result":{"sites":[]}}',
            stderr: '',
          ),
          ProcessResult(exitCode: 0, stdout: 'created', stderr: ''),
        ]);
        final manager = HostingSiteManager(
          'demo',
          workingDirectory: '/tmp/proj',
          environment: const <String, String>{
            'GOOGLE_APPLICATION_CREDENTIALS': '/abs/sa.json',
          },
          runner: runner,
        );

        await manager.ensureBetaSite();

        expect(runner.calls, hasLength(2));
        for (final call in runner.calls) {
          expect(call.environment, isNotNull,
              reason: 'every firebase invocation must pass env');
          expect(
            call.environment!['GOOGLE_APPLICATION_CREDENTIALS'],
            equals('/abs/sa.json'),
          );
        }
      },
    );

    test(
      'applyTargets passes env to both target:apply calls',
      () async {
        final runner = _ScriptedRunner(results: <ProcessResult>[
          ProcessResult(exitCode: 0, stdout: '', stderr: ''),
          ProcessResult(exitCode: 0, stdout: '', stderr: ''),
        ]);
        final manager = HostingSiteManager(
          'demo',
          workingDirectory: '/tmp/proj',
          environment: const <String, String>{
            'GOOGLE_APPLICATION_CREDENTIALS': '/abs/sa.json',
          },
          runner: runner,
        );

        await manager.applyTargets();

        expect(runner.calls, hasLength(2));
        for (final call in runner.calls) {
          expect(call.environment, isNotNull);
          expect(
            call.environment!['GOOGLE_APPLICATION_CREDENTIALS'],
            equals('/abs/sa.json'),
          );
        }
      },
    );

    test(
      'no environment param means firebase calls inherit parent env',
      () async {
        final runner = _ScriptedRunner(results: <ProcessResult>[
          ProcessResult(
            exitCode: 0,
            stdout: '{"status":"success","result":{"sites":[]}}',
            stderr: '',
          ),
        ]);
        final manager = HostingSiteManager(
          'demo',
          workingDirectory: '/tmp/proj',
          runner: runner,
          // environment intentionally omitted
        );

        await manager.listSites();

        expect(runner.calls.single.environment, isNull);
      },
    );
  });

  group('HostingSiteManager auth self-heal', () {
    test(
      'auto-recovers from "Failed to authenticate" by force-logout + retry',
      () async {
        final runner = _ScriptedRunner(results: <ProcessResult>[
          // 1) list shows no beta site → fall through to create
          ProcessResult(
            exitCode: 0,
            stdout: '{"status":"success","result":{"sites":[]}}',
            stderr: '',
          ),
          // 2) first create fails with auth error
          ProcessResult(
            exitCode: 1,
            stdout: '',
            stderr:
                'Error: Failed to authenticate, have you run firebase login?',
          ),
          // 3) firebase logout --force succeeds
          ProcessResult(exitCode: 0, stdout: 'logged out', stderr: ''),
          // 4) retry create succeeds
          ProcessResult(exitCode: 0, stdout: '✔ Site created', stderr: ''),
        ]);
        final manager = HostingSiteManager(
          'demo',
          workingDirectory: '/tmp/proj',
          environment: const <String, String>{
            'GOOGLE_APPLICATION_CREDENTIALS': '/abs/sa.json',
          },
          runner: runner,
        );

        final SiteEnsureResult result = await manager.ensureBetaSite();

        expect(result.success, isTrue);
        expect(result.outcome, SiteEnsureOutcome.created);
        expect(runner.calls, hasLength(4));

        // Calls 0 and 1 are list + first create.
        expect(runner.calls[0].arguments,
            containsAll(<String>['hosting:sites:list']));
        expect(runner.calls[1].arguments,
            containsAll(<String>['hosting:sites:create', 'demo-beta']));

        // Call 2 must be `firebase logout --force`.
        expect(
          runner.calls[2].arguments,
          containsAll(<String>['logout', '--force']),
        );
        // Logout must NOT pass env — we want firebase-tools to see the
        // shell env so it can find/clear its own configstore.
        expect(runner.calls[2].environment, isNull);

        // Call 3 must be the retried create — and must again pass env.
        expect(runner.calls[3].arguments,
            containsAll(<String>['hosting:sites:create', 'demo-beta']));
        expect(runner.calls[3].environment, isNotNull);
        expect(
          runner.calls[3].environment!['GOOGLE_APPLICATION_CREDENTIALS'],
          equals('/abs/sa.json'),
        );
      },
    );

    test(
      'self-heal does NOT fire when no environment is configured',
      () async {
        // Without an environment, we don't know that the user wants SA-
        // based auth at all — wiping the firebase login could lock them
        // out. So the self-heal must skip and return the original failure.
        final runner = _ScriptedRunner(results: <ProcessResult>[
          ProcessResult(
            exitCode: 0,
            stdout: '{"status":"success","result":{"sites":[]}}',
            stderr: '',
          ),
          ProcessResult(
            exitCode: 1,
            stdout: '',
            stderr:
                'Error: Failed to authenticate, have you run firebase login?',
          ),
        ]);
        final manager = HostingSiteManager(
          'demo',
          workingDirectory: '/tmp/proj',
          runner: runner,
          // environment intentionally omitted
        );

        final SiteEnsureResult result = await manager.ensureBetaSite();

        expect(result.success, isFalse);
        expect(result.outcome, SiteEnsureOutcome.failed);
        // Only list + create — no logout, no retry.
        expect(runner.calls, hasLength(2));
      },
    );

    test(
      'self-heal still surfaces failure when retry also fails',
      () async {
        final runner = _ScriptedRunner(results: <ProcessResult>[
          ProcessResult(
            exitCode: 0,
            stdout: '{"status":"success","result":{"sites":[]}}',
            stderr: '',
          ),
          ProcessResult(
            exitCode: 1,
            stdout: '',
            stderr: 'Failed to authenticate',
          ),
          ProcessResult(exitCode: 0, stdout: '', stderr: ''),
          ProcessResult(
            exitCode: 1,
            stdout: '',
            stderr: 'PERMISSION_DENIED: caller missing firebase.sites.create',
          ),
        ]);
        final manager = HostingSiteManager(
          'demo',
          workingDirectory: '/tmp/proj',
          environment: const <String, String>{
            'GOOGLE_APPLICATION_CREDENTIALS': '/abs/sa.json',
          },
          runner: runner,
        );

        final SiteEnsureResult result = await manager.ensureBetaSite();

        expect(result.success, isFalse);
        expect(result.message, contains('PERMISSION_DENIED'));
        expect(runner.calls, hasLength(4));
      },
    );

    test(
      'self-heal recognises the "have you run firebase login" phrasing',
      () async {
        final runner = _ScriptedRunner(results: <ProcessResult>[
          ProcessResult(
            exitCode: 0,
            stdout: '{"status":"success","result":{"sites":[]}}',
            stderr: '',
          ),
          // Different wording firebase-tools sometimes uses.
          ProcessResult(
            exitCode: 1,
            stdout: '',
            stderr: 'Error: Command requires authentication.',
          ),
          ProcessResult(exitCode: 0, stdout: '', stderr: ''),
          ProcessResult(exitCode: 0, stdout: 'created', stderr: ''),
        ]);
        final manager = HostingSiteManager(
          'demo',
          workingDirectory: '/tmp/proj',
          environment: const <String, String>{
            'GOOGLE_APPLICATION_CREDENTIALS': '/abs/sa.json',
          },
          runner: runner,
        );

        final SiteEnsureResult result = await manager.ensureBetaSite();

        expect(result.success, isTrue);
        expect(runner.calls, hasLength(4));
        expect(runner.calls[2].arguments,
            containsAll(<String>['logout', '--force']));
      },
    );
  });
}
