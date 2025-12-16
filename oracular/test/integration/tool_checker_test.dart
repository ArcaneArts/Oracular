@TestOn('vm')
import 'package:oracular/services/tool_checker.dart';
import 'package:test/test.dart';

void main() {
  late ToolChecker checker;

  setUp(() {
    checker = ToolChecker();
  });

  group('ToolChecker', () {
    test('checks Flutter availability', () async {
      final status = await checker.checkFlutter();

      // Flutter should be installed on development machines
      // But we don't fail the test if it's not
      expect(status.name, equals('Flutter'));
      expect(status.isRequired, isTrue);

      if (status.isInstalled) {
        expect(status.version, isNotNull);
        expect(status.version, isNotEmpty);
      } else {
        expect(status.installInstructions, isNotNull);
      }
    });

    test('checks Dart availability', () async {
      final status = await checker.checkDart();

      expect(status.name, equals('Dart'));
      expect(status.isRequired, isTrue);

      if (status.isInstalled) {
        expect(status.version, isNotNull);
      }
    });

    test('checks Firebase CLI availability', () async {
      final status = await checker.checkFirebase();

      expect(status.name, equals('Firebase CLI'));
      expect(status.isRequired, isFalse);
    });

    test('checks Docker availability', () async {
      final status = await checker.checkDocker();

      expect(status.name, equals('Docker'));
      expect(status.isRequired, isFalse);
    });

    test('checkRequired returns result with all required tools', () async {
      final result = await checker.checkRequired();

      expect(result.tools, isNotEmpty);
      expect(result.tools.every((t) => t.isRequired), isTrue);
    });

    test('checkAll returns result with all tools', () async {
      final result = await checker.checkAll();

      expect(result.tools, isNotEmpty);
      expect(
        result.tools.length,
        greaterThan(2),
      ); // At least required + some optional
    });

    test('checkFirebaseTools returns Firebase-related tools', () async {
      final result = await checker.checkFirebaseTools();

      expect(result.tools, isNotEmpty);
      final toolNames = result.tools.map((t) => t.name).toList();
      expect(toolNames, contains('Firebase CLI'));
      expect(toolNames, contains('FlutterFire CLI'));
    });

    test('checkServerTools returns server deployment tools', () async {
      final result = await checker.checkServerTools();

      expect(result.tools, isNotEmpty);
      final toolNames = result.tools.map((t) => t.name).toList();
      expect(toolNames, contains('Docker'));
      expect(toolNames, contains('Google Cloud SDK'));
    });
  });

  group('ToolCheckResult', () {
    test('calculates allRequiredInstalled correctly', () async {
      final result = await checker.checkRequired();

      // allRequiredInstalled should be true if all required tools are installed
      final missingRequired = result.tools
          .where((t) => t.isRequired && !t.isInstalled)
          .toList();

      expect(result.allRequiredInstalled, equals(missingRequired.isEmpty));
      expect(result.missingRequired, equals(missingRequired));
    });

    test('calculates missingOptional correctly', () async {
      final result = await checker.checkAll();

      final missingOptional = result.tools
          .where((t) => !t.isRequired && !t.isInstalled)
          .toList();

      expect(result.missingOptional, equals(missingOptional));
    });
  });
}
