import 'dart:io';

import 'package:interact/interact.dart';

import 'prompt_environment.dart';

/// Confirmation prompts (yes/no questions)
class ConfirmPrompt {
  /// Ask a yes/no question with arrow key selection
  static Future<bool> askYesNo(
    String question, {
    bool defaultValue = true,
  }) async {
    if (PromptEnvironment.useSimplePrompts) {
      return _askSimpleYesNo(question, defaultValue: defaultValue);
    }

    try {
      final bool result = Confirm(
        prompt: question,
        defaultValue: defaultValue,
        waitForNewLine: true,
      ).interact();
      return result;
    } on Object {
      return _askSimpleYesNo(question, defaultValue: defaultValue);
    }
  }

  /// Ask for confirmation with custom yes/no labels
  static Future<bool> askConfirm(
    String question, {
    bool defaultValue = true,
    String yesLabel = 'Yes',
    String noLabel = 'No',
  }) async {
    if (PromptEnvironment.useSimplePrompts) {
      return _askSimpleYesNo(
        question,
        defaultValue: defaultValue,
        yesLabel: yesLabel,
        noLabel: noLabel,
      );
    }

    try {
      final int choice = Select(
        prompt: question,
        options: <String>[yesLabel, noLabel],
        initialIndex: defaultValue ? 0 : 1,
      ).interact();
      return choice == 0;
    } on Object {
      return _askSimpleYesNo(
        question,
        defaultValue: defaultValue,
        yesLabel: yesLabel,
        noLabel: noLabel,
      );
    }
  }

  static bool _askSimpleYesNo(
    String question, {
    required bool defaultValue,
    String yesLabel = 'Yes',
    String noLabel = 'No',
  }) {
    final String hint = defaultValue ? 'Y/n' : 'y/N';

    for (int attempt = 0; attempt < 3; attempt++) {
      stdout.write('$question [$hint]: ');
      final String value = stdin.readLineSync()?.trim().toLowerCase() ?? '';
      if (value.isEmpty) {
        return defaultValue;
      }
      if (_matchesLabel(value, yesLabel) || value == 'y' || value == 'yes') {
        return true;
      }
      if (_matchesLabel(value, noLabel) || value == 'n' || value == 'no') {
        return false;
      }
      print('Enter yes or no.');
    }

    return defaultValue;
  }

  static bool _matchesLabel(String value, String label) {
    final String normalized = label.trim().toLowerCase();
    return normalized.isNotEmpty &&
        (value == normalized || value == normalized[0]);
  }
}
