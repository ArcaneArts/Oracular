import 'dart:convert';

import 'package:fast_log/fast_log.dart';

import '../utils/process_runner.dart' show ProcessResult, ProcessRunner;

/// Outcome category for a single site-ensure operation.
enum SiteEnsureOutcome {
  /// Site already existed; nothing changed.
  existed,

  /// We just created the site.
  created,

  /// Operation failed (see [SiteEnsureResult.message]).
  failed,
}

/// Outcome of `HostingSiteManager.ensureReleaseSite` /
/// `ensureBetaSite`.
class SiteEnsureResult {
  /// Hosting site identifier (e.g. `my-app`, `my-app-beta`).
  final String siteId;

  /// What happened.
  final SiteEnsureOutcome outcome;

  /// Diagnostic message; empty on success.
  final String message;

  const SiteEnsureResult({
    required this.siteId,
    required this.outcome,
    this.message = '',
  });

  bool get success => outcome != SiteEnsureOutcome.failed;

  bool get changed => outcome == SiteEnsureOutcome.created;

  /// Live URL the site will serve from once content is deployed.
  /// (Hosting always exposes both `.web.app` and `.firebaseapp.com`.)
  String? get webAppUrl => success ? 'https://$siteId.web.app' : null;

  /// Alternate live URL (`firebaseapp.com`).
  String? get firebaseAppUrl =>
      success ? 'https://$siteId.firebaseapp.com' : null;

  @override
  String toString() => 'SiteEnsureResult($siteId: $outcome)';
}

/// Outcome of `HostingSiteManager.applyTargets`.
class ApplyTargetsResult {
  /// Whether release+beta target mappings were both written into
  /// `.firebaserc`.
  final bool releaseApplied;
  final bool betaApplied;
  final String message;

  const ApplyTargetsResult({
    required this.releaseApplied,
    required this.betaApplied,
    this.message = '',
  });

  bool get success => releaseApplied && betaApplied;

  @override
  String toString() =>
      'ApplyTargetsResult(release: $releaseApplied, beta: $betaApplied)';
}

/// Manages Firebase Hosting sites and `firebase target:apply` mappings.
///
/// The orchestrator uses this to:
///   1. Verify the **release** site exists. Firebase auto-creates a site
///      called `<projectId>` when the project is created, so this is
///      almost always a no-op verify, but we still check because
///      `firebase deploy --only hosting:release` will fail loudly if the
///      target points at a missing site.
///   2. Create the **beta** site `<projectId>-beta`. This is *not* auto-
///      created and is the most common reason a fresh project's beta
///      hosting deploy fails.
///   3. Apply target mappings into the project's `.firebaserc` so
///      `firebase deploy --only hosting:release` / `hosting:beta` works.
///
/// All operations are idempotent: re-running has no effect when the
/// resource already exists.
///
/// Template-agnostic: the same site/target wiring is used by Flutter web,
/// Jaspr client, and Jaspr static templates because the hosting public
/// path is set in `firebase.json` per-template (see
/// `ConfigGenerator._hostingPublicPath` at
/// `oracular/lib/services/config_generator.dart:77-82`).
class HostingSiteManager {
  /// Firebase project ID. Used as the release site id and as the prefix
  /// for the beta site (`<projectId>-beta`).
  final String projectId;

  /// Working directory for any `firebase` invocation that needs to
  /// touch `.firebaserc` / `firebase.json` (i.e. [applyTargets]).
  final String workingDirectory;

  /// Optional environment vars passed on every `firebase` invocation.
  /// **Critical:** without this, firebase-tools inherits only the parent
  /// shell's env and falls back to `~/.config/configstore/firebase-tools.json`
  /// for auth — which fails with "Failed to authenticate, have you run
  /// firebase login?" the moment the user logs out (or never logged in
  /// in the first place).
  ///
  /// Should be set from `FirebaseService.authEnvironment` so all
  /// HostingSiteManager calls authenticate as the same SA Oracular uses
  /// for everything else.
  final Map<String, String>? environment;

  final ProcessRunner _runner;

  HostingSiteManager(
    this.projectId, {
    required this.workingDirectory,
    this.environment,
    ProcessRunner? runner,
  }) : _runner = runner ?? ProcessRunner();

  /// Computed beta site id: `<projectId>-beta`.
  String get betaSiteId => '$projectId-beta';

