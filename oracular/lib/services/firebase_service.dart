import 'dart:convert';
import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../models/setup_config.dart';
import '../models/template_info.dart';
import '../utils/process_runner.dart' show ProcessResult, ProcessRunner;
import '../utils/user_prompt.dart';
import 'firebase_initializer.dart';

/// Service for Firebase operations
class FirebaseService {
  static const String _firebaseJsSdkVersion = '12.12.1';

  final SetupConfig config;
  final ProcessRunner _runner;

  FirebaseService(this.config, {ProcessRunner? runner})
    : _runner = runner ?? ProcessRunner();

  String? get _resolvedServiceAccountPath {
    final Set<String> candidates = <String>{};
    final String? configuredPath = config.serviceAccountKeyPath;

    if (configuredPath != null && configuredPath.trim().isNotEmpty) {
      candidates.add(
        p.isAbsolute(configuredPath)
            ? configuredPath
            : p.normalize(p.join(config.outputDir, configuredPath)),
      );
    }

    // Conventional project-level locations.
    candidates.add(
      p.normalize(p.join(config.outputDir, 'service-account.json')),
    );
    candidates.add(
      p.normalize(
        p.join(config.outputDir, 'config', 'keys', 'service-account.json'),
      ),
    );

    // Fallback for running Oracular from a workspace with a root key file.
    candidates.add(
      p.normalize(p.join(Directory.current.path, 'service-account.json')),
    );

    for (final String candidate in candidates) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    return null;
  }

  Map<String, String>? get _authEnvironment {
    final String? serviceAccountPath = _resolvedServiceAccountPath;
    if (serviceAccountPath == null) {
      return null;
    }
    return <String, String>{
      'GOOGLE_APPLICATION_CREDENTIALS': serviceAccountPath,
    };
  }

  /// Public accessor for the auth environment so collaborator services
  /// (like [HostingSiteManager]) can run firebase/gcloud as the same SA
  /// that Oracular's other steps use. Returns the same map as the
  /// internal `_authEnvironment` getter — i.e. a single-key map binding
  /// `GOOGLE_APPLICATION_CREDENTIALS` to the resolved SA file, or `null`
  /// when no SA file was configured/found.
  ///
  /// Without this, downstream commands like `firebase hosting:sites:create`
  /// inherit only the parent shell's environment, which routinely leaves
  /// firebase-tools with no credentials at all (no stored login + no
  /// GOOGLE_APPLICATION_CREDENTIALS) and fails with "Failed to authenticate,
  /// have you run firebase login?".
  Map<String, String>? get authEnvironment => _authEnvironment;

  /// Absolute path to the service-account JSON file Oracular will use for
  /// authenticating Firebase / gcloud commands, or `null` when none was
  /// supplied or found.
  ///
  /// The wizard uses this to (a) decide whether to prompt the user for a
  /// one-time IAM grant before steps that require project-management
  /// permissions, and (b) display the file path in those instructions.
  String? get serviceAccountKeyPath => _resolvedServiceAccountPath;

