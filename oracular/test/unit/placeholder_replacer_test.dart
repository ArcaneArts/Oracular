import 'package:oracular/models/setup_config.dart';
import 'package:oracular/models/template_info.dart';
import 'package:oracular/services/placeholder_replacer.dart';
import 'package:test/test.dart';

void main() {
  late SetupConfig config;
  late PlaceholderReplacer replacer;

  setUp(() {
    config = SetupConfig(
      appName: 'my_app',
      orgDomain: 'com.example',
      baseClassName: 'MyApp',
      template: TemplateType.arcaneTemplate,
      outputDir: '/tmp/test',
      useFirebase: true,
      firebaseProjectId: 'my-firebase-project',
    );
    replacer = PlaceholderReplacer(config);
  });

  group('replaceInContent - canonical names', () {
    test('replaces arcane_app with snake_case name', () {
      final result = replacer.replaceInContent('name: arcane_app');
      expect(result, equals('name: my_app'));
    });

    test('replaces arcane_beamer_app with snake_case name', () {
      final beamerConfig = SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.example',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneBeamer,
        outputDir: '/tmp/test',
      );
      final beamerReplacer = PlaceholderReplacer(beamerConfig);
      final result = beamerReplacer.replaceInContent('name: arcane_beamer_app');
      expect(result, equals('name: my_app'));
    });

    test('replaces arcane_dock_app with snake_case name', () {
      final dockConfig = SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.example',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneDock,
        outputDir: '/tmp/test',
      );
      final dockReplacer = PlaceholderReplacer(dockConfig);
      final result = dockReplacer.replaceInContent('name: arcane_dock_app');
      expect(result, equals('name: my_app'));
    });

    test('replaces arcane_cli_app with snake_case name', () {
      final cliConfig = SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.example',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneCli,
        outputDir: '/tmp/test',
      );
      final cliReplacer = PlaceholderReplacer(cliConfig);
      final result = cliReplacer.replaceInContent('name: arcane_cli_app');
      expect(result, equals('name: my_app'));
    });

    test('replaces arcane_jaspr_app with web package name', () {
      final jasprConfig = SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.example',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneJaspr,
        outputDir: '/tmp/test',
      );
      final jasprReplacer = PlaceholderReplacer(jasprConfig);
      final result = jasprReplacer.replaceInContent('name: arcane_jaspr_app');
      expect(result, equals('name: my_app_web'));
    });

    test('replaces ArcaneJasprApp with PascalCase web class name', () {
      final jasprConfig = SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.example',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneJaspr,
        outputDir: '/tmp/test',
      );
      final jasprReplacer = PlaceholderReplacer(jasprConfig);
      final result = jasprReplacer.replaceInContent('class ArcaneJasprApp');
      expect(result, equals('class MyAppWeb'));
    });

    test('replaces package imports for arcane_jaspr_app', () {
      final result = replacer.replaceInContent(
        "import 'package:arcane_jaspr_app/main.dart';",
      );
      expect(result, equals("import 'package:my_app_web/main.dart';"));
    });

    test('replaces ArcaneServer with PascalCase server name', () {
      final result = replacer.replaceInContent('class ArcaneServer');
      expect(result, equals('class MyAppServer'));
    });

    test('replaces ArcaneRunner with PascalCase runner name', () {
      final result = replacer.replaceInContent('class ArcaneRunner');
      expect(result, equals('class MyAppRunner'));
    });

    test('replaces FIREBASE_PROJECT_ID', () {
      final result = replacer.replaceInContent('project: FIREBASE_PROJECT_ID');
      expect(result, equals('project: my-firebase-project'));
    });

    test('replaces package imports for arcane_app', () {
      final result = replacer.replaceInContent(
        "import 'package:arcane_app/main.dart';",
      );
      expect(result, equals("import 'package:my_app/main.dart';"));
    });

    test('replaces package imports for arcane_beamer_app', () {
      final result = replacer.replaceInContent(
        "import 'package:arcane_beamer_app/routes.dart';",
      );
      expect(result, equals("import 'package:my_app/routes.dart';"));
    });

    test('replaces package imports for arcane_dock_app', () {
      final result = replacer.replaceInContent(
        "import 'package:arcane_dock_app/main.dart';",
      );
      expect(result, equals("import 'package:my_app/main.dart';"));
    });

    test('replaces package imports for arcane_cli_app', () {
      final result = replacer.replaceInContent(
        "import 'package:arcane_cli_app/cli.dart';",
      );
      expect(result, equals("import 'package:my_app/cli.dart';"));
    });

    test('replaces arcane_models package imports', () {
      final result = replacer.replaceInContent(
        "import 'package:arcane_models/models.dart';",
      );
      expect(result, equals("import 'package:my_app_models/models.dart';"));
    });

    test('replaces arcane_server references', () {
      final result = replacer.replaceInContent('arcane_server');
      expect(result, equals('my_app_server'));
    });

    test('handles multiple replacements in same content', () {
      final content = '''
class ArcaneServer {
  final String project = 'FIREBASE_PROJECT_ID';
  final String name = 'arcane_app';
}
''';
      final expected = '''
class MyAppServer {
  final String project = 'my-firebase-project';
  final String name = 'my_app';
}
''';
      expect(replacer.replaceInContent(content), equals(expected));
    });

    test('preserves content without placeholders', () {
      const content = 'This is regular content with no placeholders.';
      expect(replacer.replaceInContent(content), equals(content));
    });

    test('replaces organization domain pattern', () {
      final result =
          replacer.replaceInContent('art.arcane.template.myapp');
      expect(result, contains('com.example.myapp'));
    });
  });

  group('replaceInFilename', () {
    test('replaces arcane_models.dart', () {
      final result = replacer.replaceInFilename('arcane_models.dart');
      expect(result, equals('my_app_models.dart'));
    });

    test('replaces arcane_app.dart', () {
      final result = replacer.replaceInFilename('arcane_app.dart');
      expect(result, equals('my_app.dart'));
    });

    test('replaces arcane_cli_app.dart', () {
      final result = replacer.replaceInFilename('arcane_cli_app.dart');
      expect(result, equals('my_app.dart'));
    });

    test('replaces arcane_cli_app.g.dart', () {
      final result = replacer.replaceInFilename('arcane_cli_app.g.dart');
      expect(result, equals('my_app.g.dart'));
    });

    test('replaces arcane_beamer_app.dart', () {
      final result = replacer.replaceInFilename('arcane_beamer_app.dart');
      expect(result, equals('my_app.dart'));
    });

    test('replaces arcane_dock_app.dart', () {
      final result = replacer.replaceInFilename('arcane_dock_app.dart');
      expect(result, equals('my_app.dart'));
    });

    test('replaces arcane_jaspr_app.dart', () {
      final result = replacer.replaceInFilename('arcane_jaspr_app.dart');
      expect(result, equals('my_app_web.dart'));
    });

    test('preserves filenames without placeholders', () {
      final result = replacer.replaceInFilename('main.dart');
      expect(result, equals('main.dart'));
    });
  });

  group('shouldProcessFile', () {
    test('returns true for Dart files', () {
      expect(replacer.shouldProcessFile('main.dart'), isTrue);
      expect(replacer.shouldProcessFile('/path/to/file.dart'), isTrue);
    });

    test('returns true for YAML files', () {
      expect(replacer.shouldProcessFile('pubspec.yaml'), isTrue);
      expect(replacer.shouldProcessFile('config.yml'), isTrue);
    });

    test('returns true for other text files', () {
      expect(replacer.shouldProcessFile('file.json'), isTrue);
      expect(replacer.shouldProcessFile('file.md'), isTrue);
      expect(replacer.shouldProcessFile('file.xml'), isTrue);
      expect(replacer.shouldProcessFile('file.plist'), isTrue);
    });

    test('returns false for binary files', () {
      expect(replacer.shouldProcessFile('icon.png'), isFalse);
      expect(replacer.shouldProcessFile('image.jpg'), isFalse);
      expect(replacer.shouldProcessFile('font.ttf'), isFalse);
    });
  });

  group('replacement order', () {
    test(
      'replaces class names before snake_case to avoid double replacement',
      () {
        // This tests that ArcaneServer becomes MyAppServer, not my_appServer
        final result = replacer.replaceInContent('ArcaneServer');
        expect(result, equals('MyAppServer'));
        expect(result, isNot(contains('my_app')));
      },
    );

    test('longer names replaced before shorter to avoid partial replacement',
        () {
      // arcane_beamer_app should be replaced before arcane_app would match
      final result = replacer.replaceInContent('arcane_beamer_app');
      expect(result, equals('my_app'));
      expect(result, isNot(contains('arcane')));
    });
  });

  group('edge cases', () {
    test('handles empty content', () {
      expect(replacer.replaceInContent(''), equals(''));
    });

    test('handles content with only whitespace', () {
      expect(replacer.replaceInContent('   \n\t  '), equals('   \n\t  '));
    });

    test('handles multiple occurrences of same placeholder', () {
      final result = replacer
          .replaceInContent('arcane_app arcane_app arcane_app');
      expect(result, equals('my_app my_app my_app'));
    });

    test('replaces within longer strings', () {
      // arcane_app within arcane_apple becomes my_app within my_apple
      // This is expected behavior since we use simple string replacement
      final result = replacer.replaceInContent('arcane_apple');
      expect(result, equals('my_apple'));
    });
  });
}
