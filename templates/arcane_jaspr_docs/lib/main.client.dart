/// The entrypoint for the **client** app (hydration).
library;

import 'package:web/web.dart' as web;
import 'package:jaspr/client.dart';
import 'package:fast_log/fast_log.dart';

void main() {
  info('arcane_jaspr_docs hydrating...');

  Jaspr.initializeApp(
    options: const ClientOptions(clients: {}),
  );

  try {
    // Hydrate any client-side components
    runApp();

    // Hide loading screen
    web.document.getElementById('loading')?.remove();

    success('arcane_jaspr_docs hydrated');
  } catch (e, stack) {
    error('Exception: $e');
    error('Stack: $stack');
  }
}
