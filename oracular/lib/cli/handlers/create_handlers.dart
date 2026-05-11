import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../../models/setup_config.dart';
import '../../models/template_info.dart';
import '../../services/config_generator.dart';
import '../../services/dependency_manager.dart';
import '../../services/docs_generator.dart';
import '../../services/project_creator.dart';
import '../../services/server_setup.dart';
import '../../services/template_copier.dart';
import '../../services/tool_checker.dart';
import '../../utils/firebase_setup_prompts.dart';
import '../../utils/process_runner.dart';
import '../../utils/string_utils.dart';
import '../../utils/setup_guidance.dart';
import '../../utils/user_prompt.dart';
import '../../utils/validators.dart';

/// Handle create command
Future<void> handleCreate(
  Map<String, dynamic> args,
  Map<String, dynamic> flags,
) async {
  UserPrompt.printBanner(
    'Oracular Project Creator',
    subtitle: 'Arcane Template System',
  );

  // Check required tools first
  final skipCheck = flags['skip-check'] == true;
  if (!skipCheck) {
    final checker = ToolChecker();
    final result = await checker.checkRequired();
    if (!result.allRequiredInstalled) {
      error(
        'Required tools are missing. Run "oracular check tools" for details.',
      );
      exit(1);
    }
  }

  final yes = flags['yes'] == true;

  // Gather configuration
  final config = await _gatherConfig(
    appName: args['app-name'] as String?,
    org: args['org'] as String?,
    template: args['template'] as String?,
    className: args['class-name'] as String?,
    outputDir: args['output-dir'] as String?,
    withModels: flags['with-models'] == true,
    withServer: flags['with-server'] == true,
    withFirebase: flags['with-firebase'] == true,
    firebaseProjectId: args['firebase-project-id'] as String?,
    withCloudRun: flags['with-cloud-run'] == true,
    serviceAccountKey: args['service-account-key'] as String?,
    renderMode: args['render-mode'] as String?,
    interactive: !yes,
  );

  // Show config and confirm
  if (!yes) {
    UserPrompt.printConfigPreview(config.toDisplayMap());

    final confirmed = await UserPrompt.askYesNo('Proceed with these settings?');
    if (!confirmed) {
      warn('Operation cancelled');
      return;
    }
  }

  // Execute creation
  await _executeCreation(config, nonInteractive: yes);
}

/// List available templates
Future<void> handleListTemplates(
  Map<String, dynamic> args,
  Map<String, dynamic> flags,
) async {
  print('\nAvailable Templates:');
  print('\u2500' * 70);

  for (final type in TemplateType.values) {
    print('');
    print('  ${type.number}. ${type.displayName}');
    print('     ${type.description}');
    if (type.supportedPlatforms.isNotEmpty) {
      print('     Platforms: ${type.supportedPlatforms.join(", ")}');
    } else {
      print('     Type: Dart CLI (no Flutter platforms)');
    }
  }

  print('');
  print('\u2500' * 70);
  info('Use --template <number> or --template <name> to select');
}

