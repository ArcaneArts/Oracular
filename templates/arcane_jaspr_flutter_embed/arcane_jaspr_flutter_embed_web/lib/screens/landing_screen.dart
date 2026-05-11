import 'package:arcane_jaspr/arcane_jaspr.dart';

import '../components/app_header.dart';
import '../utils/constants.dart';

/// Marketing landing page. SEO-friendly because it's pre-rendered at
/// build time by `main.server.dart` when the host is built in static
/// mode.
class LandingScreen extends StatelessWidget {
  final bool isDark;
  final void Function()? onThemeToggle;

  const LandingScreen({super.key, this.isDark = true, this.onThemeToggle});

  @override
  Widget build(BuildContext context) {
    return ArcaneBox(
      style: const ArcaneStyleData(
        minHeight: '100vh',
        display: Display.flex,
        flexDirection: FlexDirection.column,
      ),
      children: [
        AppHeader(
          isDark: isDark,
          onThemeToggle: onThemeToggle,
          currentPath: AppRoutes.home,
        ),
        const _HeroSection(),
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
            ArcaneBox(
              style: ArcaneStyleData(
                fontSize: FontSize.mega,
                fontWeight: FontWeight.w800,
                textColor: TextColor.primary,
                lineHeight: LineHeight.tight,
              ),
              children: [
                Text('A static marketing site, with a Flutter app inside.'),
              ],
            ),
            ArcaneBox(
              style: ArcaneStyleData(
                fontSize: FontSize.xl,
                textColor: TextColor.muted,
                maxWidth: MaxWidth.text,
              ),
              children: [
                Text(
                  'Pre-rendered for SEO. Hydrated for interactivity. '
                  'Launches a Flutter web app at /app for the real product '
                  'experience — all from one Firebase Hosting bundle.',
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              style: ArcaneStyleData(gap: Gap.md),
              children: [
                Button.primary(href: AppRoutes.app, label: 'Launch App'),
                Button.secondary(href: AppRoutes.about, label: 'Read more'),
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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  style: ArcaneStyleData(gap: Gap.sm),
                  children: [
                    Text.heading('Why this architecture?'),
                    Text.body(
                      'Get Jaspr SEO for crawlers and Flutter polish for users.',
                    ),
                  ],
                ),
                ArcaneBox(
                  style: const ArcaneStyleData(
                    display: Display.grid,
                    gridColumns: GridColumns.autoFitMd,
                    gap: Gap.lg,
                    width: Size.full,
                  ),
                  children: [
                    _FeatureCard(
                      icon: ArcaneIcon.search(size: IconSize.xl),
                      title: 'SEO-friendly shell',
                      description:
                          'Jaspr static prerender emits real HTML for crawlers; '
                          'OG/Twitter/JSON-LD all per-page.',
                    ),
                    _FeatureCard(
                      icon: ArcaneIcon.zap(size: IconSize.xl),
                      title: 'Rich Flutter app at /app',
                      description:
                          'A full Flutter web app mounts at /app/ with shared '
                          'cookies and a shared Firebase session.',
                    ),
                    _FeatureCard(
                      icon: ArcaneIcon.layers(size: IconSize.xl),
                      title: 'One deploy target',
                      description:
                          'Both packages ship as one Firebase Hosting bundle. '
                          'No iframe, no cross-origin headaches.',
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
              ArcaneBox(
                style: const ArcaneStyleData(
                  fontSize: FontSize.lg,
                  fontWeight: FontWeight.w600,
                  textColor: TextColor.primary,
                ),
                children: [Text(title)],
              ),
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
