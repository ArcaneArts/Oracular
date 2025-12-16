import 'package:interact/interact.dart';

/// Password/secret input prompts (hidden input)
class PasswordPrompt {
  /// Password input (hidden)
  static Future<String> askPassword(
    String prompt, {
    bool confirm = false,
    String? confirmPrompt,
  }) async {
    final String result = Password(
      prompt: prompt,
      confirmation: confirm,
      confirmPrompt: confirmPrompt ?? 'Confirm password',
    ).interact();
    return result;
  }

  /// Ask for API key or secret (hidden input)
  static Future<String> askSecret(String prompt) async {
    final String result = Password(prompt: prompt, confirmation: false).interact();
    return result;
  }
}
