# Arcane Jaspr Flutter Embed — Guest (Flutter web app)

This is the Flutter side of the embed template. It builds to `web/` and
is mounted by the Jaspr host at `/app/` (the value of
`EMBEDDED_FLUTTER_MOUNT` in `setup_config.env`).

## Local dev

```bash
flutter run -d chrome --web-port=5050 --web-renderer=canvaskit --base-href=/app/
```

Then point the Jaspr host's dev server at `http://localhost:5050/app/`
when developing both sides.

## Build (standalone)

```bash
flutter build web --release --base-href=/app/
```

## Build into the Jaspr host (production)

```bash
flutter build web --release \
  --base-href=/app/ \
  --output=../<appName>_web/web/app
```

This is exactly what `oracular build flutter-embed` runs. After it
completes, `jaspr build` in the host package picks up the static
output and bundles it into the final deployable.

## Firebase bridge

If Firebase is enabled for this project, the **Jaspr host** owns the
Firebase JS SDK initialization. This Flutter guest reads the
initialized FirebaseApp from `window.__ORACULAR_FIREBASE__` instead of
calling `Firebase.initializeApp()` itself. See
`lib/firebase_bridge.dart` for the bridge implementation.
