import 'package:arcane/arcane.dart';
import 'package:beamer/beamer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Screen(
      header: Bar(
        titleText: "Arcane Beamer",
        subtitleText: "Template Project",
      ),
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
                    "Welcome to Arcane Beamer",
                    style: Theme.of(context).typography.large,
                  ),
                  const Gap(12),
                  const Text(
                    "This is a minimal template project using Arcane styling with Beamer navigation. "
                    "Start building by modifying this home screen or adding new screens in lib/screens/.",
                  ),
                ],
              ),
            ),
          ),
          const Gap(16),

          // Example navigation
          Section(
            titleText: "Getting Started",
            child: Collection(
              children: [
                Tile(
                  leading: const Icon(Icons.book),
                  title: const Text("Example Screen"),
                  subtitle: const Text("See how to create new pages"),
                  trailing: const Icon(Icons.chevron_forward_ionic),
                  onPressed: () => context.beamToNamed('/example'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
