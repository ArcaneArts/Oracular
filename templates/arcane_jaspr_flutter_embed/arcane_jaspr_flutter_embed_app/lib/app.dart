import 'package:arcane/arcane.dart';

import 'screens/home_screen.dart';

/// Root widget for the embedded Flutter web app.
///
/// Renders inside the Jaspr-rendered `<div id="flutter-app-mount">`
/// element on the host site's `/app` route. The Jaspr host owns the
/// page chrome (header, footer, theme boot); this app owns everything
/// that happens *inside* the mount slot.
class EmbeddedApp extends StatefulWidget {
  const EmbeddedApp({super.key});

  @override
  State<EmbeddedApp> createState() => _EmbeddedAppState();
}

class _EmbeddedAppState extends State<EmbeddedApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    setState(() {
      _themeMode = switch (_themeMode) {
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.system,
        ThemeMode.system => ThemeMode.light,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return ArcaneApp(
      debugShowCheckedModeBanner: false,
      theme: ArcaneTheme(
        scheme: ContrastedColorScheme(
          light: ColorSchemes.green(ThemeMode.light),
          dark: ColorSchemes.green(ThemeMode.dark),
        ),
        themeMode: _themeMode,
      ),
      home: const HomeScreen(),
    );
  }
}

/// Helper extension so screens can flip the theme without touching the
/// state class directly.
extension EmbeddedAppContext on BuildContext {
  void toggleTheme() {
    final _EmbeddedAppState? state = findAncestorStateOfType<_EmbeddedAppState>();
    state?._toggleTheme();
  }

  ThemeMode get currentThemeMode {
    final _EmbeddedAppState? state = findAncestorStateOfType<_EmbeddedAppState>();
    return state?._themeMode ?? ThemeMode.system;
  }
}
