import 'package:fast_log/fast_log.dart';
import 'package:interact/interact.dart';

/// Sorting/ordering prompts
class SortPrompt {
  /// Let user sort/order a list of items by preference
  /// Returns the sorted list of options
  static Future<List<String>> askSort(
    String title,
    List<String> options, {
    bool showOutput = true,
  }) async {
    print('');
    print('  Use ↑↓ to navigate, Shift+↑↓ to reorder, Enter to confirm');
    final List<String> result = Sort(
      prompt: title,
      options: options,
      showOutput: showOutput,
    ).interact();
    return result;
  }

  /// Sort and return the sorted option names (alias for askSort)
  static Future<List<String>> askSortGetValues(
    String title,
    List<String> options, {
    bool showOutput = true,
  }) async {
    final List<String> result = await askSort(title, options, showOutput: showOutput);
    return result;
  }

  /// Ask user to prioritize features/options
  static Future<List<String>> askPrioritize(
    String title,
    List<String> items,
  ) async {
    print('');
    info('Arrange items in order of priority (most important first)');
    final List<String> result = await askSortGetValues(title, items);
    return result;
  }
}
