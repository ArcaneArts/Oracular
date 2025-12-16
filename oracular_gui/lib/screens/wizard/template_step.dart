import 'package:arcane/arcane.dart';

import '../../models/wizard_config.dart';

class TemplateStep extends StatelessWidget {
  final TemplateType selectedTemplate;
  final ValueChanged<TemplateType> onTemplateChanged;

  const TemplateStep({
    super.key,
    required this.selectedTemplate,
    required this.onTemplateChanged,
  });

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

    return Collection(
      children: [
        Basic(
          leading: Icon(Icons.layout, color: theme.colorScheme.primary),
          title: Text('Choose Template',
              style: theme.typography.h4.copyWith(color: theme.colorScheme.foreground)),
          subtitle: Text('Select the project type that fits your needs',
              style: TextStyle(color: theme.colorScheme.mutedForeground)),
        ),
        const Gap(24),
        RadioGroup<TemplateType>(
          value: selectedTemplate,
          onChanged: onTemplateChanged,
          child: Column(
            children: TemplateType.values
                .map((template) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RadioCard<TemplateType>(
                        value: template,
                        child: Basic(
                          leading: Icon(_getTemplateIcon(template)),
                          title: Text(template.displayName),
                          subtitle: Text(template.description),
                          content: Text(
                            template.platforms.isEmpty
                                ? 'Pure Dart CLI'
                                : 'Platforms: ${template.platforms.join(", ")}',
                            style: TextStyle(
                              color: theme.colorScheme.mutedForeground,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}
