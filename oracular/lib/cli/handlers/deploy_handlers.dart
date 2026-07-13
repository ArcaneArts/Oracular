import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../../models/setup_config.dart';
import '../../models/template_info.dart';
import '../../services/artifact_cleanup_service.dart';
import '../../services/config_generator.dart';
import '../../services/firebase_initializer.dart';
import '../../services/firebase_service.dart';
import '../../services/firebase_setup_orchestrator.dart';
import '../../services/hosting_site_manager.dart';
import '../../services/jaspr_server_deployer.dart';
import '../../services/server_setup.dart';
import '../../utils/project_config_loader.dart';
import '../../utils/setup_guidance.dart';
import '../../utils/user_prompt.dart';
import 'setup_config_requirements.dart';

/// Re-walks the upward search path used by [ProjectConfigLoader] and returns
/// the first existing `setup_config.env` path. Used when a handler needs to
/// persist mutations back to the same file the loader read from.
String? _findExistingConfigPath() {
  final List<String> paths = ProjectConfigLoader.configSearchPaths(
    Directory.current.path,
  );
  for (final String path in paths) {
    if (File(path).existsSync()) {
      return path;
    }
  }
  return null;
}

void _printFirebaseDisabledHelp(SetupConfig config) {
  error('Firebase is not enabled for this project.');
  print('');
  UserPrompt.printList(<String>[
    'Edit ${p.join(config.outputDir, 'config', 'setup_config.env')} and set:',
    '  USE_FIREBASE=yes',
    '  FIREBASE_PROJECT_ID=<your-project-id>',
    'Then run: oracular deploy firebase-setup',
    SetupGuidance.linkLine(
      'Firebase console',
      'https://console.firebase.google.com',
    ),
  ]);
}

/// Deploy Firestore rules and indexes
Future<void> handleDeployFirestore() async {
  final config = await ProjectConfigLoader.load();
  if (config == null) {
    ProjectConfigLoader.printMissingConfigHelp();
    return;
  }

  if (!config.useFirebase) {
    _printFirebaseDisabledHelp(config);
    return;
  }

  final firebase = FirebaseService(config);
  if (await firebase.deployFirestore()) {
    success('Firestore deployed successfully');
  } else {
    error('Firestore deployment failed');
  }
}

/// Deploy Storage rules
Future<void> handleDeployStorage() async {
  final config = await ProjectConfigLoader.load();
  if (config == null) {
    ProjectConfigLoader.printMissingConfigHelp();
    return;
  }

  if (!config.useFirebase) {
    _printFirebaseDisabledHelp(config);
    return;
  }

  final firebase = FirebaseService(config);
  if (await firebase.deployStorage()) {
    success('Storage rules deployed successfully');
  } else {
    error('Storage deployment failed');
  }
}

/// Deploy to Firebase Hosting (release)
Future<void> handleDeployHosting() async {
  final config = await ProjectConfigLoader.load();
  if (config == null) {
    ProjectConfigLoader.printMissingConfigHelp();
    return;
  }

  if (!config.useFirebase) {
    _printFirebaseDisabledHelp(config);
    return;
  }

  if (!SetupGuidance.supportsWebHosting(config)) {
    error('This project is not configured for web hosting.');
    print('');
    UserPrompt.printList(<String>[
      'To add web support:',
      '  cd ${SetupGuidance.mainProjectPath(config)}',
      '  flutter create --platforms=web .',
      'Then retry: oracular deploy hosting',
      SetupGuidance.linkLine(
        'Flutter web deployment docs',
        'https://docs.flutter.dev/deployment/web',
      ),
    ]);
    return;
  }

  final firebase = FirebaseService(config);

  // Build first
  if (!await firebase.buildWeb()) {
    error('Web build failed');
    return;
  }

  if (await firebase.deployHostingRelease()) {
    success('Hosting deployed successfully');
    SetupGuidance.printHostingSuccess(config, beta: false);
  } else {
    error('Hosting deployment failed');
  }
}

