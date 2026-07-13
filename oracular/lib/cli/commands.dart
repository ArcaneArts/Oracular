import 'package:darted_cli/darted_cli.dart';

import '../version.dart';
import 'handlers/build_handlers.dart';
import 'handlers/check_handlers.dart';
import 'handlers/config_handlers.dart';
import 'handlers/companion_handlers.dart';
import 'handlers/create_handlers.dart';
import 'handlers/deploy_handlers.dart';
import 'handlers/guide_handlers.dart';
import 'handlers/gitignore_handlers.dart';
import 'handlers/rebuild_handlers.dart';
import 'handlers/script_handlers.dart';
import 'handlers/templates_handlers.dart';
import 'handlers/update_handlers.dart';

/// All CLI commands for Oracular
final List<DartedCommand> commandsTree = [
  // Friendly happy-path command
  DartedCommand(
    name: 'new',
    helperDescription: 'Create a project with recommended defaults',
    arguments: [
      DartedArgument(
        name: 'appname',
        abbreviation: 'n',
        description: 'Project name in snake_case, e.g. my_app',
      ),
      DartedArgument(
        name: 'name',
        abbreviation: '',
        description: 'Alias for --app-name / --appname',
      ),
      DartedArgument(name: 'org', abbreviation: 'o'),
      DartedArgument(name: 'template', abbreviation: 't'),
      DartedArgument(name: 'outputdir', abbreviation: 'd'),
      DartedArgument(name: 'firebaseprojectid', abbreviation: 'p'),
      DartedArgument(name: 'serviceaccountkey', abbreviation: 'k'),
      DartedArgument(
        name: 'rendermode',
        abbreviation: 'R',
        description: 'Jaspr render mode: csr | ssg | ssr | hybrid | embed',
      ),
    ],
    flags: [
      DartedFlag(name: 'withmodels', abbreviation: 'm'),
      DartedFlag(name: 'withserver', abbreviation: 's'),
      DartedFlag(name: 'withfirebase', abbreviation: 'f'),
      DartedFlag(name: 'withcloudrun', abbreviation: 'r'),
      DartedFlag(name: 'skipcheck', abbreviation: 'x'),
      DartedFlag.help,
    ],
    callback: (args, flags) => handleNew(_argsMap(args), _boolToMap(flags)),
  ),

  // Create command
  DartedCommand(
    name: 'create',
    helperDescription: 'Create new Arcane projects (Flutter or Dart)',
    arguments: [
      DartedArgument(name: 'appname', abbreviation: 'n'),
      DartedArgument(
        name: 'name',
        abbreviation: '',
        description: 'Alias for --app-name / --appname',
      ),
      DartedArgument(name: 'org', abbreviation: 'o'),
      DartedArgument(name: 'template', abbreviation: 't'),
      DartedArgument(name: 'classname', abbreviation: 'c'),
      DartedArgument(name: 'outputdir', abbreviation: 'd'),
      DartedArgument(name: 'firebaseprojectid', abbreviation: 'p'),
      DartedArgument(name: 'serviceaccountkey', abbreviation: 'k'),
      DartedArgument(
        name: 'rendermode',
        abbreviation: 'R',
        description:
            'Jaspr render mode: csr | ssg | ssr | hybrid | embed '
            '(only meaningful for Jaspr templates; defaults derived from template).',
      ),
    ],
    flags: [
      DartedFlag(name: 'withmodels', abbreviation: 'm'),
      DartedFlag(name: 'withserver', abbreviation: 's'),
      DartedFlag(name: 'withfirebase', abbreviation: 'f'),
      DartedFlag(name: 'withcloudrun', abbreviation: 'r'),
      DartedFlag(name: 'yes', abbreviation: 'y'),
      DartedFlag(name: 'skipcheck', abbreviation: 'x'),
      DartedFlag.help,
    ],
    callback: (args, flags) => handleCreate(_argsMap(args), _boolToMap(flags)),
    subCommands: [
      DartedCommand(
        name: 'app',
        helperDescription: 'Create a Flutter app using recommended defaults',
        arguments: [
          DartedArgument(name: 'appname', abbreviation: 'n'),
          DartedArgument(
            name: 'name',
            abbreviation: '',
            description: 'Alias for --app-name / --appname',
          ),
          DartedArgument(name: 'org', abbreviation: 'o'),
          DartedArgument(name: 'template', abbreviation: 't'),
          DartedArgument(name: 'classname', abbreviation: 'c'),
          DartedArgument(name: 'outputdir', abbreviation: 'd'),
          DartedArgument(name: 'firebaseprojectid', abbreviation: 'p'),
          DartedArgument(name: 'serviceaccountkey', abbreviation: 'k'),
          DartedArgument(name: 'rendermode', abbreviation: 'R'),
        ],
        flags: [
          DartedFlag(name: 'withmodels', abbreviation: 'm'),
          DartedFlag(name: 'withserver', abbreviation: 's'),
          DartedFlag(name: 'withfirebase', abbreviation: 'f'),
          DartedFlag(name: 'withcloudrun', abbreviation: 'r'),
          DartedFlag(name: 'yes', abbreviation: 'y'),
          DartedFlag(name: 'skipcheck', abbreviation: 'x'),
          DartedFlag.help,
        ],
        callback: (args, flags) =>
            handleCreateAppAlias(_argsMap(args), _boolToMap(flags)),
      ),
      DartedCommand(
        name: 'templates',
        helperDescription: 'List available templates',
        callback: (args, flags) =>
            handleListTemplates(_argsMap(args), _boolToMap(flags)),
      ),
    ],
  ),

  // Companion commands
  DartedCommand(
    name: 'next',
    helperDescription: 'Show the next useful actions for this project',
    callback: (_, _) => handleNext(),
  ),
  DartedCommand(
    name: 'verify',
    helperDescription:
        'Verify generated project folders, dependencies, and analysis',
    flags: [
      DartedFlag(name: 'build', abbreviation: 'b'),
      DartedFlag.help,
    ],
    callback: (args, flags) => handleVerify(_argsMap(args), _boolToMap(flags)),
  ),

  // Guide command
  DartedCommand(
    name: 'guide',
    helperDescription: 'Generate and print the project setup guide',
    flags: [
      DartedFlag(name: 'print', abbreviation: 'p'),
      DartedFlag.help,
    ],
    callback: (args, flags) => handleGuide(_argsMap(args), _boolToMap(flags)),
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
    callback: (args, _) =>
        handleOpenTarget((_argsMap(args)['target'] ?? '').toString()),
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
        helperDescription: 'Check Firebase billing plan (Spark vs Blaze)',
        callback: (_, _) => handleCheckBilling(),
      ),
    ],
  ),

  // Build command — produce every artifact this project ships, in a
  // mode-aware way. Distinct from `deploy`: `build` never pushes images
  // or runs `firebase deploy`. Always safe to run.
  DartedCommand(
    name: 'build',
    helperDescription:
        'Build artifacts (Flutter platforms, Jaspr, embed, images)',
    callback: (_, _) => _printBuildHelp(),
    subCommands: [
      // NOTE: every leaf name below MUST be globally unique across the
      // entire command tree. darted_cli flattens subcommands by leaf
      // name when matching the call stack, so `build flutter` would
      // otherwise resolve to `check flutter`. See commands.dart:130.
      DartedCommand(
        name: 'everything',
        helperDescription: 'Build every artifact applicable to this project',
        callback: (_, _) => handleBuildAll(),
      ),
      DartedCommand(
        name: 'flutter-app',
        helperDescription:
            'Build Flutter platforms (defaults to every platform in setup_config.env)',
        arguments: [
          DartedArgument(
            name: 'platform',
            abbreviation: 'p',
            description:
                'Single platform to build (web, ios, android, macos, linux, windows). '
                'Omit to build every platform listed in setup_config.env.',
          ),
        ],
        flags: [DartedFlag.help],
        callback: (args, _) => handleBuildFlutter(_argsMap(args)),
      ),
      DartedCommand(
        name: 'jaspr-site',
        helperDescription:
            'Build the Jaspr site (render-mode aware: CSR / SSG / SSR / Hybrid / Embed)',
        callback: (_, _) => handleBuildJaspr(),
      ),
      DartedCommand(
        name: 'jaspr-image',
        helperDescription:
            'Build the Cloud Run image for the Jaspr server (SSR / hybrid only)',
        callback: (_, _) => handleBuildJasprServer(),
      ),
      DartedCommand(
        name: 'flutter-embed',
        helperDescription:
            'Build the Flutter web guest + Jaspr host bundle (embed template only)',
        callback: (_, _) => handleBuildFlutterEmbed(),
      ),
      DartedCommand(
        name: 'cli-binary',
        helperDescription:
            'Compile the Dart CLI to a native binary (arcane_cli_app only)',
        callback: (_, _) => handleBuildCli(),
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
        name: 'jaspr-server',
        helperDescription:
            'Build + push + deploy the Jaspr server to Cloud Run (SSR / hybrid)',
        callback: (_, _) => handleDeployJasprServer(),
      ),
      DartedCommand(
        name: 'arcane-server',
        helperDescription:
            'Build + push + deploy the arcane_server companion to Cloud Run',
        callback: (_, _) => handleDeployServer(),
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
        helperDescription: 'Ensure the default Firestore database exists',
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
        arguments: [
          DartedArgument(name: 'hybriddynamicprefix', abbreviation: 'H'),
        ],
        callback: (args, _) => handleGenerateConfigs(_argsMap(args)),
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
        callback: (args, flags) =>
            handleConfigInit(_argsMap(args), _boolToMap(flags)),
      ),
      DartedCommand(
        name: 'get',
        helperDescription: 'Get a configuration value',
        arguments: [DartedArgument(name: 'key', abbreviation: 'k')],
        callback: (args, flags) =>
            handleConfigGet(_argsMap(args), _boolToMap(flags)),
      ),
      DartedCommand(
        name: 'set',
        helperDescription: 'Set a configuration value',
        arguments: [
          DartedArgument(name: 'key', abbreviation: 'k'),
          DartedArgument(name: 'value', abbreviation: 'v'),
        ],
        callback: (args, flags) =>
            handleConfigSet(_argsMap(args), _boolToMap(flags)),
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
        callback: (args, flags) =>
            handleScriptsExec(_argsMap(args), _boolToMap(flags)),
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
    flags: [DartedFlag(name: 'force', abbreviation: 'f')],
    callback: (args, flags) =>
        handleGitignore(_argsMap(args), _boolToMap(flags)),
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
        description:
            'Path to setup_config.env (defaults to ./config/setup_config.env)',
      ),
      DartedArgument(
        name: 'outputdir',
        abbreviation: 'd',
        description: 'Project root that contains config/setup_config.env',
      ),
    ],
    flags: [
      DartedFlag(name: 'yes', abbreviation: 'y'),
      DartedFlag(name: 'dryrun', abbreviation: 'n'),
      DartedFlag.help,
    ],
    callback: (args, flags) => handleRebuild(_argsMap(args), _boolToMap(flags)),
  ),

  // Refresh — alias of rebuild for muscle memory.
  DartedCommand(
    name: 'refresh',
    helperDescription: 'Alias of `oracular rebuild`',
    arguments: [
      DartedArgument(name: 'config', abbreviation: 'c'),
      DartedArgument(name: 'outputdir', abbreviation: 'd'),
    ],
    flags: [
      DartedFlag(name: 'yes', abbreviation: 'y'),
      DartedFlag(name: 'dryrun', abbreviation: 'n'),
      DartedFlag.help,
    ],
    callback: (args, flags) => handleRebuild(_argsMap(args), _boolToMap(flags)),
  ),

  // Update command — surgical updates to existing projects (IDE wiring,
  // run configurations, etc.) without re-running the full wizard.
  DartedCommand(
    name: 'update',
    helperDescription: 'Update IDE wiring and project assets in-place',
    callback: (_, _) => _printUpdateHelp(),
    subCommands: [
      DartedCommand(
        name: 'runs',
        helperDescription:
            'Add/refresh IntelliJ run configs (Deploy All + Jaspr Serve/Build/Killall)',
        arguments: [
          DartedArgument(
            name: 'port',
            abbreviation: 'p',
            description: 'Port for jaspr serve / killall (default: 8080)',
            defaultValue: '8080',
          ),
          DartedArgument(
            name: 'dir',
            abbreviation: 'd',
            description:
                'Project root containing config/setup_config.env (default: cwd)',
          ),
        ],
        flags: [DartedFlag.help],
        callback: (args, _) => handleUpdateRuns(_argsMap(args)),
      ),
    ],
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

/// Lazily-built lookup tables that mirror every CLI flag/argument key
/// between its long-form name and short-form abbreviation. darted_cli stores
/// each flag/arg under whichever spelling the user typed (e.g. `-y` lands
/// under the `'y'` key, `--yes` lands under `'yes'`), so handlers that only
/// check one spelling silently miss the other. We populate these registries
/// once from [commandsTree] and use them to mirror keys in [_boolToMap] and
/// [_argsMap] so callers can use either spelling reliably.
///
/// Abbreviations can collide across commands (e.g. `-t` is used for both
/// `create --template` and `open --target`). To handle that we store
/// every long-form name that an abbreviation expands to, and mirror
/// to ALL of them in the output map. Handlers only read keys that
/// belong to their own command, so the extra entries are harmless.
final Map<String, Set<String>> _flagAbbrevToNames = <String, Set<String>>{};
final Map<String, Set<String>> _flagNameToAbbrevs = <String, Set<String>>{};
final Map<String, Set<String>> _argAbbrevToNames = <String, Set<String>>{};
final Map<String, Set<String>> _argNameToAbbrevs = <String, Set<String>>{};
bool _aliasesBuilt = false;

void _ensureAliasMaps() {
  if (_aliasesBuilt) return;
  void addFlag(String abbr, String name) {
    _flagAbbrevToNames.putIfAbsent(abbr, () => <String>{}).add(name);
    _flagNameToAbbrevs.putIfAbsent(name, () => <String>{}).add(abbr);
  }

  void addArg(String abbr, String name) {
    _argAbbrevToNames.putIfAbsent(abbr, () => <String>{}).add(name);
    _argNameToAbbrevs.putIfAbsent(name, () => <String>{}).add(abbr);
  }

  void walk(List<DartedCommand> cmds) {
    for (final cmd in cmds) {
      for (final f in cmd.flags ?? const <DartedFlag>[]) {
        final abbr = f.abbreviation;
        if (abbr.isNotEmpty && abbr != f.name) {
          addFlag(abbr, f.name);
        }
      }
      for (final a in cmd.arguments ?? const <DartedArgument?>[]) {
        if (a == null) continue;
        final abbr = a.abbreviation;
        if (abbr.isNotEmpty && abbr != a.name) {
          addArg(abbr, a.name);
        }
      }
      final subs = cmd.subCommands;
      if (subs != null && subs.isNotEmpty) walk(subs);
    }
  }

  walk(commandsTree);
  _aliasesBuilt = true;
}

/// Normalise the flags map so handlers can read a flag by either its long
/// name (`yes`) or short abbreviation (`y`) and get the same value.
Map<String, dynamic> _boolToMap(Map<String, bool>? flags) {
  if (flags == null || flags.isEmpty) return <String, dynamic>{};
  _ensureAliasMaps();
  final out = <String, dynamic>{};
  flags.forEach((k, v) {
    out[k] = v;
    final mirrors =
        _flagAbbrevToNames[k] ?? _flagNameToAbbrevs[k] ?? const <String>{};
    for (final mirror in mirrors) {
      out[mirror] = v;
    }
  });
  return out;
}

/// Same idea as [_boolToMap] but for positional/named string arguments.
Map<String, dynamic> _argsMap(Map<String, dynamic>? args) {
  if (args == null || args.isEmpty) return <String, dynamic>{};
  _ensureAliasMaps();
  final out = <String, dynamic>{};
  args.forEach((k, v) {
    out[k] = v;
    final mirrors =
        _argAbbrevToNames[k] ?? _argNameToAbbrevs[k] ?? const <String>{};
    for (final mirror in mirrors) {
      out[mirror] = v;
    }
  });
  return out;
}

/// Print build help
///
/// Subcommand names are deliberately disambiguated (e.g. `flutter-app`
/// instead of `flutter`) because darted_cli matches commands by leaf
/// name from a flattened tree — `build flutter` would otherwise
/// resolve to `check flutter`. Keep these names globally unique when
/// adding new build steps.
void _printBuildHelp() {
  print('');
  print('Build subcommands:');
  print(
    '  everything                  Build every artifact applicable to this project',
  );
  print('  flutter-app [--platform p]  Build one or all Flutter platforms');
  print(
    '  jaspr-site                  Build the Jaspr site (render-mode aware)',
  );
  print(
    '  jaspr-image                 Build the Cloud Run image (SSR / hybrid)',
  );
  print('  flutter-embed               Build the Flutter+Jaspr embed bundle');
  print('  cli-binary                  Compile the Dart CLI binary');
  print('');
  print('Run "oracular build <subcommand>" for more information.');
}

/// Print deploy help
void _printDeployHelp() {
  print('');
  print('Deploy subcommands:');
  print('  firestore             Deploy Firestore rules and indexes');
  print('  storage               Deploy Storage rules');
  print('  hosting               Deploy to Firebase Hosting (release)');
  print('  hosting-beta          Deploy to Firebase Hosting (beta)');
  print('  jaspr-server          Build/push/deploy Jaspr server (SSR/hybrid)');
  print('  arcane-server        Build/push/deploy arcane_server companion');
  print('  all                   Deploy all Firebase resources');
  print(
    '  firebase-setup        Setup Firebase (alias of firebase-setup-full)',
  );
  print(
    '  firebase-setup-full   End-to-end setup: billing, init, auth, deploy',
  );
  print('  hosting-init          Create <project>-beta site + targets');
  print('  firestore-init        Ensure default Firestore database exists');
  print('  storage-init          Ensure default Storage bucket exists');
  print('  auth-providers        Enable Email/Password + Google sign-in');
  print('  artifact-cleanup      Apply Artifact Registry cleanup policy');
  print('  cloudrun-prune        Prune Cloud Run revisions');
  print('  generate-configs      Generate Firebase configuration files');
  print('                        --hybrid-dynamic-prefix <p1,p2,...>');
  print('                        rewrites SSR prefixes for hybrid render mode');
  print('  server-setup          Setup server for deployment');
  print('  server-build          Build server Docker image');
  print('');
  print('Run "oracular deploy <subcommand>" for more information.');
}

/// Print update help
void _printUpdateHelp() {
  print('');
  print('Update subcommands:');
  print('  runs                  Add/refresh IntelliJ run configs');
  print('                        - Deploy All (project root)');
  print(
    '                        - Serve / Build / Killall (per Jaspr package)',
  );
  print('');
  print('Examples:');
  print('  oracular update runs                  # default port 8080');
  print('  oracular update runs --port 3000      # custom Jaspr port');
  print(
    '  oracular update runs --dir /path/proj # operate on a different project',
  );
  print('  oracular update runs -d ./my_jaspr_app -p 9000');
}
