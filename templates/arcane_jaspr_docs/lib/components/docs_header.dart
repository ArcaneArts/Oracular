import 'package:arcane_jaspr/arcane_jaspr.dart';

import '../utils/constants.dart';

/// Documentation site header with navigation
class DocsHeader extends StatelessComponent {
  const DocsHeader({super.key});

  @override
  Component build(BuildContext context) {
    return ArcaneBar(
      leading: [
        a(
          href: '/',
          [
            ArcaneDiv(
              styles: const ArcaneStyleData(
                display: Display.flex,
                alignItems: AlignItems.center,
                gap: Gap.sm,
              ),
              children: [
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
          ],
        ),
      ],
      trailing: [
        a(
          href: '/docs',
          [
            ArcaneButton.ghost(
              label: 'Docs',
              onPressed: () {},
            ),
          ],
        ),
        a(
          href: '/guides',
          [
            ArcaneButton.ghost(
              label: 'Guides',
              onPressed: () {},
            ),
          ],
        ),
        if (AppConstants.githubUrl.isNotEmpty)
          a(
            href: AppConstants.githubUrl,
            attributes: {'target': '_blank', 'rel': 'noopener'},
            [
              ArcaneButton.ghost(
                label: 'GitHub',
                onPressed: () {},
              ),
            ],
          ),
      ],
    );
  }
}
