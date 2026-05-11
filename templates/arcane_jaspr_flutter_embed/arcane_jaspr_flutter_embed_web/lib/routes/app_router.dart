import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:fast_log/fast_log.dart';

import '../screens/about_screen.dart';
import '../screens/landing_screen.dart';
import '../utils/constants.dart';

/// Top-level router for the embed host's Jaspr pages.
///
/// Note: `/app/**` is **NOT** routed here. Firebase Hosting rewrites
/// match `/app/**` to the Flutter SPA's `index.html` before the request
/// ever reaches Jaspr, so the embed app has no Jaspr-side "/app" route.
/// This keeps Flutter as the sole owner of `/app/**` deep-linking.
class AppRouter extends StatelessWidget {
  final bool isDark;
  final void Function()? onThemeToggle;

  const AppRouter({super.key, this.isDark = true, this.onThemeToggle});

  @override
  Widget build(BuildContext context) {
    verbose('Building AppRouter (embed host)');
    return RouterOutlet(isDark: isDark, onThemeToggle: onThemeToggle);
  }
}

/// Resolves the current URL path to the right Jaspr screen.
class RouterOutlet extends StatelessWidget {
  final bool isDark;
  final void Function()? onThemeToggle;

  const RouterOutlet({super.key, this.isDark = true, this.onThemeToggle});

  @override
  Widget build(BuildContext context) {
    final Uri currentUri = Uri.base;
    final String path = currentUri.path.isEmpty ? '/' : currentUri.path;
    verbose('Routing to path: $path');

    switch (path) {
      case AppRoutes.about:
        navigation('Navigating to About');
        return AboutScreen(isDark: isDark, onThemeToggle: onThemeToggle);
      case AppRoutes.home:
      default:
        navigation('Navigating to Landing');
        return LandingScreen(isDark: isDark, onThemeToggle: onThemeToggle);
    }
  }
}
