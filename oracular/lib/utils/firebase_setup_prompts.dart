import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import 'user_prompt.dart';

/// Shared prompts for optional Firebase server credentials.
class FirebaseSetupPrompts {
  static Future<String?> askServiceAccountKeyPath({
    required String outputDir,
    required String serverPackageName,
  }) async {
    final String recommendedPath = p.join(
      outputDir,
      serverPackageName,
      'service-account.json',
    );

    print('');
    info('A service account key is only needed for server deployment.');
    UserPrompt.printList(<String>[
      'You can skip this now and add the file later.',
      'Recommended path: $recommendedPath',
      'Firebase Console: Project settings > Service accounts > '
          'Generate new private key.',
    ]);

    final bool addNow = await UserPrompt.askYesNo(
      'Use an existing service account key now?',
      defaultValue: false,
    );
    if (!addNow) {
      return null;
    }

    final String keyPath = await UserPrompt.askString(
      'Path to service-account.json',
      validator: (String value) => _isExistingJsonFile(value),
      validationMessage: 'Enter the path to an existing JSON key file.',
    );

    return p.normalize(p.absolute(keyPath));
  }

  static String? normalizeConfiguredKeyPath(String? keyPath) {
    if (keyPath == null || keyPath.trim().isEmpty) {
      return null;
    }
    return p.normalize(p.absolute(keyPath));
  }

  static bool _isExistingJsonFile(String value) {
    final String path = value.trim();
    if (path.isEmpty || !path.endsWith('.json')) {
      return false;
    }
    return File(path).existsSync();
  }
}
