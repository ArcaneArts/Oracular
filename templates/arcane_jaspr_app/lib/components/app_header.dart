import 'package:arcane_jaspr/arcane_jaspr.dart';

import '../utils/constants.dart';

/// Shared application header with navigation and theme toggle
class AppHeader extends StatelessWidget {
  final bool isDark;
  final void Function()? onThemeToggle;
  final String currentPath;

  const AppHeader({
    super.key,
    this.isDark = true,
    this.onThemeToggle,
    this.currentPath = '/',
  });

  @override
  Widget build(BuildContext context) {
    return ArcaneBox(
      style: const ArcaneStyleData(
        display: Display.flex,
        alignItems: AlignItems.center,
        justifyContent: JustifyContent.spaceBetween,
        padding: PaddingPreset.horizontalLg,
        heightCustom: '64px',
        borderBottom: BorderPreset.subtle,
        background: Background.surface,
        width: Size.full,
      ),
      children: [
        const Button.ghost(label: AppConstants.appName, href: AppRoutes.home),
        Row(
          style: const ArcaneStyleData(
            gap: Gap.sm,
            alignItems: AlignItems.center,
          ),
          children: [
            // Navigation links
            _buildNavLink('Home', AppRoutes.home),
            _buildNavLink('About', AppRoutes.about),

            // GitHub link (if configured)
            if (AppConstants.githubUrl.isNotEmpty)
              const Button.ghost(
                label: 'GitHub',
                href: AppConstants.githubUrl,
                showArrow: true,
              ),

            // Theme toggle using the new ArcaneThemeToggle component
            Button.ghost(
              label: isDark ? 'Light' : 'Dark',
              onPressed: onThemeToggle,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavLink(String label, String href) {
    final bool isActive = currentPath == href;
    if (isActive) {
      return Button.secondary(label: label, href: href);
    }

    return Button.ghost(label: label, href: href);
  }
}
