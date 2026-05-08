import 'package:fast_log/fast_log.dart';

import '../models/setup_config.dart';
import '../models/template_info.dart';
import '../utils/link_opener.dart';
import '../utils/process_runner.dart' show ProcessRunner;
import '../utils/setup_guidance.dart';
import '../utils/user_prompt.dart';
import 'artifact_cleanup_service.dart';
import 'firebase_billing_service.dart';
import 'firebase_initializer.dart';
import 'firebase_service.dart';
import 'hosting_site_manager.dart';

/// Identifier for a single sub-step in the Firebase setup flow. The wizard
/// translates these into "Step 5.x · …" indicators; CLI callers use them
/// for structured logging.
enum WizardSubStep {
  // Authentication
  firebaseLogin,
  gcloudLogin,
  billingCheck,

  // Pre-flight: enable required Google APIs (firebase, firestore,
  // firebasestorage, firebasehosting, identitytoolkit). Done BEFORE
  // any apps:list / firestore describe / storage describe call so
  // those don't fail with SERVICE_DISABLED.
  enableFirebaseApis,

  // Client wiring
  configureClient,

  // Bootstrapping
  initFirestore,
  initStorage,
  enableAuthProviders,

  // Rules + content
  deployFirestoreRules,
  deployStorageRules,
  buildWeb,

  // Hosting
  hostingInit,
  deployHostingRelease,
  deployHostingBeta,

  // Server / Cloud Run (Step 6)
  enableServerApis,
  ensureArtifactRegistryRepo,
  applyArtifactCleanupPolicy,
  capCloudRunRevisions,
}

extension WizardSubStepLabel on WizardSubStep {
  /// Human-readable label printed by the wizard / CLI ("5.1 Authenticate
  /// with Firebase", etc.). Step numbers are prefixed by the caller.
  String get label {
    switch (this) {
      case WizardSubStep.firebaseLogin:
        return 'Authenticate with Firebase';
      case WizardSubStep.gcloudLogin:
        return 'Authenticate with Google Cloud';
      case WizardSubStep.billingCheck:
        return 'Verify billing plan (Spark / Blaze)';
      case WizardSubStep.enableFirebaseApis:
        return 'Enable required Firebase APIs';
      case WizardSubStep.configureClient:
        return 'Configure Firebase client wiring';
      case WizardSubStep.initFirestore:
        return 'Initialize Firestore default database';
      case WizardSubStep.initStorage:
        return 'Initialize Storage default bucket';
      case WizardSubStep.enableAuthProviders:
        return 'Enable Authentication providers';
      case WizardSubStep.deployFirestoreRules:
        return 'Deploy Firestore rules';
      case WizardSubStep.deployStorageRules:
        return 'Deploy Storage rules';
      case WizardSubStep.buildWeb:
        return 'Build web app';
      case WizardSubStep.hostingInit:
        return 'Create & target beta hosting site';
      case WizardSubStep.deployHostingRelease:
        return 'Deploy hosting (release)';
      case WizardSubStep.deployHostingBeta:
        return 'Deploy hosting (beta)';
      case WizardSubStep.enableServerApis:
        return 'Enable Cloud Run / Artifact Registry APIs';
      case WizardSubStep.ensureArtifactRegistryRepo:
        return 'Create Artifact Registry repository';
      case WizardSubStep.applyArtifactCleanupPolicy:
        return 'Apply Artifact Registry cleanup policy';
      case WizardSubStep.capCloudRunRevisions:
        return 'Cap Cloud Run revisions';
    }
  }
}

/// Status of an individual sub-step.
enum SetupStepStatus { success, skipped, failed }

/// Outcome of a single orchestrator sub-step.
class SetupStepResult {
  final WizardSubStep step;
  final SetupStepStatus status;

  /// Diagnostic message — empty on plain success.
  final String message;

  /// CLI command (or short hint) that the user can run to fix a [failed]
  /// or [skipped] step independently. Empty when no specific fix exists.
  final String fixHint;

  const SetupStepResult({
    required this.step,
    required this.status,
    this.message = '',
    this.fixHint = '',
  });

  factory SetupStepResult.success(WizardSubStep step, {String message = ''}) {
    return SetupStepResult(
      step: step,
      status: SetupStepStatus.success,
      message: message,
    );
  }

  factory SetupStepResult.skipped(WizardSubStep step,
      {String message = '', String fixHint = ''}) {
    return SetupStepResult(
      step: step,
      status: SetupStepStatus.skipped,
      message: message,
      fixHint: fixHint,
    );
  }

  factory SetupStepResult.failed(WizardSubStep step,
      {String message = '', String fixHint = ''}) {
    return SetupStepResult(
      step: step,
      status: SetupStepStatus.failed,
      message: message,
      fixHint: fixHint,
    );
  }

  bool get success => status == SetupStepStatus.success;
  bool get skipped => status == SetupStepStatus.skipped;
  bool get failed => status == SetupStepStatus.failed;

  @override
  String toString() => 'SetupStepResult(${step.label}: $status)';
}

/// Aggregate report of an orchestrator run.
class OrchestratorReport {
  final List<SetupStepResult> results;

  /// Hosting URL for the release site, when it was successfully deployed.
  final String? releaseUrl;

  /// Hosting URL for the beta site, when it was successfully deployed.
  final String? betaUrl;

  /// Detected Blaze status; `null` when the billing check did not run.
  final BlazeStatus? blazeStatus;

  /// Bucket name we initialized (or confirmed existed).
  final String? storageBucketName;

  /// Firestore region we initialized (or confirmed existed).
  final String? firestoreRegion;

  /// True when the user (or fail-fast policy) aborted the run before
  /// every applicable step had a chance to execute. The caller is expected
  /// to treat unrun steps as "skipped, fix and re-run".
  final bool aborted;

  const OrchestratorReport({
    required this.results,
    this.releaseUrl,
    this.betaUrl,
    this.blazeStatus,
    this.storageBucketName,
    this.firestoreRegion,
    this.aborted = false,
  });

  /// Number of sub-steps that succeeded.
  int get successCount =>
      results.where((SetupStepResult r) => r.success).length;

  /// Number of sub-steps that were skipped.
  int get skippedCount =>
      results.where((SetupStepResult r) => r.skipped).length;

  /// Number of sub-steps that failed.
  int get failedCount => results.where((SetupStepResult r) => r.failed).length;

  /// True when no step failed (skips are allowed).
  bool get success => failedCount == 0;

  /// All steps that did not succeed (skipped or failed). Used to render the
  /// post-setup checklist of remaining work.
  List<SetupStepResult> get pending =>
      results.where((SetupStepResult r) => !r.success).toList(growable: false);

  /// All failed steps with their fix hints, suitable for printing as a
  /// "what went wrong" block.
  List<SetupStepResult> get failures =>
      results.where((SetupStepResult r) => r.failed).toList(growable: false);
}

/// Callback fired before each step starts. Returns `true` to run the step,
/// `false` to skip it. The default implementation runs every step.
typedef StepConfirm = Future<bool> Function(WizardSubStep step);

/// Callback fired after each step completes (success / skipped / failed).
typedef StepListener = Future<void> Function(SetupStepResult result);

/// User-facing decision after a step fails.
///
///   • [retry]  → re-run the same step from scratch (loops until success or
///                the user picks a different action)
///   • [skip]   → record as skipped, continue with the rest of the run
///   • [abort]  → stop the run immediately and return the partial report
enum FailureAction { retry, skip, abort }

/// Callback invoked when a step fails AND fail-fast is enabled. The wizard
/// implementation pretty-prints the failure (with `result.message` and
/// `result.fixHint`) and prompts the user. CLI callers running with
/// `interactive: false` can supply a fixed-policy implementation
/// (e.g. always [FailureAction.abort]).
///
/// `attempt` starts at 1 for the first failure of a given step and
/// increments by one per retry.
typedef StepFailureHandler = Future<FailureAction> Function(
  SetupStepResult result, {
  required int attempt,
});

