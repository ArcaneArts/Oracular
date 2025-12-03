library APPNAME;

import 'package:cli_annotations/cli_annotations.dart';
import 'package:fast_log/fast_log.dart';

// CONDITIONAL_IMPORTS_START - These imports are added during setup based on user choices
// MODELS_IMPORT: import 'package:APPNAME_models/APPNAME_models.dart';
// FIREBASE_IMPORT: import 'package:arcane_fluf/arcane_fluf.dart';
// FIREBASE_IMPORT: import 'package:fire_crud/fire_crud.dart';
// CONDITIONAL_IMPORTS_END

import 'commands/hello_command.dart';
import 'commands/config_command.dart';
// SERVER_COMMAND_IMPORT: import 'commands/server_command.dart';

part 'APPNAME.g.dart';

/// CLI application for APPNAME
///
/// This is the main command runner that orchestrates all CLI commands.
/// Commands are automatically discovered and registered through cli_gen code generation.
@cliRunner
class APPNAMERunner extends _$APPNAMERunner {
  APPNAMERunner() {
    // Initialize logging
    verbose("APPNAMERunner initialized");
  }

  /// Hello world command - demonstrates basic CLI structure
  @cliMount
  HelloCommand get hello => HelloCommand();

  /// Configuration management commands
  @cliMount
  ConfigCommand get config => ConfigCommand();

  // SERVER_MOUNT: @cliMount
  // SERVER_MOUNT: ServerCommand get server => ServerCommand();
}
