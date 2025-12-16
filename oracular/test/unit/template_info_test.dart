import 'package:oracular/models/template_info.dart';
import 'package:test/test.dart';

void main() {
  group('TemplateType', () {
    test('has correct display names', () {
      expect(TemplateType.arcaneTemplate.displayName, contains('Basic'));
      expect(TemplateType.arcaneBeamer.displayName, contains('Navigation'));
      expect(TemplateType.arcaneDock.displayName, contains('Desktop'));
      expect(TemplateType.arcaneCli.displayName, contains('CLI'));
    });

    test('has correct directory names (new canonical names)', () {
      expect(
        TemplateType.arcaneTemplate.directoryName,
        equals('arcane_app'),
      );
      expect(TemplateType.arcaneBeamer.directoryName, equals('arcane_beamer_app'));
      expect(TemplateType.arcaneDock.directoryName, equals('arcane_dock_app'));
      expect(TemplateType.arcaneCli.directoryName, equals('arcane_cli_app'));
    });

    test('has correct canonical package names', () {
      expect(
        TemplateType.arcaneTemplate.canonicalPackageName,
        equals('arcane_app'),
      );
      expect(
        TemplateType.arcaneBeamer.canonicalPackageName,
        equals('arcane_beamer_app'),
      );
      expect(
        TemplateType.arcaneDock.canonicalPackageName,
        equals('arcane_dock_app'),
      );
      expect(
        TemplateType.arcaneCli.canonicalPackageName,
        equals('arcane_cli_app'),
      );
    });

    test('has correct platform support', () {
      // arcane_template supports all platforms
      expect(
        TemplateType.arcaneTemplate.supportedPlatforms,
        contains('android'),
      );
      expect(TemplateType.arcaneTemplate.supportedPlatforms, contains('ios'));
      expect(TemplateType.arcaneTemplate.supportedPlatforms, contains('web'));

      // arcane_dock only supports desktop
      expect(TemplateType.arcaneDock.supportedPlatforms, contains('linux'));
      expect(TemplateType.arcaneDock.supportedPlatforms, contains('macos'));
      expect(TemplateType.arcaneDock.supportedPlatforms, contains('windows'));
      expect(
        TemplateType.arcaneDock.supportedPlatforms,
        isNot(contains('android')),
      );

      // arcane_cli has no Flutter platforms
      expect(TemplateType.arcaneCli.supportedPlatforms, isEmpty);
    });

    test('identifies Flutter vs CLI correctly', () {
      expect(TemplateType.arcaneTemplate.isFlutterApp, isTrue);
      expect(TemplateType.arcaneBeamer.isFlutterApp, isTrue);
      expect(TemplateType.arcaneDock.isFlutterApp, isTrue);
      expect(TemplateType.arcaneCli.isFlutterApp, isFalse);

      expect(TemplateType.arcaneCli.isDartCli, isTrue);
      expect(TemplateType.arcaneTemplate.isDartCli, isFalse);
    });

    test('has correct numbers', () {
      expect(TemplateType.arcaneTemplate.number, equals(1));
      expect(TemplateType.arcaneBeamer.number, equals(2));
      expect(TemplateType.arcaneDock.number, equals(3));
      expect(TemplateType.arcaneCli.number, equals(4));
    });
  });

  group('TemplateTypeExtension.parse', () {
    test('parses numbers correctly', () {
      expect(
        TemplateTypeExtension.parse('1'),
        equals(TemplateType.arcaneTemplate),
      );
      expect(
        TemplateTypeExtension.parse('2'),
        equals(TemplateType.arcaneBeamer),
      );
      expect(TemplateTypeExtension.parse('3'), equals(TemplateType.arcaneDock));
      expect(TemplateTypeExtension.parse('4'), equals(TemplateType.arcaneCli));
    });

    test('parses new directory names correctly', () {
      expect(
        TemplateTypeExtension.parse('arcane_app'),
        equals(TemplateType.arcaneTemplate),
      );
      expect(
        TemplateTypeExtension.parse('arcane_beamer_app'),
        equals(TemplateType.arcaneBeamer),
      );
      expect(
        TemplateTypeExtension.parse('arcane_dock_app'),
        equals(TemplateType.arcaneDock),
      );
      expect(
        TemplateTypeExtension.parse('arcane_cli_app'),
        equals(TemplateType.arcaneCli),
      );
    });

    test('parses enum names correctly', () {
      expect(
        TemplateTypeExtension.parse('arcaneTemplate'),
        equals(TemplateType.arcaneTemplate),
      );
      expect(
        TemplateTypeExtension.parse('arcanebeamer'),
        equals(TemplateType.arcaneBeamer),
      );
      expect(
        TemplateTypeExtension.parse('arcanedock'),
        equals(TemplateType.arcaneDock),
      );
      expect(
        TemplateTypeExtension.parse('arcanecli'),
        equals(TemplateType.arcaneCli),
      );
    });

    test('is case insensitive', () {
      expect(
        TemplateTypeExtension.parse('ARCANE_APP'),
        equals(TemplateType.arcaneTemplate),
      );
      expect(
        TemplateTypeExtension.parse('Arcane_Beamer_App'),
        equals(TemplateType.arcaneBeamer),
      );
    });

    test('returns null for invalid input', () {
      expect(TemplateTypeExtension.parse('5'), isNull);
      expect(TemplateTypeExtension.parse('invalid'), isNull);
      expect(TemplateTypeExtension.parse(''), isNull);
    });

    test('handles whitespace', () {
      expect(
        TemplateTypeExtension.parse('  1  '),
        equals(TemplateType.arcaneTemplate),
      );
      expect(
        TemplateTypeExtension.parse(' arcane_beamer_app '),
        equals(TemplateType.arcaneBeamer),
      );
    });
  });

  group('TemplateInfo', () {
    test('creates from type correctly', () {
      final info = TemplateInfo.fromType(TemplateType.arcaneTemplate);

      expect(info.type, equals(TemplateType.arcaneTemplate));
      expect(info.name, equals(TemplateType.arcaneTemplate.displayName));
      expect(info.description, equals(TemplateType.arcaneTemplate.description));
      expect(
        info.platforms,
        equals(TemplateType.arcaneTemplate.supportedPlatforms),
      );
      expect(info.isFlutter, equals(TemplateType.arcaneTemplate.isFlutterApp));
    });

    test('all returns all templates', () {
      final all = TemplateInfo.all;

      expect(all.length, equals(TemplateType.values.length));
      expect(all.map((t) => t.type), containsAll(TemplateType.values));
    });
  });
}
