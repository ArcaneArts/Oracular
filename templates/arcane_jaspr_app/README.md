# arcane_jaspr_app

A modern web application built with [Jaspr](https://jaspr.site) and the Arcane design system.

## Getting Started

### Development

Start the development server:

```bash
jaspr serve
```

This will start a development server at `localhost:8080` with hot reload.

### Production Build

Build for production:

```bash
jaspr build
```

The build output will be in `build/jaspr/`.

## Project Structure

```
lib/
  main.client.dart    # Client entry point
  app.dart            # Main app widget with theming
  routes/
    app_router.dart   # Route definitions and navigation
  screens/
    home_screen.dart  # Home widget
    about_screen.dart # About widget
  utils/
    constants.dart    # Route constants and configuration
web/
  index.html          # HTML template
  styles.css          # Global styles (Arcane theme)
  assets/             # Static assets
```

## Adding New Screens

1. Create a new screen widget in `lib/screens/`
2. Add the route constant in `lib/utils/constants.dart`
3. Add the route case in `lib/routes/app_router.dart`

## Firebase Integration

The base template ships with the Firebase JS SDK loaded in `web/index.html`
(loaded only after you fill in your project config). It does **not** depend on
any Firebase Auth package by default - the base template is intended to be a
clean husk so you can layer in only what you need.

To enable Firebase services:

1. Uncomment the Firebase scripts in `web/index.html`
2. Update the Firebase config with your project details (`oracular deploy
   firebase-setup` will do this for you)
3. Add the specific Jaspr-compatible packages you actually need to
   `pubspec.yaml`. There is currently no published `arcane_auth_jaspr` that is
   compatible with Jaspr `^0.23.0`; for now wire auth via the Firebase JS SDK
   directly or call your own `arcane_server` endpoints.

## Deployment

### Firebase Hosting

```bash
jaspr build
firebase deploy --only hosting
```

### Cloud Run / Docker

Use the included Dockerfile (if server is enabled) or create one for static hosting.

## Scripts

Available scripts (run with `oracular scripts exec <name>`):

- `serve` - Start development server
- `serve_release` - Start release mode server
- `build` - Build for production
- `clean` - Clean build artifacts
- `build_runner` - Run code generation
