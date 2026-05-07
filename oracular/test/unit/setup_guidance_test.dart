import 'package:oracular/models/setup_config.dart';
import 'package:oracular/models/template_info.dart';
import 'package:oracular/utils/setup_guidance.dart';
import 'package:test/test.dart';

void main() {
  group('SetupGuidance', () {
    test('uses web package name for Jaspr templates', () {
      final SetupConfig config = SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.example',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneJaspr,
        outputDir: '/tmp/project',
      );

      expect(SetupGuidance.mainProjectName(config), equals('my_app_web'));
      expect(SetupGuidance.runCommand(config), equals('jaspr serve'));
    });

    test('uses app name for Flutter templates', () {
      final SetupConfig config = SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.example',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneTemplate,
        outputDir: '/tmp/project',
        platforms: const <String>['android', 'web'],
      );

      expect(SetupGuidance.mainProjectName(config), equals('my_app'));
      expect(SetupGuidance.runCommand(config), equals('flutter run'));
      expect(SetupGuidance.supportsWebHosting(config), isTrue);
    });

    test('detects non-web Flutter projects as not hostable', () {
      final SetupConfig config = SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.example',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneDock,
        outputDir: '/tmp/project',
        platforms: const <String>['linux', 'macos', 'windows'],
      );

      expect(SetupGuidance.supportsWebHosting(config), isFalse);
    });

    test('builds hosting URLs from project ID', () {
      expect(
        SetupGuidance.releaseHostingUrl('example-project'),
        equals('https://example-project.web.app'),
      );
      expect(
        SetupGuidance.betaHostingUrl('example-project'),
        equals('https://example-project-beta.web.app'),
      );
    });

    test('includes .oracular_deps item for Jaspr docs projects', () {
      final SetupConfig config = SetupConfig(
        appName: 'docs_site',
        orgDomain: 'com.example',
        baseClassName: 'DocsSite',
        template: TemplateType.arcaneJasprDocs,
        outputDir: '/tmp/project',
      );

      final List<String> items = SetupGuidance.createdProjectItems(config);
      expect(
        items.any((String item) => item.startsWith('.oracular_deps/')),
        isTrue,
      );
    });

    test('generates click-through Firebase and server guide content', () {
      final SetupConfig config = SetupConfig(
        appName: 'my_app',
        orgDomain: 'com.example',
        baseClassName: 'MyApp',
        template: TemplateType.arcaneTemplate,
        outputDir: '/tmp/project',
        createServer: true,
        useFirebase: true,
        firebaseProjectId: 'example-project',
        setupCloudRun: true,
        platforms: const <String>['web'],
      );

      final String guide = SetupGuidance.projectGuideMarkdown(config);

      expect(guide, contains('oracular open firebase'));
      expect(guide, contains('oracular open auth'));
      expect(guide, contains('oracular open cloud-run'));
      expect(
        guide,
        contains(
          SetupGuidance.firebaseAuthenticationConsoleUrl('example-project'),
        ),
      );
      expect(
        guide,
        contains(SetupGuidance.cloudRunConsoleUrl('example-project')),
      );
      expect(guide, contains('./script_deploy.sh'));
    });
  });
}