  /// List the hosting site ids for this project. Returns `null` when the
  /// CLI invocation failed (auth / network / not-found etc) so callers can
  /// fall back to the optimistic create flow.
  Future<List<String>?> listSites() async {
    if (projectId.isEmpty) {
      return null;
    }
    final ProcessResult result = await _runner.run(
      'firebase',
      <String>[
        'hosting:sites:list',
        '--project',
        projectId,
        '--json',
      ],
      workingDirectory: workingDirectory,
      environment: environment,
    );
    if (!result.success) {
      return null;
    }
    return _parseSites(result.stdout);
  }

  /// Ensure the **release** hosting site exists.
  ///
  /// Firebase auto-creates `<projectId>` as the default site when a
  /// project is created in the console, so this is *usually* an idempotent
  /// verification. If the site is missing we attempt to create it; on
  /// `ALREADY_EXISTS` we treat it as success.
  Future<SiteEnsureResult> ensureReleaseSite() async {
    return _ensureSite(projectId, label: 'release');
  }

  /// Ensure the **beta** hosting site `<projectId>-beta` exists.
  ///
  /// This is the site users almost always need created — it is not auto-
  /// provisioned by Firebase. Idempotent: returns [SiteEnsureOutcome.existed]
  /// when the site is already present.
  Future<SiteEnsureResult> ensureBetaSite() async {
    return _ensureSite(betaSiteId, label: 'beta');
  }

  /// Apply `firebase target:apply hosting release <projectId>` and
  /// `firebase target:apply hosting beta <projectId>-beta` so
  /// `firebase deploy --only hosting:release|hosting:beta` works.
  ///
  /// Idempotent: writes mappings into `.firebaserc` and overwrites any
  /// previous mapping for the same target name.
  Future<ApplyTargetsResult> applyTargets({
    String releaseTarget = 'release',
    String betaTarget = 'beta',
  }) async {
    if (projectId.isEmpty) {
      return const ApplyTargetsResult(
        releaseApplied: false,
        betaApplied: false,
        message: 'No Firebase project ID configured',
      );
    }

    final ProcessResult release = await _runner.run('firebase', <String>[
      'target:apply',
      'hosting',
      releaseTarget,
      projectId,
      '--project',
      projectId,
    ], workingDirectory: workingDirectory, environment: environment);

    final ProcessResult beta = await _runner.run('firebase', <String>[
      'target:apply',
      'hosting',
      betaTarget,
      betaSiteId,
      '--project',
      projectId,
    ], workingDirectory: workingDirectory, environment: environment);

    final bool releaseOk = release.success;
    final bool betaOk = beta.success;

    final List<String> errors = <String>[];
    if (!releaseOk) {
      errors.add('release target: ${_extractError(release)}');
    }
    if (!betaOk) {
      errors.add('beta target: ${_extractError(beta)}');
    }

    if (releaseOk && betaOk) {
      info('Hosting targets applied: $releaseTarget=$projectId, '
          '$betaTarget=$betaSiteId');
    } else {
      warn('Failed to apply hosting targets: ${errors.join('; ')}');
    }

    return ApplyTargetsResult(
      releaseApplied: releaseOk,
      betaApplied: betaOk,
      message: errors.join('; '),
    );
  }

