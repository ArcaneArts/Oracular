import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:arcane_jaspr_shadcn/arcane_jaspr_shadcn.dart';
import 'package:fast_log/fast_log.dart';

import 'routes/app_router.dart';

/// Root component for the Jaspr-side of the embed template.
///
/// Provides site-wide theming and routes between:
///   - `/`       Jaspr-native marketing landing
///   - `/about`  Jaspr-native about page
///   - `/app/**` mount slot for the embedded Flutter web app
class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  bool _isDark = true;

  @override
  void initState() {
    super.initState();
    verbose('App initializing (embed host)');
  }

  void _toggleTheme() {
    setState(() => _isDark = !_isDark);
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = _isDark ? Brightness.dark : Brightness.light;
    return ArcaneApp(
      stylesheet: const ShadcnStylesheet(theme: ShadcnTheme.midnight),
      brightness: brightness,
      includeFallbackScripts: false,
      home: AppRouter(isDark: _isDark, onThemeToggle: _toggleTheme),
    );
  }
}
