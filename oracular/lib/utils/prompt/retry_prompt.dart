import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:interact/interact.dart';

/// Retry choice enum
enum RetryChoice { retry, skip, abort }

/// Retry/error handling prompts
class RetryPrompt {
  /// Ask user for retry choice after failure
  static Future<RetryChoice> askRetryChoice(String operationName) async {
    print('');
    warn('$operationName failed.');

    final int choice = Select(
      prompt: 'What would you like to do?',
      options: <String>['🔄 Retry', '⏭️ Skip', '🛑 Abort'],
      initialIndex: 0,
    ).interact();

    return RetryChoice.values[choice];
  }

  /// Run an operation with automatic retry prompts
  static Future<T?> withRetry<T>(
    String operationName,
    Future<T> Function() action, {
    int maxRetries = 3,
  }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        final T result = await action();
        return result;
      } catch (e) {
        attempts++;
        error('$operationName failed: $e');

        if (attempts >= maxRetries) {
          error('Max retries ($maxRetries) reached.');
          return null;
        }

        final RetryChoice choice = await askRetryChoice(operationName);
        switch (choice) {
          case RetryChoice.retry:
            info('Retrying... (attempt ${attempts + 1}/$maxRetries)');
            continue;
          case RetryChoice.skip:
            warn('Skipping $operationName');
            return null;
          case RetryChoice.abort:
            error('Aborting...');
            exit(1);
        }
      }
    }

    return null;
  }
}
