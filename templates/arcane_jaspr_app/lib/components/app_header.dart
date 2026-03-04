import 'package:arcane_jaspr/arcane_jaspr.dart';

import '../utils/constants.dart';

/// Shared application header with navigation and theme toggle
class AppHeader extends StatelessComponent {
  final bool isDark;
  final VoidCallback? onThemeToggle;
  final String currentPath;

  const AppHeader({
    super.key,
    this.isDark = true,
    this.onThemeToggle,
    this.currentPath = '/',
  });

  @override
  Component build(BuildContext context) {
    return ArcaneDiv(
      styles: const ArcaneStyleData(
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
        // Logo/Brand link
        ArcaneLink(
          href: AppRoutes.home,
          styles: const ArcaneStyleData(textDecoration: TextDecoration.none),
          child: ArcaneText(
            AppConstants.appName,
            style: const ArcaneStyleData(
              fontWeight: FontWeight.bold,
              fontSize: FontSize.lg,
              textColor: TextColor.primary,
            ),
          ),
        ),
        ArcaneRow(
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
              ArcaneButton.ghost(
                label: 'GitHub',
                href: AppConstants.githubUrl,
                showArrow: true,
              ),

            // Theme toggle using the new ArcaneThemeToggle component
            ArcaneButton.ghost(
              label: isDark ? 'Light' : 'Dark',
              onPressed: onThemeToggle,
            ),
          ],
        ),
      ],
    );
  }

  Component _buildNavLink(String label, String href) {
    final bool isActive = currentPath == href;
    if (isActive) {
      return ArcaneButton.secondary(label: label, href: href);
    }

    return ArcaneButton.ghost(label: label, href: href);
  }
}
