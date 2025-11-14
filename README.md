# Arcane Templates

Production-ready Flutter project templates using the Arcane UI framework. Material Design-free architecture with complete backend infrastructure.

## Quick Start

Run the interactive setup wizard:

```bash
./setup.sh
```

The wizard creates a complete 3-project architecture: client app, shared models package, and backend server.

## Available Templates

### arcane_template
Pure Arcane UI with multi-platform support. Best for apps with simple navigation or custom routing.

**Platforms:** Web, iOS, Android, Linux, macOS, Windows
**Navigation:** None (bring your own)
**Use cases:** Single-screen apps, PWAs, custom navigation requirements

### arcane_beamer
Arcane UI with Beamer navigation. Best for web-first apps with complex routing and deep linking.

**Platforms:** Web, iOS, Android, Linux, macOS, Windows
**Navigation:** Beamer (declarative routing, clean URLs)
**Use cases:** Multi-screen apps, shareable URLs, complex navigation flows

### arcane_dock
Arcane UI for system tray/menu bar applications. Desktop-only template with window management.

**Platforms:** macOS, Linux, Windows
**Navigation:** None (single-window popup)
**Use cases:** System utilities, menu bar tools, background services with UI

## Project Architecture

```
your-project/
├── your_app/              # Client application
│   ├── lib/
│   ├── android/
│   ├── ios/
│   ├── web/
│   ├── macos/
│   ├── linux/
│   ├── windows/
│   └── pubspec.yaml
├── your_app_models/       # Shared data models (optional)
│   ├── lib/models/
│   └── pubspec.yaml
├── your_app_server/       # Backend server (optional)
│   ├── lib/
│   ├── Dockerfile
│   ├── script_deploy.sh
│   └── pubspec.yaml
├── config/                # Firebase configuration (optional)
│   ├── firestore.rules
│   ├── storage.rules
│   └── keys/
└── firebase.json
```

## What's Included

**UI Framework**
- Arcane components (Screen, Bar, Collection, Section, Tile, Card, Gap, Buttons)
- Theme system (light/dark/system with context extensions)
- No Material Design dependency

**State Management**
- Pylon (immutable and mutable state with reactive rebuilds)
- RxDart (reactive programming support)

**Data Layer**
- FireCrud (type-safe Firestore CRUD operations, optional)
- Hive (local storage and caching)
- Artifact (data serialization and codecs)

**Backend (Server Template)**
- Shelf Router (HTTP routing and middleware)
- Firebase Admin (server-side Firestore/Storage access)
- Request authentication (signature-based with timing attack protection)
- Docker (production-ready containerization)
- Cloud Run deployment scripts

**Utilities**
- Toxic (Flutter extensions: pad, sized, centered, etc.)
- Fast Log (production logging)
- Serviced (service layer management)

## Features

- Pure Arcane UI (no Material Design)
- Optional Firebase integration (Auth, Firestore, Storage, Analytics)
- Multi-platform support (Web, iOS, Android, Desktop)
- Server deployment (Docker + Google Cloud Run)
- Dart run scripts for common tasks
- Pre-configured security rules
- Type-safe architecture

## Dart Run Scripts

After setup, your client app includes convenience scripts:

```bash
# Firebase deployment
dart run deploy_firebase
dart run deploy_firestore
dart run deploy_hosting

# Web build and deploy
dart run build_web
dart run deploy_web

# Asset generation
dart run gen_icons
dart run gen_splash
dart run gen_assets

# Platform setup
dart run pod_install_ios
dart run pod_install_macos
```

## Prerequisites

**Required:**
- Flutter SDK (latest stable)
- Dart SDK (included with Flutter)

**Optional (based on features):**
- Firebase CLI (for Firebase integration)
- FlutterFire CLI (for Firebase configuration)
- Google Cloud CLI (for server deployment)
- Docker (for server containerization)
- CocoaPods (for iOS/macOS development)

The setup wizard checks prerequisites and provides installation instructions.

## Example Workflow

**Create project:**
```bash
./setup.sh
```

Follow prompts to select template, configure Firebase, and choose project structure.

**Run app:**
```bash
cd my_app
flutter run
```

**Generate assets:**
```bash
cd my_app
dart run gen_assets
```

**Deploy to Firebase:**
```bash
cd my_app
dart run deploy_web
```

**Deploy server to Cloud Run:**
```bash
cd my_app_server
./script_deploy.sh
```

## Documentation

**Setup & Configuration:**
- [Setup Script Documentation](scripts/README.md) - Complete wizard guide
- [Models Template Guide](models_template/README.md) - Shared models package
- [Server Template Guide](server_template/README.md) - Backend server setup

**Library References:**

UI & Design:
- [ArcaneDesign.txt](references/ArcaneDesign.txt) - Complete component reference
- [ArcaneShadDesign.txt](references/ArcaneShadDesign.txt) - Advanced patterns
- [ArcaneDesktop.txt](references/ArcaneDesktop.txt) - Desktop-specific features
- [ArcaneSourcecode.txt](references/ArcaneSourcecode.txt) - Internal architecture

State & Data:
- [Pylon.txt](references/Pylon.txt) - State management guide
- [FireCrud.txt](references/FireCrud.txt) - Firestore CRUD operations
- [Artifact.txt](references/Artifact.txt) - Data serialization

Utilities:
- [Toxic.txt](references/Toxic.txt) - Flutter utility extensions

## Key Differences

**vs. Standard Flutter Templates:**
- No Material Design - pure Arcane UI framework
- Production-ready 3-project architecture
- Firebase pre-configured with security rules
- Backend server included
- Complete automation via setup wizard
- Dart run scripts for common tasks

**vs. Other Templates:**
- Real-world patterns from production applications
- User system included (User, settings, capabilities)
- Signature-based server authentication
- Docker + Cloud Run deployment ready
- Security best practices (Firestore/Storage rules included)

## Troubleshooting

**Setup Issues:**

Command not found errors: The wizard checks prerequisites and provides installation instructions.

Flutter pub get failures: Automatic retry logic included. Check internet connection or run `flutter pub cache repair`.

Firebase login issues: Run `firebase login --reauth` and ensure you have Owner or Editor role.

**Build Issues:**

Android: Run `cd my_app/android && ./gradlew clean && cd .. && flutter clean && flutter pub get`

iOS/macOS pods: Run `cd my_app && dart run pod_install_ios` (or pod_install_macos)

Web: Clear browser cache and run `flutter clean && flutter pub get`

**Server Deployment:**

Docker: Ensure Docker daemon is running and sufficient disk space available.

Cloud Run: Check authentication (`gcloud auth list`), verify project (`gcloud config get-value project`), and ensure Cloud Run API is enabled.

## License

See LICENSE file for details.

## Acknowledgments

- Arcane Framework - Material Design-free Flutter UI
- Beamer Navigation - Declarative routing
- Flutter Team - Amazing framework
- Occult CLI - Original inspiration for project automation

## Support

- Issues: GitHub Issues
- Flutter Community: flutter.dev/community
- Stack Overflow: Tag with `flutter` and `arcane`
