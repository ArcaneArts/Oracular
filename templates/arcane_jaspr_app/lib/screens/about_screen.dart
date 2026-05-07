import 'package:arcane_jaspr/arcane_jaspr.dart';

import '../components/app_header.dart';
import '../utils/constants.dart';

/// About screen - information about the application
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
        // Header
        AppHeader(
          isDark: isDark,
          onThemeToggle: onThemeToggle,
          currentPath: AppRoutes.about,
        ),

        // Content
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
                // Page title using ArcaneSectionHeader
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  style: ArcaneStyleData(gap: Gap.sm),
                  children: [
                    Text.heading('About'),
                    Text.body(
                      '${AppConstants.appName} is a modern web application template built with Jaspr - the Dart web framework.',
                    ),
                  ],
                ),

                // Description text
                ArcaneBox(
                  style: ArcaneStyleData(
                    fontSize: FontSize.lg,
                    textColor: TextColor.muted,
                    lineHeight: LineHeight.relaxed,
                  ),
                  children: [
                    Text(
                      'This template includes the Arcane design system for beautiful, '
                      'consistent UI components, along with routing, logging, and '
                      'a ready-to-use project structure.',
                    ),
                  ],
                ),

                // Getting Started section
                ArcaneBox(
                  style: ArcaneStyleData(margin: MarginPreset.topXl),
                  children: [Text.heading2('Getting Started')],
                ),

                // Getting started checklist using ArcaneCheckList
                Card(
                  child: ArcaneBox(
                    style: ArcaneStyleData(padding: PaddingPreset.lg),
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        style: ArcaneStyleData(gap: Gap.sm),
                        children: [
                          _ChecklistItem(
                            text:
                                'Run jaspr serve to start the development server',
                          ),
                          _ChecklistItem(text: 'Edit screens in lib/screens/'),
                          _ChecklistItem(
                            text: 'Add routes in lib/routes/app_router.dart',
                          ),
                          _ChecklistItem(
                            text: 'Build for production with jaspr build',
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

                // Tech stack badges
                Row(
                  style: ArcaneStyleData(gap: Gap.sm, flexWrap: FlexWrap.wrap),
                  children: [
                    ArcaneStatusBadge.info('Dart'),
                    ArcaneStatusBadge.success('Jaspr'),
                    ArcaneStatusBadge.info('Arcane UI'),
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

class _ChecklistItem extends StatelessWidget {
  final String text;

  const _ChecklistItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      style: const ArcaneStyleData(gap: Gap.sm, alignItems: AlignItems.center),
      children: [
        ArcaneIcon.check(size: IconSize.sm),
        Text(text),
      ],
    );
  }
}
