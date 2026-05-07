import 'package:interact/interact.dart';

/// Spinner/loading prompts
class SpinnerPrompt {
  /// Show a spinner while performing an async operation.
  ///
  /// The spinner will display [doneMessage] (or a sensible default) when the
  /// action completes successfully, and [failedMessage] when the action either
  /// throws or returns a falsy boolean (`false`).
  ///
  /// If [isSuccess] is provided it overrides the default success detection.
  ///
  /// Note: when the action throws, the original exception is rethrown after
  /// the spinner finishes.
  static Future<T> withSpinner<T>(
    String message,
    Future<T> Function() action, {
    String? doneMessage,
    String? failedMessage,
    String? icon,
    bool Function(T result)? isSuccess,
  }) async {
    bool succeeded = true;

    final SpinnerState spinner = Spinner(
      icon: icon ?? '⠋',
      rightPrompt: (bool done) {
        if (!done) return message;
        if (succeeded) {
          return doneMessage ?? '✓ Done!';
        }
        return failedMessage ?? '✗ Failed';
      },
    ).interact();

    try {
      final T result = await action();

      if (isSuccess != null) {
        succeeded = isSuccess(result);
      } else if (result is bool) {
        succeeded = result;
      }

      spinner.done();
      return result;
    } catch (e) {
      succeeded = false;
      spinner.done();
      rethrow;
    }
  }

  /// Show a spinner with custom loading animation
  static Future<T> withLoadingSpinner<T>(
    String message,
    Future<T> Function() action, {
    String? failedMessage,
  }) async {
    return withSpinner(
      message,
      action,
      icon: '⣾',
      doneMessage: '✓ Complete!',
      failedMessage: failedMessage,
    );
  }
}
