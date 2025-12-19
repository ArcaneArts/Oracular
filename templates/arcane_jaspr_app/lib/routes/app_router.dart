import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:fast_log/fast_log.dart';

import '../screens/home_screen.dart';
import '../screens/about_screen.dart';
import '../utils/constants.dart';

/// Main router component that handles navigation
class AppRouter extends StatelessComponent {
  const AppRouter({super.key});

  @override
  Component build(BuildContext context) {
    verbose('Building AppRouter');
    return const RouterOutlet();
  }
}

/// Router outlet that renders the appropriate screen based on path
class RouterOutlet extends StatelessComponent {
  const RouterOutlet({super.key});

  @override
  Component build(BuildContext context) {
    final String path = context.url;
    verbose('Routing to path: $path');

    switch (path) {
      case AppRoutes.about:
        navigation('Navigating to About');
        return const AboutScreen();
      case AppRoutes.home:
      default:
        navigation('Navigating to Home');
        return const HomeScreen();
    }
  }
}
