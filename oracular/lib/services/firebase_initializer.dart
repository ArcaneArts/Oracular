import 'dart:convert';

import 'package:fast_log/fast_log.dart';

import '../utils/process_runner.dart' show ProcessResult, ProcessRunner;
import '../utils/user_prompt.dart';
import 'firebase_billing_service.dart';

/// Identifier for a Firebase Auth provider.
///
/// Currently supported by [FirebaseInitializer.enableAuthProviders]:
///   • [emailPassword] — auto-enabled via REST when an admin token is present
///   • [google]        — always a console hand-off (OAuth client config is
///                       browser-only)
enum AuthProvider {
  /// Email + password (no link / no anonymous).
  emailPassword,

  /// Google federated sign-in.
  google,
}

extension AuthProviderLabel on AuthProvider {
  /// Human-readable label used in CLI output.
  String get label {
    switch (this) {
      case AuthProvider.emailPassword:
        return 'Email / Password';
      case AuthProvider.google:
        return 'Google sign-in';
    }
  }
}

/// Outcome of `FirebaseInitializer.enableAuthProviders`.
class AuthProvidersResult {
  /// Providers we attempted to enable.
  final Set<AuthProvider> requested;

  /// Providers we automated successfully (never includes [AuthProvider.google]).
  final Set<AuthProvider> automated;

  /// Providers that required the console hand-off (always succeeds because
  /// the user confirms manually).
  final Set<AuthProvider> handedOff;

  /// Diagnostic message; empty on full success.
  final String message;

  const AuthProvidersResult({
    required this.requested,
    required this.automated,
    required this.handedOff,
    this.message = '',
  });

  /// True when every requested provider was either automated or handed off.
  bool get success => automated.union(handedOff).containsAll(requested);

  @override
  String toString() => 'AuthProvidersResult(automated: ${automated.length}, '
      'handedOff: ${handedOff.length})';
}

/// Outcome of `FirebaseInitializer.ensureFirestoreDatabase`.
class FirestoreInitResult {
  /// The default database already existed.
  final bool existed;

  /// We just created the default database.
  final bool created;

  /// Multi-region or regional locator (e.g. `nam5`, `us-central1`).
  final String region;

  /// Diagnostic message; empty on success.
  final String message;

  const FirestoreInitResult({
    required this.existed,
    required this.created,
    required this.region,
    this.message = '',
  });

  bool get success => existed || created;

  /// Convenience: did the initializer change anything?
  bool get changed => created;

  @override
  String toString() => 'FirestoreInitResult(existed: $existed, created: $created, region: $region)';
}

/// Outcome of `FirebaseInitializer.ensureStorageBucket`.
class StorageInitResult {
  /// The default bucket already existed.
  final bool existed;

  /// We just created the default bucket.
  final bool created;

  /// Bucket name (no `gs://` prefix).
  final String bucketName;

  /// Diagnostic message; empty on success.
  final String message;

  /// True when the bucket is accessible via `gcloud storage` but Firebase
  /// Storage itself has not yet had "Get Started" clicked in the console.
  /// Callers can prompt the user to finalize via the URL in [getStartedUrl].
  final bool needsFirebaseInit;

  /// Console URL the user can visit to finish enabling Firebase Storage.
  final String? getStartedUrl;

  const StorageInitResult({
    required this.existed,
    required this.created,
    required this.bucketName,
    this.message = '',
    this.needsFirebaseInit = false,
    this.getStartedUrl,
  });

  bool get success => existed || created;

  bool get changed => created;

  @override
  String toString() =>
      'StorageInitResult(existed: $existed, created: $created, bucket: $bucketName)';
}

/// Bootstraps Firebase resources that the orchestrator depends on.
///
/// This service intentionally avoids any project-wide side effects beyond
/// creating the default Firestore database and the default Storage bucket.
/// All operations are idempotent: an already-existing resource is treated
/// as success.
///
/// All shell commands are routed through [ProcessRunner] for testability.
class FirebaseInitializer {
  /// Firebase / GCP project id.
  final String projectId;