/// High-level coordinator that wires every Firebase setup sub-step into a
/// single, idempotent end-to-end flow.
///
/// Used by:
///   • The interactive wizard (Step 5/6) — supplies a [StepConfirm] that
///     prompts the user before each sub-step and a [StepListener] that
///     drives the spinner / checklist UI.
///   • The CLI's `oracular deploy firebase-setup-full` — passes
///     [interactive: false] and accepts the defaults (run every step).
///   • Individual `oracular deploy <thing>` commands — call only the
///     specific sub-step method they care about.
///
/// All steps return [SetupStepResult]; nothing throws on user-facing
/// failures, so a partial run can always be resumed by re-invoking
/// [runAll] (every "ensure" call is idempotent).
class FirebaseSetupOrchestrator {
  /// Project / template configuration loaded from `setup_config.env`.
  final SetupConfig config;

  /// Existing Firebase wrapper used for login, FlutterFire / Jaspr JS SDK
  /// configuration, rules deploys, web build, and hosting deploys.
  final FirebaseService firebase;

  /// Billing detection + Blaze upgrade hand-off.
  final FirebaseBillingService billing;

  /// Firestore / Storage / Auth bootstrap helpers.
  final FirebaseInitializer initializer;

  /// Hosting site / target manager for `<project>` + `<project>-beta`.
  final HostingSiteManager hosting;

  /// Artifact Registry + Cloud Run cleanup helper. Only used when
  /// `config.setupCloudRun` is true.
  final ArtifactCleanupService cleanup;

  FirebaseSetupOrchestrator(
    this.config, {
    FirebaseService? firebase,
    FirebaseBillingService? billing,
    FirebaseInitializer? initializer,
    HostingSiteManager? hosting,
    ArtifactCleanupService? cleanup,
    ProcessRunner? runner,
  })  : firebase = firebase ?? FirebaseService(config, runner: runner),
        billing = billing ??
            FirebaseBillingService(
              config.firebaseProjectId ?? '',
              runner: runner,
            ),
        initializer = initializer ??
            FirebaseInitializer(
              config.firebaseProjectId ?? '',
              runner: runner,
            ),
        // ─── Hosting wiring ────────────────────────────────────────────────
        // Pass `firebase.authEnvironment` so HostingSiteManager runs every
        // `firebase` call with the same `GOOGLE_APPLICATION_CREDENTIALS`
        // Oracular uses elsewhere. Without this, `firebase
        // hosting:sites:create` inherits only the parent shell's env and
        // falls back to firebase-tools' stored login — which routinely
        // fails with "Failed to authenticate, have you run firebase
        // login?" the moment the user has logged out (or never logged in).
        hosting = hosting ??
            HostingSiteManager(
              config.firebaseProjectId ?? '',
              workingDirectory: config.outputDir,
              environment: (firebase ?? FirebaseService(config, runner: runner))
                  .authEnvironment,
              runner: runner,
            ),
        cleanup = cleanup ??
            ArtifactCleanupService(
              config.firebaseProjectId ?? '',
              runner: runner,
            );

  // ─── Service-account IAM gate ────────────────────────────────────────────

  /// Whether the wizard has already walked the user through granting IAM
  /// roles to the configured service account.
  ///
  /// We only ever prompt once per orchestrator instance; re-running an
  /// individual sub-step (e.g. retrying [runEnableFirebaseApis] after a
  /// failure) skips the prompt because the user has already confirmed.
  bool _serviceAccountIamGateConfirmed = false;

  /// IAM roles the configured service account needs in order for the rest
  /// of the wizard to succeed end-to-end. The auto-generated Firebase
  /// Admin SDK service account (`firebase-adminsdk-…@<project>.iam`) ships
  /// with `roles/firebase.sdkAdminServiceAgent` only — that role does NOT
  /// include `serviceusage.services.enable`, which is required by every
  /// `gcloud services enable …` call. Granting these four roles up-front
  /// turns the wizard into a single, unattended run.
  ///
  /// Each entry is `[displayName, roleId]`. The display name matches what
  /// the user sees in the Cloud Console "Add role" picker, so they can
  /// type the name verbatim.
  static const List<List<String>> _requiredServiceAccountRoles =
      <List<String>>[
    <String>['Service Usage Admin', 'roles/serviceusage.serviceUsageAdmin'],
    <String>['Firebase Admin', 'roles/firebase.admin'],
    <String>['Cloud Datastore Owner', 'roles/datastore.owner'],
    <String>['Storage Admin', 'roles/storage.admin'],
  ];

  /// Direct link to the IAM principals page for [projectId]. The user
  /// finds the row for their service account and clicks the pencil icon
  /// (or "Grant access" if the row does not yet exist) to add the roles
  /// listed in [_requiredServiceAccountRoles].
  static String _iamPageUrl(String projectId) =>
      'https://console.cloud.google.com/iam-admin/iam?project=$projectId';

  /// `true` when [email] looks like a Google Cloud service-account address
  /// (the `…@<project>.iam.gserviceaccount.com` suffix). Used to classify
  /// credentialed accounts so the gate can pick a *non-SA* principal to
  /// run IAM bindings as.
  static bool _isServiceAccountEmail(String email) =>
      email.toLowerCase().endsWith('.iam.gserviceaccount.com');

