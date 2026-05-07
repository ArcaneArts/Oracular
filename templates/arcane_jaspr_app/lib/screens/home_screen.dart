import 'package:arcane_jaspr/arcane_jaspr.dart';

import '../components/app_header.dart';
import '../utils/constants.dart';

/// Home screen - landing page for the application
class HomeScreen extends StatelessWidget {
  final bool isDark;
  final void Function()? onThemeToggle;

  const HomeScreen({super.key, this.isDark = true, this.onThemeToggle});

  @override
  Widget build(BuildContext context) {
    return ArcaneBox(
      style: const ArcaneStyleData(
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
        const _HeroSection(),

        // Features section
        const _FeaturesSection(),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return const ArcaneBox(
      style: ArcaneStyleData(
        padding: PaddingPreset.heroY,
        textAlign: TextAlign.center,
      ),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          style: ArcaneStyleData(gap: Gap.lg),
          children: [
            // Hero headline with gradient text
            ArcaneBox(
              style: ArcaneStyleData(
                fontSize: FontSize.mega,
                fontWeight: FontWeight.w800,
                textColor: TextColor.primary,
                lineHeight: LineHeight.tight,
              ),
              children: [Text('Welcome to ${AppConstants.appName}')],
            ),
            // Subtitle
            ArcaneBox(
              style: ArcaneStyleData(
                fontSize: FontSize.xl,
                textColor: TextColor.muted,
                maxWidth: MaxWidth.text,
              ),
              children: [Text(AppConstants.appDescription)],
            ),
            // CTA buttons using new ArcaneCtaLink variants
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              style: ArcaneStyleData(gap: Gap.md),
              children: [
                Button.primary(href: AppRoutes.about, label: 'Get Started'),
                Button.secondary(href: AppRoutes.about, label: 'Learn More'),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  @override
  Widget build(BuildContext context) {
    return ArcaneBox(
      style: const ArcaneStyleData(
        padding: PaddingPreset.sectionY,
        flexGrow: 1,
      ),
      children: [
        ArcaneBox(
          maxWidth: MaxWidth.container,
          margin: MarginPreset.autoX,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              style: const ArcaneStyleData(gap: Gap.xxl),
              children: [
                // Section header using new ArcaneSectionHeader component
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  style: ArcaneStyleData(gap: Gap.sm),
                  children: [
                    Text.heading('Features'),
                    Text.body(
                      'Everything you need to build modern web applications',
                    ),
                  ],
                ),
                // Feature cards in a grid
                ArcaneBox(
                  style: const ArcaneStyleData(
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

class _FeatureCard extends StatelessWidget {
  final Widget icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ArcaneBox(
        style: const ArcaneStyleData(padding: PaddingPreset.lg),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            style: const ArcaneStyleData(gap: Gap.md),
            children: [
              // Icon with accent background
              ArcaneBox(
                style: const ArcaneStyleData(
                  padding: PaddingPreset.sm,
                  borderRadius: Radius.lg,
                  background: Background.accentContainer,
                  textColor: TextColor.accent,
                  display: Display.inlineFlex,
                ),
                children: [icon],
              ),
              // Title
              ArcaneBox(
                style: const ArcaneStyleData(
                  fontSize: FontSize.lg,
                  fontWeight: FontWeight.w600,
                  textColor: TextColor.primary,
                ),
                children: [Text(title)],
              ),
              // Description
              ArcaneBox(
                style: const ArcaneStyleData(
                  textColor: TextColor.muted,
                  lineHeight: LineHeight.relaxed,
                ),
                children: [Text(description)],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
