@TestOn('vm')
@Timeout(Duration(minutes: 10))
import 'dart:io';

import 'package:oracular/models/setup_config.dart';
import 'package:oracular/models/template_info.dart';
import 'package:oracular/services/firebase_service.dart';
import 'package:oracular/utils/process_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_config.dart';

void main() {
  group('Firestore and Storage Rules Deployment Tests', () {
    late Directory tempDir;
    late ProcessRunner runner;

    setUpAll(() async {
      if (!DeploymentTestConfig.canRunDeploymentTests) {
        return;
      }

      // Initialize gcloud
      await DeploymentTestConfig.initializeGcloud();
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('oracular_rules_');
      runner = _AuthenticatedProcessRunner(
        environment: DeploymentTestConfig.authEnvironment,
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Firestore Rules', () {
      test(
        'can deploy Firestore rules',
        () async {
          if (!DeploymentTestConfig.canRunDeploymentTests) {
            markTestSkipped(DeploymentTestConfig.skipMessage);
            return;
          }

          // Create a project directory with Firestore rules
          final String projectPath = p.join(tempDir.path, 'firestore_rules_test');
          await Directory(projectPath).create(recursive: true);

          // Create firebase.json
          final File firebaseJson = File(p.join(projectPath, 'firebase.json'));
          await firebaseJson.writeAsString('''
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
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

          // Create Firestore rules file
          final File rulesFile = File(p.join(projectPath, 'firestore.rules'));
          await rulesFile.writeAsString('''
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Test rules - allow authenticated read/write
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
''');

          // Create Firestore indexes file
          final File indexesFile = File(p.join(projectPath, 'firestore.indexes.json'));
          await indexesFile.writeAsString('''
{
  "indexes": [],
  "fieldOverrides": []
}
''');

          // Deploy Firestore rules
          final ProcessResult result = await runner.run(
            'firebase',
            <String>[
              'deploy',
              '--only',
              'firestore:rules,firestore:indexes',
              '--project',
              DeploymentTestConfig.projectId,
            ],
            workingDirectory: projectPath,
          );

          expect(
            result.exitCode,
            equals(0),
            reason: 'Firestore rules deploy should succeed:\n${result.stdout}\n${result.stderr}',
          );
        },
      );

      test(
        'FirebaseService.deployFirestore works',
        () async {
          if (!DeploymentTestConfig.canRunDeploymentTests) {
            markTestSkipped(DeploymentTestConfig.skipMessage);
            return;
          }

          // Create project structure
          final String projectPath = p.join(tempDir.path, 'service_firestore_test');
          await Directory(projectPath).create(recursive: true);

          // Create firebase.json
          final File firebaseJson = File(p.join(projectPath, 'firebase.json'));
          await firebaseJson.writeAsString('''
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
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

          // Create Firestore rules
          final File rulesFile = File(p.join(projectPath, 'firestore.rules'));
          await rulesFile.writeAsString('''
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
''');

          // Create indexes
          final File indexesFile = File(p.join(projectPath, 'firestore.indexes.json'));
          await indexesFile.writeAsString('{"indexes": [], "fieldOverrides": []}');

          // Adjust: FirebaseService.deployFirestore uses config.outputDir
          // So we need to create the config with outputDir = parent of project
          final SetupConfig adjustedConfig = SetupConfig(
            appName: 'service_firestore_test',
            orgDomain: 'com.test',
            baseClassName: 'FirestoreTest',
            template: TemplateType.arcaneTemplate,
            outputDir: tempDir.path,
            useFirebase: true,
            firebaseProjectId: DeploymentTestConfig.projectId,
          );

          // Move files to the expected location (config.outputDir)
          await File(p.join(projectPath, 'firebase.json'))
              .copy(p.join(tempDir.path, 'firebase.json'));
          await File(p.join(projectPath, '.firebaserc'))
              .copy(p.join(tempDir.path, '.firebaserc'));
          await File(p.join(projectPath, 'firestore.rules'))
              .copy(p.join(tempDir.path, 'firestore.rules'));
          await File(p.join(projectPath, 'firestore.indexes.json'))
              .copy(p.join(tempDir.path, 'firestore.indexes.json'));

          final FirebaseService service = FirebaseService(adjustedConfig, runner: runner);
          final bool success = await service.deployFirestore();

          expect(success, isTrue, reason: 'FirebaseService.deployFirestore should succeed');
        },
      );
    });

    group('Storage Rules', () {
      // NOTE: Firebase Storage must be enabled manually in the Firebase Console
      // before these tests will pass. Go to:
      // https://console.firebase.google.com/project/oraculartestdeployments/storage
      // and click "Get Started" to enable Firebase Storage.

      test(
        'can deploy Storage rules',
        () async {
          if (!DeploymentTestConfig.canRunDeploymentTests) {
            markTestSkipped(DeploymentTestConfig.skipMessage);
            return;
          }

          // Create a project directory with Storage rules
          final String projectPath = p.join(tempDir.path, 'storage_rules_test');
          await Directory(projectPath).create(recursive: true);

          // Create firebase.json
          final File firebaseJson = File(p.join(projectPath, 'firebase.json'));
          await firebaseJson.writeAsString('''
{
  "storage": {
    "rules": "storage.rules"
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

          // Create Storage rules file
          final File rulesFile = File(p.join(projectPath, 'storage.rules'));
          await rulesFile.writeAsString('''
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
''');

          // Deploy Storage rules
          final ProcessResult result = await runner.run(
            'firebase',
            <String>[
              'deploy',
              '--only',
              'storage',
              '--project',
              DeploymentTestConfig.projectId,
            ],
            workingDirectory: projectPath,
          );

          // Skip if Storage is not enabled in Firebase Console
          if (result.stderr.contains('Firebase Storage has not been set up') ||
              result.stdout.contains('Firebase Storage has not been set up')) {
            markTestSkipped(
              'Firebase Storage not enabled. Enable at: '
              'https://console.firebase.google.com/project/${DeploymentTestConfig.projectId}/storage',
            );
            return;
          }

          expect(
            result.exitCode,
            equals(0),
            reason: 'Storage rules deploy should succeed:\n${result.stdout}\n${result.stderr}',
          );
        },
      );

      test(
        'FirebaseService.deployStorage works',
        () async {
          if (!DeploymentTestConfig.canRunDeploymentTests) {
            markTestSkipped(DeploymentTestConfig.skipMessage);
            return;
          }

          // Create firebase.json in tempDir
          final File firebaseJson = File(p.join(tempDir.path, 'firebase.json'));
          await firebaseJson.writeAsString('''
{
  "storage": {
    "rules": "storage.rules"
  }
}
''');

          // Create .firebaserc
          final File firebaserc = File(p.join(tempDir.path, '.firebaserc'));
          await firebaserc.writeAsString('''
{
  "projects": {
    "default": "${DeploymentTestConfig.projectId}"
  }
}
''');

          // Create Storage rules
          final File rulesFile = File(p.join(tempDir.path, 'storage.rules'));
          await rulesFile.writeAsString('''
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
''');

          final SetupConfig config = SetupConfig(
            appName: 'storage_test',
            orgDomain: 'com.test',
            baseClassName: 'StorageTest',
            template: TemplateType.arcaneTemplate,
            outputDir: tempDir.path,
            useFirebase: true,
            firebaseProjectId: DeploymentTestConfig.projectId,
          );

          final FirebaseService service = FirebaseService(config, runner: runner);
          final bool success = await service.deployStorage();

          // Skip if Storage is not enabled
          if (!success) {
            markTestSkipped(
              'Firebase Storage not enabled. Enable at: '
              'https://console.firebase.google.com/project/${DeploymentTestConfig.projectId}/storage',
            );
            return;
          }

          expect(success, isTrue, reason: 'FirebaseService.deployStorage should succeed');
        },
      );
    });

    group('Combined Rules Deployment', () {
      // NOTE: This test requires Firebase Storage to be enabled manually
      test(
        'can deploy both Firestore and Storage rules together',
        () async {
          if (!DeploymentTestConfig.canRunDeploymentTests) {
            markTestSkipped(DeploymentTestConfig.skipMessage);
            return;
          }

          // Create project structure with both rule types
          final String projectPath = p.join(tempDir.path, 'combined_rules_test');
          await Directory(projectPath).create(recursive: true);

          // Create firebase.json with both
          final File firebaseJson = File(p.join(projectPath, 'firebase.json'));
          await firebaseJson.writeAsString('''
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "storage": {
    "rules": "storage.rules"
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

          // Create Firestore rules
          final File firestoreRules = File(p.join(projectPath, 'firestore.rules'));
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

          // Create Firestore indexes
          final File firestoreIndexes = File(p.join(projectPath, 'firestore.indexes.json'));
          await firestoreIndexes.writeAsString('{"indexes": [], "fieldOverrides": []}');

          // Create Storage rules
          final File storageRules = File(p.join(projectPath, 'storage.rules'));
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

          // Deploy all rules at once
          final ProcessResult result = await runner.run(
            'firebase',
            <String>[
              'deploy',
              '--only',
              'firestore,storage',
              '--project',
              DeploymentTestConfig.projectId,
            ],
            workingDirectory: projectPath,
          );

          // Skip if Storage is not enabled
          if (result.stderr.contains('Firebase Storage has not been set up') ||
              result.stdout.contains('Firebase Storage has not been set up')) {
            markTestSkipped(
              'Firebase Storage not enabled. Enable at: '
              'https://console.firebase.google.com/project/${DeploymentTestConfig.projectId}/storage',
            );
            return;
          }

          expect(
            result.exitCode,
            equals(0),
            reason: 'Combined rules deploy should succeed:\n${result.stdout}\n${result.stderr}',
          );
        },
      );
    });
  });
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
