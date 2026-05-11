import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../../models/setup_config.dart';
import '../../models/template_info.dart';
import '../../services/build_orchestrator.dart';

/// Resolve the SetupConfig from `<cwd>/config/setup_config.env`, exiting
/// the process with a friendly error message when the file is missing or
/// malformed. Mirrors the pattern used by `deploy_handlers.dart`.
Future<SetupConfig> _loadConfigOrExit() async {
  final String configPath =
      p.join(Directory.current.path, 'config', 'setup_config.env');
  final SetupConfig? config = await SetupConfig.loadFromFile(configPath);
  if (config == null) {
    error('Could not load setup config at $configPath.');
    error(
      'Run this command from the project root, or scaffold a project '
      'first with `oracular create`.',
    );
    exit(1);
  }
  return config;
}

/// Print a one-line per-step build summary.
void _printReport(BuildReport report) {
  print('');
  print('\u2500' * 70);
  print('  Build Report');
  print('\u2500' * 70);
  for (final BuildStepResult r in report.results) {
    final String marker;
    switch (r.status) {
      case BuildStepStatus.success:
        marker = '\u2713';
        break;
      case BuildStepStatus.skipped:
        marker = '\u2026';
        break;
      case BuildStepStatus.failed:
        marker = '\u2717';
        break;
    }
    print('  $marker  ${r.label}');
    if (r.outputPath.isNotEmpty) {
      print('       \u21B3 ${r.outputPath}');
    }
    if (r.message.isNotEmpty) {
      print('       ${r.message}');
    }
  }
  print('');
  if (report.allSucceeded) {
    success(
      'Build complete: ${report.succeededCount} step(s), '
      '${report.skippedCount} skipped.',
    );
  } else if (report.anyFailed) {
    error(
      'Build failed: ${report.failedCount} step(s) errored, '
      '${report.succeededCount} succeeded.',
    );
  } else {
    warn('Build completed with no actionable steps.');
  }
}

/// `oracular build everything` — every applicable artifact for this project.
Future<void> handleBuildAll() async {
  final SetupConfig config = await _loadConfigOrExit();
  final BuildOrchestrator orchestrator = BuildOrchestrator(config);
  final BuildReport report = await orchestrator.buildAll();
  _printReport(report);
  if (report.anyFailed) {
    exit(1);
  }
}

/// `oracular build flutter-app [--platform <p>]` — build every selected
/// Flutter platform, or a specific one when `--platform` is set.
Future<void> handleBuildFlutter(Map<String, dynamic> args) async {
  final SetupConfig config = await _loadConfigOrExit();
  if (!config.template.isFlutterApp) {
    error(
      'oracular build flutter-app is only available for Flutter app templates '
      '(this project uses ${config.template.displayName}).',
    );
    exit(2);
  }

  final BuildOrchestrator orchestrator = BuildOrchestrator(config);
  final List<BuildStepResult> results = <BuildStepResult>[];

  final String? requested = (args['platform'] as String?)?.trim();
  final List<String> platforms = (requested != null && requested.isNotEmpty)
      ? <String>[requested]
      : config.platforms;

  for (final String platform in platforms) {
    results.add(await orchestrator.buildFlutter(platform: platform));
  }

  final BuildReport report = BuildReport(results);
  _printReport(report);
  if (report.anyFailed) {
    exit(1);
  }
}

/// `oracular build jaspr-site` — render-mode-aware `jaspr build`.
Future<void> handleBuildJaspr() async {
  final SetupConfig config = await _loadConfigOrExit();
  if (!config.template.isJasprApp) {
    error(
      'oracular build jaspr-site is only available for Jaspr templates '
      '(this project uses ${config.template.displayName}).',
    );
    exit(2);
  }

  final BuildOrchestrator orchestrator = BuildOrchestrator(config);
  final BuildReport report = BuildReport(<BuildStepResult>[
    await orchestrator.buildJaspr(),
  ]);
  _printReport(report);
  if (report.anyFailed) {
    exit(1);
  }
}

/// `oracular build jaspr-image` — docker image for SSR / hybrid Jaspr.
Future<void> handleBuildJasprServer() async {
  final SetupConfig config = await _loadConfigOrExit();
  if (!config.hasJasprServer) {
    error(
      'oracular build jaspr-image only applies to SSR / hybrid Jaspr '
      'projects (this project is in '
      '${config.jasprRenderMode.displayName} mode).',
    );
    exit(2);
  }

  final BuildOrchestrator orchestrator = BuildOrchestrator(config);
  final BuildReport report = BuildReport(<BuildStepResult>[
    await orchestrator.buildJasprServerImage(),
  ]);
  _printReport(report);
  if (report.anyFailed) {
    exit(1);
  }
}

/// `oracular build flutter-embed` — Flutter guest + Jaspr host bundle.
///
/// Convenience entry point that runs the embed flow without also
/// re-running every other build step. Internally this is just
/// [BuildOrchestrator.buildJaspr] in embed mode.
Future<void> handleBuildFlutterEmbed() async {
  final SetupConfig config = await _loadConfigOrExit();
  if (config.template != TemplateType.arcaneJasprFlutterEmbed) {
    error(
      'oracular build flutter-embed only applies to the '
      '${TemplateType.arcaneJasprFlutterEmbed.displayName} template.',
    );
    exit(2);
  }

  final BuildOrchestrator orchestrator = BuildOrchestrator(config);
  // For the embed flow we explicitly run the guest first, then the host,
  // so the CLI report surfaces both steps to the user.
  final BuildStepResult guest = await orchestrator.buildEmbeddedFlutter();
  final BuildStepResult host = guest.status == BuildStepStatus.failed
      ? BuildStepResult.skipped(
          BuildStepKind.jasprSite,
          'Jaspr build (Embed)',
          reason: 'Skipped because embedded Flutter build failed.',
        )
      : await orchestrator.buildJaspr();

  final BuildReport report = BuildReport(<BuildStepResult>[guest, host]);
  _printReport(report);
  if (report.anyFailed) {
    exit(1);
  }
}

/// `oracular build cli-binary` — `dart compile exe` for arcane_cli_app.
Future<void> handleBuildCli() async {
  final SetupConfig config = await _loadConfigOrExit();
  if (!config.template.isDartCli) {
    error(
      'oracular build cli-binary is only available for the arcane_cli_app template '
      '(this project uses ${config.template.displayName}).',
    );
    exit(2);
  }

  final BuildOrchestrator orchestrator = BuildOrchestrator(config);
  final BuildReport report = BuildReport(<BuildStepResult>[
    await orchestrator.buildDartCli(),
  ]);
  _printReport(report);
  if (report.anyFailed) {
    exit(1);
  }
}