/// Deploy to Firebase Hosting (beta)
Future<void> handleDeployHostingBeta() async {
  final config = await ProjectConfigLoader.load();
  if (config == null) {
    ProjectConfigLoader.printMissingConfigHelp();
    return;
  }

  if (!config.useFirebase) {
    _printFirebaseDisabledHelp(config);
    return;
  }

  if (!SetupGuidance.supportsWebHosting(config)) {
    error('This project is not configured for web hosting.');
    print('');
    UserPrompt.printList(<String>[
      'To add web support:',
      '  cd ${SetupGuidance.mainProjectPath(config)}',
      '  flutter create --platforms=web .',
      'Then retry: oracular deploy hosting-beta',
      SetupGuidance.linkLine(
        'Flutter web deployment docs',
        'https://docs.flutter.dev/deployment/web',
      ),
    ]);
    return;
  }

  final firebase = FirebaseService(config);

  // Build first
  if (!await firebase.buildWeb()) {
    error('Web build failed');
    return;
  }

  if (await firebase.deployHostingBeta()) {
    success('Beta hosting deployed successfully');
    SetupGuidance.printHostingSuccess(config, beta: true);
  } else {
    error('Beta hosting deployment failed');
    if (config.firebaseProjectId != null) {
      SetupGuidance.printBetaSiteHint(config.firebaseProjectId!);
    }
  }
}

/// Deploy all Firebase resources (and the server, when enabled).
///
/// Order:
///   1. **Firebase**: Firestore rules + Storage rules + (web build +
///      hosting release deploy).
///   2. **Jaspr server**: when `config.hasJasprServer` (SSR / hybrid
///      render modes), build + push + Cloud Run deploy of the Jaspr
///      Dart binary via [JasprServerDeployer]. Runs **before** the
///      arcane_server step so the firebase.json rewrites
///      (`/** → run:<jaspr-service>`) point at a live URL.
///   3. **Server**: when `config.createServer` is true, build + push +
///      Cloud Run deploy via [ServerSetup.deployToCloudRun]. This is
///      what makes `oracular deploy all` cover the "server for
///      hydration" case for the arcane_server companion service —
///      which `firebase.deployAll()` knows nothing about.
///
/// We surface step-level success/failure so a partial run still tells
/// the user which pieces shipped. Deploys run independently — server
/// deploy fires even when Firebase deploys had warnings — but each is
/// skipped when its `config.*` toggle is off or the project directory
/// is missing on disk.
Future<void> handleDeployAll() async {
  final config = await ProjectConfigLoader.load();
  if (config == null) {
    ProjectConfigLoader.printMissingConfigHelp();
    return;
  }

  if (!config.useFirebase && !config.createServer && !config.hasJasprServer) {
    error(
      'Neither Firebase, a Jaspr server, nor an arcane_server is '
      'enabled for this project — nothing to deploy.',
    );
    return;
  }

  bool firebaseOk = true;
  bool jasprServerOk = true;
  bool serverOk = true;
  String? serverUrl;
  String? jasprServerUrl;

  // ─── Firebase ───────────────────────────────────────────────────────────
  if (config.useFirebase) {
    final firebase = FirebaseService(config);
    if (!await firebase.deployAll()) {
      warn('Firebase deployments completed with failures.');
      firebaseOk = false;
    }
  } else {
    info('Firebase is disabled — skipping Firebase deploys.');
  }

  // ─── Jaspr server (SSR / hybrid) ────────────────────────────────────────
  // Runs before arcane_server so deploys land in dependency order:
  // Hosting rewrites need the Jaspr service URL to exist, and the
  // arcane_server is the data-tier backend for the Jaspr site.
  if (config.hasJasprServer) {
    print('');
    UserPrompt.printDivider(title: 'Deploy Jaspr server (Cloud Run)');
    final JasprServerDeployer deployer = JasprServerDeployer(config);
    final JasprServerDeployResult result = await deployer.deploy();
    jasprServerOk = result.success;
    jasprServerUrl = result.serviceUrl;
    if (!jasprServerOk) {
      error('Jaspr server deploy failed: ${result.message}');
    }
  } else if (config.template.isJasprApp) {
    info(
      'Jaspr render mode "${config.jasprRenderMode.displayName}" '
      'does not require a Cloud Run service — skipping Jaspr server deploy.',
    );
  }

  // ─── Server (arcane_server companion) ──────────────────────────────────
  // The server hosts the SSR / hydration backend (or the arcane_server
  // companion REST API), so a fresh `oracular deploy all` should leave
  // the user with a fully-redeployed stack — not just the Firebase half.
  if (config.createServer) {
    print('');
    UserPrompt.printDivider(title: 'Deploy server (Cloud Run)');
    final ServerSetup server = ServerSetup(config);
    serverUrl = await server.deployToCloudRun();
    serverOk = serverUrl != null;
    if (!serverOk) {
      error(
        'Server deploy failed. See errors above for the failing step '
        '(docker auth / build / push / gcloud run deploy).',
      );
    }
  } else {
    info('arcane_server is disabled — skipping its Cloud Run deploy.');
  }

  // ─── Summary ────────────────────────────────────────────────────────────
  print('');
  UserPrompt.printDivider(title: 'Deploy summary');
  if (config.useFirebase) {
    if (firebaseOk) {
      success('Firebase:      deployed');
    } else {
      warn('Firebase:      completed with failures (see warnings above)');
    }
  }
  if (config.hasJasprServer) {
    if (jasprServerOk) {
      success('Jaspr server:  deployed → $jasprServerUrl');
    } else {
      error('Jaspr server:  failed');
    }
  }
  if (config.createServer) {
    if (serverOk) {
      success('arcane_server: deployed → $serverUrl');
    } else {
      error('arcane_server: failed');
    }
  }
  if (firebaseOk &&
      config.useFirebase &&
      config.firebaseProjectId != null &&
      SetupGuidance.supportsWebHosting(config)) {
    SetupGuidance.printHostingSuccess(config, beta: false);
  }

  if (firebaseOk && jasprServerOk && serverOk) {
    print('');
    success('All requested deployments succeeded.');
  } else {
    print('');
    error('Some deployments failed. See errors above for details.');
  }
}