  /// One-time pre-flight check that runs before every step which requires
  /// project-management permissions on the active gcloud principal.
  ///
  /// Strategy (executed in order, each step short-circuits the gate):
  ///
  ///   1. **Probe first — TWO permissions.** Run a no-op `gcloud services
  ///      enable serviceusage.googleapis.com` AND a `firebase apps:list
  ///      --project X --json`. If BOTH succeed, the SA has every
  ///      permission downstream steps need (services.enable +
  ///      firebase.apps.list / firebase.apps.create), no prompt.
  ///      Probing only `services.enable` like we used to was the cause
  ///      of "step 5.4 says IAM check passed but step 5.5 fails with
  ///      firebase.apps.list PERMISSION_DENIED" — `roles/serviceusage.
  ///      serviceUsageAdmin` does not include firebase.* permissions.
  ///   2. **Detect the principal.** Prefer the `client_email` from the
  ///      service-account.json Oracular found, then fall back to
  ///      `gcloud config get-value account` (catches the case where the
  ///      user previously ran `gcloud auth activate-service-account`
  ///      without ever telling Oracular about the key file).
  ///   3. **Auto-grant when possible.** If the principal is a service
  ///      account *and* a non-SA user-account is already credentialed
  ///      (`gcloud auth list`), offer to switch to that user-account,
  ///      run `add-iam-policy-binding` for each missing role, and leave
  ///      it active for the rest of the run. Zero clicks, zero terminal
  ///      switches.
  ///   4. **Manual fallback.** Otherwise print the IAM-page URL and the
  ///      copy-pasteable `gcloud …` command, wait for the user, then
  ///      re-probe to verify.
  ///   5. **Verify-loop with IAM propagation poll.** After every grant
  ///      attempt poll BOTH probes for up to 60s — IAM bindings can take
  ///      30-60s to propagate, just like API enablement. If they still
  ///      fail, re-prompt; we never let the wizard continue with a
  ///      broken IAM state.
  ///
  /// No-op cases:
  ///   • [interactive] is `false` (CI / scripted runs — the failing step
  ///     will print its own fix hint instead).
  ///   • Both probes already return `true` (user-account auth, or SA
  ///     already has the roles).
  ///
  /// Returns `true` when the gate is satisfied; `false` when the user
  /// gave up. Callers translate `false` into a step failure.
  Future<bool> _ensureServiceAccountIamGate({
    required bool interactive,
  }) async {
    if (_serviceAccountIamGateConfirmed) return true;
    if (!interactive) {
      _serviceAccountIamGateConfirmed = true;
      return true;
    }

    final String? projectId = config.firebaseProjectId;
    if (projectId == null) {
      _serviceAccountIamGateConfirmed = true;
      return true;
    }

    // ─── 1. Probe BOTH services.enable AND firebase.apps.list ─────────────
    info('Verifying that the active account can enable Google APIs...');
    final bool canEnable = await firebase.canEnableServices();
    final bool canList = canEnable
        ? await firebase.canListFirebaseApps()
        : false;
    if (canEnable && canList) {
      success(
        'IAM check passed (services.enable + firebase.apps.list) — '
        'proceeding with API enablement.',
      );
      _serviceAccountIamGateConfirmed = true;
      return true;
    }
    if (canEnable && !canList) {
      // services.enable is granted but firebase.apps.list is missing —
      // the most common case: SA has roles/serviceusage.serviceUsageAdmin
      // but not roles/firebase.admin. Fall through to the grant flow so
      // step 5.5 doesn't fail.
      info(
        'Active account can enable APIs but cannot list Firebase apps — '
        'granting roles/firebase.admin and the rest of the IAM bundle.',
      );
    }

    // ─── 2. Detect the principal ──────────────────────────────────────────
    // Prefer the active gcloud account when it's an SA: that's the principal
    // every subsequent `gcloud …` call runs as (gcloud doesn't honour
    // GOOGLE_APPLICATION_CREDENTIALS, only its own credentialed-accounts
    // table). Granting roles to a different SA — even one matching
    // `service-account.json` in the repo — would leave gcloud calls
    // failing on the next probe. Only fall back to the SA file's
    // `client_email` when no SA is currently active in gcloud.
    final String? saPath = firebase.serviceAccountKeyPath;
    final String? activeAccount = await firebase.getActiveGcloudAccount();
    String? principalEmail;
    if (activeAccount != null && _isServiceAccountEmail(activeAccount)) {
      principalEmail = activeAccount;
    } else {
      principalEmail = firebase.serviceAccountEmail;
    }

    if (principalEmail == null) {
      // The probe failed but we cannot identify a service account to grant
      // roles to — this is something else (network error, gcloud not
      // installed, project does not exist, …). Surface it as a step
      // failure with a clear pointer.
      error(
        'Could not enable Google APIs and the active gcloud principal is '
        'not a service account. Run `gcloud auth list` and `gcloud config '
        'set account <owner@…>` then re-run the wizard.',
      );
      return false;
    }

    final String principal = 'serviceAccount:$principalEmail';
    final List<String> requiredRoleIds = _requiredServiceAccountRoles
        .map((List<String> r) => r[1])
        .toList(growable: false);

    // ─── 3. Auto-grant via a credentialed user-account ────────────────────
    final List<String> credAccounts = await firebase.getCredentialedAccounts();
    final List<String> userAccounts = credAccounts
        .where((String e) => !_isServiceAccountEmail(e))
        .toList(growable: false);

    if (userAccounts.isNotEmpty) {
      final String chosenAccount = userAccounts.first;
      print('');
      UserPrompt.printDivider(title: 'IAM grant required');
      UserPrompt.printList(<String>[
        'Active service account: $principalEmail',
        if (saPath != null) 'Key file: $saPath',
        'This account is missing the IAM roles needed to continue.',
        'Roles to add: ${requiredRoleIds.join(', ')}',
        'I can grant them automatically using your already-authenticated',
        'user-account ($chosenAccount) — no manual console steps needed.',
      ]);
      print('');
      final bool autoGrant = await UserPrompt.askYesNo(
        'Grant the roles automatically as $chosenAccount?',
        defaultValue: true,
      );
      if (autoGrant) {
        final bool ok = await _autoGrantUsingUserAccount(
          projectId: projectId,
          principalMember: principal,
          principalEmail: principalEmail,
          userAccount: chosenAccount,
          roleIds: requiredRoleIds,
        );
        if (ok) {
          _serviceAccountIamGateConfirmed = true;
          return true;
        }
        // Auto-grant failed → fall through to the manual flow so the user
        // can still complete the gate by hand.
      }
    }

    // ─── 4. Manual fallback ───────────────────────────────────────────────
    return _manualGrantLoop(
      projectId: projectId,
      principal: principal,
      principalEmail: principalEmail,
      saPath: saPath,
      requiredRoleIds: requiredRoleIds,
    );
  }

  /// Switch the active gcloud account to [userAccount] (an already
  /// credentialed Owner-grade principal), grant every role in [roleIds]
  /// to [principalMember] on [projectId], then re-probe to verify.
  ///
  /// Returns `true` only when the post-grant probe succeeds. Leaves
  /// [userAccount] as the active gcloud account on success — every later
  /// step that does not pass `_authEnvironment` benefits from its broader
  /// permissions.
  Future<bool> _autoGrantUsingUserAccount({
    required String projectId,
    required String principalMember,
    required String principalEmail,
    required String userAccount,
    required List<String> roleIds,
  }) async {
    info('Switching active gcloud account to $userAccount...');
    final bool switched = await firebase.setActiveGcloudAccount(userAccount);
    if (!switched) {
      warn('Could not switch active gcloud account to $userAccount.');
      return false;
    }

    bool allGranted = true;
    for (final String roleId in roleIds) {
      info('  Granting $roleId to $principalEmail...');
      final ({bool success, String error}) r =
          await firebase.addProjectIamBinding(
        projectId: projectId,
        member: principalMember,
        role: roleId,
      );
      if (!r.success) {
        warn('  Failed to grant $roleId: ${r.error}');
        allGranted = false;
      }
    }

    if (!allGranted) {
      warn(
        'Some bindings failed — falling back to manual grant flow. The '
        'most common cause is that $userAccount does not have the '
        '"resourcemanager.projects.setIamPolicy" permission on $projectId. '
        'Sign in as a project Owner instead.',
      );
      return false;
    }

    info('Re-verifying that $principalEmail can now enable Google APIs '
        'AND list Firebase apps...');
    // Test the SA principal explicitly (--account=<sa-email>) instead of
    // whatever account is now active. This catches the case where bindings
    // applied successfully against $userAccount but didn't actually grant
    // the SA the role (e.g., a typo in the role id, or the binding was
    // scoped to a parent folder that doesn't propagate).
    //
    // We poll because IAM bindings take 30-60s to propagate after
    // add-iam-policy-binding returns success. Without the poll, the wizard
    // would fail step 5.4 (or step 5.5) on the very first probe even
    // though the grant itself was successful.
    final bool gateOk = await _pollIamGateUntilReady(
      principalEmail: principalEmail,
      maxAttempts: 8, // 1+2+4+8+8+8+8 = 39s — typical IAM propagation
    );
    if (gateOk) {
      success(
        'Granted ${roleIds.length} role(s) to $principalEmail. '
        '$userAccount left active for the rest of the run.',
      );
      return true;
    }

    warn(
      'IAM bindings were applied but the verify probe still fails after '
      'polling for IAM propagation. Falling back to the manual loop so you '
      'can retry.',
    );
    return false;
  }

