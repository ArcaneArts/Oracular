/// Unified prompt utilities for CLI interactions
///
/// This library provides a comprehensive set of interactive terminal prompts
/// using the `interact` package. Each category is in its own file for modularity.
library;

// Export all prompt modules
export 'prompt/confirm_prompt.dart';
export 'prompt/display_prompt.dart';
export 'prompt/input_prompt.dart';
export 'prompt/password_prompt.dart';
export 'prompt/progress_prompt.dart';
export 'prompt/retry_prompt.dart';
export 'prompt/select_prompt.dart';
export 'prompt/sort_prompt.dart';
export 'prompt/spinner_prompt.dart';
export 'prompt/wizard_prompt.dart';

import 'prompt/confirm_prompt.dart';
import 'prompt/display_prompt.dart';
import 'prompt/input_prompt.dart';
import 'prompt/password_prompt.dart';
import 'prompt/progress_prompt.dart';
import 'prompt/retry_prompt.dart';
import 'prompt/select_prompt.dart';
import 'prompt/sort_prompt.dart';
import 'prompt/spinner_prompt.dart';
import 'prompt/wizard_prompt.dart';

/// Unified API for all prompt utilities
///
/// This class delegates to specialized prompt classes for each category.
/// You can either use this unified class or import specific prompt classes directly.
class UserPrompt {
  // ============================================================================
  // CONFIRMATION PROMPTS (ConfirmPrompt)
  // ============================================================================

  static Future<bool> askYesNo(String question, {bool defaultValue = true}) =>
      ConfirmPrompt.askYesNo(question, defaultValue: defaultValue);

  static Future<bool> askConfirm(
    String question, {
    bool defaultValue = true,
    String yesLabel = 'Yes',
    String noLabel = 'No',
  }) =>
      ConfirmPrompt.askConfirm(
        question,
        defaultValue: defaultValue,
        yesLabel: yesLabel,
        noLabel: noLabel,
      );

  // ============================================================================
  // TEXT INPUT PROMPTS (InputPrompt)
  // ============================================================================

  static Future<String> askString(
    String question, {
    String? defaultValue,
    bool Function(String)? validator,
    String? validationMessage,
  }) =>
      InputPrompt.askString(
        question,
        defaultValue: defaultValue,
        validator: validator,
        validationMessage: validationMessage,
      );

  static Future<int> askInt(
    String question, {
    required int defaultValue,
    int? min,
    int? max,
  }) =>
      InputPrompt.askInt(question, defaultValue: defaultValue, min: min, max: max);

  static Future<double> askDouble(
    String question, {
    required double defaultValue,
    double? min,
    double? max,
  }) =>
      InputPrompt.askDouble(question, defaultValue: defaultValue, min: min, max: max);

  static Future<String> askEmail(String question, {String? defaultValue}) =>
      InputPrompt.askEmail(question, defaultValue: defaultValue);

  static Future<String> askUrl(String question, {String? defaultValue}) =>
      InputPrompt.askUrl(question, defaultValue: defaultValue);

  // ============================================================================
  // PASSWORD INPUT (PasswordPrompt)
  // ============================================================================

  static Future<String> askPassword(
    String prompt, {
    bool confirm = false,
    String? confirmPrompt,
  }) =>
      PasswordPrompt.askPassword(prompt, confirm: confirm, confirmPrompt: confirmPrompt);

  static Future<String> askSecret(String prompt) => PasswordPrompt.askSecret(prompt);

  // ============================================================================
  // SELECTION PROMPTS (SelectPrompt)
  // ============================================================================

  static Future<int> showMenu(String title, List<String> options, {int? defaultIndex}) =>
      SelectPrompt.showMenu(title, options, defaultIndex: defaultIndex);

  static Future<String> showMenuGetValue(
    String title,
    List<String> options, {
    int? defaultIndex,
  }) =>
      SelectPrompt.showMenuGetValue(title, options, defaultIndex: defaultIndex);

  static Future<List<int>> askMultiSelect(
    String title,
    List<String> options, {
    List<String>? defaultSelected,
    List<bool>? defaults,
  }) =>
      SelectPrompt.askMultiSelect(
        title,
        options,
        defaultSelected: defaultSelected,
        defaults: defaults,
      );

