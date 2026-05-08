import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../models/setup_config.dart';
import '../models/template_info.dart';
import '../utils/firebase_setup_prompts.dart';
import '../utils/process_runner.dart';
import '../utils/string_utils.dart';
import '../utils/setup_guidance.dart';
import '../utils/user_prompt.dart';
import '../utils/validators.dart';
import '../utils/wizard_navigation.dart';
import '../version.dart';
import '../cli/handlers/rebuild_handlers.dart' as rebuild_handler;
import 'config_generator.dart';
import 'dependency_manager.dart';
import 'docs_generator.dart';
import 'firebase_billing_service.dart' show BlazeStatus;
import 'firebase_setup_orchestrator.dart';
import 'project_creator.dart';
import 'server_setup.dart';
import 'template_copier.dart';
import 'tool_checker.dart';

/// Interactive wizard for project setup
class InteractiveWizard {
  final ToolChecker _toolChecker = ToolChecker();
  final bool verbose;

  // Wizard step tracking. Step 5 is "Cloud Setup" which the orchestrator
  // expands into 5.1 – 5.12 (Firebase) plus 6.x for Cloud Run / cleanup
  // when the project requested a server. Total stays at 6 to keep the top
  // banner consistent regardless of branching.
  static const int _totalSteps = 6;
  int _currentStep = 0;

  /// Failures encountered during setup, surfaced at the end of the wizard.
  final List<_WizardFailure> _failures = <_WizardFailure>[];

  /// Most recent orchestrator report — used by `_printSuccess` to render the
  /// "What was deployed" block (release URL, beta URL, Firestore region,
  /// Storage bucket, billing status).
  OrchestratorReport? _firebaseReport;

  /// Sub-step counters per top-level step (5 or 6). Reset whenever the
  /// wizard transitions phases so we can render labels like "Step 5.1",
  /// "Step 5.2" or "Step 6.1".
  final Map<int, int> _subStepCounters = <int, int>{
    5: 0,
    6: 0,
  };

  /// Process runner used while spinner UI is active. Non-interactive so
  /// failed commands don't try to prompt the user from behind the spinner.
  final ProcessRunner _spinnerRunner = ProcessRunner(interactive: false);

  /// Resolved absolute target directory chosen in the wizard intro. Used as
  /// the [SetupConfig.outputDir] when scaffolding projects.
  String _targetLocation = Directory.current.path;

  InteractiveWizard({this.verbose = false});

  void _recordFailure(
    String step, {
    String? hint,
  }) {
    _failures.add(_WizardFailure(step: step, hint: hint));
  }

  /// Run the full interactive wizard
  Future<void> run() async {
    _printWelcome();

    // Top-level action menu: pick whether to start fresh, rebuild an
    // existing project, or quit. Lets users invoke the rebuild flow
    // without remembering the `oracular rebuild` command.
    final _StartAction action = await _chooseStartAction();
    switch (action) {
      case _StartAction.start:
        await _runFreshSetup();
        return;
      case _StartAction.rebuild:
        await _runRebuildFlow();
        return;
      case _StartAction.quit:
        info('Goodbye.');
        return;
    }
  }

  /// First-screen menu so users can pick between a fresh setup, rebuilding
  /// an existing project (purge + rescaffold), or bailing out without
  /// having to remember the named subcommand.
  Future<_StartAction> _chooseStartAction() async {
    print('');
    UserPrompt.printDivider(title: 'What would you like to do?');
    final List<String> options = <String>[
      'Start a new project setup',
      'Rebuild / refresh an existing project (purge + rescaffold, Firebase untouched)',
      'Quit',
    ];
    try {
      final int choice = await UserPrompt.showMenu(
        'Select an action',
        options,
        defaultIndex: 0,
      );
      switch (choice) {
        case 0:
          return _StartAction.start;
        case 1:
          return _StartAction.rebuild;
        default:
          return _StartAction.quit;
      }
    } on Object {
      // Fallback path: any unexpected error → assume start.
      return _StartAction.start;
    }
  }

  /// Run the rebuild flow by delegating to the shared `oracular rebuild`
  /// handler. Runs interactively so the user gets the same purge plan
  /// preview / confirm UX as the CLI command.
  Future<void> _runRebuildFlow() async {
    print('');
    info(
      'Rebuild reuses the SetupConfig saved at <project>/config/setup_config.env.',
    );
    UserPrompt.printList(<String>[
      'You will be prompted for the project root.',
      'Only the folders Oracular originally created are deleted.',
      'Firebase / IAM / Cloud Run setup is left untouched.',
    ]);
    print('');

    String? configPath;
    String? outputDir;
    while (true) {
      try {
        outputDir = await WizardNav.askString(
          'Project root (contains config/setup_config.env)',
          defaultValue: Directory.current.path,
          fromStep: 'rebuild project root',
        );
        break;
      } on BackNavigation {
        // User asked to go back from the only prompt — return to the
        // action menu by re-running the wizard from the top.
        await run();
        return;
      } on CancelNavigation {
        warn('Rebuild cancelled.');
        return;
      }
    }

    final String resolved = _resolveTargetPath(outputDir);
    final String defaultConfig =
        p.join(resolved, 'config', 'setup_config.env');
    if (File(defaultConfig).existsSync()) {
      configPath = defaultConfig;
    }

    final Map<String, dynamic> rebuildArgs = <String, dynamic>{
      'output-dir': resolved,
    };
    if (configPath != null) {
      rebuildArgs['config'] = configPath;
    }
    await rebuild_handler.handleRebuild(rebuildArgs, <String, dynamic>{});
  }

