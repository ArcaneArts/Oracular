import 'package:arcane/arcane.dart';

class StepIndicator extends StatelessWidget {
  final int currentStep;
  final List<String> steps;

  const StepIndicator({
    super.key,
    required this.currentStep,
    this.steps = const ['Basics', 'Template', 'Options', 'Review'],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: [
            for (int i = 0; i < steps.length; i++) ...[
              Expanded(child: _StepItem(index: i, label: steps[i], currentStep: currentStep)),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 24),
                    color: currentStep > i
                        ? theme.colorScheme.primary
                        : theme.colorScheme.border,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final int index;
  final String label;
  final int currentStep;

  const _StepItem({
    required this.index,
    required this.label,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = currentStep == index;
    final isComplete = currentStep > index;
    final color = isActive || isComplete
        ? theme.colorScheme.primary
        : theme.colorScheme.mutedForeground;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive || isComplete ? color : Colors.transparent,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: isComplete
                ? Icon(Icons.check, size: 18, color: theme.colorScheme.primaryForeground)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isActive ? theme.colorScheme.primaryForeground : color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        const Gap(8),
        Text(
          label,
          style: TextStyle(
            color: isActive ? theme.colorScheme.foreground : theme.colorScheme.mutedForeground,
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
