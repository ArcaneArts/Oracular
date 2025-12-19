import 'package:darted_cli/darted_cli.dart';
import 'package:fast_log/fast_log.dart';

import 'package:oracular/cli/commands.dart';
import 'package:oracular/services/interactive_wizard.dart';

/// Entry point for oracular CLI application
void main(List<String> arguments) async {
  // Check for --verbose flag and enable verbose logging
  final List<String> args = List<String>.from(arguments);
  final bool verbose = args.remove('--verbose') || args.remove('-v');

  if (verbose) {
    // Enable verbose logging in fast_log
    lDebugMode = true;
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
    customEntryHelper: (_) async => '''
╔═══════════════════════════════════════════════════════════╗
║                     ORACULAR CLI                          ║
║               Arcane Template System                      ║
╚═══════════════════════════════════════════════════════════╝
''',
    customVersionResponse: () => 'Oracular CLI v2.0.0',
  );
}
