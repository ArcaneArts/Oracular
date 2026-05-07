import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import 'link_opener.dart';
import 'user_prompt.dart';

/// Shared prompts for optional Firebase server credentials.
class FirebaseSetupPrompts {
  /// Canonical filename Oracular uses for the service account key.
  static const String _canonicalFileName = 'service-account.json';

  /// Ask the user where the service-account JSON lives. Instead of typing a
  /// long absolute path (which caps out at the terminal width), Oracular
  /// opens the destination folder in the OS file browser and lets the user
  /// drag/drop the key in. Pressing Enter then auto-detects the file.
  static Future<String?> askServiceAccountKeyPath({
    required String outputDir,
    required String serverPackageName,
  }) async {
    final Directory targetDir = Directory(
      p.join(outputDir, serverPackageName),
    );
    final String canonicalPath = p.join(targetDir.path, _canonicalFileName);

    print('');
    info('A service account key is only needed for server deployment.');
    UserPrompt.printList(<String>[
      'You can skip this now and add the file later.',
      'Generate one at: '
          'Firebase Console \u2192 Project settings \u2192 Service accounts.',
      'It will be saved as: $canonicalPath',
    ]);

    final bool addNow = await UserPrompt.askYesNo(
      'Drop in a service account key now?',
      defaultValue: false,
    );
    if (!addNow) {
      return null;
    }

    // Make sure the destination folder exists before opening it. Without this
    // the OS file browser would refuse to open a non-existent path.
    if (!targetDir.existsSync()) {
      try {
        targetDir.createSync(recursive: true);
      } catch (e) {
        warn('Could not create $targetDir: $e');
        return null;
      }
    }

    return _runDropInLoop(targetDir, canonicalPath);
  }

  /// Loop that opens the target folder, waits for the user to drop in a JSON
  /// file, then resolves which one to use.
  static Future<String?> _runDropInLoop(
    Directory targetDir,
    String canonicalPath,
  ) async {
    while (true) {
      final List<File> existingBefore = _listJsonFiles(targetDir);

      print('');
      info('Opening: ${targetDir.path}');
      final bool opened = await LinkOpener.open(targetDir.path);
      if (!opened) {
        warn(
          'Could not open the folder automatically. '
          'Open it manually: ${targetDir.path}',
        );
      }

      print('');
      UserPrompt.printList(<String>[
        'Move or save your key file (.json) into the opened folder.',
        'It will be renamed to "$_canonicalFileName" automatically.',
        'Press Enter when ready, or type "skip" to add it later.',
      ]);
      stdout.write('> ');
      final String response = (stdin.readLineSync() ?? '').trim().toLowerCase();
      if (response == 'skip' || response == 's') {
        return null;
      }

      final List<File> jsonFiles = _listJsonFiles(targetDir);
      if (jsonFiles.isEmpty) {
        warn(
          'No .json file found in ${targetDir.path}. '
          'Did the file get moved into the right folder?',
        );
        final bool retry = await UserPrompt.askYesNo(
          'Try again?',
          defaultValue: true,
        );
        if (!retry) {
          return null;
        }
        continue;
      }

      final File chosen = await _pickJsonFile(
        jsonFiles,
        existingBefore,
        canonicalPath,
      );

      // Normalize to canonical filename so downstream tooling can find it.
      final File canonical = File(canonicalPath);
      if (p.normalize(chosen.path) != p.normalize(canonical.path)) {
        try {
          if (canonical.existsSync()) {
            await canonical.delete();
          }
          await chosen.rename(canonical.path);
        } catch (e) {
          warn(
            'Could not rename ${chosen.path} to $canonicalPath: $e. '
            'Using the file as-is.',
          );
          return p.normalize(p.absolute(chosen.path));
        }
      }

      success('Using key: $canonicalPath');
      return canonicalPath;
    }
  }

  /// Picks the JSON file the user most likely wants. Prefers a newly-added
  /// file over pre-existing ones; if multiple new files appear, the user
  /// chooses by number.
  static Future<File> _pickJsonFile(
    List<File> jsonFiles,
    List<File> existingBefore,
    String canonicalPath,
  ) async {
    if (jsonFiles.length == 1) {
      return jsonFiles.first;
    }

    final Set<String> existingPaths =
        existingBefore.map((File f) => p.normalize(f.path)).toSet();
    final List<File> newlyAdded = jsonFiles
        .where((File f) => !existingPaths.contains(p.normalize(f.path)))
        .toList();

    if (newlyAdded.length == 1) {
      return newlyAdded.first;
    }

    // Multiple candidates: prefer a file already named service-account.json.
    final String canonicalNorm = p.normalize(canonicalPath);
    for (final File f in jsonFiles) {
      if (p.normalize(f.path) == canonicalNorm) {
        return f;
      }
    }

    print('');
    info('Multiple JSON files found:');
    for (int i = 0; i < jsonFiles.length; i++) {
      print('  ${i + 1}. ${p.basename(jsonFiles[i].path)}');
    }
    final int index = await UserPrompt.askInt(
      'Which one is the service account key?',
      defaultValue: 1,
      min: 1,
      max: jsonFiles.length,
    );
    return jsonFiles[index - 1];
  }

  static List<File> _listJsonFiles(Directory dir) {
    if (!dir.existsSync()) {
      return <File>[];
    }
    return dir
        .listSync(followLinks: false)
        .whereType<File>()
        .where((File f) => f.path.toLowerCase().endsWith('.json'))
        .toList();
  }

  static String? normalizeConfiguredKeyPath(String? keyPath) {
    if (keyPath == null || keyPath.trim().isEmpty) {
      return null;
    }
    return p.normalize(p.absolute(keyPath));
  }
}