  final ProcessRunner _runner;

  FirebaseInitializer(this.projectId, {ProcessRunner? runner})
      : _runner = runner ?? ProcessRunner();

  /// Ensure the default Firestore database exists for [projectId].
  ///
  /// Runs `gcloud firestore databases describe --database=(default)` to
  /// detect existence; on `NOT_FOUND` runs `gcloud firestore databases
  /// create --location=REGION --type=firestore-native`.
  ///
  /// Defaults to multi-region [region] `nam5` (US). Other common values:
  ///   • `eur3` — multi-region EU
  ///   • `us-central1`, `europe-west1`, `asia-northeast1` — regional
  ///
  /// Any failure other than NOT_FOUND is surfaced via [FirestoreInitResult.message]
  /// without throwing, so callers can downgrade to a console hand-off.
  Future<FirestoreInitResult> ensureFirestoreDatabase({
    String region = 'nam5',
  }) async {
    if (projectId.isEmpty) {
      return FirestoreInitResult(
        existed: false,
        created: false,
        region: region,
        message: 'No Firebase project ID configured',
      );
    }

    info('Checking Firestore default database for $projectId...');
    final ProcessResult describe = await _runner.run('gcloud', <String>[
      'firestore',
      'databases',
      'describe',
      '--database=(default)',
      '--project=$projectId',
      '--format=json',
    ]);

    if (describe.success) {
      final String? existingRegion = _extractFirestoreRegion(describe.stdout);
      info('Firestore database already exists '
          '${existingRegion != null ? '(region: $existingRegion)' : ''}');
      return FirestoreInitResult(
        existed: true,
        created: false,
        region: existingRegion ?? region,
      );
    }

    final String stderr = describe.stderr;

    // Special-case: API not enabled. We surface a clear hand-off so the
    // wizard can offer "auto-enable + retry".
    if (_isApiNotEnabledError(stderr, 'firestore.googleapis.com')) {
      return FirestoreInitResult(
        existed: false,
        created: false,
        region: region,
        message:
            'Cloud Firestore API is not enabled for $projectId. Enable it via:\n'
            '  • gcloud services enable firestore.googleapis.com --project=$projectId\n'
            '  • or open: ${apiEnableUrl(projectId, 'firestore.googleapis.com')}',
      );
    }

    if (FirebaseBillingService.isBillingAbsentError(stderr)) {
      return FirestoreInitResult(
        existed: false,
        created: false,
        region: region,
        message:
            'Billing is not enabled on $projectId. Upgrade to Blaze first:\n'
            '  ${FirebaseBillingService.upgradeUrl(projectId)}',
      );
    }

    if (!_isNotFoundError(stderr)) {
      // Don't block on permission / auth issues — caller can hand off.
      return FirestoreInitResult(
        existed: false,
        created: false,
        region: region,
        message: stderr.trim().isEmpty
            ? 'gcloud firestore describe exited ${describe.exitCode}'
            : stderr.trim(),
      );
    }

    info('Creating Firestore default database in $region...');
    final ProcessResult create = await _runner.run('gcloud', <String>[
      'firestore',
      'databases',
      'create',
      '--database=(default)',
      '--location=$region',
      '--project=$projectId',
      '--type=firestore-native',
    ]);

    if (create.success) {
      success('Firestore database created (region: $region).');
      return FirestoreInitResult(
        existed: false,
        created: true,
        region: region,
        message: 'Created in $region',
      );
    }

    final String createErr = create.stderr;
    if (FirebaseBillingService.isBillingAbsentError(createErr)) {
      return FirestoreInitResult(
        existed: false,
        created: false,
        region: region,
        message:
            'Billing is not enabled on $projectId. Upgrade to Blaze first:\n'
            '  ${FirebaseBillingService.upgradeUrl(projectId)}',
      );
    }

    return FirestoreInitResult(
      existed: false,
      created: false,
      region: region,
      message: createErr.trim().isEmpty
          ? 'gcloud firestore create exited ${create.exitCode}'
          : createErr.trim(),
    );
  }