  /// Poll BOTH `canEnableServices` and `canListFirebaseApps` against
  /// [principalEmail] with capped exponential backoff until both return
  /// `true` or [maxAttempts] is exhausted.
  ///
  /// This closes the IAM-propagation gap between
  /// `gcloud projects add-iam-policy-binding` returning success and the
  /// new role actually taking effect on subsequent API calls. Without
  /// this poll, step 5.4 routinely passes ("IAM check passed") only for
  /// step 5.5 to immediately fail with `firebase.apps.list`
  /// PERMISSION_DENIED 100ms later because the binding hadn't propagated.
  ///
  /// Returns `true` once both probes succeed, `false` after the poll
  /// budget is exhausted.
  Future<bool> _pollIamGateUntilReady({
    required String principalEmail,
    int maxAttempts = 8,
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      final bool canEnable =
          await firebase.canEnableServices(account: principalEmail);
      final bool canList = canEnable
          ? await firebase.canListFirebaseApps(account: principalEmail)
          : false;
      if (canEnable && canList) {
        if (attempt > 1) {
          verbose('  IAM gate verified after $attempt probes.');
        }
        return true;
      }
      // Capped exponential backoff: 1s, 2s, 4s, 8s, 8s, 8s, 8s.
      final int delaySec = attempt < 4 ? (1 << (attempt - 1)) : 8;
      verbose(
        '  IAM gate not ready yet (attempt $attempt/$maxAttempts: '
        'enable=$canEnable list=$canList) — '
        'waiting ${delaySec}s for binding propagation...',
      );
      await Future<void>.delayed(Duration(seconds: delaySec));
    }
    return false;
  }

  /// Print the IAM-page URL + a copy-pasteable `gcloud` command and loop
  /// until the post-grant probe succeeds (or the user aborts).
  Future<bool> _manualGrantLoop({
    required String projectId,
    required String principal,
    required String principalEmail,
    required String? saPath,
    required List<String> requiredRoleIds,
  }) async {
    while (true) {
      print('');
      UserPrompt.printDivider(title: 'IAM grant required (manual)');
      UserPrompt.printList(<String>[
        'Active service account: $principalEmail',
        if (saPath != null) 'Key file: $saPath',
        'This account is missing the IAM roles needed to enable Google',
        'APIs and create Firestore / Storage / Hosting resources.',
      ]);
      print('');
      print('  Required roles:');
      for (final List<String> role in _requiredServiceAccountRoles) {
        print('    - ${role[0].padRight(22)}  (${role[1]})');
      }
      print('');
      print('  Open this link (signed in as a project Owner):');
      print('    ${_iamPageUrl(projectId)}');
      print('');
      print('  Or paste this in any terminal authenticated as a project Owner:');
      print('');
      print('    gcloud auth login');
      print('    gcloud config set project $projectId');
      print('    for ROLE in \\');
      for (int i = 0; i < requiredRoleIds.length; i++) {
        final String roleId = requiredRoleIds[i];
        final bool last = i == requiredRoleIds.length - 1;
        print('      $roleId${last ? '' : ' \\'}');
      }
      print('    ; do');
      print('      gcloud projects add-iam-policy-binding $projectId \\');
      print('        --member="$principal" \\');
      print('        --role="\$ROLE" \\');
      print('        --condition=None');
      print('    done');
      print('');

      await UserPrompt.askYesNo(
        'Press Y once you have granted the roles (I will verify with gcloud).',
        defaultValue: true,
      );

      info('Verifying that $principalEmail can now enable Google APIs '
          'AND list Firebase apps...');
      // Test the SA principal explicitly via --account=<email>. The user
      // may have a different gcloud account active right now, so we must
      // not rely on whichever principal is "active" at this moment — only
      // a successful probe as the SA itself proves the role was granted.
      // We poll because IAM bindings take 30-60s to propagate.
      if (await _pollIamGateUntilReady(
        principalEmail: principalEmail,
        maxAttempts: 8,
      )) {
        success('IAM grant verified — proceeding.');
        _serviceAccountIamGateConfirmed = true;
        return true;
      }

      warn(
        'Still denied after polling for IAM propagation. The roles may not '
        'have been granted on the right principal, or the binding was '
        'scoped to a parent folder that does not propagate.',
      );
      print('');
      final bool retry = await UserPrompt.askYesNo(
        'Try again?',
        defaultValue: true,
      );
      if (!retry) {
        return false;
      }
    }
  }

  /// Resets the IAM gate so it prompts again on the next call. Exposed for
  /// tests and for the rare CLI flow that wants to force a re-prompt.
  void resetServiceAccountIamGate() {
    _serviceAccountIamGateConfirmed = false;
  }

  // ─── Public API ──────────────────────────────────────────────────────────

