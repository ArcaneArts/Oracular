import 'dart:convert';
import 'dart:io';

import 'package:oracular/utils/process_runner.dart' show ProcessResult;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'authenticated_runner.dart';
import 'test_config.dart';

Future<void> initializeLiveDeploymentSuite() async {
  if (!DeploymentTestConfig.canRunDeploymentTests) {
    return;
  }

  await DeploymentTestConfig.initializeGcloud();
}

bool skipUnlessLiveDeploymentEnabled() {
  if (DeploymentTestConfig.canRunDeploymentTests) {
    return false;
  }

  markTestSkipped(DeploymentTestConfig.skipMessage);
  return true;
}

Future<Directory> createDeploymentTempDir(String prefix) {
  return Directory.systemTemp.createTemp(prefix);
}

AuthenticatedProcessRunner authenticatedDeploymentRunner() {
  return AuthenticatedProcessRunner(
    environment: DeploymentTestConfig.authEnvironment,
  );
}

String get deploymentTemplatesPath => DeploymentTestConfig.templatesPath;

String? firebaseAppResourceNameFromCreateResult(ProcessResult result) {
  final String output = '${result.stdout}\n${result.stderr}';

  try {
    final Object? decoded = jsonDecode(result.stdout);
    if (decoded is Map<String, Object?>) {
      final Object? app = decoded['result'];
      if (app is Map<String, Object?>) {
        final Object? name = app['name'];
        if (name is String && name.startsWith('projects/')) {
          return name;
        }
      }
    }
  } on FormatException {
    // The Firebase CLI can emit progress text around JSON in some contexts.
  }

  return RegExp(
    r'projects/[^/\s]+/(?:webApps|androidApps|iosApps)/[^\s",}]+',
  ).firstMatch(output)?.group(0);
}

Future<void> removeFirebaseAppResource(
  AuthenticatedProcessRunner runner,
  String resourceName, {
  String? workingDirectory,
}) async {
  final ProcessResult tokenResult = await runner.run('gcloud', <String>[
    'auth',
    'application-default',
    'print-access-token',
  ], workingDirectory: workingDirectory);

  if (!tokenResult.success) {
    throw StateError(
      'Could not obtain Firebase Management API token: '
      '${tokenResult.stderr}',
    );
  }

  final ProcessResult removeResult = await runner.run(
    'bash',
    <String>[
      '-lc',
      'curl -fsS -X POST '
          '-H "Authorization: Bearer \$FIREBASE_REMOVE_TOKEN" '
          '-H "Content-Type: application/json" '
          '"\$FIREBASE_REMOVE_ENDPOINT" '
          '-d \'{"immediate":true,"allowMissing":true}\'',
    ],
    workingDirectory: workingDirectory,
    environment: <String, String>{
      'FIREBASE_REMOVE_ENDPOINT':
          'https://firebase.googleapis.com/v1beta1/$resourceName:remove',
      'FIREBASE_REMOVE_TOKEN': tokenResult.stdout.trim(),
    },
  );

  if (!removeResult.success) {
    throw StateError(
      'Could not remove Firebase test app $resourceName: '
      '${removeResult.stderr}',
    );
  }
}

bool skipIfFirebaseAppQuotaExhausted(
  ProcessResult result, {
  String? workingDirectory,
}) {
  final String output = _firebaseCommandOutput(result, workingDirectory);
  if (!output.contains('RESOURCE_EXHAUSTED') &&
      !output.contains('Too many Apps on project')) {
    return false;
  }

  markTestSkipped(
    'Firebase app quota is exhausted for '
    '${DeploymentTestConfig.projectId}; direct app-creation checks cannot run '
    'until old test apps are removed.',
  );
  return true;
}

String _firebaseCommandOutput(ProcessResult result, String? workingDirectory) {
  final StringBuffer buffer = StringBuffer()
    ..writeln(result.stdout)
    ..writeln(result.stderr);

  for (final String path in <String>[
    if (workingDirectory != null)
      p.join(workingDirectory, 'firebase-debug.log'),
    p.join(Directory.current.path, 'firebase-debug.log'),
    p.join(Directory.current.parent.path, 'firebase-debug.log'),
  ]) {
    final File log = File(path);
    if (log.existsSync()) {
      buffer.writeln(log.readAsStringSync());
    }
  }

  return buffer.toString();
}
