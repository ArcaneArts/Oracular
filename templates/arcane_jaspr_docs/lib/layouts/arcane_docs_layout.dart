import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';
import 'package:fast_log/fast_log.dart';

import '../components/docs_sidebar.dart';
import '../components/docs_header.dart';
import '../components/docs_toc.dart';
import '../utils/constants.dart';

/// Custom documentation layout using Arcane UI components
class ArcaneDocsLayout extends PageLayout {
  ArcaneDocsLayout();

  @override
  String get id => 'docs';

  @override
  Component build(BuildContext context, Page page) {
    verbose('Building ArcaneDocsLayout for: ${page.url}');

    final toc = page.tableOfContents;

    return ArcaneWindow(
      theme: ArcaneTheme.supabase(
        accent: AccentTheme.emerald,
        themeMode: ThemeMode.dark,
      ),
      child: Document(
        title: '${page.title} | ${AppConstants.siteName}',
        lang: 'en',
        head: [
          link(rel: 'icon', type: 'image/x-icon', href: '/favicon.ico'),
          meta(name: 'description', content: page.description ?? AppConstants.siteDescription),
          meta(name: 'viewport', content: 'width=device-width, initial-scale=1'),
        ],
        body: Screen(
          header: const DocsHeader(),
          sidebar: DocsSidebar(currentPath: page.url),
          child: Div(
            styles: ArcaneStyleData(
              display: Display.flex,
              gap: Gap.xl,
              padding: PaddingPreset.xl,
              maxWidth: '1200px',
              margin: 'auto',
            ),
            children: [
              // Main content area
              Div(
                styles: ArcaneStyleData(
                  flex: '1',
                  minWidth: '0',
                ),
                children: [
                  // Page title
                  if (page.title != null)
                    Div.child(
                      styles: ArcaneStyleData(
                        marginBottom: ArcaneSpacing.lg,
                      ),
                      child: ArcaneText.display(page.title!),
                    ),

                  // Page description
                  if (page.description != null)
                    Div.child(
                      styles: ArcaneStyleData(
                        marginBottom: ArcaneSpacing.xl,
                        color: ArcaneColors.textMuted,
                      ),
                      child: ArcaneText.lg(page.description!),
                    ),

                  // Rendered markdown content
                  Div.child(
                    styles: ArcaneStyleData(
                      // Prose styling for markdown content
                    ),
                    classes: 'prose',
                    child: page.content,
                  ),

                  // Page navigation (prev/next)
                  if (page.previous != null || page.next != null)
                    Div(
                      styles: ArcaneStyleData(
                        display: Display.flex,
                        justifyContent: JustifyContent.spaceBetween,
                        marginTop: ArcaneSpacing.xxl,
                        paddingTop: ArcaneSpacing.lg,
                        borderTop: '1px solid ${ArcaneColors.border}',
                      ),
                      children: [
                        if (page.previous != null)
                          _buildPageLink(page.previous!, isPrevious: true)
                        else
                          Div(children: []),
                        if (page.next != null)
                          _buildPageLink(page.next!, isPrevious: false),
                      ],
                    ),
                ],
              ),

              // Table of contents (right sidebar)
              if (toc != null && toc.isNotEmpty)
                DocsToc(tableOfContents: toc),
            ],
          ),
        ),
      ),
    );
  }

  Component _buildPageLink(PageLink link, {required bool isPrevious}) {
    return a(
      href: link.url,
      [
        Div(
          styles: ArcaneStyleData(
            display: Display.flex,
            flexDirection: FlexDirection.column,
            gap: Gap.xs,
            padding: PaddingPreset.md,
            borderRadius: BorderRadiusPreset.md,
            backgroundColor: ArcaneColors.surface,
            textAlign: isPrevious ? 'left' : 'right',
          ),
          children: [
            Div.child(
              styles: ArcaneStyleData(
                color: ArcaneColors.textMuted,
                fontSize: FontSizePreset.sm,
              ),
              child: Text(isPrevious ? 'Previous' : 'Next'),
            ),
            Div.child(
              styles: ArcaneStyleData(
                color: ArcaneColors.accent,
                fontWeight: FontWeightPreset.medium,
              ),
              child: Text(link.title ?? link.url),
            ),
          ],
        ),
      ],
    );
  }
}
