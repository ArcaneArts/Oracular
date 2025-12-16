import 'dart:io' as io;
import 'dart:io';

import 'package:fast_log/fast_log.dart';

import 'user_prompt.dart';

/// Result of a process execution
class ProcessResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final bool success;

  ProcessResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  }) : success = exitCode == 0;

  @override
  String toString() =>
      'ProcessResult(exitCode: $exitCode, success: $success, stdout: ${stdout.length} chars, stderr: ${stderr.length} chars)';
}

// RetryChoice is now defined in user_prompt.dart

/// Exception thrown when user chooses to abort
class AbortException implements Exception {
  final String message;
  AbortException([this.message = 'Operation aborted by user']);

  @override
  String toString() => message;
}

/// Execute shell commands with retry logic
class ProcessRunner {
  /// Maximum automatic retries before prompting user
  final int maxAutoRetries;

  /// Whether to show verbose output
  final bool showVerbose;

  ProcessRunner({this.maxAutoRetries = 2, this.showVerbose = false});

  /// Run a command and return the result
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool inheritStdio = false,
  }) async {
    if (showVerbose) {
      verbose('Running: $executable ${arguments.join(' ')}');
      if (workingDirectory != null) {
        verbose('  in: $workingDirectory');
      }
    }

    final io.ProcessResult result = await Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: Platform.isWindows,
    );

    return ProcessResult(
      exitCode: result.exitCode,
      stdout: result.stdout.toString(),
      stderr: result.stderr.toString(),
    );
  }

  /// Run a command with automatic retry on failure
  /// Returns null if user chooses to skip
  /// Throws AbortException if user chooses to abort
  Future<ProcessResult?> runWithRetry(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    String? operationName,
    bool interactive = true,
  }) async {
    final String opName = operationName ?? '$executable ${arguments.join(' ')}';
    int attempt = 0;

    while (true) {
      attempt++;
      final ProcessResult result = await run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
      );

      if (result.success) {
        return result;
      }

      // Failed - check if we should auto-retry
      if (attempt <= maxAutoRetries) {
        warn('$opName failed (attempt $attempt/$maxAutoRetries), retrying...');
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }

      // Auto-retries exhausted - ask user
      if (!interactive) {
        error('$opName failed after $maxAutoRetries attempts');
        error('stderr: ${result.stderr}');
        return null;
      }

      error('$opName failed after $maxAutoRetries attempts');
      if (result.stderr.isNotEmpty) {
        error('Error output:');
        print(result.stderr);
      }

      final RetryChoice choice = await UserPrompt.askRetryChoice(opName);
      switch (choice) {
        case RetryChoice.retry:
          attempt = 0; // Reset retry counter
          continue;
        case RetryChoice.skip:
          return null;
        case RetryChoice.abort:
          throw AbortException();
      }
    }
  }

  /// Run a command and stream output in real-time
  Future<int> runStreaming(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    if (showVerbose) {
      verbose('Running (streaming): $executable ${arguments.join(' ')}');
    }

    final Process process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: Platform.isWindows,
    );

    // Stream stdout and stderr
    process.stdout.listen((List<int> data) => stdout.add(data));
    process.stderr.listen((List<int> data) => stderr.add(data));

    return await process.exitCode;
  }

  /// Check if a command exists on the system
  Future<bool> commandExists(String command) async {
    try {
      final ProcessResult result = await run(Platform.isWindows ? 'where' : 'which', <String>[
        command,
      ]);
      return result.success;
    } catch (e) {
      return false;
    }
  }

  /// Get the version of a command
  Future<String?> getCommandVersion(
    String command, {
    List<String> versionArgs = const <String>['--version'],
  }) async {
    try {
      final ProcessResult result = await run(command, versionArgs);
      if (result.success) {
        return result.stdout.trim().split('\n').first;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

/// Global process runner instance
final processRunner = ProcessRunner();