  /// The original linear "fresh setup" pipeline, lifted out of `run()`
  /// so the action menu can route to it cleanly. Behaviourally identical
  /// to v3.3.6 — only relocated.
  Future<void> _runFreshSetup() async {
    // Intro: pick the target location before anything else so the user
    // knows exactly where the project will land.
    if (!await _askTargetLocation()) {
      warn('Setup cancelled');
      return;
    }

    // Step 1: Check tools
    _currentStep = 0;
    UserPrompt.printStepIndicator(
      _currentStep,
      _totalSteps,
      'Environment Check',
    );
    if (!await _checkTools()) {
      return;
    }

    // Step 2: Gather configuration
    _currentStep = 1;
    UserPrompt.printStepIndicator(
      _currentStep,
      _totalSteps,
      'Project Configuration',
    );
    final config = await _gatherConfiguration();
    if (config == null) {
      warn('Setup cancelled');
      return;
    }

    // Step 3: Confirm configuration
    _currentStep = 2;
    UserPrompt.printStepIndicator(_currentStep, _totalSteps, 'Review Settings');
    if (!await _confirmConfiguration(config)) {
      warn('Setup cancelled');
      return;
    }

    // Step 4: Execute setup
    _currentStep = 3;
    UserPrompt.printStepIndicator(
      _currentStep,
      _totalSteps,
      'Creating Project',
    );
    await _executeSetup(config);

    // Step 5: Optional Firebase + Cloud Run / Cleanup setup. The
    // orchestrator dispatches Step 5.x (Firebase) and Step 6.x (Cloud Run +
    // cleanup) based on the SetupConfig flags.
    _currentStep = 4;
    if (config.useFirebase) {
      UserPrompt.printStepIndicator(
        _currentStep,
        _totalSteps,
        'Cloud Setup',
      );
      await _offerFirebaseSetup(config);
    }

    _printSuccess(config);
  }

  void _printWelcome() {
    UserPrompt.clearScreen();
    UserPrompt.printBanner(
      'Welcome to Oracular Setup Wizard',
      subtitle: 'Arcane Template System  \u00b7  v$oracularVersion',
    );
    info('This wizard will help you create a new Arcane project.');
    print('');
    UserPrompt.printList(<String>[
      'Use \u2191\u2193 arrow keys to navigate menus',
      'Press Space to toggle selections',
      'Press Enter to confirm',
      'Type "back" / "b" / "<" at any prompt to go back one step',
      'Type "quit" / "q" to abort the wizard',
    ]);
    print('');
  }

  /// Ask the user where the new project should live. Runs as part of the
  /// intro so the resolved absolute path is known before any other config is
  /// collected. Returns false if the user backs out or the directory cannot
  /// be created.
  Future<bool> _askTargetLocation() async {
    UserPrompt.printDivider(title: 'Target Location');
    final String defaultPath = Directory.current.path;
    print('  Where should the new project be created?');
    UserPrompt.printList(<String>[
      'Press Enter to use the current directory',
      'Type an absolute path (/Users/me/code) or relative path (./projects)',
      'Use ~ as a shortcut for your home directory',
    ]);
    print('  Default: $defaultPath');
    print('');

    final String input = await UserPrompt.askString(
      'Target location',
      defaultValue: defaultPath,
      validator: (String s) => validatePath(s).isValid,
      validationMessage: 'Path contains invalid characters',
    );

    final String resolved = _resolveTargetPath(input);

    // Reject pointing at a non-directory.
    final FileSystemEntityType entityType =
        FileSystemEntity.typeSync(resolved);
    if (entityType == FileSystemEntityType.file ||
        entityType == FileSystemEntityType.link) {
      UserPrompt.printErrorBox(
        'Target is not a directory',
        hint: '$resolved already exists as a file. Pick a different target.',
      );
      return false;
    }

    // Create the directory if it doesn't exist (with confirmation).
    final Directory dir = Directory(resolved);
    if (!dir.existsSync()) {
      print('');
      info('Target does not exist yet: $resolved');
      final bool create = await UserPrompt.askYesNo(
        'Create this directory?',
        defaultValue: true,
      );
      if (!create) {
        return false;
      }
      try {
        dir.createSync(recursive: true);
      } catch (e) {
        UserPrompt.printErrorBox(
          'Could not create directory',
          hint: 'Error: $e',
        );
        return false;
      }
    }

    _targetLocation = resolved;
    if (resolved != defaultPath) {
      print('');
      info('Using target: $resolved');
    }
    print('');
    return true;
  }

