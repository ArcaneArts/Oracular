import 'package:fast_log/fast_log.dart';

import '../utils/process_runner.dart' show ProcessResult, ProcessRunner;

/// Shared Cloud Run / Artifact Registry preflights.
///
/// Both `ServerSetup.deployToCloudRun` (arcane_server) and
/// `JasprServerDeployer.deploy` (Jaspr SSR/hybrid) need the same three
/// preflight gates before any `docker push` or `gcloud run deploy` is
/// attempted:
///
///   1. **Active gcloud account sanity** — catch the "wrong service
///      account active" foot-gun up front instead of letting it cascade
///      into ten lines of `PERMISSION_DENIED` deep inside the push.
///   2. **Required GCP APIs enabled** — `artifactregistry.googleapis.com`
///      and `run.googleapis.com`. Both are off by default on fresh
///      projects.
///   3. **Artifact Registry repository exists** — without this `docker
///      push` fails with `NOT_FOUND` because the registry path doesn't
///      resolve to a repo.
///
/// All three were originally private to `ServerSetup`; this class is
/// the single source of truth so the Jaspr deployer can reuse them
/// without re-implementing or duplicating.
class CloudRunPreflight {
  final ProcessRunner _runner;

  CloudRunPreflight({ProcessRunner? runner}) : _runner = runner ?? ProcessRunner();

  /// Regex extracting `<project>` from a service-account email of the form
  /// `<sa-name>@<project>.iam.gserviceaccount.com`. Capture group 1 is the
  /// project portion. Returns `null` for user-account emails (gmail.com,
  /// custom domains, etc.) which can have IAM bindings on any project.
  static final RegExp _serviceAccountEmailRegex =
      RegExp(r'^[^@]+@([^.]+)\.iam\.gserviceaccount\.com$');

  /// Preflight: verify the active gcloud account is plausibly authorized
  /// for [projectId]. Returns `true` when:
  ///
  ///   - No account is active (let downstream gcloud calls fail with their
  ///     own clear errors), OR
  ///   - The active account is a user-account / non-SA email (any user
  ///     can in principle have IAM bindings on any project), OR
  ///   - The active account is a service-account *for this same project*
  ///     (`<sa>@<projectId>.iam.gserviceaccount.com`).
  ///
  /// Returns `false` when the active account is a service-account from a
  /// **different** project — this is almost always the result of stale
  /// `gcloud config set account …` state from a previous oracular run
  /// against another project, and downstream API enable / repo create
  /// calls will fail with `PERMISSION_DENIED` from a different project's
  /// SA. We surface that as one actionable error here instead of a
  /// cascade of warnings deep in the deploy.
  ///
  /// When we can suggest a better candidate (a SA matching [projectId] or
  /// a non-SA user account already credentialed via `gcloud auth list`),
  /// we print the exact `gcloud config set account …` command to copy.
  Future<bool> verifyActiveGcloudAccount({required String projectId}) async {
    final ProcessResult r = await _runner.run('gcloud', <String>[
      'config',
      'get-value',
      'account',
    ]);
    if (!r.success) return true; // gcloud not installed / unauthenticated

    final String active = r.stdout.trim();
    if (active.isEmpty || active == '(unset)') return true;

    final Match? saMatch = _serviceAccountEmailRegex.firstMatch(active);
    if (saMatch == null) return true; // user-account → assume OK
    final String saProject = saMatch.group(1)!;
    if (saProject == projectId) return true; // SA belongs to target project

    error('Active gcloud account is `$active`,');
    error('but you are deploying to project `$projectId`.');
    error('This service account belongs to project `$saProject` and almost');
    error('certainly cannot enable APIs / push images for `$projectId`.');
    print('');
    print('Suggested fix:');

    // Try to find a better candidate among the credentialed accounts
    // (`gcloud auth list`). Preferred order:
    //   1. A service account matching `projectId`
    //      (`*@<projectId>.iam.gserviceaccount.com`).
    //   2. A non-SA user account (gmail / workspace email).
    //   3. Generic `gcloud auth login` fallback.
    final ProcessResult listResult = await _runner.run('gcloud', <String>[
      'auth',
      'list',
      '--format=value(account)',
    ]);
    if (listResult.success) {
      final List<String> accounts = listResult.stdout
          .split('\n')
          .map((String s) => s.trim())
          .where((String s) => s.isNotEmpty)
          .toList(growable: false);

      String? matchingSa;
      String? userAccount;
      for (final String acct in accounts) {
        final Match? m = _serviceAccountEmailRegex.firstMatch(acct);
        if (m != null) {
          if (m.group(1) == projectId) {
            matchingSa = acct;
            break;
          }
        } else {
          userAccount ??= acct;
        }
      }

      if (matchingSa != null) {
        print('  gcloud config set account $matchingSa');
      } else if (userAccount != null) {
        print('  gcloud config set account $userAccount');
      } else {
        print('  gcloud auth login   '
            '# log in with an account that has roles/owner on $projectId');
      }
      print('  oracular deploy all  # then re-run');
    } else {
      print('  gcloud config set account <email>');
      print('  oracular deploy all');
    }
    return false;
  }

