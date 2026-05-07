import 'package:oracular/utils/process_runner.dart';

/// ProcessRunner that adds authentication environment to all calls
/// Used for deployment tests that require Firebase/gcloud authentication
class AuthenticatedProcessRunner extends ProcessRunner {
  final Map<String, String> environment;

  AuthenticatedProcessRunner({required this.environment})
      : super(maxAutoRetries: 0, showVerbose: true);

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool inheritStdio = false,
  }) {
    final Map<String, String> mergedEnv = <String, String>{
      ...this.environment,
      ...?environment,
    };
    return super.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: mergedEnv,
      inheritStdio: inheritStdio,
    );
  }

  @override
  Future<ProcessResult?> runWithRetry(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    String? operationName,
    bool? interactive,
  }) {
    final Map<String, String> mergedEnv = <String, String>{
      ...this.environment,
      ...?environment,
    };
    return super.runWithRetry(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: mergedEnv,
      operationName: operationName,
      interactive: false, // Never interactive in tests
    );
  }

  @override
  Future<int> runStreaming(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) {
    final Map<String, String> mergedEnv = <String, String>{
      ...this.environment,
      ...?environment,
    };
    return super.runStreaming(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: mergedEnv,
    );
  }
}
