import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:interact/interact.dart' as interact;
import 'package:interact/interact.dart' show Progress;

/// Progress state wrapper for tracking progress
class OracularProgressState {
  final interact.ProgressState _progress;
  final int _total;

  OracularProgressState(this._progress, this._total);

  void increment([int amount = 1]) => _progress.increase(amount);
  void clear() => _progress.clear();
  void done() => _progress.done();

  int get current => _progress.current;
  int get total => _total;
  double get percentage => _progress.current / _total;
}

/// Progress bar prompts
class ProgressPrompt {
  /// Create a progress bar tracker
  static OracularProgressState createProgress(
    int total, {
    String? rightPrompt,
    double size = 0.5,
  }) {
    final interact.ProgressState progress = Progress(
      length: total,
      size: size,
      rightPrompt: rightPrompt != null
          ? (int current) => ' $rightPrompt ($current/$total)'
          : (int current) => ' $current/$total',
    ).interact();
    return OracularProgressState(progress, total);
  }

  /// Run a list of tasks with progress tracking
  static Future<void> withProgress<T>(
    String title,
    List<Future<T> Function()> tasks, {
    List<String>? taskNames,
  }) async {
    print('');
    info(title);

    final OracularProgressState progress = createProgress(tasks.length);

    for (int i = 0; i < tasks.length; i++) {
      if (taskNames != null && i < taskNames.length) {
        stdout.write('\r  ${taskNames[i]}...'.padRight(60));
      }
      await tasks[i]();
      progress.increment();
    }

    print('');
    success('$title complete!');
  }

  /// Simple manual progress bar display
  static void showProgress(int current, int total, String message) {
    final String percent = (current / total * 100).toStringAsFixed(0);
    final String bar = _makeProgressBar(current, total, 30);

    // Use carriage return to overwrite the line
    stdout.write('\r[$bar] $percent% ($current/$total) $message'.padRight(100));

    // If complete, move to next line
    if (current == total) {
      print('');
    }
  }

  static String _makeProgressBar(int current, int total, int width) {
    final int filled = (current / total * width).round();
    final int empty = width - filled;
    return '\u2588' * filled + '\u2591' * empty;
  }
}