  /// Resolve a user-supplied path. Handles `~` expansion and converts
  /// relative paths to absolute paths anchored at the current working
  /// directory. The returned path is normalized.
  String _resolveTargetPath(String raw) {
    String value = raw.trim();
    if (value.isEmpty) {
      return p.normalize(Directory.current.path);
    }

    // Expand leading ~ to the user's home directory.
    if (value == '~' || value.startsWith('~/') || value.startsWith('~\\')) {
      final String home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '';
      if (home.isNotEmpty) {
        value = value == '~' ? home : p.join(home, value.substring(2));
      }
    }

    if (p.isAbsolute(value)) {
      return p.normalize(value);
    }
    return p.normalize(p.absolute(value));
  }

  /// Clear the terminal and re-print a compact section header so that the
  /// upcoming interactive prompt (especially multi-selects) has a clean
  /// viewport. Without this, prompts that wipe-and-redraw on every keypress
  /// (interact's `MultiSelect`) leave visual artifacts as the cursor scrolls
  /// over previously printed help text.
  void _resetViewport(
    List<String> contextLines, {
    required String section,
  }) {
    UserPrompt.clearScreen();
    UserPrompt.printBanner(
      'Oracular Setup',
      subtitle: 'v$oracularVersion  \u00b7  Step ${_currentStep + 1} of '
          '$_totalSteps  \u00b7  $section',
    );
    if (contextLines.isNotEmpty) {
      UserPrompt.printList(contextLines);
      print('');
    }
  }

  Future<bool> _checkTools() async {
    final result = await _toolChecker.checkRequired();

    if (!result.allRequiredInstalled) {
      print('');
      result.printSummary();
      UserPrompt.printErrorBox(
        'Missing required tools',
        hint: 'Install the tools above before continuing.',
      );
      return false;
    }

    print('');
    success('All required tools are installed!');
    print('');
    return true;
  }

