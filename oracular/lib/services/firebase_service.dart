import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../models/setup_config.dart';
import '../utils/process_runner.dart' show ProcessResult, ProcessRunner;

/// Service for Firebase operations
class FirebaseService {
  final SetupConfig config;
  final ProcessRunner _runner;

  FirebaseService(this.config, {ProcessRunner? runner})
    : _runner = runner ?? ProcessRunner();

  /// Login to Firebase CLI
  Future<bool> login() async {
    info('Logging in to Firebase...');

    final int result = await _runner.runStreaming('firebase', <String>['login']);
    return result == 0;
  }

  /// Login to gcloud
  Future<bool> gcloudLogin() async {
    info('Logging in to Google Cloud...');

    final int result = await _runner.runStreaming('gcloud', <String>['auth', 'login']);
    return result == 0;
  }

  /// Configure FlutterFire for the project
  Future<bool> configureFlutterFire() async {
    if (config.firebaseProjectId == null) {
      error('Firebase project ID not set');
      return false;
    }

    // CLI templates: no Firebase client config needed
    if (config.template.isDartCli) {
      info('CLI templates do not require FlutterFire configuration');
      info('Use Firebase Admin SDK on the server side if needed');
      return true;
    }

    // Flutter templates: use flutterfire configure
    return await _runFlutterFireConfigure(
      p.join(config.outputDir, config.appName),
      config.platforms,
    );
  }

  /// Ensure Firebase apps exist for the specified platforms
  /// FlutterFire CLI crashes with RangeError if no apps exist
  /// [appDisplayName] is the name to use for the Firebase app (e.g., my_app_mobile)
  Future<void> _ensureFirebaseAppsExist(
    List<String> platforms,
    String androidPackage,
    String iosBundleId, {
    String? appDisplayName,
  }) async {
    if (config.firebaseProjectId == null) return;

    // Use provided display name or default to config.appName
    final String displayName = appDisplayName ?? config.appName;

    verbose('  Checking Firebase apps for project: ${config.firebaseProjectId}');
    verbose('  App display name: $displayName');
    verbose('  Android package: $androidPackage');
    verbose('  iOS bundle ID: $iosBundleId');

    // Check existing apps
    final ProcessResult listResult = await _runner.run(
      'firebase',
      <String>['apps:list', '--project', config.firebaseProjectId!],
    );

    final String existingApps = listResult.stdout.toLowerCase();
    verbose('  Existing apps output: ${existingApps.length > 200 ? '${existingApps.substring(0, 200)}...' : existingApps}');

    for (final String platform in platforms) {
      bool appExists = false;

      if (platform == 'android') {
        appExists = existingApps.contains('android') &&
            existingApps.contains(androidPackage.toLowerCase());
      } else if (platform == 'ios') {
        appExists = existingApps.contains('ios') &&
            existingApps.contains(iosBundleId.toLowerCase());
      } else if (platform == 'web') {
        appExists = existingApps.contains('web');
      }

      if (!appExists) {
        info('Creating Firebase $platform app...');

        final List<String> createArgs = <String>[
          'apps:create',
          platform.toUpperCase(),
          '${displayName}_$platform',
          '--project',
          config.firebaseProjectId!,
        ];

        // Add required package name/bundle id
        if (platform == 'android') {
          createArgs.addAll(<String>['--package-name', androidPackage]);
        } else if (platform == 'ios') {
          createArgs.addAll(<String>['--bundle-id', iosBundleId]);
        }

        verbose('  Running: firebase ${createArgs.join(' ')}');

        final ProcessResult createResult = await _runner.run('firebase', createArgs);

        if (createResult.success) {
          success('  Created Firebase $platform app');
        } else {
          // Log both stdout and stderr for debugging
          if (createResult.stdout.isNotEmpty) {
            verbose('  stdout: ${createResult.stdout}');
          }
          if (createResult.stderr.isNotEmpty) {
            warn('  Firebase $platform app creation failed: ${createResult.stderr}');
          } else {
            // Check if it's because app already exists
            warn('  Firebase $platform app creation may have failed (no output)');
          }
        }
      } else {
        verbose('  Firebase $platform app already exists');
      }
    }
  }

