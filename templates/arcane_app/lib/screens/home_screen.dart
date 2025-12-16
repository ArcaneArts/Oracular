import 'package:arcane_app/screens/settings_screen.dart';
import 'package:arcane/arcane.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Screen(
      header: Bar(titleText: "Arcane Template", subtitleText: "Welcome"),
      gutter: true,
      child: Collection(
        children: [
          // Welcome card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome to Arcane Template",
                    style: Theme.of(context).typography.large,
                  ),
                  const Gap(12),
                  const Text(
                    "This is a minimal template project using pure Arcane styling. "
                    "Start building by modifying screens or adding new components.",
                  ),
                ],
              ),
            ),
          ),
          const Gap(16),

          // Features section
          Section(
            titleText: "Features",
            child: Collection(
              children: [
                Tile(
                  leading: const Icon(Icons.palette),
                  title: const Text("Pure Arcane Styling"),
                  subtitle: const Text("No Material Design components"),
                  onPressed: () {},
                ),
                Tile(
                  leading: const Icon(Icons.moon),
                  title: const Text("Theme Support"),
                  subtitle: const Text("Light, Dark, and System themes"),
                  trailing: const Icon(Icons.chevron_forward_ionic),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
                Tile(
                  leading: const Icon(Icons.layout),
                  title: const Text("Navigation"),
                  subtitle: const Text("Built-in Arcane NavigationScreen"),
                  trailing: const Icon(Icons.chevron_forward_ionic),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