  /// Ensure the default Firebase Storage bucket exists for [projectId].
  ///
  /// **Bucket-naming history (matters for what we probe):**
  ///   • Pre-Sept 2024: every Firebase project got `<projectId>.appspot.com`
  ///     as the default bucket, auto-provisioned at project creation.
  ///   • Post-Sept 2024: new projects get `<projectId>.firebasestorage.app`
  ///     instead, and **the bucket is NOT auto-created** — the user must
  ///     click "Get Started" in the Firebase Storage console once.
  ///   • Both name patterns are reserved Google domains, so a direct
  ///     `gcloud storage buckets create` against either fails with
  ///     "domain ownership verification required" — only the Firebase
  ///     Console (and Firebase backend) can create them.
  ///
  /// Strategy: probe both naming conventions for an existing bucket. If
  /// one exists, return it (success). If neither does, surface the
  /// "needs Firebase Storage init in console" path with the direct link
  /// — *don't* try to `gcloud storage buckets create` because that path
  /// is dead for default Firebase buckets and only produces confusing
  /// "verify domain ownership" errors that the user has no way to
  /// resolve.
  ///
  /// Note: a freshly-linked Firebase Storage bucket is reachable via
  /// `gcloud storage buckets describe` immediately, so this probe sees
  /// it the moment the user finishes the console click-through.
  Future<StorageInitResult> ensureStorageBucket({
    String location = 'US',
  }) async {
    if (projectId.isEmpty) {
      return const StorageInitResult(
        existed: false,
        created: false,
        bucketName: '',
        message: 'No Firebase project ID configured',
      );
    }

    // Modern projects get .firebasestorage.app, legacy projects got
    // .appspot.com. Probe both — whichever exists is the default bucket.
    final List<String> candidateBuckets = <String>[
      '$projectId.firebasestorage.app',
      '$projectId.appspot.com',
    ];

    String? lastDescribeStderr;
    for (final String bucketName in candidateBuckets) {
      final String bucketUri = 'gs://$bucketName';
      info('Checking default Storage bucket $bucketUri...');
      final ProcessResult describe = await _runner.run('gcloud', <String>[
        'storage',
        'buckets',
        'describe',
        bucketUri,
        '--format=json',
      ]);
      if (describe.success) {
        info('Default Storage bucket already exists: $bucketUri');
        return StorageInitResult(
          existed: true,
          created: false,
          bucketName: bucketName,
        );
      }
      lastDescribeStderr = describe.stderr;
    }

    // Neither candidate exists. Both `.firebasestorage.app` and
    // `.appspot.com` are reserved Google domains — `gcloud storage
    // buckets create` against either would fail with a "verify domain
    // ownership at search.google.com/search-console" 403, which the
    // user has no way to resolve (they don't own the domain). The
    // ONLY path that creates these buckets is the Firebase Console's
    // "Get Started" click-through, which calls a Firebase backend
    // that has implicit ownership.
    //
    // So: surface the console URL and let the orchestrator hand the
    // user off with a clear message, rather than burning a `buckets
    // create` call that's guaranteed to fail.
    final String defaultName = '$projectId.firebasestorage.app';
    final String stderr = lastDescribeStderr ?? '';

    if (FirebaseBillingService.isBillingAbsentError(stderr)) {
      return StorageInitResult(
        existed: false,
        created: false,
        bucketName: defaultName,
        message:
            'Billing is not enabled on $projectId. Either:\n'
            '  • Upgrade to Blaze: ${FirebaseBillingService.upgradeUrl(projectId)}\n'
            '  • OR open ${getStartedUrl(projectId)} and click "Get Started" '
            '(works on Spark — Firebase will create gs://$defaultName for you).',
        needsFirebaseInit: true,
        getStartedUrl: getStartedUrl(projectId),
      );
    }

    if (_isApiNotEnabledError(stderr, 'firebasestorage.googleapis.com') ||
        _isApiNotEnabledError(stderr, 'storage.googleapis.com')) {
      return StorageInitResult(
        existed: false,
        created: false,
        bucketName: defaultName,
        message:
            'Firebase Storage API is not enabled for $projectId. Enable it via:\n'
            '  • gcloud services enable firebasestorage.googleapis.com --project=$projectId\n'
            '  • or open: ${apiEnableUrl(projectId, 'firebasestorage.googleapis.com')}',
        needsFirebaseInit: true,
        getStartedUrl: getStartedUrl(projectId),
      );
    }

    // Default bucket isn't provisioned. The only working path is the
    // console click-through. Make the message explicit and actionable
    // — the user gets a direct link, the exact button label, and the
    // expected outcome.
    return StorageInitResult(
      existed: false,
      created: false,
      bucketName: defaultName,
      message:
          'Default Storage bucket has not been provisioned for $projectId.\n'
          'This is a one-time, one-click setup that only the Firebase\n'
          'Console can perform (the bucket name uses a reserved Google\n'
          'domain, so neither `gcloud` nor `firebase` CLI can create it).\n\n'
          '  1. Open: ${getStartedUrl(projectId)}\n'
          '  2. Click the "Get started" button.\n'
          '  3. Choose "Start in production mode" → Next.\n'
          '  4. Pick a location (recommend matching your Firestore region;\n'
          '     `us-central1` is a safe default).\n'
          '  5. Click "Done" and wait ~30 seconds for provisioning.\n'
          '  6. Re-run `oracular` — Step 5.7 will detect the new bucket\n'
          '     (`gs://$defaultName`) automatically and continue.',
      needsFirebaseInit: true,
      getStartedUrl: getStartedUrl(projectId),
    );
  }

