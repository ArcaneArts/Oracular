import 'package:arcane_beamer_app/routes.dart';
import 'package:arcane/arcane.dart';
import 'package:beamer/beamer.dart';

//  █████╗ ██████╗  ██████╗ █████╗ ███╗   ██╗███████╗    ██████╗ ███████╗ █████╗ ███╗   ███╗███████╗██████╗
// ██╔══██╗██╔══██╗██╔════╝██╔══██╗████╗  ██║██╔════╝    ██╔══██╗██╔════╝██╔══██╗████╗ ████║██╔════╝██╔══██╗
// ███████║██████╔╝██║     ███████║██╔██╗ ██║█████╗      ██████╔╝█████╗  ███████║██╔████╔██║█████╗  ██████╔╝
// ██╔══██║██╔══██╗██║     ██╔══██║██║╚██╗██║██╔══╝      ██╔══██╗██╔══╝  ██╔══██║██║╚██╔╝██║██╔══╝  ██╔══██╗
// ██║  ██║██║  ██║╚██████╗██║  ██║██║ ╚████║███████╗    ██████╔╝███████╗██║  ██║██║ ╚═╝ ██║███████╗██║  ██║
// ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝    ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝
//
// A demo/template project showcasing ARCANE styling with Beamer navigation.
// No Material Design is used - pure Arcane components only.

void main() {
  // Set Beamer to use path URL strategy (for web - removes the # from URLs)
  Beamer.setPathUrlStrategy();

  runApp("arcane_beamer_app", const ArcaneBeamerApp());
}

class ArcaneBeamerApp extends StatefulWidget {
  const ArcaneBeamerApp({super.key});

  @override
  State<ArcaneBeamerApp> createState() => _ArcaneBeamerAppState();
}

class _ArcaneBeamerAppState extends State<ArcaneBeamerApp> {
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
    return ArcaneApp.router(
      routeInformationParser: BeamerParser(),
      routerDelegate: routerDelegate,
      debugShowCheckedModeBanner: false,
      theme: ArcaneTheme(
        // You can customize the color scheme here
        scheme: ContrastedColorScheme(
          light: ColorSchemes.blue(ThemeMode.light),
          dark: ColorSchemes.blue(ThemeMode.dark),
        ),
        themeMode: _themeMode,
      ),
    );
  }
}

/// Extension to provide easy access to theme mode toggle
extension ArcaneBeamerAppContext on BuildContext {
  void toggleTheme() {
    final state = findAncestorStateOfType<_ArcaneBeamerAppState>();
    state?._toggleTheme();
  }

  ThemeMode get currentThemeMode {
    final state = findAncestorStateOfType<_ArcaneBeamerAppState>();
    return state?._themeMode ?? ThemeMode.system;
  }
}
