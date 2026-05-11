/// Hybrid render mode — **static** route examples.
///
/// Pages listed here are pre-rendered at build time and served directly
/// from Firebase Hosting as static HTML. Use this file for:
///   * Landing pages, marketing pages, About / Contact / Pricing
///   * Blog posts (when the slug is known at build time)
///   * Documentation
///
/// Routes added here MUST be added to the rewrite block in
/// `firebase.json` (Oracular's `ConfigGenerator` does this automatically
/// from `HYBRID_DYNAMIC_PREFIXES` in `setup_config.env` — see
/// `oracular/lib/services/config_generator.dart`).
///
/// This file is only kept in projects scaffolded with
/// `JASPR_RENDER_MODE=hybrid`. CSR / SSG / SSR projects don't need it.
library;

import 'package:jaspr/jaspr.dart';

import '../screens/about_screen.dart';
import '../screens/home_screen.dart';
import '../utils/constants.dart';

/// Build-time route table for the static portion of the hybrid site.
///
/// Each entry is a single page that Jaspr's static prerender pass will
/// emit as a stand-alone HTML file under `build/jaspr/<path>/index.html`.
/// At request time, Firebase Hosting serves these directly without ever
/// hitting Cloud Run.
const List<StaticRoute> staticRoutes = <StaticRoute>[
  StaticRoute(
    path: AppRoutes.home,
    builder: HomeRoute.new,
    description: 'Marketing landing page (full SEO).',
  ),
  StaticRoute(
    path: AppRoutes.about,
    builder: AboutRoute.new,
    description: 'About / company info.',
  ),
];

/// Describes a single statically pre-rendered route.
class StaticRoute {
  final String path;
  final Component Function() builder;
  final String description;

  const StaticRoute({
    required this.path,
    required this.builder,
    required this.description,
  });
}

/// Thin wrappers so the build-time prerender pass has a Component
/// constructor with no required arguments.
class HomeRoute extends StatelessComponent {
  const HomeRoute({super.key});

  @override
  Iterable<Component> build(BuildContext context) sync* {
    yield const HomeScreen();
  }
}

class AboutRoute extends StatelessComponent {
  const AboutRoute({super.key});

  @override
  Iterable<Component> build(BuildContext context) sync* {
    yield const AboutScreen();
  }
}
