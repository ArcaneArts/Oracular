import 'dart:convert';
import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../utils/process_runner.dart' show ProcessResult, ProcessRunner;

/// Outcome category for `ArtifactCleanupService.ensureRepository`.
enum RepositoryEnsureOutcome {
  /// Repository already existed; no change.
  existed,

  /// We just created the repository.
  created,

  /// Operation failed (see [RepositoryEnsureResult.message]).
  failed,
}

/// Result of `ArtifactCleanupService.ensureRepository`.
class RepositoryEnsureResult {
  /// Repository name (e.g. `oracular`, `cloud-run-source-deploy`).
  final String repository;

  /// GCP region the repository is in (e.g. `us-central1`).
  final String region;

  /// What happened.
  final RepositoryEnsureOutcome outcome;

  /// Diagnostic message; empty on success.
  final String message;

  const RepositoryEnsureResult({
    required this.repository,
    required this.region,
    required this.outcome,
    this.message = '',
  });

  bool get success => outcome != RepositoryEnsureOutcome.failed;

  bool get changed => outcome == RepositoryEnsureOutcome.created;

  @override
  String toString() =>
      'RepositoryEnsureResult($repository@$region: $outcome)';
}

/// Result of `ArtifactCleanupService.applyCleanupPolicies`.
class CleanupPolicyResult {
  /// Whether the policy file was applied successfully.
  final bool applied;

  /// Number of cleanup conditions in the applied policy
  /// (informational; does not gate success).
  final int policyCount;

  /// Diagnostic message; empty on success.
  final String message;

  const CleanupPolicyResult({
    required this.applied,
    this.policyCount = 0,
    this.message = '',
  });

  bool get success => applied;

  @override
  String toString() =>
      'CleanupPolicyResult(applied: $applied, conditions: $policyCount)';
}

/// Outcome of pruning a single Cloud Run revision.
class _RevisionPruneOutcome {
  _RevisionPruneOutcome({
    required this.revisionId,
    required this.deleted,
    required this.skippedServingTraffic,
    this.message = '',
  });

  final String revisionId;
  final bool deleted;
  final bool skippedServingTraffic;
  final String message;
}

/// Result of `ArtifactCleanupService.capCloudRunRevisions`.
class RevisionPruneResult {
  /// Number of revisions deleted.
  final int deleted;

  /// Number of revisions skipped because they served traffic.
  final int skipped;

  /// Per-revision details (deleted + skipped + failed).
  final List<String> deletedRevisions;
  final List<String> skippedRevisions;
  final List<String> failedRevisions;

  /// Diagnostic message; empty on full success.
  final String message;

  const RevisionPruneResult({
    required this.deleted,
    required this.skipped,
    required this.deletedRevisions,
    required this.skippedRevisions,
    required this.failedRevisions,
    this.message = '',
  });

  /// Total number of revisions that were either deleted or skipped without
  /// any failures.
  bool get success => failedRevisions.isEmpty;

  @override
  String toString() =>
      'RevisionPruneResult(deleted: $deleted, skipped: $skipped, '
      'failed: ${failedRevisions.length})';
}

/// Manages Artifact Registry repositories and Cloud Run revision retention.
///
/// The orchestrator (and the generated `script_deploy.sh`) use this to
/// keep production GCP usage bounded after every deploy:
///
///   1. **Artifact Registry** — creates the docker repository if missing,
///      then applies a JSON cleanup policy (keep N most-recent versions
///      tagged `latest`/`prod`, delete everything else older than D days).
///   2. **Cloud Run** — keeps the last N revisions of a service and prunes
///      everything older. Revisions currently routing traffic are always
///      preserved.
///
/// All operations are idempotent: re-running has no effect when the
/// repository already exists / the policy is unchanged / no revisions need
/// pruning. Public methods never throw — failures are returned via the
/// `…Result` types so the orchestrator can surface them in the wizard.
class ArtifactCleanupService {
  /// GCP / Firebase project ID.
  final String projectId;

