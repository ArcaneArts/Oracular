# Arcane Jaspr + Flutter Embed

A flagship template that demonstrates how to host a Flutter web app inside a
Jaspr static site. The Jaspr site owns the marketing surface (landing page,
docs, SEO, sitemap) while the Flutter web app owns the real product UX at
`/app/`.

## Layout

This template ships **two sibling packages**:

```
<your-project>/
├── arcane_jaspr_flutter_embed_web/   ← Jaspr static host  (renamed to <appName>_web)
└── arcane_jaspr_flutter_embed_app/   ← Flutter web guest  (renamed to <appName>_app)
```

Oracular's placeholder replacer rewrites the directory and package names
during `oracular create`, so after scaffolding you will see
`<appName>_web` and `<appName>_app` instead.

## Build pipeline

The build is two-step but Oracular wraps it:

```bash
# From the parent directory
oracular build flutter-embed   # 1) flutter build web --base-href=/app/ → ../<appName>_web/web/app/
                               # 2) jaspr build       (inside <appName>_web)

# Deploy as a single Firebase Hosting bundle:
oracular deploy hosting
```

The `firebase.json` produced by `oracular deploy generate-configs` routes
`/app/**` to the Flutter SPA and `/**` to the Jaspr static shell.

## Local dev story

```bash
# Terminal A — Flutter guest
cd <appName>_app
flutter run -d chrome --web-port=5050 --web-renderer=canvaskit \
  --base-href=/app/

# Terminal B — Jaspr host
cd <appName>_web
jaspr serve            # forwards /app/** to the Flutter dev server
```

A future `oracular dev` will start both processes from one terminal.

## Why two packages?

- The Flutter guest needs the **Flutter SDK** for its build (`flutter build web`).
- The Jaspr host is a **pure Dart** package and runs on the Dart SDK alone.
- Keeping them as siblings means you can iterate on the marketing site
  without rebuilding the Flutter app and vice-versa.

## Firebase

Both packages share a single Firebase project. The Jaspr `index.html`
initializes Firebase JS SDK and exposes the initialized app on
`window.__ORACULAR_FIREBASE__`; the Flutter guest reads from that global
on startup instead of calling `Firebase.initializeApp` itself. This avoids
the double-bootstrap issue documented in the Oracular plan
`plans/2026-05-10-build-deploy-rendering-modes-and-flutter-embed-v1.md`.
