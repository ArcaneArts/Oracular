import 'package:arcane_jaspr/arcane_jaspr.dart';

import '../utils/constants.dart';

/// About screen - information about the application
class AboutScreen extends StatelessComponent {
  const AboutScreen({super.key});

  @override
  Component build(BuildContext context) {
    return ArcaneDiv(
      styles: const ArcaneStyleData(
        minHeight: '100vh',
        background: Background.background,
        textColor: TextColor.primary,
        fontFamily: FontFamily.sans,
      ),
      children: [
        // Header
        _Header(),

        // Content
        _Content(),
      ],
    );
  }
}

class _Header extends StatelessComponent {
  const _Header();

  @override
  Component build(BuildContext context) {
    return ArcaneDiv(
      styles: const ArcaneStyleData(
        padding: PaddingPreset.lg,
        border: BorderPreset.subtle,
      ),
      children: [
        ArcaneRow(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo/Brand
            a(
              href: AppRoutes.home,
              [
                ArcaneDiv(
                  styles: const ArcaneStyleData(
                    fontSize: FontSize.xl,
                    fontWeight: FontWeight.bold,
                    textColor: TextColor.primary,
                  ),
                  children: [ArcaneText('ArcaneJasprApp')],
                ),
              ],
            ),

            // Navigation
            ArcaneRow(
              style: const ArcaneStyleData(gap: Gap.lg),
              children: [
                a(href: AppRoutes.home, [
                  ArcaneButton.ghost(
                    label: 'Home',
                    onPressed: () {},
                  ),
                ]),
                a(href: AppRoutes.about, [
                  ArcaneButton.ghost(
                    label: 'About',
                    onPressed: () {},
                  ),
                ]),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _Content extends StatelessComponent {
  const _Content();

  @override
  Component build(BuildContext context) {
    return ArcaneDiv(
      styles: const ArcaneStyleData(
        padding: PaddingPreset.sectionY,
      ),
      children: [
        ArcaneBox(
          maxWidth: MaxWidth.content,
          margin: MarginPreset.autoX,
          children: [
            ArcaneColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              style: const ArcaneStyleData(gap: Gap.lg),
              children: [
                // Page title
                ArcaneDiv(
                  styles: const ArcaneStyleData(
                    fontSize: FontSize.xl3,
                    fontWeight: FontWeight.bold,
                    textColor: TextColor.primary,
                  ),
                  children: [ArcaneText('About')],
                ),

                // Description
                ArcaneDiv(
                  styles: const ArcaneStyleData(
                    fontSize: FontSize.lg,
                    textColor: TextColor.muted,
                    lineHeight: LineHeight.relaxed,
                  ),
                  children: [
                    ArcaneText(
                      'ArcaneJasprApp is a modern web application template built with Jaspr - the Dart web framework.',
                    ),
                  ],
                ),
                ArcaneDiv(
                  styles: const ArcaneStyleData(
                    fontSize: FontSize.lg,
                    textColor: TextColor.muted,
                    lineHeight: LineHeight.relaxed,
                  ),
                  children: [
                    ArcaneText(
                      'This template includes the Arcane design system for beautiful, '
                      'consistent UI components, along with routing, logging, and '
                      'a ready-to-use project structure.',
                    ),
                  ],
                ),

                // Getting Started section
                ArcaneDiv(
                  styles: const ArcaneStyleData(
                    fontSize: FontSize.xl2,
                    fontWeight: FontWeight.bold,
                    textColor: TextColor.primary,
                    margin: MarginPreset.topXl,
                  ),
                  children: [ArcaneText('Getting Started')],
                ),

                ArcaneCard(
                  child: ArcaneDiv(
                    styles: const ArcaneStyleData(
                      padding: PaddingPreset.lg,
                    ),
                    children: [
                      _ListItem(
                          content:
                              'Run jaspr serve to start the development server'),
                      _ListItem(content: 'Edit screens in lib/screens/'),
                      _ListItem(
                          content: 'Add routes in lib/routes/app_router.dart'),
                      _ListItem(
                          content: 'Build for production with jaspr build'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _ListItem extends StatelessComponent {
  final String content;

  const _ListItem({required this.content});

  @override
  Component build(BuildContext context) {
    return ArcaneRow(
      style: const ArcaneStyleData(
        gap: Gap.sm,
        margin: MarginPreset.bottomSm,
      ),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ArcaneDiv(
          styles: const ArcaneStyleData(
            textColor: TextColor.brandPrimary,
            fontWeight: FontWeight.bold,
          ),
          children: [ArcaneText('•')],
        ),
        ArcaneDiv(
          styles: const ArcaneStyleData(
            textColor: TextColor.muted,
          ),
          children: [ArcaneText(content)],
        ),
      ],
    );
  }
}