  Future<SiteEnsureResult> _ensureSite(
    String siteId, {
    required String label,
  }) async {
    if (projectId.isEmpty) {
      return SiteEnsureResult(
        siteId: siteId,
        outcome: SiteEnsureOutcome.failed,
        message: 'No Firebase project ID configured',
      );
    }

    info('Ensuring $label hosting site `$siteId`...');

    // First try a list to detect existing sites cheaply. If the list call
    // fails (e.g. permissions), we fall through to an optimistic create.
    final List<String>? sites = await listSites();
    if (sites != null && sites.contains(siteId)) {
      info('Hosting site `$siteId` already exists.');
      return SiteEnsureResult(
        siteId: siteId,
        outcome: SiteEnsureOutcome.existed,
      );
    }

    ProcessResult create = await _runner.run(
      'firebase',
      <String>[
        'hosting:sites:create',
        siteId,
        '--project',
        projectId,
      ],
      workingDirectory: workingDirectory,
      environment: environment,
    );

    // Self-heal: when firebase-tools has neither a stored login nor
    // GOOGLE_APPLICATION_CREDENTIALS that resolves to a valid SA, it
    // exits with "Failed to authenticate, have you run firebase login?".
    // If we *do* have an `environment` map (i.e. a SA file is configured)
    // this almost always means firebase-tools is finding stale state
    // from a previous `firebase login` that has since been logged out.
    // Try a force-logout-everything + retry; this drops firebase-tools
    // back to GOOGLE_APPLICATION_CREDENTIALS / ADC.
    if (!create.success && _isAuthenticationError(create) && environment != null) {
      warn('firebase $label site create hit an auth error '
          '("Failed to authenticate"). Most common cause: stale firebase '
          'login state lingering after `firebase logout`. Force-clearing '
          'firebase-tools auth and retrying as the configured service '
          'account...');
      final ProcessResult logoutAll = await _runner.run(
        'firebase',
        <String>['logout', '--force'],
        workingDirectory: workingDirectory,
      );
      if (!logoutAll.success) {
        warn('  firebase logout --force failed: '
            '${logoutAll.stderr.trim()}. Continuing the retry anyway.');
      }
      create = await _runner.run(
        'firebase',
        <String>[
          'hosting:sites:create',
          siteId,
          '--project',
          projectId,
        ],
        workingDirectory: workingDirectory,
        environment: environment,
      );
    }

    if (create.success) {
      success('Hosting site `$siteId` created.');
      return SiteEnsureResult(
        siteId: siteId,
        outcome: SiteEnsureOutcome.created,
      );
    }

    final String combined = '${create.stdout}\n${create.stderr}';
    if (_isAlreadyExists(combined)) {
      info('Hosting site `$siteId` already exists.');
      return SiteEnsureResult(
        siteId: siteId,
        outcome: SiteEnsureOutcome.existed,
      );
    }

    return SiteEnsureResult(
      siteId: siteId,
      outcome: SiteEnsureOutcome.failed,
      message: _extractError(create),
    );
  }

  /// Returns true when the firebase CLI failed because it couldn't find
  /// any usable credentials (no stored login + bad/missing
  /// `GOOGLE_APPLICATION_CREDENTIALS`).
  static bool _isAuthenticationError(ProcessResult result) {
    final String combined = '${result.stdout}\n${result.stderr}'.toLowerCase();
    return combined.contains('failed to authenticate') ||
        combined.contains('have you run firebase login') ||
        combined.contains('not authenticated') ||
        combined.contains('command requires authentication');
  }

  /// Returns true when stdout/stderr indicates `409 ALREADY_EXISTS`.
  static bool _isAlreadyExists(String output) {
    final String lower = output.toLowerCase();
    return lower.contains('already_exists') ||
        lower.contains('already exists') ||
        lower.contains('409');
  }

  /// Pull a useful single-line error message out of a Firebase CLI failure.
  static String _extractError(ProcessResult result) {
    final String stderr = result.stderr.trim();
    if (stderr.isNotEmpty) {
      return stderr;
    }
    final String stdout = result.stdout.trim();
    if (stdout.isNotEmpty) {
      return stdout;
    }
    return 'firebase CLI exited ${result.exitCode}';
  }

  /// Parse `firebase hosting:sites:list --json` output into a list of
  /// site ids. The CLI envelope is:
  ///   { "status": "success", "result": { "sites": [ { "name": "...", "type": "...", ... } ] } }
  /// where `name` looks like `projects/<num>/sites/<siteId>`.
  static List<String>? _parseSites(String stdout) {
    final String trimmed = stdout.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final dynamic decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final dynamic resultMap = decoded['result'];
      if (resultMap is! Map<String, dynamic>) {
        return null;
      }
      final dynamic sites = resultMap['sites'];
      if (sites is! List) {
        return null;
      }
      final List<String> out = <String>[];
      for (final dynamic s in sites) {
        if (s is Map<String, dynamic>) {
          // Prefer explicit `siteId` field; fall back to parsing `name`.
          final dynamic siteId = s['siteId'];
          if (siteId is String && siteId.isNotEmpty) {
            out.add(siteId);
            continue;
          }
          final dynamic name = s['name'];
          if (name is String && name.isNotEmpty) {
            final List<String> parts = name.split('/');
            if (parts.isNotEmpty) {
              out.add(parts.last);
            }
          }
        }
      }
      return out;
    } on FormatException {
      return null;
    }
  }
}
