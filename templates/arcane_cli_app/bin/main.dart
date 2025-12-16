import 'package:darted_cli/darted_cli.dart';

import 'package:arcane_cli_app/cli/commands.dart';

/// Entry point for arcane_cli_app CLI application
void main(List<String> arguments) async {
  await dartedEntry(
    input: arguments,
    commandsTree: commandsTree,
    customEntryHelper: (_) async => '''
╔═══════════════════════════════════════════════════════════╗
║                    ARCANE_CLI_APP                         ║
║                 Command Line Interface                    ║
╚═══════════════════════════════════════════════════════════╝
''',
    customVersionResponse: () => 'arcane_cli_app CLI v1.0.0',
  );
}