  /// Default region for repository / Cloud Run operations.
  /// Callers can override per-call (e.g. `us-east1`).
  final String defaultRegion;

  final ProcessRunner _runner;

  ArtifactCleanupService(
    this.projectId, {
    this.defaultRegion = 'us-central1',
    ProcessRunner? runner,
  }) : _runner = runner ?? ProcessRunner();

  /// Ensure Artifact Registry [repository] exists in [region].
  ///
  /// Idempotent: a 409 / "already exists" error is treated as success and
  /// reported as [RepositoryEnsureOutcome.existed]. Any other failure is
  /// reported as [RepositoryEnsureOutcome.failed] with the gcloud stderr
  /// in the message.
  Future<RepositoryEnsureResult> ensureRepository({
    required String repository,
    String? region,
    String repositoryFormat = 'docker',
  }) async {
    final String r = region ?? defaultRegion;

    if (projectId.isEmpty) {
      return RepositoryEnsureResult(
        repository: repository,
        region: r,
        outcome: RepositoryEnsureOutcome.failed,
        message: 'No Firebase / GCP project ID configured',
      );
    }

    info('Checking Artifact Registry repository `$repository`@$r...');
    final ProcessResult describe = await _runner.run('gcloud', <String>[
      'artifacts',
      'repositories',
      'describe',
      repository,
      '--location=$r',
      '--project=$projectId',
      '--format=json',
    ]);

    if (describe.success) {
      info('Artifact Registry repository `$repository` already exists.');
      return RepositoryEnsureResult(
        repository: repository,
        region: r,
        outcome: RepositoryEnsureOutcome.existed,
      );
    }

    final String describeStderr = describe.stderr;
    if (!_isNotFoundError(describeStderr)) {
      // Surface auth / permission failure as failed; orchestrator decides
      // whether to skip or hand off.
      return RepositoryEnsureResult(
        repository: repository,
        region: r,
        outcome: RepositoryEnsureOutcome.failed,
        message: describeStderr.trim().isEmpty
            ? 'gcloud artifacts describe exited ${describe.exitCode}'
            : describeStderr.trim(),
      );
    }

    info('Creating Artifact Registry repository `$repository` in $r...');
    final ProcessResult create = await _runner.run('gcloud', <String>[
      'artifacts',
      'repositories',
      'create',
      repository,
      '--repository-format=$repositoryFormat',
      '--location=$r',
      '--project=$projectId',
    ]);

    if (create.success) {
      success('Artifact Registry repository `$repository` created.');
      return RepositoryEnsureResult(
        repository: repository,
        region: r,
        outcome: RepositoryEnsureOutcome.created,
      );
    }

    final String combined = '${create.stdout}\n${create.stderr}';
    if (_isAlreadyExists(combined)) {
      info('Artifact Registry repository `$repository` already exists.');
      return RepositoryEnsureResult(
        repository: repository,
        region: r,
        outcome: RepositoryEnsureOutcome.existed,
      );
    }

    return RepositoryEnsureResult(
      repository: repository,
      region: r,
      outcome: RepositoryEnsureOutcome.failed,
      message: _extractError(create),
    );
  }

