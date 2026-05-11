import 'package:arcane_jaspr/arcane_jaspr.dart';

import '../components/app_header.dart';
import '../utils/constants.dart';

/// Static "About" page; example of a second Jaspr-rendered route that
/// lives alongside the Flutter mount.
class AboutScreen extends StatelessWidget {
  final bool isDark;
  final void Function()? onThemeToggle;

  const AboutScreen({super.key, this.isDark = true, this.onThemeToggle});

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
          currentPath: AppRoutes.about,
        ),
        const _Content(),
      ],
    );
  }
}

class _Content extends StatelessWidget {
  const _Content();

  @override
  Widget build(BuildContext context) {
    return const ArcaneBox(
      style: ArcaneStyleData(padding: PaddingPreset.sectionY, flexGrow: 1),
      children: [
        ArcaneBox(
          maxWidth: MaxWidth.content,
          margin: MarginPreset.autoX,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              style: ArcaneStyleData(gap: Gap.lg),
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  style: ArcaneStyleData(gap: Gap.sm),
                  children: [
                    Text.heading('About'),
                    Text.body(
                      'This site is a Jaspr static shell that hosts a full '
                      'Flutter web app at /app. Visit /app to launch it.',
                    ),
                  ],
                ),

                // Why this layout
                ArcaneBox(
                  style: ArcaneStyleData(margin: MarginPreset.topXl),
                  children: [Text.heading2('Why one repo with two packages?')],
                ),
                Card(
                  child: ArcaneBox(
                    style: ArcaneStyleData(padding: PaddingPreset.lg),
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        style: ArcaneStyleData(gap: Gap.sm),
                        children: [
                          Text(
                            'The Jaspr package owns the marketing site, '
                            'rendered at build time for SEO.',
                          ),
                          Text(
                            'The Flutter package owns the real product UX, '
                            'mounted at /app/ as a Flutter web bundle.',
                          ),
                          Text(
                            'Firebase Hosting rewrites /app/** to '
                            'Flutter\'s index.html so deep links survive '
                            'page refresh.',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tech stack section
                ArcaneBox(
                  style: ArcaneStyleData(margin: MarginPreset.topXl),
                  children: [Text.heading2('Tech Stack')],
                ),
                Row(
                  style: ArcaneStyleData(gap: Gap.sm, flexWrap: FlexWrap.wrap),
                  children: [
                    ArcaneStatusBadge.success('Jaspr'),
                    ArcaneStatusBadge.info('Flutter'),
                    ArcaneStatusBadge.info('Arcane UI'),
                    ArcaneStatusBadge.info('Firebase Hosting'),
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
