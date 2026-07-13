import 'package:darted_cli/darted_cli.dart';
import 'package:fast_log/fast_log.dart';

import 'package:oracular/cli/commands.dart';
import 'package:oracular/services/interactive_wizard.dart';
import 'package:oracular/version.dart';

/// Entry point for oracular CLI application
void main(List<String> arguments) async {
  // Check for --verbose flag and enable verbose logging
  final List<String> args = List<String>.from(arguments);
  final bool verbose = args.remove('--verbose') || args.remove('-v');

  if (verbose) {
    // Enable verbose logging in fast_log
    lDebugMode = true;
  }

  if (args.length >= 2 && args.first == 'new' && !args[1].startsWith('-')) {
    final String appName = args.removeAt(1);
    args.insertAll(1, <String>['--appname', appName]);
  }

  if (_isTopLevelHelp(args)) {
    print(_entryHelp());
    return;
  }

  if (_isTopLevelVersion(args)) {
    print('Oracular CLI v$oracularVersion');
    return;
  }

  // If no arguments provided, launch interactive wizard
  if (args.isEmpty) {
    final InteractiveWizard wizard = InteractiveWizard(verbose: verbose);
    await wizard.run();
    return;
  }

  // Otherwise, run the CLI with provided arguments
  await dartedEntry(
    input: args,
    commandsTree: commandsTree,
    customEntryHelper: (_) async => _entryHelp(),
    customVersionResponse: () => 'Oracular CLI v$oracularVersion',
  );
}

bool _isTopLevelHelp(List<String> args) =>
    args.length == 1 && <String>{'--help', '-h', 'help'}.contains(args.single);

bool _isTopLevelVersion(List<String> args) =>
    args.length == 1 &&
    <String>{'--version', '-V', 'version'}.contains(args.single);

String _entryHelp() => '''
╔═══════════════════════════════════════════════════════════╗
║                     ORACULAR CLI                          ║
║               Arcane Template System                      ║
╚═══════════════════════════════════════════════════════════╝

Start:
  oracular new my_app             Create with recommended defaults
  oracular create                 Full interactive creator
  oracular check tools            Verify local Flutter/Dart tooling

Project commands:
  oracular next                   Show useful next actions
  oracular verify                 Run dependency and analyzer checks
  oracular scripts list           List pubspec.yaml scripts

Config:
  oracular config set org art.arcane
  oracular config set output_dir ~/Developer
  oracular config set default_template arcane_app
''';
