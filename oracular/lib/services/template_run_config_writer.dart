import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import 'intellij_run_config_generator.dart';

class TemplateRunConfigWriter {
  static Future<void> generateJasprPackage({
    required String packageDir,
    String failureDescription = 'IntelliJ run configs',
  }) async {
    try {
      final List<String> written = await IntellijRunConfigGenerator.generate(
        packageDir: packageDir,
        port: IntellijRunConfigGenerator.defaultPort,
      );
      if (written.isNotEmpty) {
        verbose(
          '  Generated ${written.length} IntelliJ run config(s) in '
          '${p.join(packageDir, '.idea', 'runConfigurations')}',
        );
      }
    } catch (e) {
      warn('Failed to generate $failureDescription: $e');
    }
  }

  static Future<void> generateProjectDeploy({
    required String projectDir,
  }) async {
    try {
      final List<String> deployWritten =
          await IntellijRunConfigGenerator.generateDeploy(
            projectDir: projectDir,
          );
      if (deployWritten.isNotEmpty) {
        verbose(
          '  Generated project-level "Deploy All" run config in '
          '${p.join(projectDir, '.idea', 'runConfigurations')}',
        );
      }
    } catch (e) {
      warn('Failed to generate "Deploy All" IntelliJ run config: $e');
    }
  }
}
