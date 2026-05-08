import 'package:darted_cli/darted_cli.dart';

import '../version.dart';
import 'handlers/check_handlers.dart';
import 'handlers/config_handlers.dart';
import 'handlers/create_handlers.dart';
import 'handlers/deploy_handlers.dart';
import 'handlers/guide_handlers.dart';
import 'handlers/gitignore_handlers.dart';
import 'handlers/rebuild_handlers.dart';
import 'handlers/script_handlers.dart';
import 'handlers/templates_handlers.dart';

/// All CLI commands for Oracular
final List<DartedCommand> commandsTree = [
  // Create command
  DartedCommand(
    name: 'create',
    helperDescription: 'Create new Arcane projects (Flutter or Dart)',
    arguments: [
      DartedArgument(name: 'app-name', abbreviation: 'n'),
      DartedArgument(name: 'org', abbreviation: 'o', defaultValue: 'com.example'),
      DartedArgument(name: 'template', abbreviation: 't'),
      DartedArgument(name: 'class-name', abbreviation: 'c'),
      DartedArgument(name: 'output-dir', abbreviation: 'd'),
      DartedArgument(name: 'firebase-project-id', abbreviation: 'p'),
      DartedArgument(name: 'service-account-key', abbreviation: 'k'),
    ],
    flags: [
      DartedFlag(name: 'with-models', abbreviation: 'm'),
      DartedFlag(name: 'with-server', abbreviation: 's'),
      DartedFlag(name: 'with-firebase', abbreviation: 'f'),
      DartedFlag(name: 'with-cloud-run', abbreviation: 'r'),
      DartedFlag(name: 'yes', abbreviation: 'y'),
      DartedFlag(name: 'skip-check', abbreviation: 'x'),
      DartedFlag.help,
    ],
    callback: (args, flags) => handleCreate(args ?? {}, _boolToMap(flags)),
    subCommands: [
      DartedCommand(
        name: 'templates',
        helperDescription: 'List available templates',
        callback: (args, flags) => handleListTemplates(args ?? {}, _boolToMap(flags)),
      ),
    ],
  ),

  // Guide command
  DartedCommand(
    name: 'guide',
    helperDescription: 'Generate and print the project setup guide',
    flags: [
      DartedFlag(name: 'print', abbreviation: 'p'),
      DartedFlag.help,
    ],
    callback: (args, flags) => handleGuide(args ?? {}, _boolToMap(flags)),
  ),

  // Open command
  DartedCommand(
    name: 'open',
    helperDescription: 'Open project folders and setup consoles',
    arguments: [
      DartedArgument(
        name: 'target',
        abbreviation: 't',
        isMainReq: true,
        description: 'guide, app, firebase, auth, firestore, storage, hosting',
      ),
    ],
    callback: (args, _) => handleOpenTarget((args?['target'] ?? '').toString()),
  ),

  // Check command
  DartedCommand(
    name: 'check',
    helperDescription: 'Check CLI tool availability',
    callback: (_, _) => handleCheckTools(),
    subCommands: [
      DartedCommand(
        name: 'tools',
        helperDescription: 'Check all tools (required and optional)',
        callback: (_, _) => handleCheckTools(),
      ),
      DartedCommand(
        name: 'flutter',
        helperDescription: 'Check Flutter installation',
        callback: (_, _) => handleCheckFlutter(),
      ),
      DartedCommand(
        name: 'firebase',
        helperDescription: 'Check Firebase CLI tools',
        callback: (_, _) => handleCheckFirebase(),
      ),
      DartedCommand(
        name: 'docker',
        helperDescription: 'Check Docker installation',
        callback: (_, _) => handleCheckDocker(),
      ),
      DartedCommand(
        name: 'gcloud',
        helperDescription: 'Check Google Cloud SDK',
        callback: (_, _) => handleCheckGcloud(),
      ),
      DartedCommand(
        name: 'doctor',
        helperDescription: 'Run flutter doctor',
        callback: (_, _) => handleDoctor(),
      ),
      DartedCommand(
        name: 'server',
        helperDescription: 'Check server deployment tools',
        callback: (_, _) => handleCheckServer(),
      ),
      DartedCommand(
        name: 'billing',
        helperDescription:
            'Check Firebase billing plan (Spark vs Blaze)',
        callback: (_, _) => handleCheckBilling(),
      ),
    ],
  ),

  // Deploy command
  DartedCommand(
    name: 'deploy',
    helperDescription: 'Firebase and server deployment',
    callback: (_, _) => _printDeployHelp(),
    subCommands: [
      DartedCommand(
        name: 'firestore',
        helperDescription: 'Deploy Firestore rules and indexes',
        callback: (_, _) => handleDeployFirestore(),
      ),
      DartedCommand(
        name: 'storage',
        helperDescription: 'Deploy Storage rules',
        callback: (_, _) => handleDeployStorage(),
      ),
      DartedCommand(
        name: 'hosting',
        helperDescription: 'Deploy to Firebase Hosting (release)',
        callback: (_, _) => handleDeployHosting(),
      ),
      DartedCommand(
        name: 'hosting-beta',
        helperDescription: 'Deploy to Firebase Hosting (beta)',
        callback: (_, _) => handleDeployHostingBeta(),
      ),
      DartedCommand(
        name: 'all',
        helperDescription: 'Deploy all Firebase resources',
        callback: (_, _) => handleDeployAll(),
      ),
      DartedCommand(
        name: 'firebase-setup',
        helperDescription:
            'Setup Firebase for a new project (alias of firebase-setup-full)',
        callback: (_, _) => handleFirebaseSetupFull(),
      ),
      DartedCommand(
        name: 'firebase-setup-full',
        helperDescription:
            'End-to-end Firebase setup: billing, init, auth, hosting, deploy',
        callback: (_, _) => handleFirebaseSetupFull(),
      ),
      DartedCommand(
        name: 'hosting-init',
        helperDescription:
            'Create the <project>-beta hosting site and apply targets',
        callback: (_, _) => handleHostingInit(),
      ),
      DartedCommand(
        name: 'firestore-init',
        helperDescription:
            'Ensure the default Firestore database exists',
        callback: (_, _) => handleFirestoreInit(),
      ),
      DartedCommand(
        name: 'storage-init',
        helperDescription: 'Ensure the default Storage bucket exists',
        callback: (_, _) => handleStorageInit(),
      ),
      DartedCommand(
        name: 'auth-providers',
        helperDescription:
            'Enable Email/Password and Google sign-in (best-effort + console hand-off)',
        callback: (_, _) => handleAuthProviders(),
      ),
      DartedCommand(
        name: 'artifact-cleanup',
        helperDescription:
            'Apply Artifact Registry cleanup policy for the server image',
        callback: (_, _) => handleArtifactCleanup(),
      ),
      DartedCommand(
        name: 'cloudrun-prune',
        helperDescription:
            'Prune Cloud Run revisions to the configured retention count',
        callback: (_, _) => handleCloudRunPrune(),
      ),
      DartedCommand(
        name: 'generate-configs',
        helperDescription: 'Generate Firebase configuration files',
        callback: (_, _) => handleGenerateConfigs(),
      ),
      DartedCommand(
        name: 'server-setup',
        helperDescription: 'Setup server for deployment',
        callback: (_, _) => handleServerSetup(),
      ),
      DartedCommand(
        name: 'server-build',
        helperDescription: 'Build server Docker image',
        callback: (_, _) => handleServerBuild(),
      ),
    ],
  ),

  // Config command
  DartedCommand(
    name: 'config',
    helperDescription: 'Configuration management',
    callback: (_, _) => handleConfigList(),
    subCommands: [
      DartedCommand(
        name: 'init',
        helperDescription: 'Initialize configuration file',
        flags: [DartedFlag(name: 'force', abbreviation: 'f')],
        callback: (args, flags) => handleConfigInit(args ?? {}, _boolToMap(flags)),
      ),
      DartedCommand(
        name: 'get',
        helperDescription: 'Get a configuration value',
        arguments: [DartedArgument(name: 'key', abbreviation: 'k')],
        callback: (args, flags) => handleConfigGet(args ?? {}, _boolToMap(flags)),
      ),
      DartedCommand(
        name: 'set',
        helperDescription: 'Set a configuration value',
        arguments: [
          DartedArgument(name: 'key', abbreviation: 'k'),
          DartedArgument(name: 'value', abbreviation: 'v'),
        ],
        callback: (args, flags) => handleConfigSet(args ?? {}, _boolToMap(flags)),
      ),
      DartedCommand(
        name: 'list',
        helperDescription: 'List all configuration values',
        callback: (_, _) => handleConfigList(),
      ),
      DartedCommand(
        name: 'path',
        helperDescription: 'Show configuration file path',
        callback: (_, _) => handleConfigPath(),
      ),
    ],
  ),

  // Scripts command
  DartedCommand(
    name: 'scripts',
    helperDescription: 'Run scripts from pubspec.yaml',
    callback: (_, _) => handleScriptsList(),
    subCommands: [
      DartedCommand(
        name: 'list',
        helperDescription: 'List available scripts',
        callback: (_, _) => handleScriptsList(),
      ),
      DartedCommand(
        name: 'exec',
        helperDescription: 'Execute a script',
        arguments: [DartedArgument(name: 'script', abbreviation: 's')],
        flags: [DartedFlag(name: 'stream', abbreviation: 't')],
        callback: (args, flags) => handleScriptsExec(args ?? {}, _boolToMap(flags)),
      ),
    ],
  ),

  // Templates command
  DartedCommand(
    name: 'templates',
    helperDescription: 'Manage template cache',
    callback: (_, _) => handleTemplatesStatus(),
    subCommands: [
      DartedCommand(
        name: 'status',
        helperDescription: 'Show template cache status',
        callback: (_, _) => handleTemplatesStatus(),
      ),
      DartedCommand(
        name: 'update',
        helperDescription: 'Download/update templates from GitHub',
        callback: (_, _) => handleTemplatesUpdate(),
      ),
      DartedCommand(
        name: 'clear',
        helperDescription: 'Clear the template cache',
        callback: (_, _) => handleTemplatesClear(),
      ),
      DartedCommand(
        name: 'path',
        helperDescription: 'Show template cache path',
        callback: (_, _) => handleTemplatesPath(),
      ),
    ],
  ),

  // Gitignore command
  DartedCommand(
    name: 'gitignore',
    helperDescription: 'Add standard .gitignore to current directory',
    flags: [
      DartedFlag(name: 'force', abbreviation: 'f'),
    ],
    callback: (args, flags) => handleGitignore(args ?? {}, _boolToMap(flags)),
  ),

  // Rebuild / refresh command
  DartedCommand(
    name: 'rebuild',
    helperDescription:
        'Purge managed folders + rescaffold from saved config (Firebase untouched)',
    arguments: [
      DartedArgument(
        name: 'config',
        abbreviation: 'c',
        description: 'Path to setup_config.env (defaults to ./config/setup_config.env)',
      ),
      DartedArgument(
        name: 'output-dir',
        abbreviation: 'd',
        description: 'Project root that contains config/setup_config.env',
      ),
    ],
    flags: [
      DartedFlag(name: 'yes', abbreviation: 'y'),
      DartedFlag(name: 'dry-run', abbreviation: 'n'),
      DartedFlag.help,
    ],
    callback: (args, flags) => handleRebuild(args ?? {}, _boolToMap(flags)),
  ),

  // Refresh — alias of rebuild for muscle memory.
  DartedCommand(
    name: 'refresh',
    helperDescription: 'Alias of `oracular rebuild`',
    arguments: [
      DartedArgument(name: 'config', abbreviation: 'c'),
      DartedArgument(name: 'output-dir', abbreviation: 'd'),
    ],
    flags: [
      DartedFlag(name: 'yes', abbreviation: 'y'),
      DartedFlag(name: 'dry-run', abbreviation: 'n'),
      DartedFlag.help,
    ],
    callback: (args, flags) => handleRebuild(args ?? {}, _boolToMap(flags)),
  ),

  // Version command
  DartedCommand(
    name: 'version',
    helperDescription: 'Show version information',
    callback: (_, _) {
      print('Oracular CLI v$oracularVersion');
      print('Arcane Template System');
    },
  ),
];

