import 'package:arcane_jaspr/arcane_jaspr.dart';

import '../utils/constants.dart';

/// Top navigation strip for the embed host. Mirrors the working
/// `arcane_jaspr_app` header but adds a "Launch App" CTA pointing at
/// `${AppRoutes.app}`, which Firebase Hosting rewrites to the Flutter
/// SPA bundle.
class AppHeader extends StatelessWidget {
  final bool isDark;
  final void Function()? onThemeToggle;
  final String currentPath;

  const AppHeader({
    super.key,
    required this.currentPath,
    this.isDark = true,
    this.onThemeToggle,
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
            _navLink('Home', AppRoutes.home),
            _navLink('About', AppRoutes.about),

            // CTA to the embedded Flutter SPA. Firebase Hosting rewrites
            // /app/** to the Flutter bundle, so this is a plain link.
            const Button.primary(label: 'Launch App', href: AppRoutes.app),

            Button.ghost(
              label: isDark ? 'Light' : 'Dark',
              onPressed: onThemeToggle,
            ),
          ],
        ),
      ],
    );
  }

  Widget _navLink(String label, String href) {
    final bool isActive = currentPath == href;
    return isActive
        ? Button.secondary(label: label, href: href)
        : Button.ghost(label: label, href: href);
  }
}
