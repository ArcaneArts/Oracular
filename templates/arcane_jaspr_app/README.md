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
  app.dart            # Main app component with theming
  routes/
    app_router.dart   # Route definitions and navigation
  screens/
    home_screen.dart  # Home page
    about_screen.dart # About page
  utils/
    constants.dart    # Route constants and configuration
web/
  index.html          # HTML template
  styles.css          # Global styles (Arcane theme)
  assets/             # Static assets
```

## Adding New Screens

1. Create a new screen component in `lib/screens/`
2. Add the route constant in `lib/utils/constants.dart`
3. Add the route case in `lib/routes/app_router.dart`

## Firebase Integration

To enable Firebase:

1. Uncomment the Firebase scripts in `web/index.html`
2. Update the Firebase config with your project details
3. Add `arcane_auth_jaspr` dependency in `pubspec.yaml`
4. Wrap your app with `ArcaneAuthProvider` in `app.dart`

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
