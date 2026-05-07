import 'dart:io';

import 'package:interact/interact.dart';

import 'prompt_environment.dart';

/// Selection prompts (menus, multi-select)
class SelectPrompt {
  /// Show a menu with arrow key navigation and get user selection
  static Future<int> showMenu(
    String title,
    List<String> options, {
    int? defaultIndex,
  }) async {
    if (options.isEmpty) {
      throw ArgumentError.value(options, 'options', 'Must not be empty');
    }

    if (PromptEnvironment.useSimplePrompts) {
      return _showSimpleMenu(title, options, defaultIndex: defaultIndex);
    }

    print('');
    try {
      final int result = Select(
        prompt: title,
        options: options,
        initialIndex: defaultIndex ?? 0,
      ).interact();
      return result;
    } on Object {
      return _showSimpleMenu(title, options, defaultIndex: defaultIndex);
    }
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
    if (options.isEmpty) {
      return <int>[];
    }

    // Convert defaultSelected names to boolean list if provided
    final List<bool> defaultBools = defaults ??
        options.map((String opt) {
          return defaultSelected?.contains(opt) ?? true;
        }).toList();

    if (PromptEnvironment.useSimplePrompts) {
      return _showSimpleMultiSelect(title, options, defaultBools);
    }

    print('');
    try {
      final List<int> result = MultiSelect(
        prompt: title,
        options: options,
        defaults: defaultBools,
      ).interact();
      return result;
    } on Object {
      return _showSimpleMultiSelect(title, options, defaultBools);
    }
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

    return showMenu(prompt, options, defaultIndex: initialIndex);
  }

  static int _showSimpleMenu(
    String title,
    List<String> options, {
    int? defaultIndex,
  }) {
    final int fallbackIndex = _clampDefaultIndex(defaultIndex ?? 0, options);

    print('');
    print(title);
    _printNumberedOptions(options);

    for (int attempt = 0; attempt < 3; attempt++) {
      stdout.write('Select 1-${options.length} [${fallbackIndex + 1}]: ');
      final String? input = stdin.readLineSync();
      final String value = input?.trim() ?? '';
      if (value.isEmpty) {
        return fallbackIndex;
      }

      final int? selected = int.tryParse(value);
      if (selected != null && selected >= 1 && selected <= options.length) {
        return selected - 1;
      }

      print('Enter a number between 1 and ${options.length}.');
    }

    return fallbackIndex;
  }

  static List<int> _showSimpleMultiSelect(
    String title,
    List<String> options,
    List<bool> defaultBools,
  ) {
    final List<int> defaults = _defaultIndices(defaultBools, options.length);

    print('');
    print(title);
    _printNumberedOptions(
      options,
      selectedIndices: defaults,
      showCheckboxes: true,
    );
    print('Use comma-separated numbers, ranges, "all", or "none".');

    for (int attempt = 0; attempt < 3; attempt++) {
      stdout.write('Select [${_formatDefaults(defaults)}]: ');
      final String? input = stdin.readLineSync();
      final String value = input?.trim() ?? '';

      try {
        return parseMultiSelectInput(value, options.length, defaults);
      } on FormatException catch (error) {
        print(error.message);
      }
    }

    return defaults;
  }

  /// Parses the simple prompt multi-select syntax.
  ///
  /// Values are 1-based for users and 0-based in the returned list.
  static List<int> parseMultiSelectInput(
    String input,
    int optionCount,
    List<int> defaultIndices,
  ) {
    final String normalized = input.trim().toLowerCase();
    if (normalized.isEmpty) {
      return List<int>.from(defaultIndices);
    }
    if (normalized == 'all') {
      return List<int>.generate(optionCount, (int index) => index);
    }
    if (normalized == 'none') {
      return <int>[];
    }

    final List<int> selected = <int>[];
    final Set<int> seen = <int>{};
    final List<String> tokens = normalized
        .split(RegExp(r'[\s,]+'))
        .where((String token) => token.isNotEmpty)
        .toList();

    for (final String token in tokens) {
      final List<int> parsed = _parseSelectionToken(token, optionCount);
      for (final int index in parsed) {
        if (seen.add(index)) {
          selected.add(index);
        }
      }
    }

    return selected;
  }

  static List<int> _parseSelectionToken(String token, int optionCount) {
    final RegExp rangePattern = RegExp(r'^(\d+)-(\d+)$');
    final RegExpMatch? range = rangePattern.firstMatch(token);
    if (range != null) {
      final int start = int.parse(range.group(1)!);
      final int end = int.parse(range.group(2)!);
      if (start > end) {
        throw FormatException('Invalid range: $token');
      }
      return <int>[
        for (int value = start; value <= end; value++)
          _toIndex(value, optionCount),
      ];
    }

    final int? value = int.tryParse(token);
    if (value == null) {
      throw FormatException('Invalid selection: $token');
    }
    return <int>[_toIndex(value, optionCount)];
  }

  static int _toIndex(int value, int optionCount) {
    if (value < 1 || value > optionCount) {
      throw FormatException('Selection out of range: $value');
    }
    return value - 1;
  }

  static int _clampDefaultIndex(int defaultIndex, List<String> options) {
    if (defaultIndex < 0) {
      return 0;
    }
    if (defaultIndex >= options.length) {
      return options.length - 1;
    }
    return defaultIndex;
  }

  static List<int> _defaultIndices(List<bool> defaults, int optionCount) {
    return <int>[
      for (int index = 0; index < optionCount; index++)
        if (index < defaults.length && defaults[index]) index,
    ];
  }

  static String _formatDefaults(List<int> defaults) {
    if (defaults.isEmpty) {
      return 'none';
    }
    return defaults.map((int index) => '${index + 1}').join(',');
  }

  static void _printNumberedOptions(
    List<String> options, {
    List<int> selectedIndices = const <int>[],
    bool showCheckboxes = false,
  }) {
    final Set<int> selected = selectedIndices.toSet();
    for (int i = 0; i < options.length; i++) {
      final String marker = selected.contains(i) ? '[x]' : '[ ]';
      final String option = options[i].replaceAll('\n', '\n      ');
      final String checkbox = showCheckboxes ? '$marker ' : '';
      print('  ${i + 1}. $checkbox$option');
    }
  }
}
