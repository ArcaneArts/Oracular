import 'package:fast_log/fast_log.dart';

import '../../models/setup_config.dart';
import '../../utils/project_config_loader.dart';

Future<SetupConfig?> loadRequiredSetupConfig() async {
  final SetupConfig? config = await ProjectConfigLoader.load();
  if (config == null) {
    ProjectConfigLoader.printMissingConfigHelp();
  }
  return config;
}

Future<SetupConfig?> requireFirebaseProjectConfig() async {
  final SetupConfig? config = await loadRequiredSetupConfig();
  if (config == null) return null;

  if (!config.useFirebase || config.firebaseProjectId == null) {
    error('Firebase is not enabled or project ID not set.');
    return null;
  }

  return config;
}

Future<SetupConfig?> requireCloudRunProjectConfig({
  required String disabledMessage,
  required String missingProjectMessage,
}) async {
  final SetupConfig? config = await loadRequiredSetupConfig();
  if (config == null) return null;

  if (!config.setupCloudRun) {
    error(disabledMessage);
    return null;
  }

  if (config.firebaseProjectId == null) {
    error(missingProjectMessage);
    return null;
  }

  return config;
}