/// Gather configuration from flags or interactive prompts
Future<SetupConfig> _gatherConfig({
  String? appName,
  String? org,
  String? template,
  String? className,
  String? outputDir,
  bool withModels = false,
  bool withServer = false,
  bool withFirebase = false,
  String? firebaseProjectId,
  bool withCloudRun = false,
  String? serviceAccountKey,
  String? renderMode,
  bool interactive = true,
}) async {
  // App name
  String finalAppName;
  if (appName != null) {
    final validation = validateAppName(appName);
    if (!validation.isValid) {
      error(validation.errorMessage!);
      exit(1);
    }
    finalAppName = appName;
  } else if (interactive) {
    finalAppName = await UserPrompt.askString(
      'Enter app name (snake_case)',
      defaultValue: 'my_app',
      validator: (s) => validateAppName(s).isValid,
      validationMessage:
          'Invalid app name. Use lowercase letters, numbers, and underscores.',
    );
  } else {
    error('--app-name is required');
    exit(1);
  }

  // Organization domain
  String finalOrg;
  if (org != null) {
    finalOrg = org;
  } else if (interactive) {
    finalOrg = await UserPrompt.askString(
      'Enter organization domain (e.g., com.example)',
      defaultValue: 'com.example',
    );
  } else {
    error('--org is required');
    exit(1);
  }

  // Template
  TemplateType finalTemplate;
  if (template != null) {
    final parsed = TemplateTypeExtension.parse(template);
    if (parsed == null) {
      error('Invalid template: $template');
      await handleListTemplates({}, {});
      exit(1);
    }
    finalTemplate = parsed;
  } else if (interactive) {
    final templateIndex = await UserPrompt.showMenu(
      'Select a template:',
      TemplateType.values
          .map((t) => '${t.displayName}\n      ${t.description}')
          .toList(),
      defaultIndex: 0,
    );
    finalTemplate = TemplateType.values[templateIndex];
  } else {
    error('--template is required');
    exit(1);
  }

  // Class name (auto-generate from app name if not provided)
  final finalClassName = className ?? snakeToPascal(finalAppName);

  // Output directory
  final finalOutputDir = outputDir ?? Directory.current.path;

  // Platforms
  List<String> finalPlatforms = finalTemplate.supportedPlatforms;
  final bool canChoosePlatforms =
      finalTemplate.isFlutterApp &&
      finalTemplate != TemplateType.arcaneDock &&
      finalTemplate.supportedPlatforms.length > 1;

  if (interactive && canChoosePlatforms) {
    print('');
    info('Target Platforms');
    final List<int> platformIndices = await UserPrompt.askMultiSelect(
      'Select target platforms',
      finalTemplate.supportedPlatforms,
      defaultSelected: finalTemplate.supportedPlatforms,
    );

    finalPlatforms = platformIndices
        .map((int index) => finalTemplate.supportedPlatforms[index])
        .toList();

    if (finalPlatforms.isEmpty) {
      warn(
        'At least one platform must be selected; using all supported platforms.',
      );
      finalPlatforms = finalTemplate.supportedPlatforms;
    }
  }

  // Models package
  bool finalWithModels = withModels;
  if (!withModels && interactive) {
    print('');
    info('Optional package: Shared Models');
    UserPrompt.printList(<String>[
      'Stores reusable data classes and serializers in one package.',
      'Use this if multiple projects (app/server/cli) should share the same models.',
      'Control: press Enter to accept the default shown in [Y/n] or [y/N].',
    ]);
    finalWithModels = await UserPrompt.askYesNo(
      'Create models package?',
      defaultValue: false,
    );
  }

  // Server app
  bool finalWithServer = withServer;
  if (!withServer && interactive) {
    print('');
    info('Optional package: Server Application');
    UserPrompt.printList(<String>[
      'Creates a backend service for APIs, admin operations, and secure server-side logic.',
      'Use this when your project needs a deployable server instead of client-only behavior.',
      'Control: press Enter to accept the default shown in [Y/n] or [y/N].',
    ]);
    finalWithServer = await UserPrompt.askYesNo(
      'Create server app?',
      defaultValue: false,
    );
  }

  // arcane_server templates hard-depend on the shared arcane_models package
  // via a path: ../<name>_models entry. Without models, `flutter pub get` and
  // `docker build` both fail (verified in real-deploy smoke). Force models on
  // whenever server is enabled.
  if (finalWithServer && !finalWithModels) {
    if (withModels) {
      // user explicitly asked for server, no models passed via flag — keep
      // their intent silent if they're scripting.
    } else {
      warn(
        'arcane_server depends on arcane_models. Enabling models package automatically.',
      );
    }
    finalWithModels = true;
  }

  // Firebase
  bool finalWithFirebase = withFirebase ||
      (firebaseProjectId != null && firebaseProjectId.trim().isNotEmpty);
  String? finalFirebaseProjectId = firebaseProjectId?.trim();

  // Discover an existing service-account.json *before* asking for project
  // id so we can default to the SA's project_id and offer to reuse the SA
  // file later. This is what makes the flow truly hands-off when the user
  // already keeps a key at their workspace root.
  final DiscoveredServiceAccount? preDiscovered =
      FirebaseSetupPrompts.findExistingServiceAccountKey(
    outputDir: finalOutputDir,
    serverPackageName: finalWithServer ? '${finalAppName}_server' : null,
  );

  if (interactive && !finalWithFirebase) {
    finalWithFirebase = await UserPrompt.askYesNo(
      'Enable Firebase?',
      defaultValue: false,
    );
  }
  if (finalWithFirebase &&
      (finalFirebaseProjectId == null || finalFirebaseProjectId.isEmpty) &&
      interactive) {
    if (preDiscovered != null && preDiscovered.hasProjectId) {
      info(
        'Found service account at ${preDiscovered.path} '
        '(project: ${preDiscovered.projectId}).',
      );
    }
    finalFirebaseProjectId = await UserPrompt.askString(
      'Enter Firebase project ID',
      defaultValue: preDiscovered?.projectId,
      validator: (s) => validateFirebaseProjectId(s).isValid,
      validationMessage: 'Invalid Firebase project ID',
    );
  }
  if (finalWithFirebase &&
      (finalFirebaseProjectId == null || finalFirebaseProjectId.isEmpty)) {
    error('--firebase-project-id is required when Firebase is enabled');
    exit(1);
  }

  // Cloud Run
  bool finalWithCloudRun = withCloudRun;
  if (finalWithServer && finalWithFirebase && interactive && !withCloudRun) {
    finalWithCloudRun = await UserPrompt.askYesNo(
      'Setup Cloud Run for server?',
      defaultValue: false,
    );
  }

  // Service account key. Asked whenever Firebase is enabled so even pure
  // Flutter / Beamer / Jaspr apps without a server can pre-stage the key
  // for the wizard's IAM gate, FlutterFire/Jaspr configure, and hosting
  // deploys. When no server is being created, the key lands in
  // `<outputDir>/config/keys/` (resolved automatically by FirebaseService).
  String? finalServiceAccountKey =
      FirebaseSetupPrompts.normalizeConfiguredKeyPath(serviceAccountKey);
  if (finalWithFirebase &&
      interactive &&
      serviceAccountKey == null &&
      finalFirebaseProjectId != null) {
    finalServiceAccountKey =
        await FirebaseSetupPrompts.askServiceAccountKeyPath(
      outputDir: finalOutputDir,
      serverPackageName: finalWithServer ? '${finalAppName}_server' : null,
    );
  }

  // Jaspr render mode. Only meaningful for Jaspr templates; for everything
  // else the SetupConfig constructor still stores a value (csr) for
  // serialization simplicity but it is ignored at build/deploy time.
  JasprRenderMode? finalRenderMode;
  if (renderMode != null && renderMode.trim().isNotEmpty) {
    final JasprRenderMode? parsed = JasprRenderModeExtension.parse(renderMode);
    if (parsed == null) {
      error(
        'Invalid --render-mode "$renderMode". '
        'Valid values: csr, ssg, ssr, hybrid, embed.',
      );
      exit(1);
    }
    if (!finalTemplate.isJasprApp) {
      warn(
        '--render-mode is only meaningful for Jaspr templates; '
        'ignoring "$renderMode" for ${finalTemplate.displayName}.',
      );
    } else if (parsed == JasprRenderMode.embed &&
        finalTemplate != TemplateType.arcaneJasprFlutterEmbed) {
      error(
        'Render mode "embed" requires the '
        '${TemplateType.arcaneJasprFlutterEmbed.displayName} template.',
      );
      exit(1);
    } else {
      finalRenderMode = parsed;
    }
  } else if (interactive &&
      finalTemplate.isJasprApp &&
      finalTemplate != TemplateType.arcaneJasprFlutterEmbed) {
    // arcaneJasprFlutterEmbed is locked to embed; everything else gets a
    // prompt so the user can pick CSR vs SSG vs SSR vs Hybrid.
    print('');
    info('Jaspr Render Mode');
    UserPrompt.printList(<String>[
      'CSR ships a client-only SPA (fastest to build, no server runtime).',
      'SSG pre-renders every route at build time (SEO-friendly, hosted as static).',
      'SSR renders at request time on Cloud Run (most flexible, costs more).',
      'Hybrid mixes SSG for marketing routes with SSR for /api, /auth, etc.',
    ]);
    final List<JasprRenderMode> choices = <JasprRenderMode>[
      JasprRenderMode.csr,
      JasprRenderMode.ssg,
      JasprRenderMode.ssr,
      JasprRenderMode.hybrid,
    ];
    final int defaultIndex = choices.indexOf(
      finalTemplate == TemplateType.arcaneJasprDocs
          ? JasprRenderMode.ssg
          : JasprRenderMode.csr,
    );
    final int idx = await UserPrompt.showMenu(
      'Select Jaspr render mode',
      choices
          .map((JasprRenderMode m) => '${m.displayName}\n      ${m.description}')
          .toList(),
      defaultIndex: defaultIndex < 0 ? 0 : defaultIndex,
    );
    finalRenderMode = choices[idx];
  }

  return SetupConfig(
    appName: finalAppName,
    orgDomain: finalOrg,
    baseClassName: finalClassName,
    template: finalTemplate,
    outputDir: finalOutputDir,
    createModels: finalWithModels,
    createServer: finalWithServer,
    useFirebase: finalWithFirebase,
    firebaseProjectId: finalFirebaseProjectId,
    setupCloudRun: finalWithCloudRun,
    serviceAccountKeyPath: finalServiceAccountKey,
    platforms: finalPlatforms,
    jasprRenderMode: finalRenderMode,
  );
}

