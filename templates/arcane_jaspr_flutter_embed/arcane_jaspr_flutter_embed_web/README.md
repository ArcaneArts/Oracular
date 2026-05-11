# Arcane Jaspr Flutter Embed — Host (Jaspr static site)

This is the Jaspr-side of the embed template. It owns:

- `/` — Jaspr-rendered marketing landing page with full SEO.
- `/about` — example static page.
- `/app/**` — mount point for the Flutter web guest (built into
  `web/app/` by the `flutter_build` script).

## Local dev

```bash
jaspr serve
```

This runs the Jaspr dev server on http://localhost:8080. Static assets
under `web/app/` are served verbatim, so as long as you have a
recent Flutter build there, `/app/` will work end-to-end.

## Build

```bash
dart pub run pubspec_script flutter_build   # or: oracular build flutter-embed
jaspr build
```

After this the deployable output lives in `build/jaspr/`.

## SEO

The Jaspr host owns the entire SEO surface. The Flutter guest at `/app`
is treated as an opaque app shell by crawlers; the host emits a
canonical `<link>` from the app shell back to `/` so social previews
land on the marketing page rather than the Flutter loader.