  /// `client_email` field extracted from the configured service-account JSON,
  /// or `null` when no key file is configured / readable / valid.
  ///
  /// Used by the wizard to render targeted IAM-page instructions
  /// (`grant these roles to {email}`) before any step that needs
  /// `serviceusage.services.enable` or similar project-level permissions.
  /// A returned value is the canonical principal string for
  /// `gcloud projects add-iam-policy-binding --member="serviceAccount:..."`.
  String? get serviceAccountEmail {
    final String? path = _resolvedServiceAccountPath;
    if (path == null) {
      return null;
    }
    try {
      final String body = File(path).readAsStringSync();
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final dynamic email = decoded['client_email'];
        if (email is String && email.trim().isNotEmpty) {
          return email.trim();
        }
      }
    } catch (_) {
      // Malformed key file → caller treats this as "no SA email available"
      // and falls back to the path-only message.
    }
    return null;
  }

  /// Email of the gcloud account currently active for this terminal session
  /// (`gcloud config get-value account`), or `null` when gcloud is not
  /// authenticated / not installed.
  ///
  /// This is the principal that *all* `gcloud …` calls run as when Oracular
  /// has no [_authEnvironment] override (i.e. no `service-account.json`
  /// found in the project folder). When the user previously ran
  /// `gcloud auth activate-service-account`, this can return a service
  /// account email even though Oracular itself never set
  /// `GOOGLE_APPLICATION_CREDENTIALS`. The wizard uses it as a fallback
  /// detector so the IAM gate fires correctly in that case.
  Future<String?> getActiveGcloudAccount() async {
    final ProcessResult r = await _runner.run(
      'gcloud',
      <String>['config', 'get-value', 'account'],
    );
    if (!r.success) return null;
    final String trimmed = _stripAnsi(r.stdout).trim();
    if (trimmed.isEmpty || trimmed == '(unset)') return null;
    return trimmed;
  }

  /// Email of the user the Firebase CLI is logged in as
  /// (`firebase login:list --json`), or `null` when no login is stored.
  ///
  /// **Why this matters:** the Firebase CLI prefers a stored login token
  /// at `~/.config/configstore/firebase-tools.json` over `GOOGLE_APPLICATION_
  /// CREDENTIALS`. So a user who did `firebase login` previously as a
  /// personal account that does NOT have `firebase.admin` on the
  /// configured project will hit `firebase apps:list` PERMISSION_DENIED
  /// even though Oracular set `GOOGLE_APPLICATION_CREDENTIALS` to a
  /// service-account JSON that *does* have the role.
  ///
  /// Used by [_logCredentialDiagnostics] to surface "you're authenticated
  /// as `<user>`, but the SA is `<other>` — these don't match" so the user
  /// can `firebase logout` and let Oracular's SA auth take over.
  Future<String?> getActiveFirebaseAccount() async {
    final ProcessResult r = await _runner.run(
      'firebase',
      <String>['login:list', '--json'],
    );
    if (!r.success) return null;
    try {
      final dynamic decoded = jsonDecode(_stripAnsi(r.stdout));
      if (decoded is Map<String, dynamic>) {
        final dynamic result = decoded['result'];
        if (result is List && result.isNotEmpty) {
          final dynamic first = result.first;
          if (first is Map<String, dynamic>) {
            final dynamic user = first['user'];
            if (user is Map<String, dynamic>) {
              final dynamic email = user['email'];
              if (email is String && email.trim().isNotEmpty) {
                return email.trim();
              }
            }
            // Some firebase CLI versions return the email at the top level.
            final dynamic email = first['email'];
            if (email is String && email.trim().isNotEmpty) {
              return email.trim();
            }
          } else if (first is String && first.trim().isNotEmpty) {
            return first.trim();
          }
        }
      } else if (decoded is List && decoded.isNotEmpty) {
        final dynamic first = decoded.first;
        if (first is String && first.trim().isNotEmpty) return first.trim();
      }
    } catch (_) {
      // Older firebase CLI doesn't support --json on login:list; parse
      // the text output as a fallback ("Logged in as <email>").
      final RegExp emailRe = RegExp(r'([\w.+-]+@[\w-]+\.[\w.-]+)');
      final Match? match = emailRe.firstMatch(_stripAnsi(r.stdout));
      if (match != null) return match.group(1);
    }
    return null;
  }

  /// Print every credential identity Oracular can see — service-account
  /// path/email, active gcloud account, and the Firebase CLI's stored
  /// login. Called when a `firebase` command fails with PERMISSION_DENIED
  /// so the user (and any AI agent reading the log) can immediately tell
  /// whether the failure is "wrong credentials being used" vs "right
  /// credentials, missing role".
  ///
  /// Also prints the **last 50 lines of firebase-debug.log verbatim** so
  /// the actual API response from Firebase Management is visible without
  /// the user having to `cat` the file themselves.
  Future<void> _logCredentialDiagnostics() async {
    print('');
    UserPrompt.printDivider(title: 'Credential diagnostics');
    final List<String> lines = <String>[];
    final String? saPath = _resolvedServiceAccountPath;
    final String? saEmail = serviceAccountEmail;
    lines.add(
      'Service-account file:    ${saPath ?? '(none configured)'}',
    );
    lines.add(
      'Service-account email:   ${saEmail ?? '(unable to read)'}',
    );
    final String? gcloudAccount = await getActiveGcloudAccount();
    lines.add(
      'Active gcloud account:   ${gcloudAccount ?? '(none)'}',
    );
    final String? firebaseAccount = await getActiveFirebaseAccount();
    lines.add(
      'Firebase CLI logged in:  ${firebaseAccount ?? '(none)'}',
    );

    // The killer mismatch: Oracular sets GOOGLE_APPLICATION_CREDENTIALS
    // to point at the SA, but firebase-tools prefers a stored login
    // token. If the firebase CLI is logged in as someone OTHER than the
    // SA, those calls run as the logged-in user, NOT the SA — even
    // though `gcloud …` calls run as the SA. This is the most common
    // cause of "Step 5.4 passes (gcloud) but Step 5.5 fails (firebase)".
    if (firebaseAccount != null &&
        saEmail != null &&
        firebaseAccount.toLowerCase() != saEmail.toLowerCase()) {
      lines.add('');
      lines.add(
        'Mismatch: Firebase CLI is authenticating as $firebaseAccount,',
      );
      lines.add(
        'but Oracular is using service-account $saEmail.',
      );
      lines.add(
        'firebase-tools prefers its stored login over '
        'GOOGLE_APPLICATION_CREDENTIALS, so commands like apps:list run',
      );
      lines.add(
        'as $firebaseAccount — which probably does NOT have firebase.admin',
      );
      lines.add('on this project. Fix:');
      lines.add('  firebase logout --force');
      lines.add('  # then re-run oracular');
    }

    UserPrompt.printList(lines);

    // Dump the firebase-debug.log tail so the user sees the actual API
    // response that firebase-tools hides behind "see firebase-debug.log".
    final String? logTail = _readFullFirebaseDebugLogTail(maxLines: 50);
    if (logTail != null && logTail.isNotEmpty) {
      print('');
      print('  --- firebase-debug.log (last 50 lines) ---');
      for (final String line in logTail.split('\n')) {
        print('  $line');
      }
      print('  --- end firebase-debug.log ---');
    } else {
      print('');
      print('  (firebase-debug.log not found in cwd or '
          '${config.outputDir} — firebase CLI did not write a debug log)');
    }
    print('');
  }

  /// Return the full last-N-lines of firebase-debug.log verbatim. Used by
  /// [_logCredentialDiagnostics] to surface the underlying error from the
  /// Firebase Management API response that firebase-tools hides behind
  /// the generic "See firebase-debug.log for more info." stderr line.
  String? _readFullFirebaseDebugLogTail({int maxLines = 50}) {
    final File? log = _findFirebaseDebugLog();
    if (log == null) return null;
    try {
      final List<String> lines = log.readAsLinesSync();
      if (lines.isEmpty) return null;
      final int start = lines.length > maxLines ? lines.length - maxLines : 0;
      return lines.sublist(start).join('\n');
    } catch (_) {
      return null;
    }
  }

  /// All credentialed accounts gcloud knows about
  /// (`gcloud auth list --format=value(account)`), in arbitrary order.
  ///
  /// Returns an empty list when the command fails or when no accounts
  /// are credentialed. Used by the IAM gate to find a non-service-account
  /// principal that can be used to run `add-iam-policy-binding` calls
  /// without forcing the user to log in again.
  Future<List<String>> getCredentialedAccounts() async {
    final ProcessResult r = await _runner.run('gcloud', <String>[
      'auth',
      'list',
      '--format=value(account)',
    ]);
    if (!r.success) return const <String>[];
    return _stripAnsi(r.stdout)
        .split('\n')
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList(growable: false);
  }

  /// Set the active gcloud account (`gcloud config set account <email>`).
  /// Returns true on success.
  ///
  /// The wizard uses this to temporarily switch to a user-account that
  /// has Owner privileges on the project so it can grant IAM roles to
  /// the SA, then leaves the user-account active for the rest of the run
  /// (subsequent steps either pass `_authEnvironment` explicitly when a
  /// SA file is configured, or benefit from the user-account's broader
  /// permissions).
  Future<bool> setActiveGcloudAccount(String email) async {
    final ProcessResult r = await _runner.run('gcloud', <String>[
      'config',
      'set',
      'account',
      email,
    ]);
    return r.success;
  }

  /// Probe whether a gcloud principal has the `serviceusage.services.enable`
  /// permission on [projectId] by trying to enable a single API. Defaults to
  /// `serviceusage.googleapis.com` because that API is auto-enabled on every
  /// project at creation, so the call is effectively a no-op when the
  /// principal *does* have the permission.
  ///
  /// When [account] is provided, the call passes `--account=<email>` so the
  /// probe tests that specific credentialed principal regardless of which
  /// one is currently active. This is how the IAM gate verifies that the
  /// service account actually received the freshly-granted role bindings,
  /// instead of accidentally testing the user-account we temporarily
  /// switched to in order to run `add-iam-policy-binding`.
  ///
  /// Returns:
  ///   - `true`  → enable succeeded (principal can enable services)
  ///   - `false` → PERMISSION_DENIED or any other error
  ///
  /// Used as the verify-step of the IAM gate: we run this once before
  /// prompting (to skip the gate when roles are already granted) and once
  /// after the user confirms the grant (to make sure the binding actually
  /// took effect before continuing the wizard).
  Future<bool> canEnableServices({
    String api = 'serviceusage.googleapis.com',
    String? account,
  }) async {
    final String? projectId = config.firebaseProjectId;
    if (projectId == null) return false;
    final List<String> args = <String>[
      'services',
      'enable',
      api,
      '--project',
      projectId,
      if (account != null && account.trim().isNotEmpty)
        '--account=${account.trim()}',
    ];
    final ProcessResult r = await _runner.run(
      'gcloud',
      args,
      environment: _authEnvironment,
    );
    return r.success;
  }

  /// Probe whether the active principal has `firebase.apps.list` on the
  /// configured project — i.e. the permission needed by step 5.5
  /// (Configure Firebase client wiring).
  ///
  /// Why this exists: [canEnableServices] only verifies
  /// `serviceusage.services.enable` which is granted by
  /// `roles/serviceusage.serviceUsageAdmin`. A service account with that
  /// role but no `roles/firebase.admin` will pass the existing IAM gate
  /// in step 5.4 yet fail step 5.5 with `firebase.apps.list`
  /// PERMISSION_DENIED. This probe closes that gap so the gate can grant
  /// the missing `firebase.admin` role *before* step 5.5 runs.
  ///
  /// Returns:
  ///   • `true`  → the principal can list Firebase apps OR the call
  ///               failed for a reason that is NOT a missing IAM role
  ///               (e.g. the Firebase Management API is not enabled
  ///               yet — that's fine because step 5.4 will enable it
  ///               immediately after the gate passes). We err on the
  ///               side of "let the wizard proceed" so a brand-new
  ///               project doesn't get stuck in the gate trying to
  ///               auto-grant a role the SA already has.
  ///   • `false` → ONLY when the failure is unambiguously
  ///               PERMISSION_DENIED. This is what triggers the
  ///               auto-grant flow.
  ///
  /// We use `apps:list --json` so the Firebase CLI emits a structured
  /// `{"status":"error", …}` envelope instead of a generic "Failed to
  /// list" stderr line, which lets [_classifyFirebaseError] tell the
  /// difference between SERVICE_DISABLED (API not enabled — *not* an
  /// IAM problem) and PERMISSION_DENIED (the actual IAM gap we want
  /// to fix).
  Future<bool> canListFirebaseApps({String? account}) async {
    final String? projectId = config.firebaseProjectId;
    if (projectId == null) return false;
    final ProcessResult r = await _runner.run(
      'firebase',
      <String>[
        'apps:list',
        '--project',
        projectId,
        '--json',
        if (account != null && account.trim().isNotEmpty)
          '--account=${account.trim()}',
      ],
      environment: _authEnvironment,
      workingDirectory: config.outputDir,
    );
    final Map<String, dynamic>? body = _parseFirebaseJson(r.stdout);
    if (body != null && body['status'] == 'success') {
      return true;
    }
    // Failure path: only treat PERMISSION_DENIED as "gate failed". If
    // the firebase.googleapis.com API just isn't enabled yet (the
    // SERVICE_DISABLED case), the gate should let the wizard continue
    // — step 5.4 will enable the API, and the post-enable propagation
    // poll will revalidate. Without this carve-out, a brand-new
    // project where the API has never been enabled would force the
    // gate into auto-grant for a role the SA may already have.
    final String context = _collectFirebaseFailureContext(r);
    final FirebaseFailureKind kind = _classifyFirebaseError(context);
    if (kind == FirebaseFailureKind.permissionDenied) {
      return false;
    }
    // serviceDisabled / transient / unknown → presume the SA has the
    // role; the next step will surface any real failure.
    return true;
  }

  /// Add an IAM binding (`gcloud projects add-iam-policy-binding`) granting
  /// [role] to [member] on [projectId]. Idempotent: re-running on a project
  /// where the binding already exists is a no-op (gcloud reports success).
  ///
  /// [member] must be a fully qualified principal such as
  /// `serviceAccount:foo@bar.iam.gserviceaccount.com` or
  /// `user:alice@example.com`. The call runs **without** [_authEnvironment]
  /// so that the currently active gcloud account (typically the user's
  /// personal Owner account) is used — a service account that doesn't have
  /// `resourcemanager.projects.setIamPolicy` cannot grant itself extra
  /// privileges, so we always run this as whichever principal gcloud
  /// considers "active".
  ///
  /// Returns `(success, errorMessage)`. The error message is a stripped
  /// stderr useful for direct display in the wizard's prompt.
  Future<({bool success, String error})> addProjectIamBinding({
    required String projectId,
    required String member,
    required String role,
  }) async {
    final ProcessResult r = await _runner.run('gcloud', <String>[
      'projects',
      'add-iam-policy-binding',
      projectId,
      '--member=$member',
      '--role=$role',
      '--condition=None',
      '--quiet',
    ]);
    if (r.success) {
      return (success: true, error: '');
    }
    final String stderr = _stripAnsi(r.stderr).trim();
    final String stdout = _stripAnsi(r.stdout).trim();
    return (
      success: false,
      error: stderr.isNotEmpty
          ? stderr
          : (stdout.isNotEmpty
              ? stdout
              : 'gcloud add-iam-policy-binding exited ${r.exitCode}')
    );
  }

  String? _requireFirebaseProjectId() {
    if (config.firebaseProjectId == null || config.firebaseProjectId!.isEmpty) {
      error('Firebase project ID not set');
      return null;
    }
    return config.firebaseProjectId!;
  }

  /// Strip ANSI escape sequences (color codes, etc.) from a string.
  static String _stripAnsi(String input) {
    return input.replaceAll(RegExp(r'\x1B\[[0-9;]*[a-zA-Z]'), '');
  }

  /// Extract the JSON payload from a Firebase CLI response. Firebase prints
  /// a spinner line above the JSON body, so we trim everything up to the first
  /// `{` character and parse from there. Returns `null` if no JSON object
  /// could be parsed.
  static Map<String, dynamic>? _parseFirebaseJson(String stdout) {
    final String cleaned = _stripAnsi(stdout);
    final int braceIndex = cleaned.indexOf('{');
    if (braceIndex < 0) {
      return null;
    }
    final String jsonText = cleaned.substring(braceIndex);
    try {
      final dynamic decoded = jsonDecode(jsonText);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Pull the human readable error message out of a failed firebase --json
  /// response. Falls back to stdout/stderr when the JSON envelope is missing.
  static String _firebaseError(ProcessResult result) {
    final Map<String, dynamic>? parsed = _parseFirebaseJson(result.stdout);
    if (parsed != null) {
      final dynamic err = parsed['error'];
      if (err is String && err.trim().isNotEmpty) {
        return err.trim();
      }
      if (err is Map && err['message'] is String) {
        return (err['message'] as String).trim();
      }
    }

    final String stderr = _stripAnsi(result.stderr).trim();
    if (stderr.isNotEmpty) {
      return stderr;
    }

    final String stdout = _stripAnsi(result.stdout).trim();
    if (stdout.isNotEmpty) {
      return stdout;
    }

    return 'Firebase command failed with exit code ${result.exitCode}';
  }

  /// Public accessor for tests so they can verify error extraction logic.
  static String firebaseErrorForTest(ProcessResult result) =>
      _firebaseError(result);

  // ─── firebase-debug.log diagnostics ───────────────────────────────────────
  //
  // When a `firebase --json` call fails with the unhelpful generic message
  // "Failed to … See firebase-debug.log for more info." the actual root
  // cause (`SERVICE_DISABLED`, `PERMISSION_DENIED`, propagation lag) is
  // only available in firebase-debug.log. We read that file (cwd or
  // outputDir, whichever is fresher) and surface the underlying error so
  // (a) users see something actionable and (b) the auto-recovery loop can
  // classify the failure and pick a strategy (retry / enable API / IAM
  // gate).

  /// Locate the freshest firebase-debug.log Oracular can find. The Firebase
  /// CLI writes this file to the working directory of the invocation, so we
  /// check both the process cwd and `config.outputDir` and return whichever
  /// was modified most recently. Returns `null` when no log exists.
  File? _findFirebaseDebugLog() {
    final List<File> candidates = <File>[];
    final List<String> paths = <String>[
      p.join(Directory.current.path, 'firebase-debug.log'),
      p.join(config.outputDir, 'firebase-debug.log'),
    ];
    for (final String path in paths) {
      final File file = File(path);
      if (file.existsSync()) {
        candidates.add(file);
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((File a, File b) =>
        b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return candidates.first;
  }

  /// Pull the most recent error block out of a firebase-debug.log file.
  ///
  /// The CLI writes structured lines like:
  ///   `[debug] [2026-05-08T…] <<< [apiv2][body] POST … {"error":{…}}`
  /// followed by stack traces. We tail the file and return the first
  /// non-empty error envelope we can decode, or the final stderr/stack line
  /// if no JSON envelope is present.
  String? _readFirebaseDebugLogTail({int maxLines = 200}) {
    final File? log = _findFirebaseDebugLog();
    if (log == null) return null;
    try {
      final List<String> lines = log.readAsLinesSync();
      if (lines.isEmpty) return null;
      final int start = lines.length > maxLines ? lines.length - maxLines : 0;
      final List<String> tail = lines.sublist(start);

      // Pass 1: look for a structured `{"error":{…}}` envelope
      // (Firebase Management API response body).
      for (int i = tail.length - 1; i >= 0; i--) {
        final String line = tail[i];
        final int braceIndex = line.indexOf('{');
        if (braceIndex < 0) continue;
        final String body = line.substring(braceIndex);
        try {
          final dynamic decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>) {
            final dynamic err = decoded['error'];
            if (err is Map<String, dynamic>) {
              final String message = (err['message'] ?? '').toString().trim();
              final String status = (err['status'] ?? '').toString().trim();
              if (message.isNotEmpty || status.isNotEmpty) {
                return <String>[
                  if (status.isNotEmpty) status,
                  if (message.isNotEmpty) message,
                ].join(': ');
              }
            }
          }
        } catch (_) {
          // Not JSON, keep looking.
        }
      }

      // Pass 2: fall back to the final non-empty line.
      for (int i = tail.length - 1; i >= 0; i--) {
        final String line = tail[i].trim();
        if (line.isNotEmpty) return line;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Reasons a firebase command can fail in a way that the auto-recovery
  /// loop knows how to handle.
  ///
  /// Translates raw error text (whether from stderr, JSON `error`, or
  /// firebase-debug.log) into one of:
  ///
  ///   • [FirebaseFailureKind.serviceDisabled] — Firebase Management API not enabled. Auto-fix:
  ///                         run `gcloud services enable firebase.googleapis.com`,
  ///                         wait, retry.
  ///   • [FirebaseFailureKind.permissionDenied] — caller is missing IAM roles. Auto-fix: route
  ///                          through the IAM gate (or fall through with a
  ///                          clear message).
  ///   • [FirebaseFailureKind.transient] — propagation lag, 5xx, deadline, rate limit. Auto-fix:
  ///                   exponential backoff retry.
  ///   • [FirebaseFailureKind.unknown] — neither retryable nor classifiable. Surface verbatim.
  static FirebaseFailureKind _classifyFirebaseError(String raw) {
    final String lower = raw.toLowerCase();
    if (lower.isEmpty) return FirebaseFailureKind.unknown;

    if (lower.contains('service_disabled') ||
        lower.contains('has not been used') ||
        lower.contains('is not enabled') ||
        lower.contains('not been activated') ||
        lower.contains('firebase management api') ||
        lower.contains('firebase.googleapis.com')) {
      // Note: matching the API hostname catches the `firebase.googleapis.com is
      // not enabled` phrasing AND the more generic "API X has not been used"
      // template that lists the URL of the API.
      if (lower.contains('firebase.googleapis.com') ||
          lower.contains('firebase management') ||
          lower.contains('service_disabled')) {
        return FirebaseFailureKind.serviceDisabled;
      }
    }

    if (lower.contains('permission_denied') ||
        lower.contains('caller does not have permission') ||
        lower.contains('missing the required permission') ||
        lower.contains('does not have permission') ||
        lower.contains('forbidden')) {
      return FirebaseFailureKind.permissionDenied;
    }

    if (lower.contains('deadline_exceeded') ||
        lower.contains('unavailable') ||
        lower.contains('temporarily unavailable') ||
        lower.contains('try again later') ||
        lower.contains('etimedout') ||
        lower.contains('econnreset') ||
        lower.contains('socket hang up') ||
        lower.contains('503') ||
        lower.contains('502') ||
        lower.contains('500')) {
      return FirebaseFailureKind.transient;
    }

    return FirebaseFailureKind.unknown;
  }

  /// Public accessor for tests.
  static FirebaseFailureKind classifyFirebaseErrorForTest(String raw) =>
      _classifyFirebaseError(raw);

  /// Combine the JSON envelope error, stderr, and the tail of
  /// firebase-debug.log into one searchable error blob. Used by the
  /// auto-recovery classifier so a SERVICE_DISABLED only logged in
  /// firebase-debug.log still triggers the API-enable + retry path.
  String _collectFirebaseFailureContext(ProcessResult result) {
    final List<String> parts = <String>[];
    final Map<String, dynamic>? body = _parseFirebaseJson(result.stdout);
    if (body != null && body['error'] != null) {
      parts.add(body['error'].toString());
    }
    final String stderr = _stripAnsi(result.stderr).trim();
    if (stderr.isNotEmpty) parts.add(stderr);
    final String? logTail = _readFirebaseDebugLogTail();
    if (logTail != null && logTail.isNotEmpty) parts.add(logTail);
    return parts.join('\n');
  }

  /// Run a `firebase` subcommand (passed verbatim in [args]) with
  /// auto-recovery: parses the JSON response, classifies failures, and:
  ///
  ///   • retries transient errors with exponential backoff
  ///     (1s, 2s, 4s, 8s — capped at [maxAttempts]);
  ///   • on `SERVICE_DISABLED`, runs `gcloud services enable
  ///     firebase.googleapis.com`, waits for propagation, then retries;
  ///   • on `PERMISSION_DENIED`, retries up to [maxAttempts] times with
  ///     long waits (8s → 16s → 32s) to absorb IAM-binding propagation
  ///     lag. The orchestrator's IAM gate may have just granted
  ///     `roles/firebase.admin` and the binding can take 30-60s to
  ///     reach the API endpoint serving this request.
  ///   • on success, returns the raw [ProcessResult] for the caller to
  ///     parse via `_parseFirebaseJson`.
  ///
  /// `operationLabel` is shown in the verbose log so users understand
  /// which retry is in flight (e.g., "list Firebase web apps").
  Future<ProcessResult> _runFirebaseWithRecovery({
    required List<String> args,
    required String operationLabel,
    int maxAttempts = 4,
    bool enableApiOnServiceDisabled = true,
  }) async {
    int attempt = 0;
    bool triedEnableApi = false;
    bool didTryFirebaseLogout = false;
    int permissionDeniedRetries = 0;
    while (true) {
      attempt++;
      verbose('  [attempt $attempt/$maxAttempts] firebase ${args.join(' ')}');
      final ProcessResult result = await _runner.run(
        'firebase',
        args,
        environment: _authEnvironment,
        workingDirectory: config.outputDir,
      );

      final Map<String, dynamic>? body = _parseFirebaseJson(result.stdout);
      final bool jsonOk =
          body != null && body['status'] == 'success';
      if (jsonOk || (result.success && body == null)) {
        return result;
      }

      // Failed → classify against the *combined* error context so a
      // SERVICE_DISABLED only present in firebase-debug.log still triggers
      // the auto-enable path.
      final String context = _collectFirebaseFailureContext(result);
      final FirebaseFailureKind kind = _classifyFirebaseError(context);

      // Surface what we found before retrying so the user can see
      // progress. Print the FULL multi-line context indented so they
      // see the actual API response from firebase-debug.log instead of
      // just the unhelpful "See firebase-debug.log for more info."
      // first line.
      if (context.trim().isNotEmpty) {
        for (final String line in context.split('\n')) {
          if (line.trim().isEmpty) continue;
          verbose('  underlying error: ${line.trim()}');
        }
      }

      if (kind == FirebaseFailureKind.serviceDisabled &&
          enableApiOnServiceDisabled &&
          !triedEnableApi) {
        triedEnableApi = true;
        warn('Firebase Management API is not enabled — enabling now and retrying...');
        final bool enabled = await _enableSingleApi(
          'firebase.googleapis.com',
        );
        if (!enabled) {
          // Couldn't enable — fall through to the IAM-style failure.
          return result;
        }
        // Wait for propagation before retrying. The Service Usage API
        // typically takes 10-60s to propagate after enable.
        await _waitForFirebaseManagementApi();
        continue;
      }

      // PERMISSION_DENIED can come from THREE sources:
      //   1. firebase-tools is using a stale `firebase login` token from
      //      an account that doesn't have firebase.admin on this project,
      //      EVEN THOUGH GOOGLE_APPLICATION_CREDENTIALS is set. fix:
      //      `firebase logout` so the CLI falls back to ADC. Try this
      //      automatically on the first PERMISSION_DENIED and retry once.
      //   2. The SA genuinely lacks the role → retrying never works.
      //      Surface the failure with full credential diagnostics so the
      //      user can see the SA email vs firebase login email mismatch.
      //   3. The orchestrator just granted the role but the binding hasn't
      //      propagated yet → retrying with a wait succeeds. The IAM gate
      //      already polls up to 60s for IAM propagation, so by the time
      //      we get here propagation is done — a single 10s retry covers
      //      the edge case where step 5.4 finished granting <10s ago.
      if (kind == FirebaseFailureKind.permissionDenied) {
        // First defense: if firebase-tools has a stored login, try
        // logging out and retrying. firebase-tools prefers the stored
        // login over GOOGLE_APPLICATION_CREDENTIALS, which routinely
        // makes this whole step fail when the SA itself has the role
        // but a user account did `firebase login` once and forgot.
        if (!didTryFirebaseLogout) {
          didTryFirebaseLogout = true;
          final String? firebaseAccount = await getActiveFirebaseAccount();
          final String? saEmail = serviceAccountEmail;
          if (firebaseAccount != null &&
              saEmail != null &&
              firebaseAccount.toLowerCase() != saEmail.toLowerCase()) {
            warn(
              '$operationLabel hit PERMISSION_DENIED. Firebase CLI is '
              'logged in as $firebaseAccount which overrides the '
              'service-account auth Oracular configured. Logging out '
              'firebase-tools and retrying as service-account $saEmail...',
            );
            final ProcessResult logoutResult = await _runner.run(
              'firebase',
              <String>['logout', firebaseAccount],
            );
            if (!logoutResult.success) {
              warn('  firebase logout failed: '
                  '${_stripAnsi(logoutResult.stderr).trim()}. '
                  'Run `firebase logout --force` manually and re-run.');
            } else {
              continue; // Retry with no stored login → ADC takes over.
            }
          }
        }

        // Second defense: a single 10s wait covers any IAM-binding
        // propagation lag the orchestrator's gate didn't already absorb.
        if (permissionDeniedRetries < 1) {
          permissionDeniedRetries++;
          warn(
            '$operationLabel hit PERMISSION_DENIED — waiting 10s for '
            'IAM propagation, then retrying once before bailing out '
            'with credential diagnostics.',
          );
          await Future<void>.delayed(const Duration(seconds: 10));
          continue;
        }

        // Out of retries: dump full diagnostics and surface the failure.
        warn(
          '$operationLabel still PERMISSION_DENIED after retry. Dumping '
          'credential identities + firebase-debug.log so the actual '
          'cause is visible.',
        );
        await _logCredentialDiagnostics();
        return result;
      }

      if (kind == FirebaseFailureKind.transient && attempt < maxAttempts) {
        final int delayMs = 1000 * (1 << (attempt - 1));
        warn(
          '$operationLabel failed transiently — retrying in ${delayMs ~/ 1000}s '
          '(attempt $attempt/$maxAttempts).',
        );
        await Future<void>.delayed(Duration(milliseconds: delayMs));
        continue;
      }

      // Non-retryable, or out of retries → return so the caller can render
      // the structured error.
      return result;
    }
  }

  /// Enable a single Google API via gcloud. Idempotent on repeat calls.
  Future<bool> _enableSingleApi(String api) async {
    final String? projectId = config.firebaseProjectId;
    if (projectId == null) return false;
    verbose('  Enabling $api...');
    final ProcessResult r = await _runner.run(
      'gcloud',
      <String>['services', 'enable', api, '--project', projectId],
      environment: _authEnvironment,
    );
    if (!r.success) {
      warn('Could not enable $api: ${_stripAnsi(r.stderr).trim()}');
      return false;
    }
    return true;
  }

  /// Poll `firebase apps:list` until it returns a structured success or we
  /// hit the timeout. Used after enabling `firebase.googleapis.com` so
  /// downstream calls (`apps:list WEB`, `apps:create`) hit a propagated
  /// API instead of a SERVICE_DISABLED error.
  ///
  /// **Early-exit on PERMISSION_DENIED:** if the probe failure is an IAM
  /// problem (the SA lacks `firebase.apps.list`), waiting won't help —
  /// the role hasn't been granted, so we return `false` immediately so
  /// the caller can route through the IAM gate's auto-grant flow instead
  /// of burning 30+ seconds on a propagation lag that doesn't exist.
  ///
  /// Returns `true` once the API is queryable, `false` after [maxAttempts]
  /// exhausted retries OR on the first PERMISSION_DENIED.
  Future<bool> _waitForFirebaseManagementApi({
    int maxAttempts = 8,
  }) async {
    final String? projectId = config.firebaseProjectId;
    if (projectId == null) return false;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      // Probe with a cheap apps:list call (no platform filter, --json
      // means we get a structured envelope even on transient failures).
      final ProcessResult probe = await _runner.run(
        'firebase',
        <String>['apps:list', '--project', projectId, '--json'],
        environment: _authEnvironment,
        workingDirectory: config.outputDir,
      );
      final Map<String, dynamic>? body = _parseFirebaseJson(probe.stdout);
      if (body != null && body['status'] == 'success') {
        if (attempt > 1) {
          verbose('  Firebase Management API ready after $attempt probes.');
        }
        return true;
      }

      // Distinguish "not propagated yet" from "wrong IAM" — the former
      // benefits from waiting, the latter doesn't.
      final String context = _collectFirebaseFailureContext(probe);
      final FirebaseFailureKind kind = _classifyFirebaseError(context);
      if (kind == FirebaseFailureKind.permissionDenied) {
        verbose(
          '  Probe failed with PERMISSION_DENIED — the API is enabled but '
          'the active principal lacks firebase.apps.list. Returning early '
          'so the IAM gate can auto-grant roles/firebase.admin.',
        );
        return false;
      }

      // Capped exponential backoff: 1s, 2s, 4s, 8s, 8s, 8s, ...
      final int delaySec = attempt < 4 ? (1 << (attempt - 1)) : 8;
      verbose(
        '  Firebase Management API not ready yet (attempt $attempt/$maxAttempts) — '
        'waiting ${delaySec}s for propagation...',
      );
      await Future<void>.delayed(Duration(seconds: delaySec));
    }
    return false;
  }

  /// Login to Firebase CLI
  Future<bool> login() async {
    final Map<String, String>? authEnvironment = _authEnvironment;
    if (authEnvironment != null) {
      info('Using configured service account for Firebase CLI authentication.');
      final ProcessResult result = await _runner.run('firebase', <String>[
        'projects:list',
      ], environment: authEnvironment);
      return result.success;
    }

    info('Logging in to Firebase...');

    final int result = await _runner.runStreaming('firebase', <String>[
      'login',
    ], environment: authEnvironment);
    return result == 0;
  }

  /// Login to gcloud
  Future<bool> gcloudLogin() async {
    final String? serviceAccountPath = _resolvedServiceAccountPath;
    if (serviceAccountPath != null) {
      info('Authenticating gcloud with configured service account key...');
      final List<String> args = <String>[
        'auth',
        'activate-service-account',
        '--key-file',
        serviceAccountPath,
      ];

      final String? projectId = _requireFirebaseProjectId();
      if (projectId != null) {
        args.addAll(<String>['--project', projectId]);
      }

      final ProcessResult result = await _runner.run('gcloud', args);
      return result.success;
    }

    info('Logging in to Google Cloud...');

    final int result = await _runner.runStreaming('gcloud', <String>[
      'auth',
      'login',
    ]);
    return result == 0;
  }

  /// Configure FlutterFire for the project
  Future<bool> configureFlutterFire() async {
    if (config.firebaseProjectId == null) {
      error('Firebase project ID not set');
      return false;
    }

    // CLI templates: no Firebase client config needed
    if (config.template.isDartCli) {
      info('CLI templates do not require FlutterFire configuration');
      info('Use Firebase Admin SDK on the server side if needed');
      return true;
    }

    // Jaspr templates: configure Firebase JS SDK in index.html
    if (config.template.isJasprApp) {
      return await _configureFirebaseJsSdk();
    }

    // Flutter templates: use flutterfire configure
    return await _runFlutterFireConfigure(
      p.join(config.outputDir, config.appName),
      config.platforms,
    );
  }

  /// List Firebase apps using JSON output. Returns the parsed list, or `null`
  /// on failure with a structured, user-actionable warning.
  ///
  /// Uses [_runFirebaseWithRecovery] so transient errors are retried and a
  /// `SERVICE_DISABLED` (Firebase Management API not enabled) is auto-fixed
  /// in-line — callers don't need to bail out and ask the user to run
  /// `oracular deploy firebase-setup-full` manually.
  Future<List<Map<String, dynamic>>?> _listFirebaseApps({
    required String projectId,
    String? platform,
  }) async {
    final List<String> args = <String>[
      'apps:list',
      ?platform,
      '--project',
      projectId,
      '--json',
    ];

    final String label = platform != null
        ? 'list Firebase $platform apps'
        : 'list Firebase apps';

    final ProcessResult result = await _runFirebaseWithRecovery(
      args: args,
      operationLabel: label,
    );

    final Map<String, dynamic>? body = _parseFirebaseJson(result.stdout);
    if (body == null) {
      final String detail = _collectFirebaseFailureContext(result);
      warn(
        'Could not parse firebase apps:list output for project $projectId.'
        '${detail.isNotEmpty ? '\n  Underlying error: ${detail.split('\n').first.trim()}' : ''}',
      );
      return null;
    }

    if (body['status'] != 'success') {
      final String detail = _collectFirebaseFailureContext(result);
      final FirebaseFailureKind kind = _classifyFirebaseError(detail);
      warn(
        'Firebase apps:list failed for project $projectId: '
        '${body['error'] ?? 'unknown error'}'
        '${detail.isNotEmpty ? '\n  Root cause: ${detail.split('\n').first.trim()}' : ''}',
      );
      if (kind == FirebaseFailureKind.serviceDisabled) {
        warn(
          '  Hint: Firebase Management API still reports SERVICE_DISABLED '
          'after auto-enable + propagation wait. This usually means the '
          'service account is missing the `roles/serviceusage.serviceUsageAdmin` '
          'role on project $projectId. Add it once and re-run.',
        );
      } else if (kind == FirebaseFailureKind.permissionDenied) {
        warn(
          '  Hint: the active credential lacks `firebase.apps.list`. '
          'Grant `roles/firebase.viewer` (or the firebase-setup-full IAM '
          'bundle) on project $projectId and re-run.',
        );
      }
      return null;
    }

    final dynamic resultData = body['result'];
    if (resultData is! List) {
      return <Map<String, dynamic>>[];
    }

    return resultData
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  /// Create a Firebase app using --json so we get structured success/error
  /// responses instead of fighting with spinner output.
  ///
  /// Uses [_runFirebaseWithRecovery] so transient errors are retried and
  /// `SERVICE_DISABLED` is auto-recovered before failing the step.
  Future<Map<String, dynamic>?> _createFirebaseApp({
    required String projectId,
    required String platform,
    required String displayName,
    String? androidPackage,
    String? iosBundleId,
  }) async {
    final List<String> args = <String>[
      'apps:create',
      platform.toUpperCase(),
      displayName,
      '--project',
      projectId,
      '--json',
    ];

    if (platform.toLowerCase() == 'android' && androidPackage != null) {
      args.addAll(<String>['--package-name', androidPackage]);
    }
    if (platform.toLowerCase() == 'ios' && iosBundleId != null) {
      args.addAll(<String>['--bundle-id', iosBundleId]);
    }

    final ProcessResult result = await _runFirebaseWithRecovery(
      args: args,
      operationLabel: 'create Firebase $platform app "$displayName"',
    );

    final Map<String, dynamic>? body = _parseFirebaseJson(result.stdout);
    if (body == null) {
      final String detail = _collectFirebaseFailureContext(result);
      warn(
        'Could not parse firebase apps:create output for $platform app '
        '"$displayName".'
        '${detail.isNotEmpty ? '\n  Underlying error: ${detail.split('\n').first.trim()}' : ''}',
      );
      return null;
    }

    if (body['status'] != 'success') {
      final dynamic err = body['error'];
      final String detail = _collectFirebaseFailureContext(result);
      warn(
        'Firebase $platform app creation failed: ${err ?? 'unknown error'}'
        '${detail.isNotEmpty ? '\n  Root cause: ${detail.split('\n').first.trim()}' : ''}',
      );
      return null;
    }

    final dynamic resultData = body['result'];
    if (resultData is Map<String, dynamic>) {
      return resultData;
    }
    return null;
  }

  /// Ensure Firebase apps exist for the specified platforms
  /// FlutterFire CLI crashes with RangeError if no apps exist
  /// [appDisplayName] is the name to use for the Firebase app (e.g., my_app_mobile)
  Future<void> _ensureFirebaseAppsExist(
    List<String> platforms,
    String androidPackage,
    String iosBundleId, {
    String? appDisplayName,
  }) async {
    final String? projectId = _requireFirebaseProjectId();
    if (projectId == null) return;

    // Use provided display name or default to config.appName
    final String displayName = appDisplayName ?? config.appName;

    verbose('  Checking Firebase apps for project: $projectId');
    verbose('  App display name: $displayName');
    verbose('  Android package: $androidPackage');
    verbose('  iOS bundle ID: $iosBundleId');

    final List<Map<String, dynamic>>? existing = await _listFirebaseApps(
      projectId: projectId,
    );
    if (existing == null) {
      warn(
        '  Skipping app creation because the project app list could not be retrieved.',
      );
      return;
    }

    String platformOf(Map<String, dynamic> app) {
      final dynamic platform = app['platform'];
      return platform is String ? platform.toUpperCase() : '';
    }

    String? packageOf(Map<String, dynamic> app) {
      final dynamic value = app['packageName'];
      return value is String ? value : null;
    }

    String? bundleOf(Map<String, dynamic> app) {
      final dynamic value = app['bundleId'];
      return value is String ? value : null;
    }

    for (final String platform in platforms) {
      final String upper = platform.toUpperCase();
      bool appExists = false;

      if (upper == 'ANDROID') {
        appExists = existing.any(
          (Map<String, dynamic> app) =>
              platformOf(app) == 'ANDROID' &&
              packageOf(app) == androidPackage,
        );
      } else if (upper == 'IOS') {
        appExists = existing.any(
          (Map<String, dynamic> app) =>
              platformOf(app) == 'IOS' && bundleOf(app) == iosBundleId,
        );
      } else if (upper == 'WEB') {
        appExists = existing.any(
          (Map<String, dynamic> app) => platformOf(app) == 'WEB',
        );
      }

      if (appExists) {
        verbose('  Firebase $platform app already exists');
        continue;
      }

      info('Creating Firebase $platform app...');

      final Map<String, dynamic>? created = await _createFirebaseApp(
        projectId: projectId,
        platform: platform,
        displayName: '${displayName}_$platform',
        androidPackage: upper == 'ANDROID' ? androidPackage : null,
        iosBundleId: upper == 'IOS' ? iosBundleId : null,
      );

      if (created != null) {
        success('  Created Firebase $platform app');
      }
    }
  }

  /// Run flutterfire configure for a Flutter project
  /// [subprojectName] is used for subprojects where the subproject has a different name
  Future<bool> _runFlutterFireConfigure(
    String projectPath,
    List<String> platforms, {
    String? subprojectName,
  }) async {
    info('Configuring FlutterFire...');
    verbose('  Project path: $projectPath');
    verbose('  Firebase project: ${config.firebaseProjectId}');
    verbose('  Platforms: ${platforms.join(", ")}');

    // Check if the directory exists
    if (!Directory(projectPath).existsSync()) {
      error('Project directory does not exist: $projectPath');
      return false;
    }

    // Check for pubspec.yaml
    final File pubspec = File(p.join(projectPath, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      error('pubspec.yaml not found in: $projectPath');
      return false;
    }
    verbose('  pubspec.yaml found');

    // Check pubspec content for Flutter SDK
    final String pubspecContent = await pubspec.readAsString();
    if (!pubspecContent.contains('flutter:')) {
      error(
        'This does not appear to be a Flutter project (no flutter: in pubspec.yaml)',
      );
      verbose('  pubspec.yaml content preview:');
      verbose(
        '  ${pubspecContent.substring(0, pubspecContent.length > 200 ? 200 : pubspecContent.length)}...',
      );
      return false;
    }
    verbose('  Flutter SDK dependency found');

    // Try to extract package identifiers to avoid interactive prompts
    final String? androidPackage = await _extractAndroidPackageName(
      projectPath,
    );
    final String? iosBundleId = await _extractIosBundleId(projectPath);

    // Construct default identifiers if not extracted
    // Use subprojectName for subprojects (e.g., my_app_mobile)
    final String projectName = subprojectName ?? config.appName;
    final String defaultAndroidPackage = '${config.orgDomain}.$projectName';
    // iOS bundle IDs cannot contain underscores - convert to camelCase
    final String iosSafeProjectName = _convertToCamelCase(projectName);
    final String defaultIosBundleId = '${config.orgDomain}.$iosSafeProjectName';
    final String effectiveAndroidPackage =
        androidPackage ?? defaultAndroidPackage;
    final String effectiveIosBundleId = iosBundleId ?? defaultIosBundleId;

    // Ensure Firebase apps exist before running flutterfire configure
    // FlutterFire CLI crashes with RangeError if no apps exist for the platforms
    await _ensureFirebaseAppsExist(
      platforms,
      effectiveAndroidPackage,
      effectiveIosBundleId,
      appDisplayName: projectName,
    );

    // Wait a moment for Firebase to propagate app creation
    await Future<void>.delayed(const Duration(seconds: 2));

    final List<String> args = <String>[
      'configure',
      '--project',
      config.firebaseProjectId!,
      '--yes', // Skip confirmation prompts to avoid terminal interaction issues
    ];

    // Add platforms
    for (final String platform in platforms) {
      args.add('--platforms');
      args.add(platform);
    }

    // Always provide package name/bundle ID to avoid FlutterFire interactive prompts
    if (platforms.contains('android')) {
      args.addAll(<String>['--android-package-name', effectiveAndroidPackage]);
      verbose('  Android package: $effectiveAndroidPackage');
    }

    if (platforms.contains('ios')) {
      args.addAll(<String>['--ios-bundle-id', effectiveIosBundleId]);
      verbose('  iOS bundle ID: $effectiveIosBundleId');
    }

    verbose('  Running: flutterfire ${args.join(" ")}');

    final ProcessResult? result = await _runner.runWithRetry(
      'flutterfire',
      args,
      workingDirectory: projectPath,
      environment: _authEnvironment,
      operationName: 'FlutterFire configure',
    );

    if (result == null) {
      error('FlutterFire command returned null result');
      return false;
    }

    if (!result.success) {
      error('FlutterFire configure failed');
      if (result.stdout.isNotEmpty) {
        verbose('  stdout: ${result.stdout}');
      }
      if (result.stderr.isNotEmpty) {
        verbose('  stderr: ${result.stderr}');
      }
      verbose('  Exit code: ${result.exitCode}');
    }

    return result.success;
  }

  /// Deploy Firestore rules
  Future<bool> deployFirestore() async {
    info('Deploying Firestore rules...');
    final String? projectId = _requireFirebaseProjectId();
    if (projectId == null) {
      return false;
    }

    final ProcessResult? result = await _runner.runWithRetry(
      'firebase',
      <String>[
        'deploy',
        '--only',
        'firestore:rules,firestore:indexes',
        '--project',
        projectId,
      ],
      workingDirectory: config.outputDir,
      environment: _authEnvironment,
      operationName: 'Deploy Firestore',
    );

    return result != null && result.success;
  }

  bool _isStorageNotInitialized(String output) {
    final String lower = output.toLowerCase();
    return lower.contains('firebase storage has not been set up');
  }

  /// Deploy Storage rules
  Future<bool> deployStorage({bool allowNotInitialized = false}) async {
    info('Deploying Storage rules...');
    final String? projectId = _requireFirebaseProjectId();
    if (projectId == null) {
      return false;
    }

    final List<String> args = <String>[
      'deploy',
      '--only',
      'storage',
      '--project',
      projectId,
    ];

    final ProcessResult firstAttempt = await _runner.run(
      'firebase',
      args,
      workingDirectory: config.outputDir,
      environment: _authEnvironment,
    );

    if (firstAttempt.success) {
      return true;
    }

    final String firstOutput = '${firstAttempt.stdout}\n${firstAttempt.stderr}'
        .trim();
    if (_isStorageNotInitialized(firstOutput)) {
      // Try to auto-create the default bucket via FirebaseInitializer before
      // falling back to the console hand-off.
      info(
        'Firebase Storage default bucket appears uninitialized; attempting to create it automatically...',
      );
      final FirebaseInitializer initializer = FirebaseInitializer(
        projectId,
        runner: _runner,
      );
      final StorageInitResult init = await initializer.ensureStorageBucket();
      if (init.success) {
        // Retry deploy now that the bucket exists.
        final ProcessResult retry = await _runner.run(
          'firebase',
          args,
          workingDirectory: config.outputDir,
          environment: _authEnvironment,
        );
        if (retry.success) {
          return true;
        }
        final String retryOutput = '${retry.stdout}\n${retry.stderr}'.trim();
        if (!_isStorageNotInitialized(retryOutput)) {
          // Fall through to retry-with-prompt path below.
          return _retryStorageDeploy(args);
        }
      } else if (init.message.isNotEmpty) {
        warn(init.message);
      }

      warn(
        'Firebase Storage is not initialized for project $projectId. '
        'Open ${FirebaseInitializer.getStartedUrl(projectId)} and click "Get Started".',
      );
      return allowNotInitialized;
    }

    return _retryStorageDeploy(args);
  }

  Future<bool> _retryStorageDeploy(List<String> args) async {
    final ProcessResult? result = await _runner.runWithRetry(
      'firebase',
      args,
      workingDirectory: config.outputDir,
      environment: _authEnvironment,
      operationName: 'Deploy Storage',
    );

    return result != null && result.success;
  }

  /// Self-heal `artifact_gen` / `fire_crud_gen` shims for an existing Jaspr
  /// project before running `jaspr build`.
  ///
  /// **Why this exists**
  ///
  /// Older Oracular versions did not vendor `artifact_gen` / `fire_crud_gen`
  /// into `.oracular_deps/` (only `jpatch` was vendored). Projects scaffolded
  /// before that change can fail `jaspr build` with cryptic
  /// "[CLI] [CRITICAL] Failed to connect to the build daemon" errors that
  /// trace back to a `pub get` resolution conflict between:
  ///
  ///   • `jaspr_builder ^0.23.x` → requires `analyzer ^10.0.0`
  ///   • `artifact_gen ^1.x` / `fire_crud_gen ^1.x` (auto-applied through
  ///     the upstream `artifact` / `fire_crud` packages' `build.yaml`) →
  ///     require `analyzer ^8.0.0`
  ///
  /// This method runs before every Jaspr build to:
  ///   1. Detect whether the project is at risk (Jaspr template +
  ///      `arcane_models` linked).
  ///   2. Copy `templates/_vendor/artifact_gen` and
  ///      `templates/_vendor/fire_crud_gen` into the project's
  ///      `.oracular_deps/` if missing.
  ///   3. Append `dependency_overrides` entries for both shims to the
  ///      web app's `pubspec.yaml` if missing.
  ///   4. Re-run `dart pub get` so the next `jaspr build` call sees the
  ///      patched lockfile.
  ///
  /// The shims provide no-op `Builder` instances that produce zero output,
  /// so build_runner can satisfy `auto_apply: dependents` without dragging
  /// analyzer 8 into the resolution. Real model generation still happens
  /// in the dedicated models package (which does NOT depend on
  /// `jaspr_builder`).
  ///
  /// Idempotent: shims are only copied / overrides only injected / pub get
  /// only re-run when at least one piece is missing. No-op on fully
  /// vendored projects.
  Future<void> _ensureJasprBuilderShims(String projectPath) async {
    // Only meaningful for Jaspr targets that depend on arcane_models.
    if (!config.template.isJasprApp) return;
    if (!config.createModels) return;

    final File pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) return;

    final String pubspecText = await pubspecFile.readAsString();
    // Skip projects that don't actually depend on arcane_models — vendoring
    // the shims would just add noise.
    final RegExp modelsRef = RegExp(
      '^\\s*${RegExp.escape(config.modelsPackageName)}:\\s*\$',
      multiLine: true,
    );
    if (!modelsRef.hasMatch(pubspecText)) return;

    // Locate the Oracular templates root (relative to this CLI's install
    // location). When running `dart pub global activate . --source=path`,
    // the templates directory lives next to lib/ in the package. When
    // running from a `pub global` install, we resolve via Platform.script.
    final String? templatesBasePath = _findTemplatesBasePath();
    if (templatesBasePath == null) {
      verbose(
        '[shim self-heal] Could not locate Oracular templates directory; '
        'skipping artifact_gen / fire_crud_gen vendoring. Build may fail '
        'with analyzer version conflict.',
      );
      return;
    }

    final Directory depsRoot = Directory(
      p.join(config.outputDir, '.oracular_deps'),
    );
    bool changed = false;
    const List<String> shimNames = <String>['artifact_gen', 'fire_crud_gen'];

    for (final String shimName in shimNames) {
      final Directory shimSource = Directory(
        p.join(templatesBasePath, '_vendor', shimName),
      );
      final Directory shimTarget = Directory(p.join(depsRoot.path, shimName));

      if (!shimTarget.existsSync()) {
        if (!shimSource.existsSync()) {
          verbose(
            '[shim self-heal] Source shim missing at ${shimSource.path}; '
            'cannot vendor $shimName.',
          );
          continue;
        }
        await shimTarget.create(recursive: true);
        await _copyShimDirectory(shimSource, shimTarget);
        verbose('[shim self-heal] Vendored $shimName -> ${shimTarget.path}');
        changed = true;
      }

      final String overrideMarker = '\n  $shimName:\n';
      final String overrideRefPath = '../.oracular_deps/$shimName';
      if (!pubspecText.contains(overrideMarker) ||
          !pubspecText.contains(overrideRefPath)) {
        await _addShimOverrideToPubspec(
          pubspecFile,
          packageName: shimName,
          relativeShimPath: overrideRefPath,
        );
        changed = true;
      }
    }

    if (!changed) return;

    info(
      'Self-healed missing Jaspr builder shims '
      '(artifact_gen / fire_crud_gen). Refreshing dependencies...',
    );
    final ProcessResult pubGetResult = await _runner.run(
      'dart',
      <String>['pub', 'get'],
      workingDirectory: projectPath,
    );
    if (!pubGetResult.success) {
      warn(
        'pub get after shim self-heal failed; jaspr build may still error. '
        'stderr: ${pubGetResult.stderr.trim()}',
      );
    }
  }

  /// Resolve the on-disk path to Oracular's `templates/` directory in a
  /// way that works for both:
  ///   • `dart pub global activate . --source=path`  (template lives at
  ///     `<repo>/templates`)
  ///   • A future `pub.dev` install (template would ship inside the
  ///     activated package's directory under `.pub-cache`).
  String? _findTemplatesBasePath() {
    final List<String> candidates = <String>[];

    // Walk upward from this file's compiled location.
    try {
      final String scriptPath = Platform.script.toFilePath();
      final Directory startDir = File(scriptPath).existsSync()
          ? File(scriptPath).parent
          : Directory(scriptPath);
      Directory? cursor = startDir;
      for (int i = 0; i < 8 && cursor != null; i++) {
        candidates.add(p.join(cursor.path, 'templates'));
        candidates.add(p.join(cursor.path, '..', 'templates'));
        final Directory parent = cursor.parent;
        if (parent.path == cursor.path) break;
        cursor = parent;
      }
    } catch (_) {
      // Ignore — fall through to other candidates.
    }

    // Resolve relative to the current working directory (catches the
    // common `dart run bin/main.dart` from the repo root case).
    candidates.add(p.join(Directory.current.path, 'templates'));
    candidates.add(p.join(Directory.current.path, '..', 'templates'));

    for (final String candidate in candidates) {
      final Directory dir = Directory(p.normalize(candidate));
      if (dir.existsSync() &&
          Directory(p.join(dir.path, '_vendor')).existsSync()) {
        return dir.path;
      }
    }

    return null;
  }

  Future<void> _copyShimDirectory(Directory source, Directory target) async {
    if (!target.existsSync()) {
      await target.create(recursive: true);
    }
    await for (final FileSystemEntity entity in source.list(recursive: false)) {
      final String name = p.basename(entity.path);
      final String destPath = p.join(target.path, name);
      if (entity is Directory) {
        await _copyShimDirectory(entity, Directory(destPath));
      } else if (entity is File) {
        await entity.copy(destPath);
      }
    }
  }

  /// Append a `dependency_overrides` entry for [packageName] -> [relativeShimPath]
  /// to a pubspec, idempotently. Mirrors `PlaceholderReplacer.addVendoredOverride`
  /// but lives here so the build self-heal path can run without a full
  /// scaffold pipeline being constructed.
  Future<void> _addShimOverrideToPubspec(
    File pubspecFile, {
    required String packageName,
    required String relativeShimPath,
  }) async {
    String content = await pubspecFile.readAsString();
    final List<String> lines = content.split('\n');
    bool inOverrides = false;
    final RegExp packageEntry = RegExp(
      '^\\s+${RegExp.escape(packageName)}:',
    );
    for (final String line in lines) {
      if (line.trimLeft().startsWith('#')) continue;
      if (RegExp(r'^dependency_overrides:\s*$').hasMatch(line)) {
        inOverrides = true;
        continue;
      }
      if (inOverrides && RegExp(r'^[a-zA-Z_]').hasMatch(line)) {
        inOverrides = false;
      }
      if (inOverrides && packageEntry.hasMatch(line)) {
        return;
      }
    }

    final String entry =
        '  $packageName:\n'
        '    path: $relativeShimPath\n';

    final RegExp header = RegExp(
      r'^dependency_overrides:\s*$',
      multiLine: true,
    );
    final RegExpMatch? match = header.firstMatch(content);
    if (match != null) {
      final int pos = match.end;
      content = '${content.substring(0, pos)}\n$entry${content.substring(pos)}';
    } else {
      if (!content.endsWith('\n')) content += '\n';
      content += '\ndependency_overrides:\n$entry';
    }
    await pubspecFile.writeAsString(content);
    verbose(
      '[shim self-heal] Injected $packageName override into '
      '${p.basename(pubspecFile.path)}',
    );
  }

  /// Build web app
  Future<bool> buildWeb() async {
    if (!supportsWebHosting()) {
      error(
        'Web hosting is not available because this project was created without web support.',
      );
      return false;
    }

    // Determine project path based on template type
    final String projectPath = config.template.isJasprApp
        ? p.join(config.outputDir, config.webPackageName)
        : p.join(config.outputDir, config.appName);

    info('Building web app...');

    // Jaspr templates: use jaspr build
    if (config.template.isJasprApp) {
      // Self-heal builder shims for projects scaffolded before
      // Oracular started vendoring artifact_gen / fire_crud_gen. The web
      // app cannot resolve when both jaspr_builder (analyzer ^10.0.0) and
      // the published artifact_gen / fire_crud_gen (analyzer ^8.0.0) are
      // pulled in — even just to satisfy `auto_apply: dependents` in the
      // upstream artifact / fire_crud build.yaml. See
      // [_ensureJasprBuilderShims] for the full rationale.
      await _ensureJasprBuilderShims(projectPath);

      final ProcessResult? result = await _runner.runWithRetry(
        'jaspr',
        <String>['build'],
        workingDirectory: projectPath,
        operationName: 'Jaspr build',
      );
      return result != null && result.success;
    }

    final Directory webDir = Directory(p.join(projectPath, 'web'));
    if (!webDir.existsSync()) {
      error('Web platform files were not found in: ${webDir.path}');
      info('Enable web support in the app directory with:');
      info('  flutter create --platforms=web .');
      return false;
    }

    // Flutter templates: use flutter build web
    final ProcessResult? result = await _runner.runWithRetry(
      'flutter',
      <String>['build', 'web', '--release'],
      workingDirectory: projectPath,
      operationName: 'Flutter build web',
    );

    return result != null && result.success;
  }

  /// Deploy to Firebase Hosting (release target)
  Future<bool> deployHostingRelease() async {
    info('Deploying to Firebase Hosting (release)...');
    final String? projectId = _requireFirebaseProjectId();
    if (projectId == null) {
      return false;
    }

    final ProcessResult? result = await _runner.runWithRetry(
      'firebase',
      <String>['deploy', '--only', 'hosting:release', '--project', projectId],
      workingDirectory: config.outputDir,
      environment: _authEnvironment,
      operationName: 'Deploy Hosting (release)',
    );

    if (result != null && result.success) {
      return true;
    }

    // Fallback for projects that only use a default hosting target.
    warn(
      'Release hosting target deploy failed; retrying default hosting deploy.',
    );
    final ProcessResult? fallbackResult = await _runner.runWithRetry(
      'firebase',
      <String>['deploy', '--only', 'hosting', '--project', projectId],
      workingDirectory: config.outputDir,
      environment: _authEnvironment,
      operationName: 'Deploy Hosting (default)',
    );

    return fallbackResult != null && fallbackResult.success;
  }

  /// Deploy to Firebase Hosting (beta target)
  Future<bool> deployHostingBeta() async {
    info('Deploying to Firebase Hosting (beta)...');
    final String? projectId = _requireFirebaseProjectId();
    if (projectId == null) {
      return false;
    }

    final ProcessResult? result = await _runner.runWithRetry(
      'firebase',
      <String>['deploy', '--only', 'hosting:beta', '--project', projectId],
      workingDirectory: config.outputDir,
      environment: _authEnvironment,
      operationName: 'Deploy Hosting (beta)',
    );

    return result != null && result.success;
  }

  /// Deploy all Firebase resources
  Future<bool> deployAll() async {
    info('Deploying all Firebase resources...');
    bool allSucceeded = true;

    // Deploy in order
    if (!await deployFirestore()) {
      warn('Firestore deployment failed');
      allSucceeded = false;
    }

    if (!await deployStorage(allowNotInitialized: true)) {
      warn('Storage deployment failed');
      allSucceeded = false;
    }

    if (supportsWebHosting()) {
      if (!await buildWeb()) {
        error('Web build failed');
        return false;
      }

      if (!await deployHostingRelease()) {
        warn('Hosting deployment failed');
        allSucceeded = false;
      }
    } else {
      warn('Skipping Hosting deploy because web platform is not enabled.');
    }

    if (allSucceeded) {
      success('Firebase deployment complete');
    } else {
      warn('Firebase deployment completed with failures.');
    }
    return allSucceeded;
  }

  /// Whether this project supports web hosting deployment.
  bool supportsWebHosting() {
    return config.template.isJasprApp ||
        (config.template.isFlutterApp && config.platforms.contains('web'));
  }

  /// Enable Google Cloud APIs needed for deployment
  Future<bool> enableGoogleApis() async {
    if (config.firebaseProjectId == null) {
      error('Firebase project ID not set');
      return false;
    }

    info('Enabling Google Cloud APIs...');

    bool allOk = true;

    // Enable Artifact Registry
    ProcessResult result = await _runner.run('gcloud', <String>[
      'services',
      'enable',
      'artifactregistry.googleapis.com',
      '--project',
      config.firebaseProjectId!,
    ], environment: _authEnvironment);

    if (!result.success) {
      warn(
        'Failed to enable Artifact Registry API: ${_stripAnsi(result.stderr).trim()}',
      );
      allOk = false;
    }

    // Enable Cloud Run
    result = await _runner.run('gcloud', <String>[
      'services',
      'enable',
      'run.googleapis.com',
      '--project',
      config.firebaseProjectId!,
    ], environment: _authEnvironment);

    if (!result.success) {
      warn(
        'Failed to enable Cloud Run API: ${_stripAnsi(result.stderr).trim()}',
      );
      allOk = false;
    }

    return allOk;
  }

  /// Enable the core Firebase APIs needed by every Firebase-enabled project.
  ///
  /// We enable these BEFORE running any `gcloud firestore`, `gcloud storage`,
  /// or `firebase apps:list` calls, because the most common cause of those
  /// commands failing on a fresh project is that the underlying API has
  /// never been enabled. Returns the list of APIs that failed to enable
  /// (empty when everything succeeded).
  ///
  /// After enabling, this method waits (probes) for the Firebase Management
  /// API to be queryable from the firebase CLI. This closes the propagation
  /// gap between `gcloud services enable` returning success and the API
  /// actually answering `firebase apps:list` calls — without this gate, the
  /// next step (Configure Firebase client wiring) will hit SERVICE_DISABLED
  /// on the very first call.
  ///
  /// All these APIs are available on Spark — Blaze is only required for
  /// actually using the bucket / database beyond the free quota, not for
  /// enabling the API itself.
  Future<List<String>> enableFirebaseCoreApis() async {
    if (config.firebaseProjectId == null) {
      error('Firebase project ID not set');
      return const <String>['*'];
    }

    info('Enabling core Firebase APIs...');

    const List<String> apis = <String>[
      'firebase.googleapis.com', // Firebase Management API (apps:list, etc.)
      'firestore.googleapis.com', // Cloud Firestore
      'firebasestorage.googleapis.com', // Firebase Storage
      'firebasehosting.googleapis.com', // Firebase Hosting
      'identitytoolkit.googleapis.com', // Firebase Auth
      'serviceusage.googleapis.com', // self-referential, needed for batch enable
    ];

    final List<String> failed = <String>[];
    for (final String api in apis) {
      verbose('  Enabling $api...');
      final ProcessResult result = await _runner.run(
        'gcloud',
        <String>[
          'services',
          'enable',
          api,
          '--project',
          config.firebaseProjectId!,
        ],
        environment: _authEnvironment,
      );

      if (!result.success) {
        final String detail = _stripAnsi(result.stderr).trim();
        warn('Failed to enable $api: ${detail.isEmpty ? 'unknown error' : detail}');
        failed.add(api);
      }
    }

    // Even when `gcloud services enable` returns success, the API can take
    // 10-60s to propagate before `firebase apps:list` actually works.
    // Wait here so step 5.5 (Configure Firebase client wiring) doesn't hit
    // SERVICE_DISABLED on its very first call.
    if (!failed.contains('firebase.googleapis.com')) {
      info('Waiting for Firebase Management API to become queryable...');
      final bool ready = await _waitForFirebaseManagementApi();
      if (!ready) {
        warn(
          'Firebase Management API enabled but did not become queryable '
          'within the propagation window. Subsequent steps will retry on '
          'demand, but you may want to wait a minute and re-run if they '
          'fail.',
        );
        // We don't add it back to `failed` — the API IS enabled, just not
        // visible yet. The auto-recovery loop in `_runFirebaseWithRecovery`
        // will continue retrying as needed.
      }
    }

    if (failed.isEmpty) {
      success('All core Firebase APIs are enabled.');
    }
    return failed;
  }

  /// Extract Android package name from build.gradle or AndroidManifest.xml
  Future<String?> _extractAndroidPackageName(String projectPath) async {
    // Try build.gradle.kts first (newer format)
    final File buildGradleKts = File(
      p.join(projectPath, 'android', 'app', 'build.gradle.kts'),
    );
    if (buildGradleKts.existsSync()) {
      final String content = await buildGradleKts.readAsString();
      // Look for: namespace = "com.example.app" or applicationId = "com.example.app"
      final RegExp namespaceRegex = RegExp(r'namespace\s*=\s*"([^"]+)"');
      final RegExp appIdRegex = RegExp(r'applicationId\s*=\s*"([^"]+)"');

      final RegExpMatch? namespaceMatch = namespaceRegex.firstMatch(content);
      if (namespaceMatch != null) {
        return namespaceMatch.group(1);
      }

      final RegExpMatch? appIdMatch = appIdRegex.firstMatch(content);
      if (appIdMatch != null) {
        return appIdMatch.group(1);
      }
    }

    // Try build.gradle (older format)
    final File buildGradle = File(
      p.join(projectPath, 'android', 'app', 'build.gradle'),
    );
    if (buildGradle.existsSync()) {
      final String content = await buildGradle.readAsString();
      // Look for: namespace "com.example.app" or applicationId "com.example.app"
      final RegExp namespaceRegex = RegExp(r'namespace\s+"([^"]+)"');
      final RegExp appIdRegex = RegExp(r'applicationId\s+"([^"]+)"');

      final RegExpMatch? namespaceMatch = namespaceRegex.firstMatch(content);
      if (namespaceMatch != null) {
        return namespaceMatch.group(1);
      }

      final RegExpMatch? appIdMatch = appIdRegex.firstMatch(content);
      if (appIdMatch != null) {
        return appIdMatch.group(1);
      }
    }

    // Fallback: try AndroidManifest.xml
    final File manifest = File(
      p.join(
        projectPath,
        'android',
        'app',
        'src',
        'main',
        'AndroidManifest.xml',
      ),
    );
    if (manifest.existsSync()) {
      final String content = await manifest.readAsString();
      final RegExp packageRegex = RegExp(r'package="([^"]+)"');
      final RegExpMatch? match = packageRegex.firstMatch(content);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  /// Extract iOS bundle identifier from project.pbxproj or Info.plist
  Future<String?> _extractIosBundleId(String projectPath) async {
    // Try project.pbxproj
    final File pbxproj = File(
      p.join(projectPath, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
    );
    if (pbxproj.existsSync()) {
      final String content = await pbxproj.readAsString();
      // Look for: PRODUCT_BUNDLE_IDENTIFIER = com.example.app;
      final RegExp bundleIdRegex = RegExp(
        r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);',
      );
      final RegExpMatch? match = bundleIdRegex.firstMatch(content);
      if (match != null) {
        String bundleId = match.group(1)?.trim() ?? '';
        // Remove quotes if present
        bundleId = bundleId.replaceAll('"', '');
        // Skip if it's a variable reference like $(...)
        if (!bundleId.contains(r'$(')) {
          return bundleId;
        }
      }
    }

    return null;
  }

  /// Convert snake_case to camelCase for iOS bundle IDs
  /// iOS bundle IDs cannot contain underscores
  /// e.g., my_app_mobile -> myAppMobile
  String _convertToCamelCase(String input) {
    if (!input.contains('_')) return input;

    final List<String> parts = input.split('_');
    final StringBuffer result = StringBuffer(parts.first);

    for (int i = 1; i < parts.length; i++) {
      final String part = parts[i];
      if (part.isNotEmpty) {
        result.write(part[0].toUpperCase());
        if (part.length > 1) {
          result.write(part.substring(1));
        }
      }
    }

    return result.toString();
  }

  /// Configure Firebase JS SDK for Jaspr web apps
  /// Creates a Firebase web app and updates index.html with the config
  Future<bool> _configureFirebaseJsSdk() async {
    info('Configuring Firebase JS SDK for Jaspr...');

    final String? projectId = _requireFirebaseProjectId();
    if (projectId == null) {
      return false;
    }

    final String projectPath = p.join(config.outputDir, config.webPackageName);
    final String indexPath = p.join(projectPath, 'web', 'index.html');

    // Check if index.html exists
    final File indexFile = File(indexPath);
    if (!indexFile.existsSync()) {
      error('index.html not found at: $indexPath');
      info('Expected the Jaspr web project at: $projectPath');
      return false;
    }

    // Find or create the Firebase web app for this project
    final String desiredAppName = '${config.webPackageName}_web';
    final Map<String, dynamic>? webApp = await _findOrCreateWebApp(
      projectId: projectId,
      desiredDisplayName: desiredAppName,
    );

    if (webApp == null) {
      // Errors already logged
      return false;
    }

    final dynamic appIdRaw = webApp['appId'];
    if (appIdRaw is! String || appIdRaw.isEmpty) {
      error('Firebase web app missing appId in response');
      verbose('  webApp payload: ${jsonEncode(webApp)}');
      return false;
    }

    // Get the Firebase web SDK config using the JSON output of apps:sdkconfig
    final Map<String, String>? firebaseConfig = await _getFirebaseWebConfig(
      projectId: projectId,
      appId: appIdRaw,
    );
    if (firebaseConfig == null) {
      error('Failed to get Firebase web config');
      return false;
    }

    // Update index.html with the Firebase config
    String indexContent = await indexFile.readAsString();

    final String firebaseScript =
        '''
  <script src="https://www.gstatic.com/firebasejs/$_firebaseJsSdkVersion/firebase-app-compat.js"></script>
  <script src="https://www.gstatic.com/firebasejs/$_firebaseJsSdkVersion/firebase-auth-compat.js"></script>
  <script src="https://www.gstatic.com/firebasejs/$_firebaseJsSdkVersion/firebase-firestore-compat.js"></script>
  <script>
    const firebaseConfig = {
      apiKey: "${firebaseConfig['apiKey']}",
      authDomain: "${firebaseConfig['authDomain']}",
      projectId: "${firebaseConfig['projectId']}",
      storageBucket: "${firebaseConfig['storageBucket']}",
      messagingSenderId: "${firebaseConfig['messagingSenderId']}",
      appId: "${firebaseConfig['appId']}"
    };
    firebase.initializeApp(firebaseConfig);
  </script>''';

    // Replace any existing Firebase block (commented or active) or insert it.
    //
    // Templates currently emit a block shaped like:
    //   <!-- Firebase SDKs (uncomment if using Firebase) -->
    //   <!--
    //   <script src="..."></script>
    //   ...
    //   firebase.initializeApp(firebaseConfig);
    //   </script>
    //   -->
    //
    // The regex below tolerates either a single-comment header followed by a
    // multi-line `<!-- ... -->` body, or a single comment that contains the
    // whole block.
    final RegExp commentedBlock = RegExp(
      r'<!--\s*Firebase SDKs.*?-->\s*(?:<!--\s*[\s\S]*?-->|<!--\s*[\s\S]*?-->)',
      dotAll: true,
    );
    // Older templates may have used an empty `<!-- -->` terminator instead.
    final RegExp legacyCommentedBlock = RegExp(
      r'<!--\s*Firebase SDKs.*?-->.*?<!--\s*-->',
      dotAll: true,
    );
    final RegExp activeBlock = RegExp(
      r'<script src="https://www\.gstatic\.com/firebasejs/.*?firebase\.initializeApp\(firebaseConfig\);\s*</script>',
      dotAll: true,
    );

    if (commentedBlock.hasMatch(indexContent)) {
      indexContent = indexContent.replaceFirst(commentedBlock, firebaseScript);
    } else if (legacyCommentedBlock.hasMatch(indexContent)) {
      indexContent = indexContent.replaceFirst(
        legacyCommentedBlock,
        firebaseScript,
      );
    } else if (activeBlock.hasMatch(indexContent)) {
      indexContent = indexContent.replaceFirst(activeBlock, firebaseScript);
    } else {
      indexContent = indexContent.replaceFirst(
        '</head>',
        '$firebaseScript\n</head>',
      );
    }

    await indexFile.writeAsString(indexContent);
    success('Firebase JS SDK configured in index.html');

    final String apiKey = firebaseConfig['apiKey'] ?? '';
    final String apiKeyPreview = apiKey.length > 10
        ? '${apiKey.substring(0, 10)}...'
        : apiKey;
    verbose('  API Key: $apiKeyPreview');
    verbose('  Project ID: ${firebaseConfig['projectId']}');
    return true;
  }

  /// Either return the first existing web app whose displayName matches
  /// [desiredDisplayName], the first web app of any name, or create a new one.
  Future<Map<String, dynamic>?> _findOrCreateWebApp({
    required String projectId,
    required String desiredDisplayName,
  }) async {
    verbose('Checking if Firebase web app exists...');

    final List<Map<String, dynamic>>? existing = await _listFirebaseApps(
      projectId: projectId,
      platform: 'WEB',
    );

    if (existing == null) {
      error(
        'Failed to list Firebase web apps for project $projectId. '
        'Verify the project exists and your service account has Firebase access.',
      );
      return null;
    }

    if (existing.isNotEmpty) {
      Map<String, dynamic>? matchByName;
      for (final Map<String, dynamic> app in existing) {
        if (app['displayName'] == desiredDisplayName) {
          matchByName = app;
          break;
        }
      }
      if (matchByName != null) {
        verbose(
          'Reusing existing Firebase web app: $desiredDisplayName (${matchByName['appId']})',
        );
        return matchByName;
      }

      final Map<String, dynamic> firstApp = existing.first;
      verbose(
        'Reusing existing Firebase web app: ${firstApp['displayName']} (${firstApp['appId']})',
      );
      return firstApp;
    }

    info('Creating Firebase web app: $desiredDisplayName');
    final Map<String, dynamic>? created = await _createFirebaseApp(
      projectId: projectId,
      platform: 'WEB',
      displayName: desiredDisplayName,
    );

    if (created == null) {
      error(
        'Could not create a Firebase web app. '
        'Check that the Firebase project exists and the service account has '
        '"Firebase Admin" or equivalent permissions to create apps.',
      );
      return null;
    }

    success('Created Firebase web app: $desiredDisplayName');
    // Wait for propagation
    await Future<void>.delayed(const Duration(seconds: 2));
    return created;
  }

  /// Get Firebase web SDK config from Firebase CLI using --json output.
  ///
  /// Wrapped in [_runFirebaseWithRecovery] so a SERVICE_DISABLED for the
  /// Firebase Management API or a transient propagation lag is auto-fixed
  /// before we declare the step a failure.
  Future<Map<String, String>?> _getFirebaseWebConfig({
    required String projectId,
    required String appId,
  }) async {
    verbose('Getting Firebase web SDK config for app: $appId');

    final ProcessResult result = await _runFirebaseWithRecovery(
      args: <String>[
        'apps:sdkconfig',
        'WEB',
        appId,
        '--project',
        projectId,
        '--json',
      ],
      operationLabel: 'fetch Firebase web SDK config for $appId',
    );

    final Map<String, dynamic>? body = _parseFirebaseJson(result.stdout);
    if (body == null) {
      final String detail = _collectFirebaseFailureContext(result);
      error(
        'Failed to parse firebase apps:sdkconfig output for $appId.'
        '${detail.isNotEmpty ? '\n  Underlying error: ${detail.split('\n').first.trim()}' : ''}',
      );
      return null;
    }

    if (body['status'] != 'success') {
      final String detail = _collectFirebaseFailureContext(result);
      error(
        'Failed to get Firebase SDK config for $appId: '
        '${body['error'] ?? 'unknown error'}'
        '${detail.isNotEmpty ? '\n  Root cause: ${detail.split('\n').first.trim()}' : ''}',
      );
      return null;
    }

    final dynamic resultData = body['result'];
    if (resultData is! Map<String, dynamic>) {
      error('apps:sdkconfig returned unexpected payload');
      return null;
    }

    final dynamic sdkConfig = resultData['sdkConfig'];
    Map<String, dynamic>? sdkValues;
    if (sdkConfig is Map<String, dynamic>) {
      sdkValues = sdkConfig;
    } else if (resultData['fileContents'] is String) {
      try {
        final dynamic decoded = jsonDecode(resultData['fileContents'] as String);
        if (decoded is Map<String, dynamic>) {
          sdkValues = decoded;
        }
      } catch (_) {
        // Fall through
      }
    }

    if (sdkValues == null) {
      error('Could not locate sdkConfig payload from Firebase CLI');
      return null;
    }

    final Map<String, String> firebaseConfig = <String, String>{};
    for (final String key in const <String>[
      'apiKey',
      'authDomain',
      'projectId',
      'storageBucket',
      'messagingSenderId',
      'appId',
      'databaseURL',
    ]) {
      final dynamic value = sdkValues[key];
      if (value is String && value.isNotEmpty) {
        firebaseConfig[key] = value;
      }
    }

    if (firebaseConfig.isEmpty) {
      error('Firebase SDK config response was missing all expected fields');
      return null;
    }

    verbose('Parsed Firebase config with ${firebaseConfig.length} values');
    return firebaseConfig;
  }
}

/// Classification of a `firebase --json` failure. Used by
/// `_runFirebaseWithRecovery` to decide whether to auto-retry, auto-enable
/// the Firebase Management API, or surface the failure to the caller.
///
/// Public so tests can assert against specific failure kinds returned by
/// [FirebaseService.classifyFirebaseErrorForTest].
enum FirebaseFailureKind {
  /// `firebase.googleapis.com` is not enabled on the project. Auto-fix:
  /// `gcloud services enable firebase.googleapis.com` + wait + retry.
  serviceDisabled,

  /// Caller is missing IAM roles. The IAM gate handles this in step 5.4
  /// — surfacing here means the gate didn't catch it, so we fail.
  permissionDenied,

  /// 5xx, deadline-exceeded, ECONNRESET, propagation lag — exponential
  /// backoff retry resolves these.
  transient,

  /// Anything else. The caller should surface the raw error verbatim.
  unknown,
}