  /// Run flutterfire configure for a Flutter project
  /// [subprojectName] is used for subprojects where the subproject has a different name
  Future<bool> _runFlutterFireConfigure(
    String projectPath,
    List<String> platforms, {
    String? subprojectName,
  }) async {
    info('Configuring FlutterFire...');
    verbose('  Project path: $projectPath');
    verbose('  Firebase project: ${config.firebaseProjectId}');
    verbose('  Platforms: ${platforms.join(", ")}');

    // Check if the directory exists
    if (!Directory(projectPath).existsSync()) {
      error('Project directory does not exist: $projectPath');
      return false;
    }

    // Check for pubspec.yaml
    final File pubspec = File(p.join(projectPath, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      error('pubspec.yaml not found in: $projectPath');
      return false;
    }
    verbose('  pubspec.yaml found');

    // Check pubspec content for Flutter SDK
    final String pubspecContent = await pubspec.readAsString();
    if (!pubspecContent.contains('flutter:')) {
      error('This does not appear to be a Flutter project (no flutter: in pubspec.yaml)');
      verbose('  pubspec.yaml content preview:');
      verbose('  ${pubspecContent.substring(0, pubspecContent.length > 200 ? 200 : pubspecContent.length)}...');
      return false;
    }
    verbose('  Flutter SDK dependency found');

    // Try to extract package identifiers to avoid interactive prompts
    final String? androidPackage = await _extractAndroidPackageName(projectPath);
    final String? iosBundleId = await _extractIosBundleId(projectPath);

    // Construct default identifiers if not extracted
    // Use subprojectName for subprojects (e.g., my_app_mobile)
    final String projectName = subprojectName ?? config.appName;
    final String defaultAndroidPackage = '${config.orgDomain}.$projectName';
    // iOS bundle IDs cannot contain underscores - convert to camelCase
    final String iosSafeProjectName = _convertToCamelCase(projectName);
    final String defaultIosBundleId = '${config.orgDomain}.$iosSafeProjectName';
    final String effectiveAndroidPackage = androidPackage ?? defaultAndroidPackage;
    final String effectiveIosBundleId = iosBundleId ?? defaultIosBundleId;

    // Ensure Firebase apps exist before running flutterfire configure
    // FlutterFire CLI crashes with RangeError if no apps exist for the platforms
    await _ensureFirebaseAppsExist(
      platforms,
      effectiveAndroidPackage,
      effectiveIosBundleId,
      appDisplayName: projectName,
    );

    // Wait a moment for Firebase to propagate app creation
    await Future<void>.delayed(const Duration(seconds: 2));

    final List<String> args = <String>[
      'configure',
      '--project',
      config.firebaseProjectId!,
      '--yes', // Skip confirmation prompts to avoid terminal interaction issues
    ];

    // Add platforms
    for (final String platform in platforms) {
      args.add('--platforms');
      args.add(platform);
    }

    // Always provide package name/bundle ID to avoid FlutterFire interactive prompts
    if (platforms.contains('android')) {
      args.addAll(<String>['--android-package-name', effectiveAndroidPackage]);
      verbose('  Android package: $effectiveAndroidPackage');
    }

    if (platforms.contains('ios')) {
      args.addAll(<String>['--ios-bundle-id', effectiveIosBundleId]);
      verbose('  iOS bundle ID: $effectiveIosBundleId');
    }

    verbose('  Running: flutterfire ${args.join(" ")}');

    final ProcessResult? result = await _runner.runWithRetry(
      'flutterfire',
      args,
      workingDirectory: projectPath,
      operationName: 'FlutterFire configure',
    );

    if (result == null) {
      error('FlutterFire command returned null result');
      return false;
    }

    if (!result.success) {
      error('FlutterFire configure failed');
      if (result.stdout.isNotEmpty) {
        verbose('  stdout: ${result.stdout}');
      }
      if (result.stderr.isNotEmpty) {
        verbose('  stderr: ${result.stderr}');
      }
      verbose('  Exit code: ${result.exitCode}');
    }

    return result.success;
  }

  /// Deploy Firestore rules
  Future<bool> deployFirestore() async {
    info('Deploying Firestore rules...');

    final ProcessResult? result = await _runner.runWithRetry(
      'firebase',
      <String>['deploy', '--only', 'firestore:rules,firestore:indexes'],
      workingDirectory: config.outputDir,
      operationName: 'Deploy Firestore',
    );

    return result != null && result.success;
  }

  /// Deploy Storage rules
  Future<bool> deployStorage() async {
    info('Deploying Storage rules...');

    final ProcessResult? result = await _runner.runWithRetry(
      'firebase',
      <String>['deploy', '--only', 'storage'],
      workingDirectory: config.outputDir,
      operationName: 'Deploy Storage',
    );

    return result != null && result.success;
  }

  /// Build web app
  Future<bool> buildWeb() async {
    final String projectPath = p.join(config.outputDir, config.appName);

    info('Building web app...');

    // Flutter templates: use flutter build web
    final ProcessResult? result = await _runner.runWithRetry(
      'flutter',
      <String>['build', 'web', '--release'],
      workingDirectory: projectPath,
      operationName: 'Flutter build web',
    );

    return result != null && result.success;
  }

  /// Deploy to Firebase Hosting (release target)
  Future<bool> deployHostingRelease() async {
    info('Deploying to Firebase Hosting (release)...');

    final ProcessResult? result = await _runner.runWithRetry(
      'firebase',
      <String>['deploy', '--only', 'hosting:release'],
      workingDirectory: config.outputDir,
      operationName: 'Deploy Hosting (release)',
    );

    return result != null && result.success;
  }

  /// Deploy to Firebase Hosting (beta target)
  Future<bool> deployHostingBeta() async {
    info('Deploying to Firebase Hosting (beta)...');

    final ProcessResult? result = await _runner.runWithRetry(
      'firebase',
      <String>['deploy', '--only', 'hosting:beta'],
      workingDirectory: config.outputDir,
      operationName: 'Deploy Hosting (beta)',
    );

    return result != null && result.success;
  }

  /// Deploy all Firebase resources
  Future<bool> deployAll() async {
    info('Deploying all Firebase resources...');

    // Deploy in order
    if (!await deployFirestore()) {
      warn('Firestore deployment failed');
    }

    if (!await deployStorage()) {
      warn('Storage deployment failed');
    }

    if (!await buildWeb()) {
      error('Web build failed');
      return false;
    }

    if (!await deployHostingRelease()) {
      warn('Hosting deployment failed');
    }

    success('Firebase deployment complete');
    return true;
  }

  /// Enable Google Cloud APIs needed for deployment
  Future<bool> enableGoogleApis() async {
    if (config.firebaseProjectId == null) {
      error('Firebase project ID not set');
      return false;
    }

    info('Enabling Google Cloud APIs...');

    // Enable Artifact Registry
    ProcessResult result = await _runner.run('gcloud', <String>[
      'services',
      'enable',
      'artifactregistry.googleapis.com',
      '--project',
      config.firebaseProjectId!,
    ]);

    if (!result.success) {
      warn('Failed to enable Artifact Registry API');
    }

    // Enable Cloud Run
    result = await _runner.run('gcloud', <String>[
      'services',
      'enable',
      'run.googleapis.com',
      '--project',
      config.firebaseProjectId!,
    ]);

    if (!result.success) {
      warn('Failed to enable Cloud Run API');
    }

    return true;
  }

  /// Extract Android package name from build.gradle or AndroidManifest.xml
  Future<String?> _extractAndroidPackageName(String projectPath) async {
    // Try build.gradle.kts first (newer format)
    final File buildGradleKts = File(
      p.join(projectPath, 'android', 'app', 'build.gradle.kts'),
    );
    if (buildGradleKts.existsSync()) {
      final String content = await buildGradleKts.readAsString();
      // Look for: namespace = "com.example.app" or applicationId = "com.example.app"
      final RegExp namespaceRegex = RegExp(r'namespace\s*=\s*"([^"]+)"');
      final RegExp appIdRegex = RegExp(r'applicationId\s*=\s*"([^"]+)"');

      final RegExpMatch? namespaceMatch = namespaceRegex.firstMatch(content);
      if (namespaceMatch != null) {
        return namespaceMatch.group(1);
      }

      final RegExpMatch? appIdMatch = appIdRegex.firstMatch(content);
      if (appIdMatch != null) {
        return appIdMatch.group(1);
      }
    }

    // Try build.gradle (older format)
    final File buildGradle = File(
      p.join(projectPath, 'android', 'app', 'build.gradle'),
    );
    if (buildGradle.existsSync()) {
      final String content = await buildGradle.readAsString();
      // Look for: namespace "com.example.app" or applicationId "com.example.app"
      final RegExp namespaceRegex = RegExp(r'namespace\s+"([^"]+)"');
      final RegExp appIdRegex = RegExp(r'applicationId\s+"([^"]+)"');

      final RegExpMatch? namespaceMatch = namespaceRegex.firstMatch(content);
      if (namespaceMatch != null) {
        return namespaceMatch.group(1);
      }

      final RegExpMatch? appIdMatch = appIdRegex.firstMatch(content);
      if (appIdMatch != null) {
        return appIdMatch.group(1);
      }
    }

    // Fallback: try AndroidManifest.xml
    final File manifest = File(
      p.join(projectPath, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
    );
    if (manifest.existsSync()) {
      final String content = await manifest.readAsString();
      final RegExp packageRegex = RegExp(r'package="([^"]+)"');
      final RegExpMatch? match = packageRegex.firstMatch(content);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  /// Extract iOS bundle identifier from project.pbxproj or Info.plist
  Future<String?> _extractIosBundleId(String projectPath) async {
    // Try project.pbxproj
    final File pbxproj = File(
      p.join(projectPath, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
    );
    if (pbxproj.existsSync()) {
      final String content = await pbxproj.readAsString();
      // Look for: PRODUCT_BUNDLE_IDENTIFIER = com.example.app;
      final RegExp bundleIdRegex = RegExp(
        r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);',
      );
      final RegExpMatch? match = bundleIdRegex.firstMatch(content);
      if (match != null) {
        String bundleId = match.group(1)?.trim() ?? '';
        // Remove quotes if present
        bundleId = bundleId.replaceAll('"', '');
        // Skip if it's a variable reference like $(...)
        if (!bundleId.contains(r'$(')) {
          return bundleId;
        }
      }
    }

    return null;
  }

  /// Convert snake_case to camelCase for iOS bundle IDs
  /// iOS bundle IDs cannot contain underscores
  /// e.g., my_app_mobile -> myAppMobile
  String _convertToCamelCase(String input) {
    if (!input.contains('_')) return input;

    final List<String> parts = input.split('_');
    final StringBuffer result = StringBuffer(parts.first);

    for (int i = 1; i < parts.length; i++) {
      final String part = parts[i];
      if (part.isNotEmpty) {
        result.write(part[0].toUpperCase());
        if (part.length > 1) {
          result.write(part.substring(1));
        }
      }
    }

    return result.toString();
  }
}
