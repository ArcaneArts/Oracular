import 'package:oracular/models/setup_config.dart';
import 'package:oracular/models/template_info.dart';
import 'package:oracular/services/artifact_cleanup_service.dart';
import 'package:oracular/services/firebase_billing_service.dart';
import 'package:oracular/services/firebase_initializer.dart';
import 'package:oracular/services/firebase_service.dart';
import 'package:oracular/services/firebase_setup_orchestrator.dart';
import 'package:oracular/services/hosting_site_manager.dart';
import 'package:test/test.dart';

/// FakeFirebaseService captures calls and returns scripted booleans.
class _FakeFirebaseService implements FirebaseService {
  _FakeFirebaseService(this.config);

  @override
  final SetupConfig config;

  bool loginResult = true;
  bool gcloudLoginResult = true;
  bool configureResult = true;
  bool deployFirestoreResult = true;
  bool deployStorageResult = true;
  bool buildWebResult = true;
  bool deployHostingReleaseResult = true;
  bool deployHostingBetaResult = true;
  bool enableGoogleApisResult = true;
  List<String> enableFirebaseCoreApisResult = const <String>[];
  bool? supportsWebHostingResult;

  final List<String> calls = <String>[];

  @override
  Future<bool> login() async {
    calls.add('login');
    return loginResult;
  }

  @override
  Future<bool> gcloudLogin() async {
    calls.add('gcloudLogin');
    return gcloudLoginResult;
  }

  @override
  Future<bool> configureFlutterFire() async {
    calls.add('configureFlutterFire');
    return configureResult;
  }

  @override
  Future<bool> deployFirestore() async {
    calls.add('deployFirestore');
    return deployFirestoreResult;
  }

  @override
  Future<bool> deployStorage({bool allowNotInitialized = false}) async {
    calls.add('deployStorage(allowNotInitialized=$allowNotInitialized)');
    return deployStorageResult;
  }

  @override
  Future<bool> buildWeb() async {
    calls.add('buildWeb');
    return buildWebResult;
  }

  @override
  Future<bool> deployHostingRelease() async {
    calls.add('deployHostingRelease');
    return deployHostingReleaseResult;
  }

  @override
  Future<bool> deployHostingBeta() async {
    calls.add('deployHostingBeta');
    return deployHostingBetaResult;
  }

  @override
  Future<bool> enableGoogleApis() async {
    calls.add('enableGoogleApis');
    return enableGoogleApisResult;
  }

  @override
  Future<List<String>> enableFirebaseCoreApis() async {
    calls.add('enableFirebaseCoreApis');
    return enableFirebaseCoreApisResult;
  }

  @override
  Future<bool> deployAll() async => true;