/// Execute the project creation
Future<void> _executeCreation(
  SetupConfig config, {
  bool nonInteractive = false,
}) async {
  info('Starting project creation...');

  // When --yes is set we MUST NOT fall back to interactive
  // retry/skip/abort prompts inside ProcessRunner.runWithRetry; otherwise
  // a transient failure (`flutter pub get` rate limit, missing
  // `build_runner` in a CLI template, etc.) leaves the run waiting for
  // stdin and hangs CI.
  final ProcessRunner runner = ProcessRunner(interactive: !nonInteractive);

  // 1. Create projects using flutter/dart create
  final creator = ProjectCreator(config, runner: runner);
  if (!await creator.createAllProjects()) {
    error('Failed to create projects');
    exit(1);
  }

  // 2. Copy template files (downloads from GitHub if needed)
  final copier = await TemplateCopier.create(config);
  await copier.copyAll();

  // 3. Delete test folders
  await creator.deleteTestFolders();

  // 4. Get dependencies
  final depManager = DependencyManager(config, runner: runner);

  // Link models first if created
  if (config.createModels) {
    await depManager.linkModelsToProjects();
  }

  await depManager.getAllDependencies();

  // 5. Run build_runner where needed
  await depManager.runAllBuildRunners();

  // 6. Generate deployment configuration
  if (config.useFirebase) {
    final configGenerator = ConfigGenerator(config);
    await configGenerator.generateAll();
  }

  if (config.createServer) {
    final serverSetup = ServerSetup(config);
    await serverSetup.generateAll();
  }

  // 7. Save configuration
  final configDir = Directory(p.join(config.outputDir, 'config'));
  if (!configDir.existsSync()) {
    await configDir.create(recursive: true);
  }
  await config.saveToFile(p.join(configDir.path, 'setup_config.env'));
  final File guide = await SetupGuidance.writeProjectGuide(config);
  final Directory docs = await DocsGenerator.write(config);

  // Print success message
  print('');
  success('\u2713 Project created successfully!');
  print('');
  print('Created:');
  UserPrompt.printList(SetupGuidance.createdProjectItems(config));

  SetupGuidance.printPostCreationChecklist(config);

  print('');
  UserPrompt.printList(<String>[
    'Generated guide: ${guide.path}',
    'Docs folder: ${docs.path}/',
    'Open the guide: oracular open guide',
    'Open the docs:  oracular open docs',
  ]);
  print('');
  UserPrompt.printSuccessBox('Happy coding!');
}
