import 'dart:convert';
import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import 'link_opener.dart';
import 'user_prompt.dart';

/// Result of locating a pre-existing service-account key on disk. Carries
/// both the absolute path and the inferred Firebase project_id (when the
/// JSON parses cleanly) so the wizard can pre-fill follow-up prompts.
class DiscoveredServiceAccount {
  final String path;
  final String? projectId;
  final String? clientEmail;

  const DiscoveredServiceAccount({
    required this.path,
    this.projectId,
    this.clientEmail,
  });

  /// `true` iff [projectId] is non-empty and looks like a valid Firebase
  /// project id (lowercase letters/digits/hyphens). The wizard uses this
  /// to decide whether the discovered SA can drive prompt auto-fill.
  bool get hasProjectId =>
      projectId != null && projectId!.trim().isNotEmpty;
}

/// Shared prompts for optional Firebase server credentials.
class FirebaseSetupPrompts {
  /// Canonical filename Oracular uses for the service account key.
  static const String _canonicalFileName = 'service-account.json';

  /// Walks the user's filesystem looking for a pre-existing
  /// `service-account.json` so the wizard can offer to reuse it instead of
  /// asking the user to drop in another copy of the same key.
  ///
  /// Search order (first match wins):
  ///   1. `<outputDir>/service-account.json`
  ///   2. `<outputDir>/config/keys/service-account.json`
  ///   3. `<outputDir>/<serverPackageName>/service-account.json` (when
  ///      [serverPackageName] is provided)
  ///   4. `<currentDir>/service-account.json`
  ///   5. The first ancestor of [outputDir] (and of [Directory.current])
  ///      that contains a `service-account.json`, walking up at most 6
  ///      levels. This catches the common "I keep my SA at the workspace
  ///      root" pattern (e.g. running `oracular` from a folder that has
  ///      `service-account.json` next to multiple project subdirs).
  ///
  /// Returns `null` when nothing matches.
  static DiscoveredServiceAccount? findExistingServiceAccountKey({
    required String outputDir,
    String? serverPackageName,
  }) {
    final List<String> candidates = <String>[];

    void addIfNotEmpty(String path) {
      if (path.trim().isEmpty) return;
      candidates.add(p.normalize(p.absolute(path)));
    }

    addIfNotEmpty(p.join(outputDir, _canonicalFileName));
    addIfNotEmpty(p.join(outputDir, 'config', 'keys', _canonicalFileName));
    if (serverPackageName != null && serverPackageName.trim().isNotEmpty) {
      addIfNotEmpty(p.join(outputDir, serverPackageName, _canonicalFileName));
    }
    addIfNotEmpty(p.join(Directory.current.path, _canonicalFileName));

    // Walk ancestors of both outputDir and the current working directory.
    // Six levels is more than enough for typical workspace layouts and
    // guards against runaway loops on broken filesystems.
    for (final String start in <String>{
      p.normalize(p.absolute(outputDir)),
      p.normalize(p.absolute(Directory.current.path)),
    }) {
      String dir = start;
      for (int depth = 0; depth < 6; depth++) {
        final String parent = p.dirname(dir);
        if (parent == dir) break; // reached filesystem root
        dir = parent;
        addIfNotEmpty(p.join(dir, _canonicalFileName));
      }
    }

    final Set<String> seen = <String>{};
    for (final String candidate in candidates) {
      if (!seen.add(candidate)) continue;
      final File file = File(candidate);
      if (!file.existsSync()) continue;
      return _readDiscoveredServiceAccount(file);
    }
    return null;
  }

  /// Read [file] as a Firebase service-account JSON and return the
  /// project_id / client_email pair. Returns a [DiscoveredServiceAccount]
  /// with a null `projectId` when the JSON is unreadable or malformed —
  /// callers should still treat the file as a key (the orchestrator can
  /// recover) but skip auto-filling project metadata.
  static DiscoveredServiceAccount _readDiscoveredServiceAccount(File file) {
    String? projectId;
    String? clientEmail;
    try {
      final dynamic decoded = jsonDecode(file.readAsStringSync());
      if (decoded is Map<String, dynamic>) {
        final dynamic pid = decoded['project_id'];
        if (pid is String && pid.trim().isNotEmpty) {
          projectId = pid.trim();
        }
        final dynamic email = decoded['client_email'];
        if (email is String && email.trim().isNotEmpty) {
          clientEmail = email.trim();
        }
      }
    } catch (_) {
      // Malformed JSON — surface the file path but skip metadata.
    }
    return DiscoveredServiceAccount(
      path: p.normalize(p.absolute(file.path)),
      projectId: projectId,
      clientEmail: clientEmail,
    );
  }

  /// Ask the user where the service-account JSON lives. Instead of typing a
  /// long absolute path (which caps out at the terminal width), Oracular
  /// opens the destination folder in the OS file browser and lets the user
  /// drag/drop the key in. Pressing Enter then auto-detects the file.
  ///
  /// When [serverPackageName] is provided, the key is dropped into the
  /// server package folder (`<outputDir>/<server>/`) so server deployment
  /// can pick it up directly. When omitted (or the project has no server),
  /// the key lands in the canonical project-level keys folder
  /// (`<outputDir>/config/keys/`) which `FirebaseService` resolves
  /// automatically for IAM-gated Firebase setup steps.
  ///
  /// Before prompting the user, this also walks common locations
  /// (output dir, current dir, parents up to 6 levels) for an existing
  /// `service-account.json`. When one is found, the user is offered the
  /// chance to reuse it — that's the hands-off path for users who keep a
  /// shared SA at their workspace root.
  static Future<String?> askServiceAccountKeyPath({
    required String outputDir,
    String? serverPackageName,
  }) async {
    final bool forServer =
        serverPackageName != null && serverPackageName.trim().isNotEmpty;
    final Directory targetDir = forServer
        ? Directory(p.join(outputDir, serverPackageName))
        : Directory(p.join(outputDir, 'config', 'keys'));
    final String canonicalPath = p.join(targetDir.path, _canonicalFileName);

    // Step 1: see if we already have one we can use.
    final DiscoveredServiceAccount? discovered =
        findExistingServiceAccountKey(
      outputDir: outputDir,
      serverPackageName: serverPackageName,
    );
    if (discovered != null) {
      print('');
      success('Found an existing service account key.');
      UserPrompt.printList(<String>[
        'Path: ${discovered.path}',
        if (discovered.hasProjectId) 'Project: ${discovered.projectId}',
        if (discovered.clientEmail != null)
          'Service account: ${discovered.clientEmail}',
      ]);
      final bool reuse = await UserPrompt.askYesNo(
        'Use this service account?',
        defaultValue: true,
      );
      if (reuse) {
        return discovered.path;
      }
    }

    // Step 2: explain why this matters before asking to drop one in.
    print('');
    if (forServer) {
      info(
        'A service account key powers Firebase Admin SDK calls from your '
        'server and unlocks IAM-gated Firebase setup steps.',
      );
    } else {
      info(
        'A service account key lets Oracular run Firebase setup '
        '(IAM grants, Firestore/Storage init, hosting deploys) without '
        'manual console clicks. You can also add it later.',
      );
    }
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
