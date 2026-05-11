/// The entrypoint for the **server** app.
///
/// Used by three Jaspr render modes:
///   * **SSG** — `jaspr build` (mode: static) runs this once per route at
///     build time to emit pre-rendered HTML files. SEO-friendly, hosted
///     by Firebase Hosting as static assets.
///   * **SSR** — `jaspr build` (mode: server) wraps this in a Dart binary
///     entrypoint. Runs at request time on Cloud Run; Firebase Hosting
///     fronts the service via rewrites.
///   * **Hybrid** — same as SSR but with `@StaticRoute` annotations on
///     specific pages so those routes prerender at build time and
///     everything else renders on Cloud Run.
///
/// For **CSR** mode this file is deleted by Oracular's template_copier
/// post-step. If you switch render modes later, run `oracular create`
/// again in a tmp directory and copy this file over manually.
library;

import 'package:jaspr/server.dart';

import 'app.dart';
import 'main.server.options.dart';

void main() {
  Jaspr.initializeApp(options: defaultServerOptions);
  runApp(const App());
}
