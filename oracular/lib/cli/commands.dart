import 'package:darted_cli/darted_cli.dart';

import 'handlers/check_handlers.dart';
import 'handlers/config_handlers.dart';
import 'handlers/create_handlers.dart';
import 'handlers/deploy_handlers.dart';
import 'handlers/gui_handlers.dart';
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

  // Check command
  DartedCommand(
    name: 'check',
    helperDescription: 'Check CLI tool availability',
    callback: (_, __) => handleCheckTools(),
    subCommands: [
      DartedCommand(
        name: 'tools',
        helperDescription: 'Check all tools (required and optional)',
        callback: (_, __) => handleCheckTools(),
      ),
      DartedCommand(
        name: 'flutter',
        helperDescription: 'Check Flutter installation',
        callback: (_, __) => handleCheckFlutter(),
      ),
      DartedCommand(
        name: 'firebase',
        helperDescription: 'Check Firebase CLI tools',
        callback: (_, __) => handleCheckFirebase(),
      ),
      DartedCommand(
        name: 'docker',
        helperDescription: 'Check Docker installation',
        callback: (_, __) => handleCheckDocker(),
      ),
      DartedCommand(
        name: 'gcloud',
        helperDescription: 'Check Google Cloud SDK',
        callback: (_, __) => handleCheckGcloud(),
      ),
      DartedCommand(
        name: 'doctor',
        helperDescription: 'Run flutter doctor',
        callback: (_, __) => handleDoctor(),
      ),
      DartedCommand(
        name: 'server',
        helperDescription: 'Check server deployment tools',
        callback: (_, __) => handleCheckServer(),
      ),
    ],
  ),

  // Deploy command
  DartedCommand(
    name: 'deploy',
    helperDescription: 'Firebase and server deployment',
    callback: (_, __) => _printDeployHelp(),
    subCommands: [
      DartedCommand(
        name: 'firestore',
        helperDescription: 'Deploy Firestore rules and indexes',
        callback: (_, __) => handleDeployFirestore(),
      ),
      DartedCommand(
        name: 'storage',
        helperDescription: 'Deploy Storage rules',
        callback: (_, __) => handleDeployStorage(),
      ),
      DartedCommand(
        name: 'hosting',
        helperDescription: 'Deploy to Firebase Hosting (release)',
        callback: (_, __) => handleDeployHosting(),
      ),
      DartedCommand(
        name: 'hosting-beta',
        helperDescription: 'Deploy to Firebase Hosting (beta)',
        callback: (_, __) => handleDeployHostingBeta(),
      ),
      DartedCommand(
        name: 'all',
        helperDescription: 'Deploy all Firebase resources',
        callback: (_, __) => handleDeployAll(),
      ),
      DartedCommand(
        name: 'firebase-setup',
        helperDescription: 'Setup Firebase for a new project',
        callback: (_, __) => handleFirebaseSetup(),
      ),
      DartedCommand(
        name: 'generate-configs',
        helperDescription: 'Generate Firebase configuration files',
        callback: (_, __) => handleGenerateConfigs(),
      ),
      DartedCommand(
        name: 'server-setup',
        helperDescription: 'Setup server for deployment',
        callback: (_, __) => handleServerSetup(),
      ),
      DartedCommand(
        name: 'server-build',
        helperDescription: 'Build server Docker image',
        callback: (_, __) => handleServerBuild(),
      ),
    ],
  ),

  // Config command
  DartedCommand(
    name: 'config',
    helperDescription: 'Configuration management',
    callback: (_, __) => handleConfigList(),
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
        callback: (_, __) => handleConfigList(),
      ),
      DartedCommand(
        name: 'path',
        helperDescription: 'Show configuration file path',
        callback: (_, __) => handleConfigPath(),
      ),
    ],
  ),

  // GUI command
  DartedCommand(
    name: 'gui',
    helperDescription: 'Launch the Oracular GUI wizard',
    arguments: [DartedArgument(name: 'platform', abbreviation: 'p')],
    flags: [DartedFlag(name: 'release', abbreviation: 'r')],
    callback: (args, flags) => handleGuiLaunch(args ?? {}, _boolToMap(flags)),
    subCommands: [
      DartedCommand(
        name: 'build',
        helperDescription: 'Build the GUI for distribution',
        arguments: [
          DartedArgument(name: 'platform', abbreviation: 'p', defaultValue: 'macos'),
        ],
        callback: (args, flags) => handleGuiBuild(args ?? {}, _boolToMap(flags)),
      ),
    ],
  ),

  // Scripts command
  DartedCommand(
    name: 'scripts',
    helperDescription: 'Run scripts from pubspec.yaml',
    callback: (_, __) => handleScriptsList(),
    subCommands: [
      DartedCommand(
        name: 'list',
        helperDescription: 'List available scripts',
        callback: (_, __) => handleScriptsList(),
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
    callback: (_, __) => handleTemplatesStatus(),
    subCommands: [
      DartedCommand(
        name: 'status',
        helperDescription: 'Show template cache status',
        callback: (_, __) => handleTemplatesStatus(),
      ),
      DartedCommand(
        name: 'update',
        helperDescription: 'Download/update templates from GitHub',
        callback: (_, __) => handleTemplatesUpdate(),
      ),
      DartedCommand(
        name: 'clear',
        helperDescription: 'Clear the template cache',
        callback: (_, __) => handleTemplatesClear(),
      ),
      DartedCommand(
        name: 'path',
        helperDescription: 'Show template cache path',
        callback: (_, __) => handleTemplatesPath(),
      ),
    ],
  ),

  // Version command
  DartedCommand(
    name: 'version',
    helperDescription: 'Show version information',
    callback: (_, __) {
      print('Oracular CLI v2.1.0');  // Keep in sync with pubspec.yaml
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
  print('  firestore       Deploy Firestore rules and indexes');
  print('  storage         Deploy Storage rules');
  print('  hosting         Deploy to Firebase Hosting (release)');
  print('  hosting-beta    Deploy to Firebase Hosting (beta)');
  print('  all             Deploy all Firebase resources');
  print('  firebase-setup  Setup Firebase for a new project');
  print('  generate-configs Generate Firebase configuration files');
  print('  server-setup    Setup server for deployment');
  print('  server-build    Build server Docker image');
  print('');
  print('Run "oracular deploy <subcommand>" for more information.');
}
