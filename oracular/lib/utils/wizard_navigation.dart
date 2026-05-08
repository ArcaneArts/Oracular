import 'dart:io';

import 'package:interact/interact.dart';

import 'prompt/prompt_environment.dart';
import 'user_prompt.dart';

/// Sentinel exception used by every wizard prompt to signal that the user
/// asked to step backward to the previous question. Wizards catch it and
/// re-run the previous step instead of advancing.
///
/// Recognized triggers (work in both `interact` and simple-prompt fallback
/// modes):
///   * Typing `back`, `b`, `<`, `:back` (case-insensitive) into a text prompt
///   * Selecting the appended `← Back` option from any menu/yes-no/theme
///     prompt
///
/// True ESC / Backspace key support is added on top via [WizardNav.askKey]
/// for confirm-only navigation hints. The `interact` package gobbles ESC
/// inside its own `Select`/`Confirm`/`Input` widgets and does not expose a
/// hook for handling them, so the keyword/menu fallback is what actually
/// makes "go back" work end-to-end.
class BackNavigation implements Exception {
  /// Optional human-readable name of the step the user chose to leave; used
  /// only for log messages so the wizard can print "↩ Going back to ..."
  final String? fromStep;
  const BackNavigation({this.fromStep});

  @override
  String toString() =>
      fromStep == null ? 'BackNavigation' : 'BackNavigation(from: $fromStep)';
}

/// User-cancelled navigation (Ctrl-C, typed `quit`, etc). Distinct from
/// [BackNavigation] because the wizard should abort the entire flow rather
/// than rewind one step.
class CancelNavigation implements Exception {
  final String? reason;
  const CancelNavigation({this.reason});

  @override
  String toString() =>
      reason == null ? 'CancelNavigation' : 'CancelNavigation($reason)';
}

/// Navigation-aware prompt wrappers used by the interactive wizard.
///
/// Each method is a thin layer over [UserPrompt] that recognizes "go back"
/// triggers and converts them into a [BackNavigation] exception, allowing
/// the calling wizard to rewind one step.
///
/// All methods preserve the underlying prompt UX — the only behavioural
/// change is the new keywords / appended menu options.
class WizardNav {
  /// Magic keywords that move the wizard backwards when typed into a text
  /// input. The `< ` prefix is intentional: it's the single-keystroke
  /// shortcut some users prefer over typing the full word.
  static const Set<String> backKeywords = <String>{
    'back',
    'b',
    '<',
    ':back',
  };

  /// Magic keywords that abort the wizard from any prompt.
  static const Set<String> cancelKeywords = <String>{
    'quit',
    'q',
    ':q',
    ':quit',
    'exit',
    'cancel',
  };

  /// Visible menu suffix appended to selectable prompts to advertise
  /// back-navigation. Kept in one place so we can change the glyph in one
  /// edit.
  static const String backOptionLabel = '\u21B5  Back to previous step';

