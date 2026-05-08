import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:arcane_jaspr_shadcn/arcane_jaspr_shadcn.dart';
import 'package:fast_log/fast_log.dart';

import 'routes/app_router.dart';
import 'seo/seo.dart';

/// arcane_jaspr_app - Main application component with theming + site-wide SEO.
///
/// The outer [Seo] here only sets the site-wide defaults (title, description,
/// WebSite + Organization JSON-LD). Each screen can override these by wrapping
/// its body in another [Seo] - the deeper widget wins.
class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  bool _isDark = true; // Default to dark theme

  @override
  void initState() {
    super.initState();
    verbose('App initializing with dark mode: $_isDark');
  }

  void _toggleTheme() {
    setState(() => _isDark = !_isDark);
    verbose('Theme toggled to: ${_isDark ? "dark" : "light"}');
  }

  @override
  Widget build(BuildContext context) {
    verbose('Building App component');
    final Brightness brightness = _isDark ? Brightness.dark : Brightness.light;

    return Seo(
      // Site-wide JSON-LD: WebSite + Organization. Per-page schemas
      // (Article, FAQPage, BreadcrumbList...) are added by the screens.
      structuredData: <StructuredData>[
        StructuredData.website(),
        StructuredData.organization(),
      ],
      // Use ArcaneApp wrapper for theming
      child: ArcaneApp(
        stylesheet: const ShadcnStylesheet(theme: ShadcnTheme.midnight),
        brightness: brightness,
        includeFallbackScripts: false, // Client app doesn't need static fallbacks
        home: AppRouter(isDark: _isDark, onThemeToggle: _toggleTheme),
      ),
    );
  }
}
