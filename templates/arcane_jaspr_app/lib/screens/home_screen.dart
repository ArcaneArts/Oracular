import 'package:arcane_jaspr/arcane_jaspr.dart';

import '../utils/constants.dart';

/// Home screen - landing page for the application
class HomeScreen extends StatelessComponent {
  const HomeScreen({super.key});

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

        // Hero section
        section(
          classes: 'container mx-auto px-4 py-24 text-center',
          [
            h1(
              classes: 'text-5xl font-bold text-foreground mb-6',
              [text('Welcome to ArcaneJasprApp')],
            ),
            p(
              classes: 'text-xl text-muted-foreground mb-8 max-w-2xl mx-auto',
              [
                text(
                  'A modern web application built with Jaspr and Arcane design system.',
                ),
              ],
            ),
            div(
              classes: 'flex gap-4 justify-center',
              [
                a(
                  href: AppRoutes.about,
                  classes:
                      'px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:opacity-90',
                  [text('Learn More')],
                ),
              ],
            ),
          ],
        ),

        // Features section
        section(
          classes: 'container mx-auto px-4 py-16',
          [
            h2(
              classes: 'text-3xl font-bold text-foreground text-center mb-12',
              [text('Features')],
            ),
            div(
              classes: 'grid md:grid-cols-3 gap-8',
              [
                _featureCard(
                  'Fast & Modern',
                  'Built with Dart and Jaspr for blazing fast performance.',
                ),
                _featureCard(
                  'Arcane Design',
                  'Beautiful UI components from the Arcane design system.',
                ),
                _featureCard(
                  'Full Stack',
                  'Works seamlessly with Dart servers and shared models.',
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Component _featureCard(String title, String description) {
    return div(
      classes: 'p-6 bg-card rounded-lg border border-border',
      [
        h3(
          classes: 'text-xl font-semibold text-card-foreground mb-2',
          [text(title)],
        ),
        p(
          classes: 'text-muted-foreground',
          [text(description)],
        ),
      ],
    );
  }
}
