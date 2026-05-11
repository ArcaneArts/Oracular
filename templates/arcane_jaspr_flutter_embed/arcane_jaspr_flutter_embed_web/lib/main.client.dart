/// The entrypoint for the **client** app (hydration after static
/// prerender).
library;

import 'package:web/web.dart' as web;
import 'package:jaspr/client.dart';
import 'package:fast_log/fast_log.dart';

import 'app.dart';
import 'main.client.options.dart';

void main() {
  info('arcane_jaspr_flutter_embed_web starting (client hydration)');

  Jaspr.initializeApp(options: defaultClientOptions);

  try {
    const App app = App();
    runApp(app);

    // Hide loading screen
    web.document.getElementById('loading')?.remove();

    success('arcane_jaspr_flutter_embed_web hydrated');
  } catch (e, stack) {
    error('Exception: $e');
    error('Stack: $stack');
  }
}
