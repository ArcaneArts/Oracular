import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

/// Launch the GUI wizard
Future<void> handleGuiLaunch(Map<String, dynamic> args, Map<String, dynamic> flags) async {
  info("Launching Oracular GUI wizard...");

  final String? guiPath = await _findGuiPath();

  if (guiPath == null) {
    error("Could not find oracular_gui project.");
    error("The GUI project should be located at: ../oracular_gui relative to oracular");
    exit(1);
  }

  verbose("Found GUI at: $guiPath");

  // Build flutter run command
  final flutterArgs = <String>['run'];

  // Add platform if specified
  final platform = args['platform'] as String?;
  if (platform != null) {
    flutterArgs.addAll(['-d', platform]);
  }

  // Add release mode if requested
  if (flags['release'] == true) {
    flutterArgs.add('--release');
  }

  info("Starting Flutter app...");
  verbose("Command: flutter ${flutterArgs.join(' ')}");

  // Run the GUI
  final process = await Process.start(
    'flutter',
    flutterArgs,
    workingDirectory: guiPath,
    mode: ProcessStartMode.inheritStdio,
  );

  final exitCode = await process.exitCode;

  if (exitCode != 0) {
    error("GUI exited with code $exitCode");
    exit(exitCode);
  }
}

/// Build the GUI for distribution
Future<void> handleGuiBuild(Map<String, dynamic> args, Map<String, dynamic> flags) async {
  final String platform = args['platform'] as String? ?? 'macos';
  info("Building Oracular GUI for $platform...");

  final String? guiPath = await _findGuiPath();

  if (guiPath == null) {
    error("Could not find oracular_gui project.");
    exit(1);
  }

  final flutterArgs = ['build', platform, '--release'];

  info("Running: flutter ${flutterArgs.join(' ')}");

  final result = await Process.run(
    'flutter',
    flutterArgs,
    workingDirectory: guiPath,
    runInShell: Platform.isWindows,
  );

  if (result.exitCode == 0) {
    success("Build completed successfully!");
    info("Output: $guiPath/build/$platform/");
  } else {
    error("Build failed: ${result.stderr}");
    exit(result.exitCode);
  }
}

/// Find the GUI project path
Future<String?> _findGuiPath() async {
  final List<String> possiblePaths = [
    // Relative to Oracular directory
    p.join(Directory.current.path, '..', 'oracular_gui'),
    p.join(Directory.current.path, 'oracular_gui'),
    // Check if we're in the Oracular parent directory
    p.join(Directory.current.path, 'Oracular', 'oracular_gui'),
    // Platform-specific install locations (for compiled versions)
    if (Platform.isMacOS) ...[
      p.join(Platform.environment['HOME'] ?? '', '.oracular', 'gui'),
      '/Applications/OracularGUI.app/Contents/MacOS',
    ],
    if (Platform.isLinux) ...[
      p.join(Platform.environment['HOME'] ?? '', '.oracular', 'gui'),
      '/usr/local/share/oracular/gui',
    ],
    if (Platform.isWindows) ...[
      p.join(Platform.environment['LOCALAPPDATA'] ?? '', 'Oracular', 'gui'),
    ],
  ];

  for (final String path in possiblePaths) {
    final String normalized = p.normalize(path);
    final Directory dir = Directory(normalized);
    if (dir.existsSync()) {
      // Check if it's a valid Flutter project
      final File pubspec = File(p.join(normalized, 'pubspec.yaml'));
      if (pubspec.existsSync()) {
        return normalized;
      }
    }
  }

  // Try to find it relative to the script location
  final String scriptPath = Platform.script.toFilePath();
  final String scriptDir = p.dirname(scriptPath);
  final String parentOfScript = p.dirname(p.dirname(scriptDir));
  final String guiFromScript = p.join(parentOfScript, 'oracular_gui');

  if (Directory(guiFromScript).existsSync()) {
    return guiFromScript;
  }

  return null;
}
