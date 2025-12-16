import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Get the configuration directory path
String get _configDir {
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home == null) {
    throw Exception('Could not determine home directory');
  }
  return p.join(home, '.arcane_cli_app');
}

/// Get the configuration file path
String get _configPath => p.join(_configDir, 'config.yaml');

/// Initialize configuration file with default values
Future<void> handleConfigInit(Map<String, dynamic> args, Map<String, dynamic> flags) async {
  final force = flags['force'] == true;

  info("Initializing configuration...");

  final configFile = File(_configPath);

  if (configFile.existsSync() && !force) {
    warn("Configuration already exists at: $_configPath");
    info("Use --force to overwrite");
    return;
  }

  // Create config directory if it doesn't exist
  await Directory(_configDir).create(recursive: true);

  // Write default configuration
  final defaultConfig = '''
# arcane_cli_app Configuration File
# Generated: ${DateTime.now().toIso8601String()}

# General Settings
app_name: arcane_cli_app
version: 1.0.0

# Add your custom configuration here
''';

  await configFile.writeAsString(defaultConfig);
  success("Configuration initialized at: $_configPath");
}

/// Get a configuration value by key
Future<void> handleConfigGet(Map<String, dynamic> args, Map<String, dynamic> flags) async {
  final key = args['key'] as String?;
  if (key == null) {
    error('Please provide a configuration key');
    return;
  }

  info("Reading configuration key: $key");

  final configFile = File(_configPath);

  if (!configFile.existsSync()) {
    error("Configuration not found. Run 'arcane_cli_app config init' first.");
    return;
  }

  final content = await configFile.readAsString();
  final yaml = loadYaml(content);

  if (yaml is! Map) {
    error("Invalid configuration format");
    return;
  }

  final value = yaml[key];

  if (value == null) {
    warn("Key '$key' not found in configuration");
    return;
  }

  print('$key: $value');
  success("Retrieved configuration value");
}

/// Set a configuration value
Future<void> handleConfigSet(Map<String, dynamic> args, Map<String, dynamic> flags) async {
  final key = args['key'] as String?;
  final value = args['value'] as String?;

  if (key == null || value == null) {
    error('Please provide both key and value');
    return;
  }

  info("Setting configuration: $key = $value");

  final configFile = File(_configPath);

  if (!configFile.existsSync()) {
    error("Configuration not found. Run 'arcane_cli_app config init' first.");
    return;
  }

  // Read existing config
  final content = await configFile.readAsString();
  final lines = content.split('\n');

  // Find and update the key, or append it
  bool found = false;
  final updatedLines = <String>[];

  for (final line in lines) {
    if (line.trim().startsWith('$key:')) {
      updatedLines.add('$key: $value');
      found = true;
    } else {
      updatedLines.add(line);
    }
  }

  if (!found) {
    updatedLines.add('$key: $value');
  }

  await configFile.writeAsString(updatedLines.join('\n'));
  success("Configuration updated: $key = $value");
}

/// List all configuration values
Future<void> handleConfigList() async {
  info("Listing configuration...");

  final configFile = File(_configPath);

  if (!configFile.existsSync()) {
    error("Configuration not found. Run 'arcane_cli_app config init' first.");
    return;
  }

  final content = await configFile.readAsString();
  final yaml = loadYaml(content);

  if (yaml is! Map) {
    error("Invalid configuration format");
    return;
  }

  print('\nConfiguration ($_configPath):');
  print('─' * 50);

  yaml.forEach((key, value) {
    print('$key: $value');
  });

  print('─' * 50);
  success("Listed ${yaml.length} configuration value(s)");
}

/// Show configuration file path
Future<void> handleConfigPath() async {
  print('Configuration path: $_configPath');
  final exists = File(_configPath).existsSync();
  print('Exists: ${exists ? 'Yes' : 'No'}');

  if (!exists) {
    info("Run 'arcane_cli_app config init' to create configuration");
  }
}
