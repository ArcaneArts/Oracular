import 'package:arcane_jaspr/arcane_jaspr.dart';

import '../utils/constants.dart';

/// Documentation sidebar with navigation groups
class DocsSidebar extends StatelessComponent {
  final String currentPath;

  const DocsSidebar({
    super.key,
    required this.currentPath,
  });

  @override
  Component build(BuildContext context) {
    return ArcaneAside(
      styles: const ArcaneStyleData(
        display: Display.flex,
        flexDirection: FlexDirection.column,
        widthCustom: '260px',
        minHeight: '100vh',
        flexShrink: 0,
        raw: {
          'background': 'var(--background-secondary)',
          'border-right': '1px solid var(--border-primary)',
        },
      ),
      children: [
        // Header
        ArcaneDiv(
          styles: const ArcaneStyleData(
            padding: PaddingPreset.lg,
            borderBottom: BorderPreset.subtle,
          ),
          children: [
            a(
              href: '/',
              [
                ArcaneDiv(
                  styles: const ArcaneStyleData(
                    fontWeight: FontWeight.bold,
                    fontSize: FontSize.lg,
                    textColor: TextColor.primary,
                  ),
                  children: [ArcaneText(AppConstants.siteName)],
                ),
              ],
            ),
            ArcaneDiv(
              styles: const ArcaneStyleData(
                fontSize: FontSize.sm,
                textColor: TextColor.muted,
              ),
              children: [ArcaneText('Documentation')],
            ),
          ],
        ),

        // Navigation
        ArcaneNav(
          styles: const ArcaneStyleData(
            padding: PaddingPreset.md,
            flexGrow: 1,
            overflowY: OverflowAxis.auto,
          ),
          children: [
            // Getting Started section
            _buildNavSection('Getting Started', [
              _buildNavItem(
                label: 'Introduction',
                href: '/docs',
              ),
              _buildNavItem(
                label: 'Installation',
                href: '/docs/installation',
              ),
              _buildNavItem(
                label: 'Quick Start',
                href: '/docs/quick-start',
              ),
            ]),

            // Guides section
            _buildNavSection('Guides', [
              _buildNavItem(
                label: 'Deployment',
                href: '/guides/deployment',
              ),
            ]),
          ],
        ),
      ],
    );
  }

  Component _buildNavSection(String title, List<Component> items) {
    return ArcaneDiv(
      styles: const ArcaneStyleData(
        margin: MarginPreset.bottomLg,
      ),
      children: [
        ArcaneDiv(
          styles: const ArcaneStyleData(
            fontSize: FontSize.xs,
            fontWeight: FontWeight.w600,
            textColor: TextColor.muted,
            margin: MarginPreset.bottomSm,
            textTransform: TextTransform.uppercase,
            letterSpacing: LetterSpacing.wide,
            raw: {
              'padding': '0 12px',
            },
          ),
          children: [ArcaneText(title)],
        ),
        ...items,
      ],
    );
  }

  /// Build a navigation item that links to a page
  Component _buildNavItem({
    required String label,
    required String href,
  }) {
    final isActive = currentPath == href || currentPath == '$href/';

    return ArcaneLink(
      href: href,
      styles: ArcaneStyleData(
        display: Display.flex,
        gap: Gap.sm,
        fontSize: FontSize.sm,
        borderRadius: Radius.md,
        margin: MarginPreset.bottomXs,
        transition: Transition.allFast,
        crossAxisAlignment: CrossAxisAlignment.center,
        textDecoration: TextDecoration.none,
        textColor: isActive ? TextColor.primary : TextColor.muted,
        fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
        raw: {
          'padding': '8px 12px',
          'background': isActive ? 'var(--glow-light, rgba(5, 150, 105, 0.1))' : 'transparent',
          'border': isActive
              ? '1px solid var(--border-accent, rgba(5, 150, 105, 0.25))'
              : '1px solid transparent',
        },
      ),
      child: ArcaneSpan(child: ArcaneText(label)),
    );
  }
}