  /// Run every applicable sub-step in order and return an aggregate report.
  ///
  /// Steps are skipped when the [confirm] callback returns false, when the
  /// project configuration disables the relevant feature (e.g. Cloud Run
  /// off), or when a soft prerequisite is unmet (Spark plan + Cloud Run).
  ///
  /// **Fail-fast contract:** when [failFast] is true (the default for the
  /// wizard) and a step fails, the orchestrator stops and asks the
  /// [onFailure] handler what to do. The handler can [FailureAction.retry]
  /// the same step, [FailureAction.skip] it and continue, or
  /// [FailureAction.abort] the whole run. If [onFailure] is null, the
  /// orchestrator behaves as if every failure returned [FailureAction.abort].
  ///
  /// When [failFast] is false (the legacy / non-interactive CLI mode),
  /// failed steps are recorded and the run continues so the user can see
  /// the full picture.
  Future<OrchestratorReport> runAll({
    StepConfirm? confirm,
    StepListener? onStep,
    StepFailureHandler? onFailure,
    bool interactive = true,
    bool failFast = true,
  }) async {
    if (config.firebaseProjectId == null ||
        config.firebaseProjectId!.isEmpty) {
      return OrchestratorReport(results: <SetupStepResult>[
        SetupStepResult.failed(
          WizardSubStep.firebaseLogin,
          message: 'No Firebase project ID configured',
          fixHint: 'Set FIREBASE_PROJECT_ID in config/setup_config.env',
        ),
      ], aborted: true);
    }

    final List<SetupStepResult> results = <SetupStepResult>[];
    String? releaseUrl;
    String? betaUrl;
    BlazeStatus? blazeStatus;
    String? storageBucketName;
    String? firestoreRegion;
    bool aborted = false;

    /// Run a single step with optional confirm gate, onStep listener,
    /// and (when failFast is true) retry/skip/abort handling on failure.
    /// Returns the final outcome.
    Future<SetupStepResult> runStep(
      WizardSubStep step,
      Future<SetupStepResult> Function() body, {
      bool defaultRun = true,
    }) async {
      // Once aborted, every subsequent call returns a "skipped due to abort"
      // marker without executing or prompting.
      if (aborted) {
        final SetupStepResult abortMarker = SetupStepResult.skipped(
          step,
          message: 'Run aborted by user — fix and re-run.',
          fixHint: _fixHintFor(step),
        );
        results.add(abortMarker);
        if (onStep != null) {
          await onStep(abortMarker);
        }
        return abortMarker;
      }

      bool shouldRun = defaultRun;
      if (confirm != null) {
        shouldRun = await confirm(step);
      }
      if (!shouldRun) {
        final SetupStepResult skipped = SetupStepResult.skipped(
          step,
          message: 'User declined this step',
          fixHint: _fixHintFor(step),
        );
        results.add(skipped);
        if (onStep != null) {
          await onStep(skipped);
        }
        return skipped;
      }

      // Execute (with retry loop when fail-fast is on).
      int attempt = 1;
      SetupStepResult outcome;
      while (true) {
        outcome = await body();
        if (!outcome.failed) {
          break;
        }
        if (!failFast) {
          // Legacy mode: keep going regardless.
          break;
        }
        // failFast=true → ask handler what to do.
        final FailureAction action = onFailure != null
            ? await onFailure(outcome, attempt: attempt)
            : FailureAction.abort;
        if (action == FailureAction.retry) {
          attempt++;
          continue;
        }
        if (action == FailureAction.skip) {
          outcome = SetupStepResult.skipped(
            step,
            message: outcome.message.isEmpty
                ? 'User skipped after failure'
                : 'Skipped after failure: ${outcome.message}',
            fixHint: outcome.fixHint,
          );
          break;
        }
        // abort
        aborted = true;
        break;
      }

      results.add(outcome);
      if (onStep != null) {
        await onStep(outcome);
      }
      return outcome;
    }

    // ── Step 5.1 – 5.3: authentication + billing ───────────────────────────
    await runStep(WizardSubStep.firebaseLogin, runFirebaseLogin);
    if (aborted) {
      return _buildReport(results, releaseUrl, betaUrl, blazeStatus,
          storageBucketName, firestoreRegion, aborted);
    }
    if (config.setupCloudRun || config.createServer) {
      await runStep(WizardSubStep.gcloudLogin, runGcloudLogin);
      if (aborted) {
        return _buildReport(results, releaseUrl, betaUrl, blazeStatus,
            storageBucketName, firestoreRegion, aborted);
      }
    }
    if (config.requireBlaze || config.setupCloudRun || config.createServer) {
      final SetupStepResult r = await runStep(
        WizardSubStep.billingCheck,
        () => runBillingCheck(interactive: interactive),
      );
      blazeStatus = r.success ? BlazeStatus.enabled : BlazeStatus.notEnabled;
      if (aborted) {
        return _buildReport(results, releaseUrl, betaUrl, blazeStatus,
            storageBucketName, firestoreRegion, aborted);
      }
    }

    // ── Step 5.4: enable required Firebase APIs upfront ────────────────────
    // We do this BEFORE anything that hits firestore / storage / firebase
    // management endpoints so those calls don't fail with SERVICE_DISABLED.
    await runStep(
      WizardSubStep.enableFirebaseApis,
      () => runEnableFirebaseApis(interactive: interactive),
    );
    if (aborted) {
      return _buildReport(results, releaseUrl, betaUrl, blazeStatus,
          storageBucketName, firestoreRegion, aborted);
    }

    // ── Step 5.5: client wiring (FlutterFire OR Jaspr JS SDK) ──────────────
    await runStep(WizardSubStep.configureClient, runConfigureClient);
    if (aborted) {
      return _buildReport(results, releaseUrl, betaUrl, blazeStatus,
          storageBucketName, firestoreRegion, aborted);
    }

    // ── Step 5.6 – 5.7: bootstrap Firestore + Storage ──────────────────────
    if (config.initializeFirestore) {
      final SetupStepResult r = await runStep(
        WizardSubStep.initFirestore,
        runFirestoreInit,
      );
      if (r.success) {
        firestoreRegion = config.firestoreRegion;
      }
      if (aborted) {
        return _buildReport(results, releaseUrl, betaUrl, blazeStatus,
            storageBucketName, firestoreRegion, aborted);
      }
    }
    if (config.initializeStorage) {
      final SetupStepResult r = await runStep(
        WizardSubStep.initStorage,
        runStorageInit,
      );
      if (r.success) {
        storageBucketName = '${config.firebaseProjectId}.appspot.com';
      }
      if (aborted) {
        return _buildReport(results, releaseUrl, betaUrl, blazeStatus,
            storageBucketName, firestoreRegion, aborted);
      }
    }

    // ── Step 5.8: auth providers (always console hand-off) ─────────────────
    if (config.enableEmailAuth || config.enableGoogleAuth) {
      await runStep(
        WizardSubStep.enableAuthProviders,
        () => runEnableAuthProviders(interactive: interactive),
      );
      if (aborted) {
        return _buildReport(results, releaseUrl, betaUrl, blazeStatus,
            storageBucketName, firestoreRegion, aborted);
      }
    }

    // ── Step 5.9: rules deploy (Firestore + Storage) ───────────────────────
    await runStep(
      WizardSubStep.deployFirestoreRules,
      runDeployFirestoreRules,
    );
    if (aborted) {
      return _buildReport(results, releaseUrl, betaUrl, blazeStatus,
          storageBucketName, firestoreRegion, aborted);
    }
    await runStep(WizardSubStep.deployStorageRules, runDeployStorageRules);
    if (aborted) {
      return _buildReport(results, releaseUrl, betaUrl, blazeStatus,
          storageBucketName, firestoreRegion, aborted);
    }

    // ── Step 5.10 – 5.13: web build + hosting deploys (skip when no web) ───
    final bool webEnabled = SetupGuidance.supportsWebHosting(config);
    if (webEnabled) {
      final SetupStepResult build = await runStep(
        WizardSubStep.buildWeb,
        runBuildWeb,
      );

      if (build.success) {
        if (config.deployHostingRelease || config.deployHostingBeta) {
          await runStep(WizardSubStep.hostingInit, runHostingInit);
          if (aborted) {
            return _buildReport(results, releaseUrl, betaUrl, blazeStatus,
                storageBucketName, firestoreRegion, aborted);
          }
        }

        if (config.deployHostingRelease) {
          final SetupStepResult r = await runStep(
            WizardSubStep.deployHostingRelease,
            runDeployHostingRelease,
          );
          if (r.success) {
            releaseUrl = SetupGuidance.releaseHostingUrl(
              config.firebaseProjectId!,
            );
          }
          if (aborted) {
            return _buildReport(results, releaseUrl, betaUrl, blazeStatus,
                storageBucketName, firestoreRegion, aborted);
          }
        }
        if (config.deployHostingBeta) {
          final SetupStepResult r = await runStep(
            WizardSubStep.deployHostingBeta,
            runDeployHostingBeta,
          );
          if (r.success) {
            betaUrl = SetupGuidance.betaHostingUrl(config.firebaseProjectId!);
          }
          if (aborted) {
            return _buildReport(results, releaseUrl, betaUrl, blazeStatus,
                storageBucketName, firestoreRegion, aborted);
          }
        }
      } else {
        // build failed → record skip results for the dependent hosting steps
        if (config.deployHostingRelease) {
          results.add(SetupStepResult.skipped(
            WizardSubStep.deployHostingRelease,
            message: 'Web build failed — hosting deploy skipped',
            fixHint: _fixHintFor(WizardSubStep.deployHostingRelease),
          ));
        }
        if (config.deployHostingBeta) {
          results.add(SetupStepResult.skipped(
            WizardSubStep.deployHostingBeta,
            message: 'Web build failed — beta hosting deploy skipped',
            fixHint: _fixHintFor(WizardSubStep.deployHostingBeta),
          ));
        }
      }
    }

    // ── Step 6.x: server / Cloud Run + cleanup (Blaze required) ────────────
    final bool runServerSteps = config.setupCloudRun || config.createServer;
    final bool blazeOk =
        blazeStatus == BlazeStatus.enabled || blazeStatus == null;
    if (runServerSteps && blazeOk) {
      await runStep(WizardSubStep.enableServerApis, runEnableServerApis);
      if (!aborted) {
        await runStep(
          WizardSubStep.ensureArtifactRegistryRepo,
          runEnsureArtifactRegistryRepo,
        );
      }
      if (!aborted && config.setupArtifactCleanup) {
        await runStep(
          WizardSubStep.applyArtifactCleanupPolicy,
          runApplyArtifactCleanupPolicy,
        );
      }
      if (!aborted && config.cloudRunKeepRevisions > 0) {
        await runStep(
          WizardSubStep.capCloudRunRevisions,
          runCapCloudRunRevisions,
        );
      }
    } else if (runServerSteps && !blazeOk) {
      // Record explicit skips so the post-run summary can list them.
      results.add(SetupStepResult.skipped(
        WizardSubStep.enableServerApis,
        message: 'Project is on Spark — Cloud Run is unavailable.',
        fixHint: _fixHintFor(WizardSubStep.enableServerApis),
      ));
      results.add(SetupStepResult.skipped(
        WizardSubStep.ensureArtifactRegistryRepo,
        message: 'Spark plan — Artifact Registry cleanup unavailable.',
        fixHint: _fixHintFor(WizardSubStep.ensureArtifactRegistryRepo),
      ));
      results.add(SetupStepResult.skipped(
        WizardSubStep.applyArtifactCleanupPolicy,
        message: 'Spark plan — cleanup policy not applied.',
        fixHint: _fixHintFor(WizardSubStep.applyArtifactCleanupPolicy),
      ));
      results.add(SetupStepResult.skipped(
        WizardSubStep.capCloudRunRevisions,
        message: 'Spark plan — Cloud Run revision cap not applied.',
        fixHint: _fixHintFor(WizardSubStep.capCloudRunRevisions),
      ));
    }

    return _buildReport(results, releaseUrl, betaUrl, blazeStatus,
        storageBucketName, firestoreRegion, aborted);
  }

