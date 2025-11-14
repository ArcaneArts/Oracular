# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter template project combining the Arcane UI framework with Beamer navigation. It demonstrates Material Design-free UI development using pure Arcane components with declarative web-style routing.

**Key characteristics:**
- No Material Design components used (pure Arcane styling)
- Beamer for declarative navigation and deep linking
- Multi-platform support (Web, iOS, Android, Linux, macOS, Windows)
- Path-based URL strategy for web (no # in URLs)

## Architecture

### Navigation Structure

The app uses **Beamer** for routing, configured in `arcane_beamer/lib/routes.dart`:

- `routerDelegate`: Central BeamerDelegate instance that manages all routing
- `route()` helper: Simplifies route registration by wrapping screens in BeamPage
- Routes are registered as a Map of path patterns to BeamerRouteBuilder functions
- Global context tracking via `globalContext` for programmatic navigation

**Route registration pattern:**
```dart
route("/path", "Page Title", const YourScreen())
```

This creates a BeamPage with proper key generation and title metadata.

### App Initialization

`arcane_beamer/lib/main.dart` sets up:

1. **Path URL strategy**: `Beamer.setPathUrlStrategy()` called before runApp (enables clean URLs on web)
2. **ArcaneApp.router()**: Uses Beamer's routeInformationParser and routerDelegate
3. **Theme management**: Built-in ThemeMode toggle (light/dark/system) via context extension

**Theme toggle access:**
- `context.toggleTheme()` - cycles through light → dark → system
- `context.currentThemeMode` - gets current theme mode

### Screen Structure

All screens follow a consistent Arcane component structure:

```dart
Screen(
  header: Bar(titleText: "...", subtitleText: "..."),
  gutter: true,
  child: Collection(children: [...])
)
```

**Common Arcane components:**
- `Screen` - Top-level page container
- `Bar` - Header/app bar with title, subtitle, leading/trailing actions
- `Collection` - Vertical list of widgets
- `Section` - Titled content group
- `Tile` - List item with leading/trailing icons, onPressed
- `Card` - Content container
- `Gap` - Spacing widget
- `PrimaryButton`/`SecondaryButton` - Action buttons

### Navigation

Use Beamer's context extensions:
- `context.beamToNamed('/route')` - Navigate to route
- `context.beamBack()` - Navigate back

## Essential Documentation Reference

**CRITICAL**: The `SoftwareThings/` folder at the repository root contains comprehensive documentation for all core libraries used in this project. **Always consult these files when working with their respective technologies.**

### Core Library Documentation

Located at `/Users/brianfopiano/Developer/RemoteGit/NextdoorPsycho/arcane_beamer/SoftwareThings/`:

#### UI Framework & Design
- **ArcaneDesign.txt** - Complete Arcane UI framework reference
  - Screens (ArcaneScreen, FillScreen, SliverScreen, NavigationScreen)
  - Common widgets (Cards, Search, Dialogs, Tables, Chats)
  - Navigation patterns (Tabs, Rails, Sidebars, Breadcrumbs)
  - Inputs (ArcaneInput variants: selectCards, date, time, color)
  - Feedback & Notifications (Alerts, Progress, Toasts, Skeletons)
  - Animation (NumberTicker, Accordion, Collapsible)
  - **When to use**: Any time you're building UI components, screens, or layouts

- **ArcaneShadDesign.txt** - Extended Arcane/shadcn design patterns
  - Advanced component compositions
  - **When to use**: For complex UI patterns beyond basic components

- **ArcaneSourcecode.txt** - Arcane library source code structure
  - Internal component architecture
  - **When to use**: When debugging or extending Arcane components

- **ArcaneDesktop.txt** - Desktop-specific Arcane features
  - System tray integration (ArcaneTray)
  - Custom title bars (ArcaneWindow)
  - Window effects (Acrylic, Mica)
  - Desktop initialization patterns
  - **When to use**: When building macOS, Windows, or Linux desktop apps

#### State Management & Utilities
- **Pylon.txt** - Complete Pylon state management guide
  - Pylon<T> (immutable data provision)
  - MutablePylon<T> (mutable state with rebuild control)
  - PylonFuture, PylonStream (async data handling)
  - PylonPort<T> (URL syncing for web)
  - Conduit<T> (global state management)
  - Navigation helpers (Pylon.push, pushReplacement)
  - Context extensions (pylon<T>(), setPylon<T>(), modPylon<T>())
  - **When to use**: Managing application state, widget tree data sharing, navigation with state preservation

- **Toxic.txt** - Flutter utility extensions library
  - Widget extensions (pad, sized, centered, expand, etc.)
  - Geometry extensions (Size, Offset, Rect, Float64List)
  - Stream/Future builders (FutureOnce, StreamOnce)
  - Global signaling (Signal, SignalBuilder)
  - Grid helpers (Grids.softSize)
  - **When to use**: Need convenient extensions for common Flutter operations

#### Data & Persistence
- **FireCrud.txt** - Firestore CRUD operations library
  - FireCrud singleton for global access
  - FireModel<T> and ModelCrud mixin
  - Document/collection operations (get, set, add, delete, stream)
  - Nested models and subcollections
  - CollectionViewer for pagination
  - fire_crud_flutter widgets (FireList, FireGrid, ModelView)
  - Pylon integration (context.implicitModel<T>())
  - **When to use**: Working with Firebase Firestore, data models, CRUD operations

- **Artifact.txt** - Data serialization and codec library
  - ArtifactCodec system for type conversions
  - Built-in codecs (DateTime, Duration)
  - JSON handling utilities
  - Map/Iterable/List/Set extensions ($m, $l, $s, $nn, $u)
  - Annotations (@codec, @describe, @rename, @attach)
  - **When to use**: Data serialization, type conversions, JSON operations

### Usage Guidelines

1. **Before implementing any feature**, check the relevant SoftwareThings documentation to understand available APIs and patterns
2. **When encountering unfamiliar syntax** (e.g., `context.pylon<T>()`, `model.getSelf<T>()`), consult the corresponding documentation file
3. **For UI work**, always reference ArcaneDesign.txt for component usage and patterns
4. **For state management**, consult Pylon.txt before reaching for other solutions
5. **For Firestore integration**, reference FireCrud.txt for the proper model and CRUD patterns

### Integration Patterns

These libraries are designed to work together:
- **Arcane + Pylon**: Use MutablePylon for screen-level state in ArcaneScreen components
- **FireCrud + Pylon**: Models automatically integrate with Pylon for reactive UI updates
- **Toxic + Arcane**: Use Toxic extensions to simplify Arcane widget composition
- **Artifact + FireCrud**: Use Artifact codecs for custom type serialization in Firestore models

## Development Commands

### Running the App

```bash
# Navigate to the Flutter project directory
cd arcane_beamer

# Run on your default device
flutter run

# Run on specific platform
flutter run -d chrome        # Web
flutter run -d macos          # macOS
flutter run -d linux          # Linux
```

### Dependencies

```bash
# Get dependencies
flutter pub get

# Upgrade dependencies
flutter pub upgrade
```

### Code Quality

```bash
# Run static analysis
flutter analyze

# Run linter (uses flutter_lints package)
flutter analyze --no-fatal-infos
```

### Building

```bash
# Build for web
flutter build web

# Build for specific platforms
flutter build macos
flutter build linux
flutter build windows
flutter build apk      # Android
flutter build ios      # iOS (requires macOS)
```

### Testing

```bash
# Run all tests (note: no test files currently exist)
flutter test

# Run tests in watch mode
flutter test --watch

# Run specific test file
flutter test test/widget_test.dart
```

## Adding New Screens

1. Create screen file in `arcane_beamer/lib/screens/your_screen.dart`
2. Use `ExampleScreen` (arcane_beamer/lib/screens/example_screen.dart) as template
3. Add route in `arcane_beamer/lib/routes.dart`:
   ```dart
   route("/your-path", "Your Title", const YourScreen())
   ```
4. Navigate using `context.beamToNamed('/your-path')`

## Key Dependencies

- **arcane** (^6.5.2) - Core UI framework
- **arcane_fluf**, **arcane_auth**, **arcane_user** - Arcane ecosystem packages
- **beamer** (^1.7.0) - Declarative routing and navigation
- **toxic_flutter**, **toxic** - Additional utilities
- **fire_crud**, **pylon** - Data management (Firebase commented out)
- **hive**, **hive_flutter** - Local storage
- **rxdart** - Reactive programming
- **serviced**, **fast_log** - Service layer and logging

Firebase packages are commented out in pubspec.yaml but available if needed.

## Project Structure

```
arcane_beamer/
├── lib/
│   ├── main.dart           # App entry, theme management, ArcaneApp.router setup
│   ├── routes.dart         # Beamer routing configuration
│   └── screens/            # All screen widgets
│       ├── home_screen.dart
│       ├── example_screen.dart
│       └── not_found_screen.dart
├── pubspec.yaml            # Dependencies and Flutter config
└── analysis_options.yaml   # Linter rules
```

## Important Notes

- Working directory is at repository root, but Flutter commands must be run from `arcane_beamer/` subdirectory
- The project uses Arcane theming exclusively - avoid Material Design widgets
- Beamer handles 404s automatically via `notFoundRedirectNamed: "/404"`
- Theme customization is done through `ContrastedColorScheme` with `ColorSchemes.blue()`
