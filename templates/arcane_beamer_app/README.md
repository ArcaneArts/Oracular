# Arcane Beamer

Pure Arcane UI template with Beamer navigation. Material Design-free architecture with declarative routing, deep linking, and clean URLs.

## Overview

This template combines Arcane UI framework with Beamer navigation for web-first applications requiring complex routing patterns.

**Best for:**
- Multi-screen applications
- Web apps with shareable URLs
- Apps requiring deep linking
- Complex navigation flows

## Features

- Pure Arcane UI components (no Material Design)
- Beamer declarative navigation
- Clean URLs on web (path-based strategy, no # in URLs)
- Deep linking support (mobile & web)
- Centralized route management
- Multi-platform support (Web, iOS, Android, Linux, macOS, Windows)
- Theme management (light/dark/system with context extensions)
- Firebase integration ready (commented out, easily enabled)
- Dart run scripts for common tasks

## Quick Start

This template is used via the setup wizard:

```bash
cd ..
./setup.sh
```

Select "arcane_beamer" when prompted.

## Structure

```
lib/
├── main.dart              # App entry, Beamer setup
├── routes.dart            # Route configuration
└── screens/
    ├── home_screen.dart   # Home page
    ├── example_screen.dart # Example screen
    └── not_found_screen.dart # 404 page

assets/
└── icon/
    ├── icon.png           # App icon (1024x1024)
    └── splash.png         # Splash screen

pubspec.yaml               # Dependencies and dart run scripts
```

## Usage

**Run the app:**
```bash
flutter run
```

**Run on web with specific URL:**
```bash
flutter run -d chrome --web-port=8080
# Navigate to http://localhost:8080/example
```

**Generate assets:**
```bash
dart run gen_assets
```

## Navigation

Beamer provides declarative routing with BeamPages.

**Navigate to route:**
```dart
context.beamToNamed('/example');
```

**Navigate back:**
```dart
context.beamBack();
```

**Get current location:**
```dart
final location = Beamer.of(context).currentBeamLocation;
```

**Replace current route:**
```dart
context.beamToReplacementNamed('/home');
```

## Adding Routes

Edit `lib/routes.dart`:

```dart
// Add your screen import
import 'screens/my_screen.dart';

// Register route in routerDelegate
final routerDelegate = BeamerDelegate(
  locationBuilder: RoutesLocationBuilder(
    routes: {
      '/': (context, state, data) => route("/", "Home", const HomeScreen()),
      '/example': (context, state, data) => route("/example", "Example", const ExampleScreen()),
      '/my-route': (context, state, data) => route("/my-route", "My Screen", const MyScreen()),
    },
  ),
  notFoundRedirectNamed: "/404",
);
```

**Route helper:**

The `route()` helper simplifies BeamPage creation:

```dart
BeamPage route(String path, String title, Widget screen) {
  return BeamPage(
    key: ValueKey(path),
    title: title,
    child: screen,
  );
}
```

## Deep Linking

**Web:**

URLs work automatically. Navigate to `https://yourapp.com/example` and Beamer handles routing.

**Mobile (iOS/Android):**

Configure deep links in platform-specific files:

```dart
// iOS: ios/Runner/Info.plist
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>yourapp</string>
    </array>
  </dict>
</array>

// Android: android/app/src/main/AndroidManifest.xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https"
        android:host="yourapp.com" />
</intent-filter>
```

## Route Parameters

**Path parameters:**

```dart
// In routes.dart
'/user/:userId': (context, state, data) {
  final userId = state.pathParameters['userId'];
  return route("/user/:userId", "User", UserScreen(userId: userId));
}

// Navigate
context.beamToNamed('/user/123');
```

**Query parameters:**

```dart
// In screen
final beamState = context.currentBeamLocation.state as BeamState;
final search = beamState.queryParameters['search'];

// Navigate
context.beamToNamed('/search?search=flutter');
```

## Programmatic Navigation

**With data:**

```dart
// Navigate with state
context.beamToNamed(
  '/example',
  data: {'userId': '123'},
);

// Retrieve data in screen
final data = ModalRoute.of(context)!.settings.arguments as Map?;
```

**Conditional navigation:**

```dart
if (isAuthenticated) {
  context.beamToNamed('/dashboard');
} else {
  context.beamToNamed('/login');
}
```

## Theme Management

Toggle theme using context extension:

```dart
// Toggle theme (light -> dark -> system)
context.toggleTheme();

// Get current theme mode
final mode = context.currentThemeMode;
```

## Global Context

Access context for navigation from anywhere:

```dart
import 'routes.dart';

// Navigate from outside widget tree
if (globalContext != null) {
  globalContext!.beamToNamed('/home');
}
```

**Note:** Use sparingly. Prefer `context.beamToNamed()` from within widgets.

## Dart Run Scripts

Available scripts in `pubspec.yaml`:

```bash
# Firebase deployment
dart run deploy_firebase
dart run deploy_firestore
dart run deploy_hosting

# Web build
dart run build_web
dart run deploy_web

# Assets
dart run gen_icons
dart run gen_splash
dart run gen_assets

# Platform setup
dart run pod_install_ios
dart run pod_install_macos
```

## Creating Screens

Use Arcane components for consistent UI:

```dart
import 'package:arcane/arcane.dart';

class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Screen(
      header: Bar(
        titleText: "My Screen",
        subtitleText: "Screen description",
        leading: IconButton(
          icon: Icon(Icons.chevron_left),
          onPressed: () => context.beamBack(),
        ),
      ),
      gutter: true,
      child: Collection(
        children: [
          Section(
            titleText: "Content",
            children: [
              Tile(
                titleText: "Navigate",
                onPressed: () => context.beamToNamed('/other'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

## 404 Handling

Beamer automatically redirects unknown routes to `/404`:

```dart
notFoundRedirectNamed: "/404",
```

Customize `lib/screens/not_found_screen.dart` for your 404 page.

## Common Patterns

**Tab navigation:**

```dart
Section(
  children: [
    Tile(
      titleText: "Home",
      selected: currentPath == '/home',
      onPressed: () => context.beamToNamed('/home'),
    ),
    Tile(
      titleText: "Settings",
      selected: currentPath == '/settings',
      onPressed: () => context.beamToNamed('/settings'),
    ),
  ],
)
```

**Breadcrumbs:**

```dart
final beamState = context.currentBeamLocation.state as BeamState;
final pathSegments = beamState.uri.pathSegments;

Row(
  children: pathSegments.map((segment) {
    return TextButton(
      child: Text(segment),
      onPressed: () => context.beamToNamed('/$segment'),
    );
  }).toList(),
)
```

**Protected routes:**

```dart
// In routes.dart
'/admin': (context, state, data) {
  if (!isAdmin) {
    return route("/unauthorized", "Unauthorized", const UnauthorizedScreen());
  }
  return route("/admin", "Admin", const AdminScreen());
}
```

## Documentation

- [Main README](../README.md) - All templates overview
- [Beamer Package](https://pub.dev/packages/beamer) - Beamer documentation
- [ArcaneDesign.txt](../references/ArcaneDesign.txt) - Complete component reference
- [Pylon.txt](../references/Pylon.txt) - State management

## Dependencies

**Core:**
- arcane - UI framework
- arcane_user - User management
- beamer - Declarative navigation
- pylon - State management
- toxic/toxic_flutter - Utility extensions

**Data:**
- hive/hive_flutter - Local storage
- artifact - Data serialization
- rxdart - Reactive programming

**Optional (Firebase):**
- arcane_fluf - Firebase integration (commented)
- arcane_auth - Firebase auth (commented)
- fire_crud - Firestore CRUD (commented)

See `pubspec.yaml` for complete list.

## Platform-Specific Notes

**Web:**
- Clean URLs enabled (no # in URLs)
- Browser back/forward buttons work correctly
- Deep linking works out of the box

**Mobile:**
- Configure deep links in platform files
- Back button handled by Beamer
- State restoration supported

**Desktop:**
- Full navigation history
- Keyboard shortcuts can be added

## Troubleshooting

**Routes not working:**

Ensure route path matches exactly:
```dart
'/example' not '/example/'
```

**404 on refresh (web):**

Configure server to serve `index.html` for all routes.

**Deep links not working (mobile):**

Verify platform configuration in Info.plist (iOS) and AndroidManifest.xml (Android).

**Build errors:**
```bash
flutter clean
flutter pub get
flutter run
```

## Related Templates

- **arcane_template** - Same template without navigation
- **arcane_dock** - System tray/menu bar application template
- **server_template** - Backend server for your app
- **models_template** - Shared data models

See [main README](../README.md) for details.
