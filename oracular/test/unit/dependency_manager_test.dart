import 'dart:io';

import 'package:oracular/models/setup_config.dart';
import 'package:oracular/models/template_info.dart';
import 'package:oracular/services/dependency_manager.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/process_runner_fakes.dart';

void main() {
  group('DependencyManager', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('oracular_deps_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    SetupConfig cliConfig({bool createModels = false}) {
      return SetupConfig(
        appName: 'tool_app',
        orgDomain: 'com.example',
        baseClassName: 'ToolApp',
        template: TemplateType.arcaneCli,
        outputDir: tempDir.path,
        platforms: const <String>[],
        createModels: createModels,
      );
    }

    test(
      'getAllDependencies returns false when a package pub get fails',
      () async {
        final runner = ScriptedProcessRunner(
          results: <ProcessResult>[failureResult('pub get failed')],
        );
        final manager = DependencyManager(cliConfig(), runner: runner);

        expect(await manager.getAllDependencies(), isFalse);
        expect(runner.calls.single.executable, equals('dart'));
        expect(runner.calls.single.arguments, equals(<String>['pub', 'get']));
      },
    );

    test(
      'getAllDependencies returns true when all package pub gets pass',
      () async {
        final runner = ScriptedProcessRunner(
          results: <ProcessResult>[successResult(), successResult()],
        );
        final manager = DependencyManager(
          cliConfig(createModels: true),
          runner: runner,
        );

        expect(await manager.getAllDependencies(), isTrue);
        expect(runner.calls, hasLength(2));
      },
    );

    test('runAllBuildRunners returns false when build_runner fails', () async {
      final config = cliConfig(createModels: true);
      final Directory modelsDir = Directory(
        p.join(tempDir.path, config.modelsPackageName),
      );
      await modelsDir.create(recursive: true);
      await File(p.join(modelsDir.path, 'pubspec.yaml')).writeAsString('''
name: ${config.modelsPackageName}
dev_dependencies:
  build_runner: ^2.14.0
''');

      final runner = ScriptedProcessRunner(
        results: <ProcessResult>[failureResult('build failed')],
      );
      final manager = DependencyManager(config, runner: runner);

      expect(await manager.runAllBuildRunners(), isFalse);
      expect(
        runner.calls.single.arguments,
        equals(<String>[
          'run',
          'build_runner',
          'build',
          '--delete-conflicting-outputs',
        ]),
      );
    });

    test('runAllBuildRunners skips packages without build_runner', () async {
      final manager = DependencyManager(
        cliConfig(),
        runner: ScriptedProcessRunner(),
      );

      expect(await manager.runAllBuildRunners(), isTrue);
    });
  });
}