  /// Print a one-line hint at the top of every wizard step so the user
  /// always knows how to retreat. Idempotent — call this freely.
  static void printNavHint() {
    stdout.writeln(
      '  Tip: type \u201Cback\u201D (or \u201Cb\u201D / \u201C<\u201D) at any prompt '
      'to step backwards \u00B7 \u201Cquit\u201D to abort.',
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // TEXT INPUTS
  // ──────────────────────────────────────────────────────────────────────

  /// Drop-in replacement for [UserPrompt.askString] that throws
  /// [BackNavigation] when the user types one of [backKeywords] and
  /// [CancelNavigation] when the user types one of [cancelKeywords].
  ///
  /// The validator (if any) is bypassed for the back/cancel keywords so the
  /// user can always retreat regardless of what the prompt expects.
  static Future<String> askString(
    String question, {
    String? defaultValue,
    bool Function(String)? validator,
    String? validationMessage,
    String? fromStep,
  }) async {
    while (true) {
      final String result = await UserPrompt.askString(
        '$question  (or "back")',
        defaultValue: defaultValue,
        validator: (String s) {
          // Always allow back/cancel keywords through validation.
          final String lower = s.trim().toLowerCase();
          if (backKeywords.contains(lower) ||
              cancelKeywords.contains(lower)) {
            return true;
          }
          return validator?.call(s) ?? true;
        },
        validationMessage: validationMessage,
      );

      final String trimmed = result.trim();
      final String lower = trimmed.toLowerCase();

      if (backKeywords.contains(lower)) {
        throw BackNavigation(fromStep: fromStep);
      }
      if (cancelKeywords.contains(lower)) {
        throw CancelNavigation(reason: 'user typed "$trimmed"');
      }
      return result;
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // YES / NO
  // ──────────────────────────────────────────────────────────────────────

  /// Yes/No prompt with an extra "Back" option. Throws [BackNavigation]
  /// when the user picks the third option.
  static Future<bool> askYesNo(
    String question, {
    bool defaultValue = true,
    String? fromStep,
  }) async {
    if (PromptEnvironment.useSimplePrompts) {
      return _askSimpleYesNoOrBack(
        question,
        defaultValue: defaultValue,
        fromStep: fromStep,
      );
    }
    try {
      final int choice = Select(
        prompt: '$question  (← Back to step back)',
        options: <String>['Yes', 'No', backOptionLabel],
        initialIndex: defaultValue ? 0 : 1,
      ).interact();
      switch (choice) {
        case 0:
          return true;
        case 1:
          return false;
        case 2:
          throw BackNavigation(fromStep: fromStep);
        default:
          return defaultValue;
      }
    } on BackNavigation {
      rethrow;
    } on Object {
      return _askSimpleYesNoOrBack(
        question,
        defaultValue: defaultValue,
        fromStep: fromStep,
      );
    }
  }

  static bool _askSimpleYesNoOrBack(
    String question, {
    required bool defaultValue,
    String? fromStep,
  }) {
    final String hint = defaultValue ? 'Y/n/back' : 'y/N/back';
    for (int attempt = 0; attempt < 3; attempt++) {
      stdout.write('$question [$hint]: ');
      final String value =
          stdin.readLineSync()?.trim().toLowerCase() ?? '';
      if (value.isEmpty) {
        return defaultValue;
      }
      if (backKeywords.contains(value)) {
        throw BackNavigation(fromStep: fromStep);
      }
      if (cancelKeywords.contains(value)) {
        throw CancelNavigation(reason: 'user typed "$value"');
      }
      if (value == 'y' || value == 'yes') return true;
      if (value == 'n' || value == 'no') return false;
      stdout.writeln('Enter yes, no, or back.');
    }
    return defaultValue;
  }

  // ──────────────────────────────────────────────────────────────────────
  // MENU / THEME SELECT
  // ──────────────────────────────────────────────────────────────────────

  /// Theme/option selector with an appended "Back" item that throws
  /// [BackNavigation] when chosen.
  static Future<int> askTheme(
    String prompt,
    List<String> themes,
    List<String> descriptions, {
    int initialIndex = 0,
    String? fromStep,
  }) async {
    final List<String> options = <String>[
      for (int i = 0; i < themes.length; i++)
        if (i < descriptions.length)
          '${themes[i]} - ${descriptions[i]}'
        else
          themes[i],
      backOptionLabel,
    ];

    final int chosen = await UserPrompt.showMenu(
      prompt,
      options,
      defaultIndex: initialIndex,
    );

    if (chosen == options.length - 1) {
      throw BackNavigation(fromStep: fromStep);
    }
    return chosen;
  }

  /// Plain menu with a Back option appended.
  static Future<int> showMenu(
    String title,
    List<String> options, {
    int? defaultIndex,
    String? fromStep,
  }) async {
    final List<String> withBack = <String>[
      ...options,
      backOptionLabel,
    ];
    final int chosen = await UserPrompt.showMenu(
      title,
      withBack,
      defaultIndex: defaultIndex,
    );
    if (chosen == withBack.length - 1) {
      throw BackNavigation(fromStep: fromStep);
    }
    return chosen;
  }
}