/// Deploy the Jaspr server (SSR / hybrid render modes) to Cloud Run.
///
/// Standalone entry point invoked by `oracular deploy jaspr-server`.
/// Identical to the Jaspr-server stage of [handleDeployAll] but
/// re-runnable in isolation when only the Jaspr binary needs to be
/// shipped (e.g. content-only updates or hot fixes that don't touch
/// Firebase rules or arcane_server).
Future<void> handleDeployJasprServer() async {
  final SetupConfig? config = await ProjectConfigLoader.load();
  if (config == null) {
    ProjectConfigLoader.printMissingConfigHelp();
    return;
  }

  if (!config.template.isJasprApp) {
    error('This project is not a Jaspr app — nothing to deploy.');
    print('');
    UserPrompt.printList(<String>[
      'oracular deploy jaspr-server only applies to Jaspr templates '
          'rendered in SSR / hybrid mode.',
      'Current template: ${config.template.displayName}',
    ]);
    return;
  }

  if (!config.hasJasprServer) {
    error(
      'Render mode "${config.jasprRenderMode.displayName}" does not '
      'produce a Cloud Run image — nothing to deploy.',
    );
    print('');
    UserPrompt.printList(<String>[
      'To enable a Jaspr Cloud Run service, set:',
      '  JASPR_RENDER_MODE=ssr   # (or hybrid)',
      'in ${p.join(config.outputDir, 'config', 'setup_config.env')} and re-run.',
    ]);
    return;
  }

  final JasprServerDeployer deployer = JasprServerDeployer(config);
  final JasprServerDeployResult result = await deployer.deploy();

  print('');
  UserPrompt.printDivider(title: 'Jaspr server deploy summary');
  if (result.success) {
    UserPrompt.printList(<String>[
      'Service:  ${result.serviceName}',
      'Region:   ${result.region}',
      'Image:    ${result.imageTag}',
      'URL:      ${result.serviceUrl}',
    ]);
    print('');
    success('Jaspr server deployed.');
  } else {
    error('Jaspr server deploy failed: ${result.message}');
  }
}