  /// URL to enable Firebase Storage in the console.
  static String getStartedUrl(String projectId) =>
      'https://console.firebase.google.com/project/$projectId/storage';

  /// URL to view Firestore in the console.
  static String firestoreConsoleUrl(String projectId) =>
      'https://console.firebase.google.com/project/$projectId/firestore';

  /// URL to the Authentication > Sign-in method tab in the Firebase Console.
  static String authProvidersConsoleUrl(String projectId) =>
      'https://console.firebase.google.com/project/$projectId/authentication/providers';

  /// URL to the Authentication > Settings > Authorized domains tab.
  static String authDomainsConsoleUrl(String projectId) =>
      'https://console.firebase.google.com/project/$projectId/authentication/settings';

  /// URL to the Google OAuth consent screen / client configuration.
  static String oauthConsentUrl(String projectId) =>
      'https://console.cloud.google.com/apis/credentials/consent?project=$projectId';

  /// Walk the user through enabling each requested Firebase Auth provider.
  ///
  /// Auth provider toggles are intentionally a *console hand-off* rather
  /// than an automation:
  ///
  ///   • Email/Password could be flipped via the Identity Toolkit Admin
  ///     REST API, but that requires an OAuth bearer token with the
  ///     `https://www.googleapis.com/auth/firebase` scope. Asking the user
  ///     to mint that token is more friction than just clicking a single
  ///     toggle in the browser.
  ///   • Google sign-in cannot be fully automated at all — the OAuth
  ///     client still has to be configured by hand in Google Cloud
  ///     Console, including the consent screen and authorized domains.
  ///
  /// This method therefore prints the list of providers, opens (well —
  /// emits) the relevant URLs, and confirms with the user. It always
  /// succeeds when [interactive] is false (silent skip).
  ///
  /// Behaviour for both Flutter and Jaspr templates is identical: the
  /// console URL is the same regardless of client framework.
  Future<AuthProvidersResult> enableAuthProviders({
    required Set<AuthProvider> providers,
    bool interactive = true,
  }) async {
    if (projectId.isEmpty) {
      return AuthProvidersResult(
        requested: providers,
        automated: const <AuthProvider>{},
        handedOff: const <AuthProvider>{},
        message: 'No Firebase project ID configured',
      );
    }

    if (providers.isEmpty) {
      return const AuthProvidersResult(
        requested: <AuthProvider>{},
        automated: <AuthProvider>{},
        handedOff: <AuthProvider>{},
      );
    }

    if (!interactive) {
      info(
        'Non-interactive mode: skipping auth provider hand-off for ${providers.map((AuthProvider p) => p.label).join(', ')}',
      );
      return AuthProvidersResult(
        requested: providers,
        automated: const <AuthProvider>{},
        handedOff: const <AuthProvider>{},
        message: 'Run `oracular deploy auth-providers` interactively',
      );
    }

    UserPrompt.printDivider(title: 'Enable Firebase Auth providers');
    UserPrompt.printList(<String>[
      'Open: ${authProvidersConsoleUrl(projectId)}',
      for (final AuthProvider p in providers) _instructionFor(p),
      if (providers.contains(AuthProvider.google))
        'Google OAuth client config: ${oauthConsentUrl(projectId)}',
      'Authorized domains (add web hosting domains): ${authDomainsConsoleUrl(projectId)}',
    ]);
    print('');

    final bool confirmed = await UserPrompt.askYesNo(
      'Have you enabled the providers above?',
      defaultValue: true,
    );

    if (!confirmed) {
      warn(
        'Auth providers not yet enabled. Re-run `oracular deploy auth-providers` once they are configured.',
      );
      return AuthProvidersResult(
        requested: providers,
        automated: const <AuthProvider>{},
        handedOff: const <AuthProvider>{},
        message: 'User skipped Auth provider enablement',
      );
    }

    return AuthProvidersResult(
      requested: providers,
      automated: const <AuthProvider>{},
      handedOff: providers,
    );
  }

