import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../models/setup_config.dart';
import '../models/template_info.dart';
import '../utils/string_utils.dart';
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

  // Wizard step tracking
  static const int _totalSteps = 5;
  int _currentStep = 0;

  /// Run the full interactive wizard
  Future<void> run() async {
    _printWelcome();

    // Step 1: Check tools
    _currentStep = 0;
    UserPrompt.printStepIndicator(_currentStep, _totalSteps, 'Environment Check');
    if (!await _checkTools()) {
      return;
    }

    // Step 2: Gather configuration
    _currentStep = 1;
    UserPrompt.printStepIndicator(_currentStep, _totalSteps, 'Project Configuration');
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
    UserPrompt.printStepIndicator(_currentStep, _totalSteps, 'Creating Project');
    await _executeSetup(config);

    // Step 5: Optional Firebase setup
    _currentStep = 4;
    if (config.useFirebase) {
      UserPrompt.printStepIndicator(_currentStep, _totalSteps, 'Firebase Setup');
      await _offerFirebaseSetup(config);
    }

    _printSuccess(config);
  }

  void _printWelcome() {
    UserPrompt.clearScreen();
    UserPrompt.printBanner(
      'Welcome to Oracular Setup Wizard',
      subtitle: 'Arcane Template System v2.0',
    );
    info('This wizard will help you create a new Arcane project.');
    print('');
    UserPrompt.printList([
      'Use ↑↓ arrow keys to navigate menus',
      'Press Space to toggle selections',
      'Press Enter to confirm',
    ]);
    print('');
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

    // Output directory
    final outputDir = await UserPrompt.askString(
      'Output directory',
      defaultValue: Directory.current.path,
    );

    // ── Section 3: Platform Selection ──
    List<String> selectedPlatforms = template.supportedPlatforms;
    if (template.isFlutterApp && template != TemplateType.arcaneDock) {
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
    }

    // ── Section 4: Additional Packages ──
    UserPrompt.printDivider(title: 'Additional Packages');

    // Multi-select for additional features
    final additionalFeatures = await UserPrompt.askMultiSelectNames(
      'Select additional packages to create',
      ['Shared Models Package', 'Server Application'],
      defaultSelected: ['Shared Models Package'],
    );

    final createModels = additionalFeatures.contains('Shared Models Package');
    final createServer = additionalFeatures.contains('Server Application');

    // ── Section 5: Firebase Integration ──
    UserPrompt.printDivider(title: 'Cloud Services');

    // Firebase
    final useFirebase = await UserPrompt.askYesNo(
      'Enable Firebase integration?',
      defaultValue: false,
    );

    String? firebaseProjectId;
    bool setupCloudRun = false;

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
    await UserPrompt.withSpinner(
      'Creating project structure...',
      () async {
        final creator = ProjectCreator(config);
        if (!await creator.createAllProjects()) {
          throw Exception('Failed to create projects');
        }
        // Clean up test folders while we're at it
        await creator.deleteTestFolders();
      },
      doneMessage: '✓ Project structure created',
    );

    // Copy templates with spinner
    await UserPrompt.withSpinner(
      'Copying template files...',
      () async {
        final copier = TemplateCopier(config);
        await copier.copyAll();
      },
      doneMessage: '✓ Template files copied',
    );

    // Link models if needed
    final depManager = DependencyManager(config);
    if (config.createModels) {
      await UserPrompt.withSpinner(
        'Linking models package...',
        () async {
          await depManager.linkModelsToProjects();
        },
        doneMessage: '✓ Models package linked',
      );
    }

    // Get dependencies with spinner (this can take a while)
    await UserPrompt.withSpinner(
      'Installing dependencies (this may take a moment)...',
      () async {
        await depManager.getAllDependencies();
      },
      doneMessage: '✓ Dependencies installed',
    );

    // Run build_runner with spinner
    await UserPrompt.withSpinner(
      'Running code generation...',
      () async {
        await depManager.runAllBuildRunners();
      },
      doneMessage: '✓ Code generation complete',
    );

    // Generate Firebase configs if enabled
    if (config.useFirebase) {
      await UserPrompt.withSpinner(
        'Generating Firebase configuration...',
        () async {
          final configGen = ConfigGenerator(config);
          await configGen.generateAll();
        },
        doneMessage: '✓ Firebase config generated',
      );
    }

    // Generate server files if enabled
    if (config.createServer) {
      await UserPrompt.withSpinner(
        'Setting up server deployment...',
        () async {
          final serverSetup = ServerSetup(config);
          await serverSetup.generateAll();
        },
        doneMessage: '✓ Server setup complete',
      );
    }

    // Save configuration
    await UserPrompt.withSpinner(
      'Saving configuration...',
      () async {
        final configDir = Directory(p.join(config.outputDir, 'config'));
        if (!configDir.existsSync()) {
          await configDir.create(recursive: true);
        }
        await config.saveToFile(p.join(configDir.path, 'setup_config.env'));
      },
      doneMessage: '✓ Configuration saved',
    );

    print('');
    UserPrompt.printSuccessBox('Project created successfully!');
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

    final firebase = FirebaseService(config);

    // Login to Firebase with spinner
    await UserPrompt.withSpinner(
      'Logging in to Firebase...',
      () async {
        await firebase.login();
      },
      doneMessage: '✓ Firebase login complete',
    );

    // Login to gcloud if Cloud Run enabled
    if (config.setupCloudRun) {
      await UserPrompt.withSpinner(
        'Logging in to Google Cloud...',
        () async {
          await firebase.gcloudLogin();
        },
        doneMessage: '✓ Google Cloud login complete',
      );
    }

    // Configure FlutterFire with spinner
    final flutterFireSuccess = await UserPrompt.withSpinner(
      'Configuring FlutterFire...',
      () async {
        return await firebase.configureFlutterFire();
      },
      doneMessage: '✓ FlutterFire configured',
    );

    if (!flutterFireSuccess) {
      UserPrompt.printErrorBox(
        'FlutterFire configuration failed',
        hint: 'You can retry with: oracular deploy firebase-setup',
      );
    }

    // Enable APIs
    if (config.setupCloudRun) {
      await UserPrompt.withSpinner(
        'Enabling Google Cloud APIs...',
        () async {
          await firebase.enableGoogleApis();
        },
        doneMessage: '✓ APIs enabled',
      );
    }

    print('');
    UserPrompt.printSuccessBox('Firebase setup complete!');
  }

  void _printSuccess(SetupConfig config) {
    UserPrompt.printBanner('Project Created Successfully!');

    // List created packages
    final createdItems = <String>[
      '${config.appName}/ - Main application',
    ];
    if (config.createModels) {
      createdItems.add('${config.modelsPackageName}/ - Shared models package');
    }
    if (config.createServer) {
      createdItems.add('${config.serverPackageName}/ - Server application');
    }
    createdItems.add('config/ - Configuration files');
    createdItems.add('references/ - Library documentation');

    print('Created:');
    UserPrompt.printList(createdItems);

    // Next steps
    UserPrompt.printDivider(title: 'Next Steps');

    final nextSteps = <String>[
      'cd ${config.outputDir}/${config.appName}',
    ];

    if (config.template.isFlutterApp) {
      nextSteps.add('flutter run');
    } else {
      nextSteps.add('dart run bin/main.dart --help');
    }

    UserPrompt.printNumberedList(nextSteps);

    // Firebase deployment commands
    if (config.useFirebase) {
      UserPrompt.printDivider(title: 'Firebase Deployment');
      UserPrompt.printList(['oracular deploy all']);
    }

    // Server deployment commands
    if (config.createServer) {
      UserPrompt.printDivider(title: 'Server Deployment');
      UserPrompt.printList([
        'cd ${config.serverPackageName}',
        './script_deploy.sh',
      ]);
    }

    print('');
    UserPrompt.printSuccessBox('Happy coding!');
  }
}
