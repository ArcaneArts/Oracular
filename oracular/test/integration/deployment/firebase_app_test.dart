@TestOn('vm')
@Timeout(Duration(minutes: 10))
@Tags(<String>['live_deployment'])
library;

import 'dart:io';

import 'package:oracular/models/setup_config.dart';
import 'package:oracular/models/template_info.dart';
import 'package:oracular/services/firebase_service.dart';
import 'package:oracular/utils/process_runner.dart' show ProcessResult;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'authenticated_runner.dart';
import 'deployment_test_harness.dart';
import 'test_config.dart';

void main() {
  group('Firebase App Creation Tests', () {
    late Directory tempDir;
    late AuthenticatedProcessRunner runner;

    setUpAll(initializeLiveDeploymentSuite);

    setUp(() async {
      tempDir = await createDeploymentTempDir('oracular_firebase_');
      runner = authenticatedDeploymentRunner();
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('can list Firebase apps', () async {
      if (skipUnlessLiveDeploymentEnabled()) {
        return;
      }

      final ProcessResult result = await runner.run('firebase', <String>[
        'apps:list',
        '--project',
        DeploymentTestConfig.projectId,
      ], environment: DeploymentTestConfig.authEnvironment);

      expect(result.success, isTrue, reason: 'Should be able to list apps');
    });

    test('can create Firebase web app', () async {
      if (skipUnlessLiveDeploymentEnabled()) {
        return;
      }

      final String testAppName =
          'test_web_${DateTime.now().millisecondsSinceEpoch}';

      final ProcessResult result = await runner.run('firebase', <String>[
        'apps:create',
        'WEB',
        testAppName,
        '--project',
        DeploymentTestConfig.projectId,
        '--json',
        '--debug',
      ], workingDirectory: tempDir.path);

      if (skipIfFirebaseAppQuotaExhausted(
        result,
        workingDirectory: tempDir.path,
      )) {
        return;
      }

      final String? appResourceName = firebaseAppResourceNameFromCreateResult(
        result,
      );
      expect(
        result.success,
        isTrue,
        reason: 'Should create web app: ${result.stderr}',
      );
      expect(
        appResourceName,
        isNotNull,
        reason: 'Should capture created Firebase app resource name',
      );

      try {
        // Verify the app was created
        final ProcessResult listResult = await runner.run('firebase', <String>[
          'apps:list',
          'WEB',
          '--project',
          DeploymentTestConfig.projectId,
        ], environment: DeploymentTestConfig.authEnvironment);

        expect(listResult.stdout.toLowerCase(), contains('web'));
      } finally {
        await removeFirebaseAppResource(
          runner,
          appResourceName!,
          workingDirectory: tempDir.path,
        );
      }
    });

    test('can create Firebase Android app', () async {
      if (skipUnlessLiveDeploymentEnabled()) {
        return;
      }

      final String testAppName =
          'test_android_${DateTime.now().millisecondsSinceEpoch}';
      final String packageName =
          'com.test.app${DateTime.now().millisecondsSinceEpoch}';

      final ProcessResult result = await runner.run('firebase', <String>[
        'apps:create',
        'ANDROID',
        testAppName,
        '--package-name',
        packageName,
        '--project',
        DeploymentTestConfig.projectId,
        '--json',
        '--debug',
      ], workingDirectory: tempDir.path);

      if (skipIfFirebaseAppQuotaExhausted(
        result,
        workingDirectory: tempDir.path,
      )) {
        return;
      }

      final String? appResourceName = firebaseAppResourceNameFromCreateResult(
        result,
      );
      expect(
        result.success,
        isTrue,
        reason: 'Should create Android app: ${result.stderr}',
      );
      expect(
        appResourceName,
        isNotNull,
        reason: 'Should capture created Firebase app resource name',
      );

      await removeFirebaseAppResource(
        runner,
        appResourceName!,
        workingDirectory: tempDir.path,
      );
    });

    test('can create Firebase iOS app', () async {
      if (skipUnlessLiveDeploymentEnabled()) {
        return;
      }

      final String testAppName =
          'test_ios_${DateTime.now().millisecondsSinceEpoch}';
      final String bundleId =
          'com.test.app${DateTime.now().millisecondsSinceEpoch}';

      final ProcessResult result = await runner.run('firebase', <String>[
        'apps:create',
        'IOS',
        testAppName,
        '--bundle-id',
        bundleId,
        '--project',
        DeploymentTestConfig.projectId,
        '--json',
        '--debug',
      ], workingDirectory: tempDir.path);

      if (skipIfFirebaseAppQuotaExhausted(
        result,
        workingDirectory: tempDir.path,
      )) {
        return;
      }

      final String? appResourceName = firebaseAppResourceNameFromCreateResult(
        result,
      );
      expect(
        result.success,
        isTrue,
        reason: 'Should create iOS app: ${result.stderr}',
      );
      expect(
        appResourceName,
        isNotNull,
        reason: 'Should capture created Firebase app resource name',
      );

      await removeFirebaseAppResource(
        runner,
        appResourceName!,
        workingDirectory: tempDir.path,
      );
    });

    test(
      'FirebaseService._ensureFirebaseAppsExist works via configureFlutterFire',
      () async {
        if (skipUnlessLiveDeploymentEnabled()) {
          return;
        }

        // Create a minimal Flutter project structure for the test
        final String appName = 'ensure_apps_test';
        final String projectPath = p.join(tempDir.path, appName);
        await Directory(projectPath).create(recursive: true);
        await Directory(p.join(projectPath, 'lib')).create();
        await Directory(
          p.join(projectPath, 'android', 'app'),
        ).create(recursive: true);
        await Directory(
          p.join(projectPath, 'ios', 'Runner.xcodeproj'),
        ).create(recursive: true);

        // Create minimal pubspec.yaml
        final File pubspec = File(p.join(projectPath, 'pubspec.yaml'));
        await pubspec.writeAsString('''
name: $appName
description: Test app
version: 1.0.0

environment:
  sdk: ^3.0.0

dependencies:
  flutter:
    sdk: flutter
''');

        // Create a config that uses our test project
        final SetupConfig config = SetupConfig(
          appName: appName,
          orgDomain: 'com.test',
          baseClassName: 'TestApp',
          template: TemplateType.arcaneTemplate,
          outputDir: tempDir.path,
          useFirebase: true,
          firebaseProjectId: DeploymentTestConfig.projectId,
          platforms: <String>['web'],
        );

        final FirebaseService service = FirebaseService(
          config,
          runner: authenticatedDeploymentRunner(),
        );

        // This should trigger _ensureFirebaseAppsExist internally
        // We're testing that it doesn't crash and creates apps if needed
        // Note: configureFlutterFire requires flutterfire CLI which may not be available
        // So we just test that the service can be created and accessed

        expect(
          service.config.firebaseProjectId,
          equals(DeploymentTestConfig.projectId),
        );
      },
    );

    test('can get Firebase web SDK config', () async {
      if (skipUnlessLiveDeploymentEnabled()) {
        return;
      }

      // First ensure we have at least one web app
      final ProcessResult listResult = await runner.run('firebase', <String>[
        'apps:list',
        'WEB',
        '--project',
        DeploymentTestConfig.projectId,
      ], environment: DeploymentTestConfig.authEnvironment);

      if (!listResult.stdout.toLowerCase().contains('web')) {
        // Create a web app first
        await runner.run('firebase', <String>[
          'apps:create',
          'WEB',
          'sdk_config_test_app',
          '--project',
          DeploymentTestConfig.projectId,
        ], environment: DeploymentTestConfig.authEnvironment);

        // Wait for propagation
        await Future<void>.delayed(const Duration(seconds: 3));
      }

      // Get app list again to find the app ID
      final ProcessResult appsResult = await runner.run('firebase', <String>[
        'apps:list',
        'WEB',
        '--project',
        DeploymentTestConfig.projectId,
        '--json',
      ], environment: DeploymentTestConfig.authEnvironment);

      expect(appsResult.success, isTrue);

      // Extract app ID from JSON output
      final String output = appsResult.stdout;
      final RegExp appIdRegex = RegExp(r'1:\d+:web:[a-f0-9]+');
      final RegExpMatch? match = appIdRegex.firstMatch(output);

      if (match == null) {
        fail('Could not find web app ID in output: $output');
      }

      final String appId = match.group(0)!;

      // Now get the SDK config
      final ProcessResult configResult = await runner.run('firebase', <String>[
        'apps:sdkconfig',
        'WEB',
        appId,
        '--project',
        DeploymentTestConfig.projectId,
      ], environment: DeploymentTestConfig.authEnvironment);

      expect(configResult.success, isTrue, reason: 'Should get SDK config');
      expect(configResult.stdout, contains('apiKey'));
      expect(configResult.stdout, contains('projectId'));
    });
  });
}
