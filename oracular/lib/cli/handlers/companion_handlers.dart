import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../../models/setup_config.dart';
import '../../models/template_info.dart';
import '../../utils/process_runner.dart' show ProcessResult, ProcessRunner;
import '../../utils/project_config_loader.dart';
import '../../utils/setup_guidance.dart';
import '../../utils/user_prompt.dart';

/// Show the next useful commands for the generated project at or above cwd.
Future<void> handleNext() async {
  final SetupConfig? config = await ProjectConfigLoader.load();
  print('');
  UserPrompt.printDivider(title: 'Next Steps');

  if (config == null) {
    UserPrompt.printNumberedList(<String>[
      'oracular check tools',
      'oracular new my_app',
      'oracular create',
      'oracular config init',
    ]);
    print('');
    info('Run this inside a generated project to get project-specific steps.');
    return;
  }

  UserPrompt.printNumberedList(<String>[
    'cd ${SetupGuidance.mainProjectPath(config)}',
    SetupGuidance.runCommand(config),
    'oracular verify',
    if (config.useFirebase) 'oracular deploy firebase-setup-full',
    if (config.useFirebase && SetupGuidance.supportsWebHosting(config))
      'oracular deploy hosting',
    if (config.createServer) 'oracular deploy arcane-server',
    if (config.hasJasprServer) 'oracular deploy jaspr-server',
    'oracular open guide',
  ]);
}

/// Verify generated packages without changing project structure.
Future<void> handleVerify(
  Map<String, dynamic> _,
  Map<String, dynamic> flags,
) async {
  final SetupConfig? config = await ProjectConfigLoader.load();
  if (config == null) {
    ProjectConfigLoader.printMissingConfigHelp();
    exit(1);
  }

  final bool runBuild = flags['build'] == true || flags['b'] == true;
  final ProcessRunner runner = ProcessRunner(
    maxAutoRetries: 0,
    interactive: false,
    showVerbose: true,
  );
  final List<_VerifyStep> steps = _buildVerifySteps(config, runBuild: runBuild);
  final List<String> failures = <String>[];

  print('');
  UserPrompt.printDivider(title: 'Verify Project');

  for (final _VerifyStep step in steps) {
    if (!Directory(step.workingDirectory).existsSync()) {
      failures.add('${step.label}: missing ${step.workingDirectory}');
      error('Missing: ${step.workingDirectory}');
      continue;
    }

    info(step.label);
    final ProcessResult result = await runner.run(
      step.executable,
      step.arguments,
      workingDirectory: step.workingDirectory,
    );
    if (!result.success) {
      failures.add(
        '${step.label}: ${step.executable} ${step.arguments.join(' ')}',
      );
      if (result.stderr.trim().isNotEmpty) {
        stderr.writeln(result.stderr.trim());
      }
      if (result.stdout.trim().isNotEmpty) {
        stdout.writeln(result.stdout.trim());
      }
    }
  }

  print('');
  if (failures.isEmpty) {
    success('Project verification passed.');
    return;
  }

  error('Project verification failed.');
  UserPrompt.printList(failures);
  exit(1);
}

List<_VerifyStep> _buildVerifySteps(
  SetupConfig config, {
  required bool runBuild,
}) {
  final List<_VerifyStep> steps = <_VerifyStep>[];

  void addPackage({
    required String label,
    required String path,
    required bool flutter,
  }) {
    steps.add(
      _VerifyStep(
        label: '$label dependencies',
        workingDirectory: path,
        executable: flutter ? 'flutter' : 'dart',
        arguments: const <String>['pub', 'get'],
      ),
    );
    steps.add(
      _VerifyStep(
        label: '$label analysis',
        workingDirectory: path,
        executable: flutter ? 'flutter' : 'dart',
        arguments: const <String>['analyze'],
      ),
    );
  }

  addPackage(
    label: SetupGuidance.mainProjectLabel(config),
    path: SetupGuidance.mainProjectPath(config),
    flutter: config.template.isFlutterApp,
  );

  if (config.template == TemplateType.arcaneJasprFlutterEmbed) {
    addPackage(
      label: 'Embedded Flutter app',
      path: p.join(config.outputDir, config.embeddedFlutterPackageName),
      flutter: true,
    );
  }

  if (config.createModels) {
    addPackage(
      label: 'Models package',
      path: p.join(config.outputDir, config.modelsPackageName),
      flutter: false,
    );
  }

  if (config.createServer) {
    addPackage(
      label: 'Server app',
      path: p.join(config.outputDir, config.serverPackageName),
      flutter: true,
    );
  }

  if (runBuild) {
    steps.addAll(_buildSteps(config));
  }

  return steps;
}

List<_VerifyStep> _buildSteps(SetupConfig config) {
  if (config.template.isFlutterApp) {
    if (!config.platforms.contains('web')) {
      return const <_VerifyStep>[];
    }
    return <_VerifyStep>[
      _VerifyStep(
        label: 'Flutter web build',
        workingDirectory: SetupGuidance.mainProjectPath(config),
        executable: 'flutter',
        arguments: const <String>['build', 'web', '--release'],
      ),
    ];
  }

  if (config.template.isJasprApp) {
    return <_VerifyStep>[
      _VerifyStep(
        label: 'Jaspr build',
        workingDirectory: SetupGuidance.mainProjectPath(config),
        executable: 'jaspr',
        arguments: const <String>['build'],
      ),
    ];
  }

  if (config.template.isDartCli) {
    return <_VerifyStep>[
      _VerifyStep(
        label: 'CLI compile',
        workingDirectory: SetupGuidance.mainProjectPath(config),
        executable: 'dart',
        arguments: const <String>['compile', 'exe', 'bin/main.dart'],
      ),
    ];
  }

  return const <_VerifyStep>[];
}

class _VerifyStep {
  const _VerifyStep({
    required this.label,
    required this.workingDirectory,
    required this.executable,
    required this.arguments,
  });

  final String label;
  final String workingDirectory;
  final String executable;
  final List<String> arguments;
}