/// Setup Firebase for a new project.
///
/// Legacy entry point retained for source compatibility. The CLI now routes
/// `oracular deploy firebase-setup` directly to [handleFirebaseSetupFull];
/// callers that still reference this symbol receive the same behavior.
@Deprecated('Use handleFirebaseSetupFull')
Future<void> handleFirebaseSetup() => handleFirebaseSetupFull();

/// Deploy the arcane_server companion package to Cloud Run.
///
/// Standalone entry point invoked by `oracular deploy arcane-server`. Identical
/// to the arcane_server stage of [handleDeployAll] but re-runnable in
/// isolation when only the server binary needs to be shipped (e.g. when
/// Firebase hosting and Jaspr deploys are already current).
///
/// Exits the process non-zero on failure so CI / shell pipelines treat
/// it as an error.
Future<void> handleDeployServer() async {
  final SetupConfig? config = await ProjectConfigLoader.load();
  if (config == null) {
    ProjectConfigLoader.printMissingConfigHelp();
    exit(1);
  }
  if (!config.createServer) {
    error('arcane_server is not enabled for this project.');
    print('');
    UserPrompt.printList(<String>[
      'oracular deploy arcane-server only applies when the project was '
          'scaffolded with --with-server.',
      'Re-scaffold or set CREATE_SERVER=yes in setup_config.env to enable.',
    ]);
    exit(2);
  }
  if (config.firebaseProjectId == null ||
      config.firebaseProjectId!.trim().isEmpty) {
    error(
      'No FIREBASE_PROJECT_ID configured \u2014 cannot deploy to Cloud Run.',
    );
    print('');
    UserPrompt.printList(<String>[
      'Set FIREBASE_PROJECT_ID in '
          '${p.join(config.outputDir, 'config', 'setup_config.env')}.',
    ]);
    exit(2);
  }

  print('');
  UserPrompt.printDivider(title: 'Deploy server (Cloud Run)');
  final ServerSetup server = ServerSetup(config);
  final String? url = await server.deployToCloudRun();

  print('');
  UserPrompt.printDivider(title: 'arcane_server deploy summary');
  if (url == null) {
    error('arcane_server deploy failed. See errors above.');
    exit(1);
  }
  UserPrompt.printList(<String>[
    'Service:  ${server.serverServiceName}',
    'URL:      $url',
  ]);
  print('');
  success('arcane_server deployed.');
}

