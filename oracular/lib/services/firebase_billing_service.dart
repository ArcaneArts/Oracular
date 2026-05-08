import 'dart:convert';

import 'package:fast_log/fast_log.dart';

import '../utils/process_runner.dart' show ProcessResult, ProcessRunner;
import '../utils/user_prompt.dart';

/// Whether the Firebase / GCP project is on Blaze (pay-as-you-go) billing.
enum BlazeStatus {
  /// Project has billing enabled (Blaze plan).
  enabled,

  /// Project has billing disabled (Spark plan).
  notEnabled,

  /// Could not determine status (auth missing, gcloud not installed, no IAM
  /// permission, or unexpected output). Treated as soft-fail by callers.
  unknown,
}

/// Detailed result of a billing check.
class BillingCheckResult {
  /// Current billing status.
  final BlazeStatus status;

  /// `billingAccounts/AAAAAA-BBBBBB-CCCCCC` style identifier when known.
  final String? billingAccountName;

  /// Human readable message describing why a check returned [unknown].
  /// Empty for [enabled] / [notEnabled].
  final String? message;

  const BillingCheckResult({
    required this.status,
    this.billingAccountName,
    this.message,
  });

  bool get isBlaze => status == BlazeStatus.enabled;

  @override
  String toString() =>
      'BillingCheckResult(status: $status, account: $billingAccountName)';
}

/// Detect Spark vs Blaze on a Firebase / GCP project and guide the user
/// through upgrading when necessary.
///
/// This service intentionally never blocks: every public call gracefully
/// degrades to [BlazeStatus.unknown] when the underlying tooling fails,
/// letting the orchestrator decide whether to skip Blaze-only steps.
class FirebaseBillingService {
  /// Project we are checking. Required for [checkBlazeStatus] /
  /// [guideUpgrade] callers that don't pass an explicit override.
  final String projectId;

  final ProcessRunner _runner;

  FirebaseBillingService(this.projectId, {ProcessRunner? runner})
      : _runner = runner ?? ProcessRunner();

  /// Build the Firebase Console URL where the user can flip Spark → Blaze.
  static String upgradeUrl(String projectId) =>
      'https://console.firebase.google.com/project/$projectId/usage/details';

  /// Build the GCP console billing URL (alternate path used during upgrade).
  static String gcpBillingUrl(String projectId) =>
      'https://console.cloud.google.com/billing/linkedaccount?project=$projectId';

  /// Determine whether [projectId] is on Blaze billing.
  ///
  /// Calls `gcloud beta billing projects describe <project> --format=json`
  /// and parses `billingEnabled` / `billingAccountName`.
  Future<BillingCheckResult> checkBlazeStatus({String? projectId}) async {
    final String pid = projectId ?? this.projectId;
    if (pid.isEmpty) {
      return const BillingCheckResult(
        status: BlazeStatus.unknown,
        message: 'No Firebase project ID configured',
      );
    }

    final ProcessResult result = await _runner.run('gcloud', <String>[
      'beta',
      'billing',
      'projects',
      'describe',
      pid,
      '--format=json',
    ]);

    if (!result.success) {
      final String stderr = result.stderr.trim();
      if (stderr.contains('PERMISSION_DENIED') ||
          stderr.contains('does not have permission')) {
        return BillingCheckResult(
          status: BlazeStatus.unknown,
          message:
              'Permission denied reading billing info for $pid. Run `gcloud auth login` with an account that has roles/billing.viewer.',
        );
      }
      if (stderr.contains('NOT_FOUND') ||
          stderr.contains('Could not find project')) {
        return BillingCheckResult(
          status: BlazeStatus.unknown,
          message:
              'Project $pid was not found. Verify the project ID and that the active gcloud account can access it.',
        );
      }
      return BillingCheckResult(
        status: BlazeStatus.unknown,
        message: stderr.isEmpty
            ? 'gcloud billing describe exited ${result.exitCode}'
            : stderr,
      );
    }

    return _parseBillingJson(result.stdout);
  }

