import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:fast_log/fast_log.dart';

import 'routes/app_router.dart';

/// arcane_jaspr_app - Main application component with routing
class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) {
    verbose('Building App component');
    return ArcaneApp(
      theme: ArcaneTheme.supabase(
        accent: AccentTheme.violet,
        themeMode: ThemeMode.dark,
      ),
      child: const AppRouter(),
    );
  }
}