  static OrchestratorReport _buildReport(
    List<SetupStepResult> results,
    String? releaseUrl,
    String? betaUrl,
    BlazeStatus? blazeStatus,
    String? storageBucketName,
    String? firestoreRegion,
    bool aborted,
  ) {
    return OrchestratorReport(
      results: List<SetupStepResult>.unmodifiable(results),
      releaseUrl: releaseUrl,
      betaUrl: betaUrl,
      blazeStatus: blazeStatus,
      storageBucketName: storageBucketName,
      firestoreRegion: firestoreRegion,
      aborted: aborted,
    );
  }

  // ─── Individual step methods (also re-exported via deploy_handlers) ──────

  Future<SetupStepResult> runFirebaseLogin() async {
    final bool ok = await firebase.login();
    if (ok) {
      return SetupStepResult.success(WizardSubStep.firebaseLogin);
    }
    return SetupStepResult.failed(
      WizardSubStep.firebaseLogin,
      message: 'firebase login did not complete successfully',
      fixHint: _fixHintFor(WizardSubStep.firebaseLogin),
    );
  }

  Future<SetupStepResult> runGcloudLogin() async {
    final bool ok = await firebase.gcloudLogin();
    if (ok) {
      return SetupStepResult.success(WizardSubStep.gcloudLogin);
    }
    return SetupStepResult.failed(
      WizardSubStep.gcloudLogin,
      message: 'gcloud auth did not complete successfully',
      fixHint: _fixHintFor(WizardSubStep.gcloudLogin),
    );
  }

  Future<SetupStepResult> runBillingCheck({bool interactive = true}) async {
    final BillingCheckResult check = await billing.checkBlazeStatus();
    switch (check.status) {
      case BlazeStatus.enabled:
        info('Blaze plan confirmed for ${config.firebaseProjectId}.');
        return SetupStepResult.success(
          WizardSubStep.billingCheck,
          message: check.billingAccountName != null
              ? 'Billing account: ${check.billingAccountName}'
              : 'Blaze',
        );
      case BlazeStatus.notEnabled:
        if (!interactive) {
          return SetupStepResult.skipped(
            WizardSubStep.billingCheck,
            message: 'Project is on Spark — Cloud Run requires Blaze',
            fixHint: _fixHintFor(WizardSubStep.billingCheck),
          );
        }
        final BillingCheckResult upgraded = await billing.guideUpgrade();
        if (upgraded.status == BlazeStatus.enabled) {
          return SetupStepResult.success(
            WizardSubStep.billingCheck,
            message: 'Upgraded to Blaze',
          );
        }
        return SetupStepResult.skipped(
          WizardSubStep.billingCheck,
          message: upgraded.message ??
              'Project remained on Spark; Blaze-only steps will be skipped.',
          fixHint: _fixHintFor(WizardSubStep.billingCheck),
        );
      case BlazeStatus.unknown:
        return SetupStepResult.skipped(
          WizardSubStep.billingCheck,
          message: check.message ?? 'Could not determine billing status',
          fixHint: _fixHintFor(WizardSubStep.billingCheck),
        );
    }
  }

  Future<SetupStepResult> runConfigureClient() async {
    final bool ok = await firebase.configureFlutterFire();
    if (ok) {
      return SetupStepResult.success(WizardSubStep.configureClient);
    }
    return SetupStepResult.failed(
      WizardSubStep.configureClient,
      message: config.template.isJasprApp
          // The Jaspr path runs `firebase apps:list WEB` + `apps:create WEB`
          // through `_runFirebaseWithRecovery`, which already auto-enables the
          // Firebase Management API and retries transient failures. If we
          // landed here anyway, the failure is one of:
          //   • The service account is missing IAM roles even after the gate
          //     in step 5.4 (e.g., `firebase.apps.create`,
          //     `serviceusage.services.enable`).
          //   • Firebase Management API is enabled but still propagating —
          //     re-running in 30-60 seconds will succeed.
          //   • A non-recoverable error (project deleted, billing issue,
          //     org policy block). The verbose logs above show the root
          //     cause from firebase-debug.log.
          ? 'Could not inject Firebase JS SDK into Jaspr index.html. '
              'See the warning above for the root cause from '
              'firebase-debug.log. Common fixes:\n'
              '  • Wait 30-60s and retry — the Firebase Management API may '
              'still be propagating after enable.\n'
              '  • Run `oracular deploy firebase-setup-full` to re-run the '
              'IAM gate (step 5.4) and retry this step.\n'
              '  • Verify the service account has the firebase-setup-full '
              'IAM bundle on this project.'
          : 'flutterfire configure did not complete successfully',
      fixHint: _fixHintFor(WizardSubStep.configureClient),
    );
  }

  /// Enable the Firebase APIs every project needs (firebase, firestore,
  /// firebasestorage, firebasehosting, identitytoolkit, serviceusage).
  ///
  /// This step is idempotent — re-running on a project where the APIs are
  /// already enabled is a no-op (gcloud short-circuits on the server side).
  ///
  /// When [interactive] is true, this method first walks the user through
  /// granting the IAM roles the active gcloud principal needs (see
  /// [_ensureServiceAccountIamGate]). If the gate cannot be satisfied
  /// (probe still fails after retries, or the user gives up), the step
  /// returns a `failed` result *without* attempting the API enablement,
  /// so we don't spam the user with six identical PERMISSION_DENIED
  /// warnings before bailing out.
  Future<SetupStepResult> runEnableFirebaseApis({
    bool interactive = true,
  }) async {
    final bool gateOk =
        await _ensureServiceAccountIamGate(interactive: interactive);
    if (!gateOk) {
      final String? projectId = config.firebaseProjectId;
      final String url = projectId == null
          ? ''
          : ' (open ${_iamPageUrl(projectId)} and grant the missing roles)';
      return SetupStepResult.failed(
        WizardSubStep.enableFirebaseApis,
        message: 'IAM gate not satisfied — '
            'the active gcloud principal cannot enable Google APIs$url',
        fixHint: _fixHintFor(WizardSubStep.enableFirebaseApis),
      );
    }
    final List<String> failed = await firebase.enableFirebaseCoreApis();
    if (failed.isEmpty) {
      return SetupStepResult.success(
        WizardSubStep.enableFirebaseApis,
        message: 'Enabled core Firebase APIs',
      );
    }
    final String firstApi = failed.first;
    final String? projectId = config.firebaseProjectId;
    final String url = projectId == null
        ? ''
        : ' (open ${FirebaseInitializer.apiEnableUrl(projectId, firstApi)})';
    return SetupStepResult.failed(
      WizardSubStep.enableFirebaseApis,
      message: 'Failed to enable: ${failed.join(', ')}$url',
      fixHint: _fixHintFor(WizardSubStep.enableFirebaseApis),
    );
  }