/// Generate Firebase configuration files.
///
/// When `--hybrid-dynamic-prefix <p1,p2,...>` is supplied the supplied
/// prefixes overwrite `HYBRID_DYNAMIC_PREFIXES` in `setup_config.env`
/// before regenerating `firebase.json`. This is the supported workflow
/// for managing the per-mode rewrites delivered in T5.4 / T7.1 of the
/// 2026-05-10 build/deploy/rendering-modes plan.
Future<void> handleGenerateConfigs([Map<String, dynamic>? args]) async {
  final config = await ProjectConfigLoader.load();
  if (config == null) {
    ProjectConfigLoader.printMissingConfigHelp();
    return;
  }

  // Optionally override the hybrid dynamic prefixes the user wants Firebase
  // Hosting to rewrite to the Jaspr Cloud Run service. Accepts a single
  // comma-separated string ("/api,/auth,/admin") which is the most ergonomic
  // shape for the darted_cli single-value argument model.
  final String? raw = args == null
      ? null
      : (args['hybrid-dynamic-prefix'] ??
                args['hybriddynamicprefix'] ??
                args['H'])
            ?.toString();
  if (raw != null && raw.trim().isNotEmpty) {
    final List<String> requested = raw
        .split(RegExp('[,\\s]+'))
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .map((String s) => s.startsWith('/') ? s : '/$s')
        .toList(growable: false);
    if (requested.isEmpty) {
      error('No valid prefixes parsed from --hybrid-dynamic-prefix.');
      return;
    }
    if (!config.template.isJasprApp ||
        config.jasprRenderMode != JasprRenderMode.hybrid) {
      info(
        '--hybrid-dynamic-prefix is only effective for Jaspr templates in '
        'hybrid render mode. The value will still be persisted to '
        'setup_config.env for future runs.',
      );
    }

    final SetupConfig updated = config.copyWith(
      hybridDynamicPrefixes: requested,
    );
    final String? configPath = _findExistingConfigPath();
    if (configPath == null) {
      error('Unable to locate setup_config.env on disk to persist update.');
      return;
    }
    await updated.saveToFile(configPath);
    info(
      'Updated HYBRID_DYNAMIC_PREFIXES in setup_config.env: '
      '${requested.join(', ')}',
    );

    final ConfigGenerator configGen = ConfigGenerator(updated);
    await configGen.generateAll();
    return;
  }

  final ConfigGenerator configGen = ConfigGenerator(config);
  await configGen.generateAll();
}

/// Setup server for deployment
Future<void> handleServerSetup() async {
  final config = await ProjectConfigLoader.load();
  if (config == null) {
    ProjectConfigLoader.printMissingConfigHelp();
    return;
  }

  if (!config.createServer) {
    error('Server is not enabled for this project.');
    return;
  }

  final server = ServerSetup(config);
  await server.generateAll();
}

/// Build server Docker image
Future<void> handleServerBuild() async {
  final config = await ProjectConfigLoader.load();
  if (config == null) {
    ProjectConfigLoader.printMissingConfigHelp();
    return;
  }

  if (!config.createServer) {
    error('Server is not enabled for this project.');
    return;
  }

  final server = ServerSetup(config);
  if (await server.buildDockerImage()) {
    success('Server Docker image built successfully');
  } else {
    error('Docker build failed');
  }
}

// ─── End-to-end Firebase setup commands (v3.2.0) ─────────────────────────────
//
// These handlers were introduced in T2 of the 2026-05-07
// firebase-end-to-end-setup plan and fully wired by T3–T8 (T8 connects the
// `FirebaseSetupOrchestrator`). Each remains independently re-runnable so
// a single failed sub-step can be retried without re-running the full flow.

Future<bool> _ensureProjectConfigOrHelp() async {
  final SetupConfig? config = await ProjectConfigLoader.load();
  if (config == null) {
    ProjectConfigLoader.printMissingConfigHelp();
    return false;
  }
  if (!config.useFirebase) {
    _printFirebaseDisabledHelp(config);
    return false;
  }
  return true;
}