  static Future<List<String>> askMultiSelectNames(
    String title,
    List<String> options, {
    List<String>? defaultSelected,
  }) =>
      SelectPrompt.askMultiSelectNames(title, options, defaultSelected: defaultSelected);

  static Future<int> askTheme(
    String prompt,
    List<String> themes,
    List<String> descriptions, {
    int initialIndex = 0,
  }) =>
      SelectPrompt.askTheme(prompt, themes, descriptions, initialIndex: initialIndex);

  // ============================================================================
  // SORTING / ORDERING (SortPrompt)
  // ============================================================================

  static Future<List<String>> askSort(
    String title,
    List<String> options, {
    bool showOutput = true,
  }) =>
      SortPrompt.askSort(title, options, showOutput: showOutput);

  static Future<List<String>> askSortGetValues(
    String title,
    List<String> options, {
    bool showOutput = true,
  }) =>
      SortPrompt.askSortGetValues(title, options, showOutput: showOutput);

  static Future<List<String>> askPrioritize(String title, List<String> items) =>
      SortPrompt.askPrioritize(title, items);

  // ============================================================================
  // SPINNERS (SpinnerPrompt)
  // ============================================================================

  static Future<T> withSpinner<T>(
    String message,
    Future<T> Function() action, {
    String? doneMessage,
    String? icon,
  }) =>
      SpinnerPrompt.withSpinner(message, action, doneMessage: doneMessage, icon: icon);

  static Future<T> withLoadingSpinner<T>(
    String message,
    Future<T> Function() action,
  ) =>
      SpinnerPrompt.withLoadingSpinner(message, action);

  // ============================================================================
  // PROGRESS (ProgressPrompt)
  // ============================================================================

  static OracularProgressState createProgress(
    int total, {
    String? rightPrompt,
    double size = 0.5,
  }) =>
      ProgressPrompt.createProgress(total, rightPrompt: rightPrompt, size: size);

  static Future<void> withProgress<T>(
    String title,
    List<Future<T> Function()> tasks, {
    List<String>? taskNames,
  }) =>
      ProgressPrompt.withProgress(title, tasks, taskNames: taskNames);

  static void showProgress(int current, int total, String message) =>
      ProgressPrompt.showProgress(current, total, message);

  // ============================================================================
  // WIZARD (WizardPrompt)
  // ============================================================================

  static void printStepIndicator(int currentStep, int totalSteps, String stepName) =>
      WizardPrompt.printStepIndicator(currentStep, totalSteps, stepName);

  static Future<Map<String, dynamic>> runWizard(String title, List<WizardStep> steps) =>
      WizardPrompt.runWizard(title, steps);

  // ============================================================================
  // RETRY / ERROR HANDLING (RetryPrompt)
  // ============================================================================

  static Future<RetryChoice> askRetryChoice(String operationName) =>
      RetryPrompt.askRetryChoice(operationName);

  static Future<T?> withRetry<T>(
    String operationName,
    Future<T> Function() action, {
    int maxRetries = 3,
  }) =>
      RetryPrompt.withRetry(operationName, action, maxRetries: maxRetries);

  // ============================================================================
  // DISPLAY UTILITIES (DisplayPrompt)
  // ============================================================================

  static void printBanner(String title, {String? subtitle}) =>
      DisplayPrompt.printBanner(title, subtitle: subtitle);

  static void printDivider({String? title, int width = 60}) =>
      DisplayPrompt.printDivider(title: title, width: width);

  static void printConfigPreview(
    Map<String, String> config, {
    String title = 'Configuration Preview',
  }) =>
      DisplayPrompt.printConfigPreview(config, title: title);

  static void printList(List<String> items, {String bullet = '•'}) =>
      DisplayPrompt.printList(items, bullet: bullet);

  static void printNumberedList(List<String> items) => DisplayPrompt.printNumberedList(items);

  static void printSuccessBox(String message, {List<String>? details}) =>
      DisplayPrompt.printSuccessBox(message, details: details);

  static void printErrorBox(String message, {String? hint}) =>
      DisplayPrompt.printErrorBox(message, hint: hint);

  static Future<void> pressEnter({String message = 'Press Enter to continue...'}) =>
      DisplayPrompt.pressEnter(message: message);

  static void clearScreen() => DisplayPrompt.clearScreen();
}