  Future<SetupConfig?> _gatherConfiguration() async {
    // ── Section 1: Basic Info ──
    UserPrompt.printDivider(title: 'Basic Information');

    // App name
    final appName = await UserPrompt.askString(
      'App name (snake_case)',
      defaultValue: 'my_app',
      validator: (s) => validateAppName(s).isValid,
      validationMessage:
          'App name must be lowercase with underscores (e.g., my_app)',
    );

    // Organization domain
    final orgDomain = await UserPrompt.askString(
      'Organization domain',
      defaultValue: 'com.example',
    );

    // Base class name (auto-generate suggestion)
    final suggestedClassName = snakeToPascal(appName);
    final baseClassName = await UserPrompt.askString(
      'Base class name (PascalCase)',
      defaultValue: suggestedClassName,
    );

    // ── Section 2: Template Selection ──
    _resetViewport(<String>[
      'App: $appName  ·  Org: $orgDomain  ·  Class: $baseClassName',
      'Target: $_targetLocation',
    ], section: 'Template Selection');

    // Template selection with descriptions
    final templateIndex = await UserPrompt.askTheme(
      'Select a project template',
      TemplateType.values.map((t) => t.displayName).toList(),
      TemplateType.values.map((t) => t.description).toList(),
      initialIndex: 0,
    );
    final template = TemplateType.values[templateIndex];

    // Output directory was selected during the intro; reuse it here so the
    // user isn't prompted twice.
    final String outputDir = _targetLocation;

    // ── Section 3: Platform Selection ──
    // Only show for Flutter apps that have platform choices
    // Skip for: Dart CLI, arcaneDock (fixed platforms)
    List<String> selectedPlatforms = template.supportedPlatforms;

    final bool showPlatformSelection =
        template.isFlutterApp &&
        template != TemplateType.arcaneDock &&
        template.supportedPlatforms.length > 1;

    if (showPlatformSelection) {
      _resetViewport(<String>[
        'Template: ${template.displayName}',
        'Space to toggle  ·  Enter to confirm  ·  At least one required',
      ], section: 'Target Platforms');

      final platformIndices = await UserPrompt.askMultiSelect(
        'Target platforms',
        template.supportedPlatforms,
        defaultSelected: template.supportedPlatforms,
      );

      selectedPlatforms = platformIndices
          .map((i) => template.supportedPlatforms[i])
          .toList();

      if (selectedPlatforms.isEmpty) {
        warn('At least one platform must be selected');
        selectedPlatforms = template.supportedPlatforms;
      }

      // Offer to prioritize platforms
      if (selectedPlatforms.length > 1) {
        final prioritize = await UserPrompt.askYesNo(
          'Would you like to prioritize platform order?',
          defaultValue: false,
        );

        if (prioritize) {
          selectedPlatforms = await UserPrompt.askPrioritize(
            'Drag to reorder platforms (most important first)',
            selectedPlatforms,
          );
        }
      }
    } else if (template == TemplateType.arcaneDock) {
      // Dock app: desktop platforms only
      info('Desktop dock app targets: macOS, Linux, Windows');
    } else if (template.isDartCli) {
      // Dart CLI: no platforms needed
      info('Dart CLI app - no platform selection needed');
    }

    // ── Section 4: Additional Packages ──
    // Customize options based on template type
    bool createModels = false;
    bool createServer = false;

    if (template.isDartCli) {
      // Dart CLI: only offer models package (server is unusual for CLI)
      _resetViewport(<String>[
        'Template: ${template.displayName}',
        'Shared Models Package = reusable data classes for CLI + app/server.',
      ], section: 'Additional Packages');
      createModels = await UserPrompt.askYesNo(
        'Create shared models package?',
        defaultValue: true,
      );
      // Skip server for CLI apps
    } else {
      // Flutter apps: offer both models and server
      _resetViewport(<String>[
        'Template: ${template.displayName}',
        'Models = shared data classes  ·  Server = backend API',
        'Space to toggle  ·  Enter to confirm',
      ], section: 'Additional Packages');

      final additionalFeatures = await UserPrompt.askMultiSelectNames(
        'Select additional packages',
        ['Shared Models Package', 'Server Application'],
        defaultSelected: ['Shared Models Package'],
      );

      createModels = additionalFeatures.contains('Shared Models Package');
      createServer = additionalFeatures.contains('Server Application');
    }

    // ── Section 5: Firebase Integration ──
    final List<String> cloudContext = <String>[
      'Template: ${template.displayName}',
    ];
    if (createModels || createServer) {
      final List<String> packages = <String>[
        if (createModels) 'Models',
        if (createServer) 'Server',
      ];
      cloudContext.add('Packages: ${packages.join(' + ')}');
    }
    _resetViewport(cloudContext, section: 'Cloud Services');

    // Firebase
    final useFirebase = await UserPrompt.askYesNo(
      'Enable Firebase integration?',
      defaultValue: false,
    );

    String? firebaseProjectId;
    bool setupCloudRun = false;
    String? serviceAccountKeyPath;

    if (useFirebase) {
      firebaseProjectId = await UserPrompt.askString(
        'Firebase project ID',
        validator: (s) => validateFirebaseProjectId(s).isValid,
        validationMessage: 'Invalid Firebase project ID',
      );

      // Cloud Run (only if server is enabled)
      if (createServer) {
        setupCloudRun = await UserPrompt.askYesNo(
          'Setup Cloud Run for server deployment?',
          defaultValue: false,
        );
      }
    }

    // Service account key (optional now, needed later for server deployment)
    if (createServer && useFirebase && firebaseProjectId != null) {
      serviceAccountKeyPath =
          await FirebaseSetupPrompts.askServiceAccountKeyPath(
        outputDir: outputDir,
        serverPackageName: '${appName}_server',
      );
    }

    return SetupConfig(
      appName: appName,
      orgDomain: orgDomain,
      baseClassName: baseClassName,
      template: template,
      outputDir: outputDir,
      createModels: createModels,
      createServer: createServer,
      useFirebase: useFirebase,
      firebaseProjectId: firebaseProjectId,
      setupCloudRun: setupCloudRun,
      serviceAccountKeyPath: serviceAccountKeyPath,
      platforms: selectedPlatforms,
    );
  }

  Future<bool> _confirmConfiguration(SetupConfig config) async {
    UserPrompt.printConfigPreview(config.toDisplayMap());
    print('');

    return await UserPrompt.askYesNo('Proceed with these settings?');
  }

