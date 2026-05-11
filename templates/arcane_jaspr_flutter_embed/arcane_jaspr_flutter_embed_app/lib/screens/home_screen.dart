import 'package:arcane/arcane.dart';

import '../app.dart' show EmbeddedAppContext;

/// Default screen shown to the user once the Flutter app boots inside
/// the Jaspr host at `/app/`.
///
/// Built with the standard Arcane primitives (`Screen` + `Bar` +
/// `Collection`/`Section`/`Card`/`Tile`) so the embedded experience
/// matches the rest of the Arcane app shell.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Screen(
      header: Bar(
        titleText: 'Embedded Flutter App',
        subtitleText: 'Mounted at /app/ inside the Jaspr host',
        trailing: <Widget>[
          // Arcane's IconButton doesn't accept a `tooltip:` (that's a
          // Material-ism). Wrap in `Tooltip` whose `tooltip:` slot is a
          // WidgetBuilder, not a Widget.
          Tooltip(
            tooltip: (BuildContext _) => const TooltipContainer(
              child: Text('Toggle theme'),
            ),
            child: IconButton(
              icon: const Icon(Icons.moon),
              onPressed: () => context.toggleTheme(),
            ),
          ),
        ],
      ),
      gutter: true,
      child: Collection(
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Hello from the embedded Flutter web app!',
                    style: Theme.of(context).typography.large,
                  ),
                  const Gap(12),
                  const Text(
                    'You are currently inside the /app mount of the Jaspr '
                    'host. Routes added here behave like a normal Flutter '
                    'SPA — Firebase Hosting rewrites /app/** through '
                    '/app/index.html so deep-linking works.',
                  ),
                ],
              ),
            ),
          ),
          const Gap(16),
          Section(
            titleText: 'Embed contract',
            child: Collection(
              children: const <Widget>[
                Tile(
                  leading: Icon(Icons.layout),
                  title: Text('Flutter mount: /app/'),
                  subtitle: Text(
                    'Configured via SetupConfig.embeddedFlutterMount.',
                  ),
                ),
                Tile(
                  leading: Icon(Icons.palette),
                  title: Text('Theme isolation'),
                  subtitle: Text(
                    'The Flutter app owns its own ArcaneTheme; the Jaspr '
                    'host stays untouched outside /app/.',
                  ),
                ),
                Tile(
                  leading: Icon(Icons.power),
                  title: Text('Firebase bridge'),
                  subtitle: Text(
                    'FirebaseBridge detects host-initialized SDKs so '
                    'auth/firestore sessions are shared.',
                  ),
                ),
              ],
            ),
          ),
          const Gap(24),
          _LinkBackToHost(),
        ],
      ),
    );
  }
}

class _LinkBackToHost extends StatelessWidget {
  const _LinkBackToHost();

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      onPressed: () {
        // Pop back to the Jaspr-rendered host. If there's nothing to pop
        // (deep link landed directly here), no-op gracefully.
        Navigator.of(context).maybePop();
      },
      child: const Text('Back to the marketing site'),
    );
  }
}
