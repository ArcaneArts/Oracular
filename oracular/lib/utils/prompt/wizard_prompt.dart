import 'package:fast_log/fast_log.dart';

import 'display_prompt.dart';

/// Wizard step definition
class WizardStep {
  final String name;
  final String key;
  final bool required;
  final Future<dynamic> Function(Map<String, dynamic> previousResults) execute;

  WizardStep({
    required this.name,
    required this.key,
    required this.execute,
    this.required = true,
  });
}

/// Step-by-step wizard prompts
class WizardPrompt {
  /// Display a step indicator
  static void printStepIndicator(int currentStep, int totalSteps, String stepName) {
    final String steps = List<String>.generate(totalSteps, (int i) {
      if (i < currentStep) return '●';
      if (i == currentStep) return '◉';
      return '○';
    }).join(' ');

    print('');
    print('  $steps');
    print('  Step ${currentStep + 1} of $totalSteps: $stepName');
    print('');
  }

  /// Run a multi-step wizard process
  static Future<Map<String, dynamic>> runWizard(
    String title,
    List<WizardStep> steps,
  ) async {
    final Map<String, dynamic> results = <String, dynamic>{};

    DisplayPrompt.printBanner(title);

    for (int i = 0; i < steps.length; i++) {
      printStepIndicator(i, steps.length, steps[i].name);

      final dynamic result = await steps[i].execute(results);
      if (result == null && steps[i].required) {
        warn('Step cancelled. Aborting wizard.');
        return <String, dynamic>{};
      }
      results[steps[i].key] = result;
    }

    return results;
  }
}
