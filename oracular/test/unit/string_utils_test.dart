import 'package:oracular/utils/string_utils.dart';
import 'package:test/test.dart';

void main() {
  group('snakeToPascal', () {
    test('converts simple snake_case to PascalCase', () {
      expect(snakeToPascal('my_app'), equals('MyApp'));
      expect(snakeToPascal('hello_world'), equals('HelloWorld'));
    });

    test('handles single words', () {
      expect(snakeToPascal('app'), equals('App'));
      expect(snakeToPascal('hello'), equals('Hello'));
    });

    test('handles multiple underscores', () {
      expect(snakeToPascal('my_cool_app_name'), equals('MyCoolAppName'));
    });

    test('handles empty strings', () {
      expect(snakeToPascal(''), equals(''));
    });

    test('handles single character', () {
      expect(snakeToPascal('a'), equals('A'));
    });

    test('handles numbers in names', () {
      expect(snakeToPascal('app_123'), equals('App123'));
      expect(snakeToPascal('my_app_2'), equals('MyApp2'));
    });
  });

  group('snakeToCamel', () {
    test('converts snake_case to camelCase', () {
      expect(snakeToCamel('my_app'), equals('myApp'));
      expect(snakeToCamel('hello_world'), equals('helloWorld'));
    });

    test('handles single words', () {
      expect(snakeToCamel('app'), equals('app'));
      expect(snakeToCamel('hello'), equals('hello'));
    });

    test('handles empty strings', () {
      expect(snakeToCamel(''), equals(''));
    });
  });

  group('toSnakeCase', () {
    test('converts PascalCase to snake_case', () {
      expect(toSnakeCase('MyApp'), equals('my_app'));
      expect(toSnakeCase('HelloWorld'), equals('hello_world'));
    });

    test('converts camelCase to snake_case', () {
      expect(toSnakeCase('myApp'), equals('my_app'));
      expect(toSnakeCase('helloWorld'), equals('hello_world'));
    });

    test('handles single words', () {
      expect(toSnakeCase('App'), equals('app'));
      expect(toSnakeCase('hello'), equals('hello'));
    });

    test('handles empty strings', () {
      expect(toSnakeCase(''), equals(''));
    });

    test('handles consecutive uppercase letters', () {
      expect(toSnakeCase('APIServer'), equals('a_p_i_server'));
    });
  });

  group('toKebabCase', () {
    test('converts snake_case to kebab-case', () {
      expect(toKebabCase('my_app'), equals('my-app'));
      expect(toKebabCase('hello_world'), equals('hello-world'));
    });

    test('handles single words', () {
      expect(toKebabCase('app'), equals('app'));
    });

    test('handles empty strings', () {
      expect(toKebabCase(''), equals(''));
    });
  });

  group('capitalize', () {
    test('capitalizes first letter', () {
      expect(capitalize('hello'), equals('Hello'));
      expect(capitalize('world'), equals('World'));
    });

    test('handles already capitalized strings', () {
      expect(capitalize('Hello'), equals('Hello'));
    });

    test('handles empty strings', () {
      expect(capitalize(''), equals(''));
    });

    test('handles single character', () {
      expect(capitalize('a'), equals('A'));
    });
  });

  group('lowercaseFirst', () {
    test('lowercases first letter', () {
      expect(lowercaseFirst('Hello'), equals('hello'));
      expect(lowercaseFirst('World'), equals('world'));
    });

    test('handles already lowercase strings', () {
      expect(lowercaseFirst('hello'), equals('hello'));
    });

    test('handles empty strings', () {
      expect(lowercaseFirst(''), equals(''));
    });
  });
}
