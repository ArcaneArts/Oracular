import 'package:oracular/utils/prompt/select_prompt.dart';
import 'package:test/test.dart';

void main() {
  group('SelectPrompt.parseMultiSelectInput', () {
    test('returns defaults for empty input', () {
      expect(
        SelectPrompt.parseMultiSelectInput('', 4, <int>[0, 2]),
        equals(<int>[0, 2]),
      );
    });

    test('supports all and none shorthands', () {
      expect(
        SelectPrompt.parseMultiSelectInput('all', 3, <int>[]),
        equals(<int>[0, 1, 2]),
      );
      expect(
        SelectPrompt.parseMultiSelectInput('none', 3, <int>[0, 1]),
        isEmpty,
      );
    });

    test('supports comma-separated values and ranges', () {
      expect(
        SelectPrompt.parseMultiSelectInput('1, 3-4', 5, <int>[]),
        equals(<int>[0, 2, 3]),
      );
    });

    test('deduplicates selections while preserving order', () {
      expect(
        SelectPrompt.parseMultiSelectInput('2 2 1-2', 3, <int>[]),
        equals(<int>[1, 0]),
      );
    });

    test('rejects invalid selections', () {
      expect(
        () => SelectPrompt.parseMultiSelectInput('0', 3, <int>[]),
        throwsFormatException,
      );
      expect(
        () => SelectPrompt.parseMultiSelectInput('4', 3, <int>[]),
        throwsFormatException,
      );
      expect(
        () => SelectPrompt.parseMultiSelectInput('3-1', 3, <int>[]),
        throwsFormatException,
      );
    });
  });
}