  /// Enable the GCP services Cloud Run deployment depends on. Returns true
  /// when **all** required APIs are enabled (or were already enabled), false
  /// when at least one `gcloud services enable` call returns non-zero.
  ///
  /// Idempotent: gcloud silently returns success when an API is already
  /// enabled. Required APIs:
  ///   - `artifactregistry.googleapis.com` — needed for `docker push` to
  ///     `<region>-docker.pkg.dev`.
  ///   - `run.googleapis.com` — needed for `gcloud run deploy`.
  ///
  /// Failures here are typically auth / IAM issues
  /// (`serviceusage.services.enable` permission). Callers usually surface
  /// the failure as a warning (the user can manually enable the APIs in
  /// the console) rather than an abort because subsequent steps print
  /// clearer errors when the APIs really aren't on.
  Future<bool> ensureCloudRunPrerequisiteApis({
    required String projectId,
  }) async {
    const List<String> apis = <String>[
      'artifactregistry.googleapis.com',
      'run.googleapis.com',
    ];

    bool allOk = true;
    for (final String api in apis) {
      info('Ensuring GCP API `$api` is enabled...');
      final ProcessResult result = await _runner.run('gcloud', <String>[
        'services',
        'enable',
        api,
        '--project',
        projectId,
      ]);
      if (!result.success) {
        warn('Could not enable $api: ${result.stderr.trim()}');
        allOk = false;
      }
    }
    return allOk;
  }

  /// Ensure the Artifact Registry repository `<repository>@<region>` exists
  /// for [projectId]. Idempotent: a "already exists" / 409 response is
  /// treated as success.
  ///
  /// Returns `true` when the repository exists (created or pre-existing),
  /// `false` when the create call fails for a non-conflict reason
  /// (typically missing IAM role `roles/artifactregistry.admin` or the
  /// API not being enabled — in which case [ensureCloudRunPrerequisiteApis]
  /// already warned).
  ///
  /// Without this step, `docker push` against a fresh project fails with
  /// `name unknown: Repository "oracular" not found` because the registry
  /// path doesn't resolve to an existing repo.
  Future<bool> ensureArtifactRegistryRepository({
    required String projectId,
    required String repository,
    required String region,
  }) async {
    info('Ensuring Artifact Registry repository `$repository`@$region exists...');
    // First try to describe — fast path when the repo already exists.
    final ProcessResult describe = await _runner.run('gcloud', <String>[
      'artifacts',
      'repositories',
      'describe',
      repository,
      '--location=$region',
      '--project=$projectId',
      '--format=json',
    ]);
    if (describe.success) {
      info('  Repository `$repository` already exists.');
      return true;
    }

    // Create on NOT_FOUND (any other failure is auth / IAM and the caller
    // will see a clear error from the next step).
    final ProcessResult create = await _runner.run('gcloud', <String>[
      'artifacts',
      'repositories',
      'create',
      repository,
      '--repository-format=docker',
      '--location=$region',
      '--project=$projectId',
    ]);
    if (create.success) {
      success('  Repository `$repository` created in $region.');
      return true;
    }

    final String combined = '${create.stdout}\n${create.stderr}'.toLowerCase();
    if (combined.contains('already exists') || combined.contains('alreadyexists')) {
      info('  Repository `$repository` already exists (race-created).');
      return true;
    }

    warn('Could not create Artifact Registry repository `$repository`: '
        '${create.stderr.trim()}');
    return false;
  }

  /// Run all three preflights in order. Returns `true` only when the
  /// project is ready for `docker push` + `gcloud run deploy`.
  ///
  /// `ensureCloudRunPrerequisiteApis` is allowed to soft-fail (the
  /// `docker push` step prints a clearer error if the API really is
  /// off), so its result is **not** propagated as a hard failure.
  /// `verifyActiveGcloudAccount` and `ensureArtifactRegistryRepository`
  /// are hard gates.
  Future<bool> runAll({
    required String projectId,
    required String repository,
    required String region,
  }) async {
    if (!await verifyActiveGcloudAccount(projectId: projectId)) {
      return false;
    }
    if (!await ensureCloudRunPrerequisiteApis(projectId: projectId)) {
      warn('Could not confirm Artifact Registry / Cloud Run APIs are '
          'enabled. Continuing — push will fail with a clear error if '
          'they really are off.');
    }
    if (!await ensureArtifactRegistryRepository(
      projectId: projectId,
      repository: repository,
      region: region,
    )) {
      error('Could not ensure Artifact Registry repository '
          '`$repository` in $region exists. Push will fail without it.');
      return false;
    }
    return true;
  }
}
