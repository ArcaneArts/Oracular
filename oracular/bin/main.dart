import 'package:darted_cli/darted_cli.dart';

import 'package:oracular/cli/commands.dart';
import 'package:oracular/services/interactive_wizard.dart';

/// Entry point for oracular CLI application
void main(List<String> arguments) async {
  // If no arguments provided, launch interactive wizard
  if (arguments.isEmpty) {
    final InteractiveWizard wizard = InteractiveWizard();
    await wizard.run();
    return;
  }

  // Otherwise, run the CLI with provided arguments
  await dartedEntry(
    input: arguments,
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
