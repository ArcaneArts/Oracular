import 'package:arcane/arcane.dart';

import '../../models/wizard_config.dart';

class OptionsStep extends StatelessWidget {
  final WizardConfig config;
  final TextEditingController firebaseIdController;
  final String? firebaseIdError;
  final ValueChanged<String> onFirebaseIdChanged;
  final ValueChanged<bool> onCreateModelsChanged;
  final ValueChanged<bool> onCreateServerChanged;
  final ValueChanged<bool> onUseFirebaseChanged;
  final ValueChanged<bool> onSetupCloudRunChanged;
  final ValueChanged<String> onPlatformToggled;

  const OptionsStep({
    super.key,
    required this.config,
    required this.firebaseIdController,
    required this.firebaseIdError,
    required this.onFirebaseIdChanged,
    required this.onCreateModelsChanged,
    required this.onCreateServerChanged,
    required this.onUseFirebaseChanged,
    required this.onSetupCloudRunChanged,
    required this.onPlatformToggled,
  });

  String _getPlatformDisplayName(String platform) {
    return switch (platform) {
      'android' => 'Android',
      'ios' => 'iOS',
      'web' => 'Web',
      'linux' => 'Linux',
      'macos' => 'macOS',
      'windows' => 'Windows',
      _ => platform,
    };
  }

  IconData _getPlatformIcon(String platform) {
    return switch (platform) {
      'android' || 'ios' => Icons.device_mobile,
      'web' => Icons.globe,
      _ => Icons.desktop,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Collection(
      children: [
        Basic(
          leading: Icon(Icons.gear, color: theme.colorScheme.primary),
          title: Text('Project Options',
              style: theme.typography.h4.copyWith(color: theme.colorScheme.foreground)),
          subtitle: Text('Configure additional features',
              style: TextStyle(color: theme.colorScheme.mutedForeground)),
        ),
        const Gap(24),
        if (config.template.allowsPlatformSelection) ...[
          _buildPlatformSection(theme),
          const Gap(16),
        ],
        _buildPackagesSection(theme),
        const Gap(16),
        _buildFirebaseSection(theme),
        if (config.createServer && config.useFirebase) ...[
          const Gap(16),
          _buildCloudRunSection(theme),
        ],
      ],
    );
  }

  Widget _buildPlatformSection(ThemeData theme) {
    return CardSection(
      titleText: 'Target Platforms',
      subtitleText: 'Select which platforms to build for',
      leadingIcon: Icons.monitor,
      children: config.template.platforms
          .map((platform) => Tile(
                leading: Icon(_getPlatformIcon(platform)),
                title: Text(_getPlatformDisplayName(platform)),
                trailing: Switch(
                  value: config.isPlatformSelected(platform),
                  onChanged: (_) => onPlatformToggled(platform),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildPackagesSection(ThemeData theme) {
    return CardSection(
      titleText: 'Additional Packages',
      subtitleText: 'Create supplementary projects',
      leadingIcon: Icons.package,
      children: [
        Tile(
          leading: const Icon(Icons.cube),
          title: const Text('Models Package'),
          subtitle: const Text('Shared data models for client and server'),
          trailing: Switch(
            value: config.createModels,
            onChanged: onCreateModelsChanged,
          ),
        ),
        Tile(
          leading: const Icon(Icons.cloud),
          title: const Text('Server App'),
          subtitle: const Text('Backend REST API with Shelf'),
          trailing: Switch(
            value: config.createServer,
            onChanged: onCreateServerChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildFirebaseSection(ThemeData theme) {
    return CardSection(
      titleText: 'Firebase Integration',
      subtitleText: 'Connect to Firebase services',
      leadingIcon: Icons.flame,
      children: [
        Tile(
          leading: const Icon(Icons.flame),
          title: const Text('Enable Firebase'),
          subtitle: const Text('Add Firebase configuration'),
          trailing: Switch(
            value: config.useFirebase,
            onChanged: onUseFirebaseChanged,
          ),
        ),
        if (config.useFirebase)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Firebase Project ID',
                    style: TextStyle(fontWeight: FontWeight.w500, color: theme.colorScheme.foreground)),
                const Gap(8),
                TextField(
                  controller: firebaseIdController,
                  onChanged: onFirebaseIdChanged,
                  placeholder: const Text('my-firebase-project'),
                ),
                if (firebaseIdError != null) ...[
                  const Gap(8),
                  Text(firebaseIdError!, style: TextStyle(color: theme.colorScheme.destructive, fontSize: 12)),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCloudRunSection(ThemeData theme) {
    return CardSection(
      titleText: 'Cloud Deployment',
      subtitleText: 'Deploy to Google Cloud',
      leadingIcon: Icons.cloud_arrow_up,
      children: [
        Tile(
          leading: const Icon(Icons.rocket),
          title: const Text('Setup Cloud Run'),
          subtitle: const Text('Configure Docker deployment for server'),
          trailing: Switch(
            value: config.setupCloudRun,
            onChanged: onSetupCloudRunChanged,
          ),
        ),
      ],
    );
  }
}
