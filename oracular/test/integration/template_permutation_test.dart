@TestOn('vm')
import 'dart:io';

import 'package:oracular/models/setup_config.dart';
import 'package:oracular/models/template_info.dart';
import 'package:oracular/services/placeholder_replacer.dart';
import 'package:oracular/services/template_copier.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Get the templates path relative to the test directory
String getTemplatesPath() {
  // From test/integration/ we need to go up to oracular/, then up to Oracular/templates
  return p.normalize(p.join(Directory.current.path, '..', 'templates'));
}

/// Test configuration for a single permutation
class TestPermutation {
  final TemplateType template;
  final bool createModels;
  final bool createServer;

  TestPermutation({
    required this.template,
    required this.createModels,
    required this.createServer,
  });

  String get name =>
      '${template.name}_models${createModels ? "Yes" : "No"}_server${createServer ? "Yes" : "No"}';

  SetupConfig toConfig(String outputDir) => SetupConfig(
        appName: 'test_app',
        orgDomain: 'com.example',
        baseClassName: 'TestApp',
        template: template,
        outputDir: outputDir,
        createModels: createModels,
        createServer: createServer,
        useFirebase: false,
      );
}

void main() {
  // Generate all permutations
  final permutations = <TestPermutation>[];
  for (final template in TemplateType.values) {
    for (final models in [false, true]) {
      for (final server in [false, true]) {
        permutations.add(TestPermutation(
          template: template,
          createModels: models,
          createServer: server,
        ));
      }
    }
  }

  group('Template Permutation Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('oracular_permutation_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Template source directories exist', () {
      test('all template directories exist', () {
        // We need to find the templates path first
        final config = SetupConfig(
          appName: 'test',
          orgDomain: 'com.test',
          baseClassName: 'Test',
          template: TemplateType.arcaneTemplate,
          outputDir: tempDir.path,
        );
        final copier = TemplateCopier.withPath(config, getTemplatesPath());

        for (final template in TemplateType.values) {
          final templatePath = copier.getTemplatePath(template.directoryName);
          expect(
            Directory(templatePath).existsSync(),
            isTrue,
            reason: 'Template directory should exist: ${template.directoryName}',
          );
        }

        // Also check models and server
        expect(
          Directory(copier.getTemplatePath('arcane_models')).existsSync(),
          isTrue,
          reason: 'arcane_models template should exist',
        );
        expect(
          Directory(copier.getTemplatePath('arcane_server')).existsSync(),
          isTrue,
          reason: 'arcane_server template should exist',
        );
      });

      test('all templates have pubspec.yaml', () {
        final config = SetupConfig(
          appName: 'test',
          orgDomain: 'com.test',
          baseClassName: 'Test',
          template: TemplateType.arcaneTemplate,
          outputDir: tempDir.path,
        );
        final copier = TemplateCopier.withPath(config, getTemplatesPath());

        final templateNames = [
          ...TemplateType.values.map((t) => t.directoryName),
          'arcane_models',
          'arcane_server',
        ];

        for (final name in templateNames) {
          final pubspec =
              File(p.join(copier.getTemplatePath(name), 'pubspec.yaml'));
          expect(
            pubspec.existsSync(),
            isTrue,
            reason: 'pubspec.yaml should exist in $name',
          );
        }
      });

      test('all templates have lib directory', () {
        final config = SetupConfig(
          appName: 'test',
          orgDomain: 'com.test',
          baseClassName: 'Test',
          template: TemplateType.arcaneTemplate,
          outputDir: tempDir.path,
        );
        final copier = TemplateCopier.withPath(config, getTemplatesPath());

        final templateNames = [
          ...TemplateType.values.map((t) => t.directoryName),
          'arcane_models',
          'arcane_server',
        ];

        for (final name in templateNames) {
          final libDir = Directory(p.join(copier.getTemplatePath(name), 'lib'));
          expect(
            libDir.existsSync(),
            isTrue,
            reason: 'lib directory should exist in $name',
          );
        }
      });
    });

    group('PlaceholderReplacer content replacement', () {
      for (final template in TemplateType.values) {
        test('replaces canonical package name for ${template.name}', () {
          final config = SetupConfig(
            appName: 'my_cool_app',
            orgDomain: 'com.example',
            baseClassName: 'MyCoolApp',
            template: template,
            outputDir: tempDir.path,
          );
          final replacer = PlaceholderReplacer(config);

          // Test replacing canonical package name
          final input =
              "import 'package:${template.canonicalPackageName}/main.dart';";
          final result = replacer.replaceInContent(input);

          // Jaspr templates use webPackageName (my_cool_app_web), others use appName
          final expectedPackage =
              template.isJasprApp ? 'my_cool_app_web' : 'my_cool_app';
          expect(
            result,
            equals("import 'package:$expectedPackage/main.dart';"),
            reason:
                'Should replace ${template.canonicalPackageName} with $expectedPackage',
          );
        });
      }

      test('replaces arcane_models package', () {
        final config = SetupConfig(
          appName: 'my_app',
          orgDomain: 'com.example',
          baseClassName: 'MyApp',
          template: TemplateType.arcaneTemplate,
          outputDir: tempDir.path,
          createModels: true,
        );
        final replacer = PlaceholderReplacer(config);

        final input = "import 'package:arcane_models/models.dart';";
        final result = replacer.replaceInContent(input);
        expect(result, equals("import 'package:my_app_models/models.dart';"));
      });

      test('replaces arcane_server package', () {
        final config = SetupConfig(
          appName: 'my_app',
          orgDomain: 'com.example',
          baseClassName: 'MyApp',
          template: TemplateType.arcaneTemplate,
          outputDir: tempDir.path,
          createServer: true,
        );
        final replacer = PlaceholderReplacer(config);

        final input = 'arcane_server';
        final result = replacer.replaceInContent(input);
        expect(result, equals('my_app_server'));
      });

      test('replaces ArcaneServer class name', () {
        final config = SetupConfig(
          appName: 'my_app',
          orgDomain: 'com.example',
          baseClassName: 'MyApp',
          template: TemplateType.arcaneTemplate,
          outputDir: tempDir.path,
        );
        final replacer = PlaceholderReplacer(config);

        final input = 'class ArcaneServer';
        final result = replacer.replaceInContent(input);
        expect(result, equals('class MyAppServer'));
      });

      test('replaces ArcaneRunner class name', () {
        final config = SetupConfig(
          appName: 'my_app',
          orgDomain: 'com.example',
          baseClassName: 'MyApp',
          template: TemplateType.arcaneTemplate,
          outputDir: tempDir.path,
        );
        final replacer = PlaceholderReplacer(config);

        final input = 'class ArcaneRunner';
        final result = replacer.replaceInContent(input);
        expect(result, equals('class MyAppRunner'));
      });

      test('replaces Firebase project ID when provided', () {
        final config = SetupConfig(
          appName: 'my_app',
          orgDomain: 'com.example',
          baseClassName: 'MyApp',
          template: TemplateType.arcaneTemplate,
          outputDir: tempDir.path,
          useFirebase: true,
          firebaseProjectId: 'my-firebase-project',
        );
        final replacer = PlaceholderReplacer(config);

        final input = 'project: FIREBASE_PROJECT_ID';
        final result = replacer.replaceInContent(input);
        expect(result, equals('project: my-firebase-project'));
      });

      test('replaces organization domain', () {
        final config = SetupConfig(
          appName: 'my_app',
          orgDomain: 'com.mycompany',
          baseClassName: 'MyApp',
          template: TemplateType.arcaneTemplate,
          outputDir: tempDir.path,
        );
        final replacer = PlaceholderReplacer(config);

        final input = 'art.arcane.template.myapp';
        final result = replacer.replaceInContent(input);
        expect(result, equals('com.mycompany.myapp.myapp'));
      });
    });

    group('PlaceholderReplacer filename replacement', () {
      for (final template in TemplateType.values) {
        test('renames ${template.canonicalPackageName}.dart', () {
          final config = SetupConfig(
            appName: 'my_app',
            orgDomain: 'com.example',
            baseClassName: 'MyApp',
            template: template,
            outputDir: tempDir.path,
          );
          final replacer = PlaceholderReplacer(config);

          final result =
              replacer.replaceInFilename('${template.canonicalPackageName}.dart');

          // Jaspr templates use webPackageName (my_app_web), others use appName
          final expectedFilename =
              template.isJasprApp ? 'my_app_web.dart' : 'my_app.dart';
          expect(result, equals(expectedFilename));
        });
      }

      test('renames arcane_models.dart', () {
        final config = SetupConfig(
          appName: 'my_app',
          orgDomain: 'com.example',
          baseClassName: 'MyApp',
          template: TemplateType.arcaneTemplate,
          outputDir: tempDir.path,
        );
        final replacer = PlaceholderReplacer(config);

        final result = replacer.replaceInFilename('arcane_models.dart');
        expect(result, equals('my_app_models.dart'));
      });
    });

    // Test each permutation
    for (final permutation in permutations) {
      group('Permutation: ${permutation.name}', () {
        test('TemplateCopier can be instantiated', () {
          final config = permutation.toConfig(tempDir.path);
          final copier = TemplateCopier.withPath(config, getTemplatesPath());
          expect(copier.templatesBasePath, isNotEmpty);
        });

        test('template directory exists', () {
          final config = permutation.toConfig(tempDir.path);
          final copier = TemplateCopier.withPath(config, getTemplatesPath());
          final templatePath =
              copier.getTemplatePath(config.template.directoryName);
          expect(
            Directory(templatePath).existsSync(),
            isTrue,
            reason: 'Template ${config.template.directoryName} should exist',
          );
        });

        if (permutation.createModels) {
          test('models template directory exists', () {
            final config = permutation.toConfig(tempDir.path);
            final copier = TemplateCopier.withPath(config, getTemplatesPath());
            final modelsPath = copier.getTemplatePath('arcane_models');
            expect(
              Directory(modelsPath).existsSync(),
              isTrue,
              reason: 'Models template should exist',
            );
          });
        }

        if (permutation.createServer) {
          test('server template directory exists', () {
            final config = permutation.toConfig(tempDir.path);
            final copier = TemplateCopier.withPath(config, getTemplatesPath());
            final serverPath = copier.getTemplatePath('arcane_server');
            expect(
              Directory(serverPath).existsSync(),
              isTrue,
              reason: 'Server template should exist',
            );
          });
        }

        test('PlaceholderReplacer works for this config', () {
          final config = permutation.toConfig(tempDir.path);
          final replacer = PlaceholderReplacer(config);

          // Test basic replacement
          final canonicalName = config.template.canonicalPackageName;
          final input = "import 'package:$canonicalName/main.dart';";
          final result = replacer.replaceInContent(input);

          // Jaspr templates use webPackageName (test_app_web), others use appName
          final expectedPackage =
              config.template.isJasprApp ? 'test_app_web' : 'test_app';
          expect(result, equals("import 'package:$expectedPackage/main.dart';"));
        });
      });
    }
  });

  group('Full Copy Integration Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('oracular_copy_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    // Run actual copy tests for each template type
    for (final template in TemplateType.values) {
      test('copyAppTemplate works for ${template.name}', () async {
        final config = SetupConfig(
          appName: 'test_${template.name.toLowerCase()}',
          orgDomain: 'com.test',
          baseClassName: 'Test${template.name}',
          template: template,
          outputDir: tempDir.path,
          createModels: false,
          createServer: false,
        );

        final copier = TemplateCopier.withPath(config, getTemplatesPath());

        // Only test if template exists
        final templatePath = copier.getTemplatePath(template.directoryName);
        if (!Directory(templatePath).existsSync()) {
          print('Skipping ${template.name} - template not found');
          return;
        }

        await copier.copyAppTemplate();

        // Verify output directory was created
        // For Jaspr templates, use webPackageName; for others, use appName
        final expectedDirName =
            template.isJasprApp ? config.webPackageName : config.appName;
        final outputDir = Directory(p.join(tempDir.path, expectedDirName));
        expect(outputDir.existsSync(), isTrue,
            reason: 'Output directory should be created');

        // Verify pubspec.yaml was copied and modified
        final pubspec = File(p.join(outputDir.path, 'pubspec.yaml'));
        expect(pubspec.existsSync(), isTrue,
            reason: 'pubspec.yaml should exist');

        final pubspecContent = await pubspec.readAsString();
        expect(pubspecContent, contains('name: $expectedDirName'),
            reason: 'pubspec should have correct name');

        // Verify lib directory exists
        final libDir = Directory(p.join(outputDir.path, 'lib'));
        expect(libDir.existsSync(), isTrue,
            reason: 'lib directory should exist');

        // Verify no canonical names remain in Dart files
        await for (final entity in libDir.list(recursive: true)) {
          if (entity is File && entity.path.endsWith('.dart')) {
            final content = await entity.readAsString();
            expect(
              content,
              isNot(contains('package:${template.canonicalPackageName}/')),
              reason:
                  'File ${entity.path} should not contain canonical package name',
            );
          }
        }
      });
    }

    test('copyModelsTemplate works', () async {
      final config = SetupConfig(
        appName: 'test_app',
        orgDomain: 'com.test',
        baseClassName: 'TestApp',
        template: TemplateType.arcaneTemplate,
        outputDir: tempDir.path,
        createModels: true,
        createServer: false,
      );

      final copier = TemplateCopier.withPath(config, getTemplatesPath());

      // Only test if template exists
      final modelsPath = copier.getTemplatePath('arcane_models');
      if (!Directory(modelsPath).existsSync()) {
        print('Skipping models test - template not found');
        return;
      }

      await copier.copyModelsTemplate();

      // Verify output directory was created
      final outputDir =
          Directory(p.join(tempDir.path, config.modelsPackageName));
      expect(outputDir.existsSync(), isTrue,
          reason: 'Models output directory should be created');

      // Verify pubspec.yaml was copied and modified
      final pubspec = File(p.join(outputDir.path, 'pubspec.yaml'));
      expect(pubspec.existsSync(), isTrue,
          reason: 'pubspec.yaml should exist');

      final pubspecContent = await pubspec.readAsString();
      expect(pubspecContent, contains('name: ${config.modelsPackageName}'),
          reason: 'pubspec should have correct name');
    });

    test('copyServerTemplate works', () async {
      final config = SetupConfig(
        appName: 'test_app',
        orgDomain: 'com.test',
        baseClassName: 'TestApp',
        template: TemplateType.arcaneTemplate,
        outputDir: tempDir.path,
        createModels: false,
        createServer: true,
      );

      final copier = TemplateCopier.withPath(config, getTemplatesPath());

      // Only test if template exists
      final serverPath = copier.getTemplatePath('arcane_server');
      if (!Directory(serverPath).existsSync()) {
        print('Skipping server test - template not found');
        return;
      }

      await copier.copyServerTemplate();

      // Verify output directory was created
      final outputDir =
          Directory(p.join(tempDir.path, config.serverPackageName));
      expect(outputDir.existsSync(), isTrue,
          reason: 'Server output directory should be created');

      // Verify pubspec.yaml was copied and modified
      final pubspec = File(p.join(outputDir.path, 'pubspec.yaml'));
      expect(pubspec.existsSync(), isTrue,
          reason: 'pubspec.yaml should exist');

      final pubspecContent = await pubspec.readAsString();
      expect(pubspecContent, contains('name: ${config.serverPackageName}'),
          reason: 'pubspec should have correct name');
    });

    test('copyAll creates all requested packages', () async {
      final config = SetupConfig(
        appName: 'full_test_app',
        orgDomain: 'com.fulltest',
        baseClassName: 'FullTestApp',
        template: TemplateType.arcaneTemplate,
        outputDir: tempDir.path,
        createModels: true,
        createServer: true,
      );

      final copier = TemplateCopier.withPath(config, getTemplatesPath());

      // Only test if all templates exist
      final appPath = copier.getTemplatePath(config.template.directoryName);
      final modelsPath = copier.getTemplatePath('arcane_models');
      final serverPath = copier.getTemplatePath('arcane_server');

      if (!Directory(appPath).existsSync() ||
          !Directory(modelsPath).existsSync() ||
          !Directory(serverPath).existsSync()) {
        print('Skipping copyAll test - some templates not found');
        return;
      }

      await copier.copyAll();

      // Verify app was created
      expect(
        Directory(p.join(tempDir.path, config.appName)).existsSync(),
        isTrue,
        reason: 'App directory should be created',
      );

      // Verify models was created
      expect(
        Directory(p.join(tempDir.path, config.modelsPackageName)).existsSync(),
        isTrue,
        reason: 'Models directory should be created',
      );

      // Verify server was created
      expect(
        Directory(p.join(tempDir.path, config.serverPackageName)).existsSync(),
        isTrue,
        reason: 'Server directory should be created',
      );

      // Verify references was created (only if references template exists)
      final referencesTemplate = Directory(copier.getTemplatePath('references'));
      if (referencesTemplate.existsSync()) {
        expect(
          Directory(p.join(tempDir.path, 'references')).existsSync(),
          isTrue,
          reason: 'References directory should be created',
        );
      }
    });
  });

  group('Template Compilation Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('oracular_compile_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    for (final template in TemplateType.values) {
      test(
        '${template.name} template compiles successfully',
        () async {
          final config = SetupConfig(
            appName: 'compile_test',
            orgDomain: 'com.test',
            baseClassName: 'CompileTest',
            template: template,
            outputDir: tempDir.path,
            createModels: false,
            createServer: false,
          );

          final copier = TemplateCopier.withPath(config, getTemplatesPath());

          // Skip if template doesn't exist
          final templatePath = copier.getTemplatePath(template.directoryName);
          if (!Directory(templatePath).existsSync()) {
            print('Skipping ${template.name} - template not found');
            return;
          }

          // Copy the template
          await copier.copyAppTemplate();

          // Get output directory name
          final outputDirName =
              template.isJasprApp ? config.webPackageName : config.appName;
          final projectDir = Directory(p.join(tempDir.path, outputDirName));
          expect(projectDir.existsSync(), isTrue,
              reason: 'Project directory should exist after copy');

          // Run pub get first
          late ProcessResult pubResult;
          if (template.isFlutterApp) {
            pubResult = await Process.run(
              'flutter',
              ['pub', 'get'],
              workingDirectory: projectDir.path,
            );
          } else if (template.isJasprApp) {
            // For Jaspr, use dart pub get
            pubResult = await Process.run(
              'dart',
              ['pub', 'get'],
              workingDirectory: projectDir.path,
            );
          } else {
            // Dart CLI
            pubResult = await Process.run(
              'dart',
              ['pub', 'get'],
              workingDirectory: projectDir.path,
            );
          }

          expect(
            pubResult.exitCode,
            equals(0),
            reason:
                'pub get should succeed for ${template.name}:\n${pubResult.stderr}',
          );

          // Run analyze/build based on template type
          late ProcessResult compileResult;
          if (template.isFlutterApp) {
            // Flutter analyze checks for compile errors
            compileResult = await Process.run(
              'flutter',
              ['analyze', '--no-fatal-infos', '--no-fatal-warnings'],
              workingDirectory: projectDir.path,
            );
          } else if (template.isJasprApp) {
            // For Jaspr, run jaspr build to verify it compiles
            compileResult = await Process.run(
              'jaspr',
              ['build'],
              workingDirectory: projectDir.path,
            );
          } else {
            // Dart CLI - use dart analyze (no --no-fatal-infos flag in dart)
            compileResult = await Process.run(
              'dart',
              ['analyze'],
              workingDirectory: projectDir.path,
            );
          }

          expect(
            compileResult.exitCode,
            equals(0),
            reason:
                '${template.name} should compile/analyze successfully:\n${compileResult.stdout}\n${compileResult.stderr}',
          );
        },
        timeout: const Timeout(Duration(minutes: 5)),
      );
    }

    // Test with models package
    test(
      'arcaneTemplate with models compiles successfully',
      () async {
        final config = SetupConfig(
          appName: 'models_test',
          orgDomain: 'com.test',
          baseClassName: 'ModelsTest',
          template: TemplateType.arcaneTemplate,
          outputDir: tempDir.path,
          createModels: true,
          createServer: false,
        );

        final copier = TemplateCopier.withPath(config, getTemplatesPath());

        // Skip if templates don't exist
        final appPath = copier.getTemplatePath(config.template.directoryName);
        final modelsPath = copier.getTemplatePath('arcane_models');
        if (!Directory(appPath).existsSync() ||
            !Directory(modelsPath).existsSync()) {
          print('Skipping models test - templates not found');
          return;
        }

        // Copy both templates
        await copier.copyAppTemplate();
        await copier.copyModelsTemplate();

        // Verify models package compiles
        final modelsDir =
            Directory(p.join(tempDir.path, config.modelsPackageName));
        expect(modelsDir.existsSync(), isTrue,
            reason: 'Models directory should exist');

        var pubResult = await Process.run(
          'dart',
          ['pub', 'get'],
          workingDirectory: modelsDir.path,
        );
        expect(pubResult.exitCode, equals(0),
            reason: 'Models pub get should succeed:\n${pubResult.stderr}');

        var analyzeResult = await Process.run(
          'dart',
          ['analyze'],
          workingDirectory: modelsDir.path,
        );
        expect(analyzeResult.exitCode, equals(0),
            reason: 'Models should analyze successfully:\n${analyzeResult.stderr}');

        // Verify app compiles (may have dependency on models)
        final appDir = Directory(p.join(tempDir.path, config.appName));
        expect(appDir.existsSync(), isTrue, reason: 'App directory should exist');

        pubResult = await Process.run(
          'flutter',
          ['pub', 'get'],
          workingDirectory: appDir.path,
        );
        expect(pubResult.exitCode, equals(0),
            reason: 'App pub get should succeed:\n${pubResult.stderr}');

        analyzeResult = await Process.run(
          'flutter',
          ['analyze', '--no-fatal-infos', '--no-fatal-warnings'],
          workingDirectory: appDir.path,
        );
        expect(analyzeResult.exitCode, equals(0),
            reason: 'App should analyze successfully:\n${analyzeResult.stderr}');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    // Test with server package (requires models since server depends on it)
    test(
      'arcaneTemplate with server compiles successfully',
      () async {
        final config = SetupConfig(
          appName: 'server_test',
          orgDomain: 'com.test',
          baseClassName: 'ServerTest',
          template: TemplateType.arcaneTemplate,
          outputDir: tempDir.path,
          createModels: true, // Server requires models
          createServer: true,
        );

        final copier = TemplateCopier.withPath(config, getTemplatesPath());

        // Skip if templates don't exist
        final appPath = copier.getTemplatePath(config.template.directoryName);
        final modelsPath = copier.getTemplatePath('arcane_models');
        final serverPath = copier.getTemplatePath('arcane_server');
        if (!Directory(appPath).existsSync() ||
            !Directory(modelsPath).existsSync() ||
            !Directory(serverPath).existsSync()) {
          print('Skipping server test - templates not found');
          return;
        }

        // Copy all required templates (server depends on models)
        await copier.copyAppTemplate();
        await copier.copyModelsTemplate();
        await copier.copyServerTemplate();

        // First get and analyze models (server depends on it)
        final modelsDir =
            Directory(p.join(tempDir.path, config.modelsPackageName));
        var pubResult = await Process.run(
          'dart',
          ['pub', 'get'],
          workingDirectory: modelsDir.path,
        );
        expect(pubResult.exitCode, equals(0),
            reason: 'Models pub get should succeed:\n${pubResult.stderr}');

        // Verify server package compiles
        final serverDir =
            Directory(p.join(tempDir.path, config.serverPackageName));
        expect(serverDir.existsSync(), isTrue,
            reason: 'Server directory should exist');

        pubResult = await Process.run(
          'dart',
          ['pub', 'get'],
          workingDirectory: serverDir.path,
        );
        expect(pubResult.exitCode, equals(0),
            reason: 'Server pub get should succeed:\n${pubResult.stderr}');

        var analyzeResult = await Process.run(
          'dart',
          ['analyze'],
          workingDirectory: serverDir.path,
        );
        expect(analyzeResult.exitCode, equals(0),
            reason: 'Server should analyze successfully:\n${analyzeResult.stderr}');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    // Full permutation test with models + server
    test(
      'arcaneTemplate with models and server compiles successfully',
      () async {
        final config = SetupConfig(
          appName: 'full_test',
          orgDomain: 'com.test',
          baseClassName: 'FullTest',
          template: TemplateType.arcaneTemplate,
          outputDir: tempDir.path,
          createModels: true,
          createServer: true,
        );

        final copier = TemplateCopier.withPath(config, getTemplatesPath());

        // Skip if templates don't exist
        final appPath = copier.getTemplatePath(config.template.directoryName);
        final modelsPath = copier.getTemplatePath('arcane_models');
        final serverPath = copier.getTemplatePath('arcane_server');
        if (!Directory(appPath).existsSync() ||
            !Directory(modelsPath).existsSync() ||
            !Directory(serverPath).existsSync()) {
          print('Skipping full test - templates not found');
          return;
        }

        // Copy all templates
        await copier.copyAll();

        // Verify models compiles first (no dependencies)
        final modelsDir =
            Directory(p.join(tempDir.path, config.modelsPackageName));
        var pubResult = await Process.run(
          'dart',
          ['pub', 'get'],
          workingDirectory: modelsDir.path,
        );
        expect(pubResult.exitCode, equals(0),
            reason: 'Models pub get should succeed');

        var analyzeResult = await Process.run(
          'dart',
          ['analyze'],
          workingDirectory: modelsDir.path,
        );
        expect(analyzeResult.exitCode, equals(0),
            reason: 'Models should analyze successfully');

        // Verify server compiles
        final serverDir =
            Directory(p.join(tempDir.path, config.serverPackageName));
        pubResult = await Process.run(
          'dart',
          ['pub', 'get'],
          workingDirectory: serverDir.path,
        );
        expect(pubResult.exitCode, equals(0),
            reason: 'Server pub get should succeed');

        analyzeResult = await Process.run(
          'dart',
          ['analyze'],
          workingDirectory: serverDir.path,
        );
        expect(analyzeResult.exitCode, equals(0),
            reason: 'Server should analyze successfully');

        // Verify app compiles
        final appDir = Directory(p.join(tempDir.path, config.appName));
        pubResult = await Process.run(
          'flutter',
          ['pub', 'get'],
          workingDirectory: appDir.path,
        );
        expect(pubResult.exitCode, equals(0),
            reason: 'App pub get should succeed');

        analyzeResult = await Process.run(
          'flutter',
          ['analyze', '--no-fatal-infos', '--no-fatal-warnings'],
          workingDirectory: appDir.path,
        );
        expect(analyzeResult.exitCode, equals(0),
            reason: 'App should analyze successfully');
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  });

  group('No Canonical Names Remaining Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('oracular_canonical_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    for (final template in TemplateType.values) {
      test(
          'no canonical names remain after copying ${template.name} template',
          () async {
        final config = SetupConfig(
          appName: 'my_custom_app',
          orgDomain: 'com.custom',
          baseClassName: 'MyCustomApp',
          template: template,
          outputDir: tempDir.path,
          createModels: true,
          createServer: true,
        );

        final copier = TemplateCopier.withPath(config, getTemplatesPath());

        // Skip if templates don't exist
        if (!Directory(copier.getTemplatePath(template.directoryName))
            .existsSync()) {
          print('Skipping ${template.name} - template not found');
          return;
        }

        await copier.copyAll();

        // List of canonical names that should NOT appear
        final canonicalNames = [
          'arcane_app',
          'arcane_beamer_app',
          'arcane_dock_app',
          'arcane_cli_app',
          'arcane_models',
          'arcane_server',
          'ArcaneServer',
          'ArcaneRunner',
        ];

        // Check all Dart, YAML, and other text files
        final outputDir = Directory(tempDir.path);
        await for (final entity in outputDir.list(recursive: true)) {
          if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            if (['.dart', '.yaml', '.yml'].contains(ext)) {
              final content = await entity.readAsString();
              for (final canonicalName in canonicalNames) {
                // Skip checking for arcane_models/arcane_server in commented lines
                // as they might be in template comments explaining structure
                if (canonicalName == 'arcane_models' ||
                    canonicalName == 'arcane_server') {
                  // Check it's not in package imports
                  expect(
                    content,
                    isNot(contains('package:$canonicalName/')),
                    reason:
                        'File ${entity.path} should not contain package:$canonicalName/',
                  );
                } else {
                  expect(
                    content,
                    isNot(contains(canonicalName)),
                    reason:
                        'File ${entity.path} should not contain $canonicalName',
                  );
                }
              }
            }
          }
        }
      });
    }
  });
}