  @override
  bool supportsWebHosting() {
    if (supportsWebHostingResult != null) return supportsWebHostingResult!;
    return config.template.isJasprApp ||
        (config.template.isFlutterApp && config.platforms.contains('web'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

/// FakeBillingService that returns a canned status without invoking gcloud.
class _FakeBilling implements FirebaseBillingService {
  _FakeBilling(this.projectId, {this.status = BlazeStatus.enabled});

  @override
  final String projectId;

  BlazeStatus status;

  @override
  Future<BillingCheckResult> checkBlazeStatus({String? projectId}) async {
    return BillingCheckResult(status: status);
  }

  @override
  Future<BillingCheckResult> guideUpgrade({
    String? projectId,
    int maxLoops = 3,
    bool interactive = true,
  }) async {
    return BillingCheckResult(status: status);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

/// FakeInitializer returns canned init results.
class _FakeInitializer implements FirebaseInitializer {
  _FakeInitializer(this.projectId);

  @override
  final String projectId;

  FirestoreInitResult firestoreResult = FirestoreInitResult(
    existed: true,
    created: false,
    region: 'nam5',
  );

  StorageInitResult storageResult = StorageInitResult(
    existed: true,
    created: false,
    bucketName: 'demo.appspot.com',
  );

  AuthProvidersResult authResult = const AuthProvidersResult(
    requested: <AuthProvider>{
      AuthProvider.emailPassword,
      AuthProvider.google
    },
    automated: <AuthProvider>{},
    handedOff: <AuthProvider>{
      AuthProvider.emailPassword,
      AuthProvider.google
    },
  );

  @override
  Future<FirestoreInitResult> ensureFirestoreDatabase({
    String region = 'nam5',
  }) async {
    return firestoreResult;
  }

  @override
  Future<StorageInitResult> ensureStorageBucket({
    String location = 'US',
  }) async {
    return storageResult;
  }

  @override
  Future<AuthProvidersResult> enableAuthProviders({
    required Set<AuthProvider> providers,
    bool interactive = true,
  }) async {
    return authResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

/// FakeHosting returns canned hosting results.
class _FakeHosting implements HostingSiteManager {
  _FakeHosting(this.projectId, {required this.workingDirectory});

  @override
  final String projectId;

  @override
  final String workingDirectory;

  @override
  String get betaSiteId => '$projectId-beta';

  SiteEnsureResult releaseResult = SiteEnsureResult(
    siteId: 'demo',
    outcome: SiteEnsureOutcome.existed,
  );

  SiteEnsureResult betaResult = SiteEnsureResult(
    siteId: 'demo-beta',
    outcome: SiteEnsureOutcome.created,
  );

  ApplyTargetsResult applyResult = const ApplyTargetsResult(
    releaseApplied: true,
    betaApplied: true,
  );

  @override
  Future<SiteEnsureResult> ensureReleaseSite() async => releaseResult;

  @override
  Future<SiteEnsureResult> ensureBetaSite() async => betaResult;

  @override
  Future<ApplyTargetsResult> applyTargets({
    String releaseTarget = 'release',
    String betaTarget = 'beta',
  }) async {
    return applyResult;
  }

  @override
  Future<List<String>?> listSites() async => <String>[];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

/// FakeCleanup returns canned cleanup results.
class _FakeCleanup implements ArtifactCleanupService {
  _FakeCleanup(this.projectId);

  @override
  final String projectId;

  @override
  String get defaultRegion => 'us-central1';

  RepositoryEnsureResult repoResult = RepositoryEnsureResult(
    repository: 'oracular',
    region: 'us-central1',
    outcome: RepositoryEnsureOutcome.existed,
  );

  CleanupPolicyResult policyResult = const CleanupPolicyResult(
    applied: true,
    policyCount: 2,
  );

  RevisionPruneResult pruneResult = const RevisionPruneResult(
    deleted: 0,
    skipped: 0,
    deletedRevisions: <String>[],
    skippedRevisions: <String>[],
    failedRevisions: <String>[],
  );

  @override
  Future<RepositoryEnsureResult> ensureRepository({
    required String repository,
    String? region,
    String repositoryFormat = 'docker',
  }) async {
    return repoResult;
  }

  @override
  Future<CleanupPolicyResult> applyCleanupPolicies({
    required String repository,
    String? region,
    int keepRecent = 5,
    int deleteOlderDays = 30,
  }) async {
    return policyResult;
  }

  @override
  Future<RevisionPruneResult> capCloudRunRevisions({
    required String service,
    String? region,
    int keepRevisions = 3,
  }) async {
    return pruneResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

/// Build a minimal Flutter web SetupConfig for orchestrator tests.
SetupConfig _flutterWebConfig({
  bool createServer = false,
  bool setupCloudRun = false,
}) {
  return SetupConfig(
    appName: 'demo',
    orgDomain: 'com.example',
    baseClassName: 'Demo',
    template: TemplateType.arcaneTemplate,
    outputDir: '/tmp/demo',
    useFirebase: true,
    firebaseProjectId: 'demo',
    createServer: createServer,
    setupCloudRun: setupCloudRun,
    platforms: const <String>['web'],
  );
}

SetupConfig _jasprStaticConfig() {
  return SetupConfig(
    appName: 'demo',
    orgDomain: 'com.example',
    baseClassName: 'Demo',
    template: TemplateType.arcaneJasprDocs,
    outputDir: '/tmp/demo',
    useFirebase: true,
    firebaseProjectId: 'demo',
  );
}

SetupConfig _dartCliConfig() {
  return SetupConfig(
    appName: 'demo',
    orgDomain: 'com.example',
    baseClassName: 'Demo',
    template: TemplateType.arcaneCli,
    outputDir: '/tmp/demo',
    useFirebase: true,
    firebaseProjectId: 'demo',
  );
}

FirebaseSetupOrchestrator _buildOrchestrator(
  SetupConfig config, {
  _FakeFirebaseService? firebase,
  _FakeBilling? billing,
  _FakeInitializer? initializer,
  _FakeHosting? hosting,
  _FakeCleanup? cleanup,
}) {
  return FirebaseSetupOrchestrator(
    config,
    firebase: firebase ?? _FakeFirebaseService(config),
    billing: billing ?? _FakeBilling(config.firebaseProjectId ?? ''),
    initializer:
        initializer ?? _FakeInitializer(config.firebaseProjectId ?? ''),
    hosting: hosting ??
        _FakeHosting(
          config.firebaseProjectId ?? '',
          workingDirectory: config.outputDir,
        ),
    cleanup: cleanup ?? _FakeCleanup(config.firebaseProjectId ?? ''),
  );
}

void main() {
  group('FirebaseSetupOrchestrator.runAll · Flutter web', () {
    test('runs every web step on Spark+no-server config and prints URLs',
        () async {
      final fb = _FakeFirebaseService(_flutterWebConfig());
      final orchestrator = _buildOrchestrator(
        _flutterWebConfig(),
        firebase: fb,
        billing: _FakeBilling('demo', status: BlazeStatus.notEnabled),
      );

      final OrchestratorReport report = await orchestrator.runAll(
        interactive: false,
      );

      // Hosting URLs are populated.
      expect(report.releaseUrl, equals('https://demo.web.app'));
      expect(report.betaUrl, equals('https://demo-beta.web.app'));

      // Firebase service was driven through the Flutter-web flow.
      expect(fb.calls, contains('login'));
      expect(fb.calls, contains('configureFlutterFire'));
      expect(fb.calls, contains('deployFirestore'));
      expect(fb.calls, contains('deployStorage(allowNotInitialized=true)'));
      expect(fb.calls, contains('buildWeb'));
      expect(fb.calls, contains('deployHostingRelease'));
      expect(fb.calls, contains('deployHostingBeta'));

      // gcloud login is *not* invoked when no server / no Cloud Run.
      expect(fb.calls, isNot(contains('gcloudLogin')));
      expect(fb.calls, isNot(contains('enableGoogleApis')));
    });

    test('skips beta deploy when deployHostingBeta is false', () async {
      final fb = _FakeFirebaseService(
        _flutterWebConfig().copyWith(deployHostingBeta: false),
      );
      final orchestrator = _buildOrchestrator(
        _flutterWebConfig().copyWith(deployHostingBeta: false),
        firebase: fb,
        billing: _FakeBilling('demo', status: BlazeStatus.notEnabled),
      );

      final OrchestratorReport report = await orchestrator.runAll(
        interactive: false,
      );

      expect(report.releaseUrl, equals('https://demo.web.app'));
      expect(report.betaUrl, isNull);
      expect(fb.calls, isNot(contains('deployHostingBeta')));
    });

    test('skips dependent hosting deploys when buildWeb fails', () async {
      final fb = _FakeFirebaseService(_flutterWebConfig());
      fb.buildWebResult = false;
      final orchestrator = _buildOrchestrator(
        _flutterWebConfig(),
        firebase: fb,
        billing: _FakeBilling('demo', status: BlazeStatus.notEnabled),
      );

      final OrchestratorReport report = await orchestrator.runAll(
        interactive: false,
      );

      // No deploy attempt was made.
      expect(fb.calls, isNot(contains('deployHostingRelease')));
      expect(fb.calls, isNot(contains('deployHostingBeta')));
      expect(report.releaseUrl, isNull);
      expect(report.betaUrl, isNull);

      // The orchestrator records the build failure + two skipped hosting
      // steps.
      final List<WizardSubStep> steps = report.results
          .map((SetupStepResult r) => r.step)
          .toList();
      expect(steps, contains(WizardSubStep.buildWeb));
      expect(steps, contains(WizardSubStep.deployHostingRelease));
      expect(steps, contains(WizardSubStep.deployHostingBeta));

      final SetupStepResult buildResult =
          report.results.firstWhere((r) => r.step == WizardSubStep.buildWeb);
      expect(buildResult.failed, isTrue);

      final SetupStepResult releaseResult = report.results
          .firstWhere((r) => r.step == WizardSubStep.deployHostingRelease);
      expect(releaseResult.skipped, isTrue);
    });

    test('respects confirm callback for individual steps', () async {
      final fb = _FakeFirebaseService(_flutterWebConfig());
      final orchestrator = _buildOrchestrator(
        _flutterWebConfig(),
        firebase: fb,
        billing: _FakeBilling('demo', status: BlazeStatus.notEnabled),
      );

      final List<WizardSubStep> events = <WizardSubStep>[];

      final OrchestratorReport report = await orchestrator.runAll(
        interactive: false,
        confirm: (WizardSubStep step) async {
          events.add(step);
          // Decline the auth providers + storage init steps to test skip
          // behaviour.
          if (step == WizardSubStep.enableAuthProviders ||
              step == WizardSubStep.initStorage) {
            return false;
          }
          return true;
        },
      );

      expect(events, isNotEmpty);
      final SetupStepResult auth = report.results.firstWhere(
        (SetupStepResult r) => r.step == WizardSubStep.enableAuthProviders,
      );
      expect(auth.skipped, isTrue);
      expect(auth.message, contains('User declined'));
      // Hosting still ran because confirm only declined those two steps.
      expect(fb.calls, contains('deployHostingRelease'));
    });
  });

  group('FirebaseSetupOrchestrator.runAll · Jaspr static', () {
    test('runs hosting flow and routes through Firebase JS SDK config',
        () async {
      final fb = _FakeFirebaseService(_jasprStaticConfig());
      final orchestrator = _buildOrchestrator(
        _jasprStaticConfig(),
        firebase: fb,
        billing: _FakeBilling('demo', status: BlazeStatus.notEnabled),
      );

      final OrchestratorReport report = await orchestrator.runAll(
        interactive: false,
      );

      expect(report.releaseUrl, equals('https://demo.web.app'));
      expect(report.betaUrl, equals('https://demo-beta.web.app'));

      // The orchestrator dispatches both Flutter and Jaspr through the same
      // public method (`configureFlutterFire`), which internally branches.
      expect(fb.calls, contains('configureFlutterFire'));
      expect(fb.calls, contains('buildWeb'));
      expect(fb.calls, contains('deployHostingRelease'));
      expect(fb.calls, contains('deployHostingBeta'));
    });
  });

  group('FirebaseSetupOrchestrator.runAll · Dart CLI', () {
    test('skips the web build & hosting steps for non-web templates',
        () async {
      final fb = _FakeFirebaseService(_dartCliConfig());
      final orchestrator = _buildOrchestrator(
        _dartCliConfig(),
        firebase: fb,
        billing: _FakeBilling('demo', status: BlazeStatus.notEnabled),
      );

      final OrchestratorReport report = await orchestrator.runAll(
        interactive: false,
      );

      expect(report.releaseUrl, isNull);
      expect(report.betaUrl, isNull);
      expect(fb.calls, isNot(contains('buildWeb')));
      expect(fb.calls, isNot(contains('deployHostingRelease')));
      expect(fb.calls, isNot(contains('deployHostingBeta')));

      // But Firestore + Storage rules still deploy for Dart CLI.
      expect(fb.calls, contains('deployFirestore'));
      expect(fb.calls, contains('deployStorage(allowNotInitialized=true)'));
    });
  });

  group('FirebaseSetupOrchestrator.runAll · Server + Cloud Run', () {
    test('runs all server steps when Blaze is enabled', () async {
      final fb = _FakeFirebaseService(
        _flutterWebConfig(createServer: true, setupCloudRun: true),
      );
      final cleanup = _FakeCleanup('demo');
      final orchestrator = _buildOrchestrator(
        _flutterWebConfig(createServer: true, setupCloudRun: true),
        firebase: fb,
        billing: _FakeBilling('demo', status: BlazeStatus.enabled),
        cleanup: cleanup,
      );

      final OrchestratorReport report = await orchestrator.runAll(
        interactive: false,
      );

      expect(report.blazeStatus, equals(BlazeStatus.enabled));
      expect(fb.calls, contains('gcloudLogin'));
      expect(fb.calls, contains('enableGoogleApis'));

      final List<WizardSubStep> steps = report.results
          .map((SetupStepResult r) => r.step)
          .toList();
      expect(steps, contains(WizardSubStep.ensureArtifactRegistryRepo));
      expect(steps, contains(WizardSubStep.applyArtifactCleanupPolicy));
      expect(steps, contains(WizardSubStep.capCloudRunRevisions));
    });

    test('records explicit skips for server steps when on Spark', () async {
      final orchestrator = _buildOrchestrator(
        _flutterWebConfig(createServer: true, setupCloudRun: true),
        billing: _FakeBilling('demo', status: BlazeStatus.notEnabled),
      );

      final OrchestratorReport report = await orchestrator.runAll(
        interactive: false,
      );

      expect(report.blazeStatus, equals(BlazeStatus.notEnabled));

      final SetupStepResult enableApis = report.results.firstWhere(
        (r) => r.step == WizardSubStep.enableServerApis,
      );
      expect(enableApis.skipped, isTrue);
      expect(enableApis.message, contains('Spark'));

      final SetupStepResult cap = report.results.firstWhere(
        (r) => r.step == WizardSubStep.capCloudRunRevisions,
      );
      expect(cap.skipped, isTrue);
    });
  });

  group('FirebaseSetupOrchestrator.runAll · partial failures', () {
    test('continues running subsequent steps after a single failure',
        () async {
      final fb = _FakeFirebaseService(_flutterWebConfig());
      // Firestore rules deploy fails.
      fb.deployFirestoreResult = false;

      final orchestrator = _buildOrchestrator(
        _flutterWebConfig(),
        firebase: fb,
        billing: _FakeBilling('demo', status: BlazeStatus.notEnabled),
      );

      final OrchestratorReport report = await orchestrator.runAll(
        interactive: false,
        // Opt into the legacy "always continue" semantics so the rest
        // of this test can verify subsequent steps still run after a
        // failed step. The default fail-fast behavior would abort here.
        onFailure: (_, {required attempt}) async => FailureAction.skip,
      );

      // The Firestore rules step is recorded as skipped-after-failure
      // (when onFailure returns skip, the orchestrator demotes failed →
      // skipped so the rest of the run can continue).
      final SetupStepResult fs = report.results.firstWhere(
        (r) => r.step == WizardSubStep.deployFirestoreRules,
      );
      expect(fs.skipped, isTrue);
      expect(fs.message, contains('Skipped after failure'));

      // But hosting deploys still ran.
      expect(fb.calls, contains('deployHostingRelease'));
      expect(fb.calls, contains('deployHostingBeta'));

      expect(report.success, isTrue,
          reason:
              'overall report.success should be true because every step that '
              'ran is either success or skipped — there are no failed steps.');
      expect(report.skippedCount, greaterThanOrEqualTo(1));
    });

    test('returns failed step with fix hint when login fails', () async {
      final fb = _FakeFirebaseService(_flutterWebConfig());
      fb.loginResult = false;

      final orchestrator = _buildOrchestrator(
        _flutterWebConfig(),
        firebase: fb,
        billing: _FakeBilling('demo', status: BlazeStatus.notEnabled),
      );

      final OrchestratorReport report = await orchestrator.runAll(
        interactive: false,
      );

      final SetupStepResult fbLogin = report.results.firstWhere(
        (r) => r.step == WizardSubStep.firebaseLogin,
      );
      expect(fbLogin.failed, isTrue);
      expect(fbLogin.fixHint, contains('firebase login'));
    });

    test('default fail-fast aborts the run on first failure', () async {
      final fb = _FakeFirebaseService(_flutterWebConfig());
      fb.deployFirestoreResult = false;

      final orchestrator = _buildOrchestrator(
        _flutterWebConfig(),
        firebase: fb,
        billing: _FakeBilling('demo', status: BlazeStatus.notEnabled),
      );

      // No onFailure handler → default abort policy.
      final OrchestratorReport report = await orchestrator.runAll(
        interactive: false,
      );

      expect(report.aborted, isTrue);
      // Subsequent hosting steps should NOT have been called.
      expect(fb.calls, isNot(contains('deployHostingRelease')));
      expect(fb.calls, isNot(contains('deployHostingBeta')));
    });

    test('onFailure handler can request retry which re-runs the step',
        () async {
      final fb = _FakeFirebaseService(_flutterWebConfig());
      // Fail twice, succeed on the 3rd attempt.
      int attemptsBeforeSuccess = 2;
      fb.deployFirestoreResult = false;

      int retryCount = 0;
      final orchestrator = _buildOrchestrator(
        _flutterWebConfig(),
        firebase: fb,
        billing: _FakeBilling('demo', status: BlazeStatus.notEnabled),
      );

      final OrchestratorReport report = await orchestrator.runAll(
        interactive: false,
        onFailure: (_, {required attempt}) async {
          retryCount++;
          if (attemptsBeforeSuccess > 0) {
            attemptsBeforeSuccess--;
            // Flip the flag to success on the final retry.
            if (attemptsBeforeSuccess == 0) {
              fb.deployFirestoreResult = true;
            }
            return FailureAction.retry;
          }
          return FailureAction.skip;
        },
      );

      expect(retryCount, greaterThanOrEqualTo(2));
      // The Firestore rules step ultimately succeeded after retries.
      final SetupStepResult fs = report.results.firstWhere(
        (r) => r.step == WizardSubStep.deployFirestoreRules,
      );
      expect(fs.success, isTrue);
    });
  });

  group('FirebaseSetupOrchestrator.runAll · empty project id', () {
    test('returns a single failed step when project id is missing',
        () async {
      final SetupConfig config = SetupConfig(
        appName: 'demo',
        orgDomain: 'com.example',
        baseClassName: 'Demo',
        template: TemplateType.arcaneTemplate,
        outputDir: '/tmp/demo',
        useFirebase: true,
        // firebaseProjectId not set
      );
      final orchestrator = FirebaseSetupOrchestrator(
        config,
        firebase: _FakeFirebaseService(config),
        billing: _FakeBilling(''),
        initializer: _FakeInitializer(''),
        hosting: _FakeHosting('', workingDirectory: '/tmp/demo'),
        cleanup: _FakeCleanup(''),
      );

      final OrchestratorReport report = await orchestrator.runAll(
        interactive: false,
      );

      expect(report.results, hasLength(1));
      expect(report.results.single.failed, isTrue);
      expect(report.results.single.message, contains('project ID'));
    });
  });

  group('FirebaseSetupOrchestrator.fixHintFor', () {
    test('every WizardSubStep value has a non-empty fix hint', () {
      for (final WizardSubStep step in WizardSubStep.values) {
        final String hint = FirebaseSetupOrchestrator.fixHintFor(step);
        expect(hint, isNotEmpty,
            reason: 'fixHintFor should be non-empty for ${step.name}');
      }
    });

    test('points at the matching CLI command for each step', () {
      expect(
        FirebaseSetupOrchestrator.fixHintFor(WizardSubStep.initFirestore),
        equals('oracular deploy firestore-init'),
      );
      expect(
        FirebaseSetupOrchestrator.fixHintFor(WizardSubStep.initStorage),
        equals('oracular deploy storage-init'),
      );
      expect(
        FirebaseSetupOrchestrator.fixHintFor(WizardSubStep.deployHostingBeta),
        equals('oracular deploy hosting-beta'),
      );
      expect(
        FirebaseSetupOrchestrator.fixHintFor(
            WizardSubStep.applyArtifactCleanupPolicy),
        equals('oracular deploy artifact-cleanup'),
      );
      expect(
        FirebaseSetupOrchestrator.fixHintFor(
            WizardSubStep.capCloudRunRevisions),
        equals('oracular deploy cloudrun-prune'),
      );
    });
  });

  group('OrchestratorReport', () {
    test('aggregates success/skipped/failed counts correctly', () {
      const OrchestratorReport report = OrchestratorReport(
        results: <SetupStepResult>[
          SetupStepResult(
            step: WizardSubStep.firebaseLogin,
            status: SetupStepStatus.success,
          ),
          SetupStepResult(
            step: WizardSubStep.gcloudLogin,
            status: SetupStepStatus.skipped,
          ),
          SetupStepResult(
            step: WizardSubStep.deployFirestoreRules,
            status: SetupStepStatus.failed,
          ),
        ],
      );

      expect(report.successCount, equals(1));
      expect(report.skippedCount, equals(1));
      expect(report.failedCount, equals(1));
      expect(report.success, isFalse);
      expect(report.failures, hasLength(1));
      expect(report.pending, hasLength(2));
    });

    test('success=true when nothing failed (skips allowed)', () {
      const OrchestratorReport report = OrchestratorReport(
        results: <SetupStepResult>[
          SetupStepResult(
            step: WizardSubStep.firebaseLogin,
            status: SetupStepStatus.success,
          ),
          SetupStepResult(
            step: WizardSubStep.gcloudLogin,
            status: SetupStepStatus.skipped,
          ),
        ],
      );

      expect(report.success, isTrue);
    });
  });
}
