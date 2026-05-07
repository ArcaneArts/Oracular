import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../models/setup_config.dart';
import 'user_prompt.dart';

/// Finds generated Oracular project configuration from common cwd locations.
class ProjectConfigLoader {
  static Future<SetupConfig?> load({String? startDir}) async {
    final String currentDir = startDir ?? Directory.current.path;

    final List<String> searchPaths = configSearchPaths(currentDir);

    for (final String path in searchPaths) {
      final String normalizedPath = p.normalize(path);
      final SetupConfig? config =
          await SetupConfig.loadFromFile(normalizedPath);
      if (config != null) {
        verbose('Loaded config from: $normalizedPath');
        return config;
      }
    }

    return null;
  }

  static List<String> configSearchPaths(String startDir, {int maxDepth = 6}) {
    final List<String> searchPaths = <String>[];
    final Set<String> seen = <String>{};
    String cursor = p.normalize(startDir);

    for (int depth = 0; depth <= maxDepth; depth++) {
      final String configPath = p.join(cursor, 'config', 'setup_config.env');
      if (seen.add(configPath)) {
        searchPaths.add(configPath);
      }

      final String parent = p.dirname(cursor);
      if (parent == cursor) {
        break;
      }
      cursor = parent;
    }

    return searchPaths;
  }

  static void printMissingConfigHelp() {
    error('No Oracular setup configuration found.');
    print('');
    UserPrompt.printNumberedList(<String>[
      'cd <your generated project root>',
      'oracular guide',
      'If this is a new project, run: oracular create',
    ]);
  }
}
