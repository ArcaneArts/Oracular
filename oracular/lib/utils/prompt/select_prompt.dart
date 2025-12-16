import 'package:interact/interact.dart';

/// Selection prompts (menus, multi-select)
class SelectPrompt {
  /// Show a menu with arrow key navigation and get user selection
  static Future<int> showMenu(
    String title,
    List<String> options, {
    int? defaultIndex,
  }) async {
    print('');
    final int result = Select(
      prompt: title,
      options: options,
      initialIndex: defaultIndex ?? 0,
    ).interact();
    return result;
  }

  /// Show a menu and return the selected option string
  static Future<String> showMenuGetValue(
    String title,
    List<String> options, {
    int? defaultIndex,
  }) async {
    final int index = await showMenu(title, options, defaultIndex: defaultIndex);
    return options[index];
  }

  /// Multi-select with checkboxes and arrow key navigation
  static Future<List<int>> askMultiSelect(
    String title,
    List<String> options, {
    List<String>? defaultSelected,
    List<bool>? defaults,
  }) async {
    // Convert defaultSelected names to boolean list if provided
    final List<bool> defaultBools = defaults ??
        options.map((String opt) {
          return defaultSelected?.contains(opt) ?? true;
        }).toList();

    print('');
    final List<int> result = MultiSelect(
      prompt: title,
      options: options,
      defaults: defaultBools,
    ).interact();
    return result;
  }

  /// Multi-select that returns the selected option names
  static Future<List<String>> askMultiSelectNames(
    String title,
    List<String> options, {
    List<String>? defaultSelected,
  }) async {
    final List<int> indices = await askMultiSelect(
      title,
      options,
      defaultSelected: defaultSelected,
    );
    return indices.map((int i) => options[i]).toList();
  }

  /// Theme/option selector with descriptions
  static Future<int> askTheme(
    String prompt,
    List<String> themes,
    List<String> descriptions, {
    int initialIndex = 0,
  }) async {
    // Build options with descriptions
    final List<String> options = <String>[];
    for (int i = 0; i < themes.length; i++) {
      if (i < descriptions.length) {
        options.add('${themes[i]} - ${descriptions[i]}');
      } else {
        options.add(themes[i]);
      }
    }

    final int result = Select(
      prompt: prompt,
      options: options,
      initialIndex: initialIndex,
    ).interact();
    return result;
  }
}
