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
    return Sidebar(
      header: SidebarHeader(
        title: AppConstants.siteName,
        subtitle: 'Documentation',
      ),
      children: [
        // Getting Started section
        SidebarGroup(
          title: 'Getting Started',
          initiallyExpanded: true,
          children: [
            SidebarItem(
              label: 'Introduction',
              icon: Icons.book,
              href: '/docs',
              active: currentPath == '/docs' || currentPath == '/docs/',
            ),
            SidebarItem(
              label: 'Installation',
              icon: Icons.download,
              href: '/docs/installation',
              active: currentPath == '/docs/installation',
            ),
            SidebarItem(
              label: 'Quick Start',
              icon: Icons.rocket,
              href: '/docs/quick-start',
              active: currentPath == '/docs/quick-start',
            ),
          ],
        ),

        // Core Concepts section
        SidebarGroup(
          title: 'Core Concepts',
          collapsible: true,
          initiallyExpanded: currentPath.contains('/docs/concepts'),
          children: [
            SidebarItem(
              label: 'Architecture',
              icon: Icons.layers,
              href: '/docs/concepts/architecture',
              active: currentPath == '/docs/concepts/architecture',
            ),
            SidebarItem(
              label: 'Configuration',
              icon: Icons.settings,
              href: '/docs/concepts/configuration',
              active: currentPath == '/docs/concepts/configuration',
            ),
          ],
        ),

        // Guides section
        SidebarGroup(
          title: 'Guides',
          collapsible: true,
          initiallyExpanded: currentPath.startsWith('/guides'),
          children: [
            SidebarItem(
              label: 'Deployment',
              icon: Icons.cloud,
              href: '/guides/deployment',
              active: currentPath == '/guides/deployment',
            ),
            SidebarItem(
              label: 'Customization',
              icon: Icons.palette,
              href: '/guides/customization',
              active: currentPath == '/guides/customization',
            ),
          ],
        ),

        // API Reference section
        SidebarGroup(
          title: 'API Reference',
          collapsible: true,
          children: [
            SidebarItem(
              label: 'Components',
              icon: Icons.code,
              href: '/docs/api/components',
              active: currentPath == '/docs/api/components',
            ),
            SidebarItem(
              label: 'Utilities',
              icon: Icons.tool,
              href: '/docs/api/utilities',
              active: currentPath == '/docs/api/utilities',
            ),
          ],
        ),
      ],
    );
  }
}
