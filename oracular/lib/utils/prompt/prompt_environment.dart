import 'dart:io';

/// Shared terminal capability checks for prompt fallbacks.
class PromptEnvironment {
  static bool get useSimplePrompts {
    final Map<String, String> env = Platform.environment;
    return env['ORACULAR_SIMPLE_PROMPTS'] == '1' ||
        env['CI'] == 'true' ||
        !stdin.hasTerminal ||
        !stdout.hasTerminal;
  }
}
