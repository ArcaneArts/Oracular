import 'package:arcane_template/main.dart';
import 'package:arcane/arcane.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Screen(
      header: Bar(
        titleText: "Settings",
      ),
      gutter: true,
      child: Collection(
        children: [
          Section(
            titleText: "Appearance",
            child: Collection(
              children: [
                Tile(
                  leading: const Icon(Icons.moon),
                  title: const Text("Theme Mode"),
                  subtitle: Text(_getThemeModeText(context)),
                  trailing: const Icon(Icons.chevron_forward_ionic),
                  onPressed: () => context.toggleTheme(),
                ),
              ],
            ),
          ),
          const Gap(16),
          Section(
            titleText: "About",
            child: Collection(
              children: [
                const Tile(
                  leading: Icon(Icons.info),
                  title: Text("Version"),
                  subtitle: Text("1.0.0"),
                ),
                const Tile(
                  leading: Icon(Icons.code),
                  title: Text("Framework"),
                  subtitle: Text("Arcane UI"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getThemeModeText(BuildContext context) {
    return switch (context.currentThemeMode) {
      ThemeMode.light => "Light",
      ThemeMode.dark => "Dark",
      ThemeMode.system => "System",
    };
  }
}
