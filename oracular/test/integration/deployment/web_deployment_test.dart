@TestOn('vm')
@Timeout(Duration(minutes: 15))
import 'dart:io';

import 'package:oracular/models/setup_config.dart';
import 'package:oracular/models/template_info.dart';
import 'package:oracular/services/firebase_service.dart';
import 'package:oracular/services/template_copier.dart';
import 'package:oracular/utils/process_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_config.dart';

void main() {
  group('Web Build and Deployment Tests', () {
    late Directory tempDir;
    late ProcessRunner runner;

    setUpAll(() async {
      if (!DeploymentTestConfig.canRunDeploymentTests) {
        return;
      }

      // Initialize gcloud for Cloud API tests
      await DeploymentTestConfig.initializeGcloud();
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('oracular_deploy_');
      runner = _AuthenticatedProcessRunner(
        environment: DeploymentTestConfig.authEnvironment,
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Flutter Web Build', () {
      test(
        'can build Flutter web for arcane_app template',
        () async {
          if (!DeploymentTestConfig.canRunDeploymentTests) {
            markTestSkipped(DeploymentTestConfig.skipMessage);
            return;
          }

          final String appName = 'flutter_build_test';
          final SetupConfig config = SetupConfig(
            appName: appName,
            orgDomain: 'com.test',
            baseClassName: 'FlutterBuildTest',
            template: TemplateType.arcaneTemplate,
            outputDir: tempDir.path,
            useFirebase: true,
            firebaseProjectId: DeploymentTestConfig.projectId,
            platforms: <String>['web'],
          );

          // Copy template
          final String templatesPath = _getTemplatesPath();
          final TemplateCopier copier = TemplateCopier.withPath(config, templatesPath);
          await copier.copyAppTemplate();

          final String projectPath = p.join(tempDir.path, appName);

          // Run flutter pub get
          ProcessResult pubResult = await runner.run(
            'flutter',
            <String>['pub', 'get'],
            workingDirectory: projectPath,
          );
          expect(pubResult.exitCode, equals(0), reason: 'pub get should succeed');

          // Build web
          ProcessResult buildResult = await runner.run(
            'flutter',
            <String>['build', 'web', '--release'],
            workingDirectory: projectPath,
          );

          expect(
            buildResult.exitCode,
            equals(0),
            reason: 'Flutter web build should succeed:\n${buildResult.stderr}',
          );

          // Verify build output exists
          final Directory buildDir = Directory(p.join(projectPath, 'build', 'web'));
          expect(buildDir.existsSync(), isTrue, reason: 'Build output should exist');

          final File indexHtml = File(p.join(buildDir.path, 'index.html'));
          expect(indexHtml.existsSync(), isTrue, reason: 'index.html should exist');
        },
        timeout: const Timeout(Duration(minutes: 10)),
      );

      test(
        'can build Flutter web for arcane_beamer_app template',
        () async {
          if (!DeploymentTestConfig.canRunDeploymentTests) {
            markTestSkipped(DeploymentTestConfig.skipMessage);
            return;
          }

          final String appName = 'beamer_build_test';
          final SetupConfig config = SetupConfig(
            appName: appName,
            orgDomain: 'com.test',
            baseClassName: 'BeamerBuildTest',
            template: TemplateType.arcaneBeamer,
            outputDir: tempDir.path,
            useFirebase: true,
            firebaseProjectId: DeploymentTestConfig.projectId,
            platforms: <String>['web'],
          );

          // Copy template
          final String templatesPath = _getTemplatesPath();
          final TemplateCopier copier = TemplateCopier.withPath(config, templatesPath);
          await copier.copyAppTemplate();

          final String projectPath = p.join(tempDir.path, appName);

          // Run flutter pub get
          ProcessResult pubResult = await runner.run(
            'flutter',
            <String>['pub', 'get'],
            workingDirectory: projectPath,
          );
          expect(pubResult.exitCode, equals(0), reason: 'pub get should succeed');

          // Build web
          ProcessResult buildResult = await runner.run(
            'flutter',
            <String>['build', 'web', '--release'],
            workingDirectory: projectPath,
          );

          expect(
            buildResult.exitCode,
            equals(0),
            reason: 'Flutter web build should succeed:\n${buildResult.stderr}',
          );

          // Verify build output
          final Directory buildDir = Directory(p.join(projectPath, 'build', 'web'));
          expect(buildDir.existsSync(), isTrue);
        },
        timeout: const Timeout(Duration(minutes: 10)),
      );
    });

    group('Jaspr Web Build', () {
      test(
        'can build Jaspr web for arcane_jaspr_app template',
        () async {
          if (!DeploymentTestConfig.canRunDeploymentTests) {
            markTestSkipped(DeploymentTestConfig.skipMessage);
            return;
          }

          final String appName = 'jaspr_build_test';
          final SetupConfig config = SetupConfig(
            appName: appName,
            orgDomain: 'com.test',
            baseClassName: 'JasprBuildTest',
            template: TemplateType.arcaneJaspr,
            outputDir: tempDir.path,
            useFirebase: true,
            firebaseProjectId: DeploymentTestConfig.projectId,
          );

          // Copy template
          final String templatesPath = _getTemplatesPath();
          final TemplateCopier copier = TemplateCopier.withPath(config, templatesPath);
          await copier.copyAppTemplate();

          // Jaspr uses webPackageName
          final String projectPath = p.join(tempDir.path, config.webPackageName);

          // Run dart pub get
          ProcessResult pubResult = await runner.run(
            'dart',
            <String>['pub', 'get'],
            workingDirectory: projectPath,
          );
          expect(pubResult.exitCode, equals(0), reason: 'pub get should succeed');

          // Build with jaspr
          ProcessResult buildResult = await runner.run(
            'jaspr',
            <String>['build'],
            workingDirectory: projectPath,
          );

          expect(
            buildResult.exitCode,
            equals(0),
            reason: 'Jaspr build should succeed:\n${buildResult.stderr}',
          );

          // Verify build output exists
          final Directory buildDir = Directory(p.join(projectPath, 'build', 'jaspr'));
          expect(buildDir.existsSync(), isTrue, reason: 'Jaspr build output should exist');
        },
        timeout: const Timeout(Duration(minutes: 10)),
      );
    });

    group('Firebase Hosting Deployment', () {
      test(
        'can deploy Flutter web app to Firebase Hosting',
        () async {
          if (!DeploymentTestConfig.canRunDeploymentTests) {
            markTestSkipped(DeploymentTestConfig.skipMessage);
            return;
          }

          final String appName = 'deploy_flutter_test';
          final SetupConfig config = SetupConfig(
            appName: appName,
            orgDomain: 'com.test',
            baseClassName: 'DeployFlutterTest',
            template: TemplateType.arcaneTemplate,
            outputDir: tempDir.path,
            useFirebase: true,
            firebaseProjectId: DeploymentTestConfig.projectId,
            platforms: <String>['web'],
          );

          // Copy template
          final String templatesPath = _getTemplatesPath();
          final TemplateCopier copier = TemplateCopier.withPath(config, templatesPath);
          await copier.copyAppTemplate();

          final String projectPath = p.join(tempDir.path, appName);

          // Run flutter pub get and build
          await runner.run(
            'flutter',
            <String>['pub', 'get'],
            workingDirectory: projectPath,
          );

          ProcessResult buildResult = await runner.run(
            'flutter',
            <String>['build', 'web', '--release'],
            workingDirectory: projectPath,
          );
          expect(buildResult.exitCode, equals(0), reason: 'Build should succeed');

          // Create firebase.json for hosting
          final File firebaseJson = File(p.join(projectPath, 'firebase.json'));
          await firebaseJson.writeAsString('''
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
''');

          // Create .firebaserc
          final File firebaserc = File(p.join(projectPath, '.firebaserc'));
          await firebaserc.writeAsString('''
{
  "projects": {
    "default": "${DeploymentTestConfig.projectId}"
  }
}
''');

          // Deploy to Firebase Hosting
          ProcessResult deployResult = await runner.run(
            'firebase',
            <String>['deploy', '--only', 'hosting', '--project', DeploymentTestConfig.projectId],
            workingDirectory: projectPath,
          );

          expect(
            deployResult.exitCode,
            equals(0),
            reason: 'Firebase hosting deploy should succeed:\n${deployResult.stdout}\n${deployResult.stderr}',
          );

          // Verify deployment URL is in output
          expect(
            deployResult.stdout,
            anyOf(
              contains('Hosting URL'),
              contains('Deploy complete'),
              contains('firebaseapp.com'),
              contains('web.app'),
            ),
          );
        },
        timeout: const Timeout(Duration(minutes: 15)),
      );

      test(
        'can deploy Jaspr web app to Firebase Hosting',
        () async {
          if (!DeploymentTestConfig.canRunDeploymentTests) {
            markTestSkipped(DeploymentTestConfig.skipMessage);
            return;
          }

          final String appName = 'deploy_jaspr_test';
          final SetupConfig config = SetupConfig(
            appName: appName,
            orgDomain: 'com.test',
            baseClassName: 'DeployJasprTest',
            template: TemplateType.arcaneJaspr,
            outputDir: tempDir.path,
            useFirebase: true,
            firebaseProjectId: DeploymentTestConfig.projectId,
          );

          // Copy template
          final String templatesPath = _getTemplatesPath();
          final TemplateCopier copier = TemplateCopier.withPath(config, templatesPath);
          await copier.copyAppTemplate();

          final String projectPath = p.join(tempDir.path, config.webPackageName);

          // Run dart pub get and build
          await runner.run(
            'dart',
            <String>['pub', 'get'],
            workingDirectory: projectPath,
          );

          ProcessResult buildResult = await runner.run(
            'jaspr',
            <String>['build'],
            workingDirectory: projectPath,
          );
          expect(buildResult.exitCode, equals(0), reason: 'Jaspr build should succeed');

          // Create firebase.json for hosting (Jaspr builds to build/jaspr)
          final File firebaseJson = File(p.join(projectPath, 'firebase.json'));
          await firebaseJson.writeAsString('''
{
  "hosting": {
    "public": "build/jaspr",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
''');

          // Create .firebaserc
          final File firebaserc = File(p.join(projectPath, '.firebaserc'));
          await firebaserc.writeAsString('''
{
  "projects": {
    "default": "${DeploymentTestConfig.projectId}"
  }
}
''');

          // Deploy to Firebase Hosting
          ProcessResult deployResult = await runner.run(
            'firebase',
            <String>['deploy', '--only', 'hosting', '--project', DeploymentTestConfig.projectId],
            workingDirectory: projectPath,
          );

          expect(
            deployResult.exitCode,
            equals(0),
            reason: 'Firebase hosting deploy should succeed:\n${deployResult.stdout}\n${deployResult.stderr}',
          );
        },
        timeout: const Timeout(Duration(minutes: 15)),
      );
    });

    group('FirebaseService Integration', () {
      test(
        'FirebaseService.buildWeb works for Flutter template',
        () async {
          if (!DeploymentTestConfig.canRunDeploymentTests) {
            markTestSkipped(DeploymentTestConfig.skipMessage);
            return;
          }

          final String appName = 'service_build_test';
          final SetupConfig config = SetupConfig(
            appName: appName,
            orgDomain: 'com.test',
            baseClassName: 'ServiceBuildTest',
            template: TemplateType.arcaneTemplate,
            outputDir: tempDir.path,
            useFirebase: true,
            firebaseProjectId: DeploymentTestConfig.projectId,
            platforms: <String>['web'],
          );

          // Copy template
          final String templatesPath = _getTemplatesPath();
          final TemplateCopier copier = TemplateCopier.withPath(config, templatesPath);
          await copier.copyAppTemplate();

          final String projectPath = p.join(tempDir.path, appName);

          // Run flutter pub get first
          await runner.run(
            'flutter',
            <String>['pub', 'get'],
            workingDirectory: projectPath,
          );

          // Use FirebaseService to build
          final FirebaseService service = FirebaseService(config, runner: runner);
          final bool buildSuccess = await service.buildWeb();

          expect(buildSuccess, isTrue, reason: 'FirebaseService.buildWeb should succeed');

          // Verify build output
          final Directory buildDir = Directory(p.join(projectPath, 'build', 'web'));
          expect(buildDir.existsSync(), isTrue);
        },
        timeout: const Timeout(Duration(minutes: 10)),
      );
    });
  });
}

/// Get the templates path relative to the test directory
String _getTemplatesPath() {
  return p.normalize(p.join(Directory.current.path, '..', 'templates'));
}

/// ProcessRunner that adds authentication environment to all calls
class _AuthenticatedProcessRunner extends ProcessRunner {
  final Map<String, String> environment;

  _AuthenticatedProcessRunner({required this.environment})
      : super(maxAutoRetries: 0, showVerbose: true);

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool inheritStdio = false,
  }) {
    final Map<String, String> mergedEnv = <String, String>{
      ...this.environment,
      ...?environment,
    };
    return super.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: mergedEnv,
      inheritStdio: inheritStdio,
    );
  }

  @override
  Future<ProcessResult?> runWithRetry(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    String? operationName,
    bool? interactive,
  }) {
    final Map<String, String> mergedEnv = <String, String>{
      ...this.environment,
      ...?environment,
    };
    return super.runWithRetry(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: mergedEnv,
      operationName: operationName,
      interactive: false,
    );
  }

  @override
  Future<int> runStreaming(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) {
    final Map<String, String> mergedEnv = <String, String>{
      ...this.environment,
      ...?environment,
    };
    return super.runStreaming(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: mergedEnv,
    );
  }
}
