# Arcane Template

Pure Arcane UI template with multi-platform support. Material Design-free architecture for building cross-platform applications.

## Overview

This template provides a clean foundation for Flutter applications using only Arcane components. No navigation framework is included - bring your own or keep it simple.

**Best for:**
- Single-screen or simple applications
- Apps with custom navigation requirements
- Progressive Web Apps (PWAs)
- Multi-platform desktop/mobile apps

## Features

- Pure Arcane UI components (no Material Design)
- Multi-platform support (Web, iOS, Android, Linux, macOS, Windows)
- Theme management (light/dark/system with context extensions)
- Firebase integration ready (commented out, easily enabled)
- Server integration ready via shared models package
- Dart run scripts for common tasks

## Quick Start

This template is used via the setup wizard:

```bash
cd ..
./setup.sh
```

Select "arcane_template" when prompted.

## Structure

```
lib/
├── main.dart              # App entry point, theme setup
└── screens/
    ├── home_screen.dart   # Main application screen
    └── example_screen.dart # Example screen showing Arcane components

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

**Run on specific platform:**
```bash
flutter run -d chrome      # Web
flutter run -d macos       # macOS
flutter run -d linux       # Linux
flutter run -d windows     # Windows
```

**Generate assets:**
```bash
dart run gen_assets
```

## Adding Screens

Create new screen in `lib/screens/`:

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
      ),
      gutter: true,
      child: Collection(
        children: [
          Section(
            titleText: "Section Title",
            children: [
              Tile(
                titleText: "Tile Item",
                subtitleText: "Tile description",
                onPressed: () {
                  // Handle tap
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

## Navigation

This template has no built-in navigation. Add your own:

**Navigator 2.0:**
```dart
MaterialApp.router(
  routerConfig: yourRouterConfig,
  // ...
)
```

**Beamer:**
Use `arcane_beamer` template instead.

**Simple Navigator:**
```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (context) => MyScreen()),
);
```

**Or keep it single-screen:**
```dart
// No navigation needed for simple apps
```

## Theme Management

Toggle theme using context extension:

```dart
// Toggle theme (light -> dark -> system)
context.toggleTheme();

// Get current theme mode
final mode = context.currentThemeMode;
```

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

## Customization

**Change theme colors:**

Edit `lib/main.dart`:

```dart
ArcaneApp(
  theme: ArcaneTheme(
    colorScheme: ColorSchemes.blue(), // or red(), green(), purple(), etc.
    themeMode: ThemeMode.system,
  ),
  // ...
)
```

**Modify app structure:**

Edit `lib/screens/home_screen.dart` to change the main screen layout.

## Common Components

**Screen with header:**
```dart
Screen(
  header: Bar(titleText: "Title"),
  child: yourContent,
)
```

**Scrollable content:**
```dart
Collection(
  children: [
    // Your widgets
  ],
)
```

**Grouped content:**
```dart
Section(
  titleText: "Section",
  children: [
    Tile(titleText: "Item 1"),
    Tile(titleText: "Item 2"),
  ],
)
```

**Buttons:**
```dart
PrimaryButton(
  text: "Primary Action",
  onPressed: () {},
)

SecondaryButton(
  text: "Secondary Action",
  onPressed: () {},
)
```

**Cards:**
```dart
Card(
  child: yourContent.padded(),
)
```

## Documentation

- [Main README](../README.md) - All templates overview
- [ArcaneDesign.txt](../references/ArcaneDesign.txt) - Complete component reference
- [Pylon.txt](../references/Pylon.txt) - State management
- [Toxic.txt](../references/Toxic.txt) - Utility extensions

## Dependencies

**Core:**
- arcane - UI framework
- arcane_user - User management
- pylon - State management
- toxic/toxic_flutter - Utility extensions

**Data:**
- hive/hive_flutter - Local storage
- artifact - Data serialization
- rxdart - Reactive programming

**Utilities:**
- fast_log - Logging
- serviced - Service management
- package_info_plus - App info
- http - HTTP requests
- crypto - Cryptographic operations

**Optional (Firebase):**
- arcane_fluf - Firebase integration (commented)
- arcane_auth - Firebase auth (commented)
- fire_crud - Firestore CRUD (commented)

See `pubspec.yaml` for complete list.

## Platform-Specific Notes

**Web:**
- Path URL strategy configured (no # in URLs)
- Responsive design recommended
- PWA manifest can be added

**Mobile:**
- Android minSdkVersion: 21
- iOS deployment target: 12.0

**Desktop:**
- Window management via arcane_desktop (optional)
- System tray support available (use arcane_dock template)

## Troubleshooting

**Build errors:**
```bash
flutter clean
flutter pub get
flutter run
```

**iOS/macOS pod issues:**
```bash
dart run pod_install_ios
# or
dart run pod_install_macos
```

**Asset generation fails:**

Ensure you have valid images in `assets/icon/`:
- icon.png (1024x1024)
- splash.png (any size, will be resized)

## Related Templates

- **arcane_beamer** - Same template with Beamer navigation
- **arcane_dock** - System tray/menu bar application template
- **server_template** - Backend server for your app
- **models_template** - Shared data models

See [main README](../README.md) for details.
