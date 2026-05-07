import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../../models/setup_config.dart';
import '../../utils/link_opener.dart';
import '../../utils/project_config_loader.dart';
import '../../utils/setup_guidance.dart';
import '../../utils/user_prompt.dart';

Future<void> handleGuide(
  Map<String, dynamic> args,
  Map<String, dynamic> flags,
) async {
  final SetupConfig? config = await ProjectConfigLoader.load();
  if (config == null) {
    ProjectConfigLoader.printMissingConfigHelp();
    return;
  }

  final File guide = await SetupGuidance.writeProjectGuide(config);
  success('Wrote setup guide: ${guide.path}');

  if (flags['print'] == true) {
    print('');
    print(await guide.readAsString());
    return;
  }

  print('');
  UserPrompt.printList(<String>[
    'Open guide: oracular open guide',
    'Open app folder: oracular open app',
    if (config.useFirebase) 'Open Firebase: oracular open firebase',
    if (config.createServer) 'Open server folder: oracular open server',
  ]);
}

Future<void> handleOpenTarget(String target) async {
  final SetupConfig? config = await ProjectConfigLoader.load();
  if (config == null) {
    ProjectConfigLoader.printMissingConfigHelp();
    return;
  }

  final String? destination = _resolveOpenTarget(config, target);
  if (destination == null) {
    _printOpenHelp(config);
    return;
  }

  if (target == 'guide' && !File(destination).existsSync()) {
    await SetupGuidance.writeProjectGuide(config);
  }

  if (await LinkOpener.open(destination)) {
    success('Opened: $destination');
  } else {
    error('Could not open: $destination');
  }
}

void _printOpenHelp(SetupConfig config) {
  print('');
  print('Open targets:');
  UserPrompt.printList(<String>[
    'guide - ${SetupGuidance.projectGuidePath(config)}',
    'root - ${config.outputDir}',
    'app - ${SetupGuidance.mainProjectPath(config)}',
    if (config.createModels)
      'models - ${p.join(config.outputDir, config.modelsPackageName)}',
    if (config.createServer)
      'server - ${p.join(config.outputDir, config.serverPackageName)}',
    'config - ${p.join(config.outputDir, 'config')}',
    if (config.useFirebase) 'firebase - Firebase project overview',
    if (config.useFirebase) 'auth - Firebase Authentication',
    if (config.useFirebase) 'firestore - Firestore Database',
    if (config.useFirebase) 'storage - Firebase Storage',
    if (SetupGuidance.supportsWebHosting(config)) 'hosting - Firebase Hosting',
    if (config.createServer && config.firebaseProjectId != null)
      'service-account - Firebase service account keys',
    if (config.createServer && config.firebaseProjectId != null)
      'cloud-run - Google Cloud Run',
  ]);
}

String? _resolveOpenTarget(SetupConfig config, String target) {
  final String normalized = target.trim().toLowerCase();
  final String? projectId = config.firebaseProjectId;

  switch (normalized) {
    case 'guide':
      return SetupGuidance.projectGuidePath(config);
    case 'root':
      return config.outputDir;
    case 'app':
      return SetupGuidance.mainProjectPath(config);
    case 'models':
      if (!config.createModels) return null;
      return p.join(config.outputDir, config.modelsPackageName);
    case 'server':
      if (!config.createServer) return null;
      return p.join(config.outputDir, config.serverPackageName);
    case 'config':
      return p.join(config.outputDir, 'config');
    case 'firebase':
      if (projectId == null) return null;
      return SetupGuidance.firebaseOverviewUrl(projectId);
    case 'auth':
    case 'authentication':
      if (projectId == null) return null;
      return SetupGuidance.firebaseAuthenticationConsoleUrl(projectId);
    case 'firestore':
      if (projectId == null) return null;
      return SetupGuidance.firebaseFirestoreConsoleUrl(projectId);
    case 'storage':
      if (projectId == null) return null;
      return SetupGuidance.firebaseStorageConsoleUrl(projectId);
    case 'hosting':
      if (projectId == null || !SetupGuidance.supportsWebHosting(config)) {
        return null;
      }
      return SetupGuidance.firebaseHostingConsoleUrl(projectId);
    case 'service-account':
    case 'service-accounts':
      if (projectId == null) return null;
      return SetupGuidance.firebaseServiceAccountUrl(projectId);
    case 'cloud-run':
    case 'cloudrun':
      if (projectId == null) return null;
      return SetupGuidance.cloudRunConsoleUrl(projectId);
  }

  return null;
}
