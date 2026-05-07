import 'dart:convert';
import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../models/setup_config.dart';
import '../models/template_info.dart';
import '../utils/process_runner.dart' show ProcessResult, ProcessRunner;

/// Service for Firebase operations
class FirebaseService {
  static const String _firebaseJsSdkVersion = '12.12.1';

  final SetupConfig config;
  final ProcessRunner _runner;

  FirebaseService(this.config, {ProcessRunner? runner})
    : _runner = runner ?? ProcessRunner();

  String? get _resolvedServiceAccountPath {
    final Set<String> candidates = <String>{};
    final String? configuredPath = config.serviceAccountKeyPath;

    if (configuredPath != null && configuredPath.trim().isNotEmpty) {
      candidates.add(
        p.isAbsolute(configuredPath)
            ? configuredPath
            : p.normalize(p.join(config.outputDir, configuredPath)),
      );
    }

    // Conventional project-level locations.
    candidates.add(
      p.normalize(p.join(config.outputDir, 'service-account.json')),
    );
    candidates.add(
      p.normalize(
        p.join(config.outputDir, 'config', 'keys', 'service-account.json'),
      ),
    );

    // Fallback for running Oracular from a workspace with a root key file.
    candidates.add(
      p.normalize(p.join(Directory.current.path, 'service-account.json')),
    );

    for (final String candidate in candidates) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    return null;
  }

  Map<String, String>? get _authEnvironment {
    final String? serviceAccountPath = _resolvedServiceAccountPath;
    if (serviceAccountPath == null) {
      return null;
    }
    return <String, String>{
      'GOOGLE_APPLICATION_CREDENTIALS': serviceAccountPath,
    };
  }

  String? _requireFirebaseProjectId() {
    if (config.firebaseProjectId == null || config.firebaseProjectId!.isEmpty) {
      error('Firebase project ID not set');
      return null;
    }
    return config.firebaseProjectId!;
  }

  /// Strip ANSI escape sequences (color codes, etc.) from a string.
  static String _stripAnsi(String input) {
    return input.replaceAll(RegExp(r'\x1B\[[0-9;]*[a-zA-Z]'), '');
  }

