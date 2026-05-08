## 3.3.9

### Added — `oracular deploy all` now ships the SSR / hydration server too

Previously `oracular deploy all` only invoked
`FirebaseService.deployAll()` (Firestore rules + Storage rules + web
build + hosting release deploy). Anyone using the arcane_jaspr SSR
template or the standalone arcane_server companion service had to
remember to run `script_deploy.sh` by hand afterwards — easy to miss,
and the resulting site had a stale backend serving the new frontend.

**Fix:** `handleDeployAll()`
(`oracular/lib/cli/handlers/deploy_handlers.dart:181-258`) now also
runs the new `ServerSetup.deployToCloudRun()` whenever
`config.createServer` is true. The order is:

1. **Firebase**: Firestore rules + Storage rules + web build + hosting.
2. **Server**: optional models snapshot → `gcloud auth configure-docker`
   → `docker build --platform linux/amd64` → `docker push` →
   `gcloud run deploy` → `gcloud run services describe` for the live URL.

Each phase is independent — a partial run still tells the user which
half shipped and which failed, and Cloud Run failures don't roll back
already-deployed Firebase rules. The deploy summary now lists the
service URL alongside the hosting URL.

### Added — `ServerSetup.deployToCloudRun()`

The Dart-side equivalent of the auto-generated `script_deploy.sh`,
exposed at `oracular/lib/services/server_setup.dart:444-606`. Returns
`String?` — the live Cloud Run URL on success (queried via
`gcloud run services describe`, since URLs embed a per-project hash
that's not predictable from project-id alone), `null` on any failure.

Each step uses `ProcessRunner.runWithRetry` so transient network /
docker errors get the same retry semantics as everything else in
Oracular. Early-exits cleanly when:
- `createServer` is false (no work to do).
- `firebaseProjectId` is missing (can't form the AR repository path).
- `<outputDir>/<server-package>/` doesn't exist (server was never
  scaffolded — directs the user to `oracular deploy server-setup`).

### Tests

- `test/unit/server_setup_test.dart:237-509` — **11 new tests** covering
  the success path (orders auth → build → push → deploy → describe),
  early-exits (no project ID, no server dir, server disabled), every
  short-circuit (auth/build/push/deploy fail), URL fallback when
  `describe` fails, and models snapshot copy success/failure.
- Total: **313/313 unit tests passed** (302 → 313, +11 new).

## 3.3.8

### Fixed — Step 5.12 hosting site creation auth ("Failed to authenticate")

`HostingSiteManager` was invoking `firebase hosting:sites:list` /
`hosting:sites:create` / `target:apply` **without passing
`GOOGLE_APPLICATION_CREDENTIALS`**, so firebase-tools fell through to
its stored login token at
`~/.config/configstore/firebase-tools.json`. The moment a user ran
`firebase logout` (or had never run `firebase login` to begin with),
step 5.12 failed with:

```
release: Error: Failed to authenticate, have you run firebase login?;
beta:    Error: Failed to authenticate, have you run firebase login?
```

**Two-part fix:**

1. **`HostingSiteManager` now accepts an `environment` constructor
   parameter** that is propagated to every `_runner.run('firebase', …)`
   call (`hosting_site_manager.dart:105-126`, `:131-153`,
   `:175-217`). The orchestrator wires it from the new public
   `FirebaseService.authEnvironment` getter
   (`firebase_service.dart:69-81`,
   `firebase_setup_orchestrator.dart:300-315`). Without an `environment`,
   `firebase` calls inherit only the parent shell env — exactly the
   broken path. With it, every hosting CLI call authenticates as the
   same SA the rest of Oracular uses.

2. **Self-heal for "Failed to authenticate" / "Command requires
   authentication" responses** (`hosting_site_manager.dart:268-303`).
   When `environment` is configured AND the create call still hits an
   auth error, Oracular now runs `firebase logout --force` (with the
   shell env, NOT the SA env, so firebase-tools can find and clear its
   own configstore) and retries the create. Logout failure is logged
   but doesn't block the retry. The pattern matches the same
   stale-login auto-recovery shipped for `apps:list` in 3.3.4.

The self-heal is intentionally gated on `environment != null`: without
that signal we cannot tell whether the user wants SA-based auth or
relies on a real `firebase login`, so wiping the login could lock them
out.

#### Tests

- `test/unit/hosting_site_manager_test.dart:271-385` — 4 new env-propagation
  tests verifying `listSites`, `ensureBetaSite`, `applyTargets` all forward
  the env, and that omitting it means `null` is forwarded (so child
  inherits parent shell env).
- `test/unit/hosting_site_manager_test.dart:388-560` — 4 new self-heal tests
  covering auth-failure → force-logout → retry, no-env-bypass,
  retry-also-fails, alternate "Command requires authentication" wording.

Validation: `dart analyze lib/` clean, `dart test test/unit/` 302/302 passed
(8 new + 294 prior).

---

## 3.3.7

### Added — Wizard rebuild flow + go-back navigation + storage prompt fix

Two new features and one polish item:

#### 1. `oracular rebuild` (and `oracular refresh` alias)

Re-scaffolds an existing project from its saved `config/setup_config.env`
**without touching Firebase / IAM / Cloud Run setup**. Use it after pulling
template updates, after a fresh `git clone`, or any time you need a clean
project skeleton without bouncing through the 12-step Firebase orchestrator
again.

```bash
# Run from inside the project root (auto-detects config/setup_config.env)
oracular rebuild

# Run from anywhere with explicit paths
oracular rebuild --output-dir ~/code/myapp --config ~/code/myapp/config/setup_config.env

# See exactly what will be deleted without doing it
oracular rebuild --dry-run

# Skip the confirmation prompt (e.g. for CI)
oracular rebuild --yes
```

The flow:

1. Loads `SetupConfig` from `setup_config.env`.
2. Shows a dry-run preview of which folders will be deleted.
3. Confirms (skip with `--yes`).
4. Deletes only `<appName>` (or `<webPackageName>` for Jaspr),
   `<appName>_models` (if enabled), `<appName>_server` (if enabled),
   `.oracular_deps/`, and `references/`. **Never** touches `.firebaserc`,
   `firebase.json`, `firestore.rules`, service-account JSON files, the
   saved config, `docs/`, or `GET_STARTED.md`.
5. Re-runs the scaffolding pipeline: `ProjectCreator` → `TemplateCopier` →
   models linking → `pub get` → `build_runner` → `ConfigGenerator` →
   `ServerSetup` → re-write `setup_config.env` + guides.

The interactive wizard now offers Rebuild as a top-level menu choice
alongside Start / Quit, so users don't need to remember the named
subcommand.

#### 2. Wizard "go back" navigation

Every prompt in the wizard now accepts `back`, `b`, `<`, or `:back` to
step backwards, and `quit` / `q` / `:q` / `exit` / `cancel` to abort
entirely. The keywords work in both `interact`-styled prompts and the
simple-prompt fallback (CI / non-TTY environments).

Yes/No prompts that want a back option get a third `↵ Back to previous
step` choice. Menu/theme prompts (showMenu, askTheme) get a `↵ Back`
appended to their option list.

The welcome screen now advertises both the action menu and the back/quit
keywords so the navigation hint is the first thing users see.

New API:
- `oracular/lib/utils/wizard_navigation.dart`:
  - `BackNavigation`, `CancelNavigation` exceptions
  - `WizardNav.askString()`, `WizardNav.askYesNo()`, `WizardNav.askTheme()`,
    `WizardNav.showMenu()` — drop-in replacements that throw
    `BackNavigation` when the user asks to retreat.

#### 3. Storage bucket prompt now uses modern naming

The wizard's "Initialize the default Storage bucket" question now references
the `<projectId>.firebasestorage.app` bucket name (the default for projects
created Sept 2024+) instead of the legacy `<projectId>.appspot.com` form.
The orchestrator already probes both names since v3.3.5, so this is purely
a copy fix to align the user-facing question with what oracular actually
provisions.

### New files

| Path | Purpose |
|------|---------|
| `oracular/lib/cli/handlers/rebuild_handlers.dart` | `handleRebuild` CLI entry point. |
| `oracular/lib/services/project_purger.dart` | `ProjectPurger` + `PurgeReport` — knows exactly which folders Oracular created and refuses to delete anything else (firebase config, service-account keys, saved `setup_config.env`, etc). |
| `oracular/lib/utils/wizard_navigation.dart` | `BackNavigation` / `CancelNavigation` exceptions and `WizardNav` prompt wrappers. |
| `oracular/test/unit/project_purger_test.dart` | 9 tests covering Flutter / Jaspr / models / server / idempotency / outputDir guard. |
| `oracular/test/unit/wizard_navigation_test.dart` | 7 tests covering keyword sets, exception messages, label content. |

### Modified

| File | Change |
|------|--------|
| `oracular/lib/cli/commands.dart` | Added `rebuild` and `refresh` (alias) commands with `--config`, `--output-dir`, `--yes`, `--dry-run` flags. |
| `oracular/lib/services/interactive_wizard.dart` | New `_chooseStartAction` action menu (Start / Rebuild / Quit). New `_runRebuildFlow` delegates to the shared CLI handler. Updated welcome banner with back/quit keyword hints. Storage bucket prompt now mentions `firebasestorage.app`. |

### Validation

- `dart analyze lib/` — clean (no new issues; only 2 pre-existing
  `dangling_library_doc_comments` warnings remain in `string_utils.dart`
  and `validators.dart`).
- `dart test test/unit/` — **294/294 passed** (278 prev + 16 new).

---

## 3.3.6

### Fixed — Step 5.11 `jaspr build` no longer fails on analyzer version conflict

When step 5.11 (Build web app) ran for a Jaspr project that also depends on
`arcane_models`, the build would fail with:

```
[CLI] [CRITICAL] Failed to connect to the build daemon. See the error above for more details.
```

That cryptic error masks a `pub get` resolution conflict:

- `jaspr_builder ^0.23.x` requires `analyzer ^10.0.0`.
- The published `artifact_gen ^1.x` and `fire_crud_gen ^1.x` pin
  `analyzer ^8.0.0`. They are pulled into the web app's build graph by
  `auto_apply: dependents` in the upstream `artifact` and `fire_crud`
  packages' `build.yaml`, even though the web app itself never defines
  any model classes.

These constraints are disjoint — `pub get` cannot resolve them in the same
project. Real model generation already happens inside the dedicated models
package (which does NOT depend on `jaspr_builder`), so the web app only
needs to consume the already-generated `.g.dart` files. It does not need
to re-run those builders.

This release vendors **pure no-op shim packages** for `artifact_gen` and
`fire_crud_gen` and wires them in via `dependency_overrides`:

- **New `templates/_vendor/artifact_gen/`** and
  **`templates/_vendor/fire_crud_gen/`** — minimal pubspecs that depend
  only on `build: ^4.0.0` (which allows analyzer 8 through 12), plus a
  single `Builder` factory each that returns a no-op `Builder`. Same
  package names, same library entrypoints, same factory function
  signatures as upstream — `build_runner` resolves the imports cleanly,
  produces no output, and `pub get` is happy.
- **`TemplateCopier._vendorJasprBuilderShims`** copies both shims to
  `<project>/.oracular_deps/` and injects `dependency_overrides` entries
  whenever a Jaspr template (`arcane_jaspr_app` or `arcane_jaspr_docs`)
  is scaffolded with models enabled.
- **`PlaceholderReplacer.addVendoredOverride`** is a generic helper used
  by both the new shim wiring and the existing `addJpatchOverride`.
  Handles header-or-no-header, idempotency, comment-aware duplicate
  detection.
- **`FirebaseService._ensureJasprBuilderShims`** runs as a self-healing
  pre-flight before every `jaspr build` step. It detects projects
  scaffolded by older Oracular versions, copies the shims, injects the
  overrides, and re-runs `dart pub get` automatically. Existing projects
  fix themselves on the next wizard run — no manual intervention.
- New `_findTemplatesBasePath` resolves `templates/_vendor/` for both
  `dart pub global activate . --source=path` (repo-relative) and
  installed `pub.dev` deployments (`Platform.script` traversal).

Test coverage:
- 6 new tests in `placeholder_replacer_test.dart` cover the new
  `addVendoredOverride`: empty pubspec, existing block, idempotency,
  jpatch wrapper compatibility, missing-file no-op, comment-only
  override line.
- All 278 unit tests pass.

End-user impact: any Jaspr web/docs project that links arcane_models —
new or existing — now builds cleanly on the first try. Step 5.11 no
longer fails with build-daemon errors that have no actionable
debugging path.

## 3.3.5

### Fixed — Step 5.7 default Storage bucket no longer fails on reserved-domain 403

When step 5.7 (Initialize Storage default bucket) ran, Oracular would call
`gcloud storage buckets create gs://<projectId>.appspot.com`. That fails
with HTTP 403 "verify domain ownership at search.google.com/search-console"
because `.appspot.com` and `.firebasestorage.app` are reserved Google
domains — only the Firebase Console (running with implicit ownership)
can provision default Firebase Storage buckets, and modern Firebase
projects (post-Sept 2024) get `<projectId>.firebasestorage.app` instead
of the legacy `<projectId>.appspot.com` anyway.

This release replaces the doomed `buckets create` path with a probe-
both-candidates + interactive console hand-off:

- **`ensureStorageBucket`** now probes BOTH `.firebasestorage.app` AND
  `.appspot.com` via `gcloud storage buckets describe`. Whichever exists
  is the default bucket. No more hard-coded `<projectId>.appspot.com`.
- If neither exists, returns `needsFirebaseInit=true` with the direct
  Firebase Console URL — never attempts a `buckets create` against
  reserved domains.
- **New `_handoffStorageBucketInit` orchestrator method** auto-opens
  `https://console.firebase.google.com/project/<projectId>/storage`
  in the user's browser, prints the exact button-by-button sequence
  ("Get started" → "Start in production mode" → location → "Done"),
  then re-probes `gcloud storage buckets describe` after the user
  confirms. Up to 4 retry rounds with 5-second waits cover the
  ~30s Firebase backend provisioning window.
- New `LinkOpener` import wires the orchestrator into the existing
  cross-platform URL opener (`open` / `xdg-open` / `cmd /c start`).
- Updated stub-runner tests cover all three new probe paths
  (modern bucket exists, legacy fallback, both missing → hand-off).

End-user impact: step 5.7 either succeeds silently (bucket already
exists) or prints a clear "click these 5 buttons" workflow with the
URL auto-opened — instead of failing hard with a confusing
search-console domain-verification error that the user has no way
to resolve.

## 3.3.4

### Fixed — Step 5.5 PERMISSION_DENIED root-causing + auto-recovery

When step 5.5 hit `firebase apps:list WEB` PERMISSION_DENIED the wizard
would burn 56 seconds on backoff retries (8s + 16s + 32s) and then bail
out with a generic "grant `roles/firebase.viewer`" hint that didn't
explain *why* the SA — which the IAM gate had just verified — couldn't
list apps.

The actual cause is almost always one of two things, neither of which
the previous error message identified:

1. **Stale `firebase login` token.** `firebase-tools` prefers the login
   token at `~/.config/configstore/firebase-tools.json` over
   `GOOGLE_APPLICATION_CREDENTIALS`. So a developer who ran
   `firebase login` once as their personal account hits PERMISSION_DENIED
   on every Oracular run, even though `gcloud …` calls (which DO honor
   `GOOGLE_APPLICATION_CREDENTIALS`) succeed. The IAM gate verifies the
   service-account, then step 5.5 silently runs as the wrong user.
2. **Wrong service account.** Multiple SAs in the project, the gate
   verified one, but the JSON file Oracular found is for another.

This release self-heals (1) and exposes (2):

- **`getActiveFirebaseAccount()`** parses `firebase login:list --json`
  to identify which account the Firebase CLI is actually using.
- **First-defense auto-recovery in `_runFirebaseWithRecovery`:** on
  the first PERMISSION_DENIED, if the firebase login email differs
  from the SA email, automatically run `firebase logout <stale-account>`
  and retry. firebase-tools then falls back to ADC and uses
  Oracular's SA. Zero user intervention.
- **Reduced wasted retries:** PERMISSION_DENIED now retries at most
  once (10s wait) instead of 3 times (8s+16s+32s = 56s). The IAM gate
  already polls up to 60s for IAM propagation, so by the time
  `_runFirebaseWithRecovery` sees PERMISSION_DENIED, propagation is
  done — more retries can't fix what's wrong.
- **`_logCredentialDiagnostics()`** dumps the four identities Oracular
  can see (SA file, SA email, active gcloud account, firebase CLI
  login) AND the last 50 lines of `firebase-debug.log` verbatim
  *before* surfacing the failure. The user no longer has to
  `cat firebase-debug.log` themselves to find the actual API
  response — Oracular prints it inline.
- **Multi-line `underlying error:` output:** the verbose log now
  prints every line of `_collectFirebaseFailureContext` instead of
  truncating to the first line ("See firebase-debug.log for more
  info."), so the actual structured error from the Firebase
  Management API response is visible without digging into the log
  file.

After this fix, the failure mode you saw goes away because:
- If the cause is a stale firebase login → auto-logout + retry → success.
- If the cause is genuine missing IAM → diagnostics show the SA email,
  the firebase CLI login email, and the actual `PERMISSION_DENIED`
  message from `firebase-debug.log` so you can tell at a glance which
  identity needs the role.

## 3.3.3

### Fixed — Step 5.4 IAM gate now verifies Firebase-specific permissions

The IAM gate in step 5.4 only probed `serviceusage.services.enable` —
which a service account with `roles/serviceUsageAdmin` happily passes
even though it lacks `firebase.apps.list`/`firebase.apps.create`. The
gate would then green-light step 5.4, the propagation poll would never
succeed (because the API *was* enabled, the *caller* just couldn't see
it), step 5.5 would run, and the user would land on a Retry/Skip/Abort
prompt with no usable next step.

This release closes the gap:

- **New `FirebaseService.canListFirebaseApps`** runs
  `firebase apps:list WEB --json` against the project as the active
  credential and classifies the result with the existing failure
  classifier — so `permissionDenied` is detected the same way
  step 5.5 would detect it.
- **The IAM gate now probes both** `serviceusage.services.enable`
  *and* `firebase.apps.list`. If either is missing, the gate fails
  fast and the auto-grant flow is triggered (instead of waiting
  until step 5.5 to discover the missing role).
- **Auto-grant + post-grant verification** now polls *both*
  permissions with exponential backoff up to ~60s, so the orchestrator
  waits for IAM propagation rather than racing it.
- **`_waitForFirebaseManagementApi`** now exits early on
  `permissionDenied` instead of burning the whole 47s budget — a
  missing role will not be fixed by waiting.
- **`_runFirebaseWithRecovery`** retries `permissionDenied` once with
  a 15s wait. This catches the narrow window where step 5.4 just
  granted the role and the binding hasn't propagated to the IAM
  edge for the calling project yet.
- **The required-roles list** now explicitly includes
  `roles/firebase.admin` so the auto-grant flow grants what
  `firebase apps:list` actually needs (not just `serviceUsageAdmin`).

After this fix, the "stuck at step 5.4 propagation poll → step 5.5
fails with `permissionDenied`" path is replaced by:
1. Step 5.4 detects the missing `firebase.apps.list` permission
   *before* enabling APIs.
2. Auto-grants `roles/firebase.admin` (and the rest of the bundle).
3. Polls until both permissions are visible to the caller.
4. Step 5.5 then runs cleanly without bouncing the user out.

## 3.3.2

### Fixed — Step 5.5 (Configure Firebase client wiring) auto-recovery

Step 5.5 used to abort the wizard with a "Run `oracular deploy
firebase-setup-full`" hint whenever `firebase apps:list WEB` failed —
the most common cause being that the Firebase Management API was just
enabled in step 5.4 but had not yet propagated. The wizard would dump
the user out, even though the only fix was "wait 30 seconds and re-run".

This release makes step 5.5 self-healing:

- **`_runFirebaseWithRecovery`** wraps every `firebase --json` call
  (`apps:list`, `apps:create`, `apps:sdkconfig`) in an auto-retry loop
  that:
  - reads `firebase-debug.log` to extract the structured error envelope
    from the Firebase Management API (the CLI hides this behind the
    generic "see firebase-debug.log for more info" banner);
  - **classifies** the error into `serviceDisabled`,
    `permissionDenied`, `transient`, or `unknown`;
  - **auto-runs `gcloud services enable firebase.googleapis.com`** and
    waits for propagation when it sees `SERVICE_DISABLED` (no
    user intervention required);
  - **retries with exponential backoff** (1s, 2s, 4s, 8s) on transient
    errors (5xx, `DEADLINE_EXCEEDED`, `ECONNRESET`, `socket hang up`);
  - surfaces a concrete IAM hint for `PERMISSION_DENIED`.
- **`enableFirebaseCoreApis`** now polls `firebase apps:list` until the
  Firebase Management API actually answers (capped exponential backoff,
  up to ~30s), closing the propagation gap between step 5.4 and 5.5.
- The step 5.5 failure message now explains the *actual* cause from
  `firebase-debug.log` instead of a one-size-fits-all "run
  firebase-setup-full" suggestion. The hint includes "wait 30-60s and
  retry" as the most common fix because the auto-recovery has already
  handled the API-not-enabled case.

### Added
- 14 new unit tests pinning down the failure classifier
  (`FirebaseFailureKind`) and structured-error parser
  (`firebaseErrorForTest`) so future regressions are caught in CI:
  matches `SERVICE_DISABLED`, `PERMISSION_DENIED`, `503`,
  `DEADLINE_EXCEEDED`, `ECONNRESET`, `socket hang up`, ANSI-prefixed
  spinner JSON.

## 3.3.0

### Added — End-to-End Firebase Setup
- **`FirebaseSetupOrchestrator`** drives a full 12-sub-step Firebase setup so
  `oracular` no longer stops after just `firebase login` + `flutterfire
  configure`. Sub-steps: firebase login, gcloud auth (server only), billing
  check, **enable required Firebase APIs**, client wiring (FlutterFire or
  Jaspr JS SDK injection), Firestore default DB, Storage default bucket,
  auth providers (email/password + Google), deploy Firestore + Storage
  rules, build web bundle, ensure `<project>-beta` site, deploy hosting
  (release + beta).
- **Fail-fast with Retry / Skip / Abort prompt.** When any sub-step fails,
  the wizard now stops, prints the reason + suggested fix, and asks
  whether to retry the same step, skip it, or abort the whole run. You
  can fix something in another terminal and hit `r` to re-run just the
  failed step.
- **Auto-enable Firebase APIs upfront** (`enableFirebaseCoreApis`):
  `firebase.googleapis.com`, `firestore.googleapis.com`,
  `firebasestorage.googleapis.com`, `firebasehosting.googleapis.com`,
  `identitytoolkit.googleapis.com`, `serviceusage.googleapis.com`. This
  prevents downstream `SERVICE_DISABLED` errors and the `firebase
  apps:list` failures that broke Jaspr JS SDK injection.
- **Billing-absent detection.** Firestore + Storage steps now detect the
  "billing account is disabled in state absent" error and surface a
  clean message pointing at the Blaze upgrade URL instead of a raw
  gcloud stack trace.
- **8 new CLI subcommands** so any failed step is independently
  re-runnable:
  - `oracular check billing`
  - `oracular deploy firebase-setup-full` (alias: `firebase-setup`)
  - `oracular deploy hosting-init`
  - `oracular deploy firestore-init`
  - `oracular deploy storage-init`
  - `oracular deploy auth-providers`
  - `oracular deploy artifact-cleanup`
  - `oracular deploy cloudrun-prune`
- **Hosting beta site auto-creation** via `HostingSiteManager` —
  `<project>-beta` site is created and `firebase target:apply hosting
  beta` is wired automatically.
- **Artifact Registry / Cloud Run cleanup** baked into both the wizard
  and the generated `script_deploy.sh`. Ships
  `templates/arcane_server/cleanup-policy.json` (keep 5 most recent +
  delete >30 days) and prunes Cloud Run revisions to the last 3.
- **"What was deployed" summary** at the end of the wizard with live
  release/beta URLs, Firebase + GCP console links, and the Cloud Run
  URL when applicable. Jaspr-aware copy ("Jaspr docs site" / "Jaspr
  web app" / "Flutter web app").
- **Post-creation checklist now filters out completed steps** instead
  of always printing the same boilerplate. Only skipped or partial
  steps remain.

### Fixed
- Wizard previously did `firebase login` + `flutterfire configure` and
  declared victory — leaving you with no deployed site, no beta site,
  no Firestore database, no Storage bucket, no rules deployed, and no
  cleanup policies on the server. Now every one of those is a real
  step you can run, retry, or skip.
- `flutterfire configure` for Jaspr templates failed with "Failed to
  list Firebase WEB apps" when the Firebase Management API was not
  enabled. Fixed by always enabling that API in step 5.4 *before*
  calling `firebase apps:list`.
- `gcloud firestore databases describe` failed with `SERVICE_DISABLED`
  on first-run projects. Fixed by enabling `firestore.googleapis.com`
  upfront and by detecting the API-not-enabled error with a precise
  fix-hint.
- `gcloud storage buckets create` failed with billing-absent on Spark
  projects. Fixed: the wizard now detects this early and instructs you
  to upgrade to Blaze with the exact console URL.
- `oracular version` reported a hard-coded `2.0.0` instead of reading
  from `lib/version.dart`. Fixed both in `bin/main.dart` and the
  `commands.dart` version handler.

### Changed
- `firebase-setup` is now an alias for `firebase-setup-full` so the
  shorter command runs the new end-to-end flow.
- `_offerFirebaseSetup` in the wizard is now a thin driver around the
  orchestrator; per-substep counters render `5.1` / `5.2` / `6.1`
  inline labels.
- Default `runAll` behavior is **fail-fast** (abort on first failure
  unless an `onFailure` handler returns `skip` or `retry`). Pass
  `onFailure: (_, {required attempt}) async => FailureAction.skip` to
  opt into the legacy "always continue" semantics.

### Tests
- 239 unit tests passing (up from 135 baseline).
- New test suites: `firebase_setup_orchestrator_test.dart` (17 tests),
  `firebase_billing_service_test.dart`,
  `firebase_initializer_test.dart`, `hosting_site_manager_test.dart`,
  `artifact_cleanup_service_test.dart`, plus expanded coverage on
  `setup_config_test.dart`, `setup_guidance_test.dart`,
  `server_setup_test.dart`, and `firebase_service_test.dart`.

## 3.1.2

### Added
- **Welcome banner** now shows the running Oracular version (e.g. `Arcane
  Template System  ·  v3.1.2`). Section headers in the wizard's reset-viewport
  also show `v$version  ·  Step N of 5`.
- **`docs/` folder** is generated at the root of every created project with a
  full set of how-to guides tailored to your config:
  - `README.md` (table of contents + project-at-a-glance summary)
  - `01-getting-started.md` - run the project, install deps, wire Firebase
  - `02-commands.md` - every Oracular subcommand and pubspec script available
  - `03-project-structure.md` - folder layout for the chosen template
  - `04-development.md` - hot reload, code-gen, adding routes/screens
  - `05-firebase.md` (or `Firebase Later` when not enabled)
  - `06-deployment.md` - hosting, firestore, storage rules
  - `07-server.md` - service account flow + Cloud Run
  - `08-models.md` - artifact patterns + path dependencies
  - `09-troubleshooting.md` - jaspr / arcane_auth_jaspr / FlutterFire fixes
  - `10-resources.md` - upstream docs links
- New `oracular open docs` target opens the docs folder in the OS file
  browser. `oracular guide` regenerates both `GET_STARTED.md` and `docs/`.

### Fixed
- **`arcane_auth_jaspr` no longer auto-uncommented** when Firebase is enabled.
  The published `arcane_auth_jaspr` is pinned to `jaspr ^0.22.0` while the
  Jaspr template uses `jaspr ^0.23.0`, so auto-enabling it produced
  `version solving failed` errors during `dart pub get`. The base Jaspr
  template is now a clean husk with **no auth dependency** by default.
- Jaspr template README updated to reflect the correct Firebase wiring path
  for `jaspr 0.23.x` (use the JS SDK directly or call `arcane_server`
  endpoints; do not add `arcane_auth_jaspr` until a `0.23.x`-compatible
  release ships).

## 3.1.1

### Changed
- **Service account key prompt**: instead of asking the user to type a long
  absolute path (which the terminal input clips), Oracular now opens the
  destination folder in Finder/Explorer/file manager, instructs the user to
  drop their `*.json` key file into that folder, and auto-detects/renames it
  to `service-account.json`. Press Enter when done, or type `skip` to add it
  later. Multiple JSON files are disambiguated with a numbered picker.
- **Multi-select / picker viewport**: each major section in the wizard
  (Template Selection, Target Platforms, Additional Packages, Cloud Services)
  now starts with a clean screen and a compact context strip showing the
  choices made so far. Fixes the issue where pressing arrow keys inside the
  Target Platforms multi-select made the console "go up" and look awful as
  the prompt redrew over previously printed help text.

## 3.1.0

### Added
- Wizard intro now asks for the **target location** up front. Press Enter to use
  the current directory, type an absolute or relative path, or use `~` as a
  shortcut for your home directory. Missing directories can be auto-created.
- Pure-Dart `jpatch` shim vendored under `templates/_vendor/jpatch/` and
  auto-injected into Jaspr/Dart-CLI projects that depend on `arcane_models`,
  so pure-Dart targets resolve **without** dragging in the Flutter SDK.
- Spinner prompts now accept a `failedMessage` so failed steps render an `✗`
  with stderr output instead of a misleading `✓`.

### Changed
- Templates upgraded to `arcane_jaspr ^3.3.0` with `arcane_jaspr_shadcn` pulled
  via git from the monorepo. `app.dart` switched from `child:` to the new
  `home:` API.
- `arcane_jaspr_docs` template now references `arcane_jaspr_shadcn` and
  `arcane_lexicon` via git deps instead of brittle `.oracular_deps/...` paths.
- `arcane_models` template no longer pulls in `arcane_admin` (which dragged
  Flutter into pure-Dart consumers).
- `arcane_server` template uses `listenPortFromEnvironment()` from current
  `google_cloud`.
- Pinned `package_info_plus` / `launch_at_startup` / etc. across templates to
  versions that actually resolve, removed unused `interact` dep from
  `arcane_cli_app`.
- Spinner-wrapped CLI processes now run in non-interactive mode so they can't
  deadlock waiting for TTY input behind the spinner.

### Fixed
- **Firebase web app provisioning**: switched all `firebase apps:*` calls to
  `--json` mode with explicit success/failure detection, fixing the
  `Failed to create Firebase web app` / `Failed to list Firebase web apps`
  cascade when configuring FlutterFire for Jaspr projects.
- **Wizard reporting failures as success**: the wizard now tracks failed steps
  and prints a `✗ Project Created With Issues` banner with the list of failed
  steps when anything went wrong, instead of always printing the success box.
- **Spinner showing `✓ Done` on failure**: the spinner now renders `✗` with
  the actual error message on failure.
- **Jaspr + server + models permutation**: end-to-end resolution and
  compilation now works (no Flutter SDK leakage) and is covered by integration
  tests.
- `addModelsDependency` no longer skips the dependency when the package name
  appears in a comment, and no longer crashes on regex matches that span
  newlines.

## 3.0.0

### Added
- New `oracular gitignore` command to add the standard `.gitignore` to any project
  - Use `--force` or `-f` to overwrite an existing `.gitignore`
- Comprehensive `.gitignore` added to all templates with Jaspr support
- Jaspr-specific ignores: `.jaspr/`, `web/main.dart.js`, `web/main.dart.js.deps`, `web/main.dart.js.map`, `web/main.dart.mjs`

### Fixed
- Jaspr and models package creation now deletes the auto-generated `example/` folder

## 2.2.2

### Fixed
- Template download failing due to case sensitivity in GitHub archive prefix (`oracular-master` vs `Oracular-master`)

## 2.2.0

- **Template Updates - arcane_jaspr_docs**:
  - Full theme switching system with 18 theme presets (colors, neutrals, OLED)
  - CSS variable-based theming using `ArcaneThemeProvider`
  - Theme persistence via localStorage
  - Search functionality with keyboard navigation
  - Code block copy buttons
  - Stateful theme toggle (sun/moon icons)
  - Updated sidebar with `ArcaneSideContent` and modern styling
  - Removed index.html for static mode compatibility

- **Template Updates - arcane_jaspr_app**:
  - Added shared `AppHeader` component with theme toggle
  - Stateful `App` component with dark/light mode switching
  - CSS variable-based theming using `ArcaneThemeProvider`
  - Theme persistence via localStorage
  - Updated screens to use shared header (DRY)
  - Added `AppConstants` class for centralized configuration
  - Theme initialization script in index.html (prevents flash)
  - Modern scrollbar and focus state styling

## 2.1.0

- **CLI Improvements**:
  - Interactive prompts for project configuration
  - Template-specific next steps in success message

## 2.0.0

- **Template Distribution**: Templates are now downloaded from GitHub at runtime
  - No longer bundled in the package - keeps install size small
  - Cached locally at `~/.oracular/templates/`
  - Automatic version checking and updates
- **New `templates` command**: Manage template cache
  - `oracular templates status` - Show cache status
  - `oracular templates update` - Download/update templates
  - `oracular templates clear` - Clear the cache
  - `oracular templates path` - Show cache location
- **CLI Framework**: Migrated to darted_cli
- **Script Runner**: Fuzzy matching with abbreviation support
- **Complete rewrite** of project scaffolding system

## 1.0.0

- Initial version.
