import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Service for running scripts defined in pubspec.yaml
class ScriptRunner {
  /// Find the nearest pubspec.yaml by walking up the directory tree
  File? findPubspec([String? startDir]) {
    Directory dir = Directory(startDir ?? Directory.current.path);

    while (true) {
      final File pubspec = File(p.join(dir.path, 'pubspec.yaml'));
      if (pubspec.existsSync()) return pubspec;

      final Directory parent = dir.parent;
      if (parent.path == dir.path) return null;
      dir = parent;
    }
  }

  /// Parse scripts from pubspec.yaml
  Map<String, String> getScripts([String? pubspecPath]) {
    final File? pubspec = pubspecPath != null ? File(pubspecPath) : findPubspec();
    if (pubspec == null || !pubspec.existsSync()) return <String, String>{};

    try {
      final String content = pubspec.readAsStringSync();
      final YamlMap? yaml = loadYaml(content) as YamlMap?;
      if (yaml == null) return <String, String>{};

      final dynamic scripts = yaml['scripts'];
      if (scripts == null || scripts is! YamlMap) return <String, String>{};

      return Map<String, String>.fromEntries(
        scripts.entries.map((MapEntry<dynamic, dynamic> e) => MapEntry<String, String>(e.key.toString(), e.value.toString())),
      );
    } on Exception catch (e) {
      error('Failed to parse pubspec.yaml: $e');
      return <String, String>{};
    }
  }

  /// Get project name from pubspec.yaml
  String? getProjectName([String? pubspecPath]) {
    final File? pubspec = pubspecPath != null ? File(pubspecPath) : findPubspec();
    if (pubspec == null || !pubspec.existsSync()) return null;

    try {
      final String content = pubspec.readAsStringSync();
      final YamlMap? yaml = loadYaml(content) as YamlMap?;
      return yaml?['name']?.toString();
    } on Exception {
      return null;
    }
  }

  /// Find a script by name (supports fuzzy matching)
  String? findScript(String query, Map<String, String> scripts) {
    // Exact match
    if (scripts.containsKey(query)) return query;

    // Case-insensitive match
    final String lower = query.toLowerCase();
    for (final String key in scripts.keys) {
      if (key.toLowerCase() == lower) return key;
    }

    // Prefix match
    final List<String> prefixMatches = scripts.keys.where((String k) => k.toLowerCase().startsWith(lower)).toList();
    if (prefixMatches.length == 1) return prefixMatches.first;

    // Contains match
    final List<String> containsMatches = scripts.keys.where((String k) => k.toLowerCase().contains(lower)).toList();
    if (containsMatches.length == 1) return containsMatches.first;

    // Abbreviation match (e.g., "br" matches "build_runner", "pi" matches "pod_install")
    final List<String> abbrevMatches = scripts.keys.where((String k) => _matchesAbbreviation(lower, k)).toList();
    if (abbrevMatches.length == 1) return abbrevMatches.first;

    return null;
  }

  /// Check if query matches as an abbreviation of script name
  /// e.g., "br" matches "build_runner", "df" matches "deploy_firebase"
  bool _matchesAbbreviation(String query, String scriptName) {
    final List<String> parts = scriptName.toLowerCase().split('_');
    if (parts.length < 2) return false;

    // Build abbreviation from first letters
    final String abbrev = parts.map((String p) => p.isNotEmpty ? p[0] : '').join();
    return abbrev.startsWith(query);
  }

  /// Get all matching scripts for ambiguous query
  List<String> findMatchingScripts(String query, Map<String, String> scripts) {
    final String lower = query.toLowerCase();
    return scripts.keys.where((String k) {
      final String kLower = k.toLowerCase();
      return kLower.contains(lower) || _matchesAbbreviation(lower, k);
    }).toList();
  }