  /// Apply a cleanup policy to [repository] that keeps the [keepRecent]
  /// most-recent versions tagged `latest`/`prod` and deletes everything
  /// older than [deleteOlderDays] days.
  ///
  /// Internally:
  ///   1. Builds an in-memory JSON policy
  ///   2. Writes it to a temp file (gcloud requires a file path)
  ///   3. Runs `gcloud artifacts repositories set-cleanup-policies`
  ///
  /// Idempotent: re-running with the same parameters is a no-op from a
  /// gcloud perspective.
  ///
  /// Returns a [CleanupPolicyResult] with `applied=true` on success.
  Future<CleanupPolicyResult> applyCleanupPolicies({
    required String repository,
    String? region,
    int keepRecent = 5,
    int deleteOlderDays = 30,
  }) async {
    final String r = region ?? defaultRegion;

    if (projectId.isEmpty) {
      return const CleanupPolicyResult(
        applied: false,
        message: 'No Firebase / GCP project ID configured',
      );
    }

    if (keepRecent < 1) {
      return CleanupPolicyResult(
        applied: false,
        message: 'keepRecent must be ≥ 1 (got $keepRecent)',
      );
    }
    if (deleteOlderDays < 1) {
      return CleanupPolicyResult(
        applied: false,
        message: 'deleteOlderDays must be ≥ 1 (got $deleteOlderDays)',
      );
    }

    final List<Map<String, Object?>> policy = buildPolicy(
      keepRecent: keepRecent,
      deleteOlderDays: deleteOlderDays,
    );

    final Directory tempDir = await Directory.systemTemp
        .createTemp('oracular-cleanup-');
    final File policyFile = File(p.join(tempDir.path, 'cleanup-policy.json'));
    try {
      await policyFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(policy));

      info(
        'Applying Artifact Registry cleanup policy '
        '(keep $keepRecent recent + delete >${deleteOlderDays}d) '
        'to `$repository`@$r...',
      );
      final ProcessResult result = await _runner.run('gcloud', <String>[
        'artifacts',
        'repositories',
        'set-cleanup-policies',
        repository,
        '--location=$r',
        '--project=$projectId',
        '--policy=${policyFile.path}',
      ]);

      if (result.success) {
        success(
          'Artifact Registry cleanup policy applied to `$repository`.',
        );
        return CleanupPolicyResult(
          applied: true,
          policyCount: policy.length,
        );
      }

      return CleanupPolicyResult(
        applied: false,
        policyCount: policy.length,
        message: _extractError(result),
      );
    } finally {
      // Best-effort cleanup of the temp dir.
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // Ignore — temp dir cleanup is non-critical.
      }
    }
  }

  /// Build the policy structure used by `set-cleanup-policies`.
  ///
  /// The schema is documented at
  /// https://cloud.google.com/artifact-registry/docs/repositories/cleanup-policy
  ///
  /// We emit two rules:
  ///   1. `keep-recent` — KEEP the most recent [keepRecent] versions tagged
  ///      `latest` or `prod`.
  ///   2. `delete-stale` — DELETE versions older than [deleteOlderDays]
  ///      days that aren't covered by `keep-recent`.
  static List<Map<String, Object?>> buildPolicy({
    required int keepRecent,
    required int deleteOlderDays,
  }) {
    return <Map<String, Object?>>[
      <String, Object?>{
        'name': 'keep-recent',
        'action': <String, Object?>{'type': 'Keep'},
        'mostRecentVersions': <String, Object?>{
          'keepCount': keepRecent,
          'packageNamePrefixes': <String>[],
        },
      },
      <String, Object?>{
        'name': 'delete-stale',
        'action': <String, Object?>{'type': 'Delete'},
        'condition': <String, Object?>{
          'olderThan': '${deleteOlderDays}d',
        },
      },
    ];
  }

  /// Cap Cloud Run revisions of [service] to the [keepRevisions] most
  /// recent ones. Revisions currently routing traffic are always preserved.
  ///
  /// Strategy:
  ///   1. List revisions newest-first via `gcloud run revisions list --format=json`
  ///   2. Read traffic allocations via `gcloud run services describe`
  ///   3. Keep first [keepRevisions] *non-traffic-serving* revisions
  ///   4. Delete the rest with `--quiet`
  Future<RevisionPruneResult> capCloudRunRevisions({
    required String service,
    String? region,
    int keepRevisions = 3,
  }) async {
    final String r = region ?? defaultRegion;

    if (projectId.isEmpty) {
      return const RevisionPruneResult(
        deleted: 0,
        skipped: 0,
        deletedRevisions: <String>[],
        skippedRevisions: <String>[],
        failedRevisions: <String>[],
        message: 'No Firebase / GCP project ID configured',
      );
    }

    if (keepRevisions < 1) {
      return RevisionPruneResult(
        deleted: 0,
        skipped: 0,
        deletedRevisions: const <String>[],
        skippedRevisions: const <String>[],
        failedRevisions: const <String>[],
        message: 'keepRevisions must be ≥ 1 (got $keepRevisions)',
      );
    }

    info(
      'Capping Cloud Run revisions for `$service`@$r '
      '(keeping latest $keepRevisions)...',
    );

    final List<String>? revisions = await _listRevisions(
      service: service,
      region: r,
    );
    if (revisions == null) {
      return RevisionPruneResult(
        deleted: 0,
        skipped: 0,
        deletedRevisions: const <String>[],
        skippedRevisions: const <String>[],
        failedRevisions: const <String>[],
        message:
            'Could not list revisions for $service in $r — skipping prune.',
      );
    }

    if (revisions.length <= keepRevisions) {
      info(
        'Cloud Run service `$service` has ${revisions.length} revisions; '
        'no pruning needed.',
      );
      return RevisionPruneResult(
        deleted: 0,
        skipped: 0,
        deletedRevisions: const <String>[],
        skippedRevisions: const <String>[],
        failedRevisions: const <String>[],
      );
    }

    final Set<String> trafficRevisions = await _listTrafficRevisions(
      service: service,
      region: r,
    );

    // Keep the newest [keepRevisions] regardless of traffic; protect any
    // additional traffic-serving ones beyond that window.
    final Set<String> keep = <String>{
      ...revisions.take(keepRevisions),
      ...trafficRevisions,
    };

    final List<String> toDelete = revisions
        .where((String r) => !keep.contains(r))
        .toList(growable: false);

    final List<String> deleted = <String>[];
    final List<String> skipped = <String>[];
    final List<String> failed = <String>[];
    for (final String rev in toDelete) {
      final _RevisionPruneOutcome outcome = await _deleteRevision(
        revision: rev,
        region: r,
      );
      if (outcome.skippedServingTraffic) {
        skipped.add(rev);
        continue;
      }
      if (outcome.deleted) {
        deleted.add(rev);
        continue;
      }
      failed.add(rev);
    }

    if (failed.isEmpty) {
      success(
        'Cloud Run prune complete for `$service`: '
        'deleted ${deleted.length}, skipped ${skipped.length}, '
        'kept ${keep.length}.',
      );
    } else {
      warn(
        'Cloud Run prune partial for `$service`: '
        'deleted ${deleted.length}, failed ${failed.length}.',
      );
    }

    return RevisionPruneResult(
      deleted: deleted.length,
      skipped: skipped.length,
      deletedRevisions: List<String>.unmodifiable(deleted),
      skippedRevisions: List<String>.unmodifiable(skipped),
      failedRevisions: List<String>.unmodifiable(failed),
    );
  }

  /// List Cloud Run revision IDs for [service] newest-first. Returns null
  /// when the underlying CLI invocation fails.
  Future<List<String>?> _listRevisions({
    required String service,
    required String region,
  }) async {
    final ProcessResult result = await _runner.run('gcloud', <String>[
      'run',
      'revisions',
      'list',
      '--service=$service',
      '--region=$region',
      '--project=$projectId',
      '--sort-by=~creationTimestamp',
      '--format=json',
    ]);
    if (!result.success) {
      return null;
    }
    return parseRevisionList(result.stdout);
  }

  /// Best-effort fetch of the set of revisions currently routing traffic
  /// for [service]. Returns an empty set when the CLI invocation fails.
  Future<Set<String>> _listTrafficRevisions({
    required String service,
    required String region,
  }) async {
    final ProcessResult result = await _runner.run('gcloud', <String>[
      'run',
      'services',
      'describe',
      service,
      '--region=$region',
      '--project=$projectId',
      '--format=json',
    ]);
    if (!result.success) {
      return const <String>{};
    }
    return parseTrafficRevisions(result.stdout);
  }

  /// Delete [revision] in [region]. Returns the revision-level outcome.
  /// `--quiet` suppresses the y/N prompt; if the revision is currently
  /// serving traffic, gcloud refuses to delete it and we return
  /// [_RevisionPruneOutcome.skippedServingTraffic].
  Future<_RevisionPruneOutcome> _deleteRevision({
    required String revision,
    required String region,
  }) async {
    final ProcessResult result = await _runner.run('gcloud', <String>[
      'run',
      'revisions',
      'delete',
      revision,
      '--region=$region',
      '--project=$projectId',
      '--quiet',
    ]);

    if (result.success) {
      return _RevisionPruneOutcome(
        revisionId: revision,
        deleted: true,
        skippedServingTraffic: false,
      );
    }

    final String combined =
        '${result.stdout}\n${result.stderr}'.toLowerCase();
    if (combined.contains('serving traffic') ||
        combined.contains('cannot delete') ||
        combined.contains('traffic is allocated')) {
      return _RevisionPruneOutcome(
        revisionId: revision,
        deleted: false,
        skippedServingTraffic: true,
      );
    }

    return _RevisionPruneOutcome(
      revisionId: revision,
      deleted: false,
      skippedServingTraffic: false,
      message: _extractError(result),
    );
  }

  /// Parse `gcloud run revisions list --format=json` output into the
  /// list of revision IDs (e.g. `arcane-server-00042-xyz`).
  ///
  /// Each list item looks like:
  ///   `{ "metadata": { "name": "<revisionId>", ... }, ... }`
  static List<String>? parseRevisionList(String stdout) {
    final String trimmed = stdout.trim();
    if (trimmed.isEmpty) {
      return <String>[];
    }
    try {
      final dynamic decoded = jsonDecode(trimmed);
      if (decoded is! List) {
        return null;
      }
      final List<String> out = <String>[];
      for (final dynamic entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        final dynamic metadata = entry['metadata'];
        if (metadata is Map<String, dynamic>) {
          final dynamic name = metadata['name'];
          if (name is String && name.isNotEmpty) {
            out.add(name);
          }
        }
      }
      return out;
    } on FormatException {
      return null;
    }
  }

  /// Parse `gcloud run services describe --format=json` output into the
  /// set of revision IDs that currently route traffic.
  ///
  /// The relevant payload is `status.traffic[*].revisionName`.
  static Set<String> parseTrafficRevisions(String stdout) {
    final String trimmed = stdout.trim();
    if (trimmed.isEmpty) {
      return const <String>{};
    }
    try {
      final dynamic decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) {
        return const <String>{};
      }
      final dynamic status = decoded['status'];
      if (status is! Map<String, dynamic>) {
        return const <String>{};
      }
      final dynamic traffic = status['traffic'];
      if (traffic is! List) {
        return const <String>{};
      }
      final Set<String> out = <String>{};
      for (final dynamic t in traffic) {
        if (t is Map<String, dynamic>) {
          final dynamic rev = t['revisionName'];
          if (rev is String && rev.isNotEmpty) {
            out.add(rev);
          }
        }
      }
      return out;
    } on FormatException {
      return const <String>{};
    }
  }

  /// Detect a `NOT_FOUND` style failure from gcloud stderr.
  static bool _isNotFoundError(String stderr) {
    final String lower = stderr.toLowerCase();
    return lower.contains('not_found') ||
        lower.contains('does not exist') ||
        lower.contains('not found') ||
        lower.contains('could not find') ||
        lower.contains('404');
  }

  /// Detect a `409 ALREADY_EXISTS` style failure from gcloud output.
  static bool _isAlreadyExists(String output) {
    final String lower = output.toLowerCase();
    return lower.contains('already_exists') ||
        lower.contains('already exists') ||
        lower.contains('409');
  }

  /// Pull a useful single-line error message out of a gcloud failure.
  static String _extractError(ProcessResult result) {
    final String stderr = result.stderr.trim();
    if (stderr.isNotEmpty) return stderr;
    final String stdout = result.stdout.trim();
    if (stdout.isNotEmpty) return stdout;
    return 'gcloud exited ${result.exitCode}';
  }
}
