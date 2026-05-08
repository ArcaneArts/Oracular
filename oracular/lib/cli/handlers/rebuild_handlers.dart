import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../../models/setup_config.dart';
import '../../services/config_generator.dart';
import '../../services/dependency_manager.dart';
import '../../services/docs_generator.dart';
import '../../services/project_creator.dart';
import '../../services/project_purger.dart';
import '../../services/server_setup.dart';
import '../../services/template_copier.dart';
import '../../utils/setup_guidance.dart';
import '../../utils/user_prompt.dart';

/// Resolve the [SetupConfig] used by the rebuild flow.
///
/// Search order (first match wins):
///   1. `--config <path>` flag
///   2. `<cwd>/config/setup_config.env`
///   3. `<cwd>/setup_config.env`
///   4. `--output-dir <path>/config/setup_config.env`
Future<SetupConfig?> _resolveConfig({
  String? configPath,
  String? outputDir,
}) async {
  final List<String> candidates = <String>[];
  if (configPath != null && configPath.isNotEmpty) {
    candidates.add(p.absolute(configPath));
  }
  final String cwd = Directory.current.path;
  candidates.add(p.join(cwd, 'config', 'setup_config.env'));
  candidates.add(p.join(cwd, 'setup_config.env'));
  if (outputDir != null && outputDir.isNotEmpty) {
    candidates.add(p.join(p.absolute(outputDir), 'config', 'setup_config.env'));
  }

  for (final String candidate in candidates) {
    if (File(candidate).existsSync()) {
      verbose('Loading rebuild config from: $candidate');
      return SetupConfig.loadFromFile(candidate);
    }
  }

  error('Could not find setup_config.env.');
  UserPrompt.printList(<String>[
    'Searched: ${candidates.join('  ·  ')}',
    'Provide --config <path> or run from the directory that holds config/setup_config.env.',
  ]);
  return null;
}

/// Implementation of `oracular rebuild` / `oracular refresh`.
///
/// Reuses the SetupConfig saved by the original wizard run to:
///   1. Show the user exactly which folders will be purged.
///   2. Confirm (skipped with `--yes`).
///   3. Delete only the folders Oracular originally created (main app,
///      models, server, `.oracular_deps`, `references`). Firebase config
///      files, service-account keys, the saved config and docs are left
///      untouched.
///   4. Re-run the scaffolding pipeline: ProjectCreator → TemplateCopier
///      → DependencyManager (link models + pub get + build_runner) →
///      ConfigGenerator → ServerSetup → save config + docs.
///   5. Skip every Firebase / Cloud Run step (those don't change unless
///      the user re-runs `oracular deploy firebase-setup-full`).
Future<void> handleRebuild(
  Map<String, dynamic> args,
  Map<String, dynamic> flags,
) async {
  UserPrompt.printBanner(
    'Oracular Project Rebuild',
    subtitle: 'Purge + rescaffold without touching Firebase',
  );

  final String? configPathArg = args['config'] as String?;
  final String? outputDirArg = args['output-dir'] as String?;
  final bool yes = flags['yes'] == true;
  final bool dryRunOnly = flags['dry-run'] == true;

  final SetupConfig? config = await _resolveConfig(
    configPath: configPathArg,
    outputDir: outputDirArg,
  );
  if (config == null) {
    exit(1);
  }

  // Show what we're about to do BEFORE deletion.
  print('');
  UserPrompt.printConfigPreview(
    config.toDisplayMap(),
    title: 'Loaded configuration',
  );

  final ProjectPurger purger = ProjectPurger(config);
  final PurgeReport plan = purger.dryRun();

  print('');
  UserPrompt.printDivider(title: 'Rebuild plan');
  if (plan.directoriesToDelete.isEmpty) {
    info('Nothing to purge — none of the managed folders are present.');
    UserPrompt.printList(<String>[
      'The rebuild will proceed straight to scaffolding.',
    ]);
  } else {
    info('Will delete the following folders:');
    UserPrompt.printList(<String>[
      for (final String d in plan.directoriesToDelete)
        p.relative(d, from: config.outputDir),
    ]);
  }

  if (plan.alreadyMissing.isNotEmpty) {
    print('');
    info('Already missing (will be created fresh):');
    UserPrompt.printList(<String>[
      for (final String d in plan.alreadyMissing)
        p.relative(d, from: config.outputDir),
    ]);
  }

  print('');
  info('Will be preserved:');
  UserPrompt.printList(<String>[
    'config/setup_config.env (loaded above)',
    'firebase.json, .firebaserc, *.rules, *.indexes.json',
    'Service-account JSON files at the project root',
    'docs/ (will be regenerated)',
    'GET_STARTED.md (will be regenerated)',
  ]);

  if (dryRunOnly) {
    print('');
    info('Dry run only — no changes were made. Run without --dry-run to apply.');
    return;
  }

  print('');
  if (!yes) {
    final bool confirmed =
        await UserPrompt.askYesNo('Proceed with rebuild?', defaultValue: false);
    if (!confirmed) {
      warn('Rebuild cancelled.');
      return;
    }
  }

  // ── 1. Purge ─────────────────────────────────────────────────────────
  print('');
  UserPrompt.printDivider(title: 'Purging managed folders');
  final int deleted = await purger.purge(plan: plan);
  success('Deleted $deleted folder(s).');

  // ── 2. Rescaffold ────────────────────────────────────────────────────
  print('');
  UserPrompt.printDivider(title: 'Rescaffolding');

  final ProjectCreator creator = ProjectCreator(config);
  if (!await creator.createAllProjects()) {
    error('Project rescaffolding failed.');
    exit(1);
  }

  final TemplateCopier copier = await TemplateCopier.create(config);
  await copier.copyAll();
  await creator.deleteTestFolders();

  final DependencyManager depManager = DependencyManager(config);
  if (config.createModels) {
    await depManager.linkModelsToProjects();
  }
  await depManager.getAllDependencies();
  await depManager.runAllBuildRunners();

  // ── 3. Re-emit Firebase / server config files (idempotent overlays) ──
  if (config.useFirebase) {
    final ConfigGenerator configGenerator = ConfigGenerator(config);
    await configGenerator.generateAll();
  }
  if (config.createServer) {
    final ServerSetup serverSetup = ServerSetup(config);
    await serverSetup.generateAll();
  }

  // ── 4. Refresh saved config + guides (overwrite is fine) ─────────────
  final Directory configDir = Directory(p.join(config.outputDir, 'config'));
  if (!configDir.existsSync()) {
    await configDir.create(recursive: true);
  }
  await config.saveToFile(p.join(configDir.path, 'setup_config.env'));
  await SetupGuidance.writeProjectGuide(config);
  await DocsGenerator.write(config);

  print('');
  UserPrompt.printSuccessBox(
    'Rebuild complete!',
    details: <String>[
      'Source folders purged + rescaffolded',
      'Dependencies re-installed and code generation re-run',
      if (config.useFirebase)
        'Firebase setup left untouched — re-run `oracular deploy firebase-setup-full` if you need to re-bootstrap',
    ],
  );
  print('');
  UserPrompt.printList(SetupGuidance.createdProjectItems(config));
}
