import 'package:arcane_jaspr/arcane_jaspr.dart';

import '../utils/constants.dart';

/// About screen - information about the application
class AboutScreen extends StatelessComponent {
  const AboutScreen({super.key});

  @override
  Component build(BuildContext context) {
    return div(
      classes: 'min-h-screen bg-background',
      [
        // Header
        header(
          classes: 'container mx-auto px-4 py-6',
          [
            nav(
              classes: 'flex items-center justify-between',
              [
                a(
                  href: AppRoutes.home,
                  classes: 'text-xl font-bold text-foreground',
                  [text('ArcaneJasprApp')],
                ),
                div(
                  classes: 'flex gap-4',
                  [
                    a(
                      href: AppRoutes.home,
                      classes: 'text-muted-foreground hover:text-foreground',
                      [text('Home')],
                    ),
                    a(
                      href: AppRoutes.about,
                      classes: 'text-muted-foreground hover:text-foreground',
                      [text('About')],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // Content
        section(
          classes: 'container mx-auto px-4 py-16 max-w-3xl',
          [
            h1(
              classes: 'text-4xl font-bold text-foreground mb-8',
              [text('About')],
            ),
            div(
              classes: 'prose prose-invert',
              [
                p(
                  classes: 'text-lg text-muted-foreground mb-6',
                  [
                    text(
                      'ArcaneJasprApp is a modern web application template built with ',
                    ),
                    a(
                      href: 'https://jaspr.site',
                      target: '_blank',
                      classes: 'text-primary hover:underline',
                      [text('Jaspr')],
                    ),
                    text(' - the Dart web framework.'),
                  ],
                ),
                p(
                  classes: 'text-lg text-muted-foreground mb-6',
                  [
                    text(
                      'This template includes the Arcane design system for beautiful, '
                      'consistent UI components, along with routing, logging, and '
                      'a ready-to-use project structure.',
                    ),
                  ],
                ),
                h2(
                  classes: 'text-2xl font-bold text-foreground mt-8 mb-4',
                  [text('Getting Started')],
                ),
                ul(
                  classes: 'list-disc list-inside text-muted-foreground space-y-2',
                  [
                    li([text('Run jaspr serve to start the development server')]),
                    li([text('Edit screens in lib/screens/')]),
                    li([text('Add routes in lib/routes/app_router.dart')]),
                    li([text('Build for production with jaspr build')]),
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