  /// Extract the JSON payload from a Firebase CLI response. Firebase prints
  /// a spinner line above the JSON body, so we trim everything up to the first
  /// `{` character and parse from there. Returns `null` if no JSON object
  /// could be parsed.
  static Map<String, dynamic>? _parseFirebaseJson(String stdout) {
    final String cleaned = _stripAnsi(stdout);
    final int braceIndex = cleaned.indexOf('{');
    if (braceIndex < 0) {
      return null;
    }
    final String jsonText = cleaned.substring(braceIndex);
    try {
      final dynamic decoded = jsonDecode(jsonText);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Pull the human readable error message out of a failed firebase --json
  /// response. Falls back to stdout/stderr when the JSON envelope is missing.
  static String _firebaseError(ProcessResult result) {
    final Map<String, dynamic>? parsed = _parseFirebaseJson(result.stdout);
    if (parsed != null) {
      final dynamic err = parsed['error'];
      if (err is String && err.trim().isNotEmpty) {
        return err.trim();
      }
      if (err is Map && err['message'] is String) {
        return (err['message'] as String).trim();
      }
    }

    final String stderr = _stripAnsi(result.stderr).trim();
    if (stderr.isNotEmpty) {
      return stderr;
    }

    final String stdout = _stripAnsi(result.stdout).trim();
    if (stdout.isNotEmpty) {
      return stdout;
    }

    return 'Firebase command failed with exit code ${result.exitCode}';
  }

  /// Public accessor for tests so they can verify error extraction logic.
  static String firebaseErrorForTest(ProcessResult result) =>
      _firebaseError(result);

  /// Login to Firebase CLI
  Future<bool> login() async {
    final Map<String, String>? authEnvironment = _authEnvironment;
    if (authEnvironment != null) {
      info('Using configured service account for Firebase CLI authentication.');
      final ProcessResult result = await _runner.run('firebase', <String>[
        'projects:list',
      ], environment: authEnvironment);
      return result.success;
    }

    info('Logging in to Firebase...');

    final int result = await _runner.runStreaming('firebase', <String>[
      'login',
    ], environment: authEnvironment);
    return result == 0;
  }

  /// Login to gcloud
  Future<bool> gcloudLogin() async {
    final String? serviceAccountPath = _resolvedServiceAccountPath;
    if (serviceAccountPath != null) {
      info('Authenticating gcloud with configured service account key...');
      final List<String> args = <String>[
        'auth',
        'activate-service-account',
        '--key-file',
        serviceAccountPath,
      ];

      final String? projectId = _requireFirebaseProjectId();
      if (projectId != null) {
        args.addAll(<String>['--project', projectId]);
      }

      final ProcessResult result = await _runner.run('gcloud', args);
      return result.success;
    }

    info('Logging in to Google Cloud...');

    final int result = await _runner.runStreaming('gcloud', <String>[
      'auth',
      'login',
    ]);
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

    // Jaspr templates: configure Firebase JS SDK in index.html
    if (config.template.isJasprApp) {
      return await _configureFirebaseJsSdk();
    }

    // Flutter templates: use flutterfire configure
    return await _runFlutterFireConfigure(
      p.join(config.outputDir, config.appName),
      config.platforms,
    );
  }

  /// List Firebase apps using JSON output. Returns the parsed list, or null on
  /// failure (with a logged warning describing the underlying error).
  Future<List<Map<String, dynamic>>?> _listFirebaseApps({
    required String projectId,
    String? platform,
  }) async {
    final List<String> args = <String>[
      'apps:list',
      if (platform != null) platform,
      '--project',
      projectId,
      '--json',
    ];

    verbose('  Running: firebase ${args.join(' ')}');

    final ProcessResult result = await _runner.run(
      'firebase',
      args,
      environment: _authEnvironment,
    );

    final Map<String, dynamic>? body = _parseFirebaseJson(result.stdout);
    if (body == null) {
      warn(
        'Could not parse firebase apps:list output. '
        'stderr: ${_stripAnsi(result.stderr).trim()}',
      );
      return null;
    }

    if (body['status'] != 'success') {
      warn(
        'Firebase apps:list failed: ${body['error'] ?? 'unknown error'}',
      );
      return null;
    }

    final dynamic resultData = body['result'];
    if (resultData is! List) {
      return <Map<String, dynamic>>[];
    }

    return resultData
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  /// Create a Firebase app using --json so we get structured success/error
  /// responses instead of fighting with spinner output.
  Future<Map<String, dynamic>?> _createFirebaseApp({
    required String projectId,
    required String platform,
    required String displayName,
    String? androidPackage,
    String? iosBundleId,
  }) async {
    final List<String> args = <String>[
      'apps:create',
      platform.toUpperCase(),
      displayName,
      '--project',
      projectId,
      '--json',
    ];

    if (platform.toLowerCase() == 'android' && androidPackage != null) {
      args.addAll(<String>['--package-name', androidPackage]);
    }
    if (platform.toLowerCase() == 'ios' && iosBundleId != null) {
      args.addAll(<String>['--bundle-id', iosBundleId]);
    }

    verbose('  Running: firebase ${args.join(' ')}');

    final ProcessResult result = await _runner.run(
      'firebase',
      args,
      environment: _authEnvironment,
    );

    final Map<String, dynamic>? body = _parseFirebaseJson(result.stdout);
    if (body == null) {
      warn(
        'Could not parse firebase apps:create output. '
        'stderr: ${_stripAnsi(result.stderr).trim()}',
      );
      return null;
    }

    if (body['status'] != 'success') {
      final dynamic err = body['error'];
      warn(
        'Firebase $platform app creation failed: ${err ?? 'unknown error'}',
      );
      return null;
    }

    final dynamic resultData = body['result'];
    if (resultData is Map<String, dynamic>) {
      return resultData;
    }
    return null;
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
    final String? projectId = _requireFirebaseProjectId();
    if (projectId == null) return;

    // Use provided display name or default to config.appName
    final String displayName = appDisplayName ?? config.appName;

    verbose('  Checking Firebase apps for project: $projectId');
    verbose('  App display name: $displayName');
    verbose('  Android package: $androidPackage');
    verbose('  iOS bundle ID: $iosBundleId');

    final List<Map<String, dynamic>>? existing = await _listFirebaseApps(
      projectId: projectId,
    );
    if (existing == null) {
      warn(
        '  Skipping app creation because the project app list could not be retrieved.',
      );
      return;
    }

    String platformOf(Map<String, dynamic> app) {
      final dynamic platform = app['platform'];
      return platform is String ? platform.toUpperCase() : '';
    }

    String? packageOf(Map<String, dynamic> app) {
      final dynamic value = app['packageName'];
      return value is String ? value : null;
    }

    String? bundleOf(Map<String, dynamic> app) {
      final dynamic value = app['bundleId'];
      return value is String ? value : null;
    }

    for (final String platform in platforms) {
      final String upper = platform.toUpperCase();
      bool appExists = false;

      if (upper == 'ANDROID') {
        appExists = existing.any(
          (Map<String, dynamic> app) =>
              platformOf(app) == 'ANDROID' &&
              packageOf(app) == androidPackage,
        );
      } else if (upper == 'IOS') {
        appExists = existing.any(
          (Map<String, dynamic> app) =>
              platformOf(app) == 'IOS' && bundleOf(app) == iosBundleId,
        );
      } else if (upper == 'WEB') {
        appExists = existing.any(
          (Map<String, dynamic> app) => platformOf(app) == 'WEB',
        );
      }

      if (appExists) {
        verbose('  Firebase $platform app already exists');
        continue;
      }

      info('Creating Firebase $platform app...');

      final Map<String, dynamic>? created = await _createFirebaseApp(
        projectId: projectId,
        platform: platform,
        displayName: '${displayName}_$platform',
        androidPackage: upper == 'ANDROID' ? androidPackage : null,
        iosBundleId: upper == 'IOS' ? iosBundleId : null,
      );

      if (created != null) {
        success('  Created Firebase $platform app');
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
      error(
        'This does not appear to be a Flutter project (no flutter: in pubspec.yaml)',
      );
      verbose('  pubspec.yaml content preview:');
      verbose(
        '  ${pubspecContent.substring(0, pubspecContent.length > 200 ? 200 : pubspecContent.length)}...',
      );
      return false;
    }
    verbose('  Flutter SDK dependency found');

    // Try to extract package identifiers to avoid interactive prompts
    final String? androidPackage = await _extractAndroidPackageName(
      projectPath,
    );
    final String? iosBundleId = await _extractIosBundleId(projectPath);

    // Construct default identifiers if not extracted
    // Use subprojectName for subprojects (e.g., my_app_mobile)
    final String projectName = subprojectName ?? config.appName;
    final String defaultAndroidPackage = '${config.orgDomain}.$projectName';
    // iOS bundle IDs cannot contain underscores - convert to camelCase
    final String iosSafeProjectName = _convertToCamelCase(projectName);
    final String defaultIosBundleId = '${config.orgDomain}.$iosSafeProjectName';
    final String effectiveAndroidPackage =
        androidPackage ?? defaultAndroidPackage;
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
      environment: _authEnvironment,
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
    final String? projectId = _requireFirebaseProjectId();
    if (projectId == null) {
      return false;
    }

    final ProcessResult? result = await _runner.runWithRetry(
      'firebase',
      <String>[
        'deploy',
        '--only',
        'firestore:rules,firestore:indexes',
        '--project',
        projectId,
      ],
      workingDirectory: config.outputDir,
      environment: _authEnvironment,
      operationName: 'Deploy Firestore',
    );

    return result != null && result.success;
  }

  bool _isStorageNotInitialized(String output) {
    final String lower = output.toLowerCase();
    return lower.contains('firebase storage has not been set up');
  }

  /// Deploy Storage rules
  Future<bool> deployStorage({bool allowNotInitialized = false}) async {
    info('Deploying Storage rules...');
    final String? projectId = _requireFirebaseProjectId();
    if (projectId == null) {
      return false;
    }

    final List<String> args = <String>[
      'deploy',
      '--only',
      'storage',
      '--project',
      projectId,
    ];

    final ProcessResult firstAttempt = await _runner.run(
      'firebase',
      args,
      workingDirectory: config.outputDir,
      environment: _authEnvironment,
    );

    if (firstAttempt.success) {
      return true;
    }

    final String firstOutput = '${firstAttempt.stdout}\n${firstAttempt.stderr}'
        .trim();
    if (_isStorageNotInitialized(firstOutput)) {
      warn(
        'Firebase Storage is not initialized for project $projectId. '
        'Open https://console.firebase.google.com/project/$projectId/storage and click "Get Started".',
      );
      return allowNotInitialized;
    }

    final ProcessResult? result = await _runner.runWithRetry(
      'firebase',
      args,
      workingDirectory: config.outputDir,
      environment: _authEnvironment,
      operationName: 'Deploy Storage',
    );

    return result != null && result.success;
  }

  /// Build web app
  Future<bool> buildWeb() async {
    if (!supportsWebHosting()) {
      error(
        'Web hosting is not available because this project was created without web support.',
      );
      return false;
    }

    // Determine project path based on template type
    final String projectPath = config.template.isJasprApp
        ? p.join(config.outputDir, config.webPackageName)
        : p.join(config.outputDir, config.appName);

    info('Building web app...');

    // Jaspr templates: use jaspr build
    if (config.template.isJasprApp) {
      final ProcessResult? result = await _runner.runWithRetry(
        'jaspr',
        <String>['build'],
        workingDirectory: projectPath,
        operationName: 'Jaspr build',
      );
      return result != null && result.success;
    }

    final Directory webDir = Directory(p.join(projectPath, 'web'));
    if (!webDir.existsSync()) {
      error('Web platform files were not found in: ${webDir.path}');
      info('Enable web support in the app directory with:');
      info('  flutter create --platforms=web .');
      return false;
    }

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
    final String? projectId = _requireFirebaseProjectId();
    if (projectId == null) {
      return false;
    }

    final ProcessResult? result = await _runner.runWithRetry(
      'firebase',
      <String>['deploy', '--only', 'hosting:release', '--project', projectId],
      workingDirectory: config.outputDir,
      environment: _authEnvironment,
      operationName: 'Deploy Hosting (release)',
    );

    if (result != null && result.success) {
      return true;
    }

    // Fallback for projects that only use a default hosting target.
    warn(
      'Release hosting target deploy failed; retrying default hosting deploy.',
    );
    final ProcessResult? fallbackResult = await _runner.runWithRetry(
      'firebase',
      <String>['deploy', '--only', 'hosting', '--project', projectId],
      workingDirectory: config.outputDir,
      environment: _authEnvironment,
      operationName: 'Deploy Hosting (default)',
    );

    return fallbackResult != null && fallbackResult.success;
  }

  /// Deploy to Firebase Hosting (beta target)
  Future<bool> deployHostingBeta() async {
    info('Deploying to Firebase Hosting (beta)...');
    final String? projectId = _requireFirebaseProjectId();
    if (projectId == null) {
      return false;
    }

    final ProcessResult? result = await _runner.runWithRetry(
      'firebase',
      <String>['deploy', '--only', 'hosting:beta', '--project', projectId],
      workingDirectory: config.outputDir,
      environment: _authEnvironment,
      operationName: 'Deploy Hosting (beta)',
    );

    return result != null && result.success;
  }

  /// Deploy all Firebase resources
  Future<bool> deployAll() async {
    info('Deploying all Firebase resources...');
    bool allSucceeded = true;

    // Deploy in order
    if (!await deployFirestore()) {
      warn('Firestore deployment failed');
      allSucceeded = false;
    }

    if (!await deployStorage(allowNotInitialized: true)) {
      warn('Storage deployment failed');
      allSucceeded = false;
    }

    if (supportsWebHosting()) {
      if (!await buildWeb()) {
        error('Web build failed');
        return false;
      }

      if (!await deployHostingRelease()) {
        warn('Hosting deployment failed');
        allSucceeded = false;
      }
    } else {
      warn('Skipping Hosting deploy because web platform is not enabled.');
    }

    if (allSucceeded) {
      success('Firebase deployment complete');
    } else {
      warn('Firebase deployment completed with failures.');
    }
    return allSucceeded;
  }

  /// Whether this project supports web hosting deployment.
  bool supportsWebHosting() {
    return config.template.isJasprApp ||
        (config.template.isFlutterApp && config.platforms.contains('web'));
  }

  /// Enable Google Cloud APIs needed for deployment
  Future<bool> enableGoogleApis() async {
    if (config.firebaseProjectId == null) {
      error('Firebase project ID not set');
      return false;
    }

    info('Enabling Google Cloud APIs...');

    bool allOk = true;

    // Enable Artifact Registry
    ProcessResult result = await _runner.run('gcloud', <String>[
      'services',
      'enable',
      'artifactregistry.googleapis.com',
      '--project',
      config.firebaseProjectId!,
    ], environment: _authEnvironment);

    if (!result.success) {
      warn(
        'Failed to enable Artifact Registry API: ${_stripAnsi(result.stderr).trim()}',
      );
      allOk = false;
    }

    // Enable Cloud Run
    result = await _runner.run('gcloud', <String>[
      'services',
      'enable',
      'run.googleapis.com',
      '--project',
      config.firebaseProjectId!,
    ], environment: _authEnvironment);

    if (!result.success) {
      warn(
        'Failed to enable Cloud Run API: ${_stripAnsi(result.stderr).trim()}',
      );
      allOk = false;
    }

    return allOk;
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
      p.join(
        projectPath,
        'android',
        'app',
        'src',
        'main',
        'AndroidManifest.xml',
      ),
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

  /// Configure Firebase JS SDK for Jaspr web apps
  /// Creates a Firebase web app and updates index.html with the config
  Future<bool> _configureFirebaseJsSdk() async {
    info('Configuring Firebase JS SDK for Jaspr...');

    final String? projectId = _requireFirebaseProjectId();
    if (projectId == null) {
      return false;
    }

    final String projectPath = p.join(config.outputDir, config.webPackageName);
    final String indexPath = p.join(projectPath, 'web', 'index.html');

    // Check if index.html exists
    final File indexFile = File(indexPath);
    if (!indexFile.existsSync()) {
      error('index.html not found at: $indexPath');
      info('Expected the Jaspr web project at: $projectPath');
      return false;
    }

    // Find or create the Firebase web app for this project
    final String desiredAppName = '${config.webPackageName}_web';
    final Map<String, dynamic>? webApp = await _findOrCreateWebApp(
      projectId: projectId,
      desiredDisplayName: desiredAppName,
    );

    if (webApp == null) {
      // Errors already logged
      return false;
    }

    final dynamic appIdRaw = webApp['appId'];
    if (appIdRaw is! String || appIdRaw.isEmpty) {
      error('Firebase web app missing appId in response');
      verbose('  webApp payload: ${jsonEncode(webApp)}');
      return false;
    }

    // Get the Firebase web SDK config using the JSON output of apps:sdkconfig
    final Map<String, String>? firebaseConfig = await _getFirebaseWebConfig(
      projectId: projectId,
      appId: appIdRaw,
    );
    if (firebaseConfig == null) {
      error('Failed to get Firebase web config');
      return false;
    }

    // Update index.html with the Firebase config
    String indexContent = await indexFile.readAsString();

    final String firebaseScript =
        '''
  <script src="https://www.gstatic.com/firebasejs/$_firebaseJsSdkVersion/firebase-app-compat.js"></script>
  <script src="https://www.gstatic.com/firebasejs/$_firebaseJsSdkVersion/firebase-auth-compat.js"></script>
  <script src="https://www.gstatic.com/firebasejs/$_firebaseJsSdkVersion/firebase-firestore-compat.js"></script>
  <script>
    const firebaseConfig = {
      apiKey: "${firebaseConfig['apiKey']}",
      authDomain: "${firebaseConfig['authDomain']}",
      projectId: "${firebaseConfig['projectId']}",
      storageBucket: "${firebaseConfig['storageBucket']}",
      messagingSenderId: "${firebaseConfig['messagingSenderId']}",
      appId: "${firebaseConfig['appId']}"
    };
    firebase.initializeApp(firebaseConfig);
  </script>''';

    // Replace any existing Firebase block (commented or active) or insert it.
    //
    // Templates currently emit a block shaped like:
    //   <!-- Firebase SDKs (uncomment if using Firebase) -->
    //   <!--
    //   <script src="..."></script>
    //   ...
    //   firebase.initializeApp(firebaseConfig);
    //   </script>
    //   -->
    //
    // The regex below tolerates either a single-comment header followed by a
    // multi-line `<!-- ... -->` body, or a single comment that contains the
    // whole block.
    final RegExp commentedBlock = RegExp(
      r'<!--\s*Firebase SDKs.*?-->\s*(?:<!--\s*[\s\S]*?-->|<!--\s*[\s\S]*?-->)',
      dotAll: true,
    );
    // Older templates may have used an empty `<!-- -->` terminator instead.
    final RegExp legacyCommentedBlock = RegExp(
      r'<!--\s*Firebase SDKs.*?-->.*?<!--\s*-->',
      dotAll: true,
    );
    final RegExp activeBlock = RegExp(
      r'<script src="https://www\.gstatic\.com/firebasejs/.*?firebase\.initializeApp\(firebaseConfig\);\s*</script>',
      dotAll: true,
    );

    if (commentedBlock.hasMatch(indexContent)) {
      indexContent = indexContent.replaceFirst(commentedBlock, firebaseScript);
    } else if (legacyCommentedBlock.hasMatch(indexContent)) {
      indexContent = indexContent.replaceFirst(
        legacyCommentedBlock,
        firebaseScript,
      );
    } else if (activeBlock.hasMatch(indexContent)) {
      indexContent = indexContent.replaceFirst(activeBlock, firebaseScript);
    } else {
      indexContent = indexContent.replaceFirst(
        '</head>',
        '$firebaseScript\n</head>',
      );
    }

    await indexFile.writeAsString(indexContent);
    success('Firebase JS SDK configured in index.html');

    final String apiKey = firebaseConfig['apiKey'] ?? '';
    final String apiKeyPreview = apiKey.length > 10
        ? '${apiKey.substring(0, 10)}...'
        : apiKey;
    verbose('  API Key: $apiKeyPreview');
    verbose('  Project ID: ${firebaseConfig['projectId']}');
    return true;
  }

  /// Either return the first existing web app whose displayName matches
  /// [desiredDisplayName], the first web app of any name, or create a new one.
  Future<Map<String, dynamic>?> _findOrCreateWebApp({
    required String projectId,
    required String desiredDisplayName,
  }) async {
    verbose('Checking if Firebase web app exists...');

    final List<Map<String, dynamic>>? existing = await _listFirebaseApps(
      projectId: projectId,
      platform: 'WEB',
    );

    if (existing == null) {
      error(
        'Failed to list Firebase web apps for project $projectId. '
        'Verify the project exists and your service account has Firebase access.',
      );
      return null;
    }

    if (existing.isNotEmpty) {
      Map<String, dynamic>? matchByName;
      for (final Map<String, dynamic> app in existing) {
        if (app['displayName'] == desiredDisplayName) {
          matchByName = app;
          break;
        }
      }
      if (matchByName != null) {
        verbose(
          'Reusing existing Firebase web app: $desiredDisplayName (${matchByName['appId']})',
        );
        return matchByName;
      }

      final Map<String, dynamic> firstApp = existing.first;
      verbose(
        'Reusing existing Firebase web app: ${firstApp['displayName']} (${firstApp['appId']})',
      );
      return firstApp;
    }

    info('Creating Firebase web app: $desiredDisplayName');
    final Map<String, dynamic>? created = await _createFirebaseApp(
      projectId: projectId,
      platform: 'WEB',
      displayName: desiredDisplayName,
    );

    if (created == null) {
      error(
        'Could not create a Firebase web app. '
        'Check that the Firebase project exists and the service account has '
        '"Firebase Admin" or equivalent permissions to create apps.',
      );
      return null;
    }

    success('Created Firebase web app: $desiredDisplayName');
    // Wait for propagation
    await Future<void>.delayed(const Duration(seconds: 2));
    return created;
  }

  /// Get Firebase web SDK config from Firebase CLI using --json output.
  Future<Map<String, String>?> _getFirebaseWebConfig({
    required String projectId,
    required String appId,
  }) async {
    verbose('Getting Firebase web SDK config for app: $appId');

    final ProcessResult result = await _runner.run('firebase', <String>[
      'apps:sdkconfig',
      'WEB',
      appId,
      '--project',
      projectId,
      '--json',
    ], environment: _authEnvironment);

    final Map<String, dynamic>? body = _parseFirebaseJson(result.stdout);
    if (body == null) {
      error(
        'Failed to parse firebase apps:sdkconfig output. '
        'stderr: ${_stripAnsi(result.stderr).trim()}',
      );
      return null;
    }

    if (body['status'] != 'success') {
      error(
        'Failed to get Firebase SDK config: ${body['error'] ?? 'unknown error'}',
      );
      return null;
    }

    final dynamic resultData = body['result'];
    if (resultData is! Map<String, dynamic>) {
      error('apps:sdkconfig returned unexpected payload');
      return null;
    }

    final dynamic sdkConfig = resultData['sdkConfig'];
    Map<String, dynamic>? sdkValues;
    if (sdkConfig is Map<String, dynamic>) {
      sdkValues = sdkConfig;
    } else if (resultData['fileContents'] is String) {
      try {
        final dynamic decoded = jsonDecode(resultData['fileContents'] as String);
        if (decoded is Map<String, dynamic>) {
          sdkValues = decoded;
        }
      } catch (_) {
        // Fall through
      }
    }

    if (sdkValues == null) {
      error('Could not locate sdkConfig payload from Firebase CLI');
      return null;
    }

    final Map<String, String> firebaseConfig = <String, String>{};
    for (final String key in const <String>[
      'apiKey',
      'authDomain',
      'projectId',
      'storageBucket',
      'messagingSenderId',
      'appId',
      'databaseURL',
    ]) {
      final dynamic value = sdkValues[key];
      if (value is String && value.isNotEmpty) {
        firebaseConfig[key] = value;
      }
    }

    if (firebaseConfig.isEmpty) {
      error('Firebase SDK config response was missing all expected fields');
      return null;
    }

    verbose('Parsed Firebase config with ${firebaseConfig.length} values');
    return firebaseConfig;
  }
}
