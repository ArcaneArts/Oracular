import 'package:arcane/arcane.dart';
import 'package:beamer/beamer.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Screen(
      backButtonMode: BarBackButtonMode.never,
      header: Bar(
        titleText: "404 - Not Found",
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_circle,
              size: 120,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const Gap(32),
            Text(
              "404",
              style: Theme.of(context).typography.large.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const Gap(16),
            Text(
              "Page Not Found",
              style: Theme.of(context).typography.medium,
            ),
            const Gap(8),
            Text(
              "The page you're looking for doesn't exist.",
              style: Theme.of(context).typography.h1,
            ),
            const Gap(32),
            PrimaryButton(
              onPressed: () => context.beamToNamed('/'),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.house, size: 20),
                  Gap(8),
                  Text("Go to Home"),
                ],
              ),
            ),
            const Gap(16),
            SecondaryButton(
              onPressed: () {
                if (Beamer.of(context).canBeamBack) {
                  Beamer.of(context).beamBack();
                } else {
                  context.beamToNamed('/');
                }
              },
              child: const Text("Go Back"),
            ),
          ],
        ),
      ),
    );
  }
}
