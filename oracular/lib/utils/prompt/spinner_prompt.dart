import 'package:interact/interact.dart';

/// Spinner/loading prompts
class SpinnerPrompt {
  /// Show a spinner while performing an async operation
  static Future<T> withSpinner<T>(
    String message,
    Future<T> Function() action, {
    String? doneMessage,
    String? icon,
  }) async {
    final SpinnerState spinner = Spinner(
      icon: icon ?? '⠋',
      rightPrompt: (bool done) => done ? (doneMessage ?? '✓ Done!') : message,
    ).interact();

    try {
      final T result = await action();
      spinner.done();
      return result;
    } catch (e) {
      spinner.done();
      rethrow;
    }
  }

  /// Show a spinner with custom loading animation
  static Future<T> withLoadingSpinner<T>(
    String message,
    Future<T> Function() action,
  ) async {
    return withSpinner(message, action, icon: '⣾', doneMessage: '✓ Complete!');
  }
}
