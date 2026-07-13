import 'dart:io';

import 'package:fast_log/fast_log.dart';

import '../../utils/global_config.dart';

/// Initialize configuration file
Future<void> handleConfigInit(
  Map<String, dynamic> args,
  Map<String, dynamic> flags,
) async {
  final force = flags['force'] == true;

  info('Initializing configuration...');

  final configFile = File(OracularGlobalConfig.configPath);

  if (configFile.existsSync() && !force) {
    warn('Configuration already exists at: ${OracularGlobalConfig.configPath}');
    info('Use --force to overwrite');
    return;
  }

  await OracularGlobalConfig.ensureExists(force: force);
  success('Configuration initialized at: ${OracularGlobalConfig.configPath}');
}

/// Get a configuration value
Future<void> handleConfigGet(
  Map<String, dynamic> args,
  Map<String, dynamic> flags,
) async {
  final key = args['key'] as String?;
  if (key == null) {
    error('Please provide a configuration key');
    return;
  }

  final String normalizedKey = OracularGlobalConfig.normalizeKey(key);
  info('Reading configuration key: $normalizedKey');

  final String? value = await OracularGlobalConfig.get(normalizedKey);
  if (value == null) {
    warn("Key '$normalizedKey' not found in configuration");
    return;
  }

  print('$normalizedKey: $value');
}

/// Set a configuration value
Future<void> handleConfigSet(
  Map<String, dynamic> args,
  Map<String, dynamic> flags,
) async {
  final key = args['key'] as String?;
  final value = args['value'] as String?;

  if (key == null || value == null) {
    error('Please provide both key and value');
    print('Example: oracular config set org art.arcane');
    return;
  }

  final String normalizedKey = OracularGlobalConfig.normalizeKey(key);
  if (!OracularGlobalConfig.supportedKeys.contains(normalizedKey) &&
      !OracularGlobalConfig.defaults.containsKey(normalizedKey)) {
    warn('Unknown config key "$key". It will be saved as "$normalizedKey".');
  }

  await OracularGlobalConfig.set(normalizedKey, value);
  success('Configuration updated: $normalizedKey = $value');
}

/// List all configuration values
Future<void> handleConfigList() async {
  info('Listing configuration...');

  final Map<String, String> values = <String, String>{
    ...OracularGlobalConfig.defaults,
    ...await OracularGlobalConfig.load(),
  };

  if (values.isEmpty) {
    error("Configuration not found. Run 'oracular config init' first.");
    return;
  }

  print('\nConfiguration (${OracularGlobalConfig.configPath}):');
  print('─' * 50);
  for (final String key in values.keys) {
    print('$key: ${values[key]}');
  }
  print('─' * 50);
  print('');
  print('Common defaults:');
  print('  oracular config set org art.arcane');
  print('  oracular config set output_dir ~/Developer');
  print('  oracular config set default_template arcane_app');
  print('  oracular config set firebase_project_id my-project');
}

/// Show configuration file path
Future<void> handleConfigPath() async {
  print('Configuration path: ${OracularGlobalConfig.configPath}');
  final exists = File(OracularGlobalConfig.configPath).existsSync();
  print('Exists: ${exists ? 'Yes' : 'No'}');

  if (!exists) {
    info("Run 'oracular config init' to create configuration");
  }
}