  /// Run a script by name
  Future<int> run(String scriptName, {bool showCommand = true}) async {
    final pubspec = findPubspec();
    if (pubspec == null) {
      error('No pubspec.yaml found in current directory or parents');
      return 1;
    }

    final scripts = getScripts(pubspec.path);
    if (scripts.isEmpty) {
      error('No scripts defined in pubspec.yaml');
      return 1;
    }

    final matchedName = findScript(scriptName, scripts);
    if (matchedName == null) {
      final matches = findMatchingScripts(scriptName, scripts);
      if (matches.isEmpty) {
        error('Script "$scriptName" not found');
        info('Available scripts: ${scripts.keys.join(', ')}');
      } else {
        error('Ambiguous script name "$scriptName"');
        info('Did you mean: ${matches.join(', ')}');
      }
      return 1;
    }

    final command = scripts[matchedName]!;
    final workingDir = pubspec.parent.path;

    if (showCommand) {
      info('Running: $matchedName');
      verbose('Command: $command');
      verbose('Working directory: $workingDir');
      print('');
    }

    // Run the command
    final result = await Process.run(
      Platform.isWindows ? 'cmd' : 'sh',
      Platform.isWindows ? ['/c', command] : ['-c', command],
      workingDirectory: workingDir,
      runInShell: true,
    );

    // Stream output
    if (result.stdout.toString().isNotEmpty) {
      stdout.write(result.stdout);
    }
    if (result.stderr.toString().isNotEmpty) {
      stderr.write(result.stderr);
    }

    if (result.exitCode == 0) {
      success('Script "$matchedName" completed successfully');
    } else {
      error('Script "$matchedName" failed with exit code ${result.exitCode}');
    }

    return result.exitCode;
  }

  /// Run a script with live output streaming
  Future<int> runStreaming(String scriptName) async {
    final pubspec = findPubspec();
    if (pubspec == null) {
      error('No pubspec.yaml found in current directory or parents');
      return 1;
    }

    final scripts = getScripts(pubspec.path);
    if (scripts.isEmpty) {
      error('No scripts defined in pubspec.yaml');
      return 1;
    }

    final matchedName = findScript(scriptName, scripts);
    if (matchedName == null) {
      final matches = findMatchingScripts(scriptName, scripts);
      if (matches.isEmpty) {
        error('Script "$scriptName" not found');
        info('Available scripts: ${scripts.keys.join(', ')}');
      } else {
        error('Ambiguous script name "$scriptName"');
        info('Did you mean: ${matches.join(', ')}');
      }
      return 1;
    }

    final command = scripts[matchedName]!;
    final workingDir = pubspec.parent.path;

    info('Running: $matchedName');
    verbose('Command: $command');
    print('');

    final process = await Process.start(
      Platform.isWindows ? 'cmd' : 'sh',
      Platform.isWindows ? ['/c', command] : ['-c', command],
      workingDirectory: workingDir,
      runInShell: true,
    );

    // Stream output in real-time
    process.stdout.listen((data) => stdout.add(data));
    process.stderr.listen((data) => stderr.add(data));

    final exitCode = await process.exitCode;

    print('');
    if (exitCode == 0) {
      success('Script "$matchedName" completed successfully');
    } else {
      error('Script "$matchedName" failed with exit code $exitCode');
    }

    return exitCode;
  }

  /// Print all available scripts
  void listScripts() {
    final pubspec = findPubspec();
    if (pubspec == null) {
      error('No pubspec.yaml found in current directory or parents');
      return;
    }

    final projectName = getProjectName(pubspec.path);
    final scripts = getScripts(pubspec.path);

    if (scripts.isEmpty) {
      warn('No scripts defined in pubspec.yaml');
      print('');
      print('Add scripts to your pubspec.yaml:');
      print('');
      print('scripts:');
      print('  build: flutter build');
      print('  test: flutter test');
      return;
    }

    print('');
    if (projectName != null) {
      print('Scripts for $projectName:');
    } else {
      print('Available scripts:');
    }
    print('\u2500' * 60);

    // Find max script name length for alignment
    final maxLen = scripts.keys.map((k) => k.length).reduce((a, b) => a > b ? a : b);

    for (final entry in scripts.entries) {
      final name = entry.key.padRight(maxLen + 2);
      final cmd = entry.value;
      // Truncate long commands
      final displayCmd = cmd.length > 50 ? '${cmd.substring(0, 47)}...' : cmd;
      print('  $name $displayCmd');
    }

    print('');
    print('Run with: oracular scripts exec <script_name>');
    print('Tip: Use abbreviations like "br" for "build_runner"');
  }
}
