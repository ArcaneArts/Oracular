import 'package:arcane_jaspr/arcane_jaspr.dart';

import '../utils/constants.dart';

/// Documentation site header with navigation
class DocsHeader extends StatelessComponent {
  const DocsHeader({super.key});

  @override
  Component build(BuildContext context) {
    return Bar(
      leading: [
        a(
          href: '/',
          [
            Div(
              styles: ArcaneStyleData(
                display: Display.flex,
                alignItems: AlignItems.center,
                gap: Gap.sm,
              ),
              children: [
                Div.child(
                  styles: ArcaneStyleData(
                    fontWeight: FontWeightPreset.bold,
                    fontSize: FontSizePreset.lg,
                    color: ArcaneColors.text,
                  ),
                  child: Text(AppConstants.siteName),
                ),
              ],
            ),
          ],
        ),
      ],
      trailing: [
        ArcaneButton.ghost(
          label: 'Docs',
          onPressed: () {},
          href: '/docs',
        ),
        ArcaneButton.ghost(
          label: 'Guides',
          onPressed: () {},
          href: '/guides',
        ),
        if (AppConstants.githubUrl.isNotEmpty)
          IconButton(
            icon: Icons.github,
            tooltip: 'GitHub',
            onPressed: () {},
            href: AppConstants.githubUrl,
          ),
      ],
      sticky: true,
    );
  }
}