/// End-to-end Firebase setup. Runs every applicable sub-step (auth,
/// billing, FlutterFire / Jaspr JS SDK, Firestore + Storage init, auth
/// providers hand-off, rules deploy, web build, hosting init, hosting
/// release + beta deploy, and — when the project enabled it — Cloud Run /
/// Artifact Registry cleanup).
///
/// Idempotent: any sub-step that already ran cleanly short-circuits.
Future<void> handleFirebaseSetupFull() async {
  if (!await _ensureProjectConfigOrHelp()) {
    return;
  }
  final SetupConfig config = (await ProjectConfigLoader.load())!;

  print('');
  UserPrompt.printDivider(title: 'Firebase end-to-end setup');
  UserPrompt.printList(<String>[
    'Project: ${config.firebaseProjectId}',
    'Template: ${config.template.name}',
    if (SetupGuidance.supportsWebHosting(config)) 'Web hosting: enabled',
    if (config.createServer) 'Server (Cloud Run): enabled',
  ]);
  print('');

  final FirebaseSetupOrchestrator orchestrator = FirebaseSetupOrchestrator(
    config,
  );

  final OrchestratorReport report = await orchestrator.runAll(
    interactive: true,
    onStep: (SetupStepResult result) async {
      switch (result.status) {
        case SetupStepStatus.success:
          success(
            '${result.step.label}'
            '${result.message.isNotEmpty ? ' — ${result.message}' : ''}',
          );
          break;
        case SetupStepStatus.skipped:
          warn(
            '${result.step.label} skipped'
            '${result.message.isNotEmpty ? ': ${result.message}' : ''}',
          );
          break;
        case SetupStepStatus.failed:
          error(
            '${result.step.label} failed'
            '${result.message.isNotEmpty ? ': ${result.message}' : ''}',
          );
          break;
      }
    },
  );

  print('');
  UserPrompt.printDivider(title: 'Setup summary');
  UserPrompt.printList(<String>[
    'Steps succeeded: ${report.successCount}',
    'Steps skipped:   ${report.skippedCount}',
    'Steps failed:    ${report.failedCount}',
  ]);

  if (report.releaseUrl != null || report.betaUrl != null) {
    print('');
    UserPrompt.printDivider(title: 'What was deployed');
    UserPrompt.printList(<String>[
      if (report.releaseUrl != null) 'Release URL: ${report.releaseUrl}',
      if (report.betaUrl != null) 'Beta URL: ${report.betaUrl}',
      if (report.firestoreRegion != null)
        SetupGuidance.linkLine(
          'Firestore console',
          FirebaseInitializer.firestoreConsoleUrl(config.firebaseProjectId!),
        ),
      if (report.storageBucketName != null)
        SetupGuidance.linkLine(
          'Storage console',
          FirebaseInitializer.getStartedUrl(config.firebaseProjectId!),
        ),
      if (config.setupCloudRun)
        SetupGuidance.linkLine(
          'Cloud Run console',
          SetupGuidance.cloudRunConsoleUrl(config.firebaseProjectId!),
        ),
    ]);
  }

  if (report.failures.isNotEmpty) {
    print('');
    UserPrompt.printDivider(title: 'Failures (re-runnable)');
    for (final SetupStepResult fail in report.failures) {
      UserPrompt.printList(<String>[
        '${fail.step.label}: ${fail.message}',
        if (fail.fixHint.isNotEmpty) '  Fix: ${fail.fixHint}',
      ]);
    }
  }

  if (!report.success) {
    print('');
    error(
      'Firebase setup completed with ${report.failedCount} failing step(s). '
      'Re-run individual commands above to retry.',
    );
  } else if (report.skippedCount > 0) {
    print('');
    info('Firebase setup completed (some steps were skipped).');
  } else {
    print('');
    success('Firebase setup complete!');
  }
}

/// Create the `<project>-beta` site and apply hosting targets (T6).
Future<void> handleHostingInit() async {
  final SetupConfig? config = await requireFirebaseProjectConfig();
  if (config == null) return;
  if (!SetupGuidance.supportsWebHosting(config)) {
    error('This project does not produce a web build; nothing to host.');
    return;
  }

  final HostingSiteManager hosting = HostingSiteManager(
    config.firebaseProjectId!,
    workingDirectory: config.outputDir,
  );

  info('Verifying release hosting site `${config.firebaseProjectId}`...');
  final SiteEnsureResult release = await hosting.ensureReleaseSite();
  _printSiteResult(release, role: 'release');

  info('Ensuring beta hosting site `${hosting.betaSiteId}`...');
  final SiteEnsureResult beta = await hosting.ensureBetaSite();
  _printSiteResult(beta, role: 'beta');

  info('Applying hosting targets...');
  final ApplyTargetsResult apply = await hosting.applyTargets();
  if (apply.success) {
    success('Hosting targets applied (release + beta).');
  } else {
    error('Failed to apply hosting targets: ${apply.message}');
  }

  print('');
  if (release.success && beta.success && apply.success) {
    success('Hosting init complete. You can now run:');
    UserPrompt.printList(<String>[
      '  oracular deploy hosting',
      '  oracular deploy hosting-beta',
      'Live URLs once deployed:',
      '  ${release.webAppUrl}',
      '  ${beta.webAppUrl}',
    ]);
  }
}

