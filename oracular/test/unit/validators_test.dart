import 'package:oracular/utils/validators.dart';
import 'package:test/test.dart';

void main() {
  group('validateAppName', () {
    test('accepts valid snake_case names', () {
      expect(validateAppName('my_app').isValid, isTrue);
      expect(validateAppName('app').isValid, isTrue);
      expect(validateAppName('my_cool_app_123').isValid, isTrue);
      expect(validateAppName('a').isValid, isTrue);
    });

    test('rejects empty names', () {
      final result = validateAppName('');
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('empty'));
    });

    test('rejects names with spaces', () {
      final result = validateAppName('my app');
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('spaces'));
    });

    test('rejects uppercase names', () {
      final result = validateAppName('MyApp');
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('lowercase'));
    });

    test('rejects names starting with numbers', () {
      final result = validateAppName('123app');
      expect(result.isValid, isFalse);
    });

    test('rejects Dart reserved words', () {
      final result = validateAppName('class');
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('reserved'));
    });

    test('rejects names with special characters', () {
      expect(validateAppName('my-app').isValid, isFalse);
      expect(validateAppName('my.app').isValid, isFalse);
      expect(validateAppName('my@app').isValid, isFalse);
    });
  });

  group('validateFirebaseProjectId', () {
    test('accepts valid project IDs', () {
      expect(validateFirebaseProjectId('my-project').isValid, isTrue);
      expect(validateFirebaseProjectId('my-project-123').isValid, isTrue);
      expect(validateFirebaseProjectId('project123').isValid, isTrue);
    });

    test('rejects empty IDs', () {
      final result = validateFirebaseProjectId('');
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('empty'));
    });

    test('rejects IDs with spaces', () {
      final result = validateFirebaseProjectId('my project');
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('spaces'));
    });

    test('rejects IDs that are too short', () {
      final result = validateFirebaseProjectId('abc');
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('6 and 30'));
    });

    test('rejects IDs that are too long', () {
      final result = validateFirebaseProjectId('a' * 31);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('6 and 30'));
    });
  });

  group('validateOrgDomain', () {
    test('accepts valid reverse domain notation', () {
      expect(validateOrgDomain('com.example').isValid, isTrue);
      expect(validateOrgDomain('art.arcane').isValid, isTrue);
      expect(validateOrgDomain('com.example.app').isValid, isTrue);
    });

    test('rejects empty domains', () {
      final result = validateOrgDomain('');
      expect(result.isValid, isFalse);
    });

    test('rejects domains with spaces', () {
      final result = validateOrgDomain('com. example');
      expect(result.isValid, isFalse);
    });

    test('rejects single-part domains', () {
      final result = validateOrgDomain('example');
      expect(result.isValid, isFalse);
    });
  });

  group('validateTemplate', () {
    test('accepts valid template numbers', () {
      expect(validateTemplate('1').isValid, isTrue);
      expect(validateTemplate('2').isValid, isTrue);
      expect(validateTemplate('3').isValid, isTrue);
      expect(validateTemplate('4').isValid, isTrue);
    });

    test('accepts valid template names', () {
      expect(validateTemplate('arcane_template').isValid, isTrue);
      expect(validateTemplate('arcane_beamer').isValid, isTrue);
      expect(validateTemplate('arcane_dock').isValid, isTrue);
      expect(validateTemplate('arcane_cli').isValid, isTrue);
    });

    test('rejects invalid templates', () {
      expect(validateTemplate('5').isValid, isFalse);
      expect(validateTemplate('invalid').isValid, isFalse);
      expect(validateTemplate('').isValid, isFalse);
    });
  });

  group('validateNotEmpty', () {
    test('accepts non-empty strings', () {
      expect(validateNotEmpty('hello', 'field').isValid, isTrue);
      expect(validateNotEmpty(' a ', 'field').isValid, isTrue);
    });

    test('rejects empty strings', () {
      final result = validateNotEmpty('', 'field');
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('field'));
    });

    test('rejects whitespace-only strings', () {
      final result = validateNotEmpty('   ', 'field');
      expect(result.isValid, isFalse);
    });
  });
}