  Future<void> _executeSetup(SetupConfig config) async {
    UserPrompt.printDivider(title: 'Creating Project');

    // Create projects with spinner
    try {
      await UserPrompt.withSpinner('Creating project structure...', () async {
        final creator = ProjectCreator(config, runner: _spinnerRunner);
        if (!await creator.createAllProjects()) {
          throw Exception('Failed to create projects');
        }
        // Clean up test folders while we're at it
        await creator.deleteTestFolders();
      },
        doneMessage: '✓ Project structure created',
        failedMessage: '✗ Project creation failed',
      );
    } catch (e) {
      _recordFailure(
        'Project structure',
        hint: 'Could not run flutter/dart create. Error: $e',
      );
      // No point continuing without project skeletons
      return;
    }

    // Copy templates with spinner (downloads from GitHub if needed)
    try {
      await UserPrompt.withSpinner('Preparing templates...', () async {
        final copier = await TemplateCopier.create(config);
        await copier.copyAll();
      },
        doneMessage: '✓ Template files copied',
        failedMessage: '✗ Template copy failed',
      );
    } catch (e) {
      _recordFailure(
        'Template copy',
        hint: 'Templates could not be copied. Error: $e',
      );
      // Templates are required for the rest to work
      return;
    }

    // Link models if needed
    final depManager = DependencyManager(config, runner: _spinnerRunner);
    if (config.createModels) {
      try {
        await UserPrompt.withSpinner('Linking models package...', () async {
          await depManager.linkModelsToProjects();
        },
          doneMessage: '✓ Models package linked',
          failedMessage: '✗ Models linking failed',
        );
      } catch (e) {
        _recordFailure(
          'Models linking',
          hint: 'Could not add path dependency to models. Error: $e',
        );
      }
    }

    // Get dependencies with spinner (this can take a while)
    final bool depsOk = await UserPrompt.withSpinner(
      'Installing dependencies (this may take a moment)...',
      () async => await depManager.getAllDependencies(),
      doneMessage: '✓ Dependencies installed',
      failedMessage: '✗ Dependency install had issues',
    );
    if (!depsOk) {
      _recordFailure(
        'Dependencies',
        hint:
            'Some pub get commands failed. Run `flutter pub get` or `dart pub get` manually in each package.',
      );
    }

    // Run build_runner with spinner
    final bool buildOk = await UserPrompt.withSpinner(
      'Running code generation...',
      () async => await depManager.runAllBuildRunners(),
      doneMessage: '✓ Code generation complete',
      failedMessage: '✗ Code generation had issues',
    );
    if (!buildOk) {
      _recordFailure(
        'Code generation',
        hint:
            'build_runner failed. After fixing dependencies, run `dart run build_runner build --delete-conflicting-outputs`.',
      );
    }

    // Generate Firebase configs if enabled
    if (config.useFirebase) {
      try {
        await UserPrompt.withSpinner(
          'Generating Firebase configuration...',
          () async {
            final configGen = ConfigGenerator(config);
            await configGen.generateAll();
          },
          doneMessage: '✓ Firebase config generated',
          failedMessage: '✗ Firebase config generation failed',
        );
      } catch (e) {
        _recordFailure(
          'Firebase config files',
          hint: 'Could not generate firebase.json/.firebaserc. Error: $e',
        );
      }
    }

    // Generate server files if enabled
    if (config.createServer) {
      try {
        await UserPrompt.withSpinner(
          'Setting up server deployment...',
          () async {
            final serverSetup = ServerSetup(config, runner: _spinnerRunner);
            await serverSetup.generateAll();
          },
          doneMessage: '✓ Server setup complete',
          failedMessage: '✗ Server setup failed',
        );
      } catch (e) {
        _recordFailure(
          'Server setup',
          hint: 'Server deployment files could not be created. Error: $e',
        );
      }
    }

    // Save configuration (always best-effort)
    try {
      await UserPrompt.withSpinner(
        'Saving configuration...',
        () async {
          final configDir = Directory(p.join(config.outputDir, 'config'));
          if (!configDir.existsSync()) {
            await configDir.create(recursive: true);
          }
          await config.saveToFile(p.join(configDir.path, 'setup_config.env'));
          await SetupGuidance.writeProjectGuide(config);
          await DocsGenerator.write(config);
        },
        doneMessage: '✓ Configuration saved',
        failedMessage: '✗ Configuration save failed',
      );
    } catch (e) {
      _recordFailure(
        'Configuration save',
        hint:
            'Could not write setup_config.env, GET_STARTED.md or docs/. Error: $e',
      );
    }

    print('');
    if (_failures.isEmpty) {
      UserPrompt.printSuccessBox('Project created successfully!');
    } else {
      UserPrompt.printErrorBox(
        'Project created with ${_failures.length} issue(s)',
        hint: 'Review the issues below and rerun the failed steps.',
      );
    }
  }

