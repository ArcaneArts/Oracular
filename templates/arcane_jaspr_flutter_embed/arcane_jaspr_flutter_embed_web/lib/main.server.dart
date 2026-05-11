/// The entrypoint for the **server** app (static prerender at build time).
///
/// Runs once per route during `jaspr build`. The output is a tree of
/// pre-rendered HTML files that Firebase Hosting serves directly.
library;

import 'package:jaspr/server.dart';

import 'app.dart';
import 'main.server.options.dart';

void main() {
  Jaspr.initializeApp(options: defaultServerOptions);

  // Same root component; jaspr's static renderer walks the route tree
  // and emits per-page HTML.
  runApp(const App());
}
