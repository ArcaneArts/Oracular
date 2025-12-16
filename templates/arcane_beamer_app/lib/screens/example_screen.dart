import 'package:arcane/arcane.dart';
import 'package:beamer/beamer.dart';

/// Example screen demonstrating how to create a new page
///
/// To add your own screen:
/// 1. Create a new file in lib/screens/
/// 2. Copy this structure
/// 3. Add a route in routes.dart
/// 4. Navigate using context.beamToNamed('/your-route')
class ExampleScreen extends StatelessWidget {
  const ExampleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Screen(
      header: Bar(
        titleText: "Example Screen",
        subtitleText: "Template for new pages",
        leading: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ionic),
            onPressed: () => context.beamToNamed('/'),
          ),
        ],
      ),
      gutter: true,
      child: Collection(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "This is an example screen",
                    style: Theme.of(context).typography.large,
                  ),
                  const Gap(12),
                  const Text(
                    "Use this as a template when creating new screens for your app. "
                    "Simply copy this file, rename it, and customize the content.",
                  ),
                ],
              ),
            ),
          ),
          const Gap(16),
          Section(
            titleText: "Common Components",
            child: Collection(
              children: [
                Tile(
                  leading: const Icon(Icons.info),
                  title: const Text("Basic Tile"),
                  subtitle: const Text("Tiles are great for list items"),
                  onPressed: () {},
                ),
                Tile(
                  leading: const Icon(Icons.star),
                  title: const Text("Another Tile"),
                  trailing: const Icon(Icons.chevron_forward_ionic),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const Gap(16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Actions", style: Theme.of(context).typography.medium),
                  const Gap(12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PrimaryButton(
                        onPressed: () => context.beamToNamed('/'),
                        child: const Text("Go Home"),
                      ),
                      SecondaryButton(
                        onPressed: () {},
                        child: const Text("Action"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
