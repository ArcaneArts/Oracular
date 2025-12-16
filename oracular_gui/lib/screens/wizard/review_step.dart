import 'package:arcane/arcane.dart';

import '../../models/wizard_config.dart';

class ReviewStep extends StatelessWidget {
  final WizardConfig config;

  const ReviewStep({super.key, required this.config});

  IconData _getTemplateIcon(TemplateType template) {
    return switch (template) {
      TemplateType.arcaneTemplate => Icons.app_window,
      TemplateType.arcaneBeamer => Icons.compass,
      TemplateType.arcaneDock => Icons.sidebar,
      TemplateType.arcaneCli => Icons.terminal,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayMap = config.toDisplayMap();

    return Collection(
      children: [
        Basic(
          leading: Icon(Icons.clipboard_text, color: theme.colorScheme.primary),
          title: Text('Review Configuration',
              style: theme.typography.h4.copyWith(color: theme.colorScheme.foreground)),
          subtitle: Text('Verify your settings before creating',
              style: TextStyle(color: theme.colorScheme.mutedForeground)),
        ),
        const Gap(24),
        CardSection(
          titleText: 'Configuration Summary',
          leadingIcon: Icons.list_checks,
          children: displayMap.entries
              .map((e) => Tile(
                    title: Text(e.key),
                    trailing: Text(e.value,
                        style: TextStyle(color: theme.colorScheme.mutedForeground)),
                  ))
              .toList(),
        ),
        const Gap(16),
        CardSection(
          titleText: 'Projects to Create',
          subtitleText: 'The following will be generated',
          leadingIcon: Icons.folder_plus,
          children: [
            Tile(
              leading: Icon(_getTemplateIcon(config.template), color: theme.colorScheme.primary),
              title: Text(config.appName),
              subtitle: Text(config.template.displayName),
            ),
            if (config.createModels)
              Tile(
                leading: Icon(Icons.cube, color: theme.colorScheme.primary),
                title: Text(config.modelsPackageName),
                subtitle: const Text('Shared models package'),
              ),
            if (config.createServer)
              Tile(
                leading: Icon(Icons.cloud, color: theme.colorScheme.primary),
                title: Text(config.serverPackageName),
                subtitle: const Text('Server application'),
              ),
          ],
        ),
      ],
    );
  }
}
