import 'package:arcane/arcane.dart';

import '../../models/wizard_config.dart';

class CompletionScreen extends StatelessWidget {
  final WizardConfig config;
  final VoidCallback onCreateAnother;
  final VoidCallback onDone;

  const CompletionScreen({
    super.key,
    required this.config,
    required this.onCreateAnother,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Collection(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: CenterBody(
              icon: Icons.check_circle,
              message: 'Project Created Successfully!',
            ),
          ),
        ),
        const Gap(24),
        CardSection(
          titleText: 'Next Steps',
          subtitleText: 'Get started with your new project',
          leadingIcon: Icons.arrow_right,
          children: [
            Tile(
              leading: Icon(Icons.terminal, color: theme.colorScheme.primary),
              title: Text('cd ${config.outputDir}/${config.appName}'),
              subtitle: const Text('Navigate to your project'),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {},
              ),
            ),
            Tile(
              leading: Icon(Icons.play_circle, color: theme.colorScheme.primary),
              title: Text(config.template.isFlutter ? 'flutter run' : 'dart run bin/main.dart'),
              subtitle: const Text('Run your application'),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {},
              ),
            ),
          ],
        ),
        const Gap(24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlineButton(
              onPressed: onCreateAnother,
              leading: const Icon(Icons.plus),
              child: const Text('Create Another'),
            ),
            const Gap(12),
            PrimaryButton(
              onPressed: onDone,
              leading: const Icon(Icons.check),
              child: const Text('Done'),
            ),
          ],
        ),
      ],
    );
  }
}
