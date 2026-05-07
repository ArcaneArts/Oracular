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
import 'config_generator.dart';
import 'dependency_manager.dart';
import 'firebase_service.dart';
import 'project_creator.dart';
import 'server_setup.dart';
import 'template_copier.dart';
import 'tool_checker.dart';

/// Interactive wizard for project setup
class InteractiveWizard {
  final ToolChecker _toolChecker = ToolChecker();
  final bool verbose;

  // Wizard step tracking
  static const int _totalSteps = 5;
  int _currentStep = 0;

  /// Failures encountered during setup, surfaced at the end of the wizard.
  final List<_WizardFailure> _failures = <_WizardFailure>[];

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

    // Step 5: Optional Firebase setup
    _currentStep = 4;
    if (config.useFirebase) {
      UserPrompt.printStepIndicator(
        _currentStep,
        _totalSteps,
        'Firebase Setup',
      );
      await _offerFirebaseSetup(config);
    }

    _printSuccess(config);
  }

  void _printWelcome() {
    UserPrompt.clearScreen();
    UserPrompt.printBanner(
      'Welcome to Oracular Setup Wizard',
      subtitle: 'Arcane Template System v2.1',
    );
    info('This wizard will help you create a new Arcane project.');
    print('');
    UserPrompt.printList(<String>[
      'Use \u2191\u2193 arrow keys to navigate menus',
      'Press Space to toggle selections',
      'Press Enter to confirm',
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
    UserPrompt.printDivider(title: 'Template Selection');

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
    info('Output directory: $outputDir');

    // ── Section 3: Platform Selection ──
    // Only show for Flutter apps that have platform choices
    // Skip for: Dart CLI, arcaneDock (fixed platforms)
    List<String> selectedPlatforms = template.supportedPlatforms;

    final bool showPlatformSelection =
        template.isFlutterApp &&
        template != TemplateType.arcaneDock &&
        template.supportedPlatforms.length > 1;

    if (showPlatformSelection) {
      UserPrompt.printDivider(title: 'Target Platforms');
      print('  Select the platforms you want to target:');

      final platformIndices = await UserPrompt.askMultiSelect(
        'Target platforms (Space to toggle)',
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
      UserPrompt.printDivider(title: 'Additional Packages');
      print('  Optional package:');
      UserPrompt.printList(<String>[
        'Shared Models Package: reusable data models and serialization for sharing types across apps.',
        'Pick this if your CLI will share entities with a server/mobile/web app.',
        'Prompt control: press Enter to accept the default choice.',
      ]);
      createModels = await UserPrompt.askYesNo(
        'Create shared models package?',
        defaultValue: true,
      );
      // Skip server for CLI apps
    } else {
      // Flutter apps: offer both models and server
      UserPrompt.printDivider(title: 'Additional Packages');
      print('  Optional packages:');
      UserPrompt.printList(<String>[
        'Shared Models Package: keeps data classes in one place so app/server use the same schema.',
        'Server Application: backend service for APIs, admin tasks, and private logic not run on client apps.',
        'Controls: use ↑↓ to move, Space to toggle a package, Enter to confirm.',
      ]);

      final additionalFeatures = await UserPrompt.askMultiSelectNames(
        'Select additional packages to create (Space to toggle)',
        ['Shared Models Package', 'Server Application'],
        defaultSelected: ['Shared Models Package'],
      );

      createModels = additionalFeatures.contains('Shared Models Package');
      createServer = additionalFeatures.contains('Server Application');
    }

    // ── Section 5: Firebase Integration ──
    UserPrompt.printDivider(title: 'Cloud Services');

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
        },
        doneMessage: '✓ Configuration saved',
        failedMessage: '✗ Configuration save failed',
      );
    } catch (e) {
      _recordFailure(
        'Configuration save',
        hint: 'Could not write setup_config.env or GET_STARTED.md. Error: $e',
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

    final setupNow = await UserPrompt.askYesNo(
      'Would you like to setup Firebase now?',
      defaultValue: true,
    );

    if (!setupNow) {
      print('');
      UserPrompt.printList([
        'You can run Firebase setup later with:',
        '  oracular deploy firebase-setup',
      ]);
      return;
    }

    final firebase = FirebaseService(config, runner: _spinnerRunner);

    // Login to Firebase with spinner
    final bool loginOk = await UserPrompt.withSpinner(
      'Logging in to Firebase...',
      () async => await firebase.login(),
      doneMessage: '✓ Firebase login complete',
      failedMessage: '✗ Firebase login failed',
    );
    if (!loginOk) {
      _recordFailure(
        'Firebase login',
        hint:
            'Run `firebase login` (or place a service-account.json) and rerun `oracular deploy firebase-setup`.',
      );
      // Without login, the rest will fail too. Surface guidance and bail.
      return;
    }

    // Login to gcloud if Cloud Run enabled
    if (config.setupCloudRun) {
      final bool gcloudOk = await UserPrompt.withSpinner(
        'Logging in to Google Cloud...',
        () async => await firebase.gcloudLogin(),
        doneMessage: '✓ Google Cloud login complete',
        failedMessage: '✗ Google Cloud login failed',
      );
      if (!gcloudOk) {
        _recordFailure(
          'gcloud login',
          hint:
              'Run `gcloud auth login` (or activate a service account) before deploying Cloud Run.',
        );
      }
    }

    // Configure FlutterFire with spinner
    final flutterFireSuccess = await UserPrompt.withSpinner(
      'Configuring FlutterFire...',
      () async => await firebase.configureFlutterFire(),
      doneMessage: '✓ FlutterFire configured',
      failedMessage: '✗ FlutterFire configuration failed',
    );

    if (!flutterFireSuccess) {
      _recordFailure(
        'FlutterFire configuration',
        hint: 'Retry with: oracular deploy firebase-setup',
      );
      UserPrompt.printErrorBox(
        'FlutterFire configuration failed',
        hint: 'You can retry with: oracular deploy firebase-setup',
      );
    }

    // Enable APIs
    if (config.setupCloudRun) {
      final bool apisOk = await UserPrompt.withSpinner(
        'Enabling Google Cloud APIs...',
        () async => await firebase.enableGoogleApis(),
        doneMessage: '✓ APIs enabled',
        failedMessage: '✗ Could not enable all APIs',
      );
      if (!apisOk) {
        _recordFailure(
          'Google Cloud APIs',
          hint:
              'Manually run `gcloud services enable artifactregistry.googleapis.com run.googleapis.com --project ${config.firebaseProjectId}`.',
        );
      }
    }

    print('');
    if (_failures.isEmpty) {
      UserPrompt.printSuccessBox('Firebase setup complete!');
    } else {
      UserPrompt.printErrorBox(
        'Firebase setup completed with issues',
        hint: 'Review the issues at the end of the wizard output.',
      );
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

    if (_failures.isNotEmpty) {
      _printFailureSummary();
    }

    SetupGuidance.printPostCreationChecklist(config);

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
