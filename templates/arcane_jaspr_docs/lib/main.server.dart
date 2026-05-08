/// The entrypoint for the **server** app (static generation).
///
/// SEO is automatic:
///   * jaspr_content emits per-page `<title>`, `description`, OpenGraph,
///     and Twitter Card tags from each markdown file's frontmatter.
///   * arcane_lexicon's `SitemapGenerator` writes `web/sitemap.xml` at
///     build time from the navigation manifest (set [SiteConfig.baseUrl]
///     in production to absolute URLs).
///   * `web/robots.txt` is shipped statically.
library;

import 'package:arcane_jaspr_shadcn/arcane_jaspr_shadcn.dart';
import 'package:arcane_lexicon/arcane_lexicon.dart' hide runApp;
import 'package:jaspr/server.dart';
import 'main.server.options.dart';
import 'utils/constants.dart';

/// `BASE_URL` env var lets you build for GitHub Pages / subdirectory hosts
/// without recompiling code. Pass via `--define=BASE_URL=/foo` to jaspr.
const String baseUrl = String.fromEnvironment('BASE_URL', defaultValue: '');

void main() async {
  Jaspr.initializeApp(options: defaultServerOptions);

  runApp(
    await KnowledgeBaseApp.create(
      config: SiteConfig(
        name: AppConstants.siteName,
        description: AppConstants.siteDescription,
        contentDirectory: 'content',
        baseUrl: baseUrl,
        githubUrl: AppConstants.githubUrl.isEmpty
            ? null
            : AppConstants.githubUrl,
        searchEnabled: true,
        tocEnabled: true,
        themeToggleEnabled: true,
        pageNavEnabled: true,
        navigationBarEnabled: true,
        navigationBarPosition: KBNavigationBarPosition.top,
        defaultTheme: KBThemeMode.dark,
        showEditLink: true,
        editBranch: 'main',
      ),
      stylesheet: const ShadcnStylesheet(theme: ShadcnTheme.midnight),
    ),
  );
}
