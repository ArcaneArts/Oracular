# Plan: End-to-End Firebase Setup In The Oracular Wizard (Flutter + Jaspr)

- **Date**: 2026-05-07
- **Version**: v1
- **Owner**: Oracular CLI maintainers
- **Status**: In Progress

---

## 1. Problem Statement

Today, when a user runs `oracular` and walks through the wizard, the Firebase
phase asks for the project ID, then runs only four commands behind a spinner:

1. `firebase login` (or service-account auth check) — `oracular/lib/services/interactive_wizard.dart:658-672`
2. `gcloud auth login` (only if Cloud Run was enabled) — `oracular/lib/services/interactive_wizard.dart:674-689`
3. `flutterfire configure` — `oracular/lib/services/interactive_wizard.dart:691-708`
4. `gcloud services enable artifactregistry/run` (only if Cloud Run was enabled) — `oracular/lib/services/interactive_wizard.dart:710-725`

Then the wizard prints a checklist that *tells* the user to run more
`oracular deploy …` commands later. **Nothing else is actually executed.**

Capabilities that exist as code but are never wired to the wizard:

- Hosting release deploy — `oracular/lib/services/firebase_service.dart:647-679`
- Hosting beta deploy — `oracular/lib/services/firebase_service.dart:682-698` (the `<project>-beta` site itself is never auto-created; only a hint at `oracular/lib/utils/setup_guidance.dart:128-135`)
- Firestore rules deploy — `oracular/lib/services/firebase_service.dart:523-545`
- Storage rules deploy + storage-not-init detection — `oracular/lib/services/firebase_service.dart:553-598`
- Generated `script_deploy.sh` — `oracular/lib/services/server_setup.dart:153-214` and `templates/arcane_server/script_deploy.sh` (only pushes images, never deletes)

Capabilities with **no code at all**:

- Spark vs Blaze plan detection
- Beta hosting site auto-creation (`firebase hosting:sites:create`)
- Default Firestore database creation (`gcloud firestore databases create`)
- Default Storage bucket creation
- Firebase Auth provider enablement (Email/Password, Google)
- Artifact Registry cleanup policy
- Cloud Run revision retention

User report: *"I enter the firebase id and it just does some things and
finishes. No site deployed, no beta site deployed, no Blaze plan setup, no
Google server setup for removing old builds, like NOTHING."*

---

## 2. Goals & Non-Goals

### Goals

1. After the wizard finishes with Firebase enabled (any template), the user has:
   - Firestore default database created (or confirmed existing)
   - Storage default bucket created (or confirmed existing)
   - Firestore + Storage rules deployed
   - Web build produced (template-aware: `flutter build web` or `jaspr build`)
   - Hosting `release` site deployed and live URL printed
   - Hosting `beta` site (`<project>-beta`) created and deployed
   - Auth providers offered (Email/Password, Google) with console hand-off when API automation isn't possible
2. When the server template is enabled and the user is on Blaze:
   - Artifact Registry repository created with cleanup policy
   - Cloud Run service deployed
   - Cloud Run revision retention policy applied
3. The wizard **explicitly walks through every step** with progress
   indicators, per-step confirmation prompts (sensible defaults), and a
   final summary listing every URL, action taken, and any step skipped.
4. Each new sub-step is **independently re-runnable** as a discrete CLI
   command so users can fix a single failure without re-running the wizard.

### Non-Goals

- Replace `flutterfire configure` with custom logic
- Manage IAM roles or per-user permissions on the Firebase project
- Fully automate OAuth consent screen configuration (browser-only flow)
- Remove or rewrite existing template payloads
- Support non-Firebase backends

---

## 3. Jaspr Coverage Matrix (Static + Client + Future SSR)

The fix must cover **all** template types. Behavior per template:

| Template | `template.is*` | Build Cmd | Hosting Public Path | Firebase Wiring | Notes |
|----------|---------------|-----------|---------------------|-----------------|-------|
| `arcaneTemplate` (Flutter) | `isFlutterApp` | `flutter build web --release` | `<appName>/build/web` | `flutterfire configure` (writes `firebase_options.dart`) | Standard Flutter web flow |
| `arcaneBeamer` (Flutter) | `isFlutterApp` | same | same | same | Same as above |
| `arcaneDock` (Flutter desktop) | `isFlutterApp` | n/a (no web target) | n/a | optional native plugins | Hosting auto-skipped; Firestore/Storage/Auth still apply |
| `arcaneCli` (Dart CLI) | `isDartCli` | n/a | n/a | Admin SDK on server | Hosting + FlutterFire auto-skipped; Firestore/Storage/Auth still apply |
| `arcaneJaspr` (Jaspr **client** SPA) | `isJasprApp && !isJasprDocs` | `jaspr build` | `<webPackageName>/build/jaspr` | Firebase JS SDK injected into `<webPackageName>/web/index.html` via `_configureFirebaseJsSdk` (`oracular/lib/services/firebase_service.dart:908-1030`) | Hydrated SPA; same hosting deploy as static |
| `arcaneJasprDocs` (Jaspr **static** site) | `isJasprApp && isJasprDocs` | `jaspr build` (mode: static) | `<webPackageName>/build/jaspr` | Same JS SDK injection | Pre-rendered HTML; SEO-friendly; client-side Firestore/Auth still works on hydration |
| Jaspr **server** mode (future) | not yet a template | `jaspr build --mode server` | n/a (Dart binary) | Admin SDK on server | Will reuse the same Cloud Run flow as `arcane_server` once a template ships |

Cross-cutting Jaspr facts already encoded in the codebase:

- `template.isJasprApp` is true for both `arcaneJaspr` and `arcaneJasprDocs` (`oracular/lib/models/template_info.dart:122-130`)
- `template.isJasprDocs` is true only for the static docs template
- `FirebaseService.buildWeb` already runs `jaspr build` for Jaspr (`oracular/lib/services/firebase_service.dart:617-625`)
- `ConfigGenerator._hostingPublicPath` already resolves to `<webPackageName>/build/jaspr` for Jaspr (`oracular/lib/services/config_generator.dart:77-82`)
- `FirebaseService.supportsWebHosting` already returns true for Jaspr OR Flutter+web (`oracular/lib/services/firebase_service.dart:739-742`)
- `_configureFirebaseJsSdk` already targets the Jaspr `web/index.html` path (`oracular/lib/services/firebase_service.dart:916-925`)

What this plan must **add** for Jaspr:

1. The orchestrator must invoke `buildWeb` and `deployHostingRelease` /
   `deployHostingBeta` for **all** Jaspr templates (currently nothing
   invokes them from the wizard at all).
2. The wizard's progress copy and final summary must say "Jaspr docs site"
   for `isJasprDocs`, "Jaspr web app" for client Jaspr, and "Flutter web app"
   for Flutter — not generic "web app" — so users immediately recognize what
   was deployed.
3. `HostingSiteManager` and the `firebase target:apply` step must work
   identically for all templates because the public path is already
   template-aware in `firebase.json`.