void _printSiteResult(SiteEnsureResult result, {required String role}) {
  switch (result.outcome) {
    case SiteEnsureOutcome.existed:
      info('$role site `${result.siteId}` already exists.');
      break;
    case SiteEnsureOutcome.created:
      success('$role site `${result.siteId}` created.');
      break;
    case SiteEnsureOutcome.failed:
      error(
        '$role site `${result.siteId}` could not be ensured: '
        '${result.message}',
      );
      break;
  }
}

/// Ensure the default Firestore database exists (T4).
Future<void> handleFirestoreInit() async {
  final SetupConfig? config = await requireFirebaseProjectConfig();
  if (config == null) return;

  final FirebaseInitializer initializer = FirebaseInitializer(
    config.firebaseProjectId!,
  );

  info(
    'Ensuring Firestore default database exists for ${config.firebaseProjectId}...',
  );
  final FirestoreInitResult result = await initializer.ensureFirestoreDatabase(
    region: config.firestoreRegion,
  );

  if (result.success) {
    if (result.created) {
      success('Firestore database created in region ${result.region}.');
    } else {
      success('Firestore database already exists (region: ${result.region}).');
    }
    print('');
    UserPrompt.printList(<String>[
      SetupGuidance.linkLine(
        'Firestore console',
        FirebaseInitializer.firestoreConsoleUrl(config.firebaseProjectId!),
      ),
    ]);
  } else {
    error('Failed to ensure Firestore database: ${result.message}');
    print('');
    UserPrompt.printList(<String>[
      'Verify gcloud is installed and authenticated.',
      'Confirm the active account has roles/datastore.owner or roles/owner.',
      'Retry with: oracular deploy firestore-init',
    ]);
  }
}

/// Ensure the default Storage bucket exists (T4).
Future<void> handleStorageInit() async {
  final SetupConfig? config = await requireFirebaseProjectConfig();
  if (config == null) return;

  final FirebaseInitializer initializer = FirebaseInitializer(
    config.firebaseProjectId!,
  );

  info(
    'Ensuring default Storage bucket exists for ${config.firebaseProjectId}...',
  );
  final StorageInitResult result = await initializer.ensureStorageBucket();

  if (result.success) {
    if (result.created) {
      success('Default Storage bucket created: gs://${result.bucketName}');
    } else {
      success(
        'Default Storage bucket already exists: gs://${result.bucketName}',
      );
    }
    print('');
    if (result.needsFirebaseInit && result.getStartedUrl != null) {
      warn(
        'Visit ${result.getStartedUrl!} once and click "Get Started" to enable Firebase Storage.',
      );
    }
  } else {
    error('Failed to ensure Storage bucket: ${result.message}');
    if (result.getStartedUrl != null) {
      print('');
      UserPrompt.printList(<String>[
        SetupGuidance.linkLine(
          'Firebase Storage console',
          result.getStartedUrl!,
        ),
        'Click "Get Started" once, then re-run: oracular deploy storage-init',
      ]);
    }
  }
}

/// Enable Email/Password and Google auth providers (T5).
Future<void> handleAuthProviders() async {
  final SetupConfig? config = await requireFirebaseProjectConfig();
  if (config == null) return;

  final Set<AuthProvider> providers = <AuthProvider>{
    if (config.enableEmailAuth) AuthProvider.emailPassword,
    if (config.enableGoogleAuth) AuthProvider.google,
  };

  if (providers.isEmpty) {
    info('No auth providers enabled in config; nothing to do.');
    print('');
    UserPrompt.printList(<String>[
      'Edit ${p.join(config.outputDir, 'config', 'setup_config.env')} and set:',
      '  ENABLE_EMAIL_AUTH=yes',
      '  ENABLE_GOOGLE_AUTH=yes',
      'Then re-run: oracular deploy auth-providers',
    ]);
    return;
  }

  final FirebaseInitializer initializer = FirebaseInitializer(
    config.firebaseProjectId!,
  );
  final AuthProvidersResult result = await initializer.enableAuthProviders(
    providers: providers,
  );

  if (result.success) {
    success(
      'Auth providers configured: ${result.handedOff.map((AuthProvider p) => p.label).join(', ')}',
    );
  } else {
    warn(result.message);
  }
}

