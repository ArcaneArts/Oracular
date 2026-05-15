import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import 'template_downloader.dart';

class TemplatePathResolver {
  static Future<String> findTemplatesPath({
    void Function(String message)? onProgress,
  }) async {
    final String scriptPath = Platform.script.toFilePath();
    final String scriptDir = p.dirname(scriptPath);

    final List<String> possiblePaths = <String>[
      p.join(scriptDir, '..', '..', 'templates'),
      p.join(Directory.current.path, '..', 'templates'),
      p.join(Directory.current.path, 'templates'),
    ];

    for (final String path in possiblePaths) {
      final String normalizedPath = p.normalize(path);
      if (Directory(normalizedPath).existsSync()) {
        verbose('Found local templates at: $normalizedPath');
        return normalizedPath;
      }
    }

    onProgress?.call('Downloading templates from GitHub...');
    return await TemplateDownloader.ensureTemplates(onProgress: onProgress);
  }
}
