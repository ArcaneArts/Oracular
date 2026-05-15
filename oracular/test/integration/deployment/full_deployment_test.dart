@TestOn('vm')
@Timeout(Duration(minutes: 30))
@Tags(<String>['live_deployment'])
library;

import 'dart:io';

import 'package:oracular/models/setup_config.dart';
import 'package:oracular/models/template_info.dart';
import 'package:oracular/services/firebase_service.dart';
import 'package:oracular/services/template_copier.dart';
import 'package:oracular/utils/process_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'authenticated_runner.dart';
import 'deployment_test_harness.dart';
import 'test_config.dart';

void main() {
  group('Full Deployment Orchestration Tests', () {
    late Directory tempDir;
    late AuthenticatedProcessRunner runner;

    setUpAll(initializeLiveDeploymentSuite);

    setUp(() async {
      tempDir = await createDeploymentTempDir('oracular_full_deploy_');
      runner = authenticatedDeploymentRunner();
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Complete Template Deployment Permutations', () {
      // Test each deployable template type
      for (final TemplateType template in <TemplateType>[
        TemplateType.arcaneTemplate,
        TemplateType.arcaneBeamer,
        TemplateType.arcaneJaspr,
      ]) {
        test(
          'full deployment flow for ${template.name}',
          () async {
            if (skipUnlessLiveDeploymentEnabled()) {
              return;
            }

            final String timestamp = DateTime.now().millisecondsSinceEpoch
                .toString();
            final String appName =
                '${template.directoryName.replaceAll('_', '')}$timestamp';

            // Shorten app name if too long
            final String safeAppName = appName.length > 20
                ? appName.substring(0, 20)
                : appName;

            final SetupConfig config = SetupConfig(
              appName: safeAppName,
              orgDomain: 'com.test',
              baseClassName: 'DeployTest',
              template: template,
              outputDir: tempDir.path,
              useFirebase: true,
              firebaseProjectId: DeploymentTestConfig.projectId,
              platforms: template.isFlutterApp ? <String>['web'] : <String>[],
            );

            // Step 1: Copy template
            final String templatesPath = deploymentTemplatesPath;
            final TemplateCopier copier = TemplateCopier.withPath(
              config,
              templatesPath,
            );
            await copier.copyAppTemplate();

            // Determine project path
            final String projectDirName = template.isJasprApp
                ? config.webPackageName
                : config.appName;
            final String projectPath = p.join(tempDir.path, projectDirName);

            expect(
              Directory(projectPath).existsSync(),
              isTrue,
              reason: 'Project directory should be created',
            );

            // Step 2: Get dependencies
            ProcessResult pubResult;
            if (template.isFlutterApp) {
              pubResult = await runner.run('flutter', <String>[
                'pub',
                'get',
              ], workingDirectory: projectPath);
            } else {
              pubResult = await runner.run('dart', <String>[
                'pub',
                'get',
              ], workingDirectory: projectPath);
            }
            expect(
              pubResult.exitCode,
              equals(0),
              reason: 'pub get should succeed',
            );

            // Step 3: Build web
            ProcessResult buildResult;
            if (template.isJasprApp) {
              buildResult = await runner.run('jaspr', <String>[
                'build',
              ], workingDirectory: projectPath);
            } else {
              buildResult = await runner.run('flutter', <String>[
                'build',
                'web',
                '--release',
              ], workingDirectory: projectPath);
            }
            expect(
              buildResult.exitCode,
              equals(0),
              reason: 'Web build should succeed:\n${buildResult.stderr}',
            );

            // Step 4: Setup Firebase config files
            final String buildOutputPath = template.isJasprApp
                ? 'build/jaspr'
                : 'build/web';

            final File firebaseJson = File(
              p.join(projectPath, 'firebase.json'),
            );
            await firebaseJson.writeAsString('''
{
  "hosting": {
    "public": "$buildOutputPath",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [{"source": "**", "destination": "/index.html"}]
  }
}
''');

            final File firebaserc = File(p.join(projectPath, '.firebaserc'));
            await firebaserc.writeAsString('''
{
  "projects": {
    "default": "${DeploymentTestConfig.projectId}"
  }
}
''');

            // Step 5: Deploy to Firebase Hosting
            final ProcessResult deployResult = await runner
                .run('firebase', <String>[
                  'deploy',
                  '--only',
                  'hosting',
                  '--project',
                  DeploymentTestConfig.projectId,
                ], workingDirectory: projectPath);

            expect(
              deployResult.exitCode,
              equals(0),
              reason:
                  'Firebase deploy should succeed for ${template.name}:\n${deployResult.stdout}\n${deployResult.stderr}',
            );

            // Step 6: Verify deployment
            expect(
              deployResult.stdout,
              anyOf(
                contains('Deploy complete'),
                contains('Hosting URL'),
                contains('firebaseapp.com'),
                contains('web.app'),
              ),
              reason: 'Deployment output should indicate success',
            );
          },
          timeout: const Timeout(Duration(minutes: 15)),
        );
      }
    });

    group('Template + Models + Server Deployment', () {
      test(
        'full deployment with models and server packages',
        () async {
          if (skipUnlessLiveDeploymentEnabled()) {
            return;
          }

          final String timestamp = DateTime.now().millisecondsSinceEpoch
              .toString()
              .substring(5);
          final String appName = 'fullstack$timestamp';

          final SetupConfig config = SetupConfig(
            appName: appName,
            orgDomain: 'com.test',
            baseClassName: 'FullStackTest',
            template: TemplateType.arcaneTemplate,
            outputDir: tempDir.path,
            useFirebase: true,
            firebaseProjectId: DeploymentTestConfig.projectId,
            createModels: true,
            createServer: true,
            platforms: <String>['web'],
          );

          // Copy all templates
          final String templatesPath = deploymentTemplatesPath;
          final TemplateCopier copier = TemplateCopier.withPath(
            config,
            templatesPath,
          );
          await copier.copyAll();

          // Verify all directories created
          final String appPath = p.join(tempDir.path, config.appName);
          final String modelsPath = p.join(
            tempDir.path,
            config.modelsPackageName,
          );
          final String serverPath = p.join(
            tempDir.path,
            config.serverPackageName,
          );

          expect(
            Directory(appPath).existsSync(),
            isTrue,
            reason: 'App dir should exist',
          );
          expect(
            Directory(modelsPath).existsSync(),
            isTrue,
            reason: 'Models dir should exist',
          );
          expect(
            Directory(serverPath).existsSync(),
            isTrue,
            reason: 'Server dir should exist',
          );

          // Get dependencies for models first (no dependencies)
          ProcessResult pubResult = await runner.run('dart', <String>[
            'pub',
            'get',
          ], workingDirectory: modelsPath);
          expect(
            pubResult.exitCode,
            equals(0),
            reason: 'Models pub get should succeed',
          );

          // Get dependencies for server (depends on models)
          pubResult = await runner.run('dart', <String>[
            'pub',
            'get',
          ], workingDirectory: serverPath);
          expect(
            pubResult.exitCode,
            equals(0),
            reason: 'Server pub get should succeed',
          );

          // Get dependencies for app
          pubResult = await runner.run('flutter', <String>[
            'pub',
            'get',
          ], workingDirectory: appPath);
          expect(
            pubResult.exitCode,
            equals(0),
            reason: 'App pub get should succeed',
          );

          // Build web
          final ProcessResult buildResult = await runner.run(
            'flutter',
            <String>['build', 'web', '--release'],
            workingDirectory: appPath,
          );
          expect(
            buildResult.exitCode,
            equals(0),
            reason: 'Web build should succeed',
          );

          // Setup Firebase and deploy
          final File firebaseJson = File(p.join(appPath, 'firebase.json'));
          await firebaseJson.writeAsString('''
{
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [{"source": "**", "destination": "/index.html"}]
  }
}
''');

          final File firebaserc = File(p.join(appPath, '.firebaserc'));
          await firebaserc.writeAsString('''
{
  "projects": {
    "default": "${DeploymentTestConfig.projectId}"
  }
}
''');

          final ProcessResult deployResult = await runner.run(
            'firebase',
            <String>[
              'deploy',
              '--only',
              'hosting',
              '--project',
              DeploymentTestConfig.projectId,
            ],
            workingDirectory: appPath,
          );

          expect(
            deployResult.exitCode,
            equals(0),
            reason: 'Full stack deploy should succeed:\n${deployResult.stderr}',
          );
        },
        timeout: const Timeout(Duration(minutes: 20)),
      );
    });

    group('FirebaseService.deployAll Integration', () {
      test(
        'deployAll orchestrates complete deployment',
        () async {
          if (skipUnlessLiveDeploymentEnabled()) {
            return;
          }

          final String timestamp = DateTime.now().millisecondsSinceEpoch
              .toString()
              .substring(5);
          final String appName = 'deploysvc$timestamp';

          final SetupConfig config = SetupConfig(
            appName: appName,
            orgDomain: 'com.test',
            baseClassName: 'DeploySvcTest',
            template: TemplateType.arcaneTemplate,
            outputDir: tempDir.path,
            useFirebase: true,
            firebaseProjectId: DeploymentTestConfig.projectId,
            platforms: <String>['web'],
          );

          // Copy template
          final String templatesPath = deploymentTemplatesPath;
          final TemplateCopier copier = TemplateCopier.withPath(
            config,
            templatesPath,
          );
          await copier.copyAppTemplate();

          final String projectPath = p.join(tempDir.path, config.appName);

          // Get dependencies first
          await runner.run('flutter', <String>[
            'pub',
            'get',
          ], workingDirectory: projectPath);

          // Create Firebase config files
          final File firebaseJson = File(p.join(tempDir.path, 'firebase.json'));
          await firebaseJson.writeAsString('''
{
  "hosting": {
    "public": "${config.appName}/build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [{"source": "**", "destination": "/index.html"}]
  },
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "storage": {
    "rules": "storage.rules"
  }
}
''');

          final File firebaserc = File(p.join(tempDir.path, '.firebaserc'));
          await firebaserc.writeAsString('''
{
  "projects": {
    "default": "${DeploymentTestConfig.projectId}"
  }
}
''');

          // Create rules files
          final File firestoreRules = File(
            p.join(tempDir.path, 'firestore.rules'),
          );
          await firestoreRules.writeAsString('''
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
''');

          final File firestoreIndexes = File(
            p.join(tempDir.path, 'firestore.indexes.json'),
          );
          await firestoreIndexes.writeAsString(
            '{"indexes": [], "fieldOverrides": []}',
          );

          final File storageRules = File(p.join(tempDir.path, 'storage.rules'));
          await storageRules.writeAsString('''
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
''');

          // Use FirebaseService to deploy all
          final FirebaseService service = FirebaseService(
            config,
            runner: runner,
          );
          final bool success = await service.deployAll();

          expect(
            success,
            isTrue,
            reason: 'FirebaseService.deployAll should succeed',
          );
        },
        timeout: const Timeout(Duration(minutes: 20)),
      );
    });

    group('Multi-target Hosting Deployment', () {
      test(
        'can deploy to multiple hosting targets (release and beta)',
        () async {
          if (skipUnlessLiveDeploymentEnabled()) {
            return;
          }

          final String timestamp = DateTime.now().millisecondsSinceEpoch
              .toString()
              .substring(5);
          final String appName = 'multitgt$timestamp';

          final SetupConfig config = SetupConfig(
            appName: appName,
            orgDomain: 'com.test',
            baseClassName: 'MultiTargetTest',
            template: TemplateType.arcaneTemplate,
            outputDir: tempDir.path,
            useFirebase: true,
            firebaseProjectId: DeploymentTestConfig.projectId,
            platforms: <String>['web'],
          );

          // Copy and build
          final String templatesPath = deploymentTemplatesPath;
          final TemplateCopier copier = TemplateCopier.withPath(
            config,
            templatesPath,
          );
          await copier.copyAppTemplate();

          final String projectPath = p.join(tempDir.path, config.appName);

          await runner.run('flutter', <String>[
            'pub',
            'get',
          ], workingDirectory: projectPath);

          final ProcessResult buildResult = await runner.run(
            'flutter',
            <String>['build', 'web', '--release'],
            workingDirectory: projectPath,
          );
          expect(buildResult.exitCode, equals(0));

          // Create firebase.json with multiple hosting targets
          final File firebaseJson = File(p.join(projectPath, 'firebase.json'));
          await firebaseJson.writeAsString('''
{
  "hosting": [
    {
      "target": "release",
      "public": "build/web",
      "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
      "rewrites": [{"source": "**", "destination": "/index.html"}]
    },
    {
      "target": "beta",
      "public": "build/web",
      "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
      "rewrites": [{"source": "**", "destination": "/index.html"}]
    }
  ]
}
''');

          final File firebaserc = File(p.join(projectPath, '.firebaserc'));
          await firebaserc.writeAsString('''
{
  "projects": {
    "default": "${DeploymentTestConfig.projectId}"
  },
  "targets": {
    "${DeploymentTestConfig.projectId}": {
      "hosting": {
        "release": ["${DeploymentTestConfig.projectId}"],
        "beta": ["${DeploymentTestConfig.projectId}"]
      }
    }
  }
}
''');

          // Deploy to release target
          ProcessResult deployResult = await runner.run('firebase', <String>[
            'deploy',
            '--only',
            'hosting:release',
            '--project',
            DeploymentTestConfig.projectId,
          ], workingDirectory: projectPath);

          expect(
            deployResult.exitCode,
            equals(0),
            reason: 'Release deploy should succeed:\n${deployResult.stderr}',
          );

          // Deploy to beta target
          deployResult = await runner.run('firebase', <String>[
            'deploy',
            '--only',
            'hosting:beta',
            '--project',
            DeploymentTestConfig.projectId,
          ], workingDirectory: projectPath);

          expect(
            deployResult.exitCode,
            equals(0),
            reason: 'Beta deploy should succeed:\n${deployResult.stderr}',
          );
        },
        timeout: const Timeout(Duration(minutes: 20)),
      );
    });
  });
}