  Future<void> _offerFirebaseSetup(SetupConfig config) async {
    UserPrompt.printDivider(title: 'Firebase Setup');

    final bool setupNow = await UserPrompt.askYesNo(
      'Would you like to setup Firebase now?',
      defaultValue: true,
    );

    if (!setupNow) {
      print('');
      UserPrompt.printList(<String>[
        'You can run Firebase setup later with:',
        '  oracular deploy firebase-setup-full',
      ]);
      return;
    }

    // Gating questions to override SetupConfig defaults *before* running
    // the orchestrator. Keeps us from interrupting the run with 12
    // separate yes/no prompts.
    final SetupConfig effective = await _gatherFirebaseSubStepConfig(config);

    final FirebaseSetupOrchestrator orchestrator =
        FirebaseSetupOrchestrator(effective, runner: _spinnerRunner);

    // Reset per-phase sub-step counters so labelling starts at 5.1 / 6.1.
    _subStepCounters[5] = 0;
    _subStepCounters[6] = 0;

    final OrchestratorReport report = await orchestrator.runAll(
      confirm: (WizardSubStep step) async {
        _printSubStepStarting(step);
        return true;
      },
      onStep: (SetupStepResult result) async {
        _printSubStepResult(result);
        if (result.failed) {
          _recordFailure(
            'Step ${_subStepLabelFor(result.step)} ${result.step.label}',
            hint: result.fixHint.isNotEmpty
                ? 'Run: ${result.fixHint}'
                : (result.message.isNotEmpty
                    ? result.message
                    : 'See the orchestrator output above for details.'),
          );
        }
      },
      onFailure: _promptFailureAction,
    );

    _firebaseReport = report;

    print('');
    if (report.aborted) {
      UserPrompt.printErrorBox(
        'Firebase setup aborted at your request',
        hint:
            'Fix the issue above, then run: oracular deploy firebase-setup-full',
      );
    } else if (report.success && report.failedCount == 0) {
      final List<String> details = <String>[];
      if (report.releaseUrl != null) {
        details.add('Release: ${report.releaseUrl}');
      }
      if (report.betaUrl != null) {
        details.add('Beta:    ${report.betaUrl}');
      }
      if (report.firestoreRegion != null) {
        details.add('Firestore region: ${report.firestoreRegion}');
      }
      if (report.storageBucketName != null) {
        details.add('Storage bucket:  gs://${report.storageBucketName}');
      }
      UserPrompt.printSuccessBox(
        'Firebase setup complete!',
        details: details.isEmpty ? null : details,
      );
    } else {
      UserPrompt.printErrorBox(
        'Firebase setup completed with ${report.failedCount} issue(s)',
        hint: 'Review the issues at the end of the wizard output.',
      );
    }
  }

  /// Convert the high-level config flags into the actual orchestrator
  /// inputs by asking the user a small set of gating questions. This
  /// replaces the per-substep `confirm` prompts so the user is not
  /// interrupted in the middle of the run.
  Future<SetupConfig> _gatherFirebaseSubStepConfig(SetupConfig config) async {
    print('');
    info('Tell me which parts of Firebase setup to run now.');
    info('You can rerun any step later with `oracular deploy <command>`.');
    print('');

    // ── Hosting ────────────────────────────────────────────────────────────
    bool deployRelease = config.deployHostingRelease;
    bool deployBeta = config.deployHostingBeta;
    if (SetupGuidance.supportsWebHosting(config)) {
      final String releaseLabel = config.template.isJasprApp
          ? 'Build & deploy the Jaspr release site (`${config.firebaseProjectId}.web.app`) now?'
          : 'Build & deploy the Flutter release site (`${config.firebaseProjectId}.web.app`) now?';
      deployRelease = await UserPrompt.askYesNo(
        releaseLabel,
        defaultValue: deployRelease,
      );

      deployBeta = await UserPrompt.askYesNo(
        'Also create + deploy `${config.firebaseProjectId}-beta` site?',
        defaultValue: deployBeta,
      );
    }

    // ── Firestore + Storage bootstrapping ──────────────────────────────────
    final bool initFirestore = await UserPrompt.askYesNo(
      'Initialize the default Firestore database (region: ${config.firestoreRegion})?',
      defaultValue: config.initializeFirestore,
    );

    final bool initStorage = await UserPrompt.askYesNo(
      'Initialize the default Storage bucket (gs://${config.firebaseProjectId}.firebasestorage.app)?',
      defaultValue: config.initializeStorage,
    );

    // ── Auth providers ─────────────────────────────────────────────────────
    final bool wantAuth = await UserPrompt.askYesNo(
      'Enable Email/Password + Google sign-in providers? (manual hand-off)',
      defaultValue: config.enableEmailAuth || config.enableGoogleAuth,
    );

    // ── Cloud Run cleanup (only if Cloud Run / server enabled) ─────────────
    bool setupCleanup = config.setupArtifactCleanup;
    if (config.setupCloudRun || config.createServer) {
      setupCleanup = await UserPrompt.askYesNo(
        'Apply Artifact Registry cleanup + cap Cloud Run revisions? '
        '(keeps storage bounded)',
        defaultValue: setupCleanup,
      );
    }

    return config.copyWith(
      deployHostingRelease: deployRelease,
      deployHostingBeta: deployBeta,
      initializeFirestore: initFirestore,
      initializeStorage: initStorage,
      enableEmailAuth: wantAuth,
      enableGoogleAuth: wantAuth,
      setupArtifactCleanup: setupCleanup,
    );
  }