4. For Jaspr templates, the orchestrator must **not** invoke FlutterFire
   (it would crash because there's no Flutter SDK in the project). The
   existing branch in `FirebaseService.configureFlutterFire`
   (`oracular/lib/services/firebase_service.dart:197-199`) routes Jaspr
   through `_configureFirebaseJsSdk` instead — the orchestrator must reuse
   that same dispatcher rather than calling FlutterFire directly.
5. For Jaspr **static** docs, the post-deploy summary must mention SEO
   benefits and that page-level Firebase code only runs after hydration.
6. The generated `GET_STARTED.md` (via `SetupGuidance`) must surface the
   correct local-dev command per Jaspr mode (`jaspr serve` for both, but
   call out static rebuild on content changes for `isJasprDocs`).

---

## 4. Current State Map (Code References)

| Capability | Already Implemented At | Wired Into Wizard? |
|------------|------------------------|--------------------|
| Project ID prompt | `oracular/lib/services/interactive_wizard.dart:425-429` | Yes |
| Firebase login | `oracular/lib/services/firebase_service.dart:134-150` | Yes |
| `gcloud` login | `oracular/lib/services/firebase_service.dart:153-180` | Yes (Cloud Run only) |
| `flutterfire configure` (Flutter) / Firebase JS SDK (Jaspr) | `oracular/lib/services/firebase_service.dart:182-206`, `:908-1030` | Yes |
| `firebase apps:list` / `apps:create` | `oracular/lib/services/firebase_service.dart:210-311` | Yes (via FlutterFire) |
| Firestore rules deploy | `oracular/lib/services/firebase_service.dart:523-545` | **No** |
| Storage rules deploy (with not-init detection) | `oracular/lib/services/firebase_service.dart:553-598` | **No** |
| `flutter build web` / `jaspr build` | `oracular/lib/services/firebase_service.dart:601-644` | **No** |
| Hosting release deploy | `oracular/lib/services/firebase_service.dart:647-679` | **No** |
| Hosting beta deploy | `oracular/lib/services/firebase_service.dart:682-698` | **No** |
| `gcloud services enable artifactregistry / run` | `oracular/lib/services/firebase_service.dart:745-787` | Yes (Cloud Run only) |
| Generated `firebase.json` with `release` & `beta` targets (Jaspr-aware path) | `oracular/lib/services/config_generator.dart:16-117` | Yes (file written) |
| `script_deploy.sh` (generated) | `oracular/lib/services/server_setup.dart:153-214` | Yes (file written, not executed) |
| Beta site creation hint (text only) | `oracular/lib/utils/setup_guidance.dart:128-135` | Yes (printed) |
| Setup config persistence | `oracular/lib/models/setup_config.dart:127-148` | Yes |

---

## 5. Proposed Architecture

### 5.1 New Services (under `oracular/lib/services/`)

1. **`firebase_billing_service.dart`** → `FirebaseBillingService`
   - `checkBlazeStatus()` — `gcloud beta billing projects describe <project> --format=json` and read `billingEnabled`. Returns `BlazeStatus { enabled, notEnabled, unknown }`.
   - `guideUpgrade()` — opens Firebase billing console URL, prints consequence list ("Hosting works on Spark; Cloud Run / scheduled cleanup require Blaze"), waits for user, re-checks (≤ 3 loops).
   - Used by orchestrator to gate Cloud Run / cleanup setup, regardless of template.

2. **`firebase_initializer.dart`** → `FirebaseInitializer`
   - `ensureFirestoreDatabase({ required String region })` — describe → create on `NOT_FOUND`. Default region `nam5`.
   - `ensureStorageBucket()` — describe → create on missing. Drives the existing `_isStorageNotInitialized` recovery.
   - `enableAuthProviders({ required Set<AuthProvider> providers })` — best-effort via Identity Toolkit / `gcloud identity providers`; falls back to console hand-off (always succeeds, never blocks).

3. **`hosting_site_manager.dart`** → `HostingSiteManager`
   - `listSites()`, `ensureReleaseSite()`, `ensureBetaSite()`, `applyTargets()`.
   - `ensureBetaSite` runs `firebase hosting:sites:create <project>-beta` and is idempotent (treats `409 ALREADY_EXISTS` as success).
   - `applyTargets` runs `firebase target:apply hosting release <project>` and `firebase target:apply hosting beta <project>-beta`.
   - **Template-agnostic**: works identically for Flutter web, Jaspr client, Jaspr static.

4. **`artifact_cleanup_service.dart`** → `ArtifactCleanupService`
   - `ensureRepository({ region, repository })` — idempotent `gcloud artifacts repositories create`.
   - `applyCleanupPolicies({ keepRecent, deleteOlderDays })` — writes a temp JSON policy and applies via `gcloud artifacts repositories set-cleanup-policies`.
   - `capCloudRunRevisions({ keepRevisions, region, service })` — keeps N most-recent revisions; deletes the rest with `--quiet`. Skips traffic-serving revisions.

5. **`firebase_setup_orchestrator.dart`** → `FirebaseSetupOrchestrator`
   - High-level coordinator the wizard (and the new `oracular deploy firebase-setup-full` command) calls.
   - Runs each step in order, captures `SetupStepResult { success | skipped | failed, message }`, emits `WizardSubStep` events back to the UI.
   - Handles dependency ordering: never attempts Cloud Run setup on Spark; never attempts hosting deploy if `supportsWebHosting(config)` is false; uses `_configureFirebaseJsSdk` for Jaspr instead of FlutterFire.

### 5.2 Configuration Additions

Add to `oracular/lib/models/setup_config.dart`:

```dart
final bool deployHostingRelease;     // default true if supportsWebHosting
final bool deployHostingBeta;        // default true if supportsWebHosting
final String firestoreRegion;        // default 'nam5'
final bool initializeFirestore;      // default true
final bool initializeStorage;        // default true
final bool enableEmailAuth;          // default true
final bool enableGoogleAuth;         // default true (console hand-off)
final bool requireBlaze;             // default true if createServer || setupCloudRun
final bool setupArtifactCleanup;     // default true if setupCloudRun
final int  artifactKeepRecent;       // default 5
final int  artifactDeleteOlderDays;  // default 30
final int  cloudRunKeepRevisions;    // default 3
```

Persist in `setup_config.env` via the existing round-trip (extend `saveToFile` / `loadFromFile`), surface in `toDisplayMap`.

### 5.3 Wizard Flow Rework

Replace `_offerFirebaseSetup` (`oracular/lib/services/interactive_wizard.dart:638-736`) with a sub-step driver:

```
Step 5 of 6 · Firebase Setup
  5.1  Authenticate with Firebase
  5.2  Authenticate with Google Cloud
  5.3  Verify billing plan (Spark / Blaze)
  5.4  Configure Firebase client wiring          ← FlutterFire OR Jaspr JS SDK
  5.5  Initialize Firestore default database
  5.6  Initialize Storage default bucket
  5.7  Enable Authentication providers
  5.8  Deploy Firestore + Storage rules
  5.9  Build web app                             ← flutter build web OR jaspr build
  5.10 Create & target beta hosting site
  5.11 Deploy hosting (release)
  5.12 Deploy hosting (beta)

Step 6 of 6 · Server & Cleanup                   (only if createServer / setupCloudRun)
  6.1  Enable Cloud Run / Artifact Registry APIs
  6.2  Create Artifact Registry repository
  6.3  Apply Artifact Registry cleanup policy
  6.4  Build & push server container
  6.5  Deploy to Cloud Run
  6.6  Cap Cloud Run revisions
```

Each sub-step:

- Renders via `UserPrompt.printStepIndicator` + a one-liner explanation
- Asks yes/no with sensible default
- Runs the work behind the existing spinner
- Records `_WizardFailure` with a `Fix:` hint pointing at the matching CLI command on failure or skip
- Steps 5.4 / 5.9 / 5.10–5.12 dispatch on `template.isJasprApp` so Jaspr templates use the right code paths

Final summary gains a "What was deployed" block listing release URL, beta
URL, Firestore console URL, Storage console URL, and (if applicable) the
Cloud Run service URL.

### 5.4 New / Updated CLI Commands

| Command | Calls | Purpose |
|---------|-------|---------|
| `oracular deploy firebase-setup-full` | `FirebaseSetupOrchestrator.runAll()` | The new end-to-end flow, runnable outside the wizard |
| `oracular deploy hosting-init` | `HostingSiteManager.ensureBetaSite()` + `applyTargets()` | Create the beta site & target mapping |
| `oracular deploy firestore-init` | `FirebaseInitializer.ensureFirestoreDatabase()` | Create the (default) DB |
| `oracular deploy storage-init` | `FirebaseInitializer.ensureStorageBucket()` | Create the default bucket |
| `oracular deploy auth-providers` | `FirebaseInitializer.enableAuthProviders()` | Enable / hand off auth providers |
| `oracular check billing` | `FirebaseBillingService.checkBlazeStatus()` | Print Spark/Blaze status |
| `oracular deploy artifact-cleanup` | `ArtifactCleanupService.applyCleanupPolicies()` | Apply cleanup policies |
| `oracular deploy cloudrun-prune` | `ArtifactCleanupService.capCloudRunRevisions()` | Cap revisions |

Existing `oracular deploy firebase-setup` (`oracular/lib/cli/handlers/deploy_handlers.dart:188-266`) becomes a thin alias that calls `firebase-setup-full`.

### 5.5 Template / Generated Asset Updates

- Update `oracular/lib/services/server_setup.dart:153-214` so `script_deploy.sh` ends with `gcloud artifacts repositories set-cleanup-policies` (idempotent) and a Cloud Run revision pruning loop.
- Mirror the change in `templates/arcane_server/script_deploy.sh`.
- Add `templates/arcane_server/cleanup-policy.json` and copy it through the existing `TemplateCopier`.
- Jaspr templates: no payload changes required; behavior is fully driven by Oracular.

---

## 6. Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| User runs wizard against a project they don't own (no billing access) | `FirebaseBillingService` returns `unknown`; orchestrator warns and lets user choose |
| `gcloud firestore databases create` requires a region the user did not pick | Default `nam5`, prompt for override; persist in `setup_config.env` |
| Storage bucket name `<project>.appspot.com` taken (rare) | Catch error, fall back to `<project>-default-bucket` |
| Beta site name `<project>-beta` taken by another tenant | Surface error + exact recovery command |
| `flutter build web` fails (no web platform) | Already detected at `firebase_service.dart:601-633`; orchestrator skips deploy with `Fix:` hint |
| `jaspr build` fails (missing build_runner output) | Surface jaspr stderr; suggest `dart run build_runner build` then retry |
| Auth provider automation hits Identity Toolkit quotas | Always fall back to console hand-off (never blocking) |
| User's Firebase CLI is too old for `--json` output we depend on | Bump version requirement in `tool_checker`; print clear upgrade hint |
| Wizard rerun double-creates resources | Every "ensure" method lists existing first and short-circuits |

---

## 7. Verification Criteria

A change is complete only if **all** of the following pass on a fresh
Firebase project:

1. **Wizard run, Spark plan, Flutter web template**: produces a project where
   Firestore + Storage are initialized, rules are deployed, release + beta
   hosting sites exist and serve the build, final summary lists
   `https://<project>.web.app` and `https://<project>-beta.web.app`.
   Cloud Run / cleanup steps skipped with "needs Blaze" hint.
2. **Wizard run, Spark plan, Jaspr static (`arcaneJasprDocs`)**: same as
   above; release + beta both serve the static HTML output from
   `<webPackageName>/build/jaspr/`.
3. **Wizard run, Spark plan, Jaspr client (`arcaneJaspr`)**: same as above;
   release + beta both serve the hydrated SPA.
4. **Wizard run, Blaze + server**: same plus Cloud Run service reachable,
   cleanup policies installed, ≤ 3 revisions.
5. **Re-run idempotency**: `oracular deploy firebase-setup-full` immediately
   after wizard prints "skipped (already configured)" for every step,
   exits 0.
6. **Partial failure recovery**: forcibly fail one step (e.g. revoke gcloud
   auth between Firestore init and hosting deploy). Re-running
   `firebase-setup-full` resumes and finishes cleanly.
7. **Unit tests**: new tests for `SetupConfig` round-trip, every new
   service, and orchestrator step ordering. `dart test` is green.
8. **Static analysis**: `dart analyze` reports zero issues.
9. **No regressions**: `oracular deploy hosting`, `hosting-beta`,
   `firestore`, `storage`, and the existing `firebase-setup` alias still
   work and produce identical output (other than additive log lines).

---

## 8. Out-of-Scope Follow-Ups

- Auto-configuring Firebase Auth Google OAuth client (browser-only flow)
- Generating Cloud Functions stubs alongside the server template
- Setting up Firebase App Check
- Multi-region Firestore / multi-bucket Storage
- A "destroy" command that tears down everything Oracular created
- A first-class `arcane_jaspr_server` template (mode: server / SSR) that
  reuses the new Cloud Run pipeline

---

## 9. Tasks

These tasks are tracked by the `execute-plan` skill. Status legend:
`[ ] PENDING`, `[~] IN_PROGRESS`, `[x] DONE`, `[!] FAILED`.

- [x] **T1**: Extend `SetupConfig` (`oracular/lib/models/setup_config.dart`) with the new fields from §5.2; update `defaults`, `copyWith`, `saveToFile`, `loadFromFile`, `toDisplayMap`. Update `oracular/test/unit/setup_config_test.dart` with round-trip + default tests for the new fields (including Jaspr templates).
- [x] **T2**: Add new CLI subcommands (`firebase-setup-full`, `hosting-init`, `firestore-init`, `storage-init`, `auth-providers`, `artifact-cleanup`, `cloudrun-prune`, `check billing`) in `oracular/lib/cli/commands.dart` and stub handlers in `oracular/lib/cli/handlers/deploy_handlers.dart` + `check_handlers.dart`. The existing `firebase-setup` becomes a thin alias.
- [x] **T3**: Implement `FirebaseBillingService` (`oracular/lib/services/firebase_billing_service.dart`): `BlazeStatus` enum, `checkBlazeStatus`, `guideUpgrade` with console URL hand-off.
- [x] **T4**: Implement `FirebaseInitializer.ensureFirestoreDatabase` and `ensureStorageBucket` (`oracular/lib/services/firebase_initializer.dart`). Wire `ensureStorageBucket` into the existing not-initialized retry path in `FirebaseService.deployStorage`.
- [x] **T5**: Implement `FirebaseInitializer.enableAuthProviders` (best-effort + console hand-off for both Flutter and Jaspr templates).
- [x] **T6**: Implement `HostingSiteManager` (`oracular/lib/services/hosting_site_manager.dart`): `listSites`, `ensureReleaseSite`, `ensureBetaSite`, `applyTargets`. Idempotent. Template-agnostic (works for Flutter web, Jaspr static, Jaspr client).
- [x] **T7**: Implement `ArtifactCleanupService` (`oracular/lib/services/artifact_cleanup_service.dart`): `ensureRepository`, `applyCleanupPolicies`, `capCloudRunRevisions`. Add `templates/arcane_server/cleanup-policy.json`.
- [x] **T8**: Implement `FirebaseSetupOrchestrator` (`oracular/lib/services/firebase_setup_orchestrator.dart`): step-by-step driver, `SetupStepResult`, `WizardSubStep` events. Dispatches Jaspr vs Flutter at the build/configure/deploy steps. Re-uses existing `FirebaseService.buildWeb` / `deployHostingRelease` / `deployHostingBeta` / `_configureFirebaseJsSdk`.
- [x] **T9**: Update `oracular/lib/services/server_setup.dart:153-214` so the generated `script_deploy.sh` runs `set-cleanup-policies` and the revision-pruning loop after every deploy. Mirror in `templates/arcane_server/script_deploy.sh`.
- [x] **T10**: Replace `_offerFirebaseSetup` in `oracular/lib/services/interactive_wizard.dart:638-736` with a sub-step driver that calls `FirebaseSetupOrchestrator` and prompts per sub-step. Bump `_totalSteps` and re-label phases. Add a "Server & Cleanup" Step 6 when `createServer` is true.
- [x] **T11**: Update `_printSuccess` in the wizard to render a "What was deployed" block (release URL, beta URL, Firestore console, Storage console, Cloud Run URL when applicable). Use Jaspr-specific copy ("Jaspr docs site" / "Jaspr web app" / "Flutter web app").
- [x] **T12**: Update `SetupGuidance.printPostCreationChecklist` (`oracular/lib/utils/setup_guidance.dart:71-107`) and `projectGuideMarkdown` so they only list **skipped** steps, and so Jaspr templates show `jaspr serve` (and a hot-rebuild note for `isJasprDocs`) as the local-dev command.
- [x] **T13**: Bump `oracular/pubspec.yaml` version (`3.1.2` → `3.2.0`) and `oracular/lib/version.dart`. Update `oracular/README.md` (and root `README.md`) deploy section to document the new commands.
- [x] **T14**: Run `dart analyze` and `dart test` in `oracular/`. Fix any failures. Confirm zero issues.
  - **Result**: 237/237 unit tests pass. Analyzer: 0 errors, 0 warnings, 17 pre-existing infos (down from 70 baseline). Cleaned up `(_, __)` → `(_, _)` across `commands.dart` and `setup_guidance_test.dart` to satisfy `unnecessary_underscores`. Wired `bin/main.dart` and `commands.dart` to the shared `oracularVersion` constant so `version` no longer drifts from `pubspec.yaml`.
