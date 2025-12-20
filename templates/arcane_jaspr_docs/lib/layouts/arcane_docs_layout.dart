import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';

import '../components/docs_sidebar.dart';
import '../components/docs_header.dart';

/// Custom documentation layout using Arcane UI components
class ArcaneDocsLayout extends PageLayoutBase {
  const ArcaneDocsLayout();

  @override
  Pattern get name => 'docs';

  @override
  Iterable<Component> buildHead(Page page) sync* {
    yield* super.buildHead(page);
    yield link(rel: 'icon', type: 'image/x-icon', href: '/favicon.ico');
    yield meta(name: 'viewport', content: 'width=device-width, initial-scale=1');
    yield link(rel: 'stylesheet', href: '/styles.css');
  }

  @override
  Component buildBody(Page page, Component child) {
    final pageData = page.data.page;
    final title = pageData['title'] as String?;
    final description = pageData['description'] as String?;
    final toc = page.data['toc'] as TableOfContents?;

    return ArcaneApp(
      theme: ArcaneTheme.supabase(
        accent: AccentTheme.emerald,
        themeMode: ThemeMode.dark,
      ),
      child: ArcaneDiv(
        styles: const ArcaneStyleData(
          display: Display.flex,
          minHeight: '100vh',
          background: Background.background,
          textColor: TextColor.primary,
          fontFamily: FontFamily.sans,
        ),
        children: [
          // Sidebar
          DocsSidebar(currentPath: page.url),

          // Main area
          ArcaneDiv(
            styles: const ArcaneStyleData(
              flexGrow: 1,
              display: Display.flex,
              flexDirection: FlexDirection.column,
              minHeight: '100vh',
            ),
            children: [
              // Header
              const DocsHeader(),

              // Content area
              ArcaneDiv(
                styles: const ArcaneStyleData(
                  display: Display.flex,
                  gap: Gap.xl,
                  padding: PaddingPreset.xl,
                  maxWidth: MaxWidth.container,
                  margin: MarginPreset.autoX,
                  flexGrow: 1,
                ),
                children: [
                  // Main content area
                  ArcaneDiv(
                    styles: const ArcaneStyleData(
                      flexGrow: 1,
                      raw: {
                        'min-width': '0',
                      },
                    ),
                    children: [
                      // Page title
                      if (title != null)
                        ArcaneDiv(
                          styles: const ArcaneStyleData(
                            margin: MarginPreset.bottomLg,
                            fontSize: FontSize.xl3,
                            fontWeight: FontWeight.bold,
                            textColor: TextColor.primary,
                          ),
                          children: [ArcaneText(title)],
                        ),

                      // Page description
                      if (description != null)
                        ArcaneDiv(
                          styles: const ArcaneStyleData(
                            margin: MarginPreset.bottomXl,
                            textColor: TextColor.muted,
                            fontSize: FontSize.lg,
                          ),
                          children: [ArcaneText(description)],
                        ),

                      // Rendered markdown content
                      div(
                        classes: 'prose',
                        [child],
                      ),
                    ],
                  ),

                  // Table of contents (right sidebar)
                  if (toc != null)
                    ArcaneDiv(
                      styles: const ArcaneStyleData(
                        widthCustom: '220px',
                        flexShrink: 0,
                        position: Position.sticky,
                        overflow: Overflow.auto,
                        raw: {
                          'top': '80px',
                          'align-self': 'flex-start',
                          'max-height': 'calc(100vh - 100px)',
                        },
                      ),
                      children: [
                        ArcaneDiv(
                          styles: const ArcaneStyleData(
                            fontSize: FontSize.sm,
                            fontWeight: FontWeight.w600,
                            textColor: TextColor.muted,
                            margin: MarginPreset.bottomMd,
                            textTransform: TextTransform.uppercase,
                            letterSpacing: LetterSpacing.wide,
                          ),
                          children: [ArcaneText('On this page')],
                        ),
                        ArcaneDiv(
                          styles: const ArcaneStyleData(
                            raw: {
                              'border-left': '1px solid var(--border-primary)',
                              'padding-left': '16px',
                            },
                          ),
                          children: [toc.build()],
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
