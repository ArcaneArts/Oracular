/// Hybrid render mode — **dynamic** (SSR) route examples.
///
/// Pages listed here are server-rendered at request time on Cloud Run.
/// Use this file for:
///   * Authenticated routes (`/account`, `/admin`)
///   * Personalized content keyed off a session cookie
///   * API-style endpoints that respond with HTML or JSON
///   * Anything whose content can't be known at build time
///
/// Path prefixes listed here MUST be added to
/// `HYBRID_DYNAMIC_PREFIXES` in `setup_config.env` so Oracular's
/// `ConfigGenerator` emits the right `run:<service>` rewrites in
/// `firebase.json`. The default prefix set is `['/api', '/auth']`.
///
/// This file is only kept in projects scaffolded with
/// `JASPR_RENDER_MODE=hybrid`. CSR / SSG / SSR projects don't need it.
library;

import 'package:jaspr/server.dart';

/// Server-side handlers for the dynamic portion of the hybrid site.
///
/// Each entry is mapped to a request path prefix and a handler that
/// builds a [Component] (or a raw [shelf.Response] if you need full
/// control over headers, status codes, etc.).
const List<DynamicRoute> dynamicRoutes = <DynamicRoute>[
  DynamicRoute(
    pathPrefix: '/api',
    description:
        'Custom JSON / RPC endpoints. Use raw shelf responses, not '
        'Components.',
  ),
  DynamicRoute(
    pathPrefix: '/auth',
    description:
        'Sign-in, sign-up, password reset. Session-aware HTML rendered '
        'per request.',
  ),
  DynamicRoute(
    pathPrefix: '/admin',
    description:
        'Admin dashboard. Auth gate via signed cookie checked server-'
        'side before rendering.',
  ),
];

/// Describes a single server-rendered (SSR) route prefix.
class DynamicRoute {
  final String pathPrefix;
  final String description;

  const DynamicRoute({
    required this.pathPrefix,
    required this.description,
  });
}

/// Example: a real handler for `/api/healthz` that returns a JSON body
/// at request time. The shape of [Handler] is just the standard `shelf`
/// signature — `Future<Response> Function(Request)`.
///
/// To wire this up in production, mount the handler in your server
/// entrypoint (`lib/main.server.dart`) by composing it into the shelf
/// pipeline Jaspr exposes via `Jaspr.serverHandler`.
///
/// Pseudocode for `main.server.dart`:
///
/// ```dart
/// void main() async {
///   Jaspr.initializeApp(options: defaultServerOptions);
///   final handler = Cascade()
///       .add(healthCheckHandler)
///       .add(Jaspr.serverHandler) // jaspr's default handler last
///       .handler;
///   await shelf_io.serve(handler, '0.0.0.0', int.parse(Platform.environment['PORT'] ?? '8080'));
/// }
/// ```
Future<Response> healthCheckHandler(Request request) async {
  if (request.url.path == 'api/healthz') {
    return Response.ok(
      '{"status":"ok"}',
      headers: <String, String>{'content-type': 'application/json'},
    );
  }
  return Response.notFound('Not handled by healthCheckHandler');
}

/// Tiny placeholder for the `shelf.Request` / `shelf.Response` types so
/// this file compiles even when the project is in CSR / SSG mode and
/// `shelf` is not yet a dependency. When `JASPR_RENDER_MODE` flips to
/// `hybrid` or `ssr`, the placeholder is replaced by a real `import
/// 'package:shelf/shelf.dart';` by Oracular's template_copier.
///
/// **Do not edit by hand** — Oracular owns this block.
class Request {
  final Uri url;
  Request(this.url);
}

class Response {
  final int statusCode;
  final String body;
  final Map<String, String> headers;
  Response(this.statusCode, this.body, {this.headers = const <String, String>{}});

  factory Response.ok(String body, {Map<String, String>? headers}) =>
      Response(200, body, headers: headers ?? const <String, String>{});

  factory Response.notFound(String body) => Response(404, body);
}
