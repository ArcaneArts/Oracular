import 'dart:io';

import 'package:path/path.dart' as p;

/// Configuration for deployment integration tests
///
/// Requires:
/// - Service account JSON file at Oracular root (not oracular/)
/// - Firebase project: oraculartestdeployments
class DeploymentTestConfig {
  /// Firebase project ID for testing
  static const String projectId = 'oraculartestdeployments';

  /// Get the Oracular root directory (parent of oracular/ CLI package)
  static String get _oracularRoot {
    // Tests run from oracular/ directory, so go up one level to Oracular/
    final String currentDir = Directory.current.path;
    // If we're in oracular/, go up to Oracular/
    if (currentDir.endsWith('oracular')) {
      return p.normalize(p.join(currentDir, '..'));
    }
    // If we're already at Oracular level
    if (Directory(p.join(currentDir, 'oracular')).existsSync() &&
        Directory(p.join(currentDir, 'templates')).existsSync()) {
      return currentDir;
    }
    // Fallback: assume we're in oracular/
    return p.normalize(p.join(currentDir, '..'));
  }

  /// Get the path to the service account file
  static String get serviceAccountPath {
    final String preferredPath = p.join(_oracularRoot, 'service-account.json');
    if (File(preferredPath).existsSync()) {
      return preferredPath;
    }

    // Backward-compatible fallback for older local setups
    return p.join(_oracularRoot, 'oraculat-test-service-account.json');
  }

  /// Get the templates path
  static String get templatesPath {
    return p.join(_oracularRoot, 'templates');
  }

  /// Check if deployment tests can run
  static bool get canRunDeploymentTests {
    final File serviceAccount = File(serviceAccountPath);
    return serviceAccount.existsSync();
  }

  /// Get environment variables for Firebase/gcloud authentication
  static Map<String, String> get authEnvironment {
    return <String, String>{
      'GOOGLE_APPLICATION_CREDENTIALS': serviceAccountPath,
    };
  }

  /// Skip message when tests cannot run
  static String get skipMessage =>
      'Deployment tests require service account at: $serviceAccountPath';

  /// Activate gcloud service account for tests that need gcloud CLI
  /// Note: This does NOT set the global project - use --project flag instead
  static Future<bool> activateGcloudServiceAccount() async {
    final ProcessResult result = await Process.run('gcloud', <String>[
      'auth',
      'activate-service-account',
      '--key-file=$serviceAccountPath',
    ]);
    return result.exitCode == 0;
  }

  /// Initialize gcloud for testing
  /// Note: Does NOT modify global gcloud config - all commands should use --project flag
  static Future<bool> initializeGcloud() async {
    return await activateGcloudServiceAccount();
  }
}
