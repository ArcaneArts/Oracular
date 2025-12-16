import 'package:arcane/arcane.dart';
import 'package:oracular_gui/screens/wizard_screen.dart';

// ██████╗ ██╗     ██╗   ██╗███╗   ██╗██████╗ ███████╗██████╗ ██╗     ███████╗██╗  ██╗
// ██╔══██╗██║     ██║   ██║████╗  ██║██╔══██╗██╔════╝██╔══██╗██║     ██╔════╝╚██╗██╔╝
// ██████╔╝██║     ██║   ██║██╔██╗ ██║██║  ██║█████╗  ██████╔╝██║     █████╗   ╚███╔╝
// ██╔══██╗██║     ██║   ██║██║╚██╗██║██║  ██║██╔══╝  ██╔══██╗██║     ██╔══╝   ██╔██╗
// ██████╔╝███████╗╚██████╔╝██║ ╚████║██████╔╝███████╗██║  ██║███████╗███████╗██╔╝ ██╗
// ╚═════╝ ╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝
//
// Oracular GUI - Visual project creation wizard for Arcane Templates

void main() {
  runApp("oracular_gui", const OracularGuiApp());
}

class OracularGuiApp extends StatefulWidget {
  const OracularGuiApp({super.key});

  @override
  State<OracularGuiApp> createState() => _OracularGuiAppState();
}

class _OracularGuiAppState extends State<OracularGuiApp> {
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
          light: ColorSchemes.violet(ThemeMode.light),
          dark: ColorSchemes.orange(ThemeMode.dark),
        ),
        themeMode: _themeMode,
      ),
      home: const WizardScreen(),
    );
  }
}

extension OracularGuiAppContext on BuildContext {
  void toggleTheme() {
    final _OracularGuiAppState? state = findAncestorStateOfType<_OracularGuiAppState>();
    state?._toggleTheme();
  }

  ThemeMode get currentThemeMode {
    final _OracularGuiAppState? state = findAncestorStateOfType<_OracularGuiAppState>();
    return state?._themeMode ?? ThemeMode.system;
  }
}