/// Convert bool map to dynamic map for handler compatibility
Map<String, dynamic> _boolToMap(Map<String, bool>? flags) {
  if (flags == null) return {};
  return flags.map((k, v) => MapEntry(k, v));
}

/// Print deploy help
void _printDeployHelp() {
  print('');
  print('Deploy subcommands:');
  print('  firestore             Deploy Firestore rules and indexes');
  print('  storage               Deploy Storage rules');
  print('  hosting               Deploy to Firebase Hosting (release)');
  print('  hosting-beta          Deploy to Firebase Hosting (beta)');
  print('  all                   Deploy all Firebase resources');
  print('  firebase-setup        Setup Firebase (alias of firebase-setup-full)');
  print('  firebase-setup-full   End-to-end setup: billing, init, auth, deploy');
  print('  hosting-init          Create <project>-beta site + targets');
  print('  firestore-init        Ensure default Firestore database exists');
  print('  storage-init          Ensure default Storage bucket exists');
  print('  auth-providers        Enable Email/Password + Google sign-in');
  print('  artifact-cleanup      Apply Artifact Registry cleanup policy');
  print('  cloudrun-prune        Prune Cloud Run revisions');
  print('  generate-configs      Generate Firebase configuration files');
  print('  server-setup          Setup server for deployment');
  print('  server-build          Build server Docker image');
  print('');
  print('Run "oracular deploy <subcommand>" for more information.');
}
