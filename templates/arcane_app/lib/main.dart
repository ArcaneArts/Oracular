import 'package:arcane_app/screens/home_screen.dart';
import 'package:arcane/arcane.dart';

//  █████╗ ██████╗  ██████╗ █████╗ ███╗   ██╗███████╗    ████████╗███████╗███╗   ███╗██████╗ ██╗      █████╗ ████████╗███████╗
// ██╔══██╗██╔══██╗██╔════╝██╔══██╗████╗  ██║██╔════╝    ╚══██╔══╝██╔════╝████╗ ████║██╔══██╗██║     ██╔══██╗╚══██╔══╝██╔════╝
// ███████║██████╔╝██║     ███████║██╔██╗ ██║█████╗         ██║   █████╗  ██╔████╔██║██████╔╝██║     ███████║   ██║   █████╗
// ██╔══██║██╔══██╗██║     ██╔══██║██║╚██╗██║██╔══╝         ██║   ██╔══╝  ██║╚██╔╝██║██╔═══╝ ██║     ██╔══██║   ██║   ██╔══╝
// ██║  ██║██║  ██║╚██████╗██║  ██║██║ ╚████║███████╗       ██║   ███████╗██║ ╚═╝ ██║██║     ███████╗██║  ██║   ██║   ███████╗
// ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝       ╚═╝   ╚══════╝╚═╝     ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝
//
// A minimal template project for building apps with ARCANE styling.
// No Material Design - pure Arcane components only.

void main() {
  runApp("arcane_app", const ArcaneTemplateApp());
}

class ArcaneTemplateApp extends StatefulWidget {
  const ArcaneTemplateApp({super.key});

  @override
  State<ArcaneTemplateApp> createState() => _ArcaneTemplateAppState();
}

class _ArcaneTemplateAppState extends State<ArcaneTemplateApp> {
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
        // You can customize the color scheme here
        scheme: ContrastedColorScheme(
          light: ColorSchemes.blue(ThemeMode.light),
          dark: ColorSchemes.blue(ThemeMode.dark),
        ),
        themeMode: _themeMode,
      ),
      home: const HomeScreen(),
    );
  }
}

/// Extension to provide easy access to theme mode toggle
extension ArcaneTemplateAppContext on BuildContext {
  void toggleTheme() {
    final state = findAncestorStateOfType<_ArcaneTemplateAppState>();
    state?._toggleTheme();
  }

  ThemeMode get currentThemeMode {
    final state = findAncestorStateOfType<_ArcaneTemplateAppState>();
    return state?._themeMode ?? ThemeMode.system;
  }
}