  /// Per-provider hand-off instruction line (printed inside [enableAuthProviders]).
  static String _instructionFor(AuthProvider provider) {
    switch (provider) {
      case AuthProvider.emailPassword:
        return '${provider.label}: click "Email/Password" → toggle "Enable" → Save.';
      case AuthProvider.google:
        return '${provider.label}: click "Google" → toggle "Enable", set support email, → Save.';
    }
  }

  /// Detect a `NOT_FOUND` style failure from gcloud stderr. gcloud is not
  /// fully consistent so we accept several phrasings:
  ///   • Firestore: `NOT_FOUND: The project does not exist`
  ///   • Storage:   `HTTPError 404: bucket ... not found`
  ///   • Generic:   `was not found`, `could not find`, `does not exist`
  static bool _isNotFoundError(String stderr) {
    final String lower = stderr.toLowerCase();
    return lower.contains('not_found') ||
        lower.contains('does not exist') ||
        lower.contains('not found') ||
        lower.contains('could not find') ||
        lower.contains('404');
  }

  /// Detect a "API has not been used / is disabled" error for [api].
  /// Matches both gcloud's PERMISSION_DENIED phrasing and the explicit
  /// SERVICE_DISABLED reason field that comes back as JSON or plain text.
  static bool _isApiNotEnabledError(String stderr, String api) {
    final String lower = stderr.toLowerCase();
    final String apiLower = api.toLowerCase();
    if (lower.contains('service_disabled')) {
      return true;
    }
    if (lower.contains(apiLower) &&
        (lower.contains('has not been used') ||
            lower.contains('is disabled') ||
            lower.contains('is not enabled') ||
            lower.contains('not been activated'))) {
      return true;
    }
    return false;
  }

  /// Console URL that lets the user enable a single Google API on a project.
  /// Used in error messages so the wizard can render a clickable link.
  static String apiEnableUrl(String projectId, String api) =>
      'https://console.developers.google.com/apis/api/$api/overview?project=$projectId';

  /// Pull `locationId` (e.g. `nam5`) out of `gcloud firestore describe` JSON.
  static String? _extractFirestoreRegion(String stdout) {
    final String trimmed = stdout.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final dynamic decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final dynamic location = decoded['locationId'];
        if (location is String && location.isNotEmpty) {
          return location;
        }
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}
