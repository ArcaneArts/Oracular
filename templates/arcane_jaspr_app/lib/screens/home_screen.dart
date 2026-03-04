import 'package:arcane_jaspr/arcane_jaspr.dart';

import '../components/app_header.dart';
import '../utils/constants.dart';

/// Home screen - landing page for the application
class HomeScreen extends StatelessComponent {
  final bool isDark;
  final VoidCallback? onThemeToggle;

  const HomeScreen({super.key, this.isDark = true, this.onThemeToggle});

  @override
  Component build(BuildContext context) {
    return ArcaneDiv(
      styles: const ArcaneStyleData(
        minHeight: '100vh',
        display: Display.flex,
        flexDirection: FlexDirection.column,
      ),
      children: [
        // Header
        AppHeader(
          isDark: isDark,
          onThemeToggle: onThemeToggle,
          currentPath: AppRoutes.home,
        ),

        // Hero section
        _HeroSection(),

        // Features section
        _FeaturesSection(),
      ],
    );
  }
}

class _HeroSection extends StatelessComponent {
  const _HeroSection();

  @override
  Component build(BuildContext context) {
    return ArcaneDiv(
      styles: const ArcaneStyleData(
        padding: PaddingPreset.heroY,
        textAlign: TextAlign.center,
      ),
      children: [
        ArcaneColumn(
          crossAxisAlignment: CrossAxisAlignment.center,
          style: const ArcaneStyleData(gap: Gap.lg),
          children: [
            // Hero headline with gradient text
            ArcaneDiv(
              styles: const ArcaneStyleData(
                fontSize: FontSize.mega,
                fontWeight: FontWeight.w800,
                textColor: TextColor.primary,
                lineHeight: LineHeight.tight,
              ),
              children: [ArcaneText('Welcome to ${AppConstants.appName}')],
            ),
            // Subtitle
            ArcaneDiv(
              styles: const ArcaneStyleData(
                fontSize: FontSize.xl,
                textColor: TextColor.muted,
                maxWidth: MaxWidth.text,
              ),
              children: [ArcaneText(AppConstants.appDescription)],
            ),
            // CTA buttons using new ArcaneCtaLink variants
            ArcaneRow(
              mainAxisAlignment: MainAxisAlignment.center,
              style: const ArcaneStyleData(gap: Gap.md),
              children: [
                ArcaneButton.primary(
                  href: AppRoutes.about,
                  label: 'Get Started',
                ),
                ArcaneButton.secondary(
                  href: AppRoutes.about,
                  label: 'Learn More',
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _FeaturesSection extends StatelessComponent {
  const _FeaturesSection();

  @override
  Component build(BuildContext context) {
    return ArcaneDiv(
      styles: const ArcaneStyleData(
        padding: PaddingPreset.sectionY,
        flexGrow: 1,
      ),
      children: [
        ArcaneBox(
          maxWidth: MaxWidth.container,
          margin: MarginPreset.autoX,
          children: [
            ArcaneColumn(
              crossAxisAlignment: CrossAxisAlignment.center,
              style: const ArcaneStyleData(gap: Gap.xxl),
              children: [
                // Section header using new ArcaneSectionHeader component
                ArcaneColumn(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  style: const ArcaneStyleData(gap: Gap.sm),
                  children: const [
                    ArcaneText.heading('Features'),
                    ArcaneText.body(
                      'Everything you need to build modern web applications',
                    ),
                  ],
                ),
                // Feature cards in a grid
                ArcaneDiv(
                  styles: const ArcaneStyleData(
                    display: Display.grid,
                    gridColumns: GridColumns.autoFitMd,
                    gap: Gap.lg,
                    width: Size.full,
                  ),
                  children: [
                    _FeatureCard(
                      icon: ArcaneIcon.zap(size: IconSize.xl),
                      title: 'Fast & Modern',
                      description:
                          'Built with Dart and Jaspr for blazing fast performance.',
                    ),
                    _FeatureCard(
                      icon: ArcaneIcon.palette(size: IconSize.xl),
                      title: 'Arcane Design',
                      description:
                          'Beautiful UI components from the Arcane design system.',
                    ),
                    _FeatureCard(
                      icon: ArcaneIcon.layers(size: IconSize.xl),
                      title: 'Full Stack',
                      description:
                          'Works seamlessly with Dart servers and shared models.',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessComponent {
  final Component icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Component build(BuildContext context) {
    return ArcaneCard(
      child: ArcaneDiv(
        styles: const ArcaneStyleData(padding: PaddingPreset.lg),
        children: [
          ArcaneColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            style: const ArcaneStyleData(gap: Gap.md),
            children: [
              // Icon with accent background
              ArcaneDiv(
                styles: const ArcaneStyleData(
                  padding: PaddingPreset.sm,
                  borderRadius: Radius.lg,
                  background: Background.accentContainer,
                  textColor: TextColor.accent,
                  display: Display.inlineFlex,
                ),
                children: [icon],
              ),
              // Title
              ArcaneDiv(
                styles: const ArcaneStyleData(
                  fontSize: FontSize.lg,
                  fontWeight: FontWeight.w600,
                  textColor: TextColor.primary,
                ),
                children: [ArcaneText(title)],
              ),
              // Description
              ArcaneDiv(
                styles: const ArcaneStyleData(
                  textColor: TextColor.muted,
                  lineHeight: LineHeight.relaxed,
                ),
                children: [ArcaneText(description)],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