  /// Parse the JSON body of `gcloud beta billing projects describe`.
  static BillingCheckResult _parseBillingJson(String stdout) {
    final String trimmed = stdout.trim();
    if (trimmed.isEmpty) {
      return const BillingCheckResult(
        status: BlazeStatus.unknown,
        message: 'gcloud billing describe returned empty output',
      );
    }

    try {
      final dynamic decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) {
        return const BillingCheckResult(
          status: BlazeStatus.unknown,
          message: 'Unexpected billing payload (not a JSON object)',
        );
      }

      final dynamic enabled = decoded['billingEnabled'];
      final dynamic account = decoded['billingAccountName'];
      final String? accountName = account is String && account.isNotEmpty
          ? account
          : null;

      if (enabled is bool) {
        return BillingCheckResult(
          status: enabled ? BlazeStatus.enabled : BlazeStatus.notEnabled,
          billingAccountName: accountName,
        );
      }

      // No `billingEnabled` field at all — Spark projects sometimes return a
      // bare `{ "name": "...", "projectId": "..." }` payload.
      return BillingCheckResult(
        status: BlazeStatus.notEnabled,
        billingAccountName: accountName,
      );
    } on FormatException catch (e) {
      return BillingCheckResult(
        status: BlazeStatus.unknown,
        message: 'Could not parse billing JSON: ${e.message}',
      );
    }
  }

  /// Walk the user through upgrading to Blaze.
  ///
  /// Prints the consequence of staying on Spark, the upgrade URL, then
  /// prompts the user. After they confirm completion the status is
  /// re-checked. The loop runs at most [maxLoops] times so a misclick can
  /// never hang the wizard.
  ///
  /// Returns the final [BillingCheckResult].
  Future<BillingCheckResult> guideUpgrade({
    String? projectId,
    int maxLoops = 3,
    bool interactive = true,
  }) async {
    final String pid = projectId ?? this.projectId;
    final String url = upgradeUrl(pid);

    UserPrompt.printDivider(title: 'Upgrade to Blaze (pay-as-you-go)');
    UserPrompt.printList(<String>[
      'Spark plan covers: Hosting, Firestore (small), Auth, Storage (small).',
      'Blaze plan is required for: Cloud Run, Artifact Registry cleanup,',
      '  scheduled jobs, callable functions, and most production workloads.',
      'Open: $url',
      'Sign in with an account that owns the project and link a billing',
      '  account. The upgrade is reversible — you can downgrade at any time.',
    ]);
    print('');

    if (!interactive) {
      info('Non-interactive mode: skipping Blaze upgrade hand-off for $pid');
      return BillingCheckResult(
        status: BlazeStatus.unknown,
        message:
            'Run `oracular check billing` after upgrading to Blaze at $url',
      );
    }

    for (int i = 0; i < maxLoops; i++) {
      final bool ready = await UserPrompt.askYesNo(
        i == 0
            ? 'Have you completed the Blaze upgrade in the browser?'
            : 'Re-check billing now? (will run gcloud billing describe)',
        defaultValue: i == 0,
      );
      if (!ready) {
        warn('Skipping Blaze verification for $pid.');
        return const BillingCheckResult(
          status: BlazeStatus.unknown,
          message: 'User skipped Blaze verification',
        );
      }

      final BillingCheckResult check = await checkBlazeStatus(projectId: pid);
      switch (check.status) {
        case BlazeStatus.enabled:
          success('Blaze plan confirmed for $pid.');
          if (check.billingAccountName != null) {
            info('Linked billing account: ${check.billingAccountName}');
          }
          return check;
        case BlazeStatus.notEnabled:
          warn(
            'Project $pid is still on Spark. The upgrade may not have completed — refresh the Firebase Console and try again.',
          );
          continue;
        case BlazeStatus.unknown:
          warn(
            'Could not verify billing for $pid: ${check.message ?? 'unknown error'}',
          );
          continue;
      }
    }

    return BillingCheckResult(
      status: BlazeStatus.unknown,
      message:
          'Could not confirm Blaze upgrade after $maxLoops attempts. Run `oracular check billing` later, or skip Blaze-only steps for now.',
    );
  }

  /// Returns true when [stderr] contains a recognizable "billing is missing
  /// or disabled" signature from gcloud / Firebase. Used by initialization
  /// code to surface a clear "upgrade to Blaze" hand-off instead of
  /// re-rendering the raw HTTP error.
  ///
  /// Examples this matches:
  ///   • `HTTPError 403: The billing account for the owning project is
  ///     disabled in state absent`
  ///   • `Billing is disabled for project ...`
  ///   • `BILLING_DISABLED`
  ///   • `requires billing to be enabled`
  static bool isBillingAbsentError(String stderr) {
    final String lower = stderr.toLowerCase();
    return lower.contains('billing account') &&
            (lower.contains('disabled') ||
                lower.contains('absent') ||
                lower.contains('not found')) ||
        lower.contains('billing_disabled') ||
        lower.contains('billing is disabled') ||
        lower.contains('requires billing to be enabled') ||
        lower.contains('requires a billing account');
  }
}