  /// Prompt the user when a Firebase sub-step fails: Retry / Skip / Abort.
  ///
  /// Pretty-prints the failure with the `fixHint` (if any) so the user can
  /// run a manual command in another terminal before choosing **Retry**.
  /// Honours fail-fast: by default the wizard aborts the whole run on the
  /// first failure unless the user explicitly skips.
  Future<FailureAction> _promptFailureAction(
    SetupStepResult result, {
    required int attempt,
  }) async {
    print('');
    UserPrompt.printDivider(title: 'Step failed');
    error('  Step ${_subStepLabelFor(result.step)} · ${result.step.label}');
    if (result.message.isNotEmpty) {
      error('  Reason: ${result.message}');
    }
    if (result.fixHint.isNotEmpty) {
      info('  Suggested fix: ${result.fixHint}');
    }
    if (attempt > 1) {
      info('  Retry attempt #$attempt');
    }
    print('');
    info('What would you like to do?');
    info('  [r] Retry this step (default)');
    info('  [s] Skip this step and continue with the rest of setup');
    info('  [a] Abort Firebase setup (you can resume later with: oracular deploy firebase-setup-full)');
    print('');

    while (true) {
      final String answer = (await UserPrompt.askString(
        'Action [r/s/a]',
        defaultValue: 'r',
      ))
          .trim()
          .toLowerCase();
      switch (answer) {
        case '':
        case 'r':
        case 'retry':
          return FailureAction.retry;
        case 's':
        case 'skip':
          return FailureAction.skip;
        case 'a':
        case 'abort':
        case 'q':
        case 'quit':
          return FailureAction.abort;
        default:
          error('Please answer r (retry), s (skip), or a (abort).');
      }
    }
  }

  /// Top-level phase number (5 or 6) a sub-step belongs to.
  int _phaseNumberFor(WizardSubStep step) {
    switch (step) {
      case WizardSubStep.enableServerApis:
      case WizardSubStep.ensureArtifactRegistryRepo:
      case WizardSubStep.applyArtifactCleanupPolicy:
      case WizardSubStep.capCloudRunRevisions:
        return 6;
      default:
        return 5;
    }
  }

  /// "5.3" / "6.1" — incremented every time `confirm` fires.
  String _subStepLabelFor(WizardSubStep step) {
    final int phase = _phaseNumberFor(step);
    final int counter = _subStepCounters[phase] ?? 0;
    return '$phase.$counter';
  }

  void _printSubStepStarting(WizardSubStep step) {
    final int phase = _phaseNumberFor(step);
    _subStepCounters[phase] = (_subStepCounters[phase] ?? 0) + 1;
    print('');
    print(
      '  ▶ Step ${_subStepLabelFor(step)} · ${step.label}…',
    );
  }

  void _printSubStepResult(SetupStepResult result) {
    final String label = _subStepLabelFor(result.step);
    final String message = result.message.isNotEmpty
        ? '  ·  ${result.message}'
        : '';
    switch (result.status) {
      case SetupStepStatus.success:
        success('  ✓ Step $label · ${result.step.label}$message');
        break;
      case SetupStepStatus.skipped:
        info('  ⏭  Step $label · ${result.step.label}$message');
        if (result.fixHint.isNotEmpty) {
          info('     Run later: ${result.fixHint}');
        }
        break;
      case SetupStepStatus.failed:
        error('  ✗ Step $label · ${result.step.label}$message');
        if (result.fixHint.isNotEmpty) {
          info('     Fix: ${result.fixHint}');
        }
        break;
    }
  }

  void _printSuccess(SetupConfig config) {
    if (_failures.isEmpty) {
      UserPrompt.printBanner('Project Created Successfully!');
    } else {
      UserPrompt.printBanner('Project Created With Issues');
    }

    // List created packages
    final List<String> createdItems = SetupGuidance.createdProjectItems(config);

    print('Created:');
    UserPrompt.printList(createdItems);

    if (_firebaseReport != null) {
      _printDeploymentSummary(config, _firebaseReport!);
    }

    if (_failures.isNotEmpty) {
      _printFailureSummary();
    }

    SetupGuidance.printPostCreationChecklist(config, report: _firebaseReport);

    print('');
    if (_failures.isEmpty) {
      UserPrompt.printSuccessBox('Happy coding!');
    } else {
      UserPrompt.printErrorBox(
        '${_failures.length} step(s) need your attention',
        hint: 'Resolve the items listed under "Setup Issues" before deploying.',
      );
    }
  }

