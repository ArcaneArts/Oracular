import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../models/template_info.dart';

/// User-level Oracular defaults stored at `~/.oracular/config.yaml`.
///
/// These values are intentionally small and project-creation focused. They
/// prefill `oracular create`, `oracular new`, and the interactive wizard so
/// repeated scaffolding does not require re-entering organization/template
/// preferences every time.
class OracularGlobalConfig {
  OracularGlobalConfig._();

  static String get configDir {
    final String? home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null || home.trim().isEmpty) {
      throw Exception('Could not determine home directory');
    }
    return p.join(home, '.oracular');
  }

  static String get configPath => p.join(configDir, 'config.yaml');

  static const Map<String, String> defaults = <String, String>{
    'org': 'com.example',
    'output_dir': '.',
    'default_template': 'arcane_app',
    'firebase_project_id': '',
    'service_account_key': '',
    'render_mode': '',
  };

  static const Map<String, String> keyAliases = <String, String>{
    'organization': 'org',
    'org_domain': 'org',
    'output': 'output_dir',
    'dir': 'output_dir',
    'template': 'default_template',
    'firebase_project': 'firebase_project_id',
    'project_id': 'firebase_project_id',
    'service_account': 'service_account_key',
    'service_account_path': 'service_account_key',
    'render': 'render_mode',
    'jaspr_render_mode': 'render_mode',
  };

  static Set<String> get supportedKeys => <String>{
    ...defaults.keys,
    ...keyAliases.keys,
  };

  static String normalizeKey(String key) {
    final String normalized = key.trim().toLowerCase().replaceAll('-', '_');
    return keyAliases[normalized] ?? normalized;
  }

  static String defaultContent() {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('# Oracular Configuration File');
    buffer.writeln('# Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln();
    buffer.writeln('# Project creation defaults');
    buffer.writeln('# Set these with: oracular config set <key> <value>');
    for (final MapEntry<String, String> entry in defaults.entries) {
      buffer.writeln('${entry.key}: ${entry.value}');
    }
    return buffer.toString();
  }

  static Future<File> ensureExists({bool force = false}) async {
    final Directory dir = Directory(configDir);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final File file = File(configPath);
    if (force || !file.existsSync()) {
      await file.writeAsString(defaultContent());
    }
    return file;
  }

  static Future<Map<String, String>> load() async {
    final File file = File(configPath);
    if (!file.existsSync()) {
      return <String, String>{};
    }

    final String content = await file.readAsString();
    final dynamic yaml = loadYaml(content);
    if (yaml is! YamlMap) {
      return <String, String>{};
    }

    final Map<String, String> values = <String, String>{};
    for (final MapEntry<dynamic, dynamic> entry in yaml.entries) {
      values[normalizeKey(entry.key.toString())] =
          entry.value?.toString() ?? '';
    }
    return values;
  }

  static Future<String?> get(String key) async {
    final String normalizedKey = normalizeKey(key);
    final Map<String, String> values = await load();
    final String? value = values[normalizedKey];
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }

  static Future<void> set(String key, String value) async {
    final String normalizedKey = normalizeKey(key);
    await ensureExists();
    final Map<String, String> values = <String, String>{
      ...defaults,
      ...await load(),
      normalizedKey: value,
    };
    await _write(values);
  }

  static Future<void> _write(Map<String, String> values) async {
    final File file = await ensureExists();
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('# Oracular Configuration File');
    buffer.writeln('# Updated: ${DateTime.now().toIso8601String()}');
    buffer.writeln();
    buffer.writeln('# Project creation defaults');

    final Set<String> written = <String>{};
    for (final String key in defaults.keys) {
      buffer.writeln('$key: ${values[key] ?? defaults[key] ?? ''}');
      written.add(key);
    }

    final List<String> customKeys =
        values.keys.where((String key) => !written.contains(key)).toList()
          ..sort();
    if (customKeys.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('# Custom values');
      for (final String key in customKeys) {
        buffer.writeln('$key: ${values[key] ?? ''}');
      }
    }

    await file.writeAsString(buffer.toString());
  }

  static String? value(Map<String, String> values, String key) {
    final String? raw = values[key];
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return raw.trim();
  }

  static String defaultOrg(Map<String, String> values) {
    return value(values, 'org') ?? defaults['org']!;
  }

  static String defaultOutputDir(Map<String, String> values) {
    return _resolvePath(value(values, 'output_dir') ?? defaults['output_dir']!);
  }

  static TemplateType defaultTemplate(Map<String, String> values) {
    final String? configured = value(values, 'default_template');
    if (configured == null) {
      return TemplateType.arcaneTemplate;
    }
    return TemplateTypeExtension.parse(configured) ??
        TemplateType.arcaneTemplate;
  }

  static String? defaultFirebaseProjectId(Map<String, String> values) {
    return value(values, 'firebase_project_id');
  }

  static String? defaultServiceAccountKey(Map<String, String> values) {
    return value(values, 'service_account_key');
  }

  static String? defaultRenderMode(Map<String, String> values) {
    return value(values, 'render_mode');
  }

  static String _resolvePath(String raw) {
    String value = raw.trim();
    if (value.isEmpty || value == '.') {
      return Directory.current.path;
    }
    if (value == '~' || value.startsWith('~/') || value.startsWith('~\\')) {
      final String? home =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home != null && home.isNotEmpty) {
        value = value == '~' ? home : p.join(home, value.substring(2));
      }
    }
    if (p.isAbsolute(value)) {
      return p.normalize(value);
    }
    return p.normalize(p.absolute(value));
  }
}