/// Apply Artifact Registry cleanup policy (T7).
Future<void> handleArtifactCleanup() async {
  final SetupConfig? config = await requireCloudRunProjectConfig(
    disabledMessage:
        'Cloud Run is not enabled for this project; nothing to clean up.',
    missingProjectMessage:
        'Firebase / GCP project ID not set; cannot apply cleanup policy.',
  );
  if (config == null) return;

  const String repository = 'oracular';
  final ArtifactCleanupService svc = ArtifactCleanupService(
    config.firebaseProjectId!,
  );

  info(
    'Ensuring Artifact Registry repository `$repository` exists '
    'in ${svc.defaultRegion}...',
  );
  final RepositoryEnsureResult repo = await svc.ensureRepository(
    repository: repository,
  );
  if (!repo.success) {
    error('Could not ensure repository `$repository`: ${repo.message}');
    return;
  }

  info(
    'Applying cleanup policy '
    '(keep ${config.artifactKeepRecent} recent, '
    'delete >${config.artifactDeleteOlderDays}d) to `$repository`...',
  );
  final CleanupPolicyResult result = await svc.applyCleanupPolicies(
    repository: repository,
    keepRecent: config.artifactKeepRecent,
    deleteOlderDays: config.artifactDeleteOlderDays,
  );

  if (result.success) {
    success(
      'Artifact Registry cleanup policy applied to `$repository` '
      '(${result.policyCount} rules).',
    );
  } else {
    error('Cleanup policy not applied: ${result.message}');
    print('');
    UserPrompt.printList(<String>[
      'Verify gcloud is installed and authenticated.',
      'The cleanup-policies API requires gcloud >= 444.0.0.',
      'Confirm the active account has roles/artifactregistry.admin.',
      'Retry with: oracular deploy artifact-cleanup',
    ]);
  }
}

/// Prune Cloud Run revisions to the configured retention count (T7).
Future<void> handleCloudRunPrune() async {
  final SetupConfig? config = await requireCloudRunProjectConfig(
    disabledMessage:
        'Cloud Run is not enabled for this project; nothing to prune.',
    missingProjectMessage:
        'Firebase / GCP project ID not set; cannot prune revisions.',
  );
  if (config == null) return;

  final String service = config.serverPackageName.replaceAll('_', '-');
  final ArtifactCleanupService svc = ArtifactCleanupService(
    config.firebaseProjectId!,
  );

  info(
    'Pruning Cloud Run revisions for `$service`@${svc.defaultRegion} '
    '(keeping latest ${config.cloudRunKeepRevisions})...',
  );
  final RevisionPruneResult result = await svc.capCloudRunRevisions(
    service: service,
    keepRevisions: config.cloudRunKeepRevisions,
  );

  if (!result.success) {
    error(
      'Cloud Run prune partial: ${result.deleted} deleted, '
      '${result.skipped} skipped (serving traffic), '
      '${result.failedRevisions.length} failed.',
    );
    if (result.failedRevisions.isNotEmpty) {
      UserPrompt.printList(<String>[
        'Failed revisions:',
        for (final String r in result.failedRevisions) '  • $r',
      ]);
    }
    return;
  }

  if (result.deleted == 0 && result.skipped == 0) {
    success(
      'Cloud Run service `$service` already at or below '
      '${config.cloudRunKeepRevisions} revisions — no pruning needed.',
    );
  } else {
    success(
      'Cloud Run prune complete: '
      'deleted ${result.deleted}, skipped ${result.skipped} '
      '(serving traffic).',
    );
  }
}