  /// Render a "What was deployed" summary block (live URLs + Firebase /
  /// Cloud consoles) once the orchestrator has run. Skipped pieces are
  /// silently omitted — the post-creation checklist (T12) tells the user
  /// what to do next.
  void _printDeploymentSummary(SetupConfig config, OrchestratorReport report) {
    final String? projectId = config.firebaseProjectId;
    if (projectId == null) {
      return;
    }

    print('');
    UserPrompt.printDivider(title: 'What was deployed');

    final List<String> lines = <String>[];

    // ── Live hosting URLs ────────────────────────────────────────────────
    if (report.releaseUrl != null) {
      final String label = config.template.isJasprApp
          ? (config.template == TemplateType.arcaneJasprDocs
              ? 'Jaspr docs site (release)'
              : 'Jaspr web app (release)')
          : 'Flutter web app (release)';
      lines.add('$label: ${report.releaseUrl}');
    }
    if (report.betaUrl != null) {
      final String label = config.template.isJasprApp
          ? (config.template == TemplateType.arcaneJasprDocs
              ? 'Jaspr docs site (beta)'
              : 'Jaspr web app (beta)')
          : 'Flutter web app (beta)';
      lines.add('$label: ${report.betaUrl}');
    }

    // ── Bootstrapped Firebase resources ──────────────────────────────────
    if (report.firestoreRegion != null) {
      lines.add(
        'Firestore default database: ${report.firestoreRegion}  '
        '(${SetupGuidance.firebaseFirestoreConsoleUrl(projectId)})',
      );
    }
    if (report.storageBucketName != null) {
      lines.add(
        'Storage bucket: gs://${report.storageBucketName}  '
        '(${SetupGuidance.firebaseStorageConsoleUrl(projectId)})',
      );
    }

    // ── Auth providers (if requested + setup completed) ──────────────────
    final bool authConfigured = report.results.any(
      (SetupStepResult r) =>
          r.step == WizardSubStep.enableAuthProviders && r.success,
    );
    if (authConfigured) {
      final List<String> providers = <String>[
        if (config.enableEmailAuth) 'Email/Password',
        if (config.enableGoogleAuth) 'Google',
      ];
      lines.add(
        'Auth providers: ${providers.join(' + ')}  '
        '(${SetupGuidance.firebaseAuthenticationConsoleUrl(projectId)})',
      );
    }

    // ── Billing status ──────────────────────────────────────────────────
    if (report.blazeStatus != null) {
      switch (report.blazeStatus!) {
        case BlazeStatus.enabled:
          lines.add('Billing: Blaze (pay-as-you-go) — Cloud Run enabled');
          break;
        case BlazeStatus.notEnabled:
          lines.add(
            'Billing: Spark (free) — Cloud Run skipped. Upgrade later: '
            'https://console.firebase.google.com/project/$projectId/usage/details',
          );
          break;
        case BlazeStatus.unknown:
          lines.add(
            'Billing: not detected — verify with `oracular check billing`',
          );
          break;
      }
    }

    // ── Cloud Run + Artifact Registry (when server steps ran) ────────────
    final bool cloudRunReady = report.results.any(
      (SetupStepResult r) =>
          r.step == WizardSubStep.enableServerApis && r.success,
    );
    if (cloudRunReady && config.createServer) {
      final String service = config.serverPackageName.replaceAll('_', '-');
      lines.add(
        'Cloud Run service: $service  '
        '(${SetupGuidance.cloudRunConsoleUrl(projectId)})',
      );
    }
    final bool cleanupApplied = report.results.any(
      (SetupStepResult r) =>
          r.step == WizardSubStep.applyArtifactCleanupPolicy && r.success,
    );
    if (cleanupApplied) {
      lines.add(
        'Artifact Registry cleanup: keep ${config.artifactKeepRecent} recent + '
        'delete >${config.artifactDeleteOlderDays}d',
      );
    }

    if (lines.isEmpty) {
      // Nothing was actually deployed — the orchestrator ran but every
      // hosting / init step was skipped or failed. Don't show the box.
      return;
    }

    UserPrompt.printList(lines);

    // Run summary footer
    print('');
    print(
      '  ${report.successCount} succeeded · '
      '${report.skippedCount} skipped · '
      '${report.failedCount} failed',
    );
  }

  void _printFailureSummary() {
    print('');
    UserPrompt.printDivider(title: 'Setup Issues');
    final List<String> lines = <String>[];
    for (int i = 0; i < _failures.length; i++) {
      final _WizardFailure failure = _failures[i];
      lines.add('${i + 1}. ${failure.step}');
      if (failure.hint != null) {
        lines.add('   Fix: ${failure.hint}');
      }
    }
    UserPrompt.printList(lines);
  }
}

class _WizardFailure {
  final String step;
  final String? hint;

  _WizardFailure({required this.step, this.hint});
}

/// Top-level action picked from the wizard's welcome menu.
enum _StartAction {
  /// Run the original linear setup wizard.
  start,

  /// Purge + rescaffold an existing project from saved config — same flow
  /// as `oracular rebuild` from the CLI.
  rebuild,

  /// Exit without doing anything.
  quit,
}
