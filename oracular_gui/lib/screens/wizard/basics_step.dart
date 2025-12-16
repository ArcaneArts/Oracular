import 'package:arcane/arcane.dart';
import 'package:file_picker/file_picker.dart' as fp;

import '../../models/wizard_config.dart';

class BasicsStep extends StatelessWidget {
  final WizardConfig config;
  final TextEditingController appNameController;
  final TextEditingController orgDomainController;
  final TextEditingController classNameController;
  final TextEditingController outputDirController;
  final String? appNameError;
  final String? orgDomainError;
  final ValueChanged<String> onAppNameChanged;
  final ValueChanged<String> onOrgDomainChanged;
  final ValueChanged<String> onClassNameChanged;
  final ValueChanged<String> onOutputDirChanged;

  const BasicsStep({
    super.key,
    required this.config,
    required this.appNameController,
    required this.orgDomainController,
    required this.classNameController,
    required this.outputDirController,
    required this.appNameError,
    required this.orgDomainError,
    required this.onAppNameChanged,
    required this.onOrgDomainChanged,
    required this.onClassNameChanged,
    required this.onOutputDirChanged,
  });

  Future<void> _selectOutputDir(BuildContext context) async {
    final result = await fp.FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Output Directory',
      initialDirectory: outputDirController.text,
    );
    if (result != null) onOutputDirChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Collection(
      children: [
        Basic(
          leading: Icon(Icons.rocket_launch, color: theme.colorScheme.primary),
          title: Text('Project Basics',
              style: theme.typography.h4.copyWith(color: theme.colorScheme.foreground)),
          subtitle: Text('Configure your new Arcane project',
              style: TextStyle(color: theme.colorScheme.mutedForeground)),
        ),
        const Gap(24),
        _buildAppNameSection(theme),
        const Gap(16),
        _buildOrgDomainSection(theme),
        const Gap(16),
        _buildClassNameSection(theme),
        const Gap(16),
        _buildOutputDirSection(context, theme),
      ],
    );
  }

  Widget _buildAppNameSection(ThemeData theme) {
    return CardSection(
      titleText: 'App Name',
      subtitleText: 'Use snake_case (e.g., my_awesome_app)',
      leadingIcon: Icons.text_aa,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: appNameController,
                onChanged: onAppNameChanged,
                placeholder: const Text('my_app'),
              ),
              if (appNameError != null) ...[
                const Gap(8),
                Text(appNameError!, style: TextStyle(color: theme.colorScheme.destructive, fontSize: 12)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrgDomainSection(ThemeData theme) {
    return CardSection(
      titleText: 'Organization',
      subtitleText: 'Reverse domain (e.g., com.example)',
      leadingIcon: Icons.buildings,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: orgDomainController,
                onChanged: onOrgDomainChanged,
                placeholder: const Text('com.example'),
              ),
              if (orgDomainError != null) ...[
                const Gap(8),
                Text(orgDomainError!, style: TextStyle(color: theme.colorScheme.destructive, fontSize: 12)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClassNameSection(ThemeData theme) {
    return CardSection(
      titleText: 'Class Name',
      subtitleText: 'Auto-generated PascalCase name',
      leadingIcon: Icons.code,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: classNameController,
            onChanged: onClassNameChanged,
            placeholder: const Text('MyApp'),
          ),
        ),
      ],
    );
  }

  Widget _buildOutputDirSection(BuildContext context, ThemeData theme) {
    return CardSection(
      titleText: 'Output Directory',
      subtitleText: 'Where to create the project',
      leadingIcon: Icons.folder,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: outputDirController,
                  onChanged: onOutputDirChanged,
                ),
              ),
              const Gap(12),
              OutlineButton(
                onPressed: () => _selectOutputDir(context),
                leading: const Icon(Icons.folder_open),
                child: const Text('Browse'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