  Future<SetupStepResult> runFirestoreInit() async {
    final FirestoreInitResult r = await initializer.ensureFirestoreDatabase(
      region: config.firestoreRegion,
    );
    if (r.success) {
      return SetupStepResult.success(
        WizardSubStep.initFirestore,
        message: r.created
            ? 'Created (region: ${r.region})'
            : 'Already exists (region: ${r.region})',
      );
    }
    return SetupStepResult.failed(
      WizardSubStep.initFirestore,
      message: r.message,
      fixHint: _fixHintFor(WizardSubStep.initFirestore),
    );
  }

  Future<SetupStepResult> runStorageInit() async {
    final StorageInitResult r = await initializer.ensureStorageBucket();
    if (r.success) {
      return SetupStepResult.success(
        WizardSubStep.initStorage,
        message: r.created
            ? 'Created bucket gs://${r.bucketName}'
            : 'Already exists: gs://${r.bucketName}',
      );
    }

    // The default Firebase Storage bucket cannot be created via gcloud or
    // firebase CLI — it uses a reserved Google domain (`*.firebasestorage.app`
    // or legacy `*.appspot.com`) and only the Firebase Console's "Get
    // started" click-through can provision it. So when `needsFirebaseInit`
    // is set, we route through an interactive console hand-off (auto-open
    // the URL, wait for user confirmation, re-probe) instead of failing
    // hard with a stale gcloud 403.
    if (r.needsFirebaseInit && r.getStartedUrl != null) {
      return _handoffStorageBucketInit(r);
    }

    return SetupStepResult.failed(
      WizardSubStep.initStorage,
      message: r.message,
      fixHint: _fixHintFor(WizardSubStep.initStorage),
    );
  }

