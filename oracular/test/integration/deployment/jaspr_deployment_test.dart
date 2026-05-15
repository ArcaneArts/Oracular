@TestOn('vm')
@Timeout(Duration(minutes: 60))
// Run tests serially to avoid port conflicts with jaspr build
@Tags(<String>['serial', 'live_deployment'])
library;

import 'dart:io';

import 'package:oracular/models/setup_config.dart';
import 'package:oracular/models/template_info.dart';
import 'package:oracular/services/template_copier.dart';
import 'package:oracular/utils/process_runner.dart' show ProcessResult;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'authenticated_runner.dart';
import 'deployment_test_harness.dart';
import 'test_config.dart';

/// Default port for jaspr tests (avoids 8080 which may be in use)
const int _jasprTestPort = 9100;

void main() {
  // Run tests serially to avoid port conflicts
  group('Jaspr Template Deployment Tests', () {
    late Directory tempDir;
    late AuthenticatedProcessRunner runner;

    setUpAll(initializeLiveDeploymentSuite);

    setUp(() async {
      tempDir = await createDeploymentTempDir('oracular_jaspr_');
      runner = authenticatedDeploymentRunner();
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    // Test arcaneJaspr permutations
    group('arcaneJaspr Template', () {
      for (final bool createModels in <bool>[false, true]) {
        for (final bool createServer in <bool>[false, true]) {
          // Server requires models - skip invalid combination
          if (createServer && !createModels) {
            continue;
          }

          final String permName =
              'models=${createModels ? "yes" : "no"}, server=${createServer ? "yes" : "no"}';

          test(
            'build and deploy with $permName',
            () async {
              if (skipUnlessLiveDeploymentEnabled()) {
                return;
              }

              // Small delay to ensure port is released from previous test
              await Future<void>.delayed(const Duration(seconds: 2));

              final String timestamp = DateTime.now().millisecondsSinceEpoch
                  .toString()
                  .substring(5);
              final String appName = 'jaspr$timestamp';

              final SetupConfig config = SetupConfig(
                appName: appName,
                orgDomain: 'com.test',
                baseClassName: 'JasprTest',
                template: TemplateType.arcaneJaspr,
                outputDir: tempDir.path,
                useFirebase: true,
                firebaseProjectId: DeploymentTestConfig.projectId,
                createModels: createModels,
                createServer: createServer,
              );

              // Step 1: Copy templates
              final String templatesPath = deploymentTemplatesPath;
              final TemplateCopier copier = TemplateCopier.withPath(
                config,
                templatesPath,
              );
              await copier.copyAll();

              // Verify web project created (Jaspr uses webPackageName)
              final String webPath = p.join(
                tempDir.path,
                config.webPackageName,
              );
              expect(
                Directory(webPath).existsSync(),
                isTrue,
                reason:
                    'Web project should be created at ${config.webPackageName}',
              );

              // Configure jaspr to use a non-standard port (avoids 8080)
              await _configureJasprPort(webPath);

              // Verify models if requested
              if (createModels) {
                final String modelsPath = p.join(
                  tempDir.path,
                  config.modelsPackageName,
                );
                expect(
                  Directory(modelsPath).existsSync(),
                  isTrue,
                  reason: 'Models package should be created',
                );

                // Get models dependencies
                final ProcessResult modelsPubResult = await runner.run(
                  'dart',
                  <String>['pub', 'get'],
                  workingDirectory: modelsPath,
                );
                expect(
                  modelsPubResult.exitCode,
                  equals(0),
                  reason: 'Models pub get should succeed',
                );

                // Analyze models
                final ProcessResult modelsAnalyze = await runner.run(
                  'dart',
                  <String>['analyze'],
                  workingDirectory: modelsPath,
                );
                expect(
                  modelsAnalyze.exitCode,
                  equals(0),
                  reason: 'Models should analyze cleanly',
                );
              }

              // Verify server if requested
              if (createServer) {
                final String serverPath = p.join(
                  tempDir.path,
                  config.serverPackageName,
                );
                expect(
                  Directory(serverPath).existsSync(),
                  isTrue,
                  reason: 'Server package should be created',
                );

                // Get server dependencies (requires models first if both are enabled)
                final ProcessResult serverPubResult = await runner.run(
                  'dart',
                  <String>['pub', 'get'],
                  workingDirectory: serverPath,
                );
                expect(
                  serverPubResult.exitCode,
                  equals(0),
                  reason: 'Server pub get should succeed',
                );

                // Analyze server
                final ProcessResult serverAnalyze = await runner.run(
                  'dart',
                  <String>['analyze'],
                  workingDirectory: serverPath,
                );
                expect(
                  serverAnalyze.exitCode,
                  equals(0),
                  reason: 'Server should analyze cleanly',
                );
              }

              // Step 2: Get web dependencies
              final ProcessResult pubResult = await runner.run('dart', <String>[
                'pub',
                'get',
              ], workingDirectory: webPath);
              expect(
                pubResult.exitCode,
                equals(0),
                reason: 'Web pub get should succeed',
              );

              // Step 3: Build with Jaspr
              final ProcessResult buildResult = await runner.run(
                'jaspr',
                <String>['build'],
                workingDirectory: webPath,
              );
              expect(
                buildResult.exitCode,
                equals(0),
                reason: 'Jaspr build should succeed:\n${buildResult.stderr}',
              );

              // Verify build output
              final Directory buildDir = Directory(
                p.join(webPath, 'build', 'jaspr'),
              );
              expect(
                buildDir.existsSync(),
                isTrue,
                reason: 'Jaspr build output should exist',
              );

              // Step 4: Setup Firebase config
              final File firebaseJson = File(p.join(webPath, 'firebase.json'));
              await firebaseJson.writeAsString('''
{
  "hosting": {
    "public": "build/jaspr",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [{"source": "**", "destination": "/index.html"}]
  }
}
''');

              final File firebaserc = File(p.join(webPath, '.firebaserc'));
              await firebaserc.writeAsString('''
{
  "projects": {
    "default": "${DeploymentTestConfig.projectId}"
  }
}
''');

              // Step 5: Deploy
              final ProcessResult deployResult = await runner
                  .run('firebase', <String>[
                    'deploy',
                    '--only',
                    'hosting',
                    '--project',
                    DeploymentTestConfig.projectId,
                  ], workingDirectory: webPath);

              expect(
                deployResult.exitCode,
                equals(0),
                reason:
                    'Firebase deploy should succeed:\n${deployResult.stdout}\n${deployResult.stderr}',
              );

              print('Successfully tested arcaneJaspr with $permName');
            },
            timeout: const Timeout(Duration(minutes: 10)),
          );
        }
      }
    });

    // Test arcaneJasprDocs permutations
    group('arcaneJasprDocs Template', () {
      for (final bool createModels in <bool>[false, true]) {
        for (final bool createServer in <bool>[false, true]) {
          // Server requires models - skip invalid combination
          if (createServer && !createModels) {
            continue;
          }

          final String permName =
              'models=${createModels ? "yes" : "no"}, server=${createServer ? "yes" : "no"}';

          test(
            'build and deploy with $permName',
            () async {
              if (skipUnlessLiveDeploymentEnabled()) {
                return;
              }

              // Small delay to ensure port is released from previous test
              await Future<void>.delayed(const Duration(seconds: 2));

              final String timestamp = DateTime.now().millisecondsSinceEpoch
                  .toString()
                  .substring(5);
              final String appName = 'jasprdocs$timestamp';

              final SetupConfig config = SetupConfig(
                appName: appName,
                orgDomain: 'com.test',
                baseClassName: 'JasprDocsTest',
                template: TemplateType.arcaneJasprDocs,
                outputDir: tempDir.path,
                useFirebase: true,
                firebaseProjectId: DeploymentTestConfig.projectId,
                createModels: createModels,
                createServer: createServer,
              );

              // Step 1: Copy templates
              final String templatesPath = deploymentTemplatesPath;
              final TemplateCopier copier = TemplateCopier.withPath(
                config,
                templatesPath,
              );
              await copier.copyAll();

              // Verify web project created
              final String webPath = p.join(
                tempDir.path,
                config.webPackageName,
              );
              expect(
                Directory(webPath).existsSync(),
                isTrue,
                reason:
                    'Web project should be created at ${config.webPackageName}',
              );

              // Configure jaspr to use a non-standard port (avoids 8080)
              await _configureJasprPort(webPath);

              // Verify models if requested
              if (createModels) {
                final String modelsPath = p.join(
                  tempDir.path,
                  config.modelsPackageName,
                );
                expect(
                  Directory(modelsPath).existsSync(),
                  isTrue,
                  reason: 'Models package should be created',
                );

                final ProcessResult modelsPubResult = await runner.run(
                  'dart',
                  <String>['pub', 'get'],
                  workingDirectory: modelsPath,
                );
                expect(
                  modelsPubResult.exitCode,
                  equals(0),
                  reason: 'Models pub get should succeed',
                );

                final ProcessResult modelsAnalyze = await runner.run(
                  'dart',
                  <String>['analyze'],
                  workingDirectory: modelsPath,
                );
                expect(
                  modelsAnalyze.exitCode,
                  equals(0),
                  reason: 'Models should analyze cleanly',
                );
              }

              // Verify server if requested
              if (createServer) {
                final String serverPath = p.join(
                  tempDir.path,
                  config.serverPackageName,
                );
                expect(
                  Directory(serverPath).existsSync(),
                  isTrue,
                  reason: 'Server package should be created',
                );

                final ProcessResult serverPubResult = await runner.run(
                  'dart',
                  <String>['pub', 'get'],
                  workingDirectory: serverPath,
                );
                expect(
                  serverPubResult.exitCode,
                  equals(0),
                  reason: 'Server pub get should succeed',
                );

                final ProcessResult serverAnalyze = await runner.run(
                  'dart',
                  <String>['analyze'],
                  workingDirectory: serverPath,
                );
                expect(
                  serverAnalyze.exitCode,
                  equals(0),
                  reason: 'Server should analyze cleanly',
                );
              }

              // Step 2: Get web dependencies
              final ProcessResult pubResult = await runner.run('dart', <String>[
                'pub',
                'get',
              ], workingDirectory: webPath);
              expect(
                pubResult.exitCode,
                equals(0),
                reason: 'Web pub get should succeed',
              );

              // Step 3: Build with Jaspr
              final ProcessResult buildResult = await runner.run(
                'jaspr',
                <String>['build'],
                workingDirectory: webPath,
              );
              expect(
                buildResult.exitCode,
                equals(0),
                reason: 'Jaspr build should succeed:\n${buildResult.stderr}',
              );

              // Verify build output
              final Directory buildDir = Directory(
                p.join(webPath, 'build', 'jaspr'),
              );
              expect(
                buildDir.existsSync(),
                isTrue,
                reason: 'Jaspr build output should exist',
              );

              // Step 4: Setup Firebase config
              final File firebaseJson = File(p.join(webPath, 'firebase.json'));
              await firebaseJson.writeAsString('''
{
  "hosting": {
    "public": "build/jaspr",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [{"source": "**", "destination": "/index.html"}]
  }
}
''');

              final File firebaserc = File(p.join(webPath, '.firebaserc'));
              await firebaserc.writeAsString('''
{
  "projects": {
    "default": "${DeploymentTestConfig.projectId}"
  }
}
''');

              // Step 5: Deploy
              final ProcessResult deployResult = await runner
                  .run('firebase', <String>[
                    'deploy',
                    '--only',
                    'hosting',
                    '--project',
                    DeploymentTestConfig.projectId,
                  ], workingDirectory: webPath);

              expect(
                deployResult.exitCode,
                equals(0),
                reason:
                    'Firebase deploy should succeed:\n${deployResult.stdout}\n${deployResult.stderr}',
              );

              print('Successfully tested arcaneJasprDocs with $permName');
            },
            timeout: const Timeout(Duration(minutes: 10)),
          );
        }
      }
    });
  });
}

/// Configure jaspr to use a different port (avoids 8080)
Future<void> _configureJasprPort(String webPath) async {
  final File pubspec = File(p.join(webPath, 'pubspec.yaml'));
  if (!pubspec.existsSync()) {
    return;
  }

  String content = await pubspec.readAsString();

  // Replace jaspr: section with port configuration
  // Handle both single-line and multi-line jaspr: sections
  final RegExp jasprSection = RegExp(r'jaspr:\s*\n(\s+\S+.*\n)*');
  if (jasprSection.hasMatch(content)) {
    // Find the jaspr section and add port at the start
    content = content.replaceAllMapped(jasprSection, (Match match) {
      final String existingContent = match.group(0)!;
      // Add port after 'jaspr:\n'
      return existingContent.replaceFirst(
        'jaspr:\n',
        'jaspr:\n  port: $_jasprTestPort\n',
      );
    });
  } else if (content.contains('jaspr:')) {
    // Simple jaspr: line without content
    content = content.replaceFirst('jaspr:', 'jaspr:\n  port: $_jasprTestPort');
  }

  await pubspec.writeAsString(content);
}