  /// Interactive console hand-off for default Firebase Storage bucket
  /// provisioning.
  ///
  /// Why this exists: modern Firebase projects (post-Sept 2024) get
  /// `<projectId>.firebasestorage.app` as their default bucket and
  /// **the bucket is not auto-created** at project creation. Legacy
  /// projects get `<projectId>.appspot.com` which used to be auto-
  /// provisioned but is no longer guaranteed. In both cases the bucket
  /// names are reserved Google domains, so:
  ///   • `gcloud storage buckets create` fails with HTTP 403 "verify
  ///     domain ownership at search.google.com/search-console".
  ///   • `firebase init storage` doesn't create the bucket either; it
  ///     just writes `storage.rules` against an existing one.
  ///
  /// The only working path is the Firebase Console's `/storage` page,
  /// which calls a Firebase backend that has implicit ownership of
  /// these reserved domains.
  ///
  /// Flow:
  ///   1. Print step-by-step instructions with the direct console URL.
  ///   2. Try to auto-open the URL in the user's default browser.
  ///   3. Block on `Press Enter when you've clicked "Get started"...`.
  ///   4. Re-probe `gcloud storage buckets describe` — if the bucket
  ///      now exists, return success.
  ///   5. If not, offer Retry / Skip / Abort. Retry waits 5s and
  ///      re-probes (covers the ~30s provisioning window after the
  ///      console hand-off).
  Future<SetupStepResult> _handoffStorageBucketInit(StorageInitResult r) async {
    final String url = r.getStartedUrl!;

    UserPrompt.printDivider(title: 'Provision default Storage bucket');
    UserPrompt.printList(<String>[
      'Bucket name will be: gs://${r.bucketName}',
      'This is a one-time, one-click setup that ONLY the Firebase',
      'Console can perform (the bucket name uses a reserved Google',
      'domain — `gcloud` and `firebase` CLI both fail with 403).',
    ]);
    print('');
    UserPrompt.printNumberedList(<String>[
      'Open: $url',
      'Click the "Get started" button.',
      'Choose "Start in production mode" (or test mode for dev) → Next.',
      'Pick a Cloud Storage location (recommend matching your Firestore region — `us-central1` is a safe default).',
      'Click "Done" and wait ~30 seconds for provisioning.',
    ]);
    print('');

    // Auto-open the URL — user still has to click but at least we save them
    // the copy/paste. If it fails (no browser, headless env), they have the
    // URL printed above.
    info('Opening browser to: $url');
    final bool opened = await LinkOpener.open(url);
    if (!opened) {
      warn('Could not auto-open browser. Copy the URL above into your browser manually.');
    }
    print('');

    // Re-probe loop: prompt → wait → re-check → on miss offer retry.
    int attempt = 0;
    while (true) {
      attempt += 1;
      final bool confirmed = await UserPrompt.askYesNo(
        attempt == 1
            ? 'Have you clicked "Get started" and finished the dialog?'
            : 'Try again — has the bucket finished provisioning yet?',
        defaultValue: true,
      );
      if (!confirmed) {
        return SetupStepResult.failed(
          WizardSubStep.initStorage,
          message:
              'User has not yet provisioned the default Storage bucket. '
              'Re-run `oracular deploy storage-init` after clicking '
              '"Get started" at $url.',
          fixHint: _fixHintFor(WizardSubStep.initStorage),
        );
      }

      info('Re-checking gs://${r.bucketName}...');
      final StorageInitResult retry = await initializer.ensureStorageBucket();
      if (retry.success) {
        return SetupStepResult.success(
          WizardSubStep.initStorage,
          message: 'Detected bucket gs://${retry.bucketName} (provisioned via console).',
        );
      }

      // Still not visible. Provisioning can take ~30s after the console
      // dialog closes; offer a short wait + retry before giving up.
      warn(
        'Bucket gs://${r.bucketName} not yet visible to gcloud — '
        'provisioning may still be in progress (Firebase typically '
        'takes ~30s after "Done" is clicked).',
      );
      if (attempt >= 4) {
        return SetupStepResult.failed(
          WizardSubStep.initStorage,
          message:
              'Bucket gs://${r.bucketName} still not visible after $attempt '
              'attempts. The console hand-off may not have completed; '
              're-open $url and verify the bucket appears in the Storage '
              'tab, then re-run `oracular deploy storage-init`.',
          fixHint: _fixHintFor(WizardSubStep.initStorage),
        );
      }
      // Brief wait before next prompt — gives Firebase backend time to finish.
      info('Waiting 5s for Firebase to finish provisioning, then re-prompting...');
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }

  Future<SetupStepResult> runEnableAuthProviders({
    bool interactive = true,
  }) async {
    final Set<AuthProvider> providers = <AuthProvider>{
      if (config.enableEmailAuth) AuthProvider.emailPassword,
      if (config.enableGoogleAuth) AuthProvider.google,
    };
    if (providers.isEmpty) {
      return SetupStepResult.skipped(
        WizardSubStep.enableAuthProviders,
        message: 'No auth providers requested in config',
      );
    }
    final AuthProvidersResult r = await initializer.enableAuthProviders(
      providers: providers,
      interactive: interactive,
    );
    if (r.success) {
      return SetupStepResult.success(
        WizardSubStep.enableAuthProviders,
        message:
            'Configured: ${providers.map((AuthProvider p) => p.label).join(', ')}',
      );
    }
    return SetupStepResult.skipped(
      WizardSubStep.enableAuthProviders,
      message: r.message,
      fixHint: _fixHintFor(WizardSubStep.enableAuthProviders),
    );
  }

  Future<SetupStepResult> runDeployFirestoreRules() async {
    final bool ok = await firebase.deployFirestore();
    if (ok) {
      return SetupStepResult.success(WizardSubStep.deployFirestoreRules);
    }
    return SetupStepResult.failed(
      WizardSubStep.deployFirestoreRules,
      message: 'firebase deploy --only firestore failed',
      fixHint: _fixHintFor(WizardSubStep.deployFirestoreRules),
    );
  }

  Future<SetupStepResult> runDeployStorageRules() async {
    final bool ok = await firebase.deployStorage(allowNotInitialized: true);
    if (ok) {
      return SetupStepResult.success(WizardSubStep.deployStorageRules);
    }
    return SetupStepResult.failed(
      WizardSubStep.deployStorageRules,
      message: 'firebase deploy --only storage failed',
      fixHint: _fixHintFor(WizardSubStep.deployStorageRules),
    );
  }

  Future<SetupStepResult> runBuildWeb() async {
    if (!SetupGuidance.supportsWebHosting(config)) {
      return SetupStepResult.skipped(
        WizardSubStep.buildWeb,
        message: 'Project does not produce a web build',
      );
    }
    final bool ok = await firebase.buildWeb();
    if (ok) {
      return SetupStepResult.success(WizardSubStep.buildWeb);
    }
    return SetupStepResult.failed(
      WizardSubStep.buildWeb,
      message: config.template.isJasprApp
          ? 'jaspr build failed'
          : 'flutter build web failed',
      fixHint: _fixHintFor(WizardSubStep.buildWeb),
    );
  }

  Future<SetupStepResult> runHostingInit() async {
    final SiteEnsureResult release = await hosting.ensureReleaseSite();
    final SiteEnsureResult beta = await hosting.ensureBetaSite();
    final ApplyTargetsResult apply = await hosting.applyTargets();
    if (release.success && beta.success && apply.success) {
      return SetupStepResult.success(
        WizardSubStep.hostingInit,
        message:
            'release=${release.siteId}, beta=${beta.siteId}, targets applied',
      );
    }
    final String issues = <String>[
      if (!release.success) 'release: ${release.message}',
      if (!beta.success) 'beta: ${beta.message}',
      if (!apply.success) 'targets: ${apply.message}',
    ].join('; ');
    return SetupStepResult.failed(
      WizardSubStep.hostingInit,
      message: issues,
      fixHint: _fixHintFor(WizardSubStep.hostingInit),
    );
  }

  Future<SetupStepResult> runDeployHostingRelease() async {
    final bool ok = await firebase.deployHostingRelease();
    if (ok) {
      return SetupStepResult.success(
        WizardSubStep.deployHostingRelease,
        message: SetupGuidance.releaseHostingUrl(config.firebaseProjectId!),
      );
    }
    return SetupStepResult.failed(
      WizardSubStep.deployHostingRelease,
      message: 'firebase deploy --only hosting:release failed',
      fixHint: _fixHintFor(WizardSubStep.deployHostingRelease),
    );
  }

  Future<SetupStepResult> runDeployHostingBeta() async {
    final bool ok = await firebase.deployHostingBeta();
    if (ok) {
      return SetupStepResult.success(
        WizardSubStep.deployHostingBeta,
        message: SetupGuidance.betaHostingUrl(config.firebaseProjectId!),
      );
    }
    return SetupStepResult.failed(
      WizardSubStep.deployHostingBeta,
      message: 'firebase deploy --only hosting:beta failed',
      fixHint: _fixHintFor(WizardSubStep.deployHostingBeta),
    );
  }

  Future<SetupStepResult> runEnableServerApis() async {
    final bool ok = await firebase.enableGoogleApis();
    if (ok) {
      return SetupStepResult.success(WizardSubStep.enableServerApis);
    }
    return SetupStepResult.failed(
      WizardSubStep.enableServerApis,
      message: 'gcloud services enable failed for one or more APIs',
      fixHint: _fixHintFor(WizardSubStep.enableServerApis),
    );
  }

  Future<SetupStepResult> runEnsureArtifactRegistryRepo({
    String repository = 'oracular',
  }) async {
    final RepositoryEnsureResult r =
        await cleanup.ensureRepository(repository: repository);
    if (r.success) {
      return SetupStepResult.success(
        WizardSubStep.ensureArtifactRegistryRepo,
        message: r.changed
            ? 'Created `${r.repository}`@${r.region}'
            : 'Already exists: `${r.repository}`@${r.region}',
      );
    }
    return SetupStepResult.failed(
      WizardSubStep.ensureArtifactRegistryRepo,
      message: r.message,
      fixHint: _fixHintFor(WizardSubStep.ensureArtifactRegistryRepo),
    );
  }

  Future<SetupStepResult> runApplyArtifactCleanupPolicy({
    String repository = 'oracular',
  }) async {
    final CleanupPolicyResult r = await cleanup.applyCleanupPolicies(
      repository: repository,
      keepRecent: config.artifactKeepRecent,
      deleteOlderDays: config.artifactDeleteOlderDays,
    );
    if (r.success) {
      return SetupStepResult.success(
        WizardSubStep.applyArtifactCleanupPolicy,
        message: 'Keep ${config.artifactKeepRecent} recent + delete '
            '>${config.artifactDeleteOlderDays}d',
      );
    }
    return SetupStepResult.failed(
      WizardSubStep.applyArtifactCleanupPolicy,
      message: r.message,
      fixHint: _fixHintFor(WizardSubStep.applyArtifactCleanupPolicy),
    );
  }

  Future<SetupStepResult> runCapCloudRunRevisions() async {
    final String service = config.serverPackageName.replaceAll('_', '-');
    final RevisionPruneResult r = await cleanup.capCloudRunRevisions(
      service: service,
      keepRevisions: config.cloudRunKeepRevisions,
    );
    if (r.success) {
      return SetupStepResult.success(
        WizardSubStep.capCloudRunRevisions,
        message: 'Deleted ${r.deleted}, skipped ${r.skipped}',
      );
    }
    return SetupStepResult.failed(
      WizardSubStep.capCloudRunRevisions,
      message:
          'Failed to prune ${r.failedRevisions.length} revisions: ${r.failedRevisions.join(', ')}',
      fixHint: _fixHintFor(WizardSubStep.capCloudRunRevisions),
    );
  }

  // ─── Fix-hint registry ───────────────────────────────────────────────────

  /// CLI command (or short hint) the user can run to retry a single step.
  /// Used both internally for [SetupStepResult.fixHint] and externally so
  /// callers can build their own re-run lists.
  static String _fixHintFor(WizardSubStep step) {
    switch (step) {
      case WizardSubStep.firebaseLogin:
        return 'firebase login --reauth';
      case WizardSubStep.gcloudLogin:
        return 'gcloud auth login --update-adc';
      case WizardSubStep.billingCheck:
        return 'oracular check billing';
      case WizardSubStep.enableFirebaseApis:
        return 'oracular deploy firebase-setup-full';
      case WizardSubStep.configureClient:
        return 'oracular deploy firebase-setup-full';
      case WizardSubStep.initFirestore:
        return 'oracular deploy firestore-init';
      case WizardSubStep.initStorage:
        return 'oracular deploy storage-init';
      case WizardSubStep.enableAuthProviders:
        return 'oracular deploy auth-providers';
      case WizardSubStep.deployFirestoreRules:
        return 'oracular deploy firestore';
      case WizardSubStep.deployStorageRules:
        return 'oracular deploy storage';
      case WizardSubStep.buildWeb:
        return 'oracular deploy hosting';
      case WizardSubStep.hostingInit:
        return 'oracular deploy hosting-init';
      case WizardSubStep.deployHostingRelease:
        return 'oracular deploy hosting';
      case WizardSubStep.deployHostingBeta:
        return 'oracular deploy hosting-beta';
      case WizardSubStep.enableServerApis:
        return 'oracular deploy firebase-setup-full';
      case WizardSubStep.ensureArtifactRegistryRepo:
        return 'oracular deploy artifact-cleanup';
      case WizardSubStep.applyArtifactCleanupPolicy:
        return 'oracular deploy artifact-cleanup';
      case WizardSubStep.capCloudRunRevisions:
        return 'oracular deploy cloudrun-prune';
    }
  }

  /// Public re-export of the per-step fix hint registry, for callers
  /// (e.g. the wizard UI) that want to display "to retry, run …".
  static String fixHintFor(WizardSubStep step) => _fixHintFor(step);
}
