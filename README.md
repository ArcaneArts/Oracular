```
 ██████╗ ██████╗  █████╗  ██████╗██╗   ██╗██╗      █████╗ ██████╗
██╔═══██╗██╔══██╗██╔══██╗██╔════╝██║   ██║██║     ██╔══██╗██╔══██╗
██║   ██║██████╔╝███████║██║     ██║   ██║██║     ███████║██████╔╝
██║   ██║██╔══██╗██╔══██║██║     ██║   ██║██║     ██╔══██║██╔══██╗
╚██████╔╝██║  ██║██║  ██║╚██████╗╚██████╔╝███████╗██║  ██║██║  ██║
 ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝
```

Project scaffolding and script runner for Arcane-based Flutter and Dart applications.

## Features

- **Project Scaffolding** - Create production-ready Flutter and Dart projects
- **Script Runner** - Execute pubspec.yaml scripts with fuzzy matching
- **Multi-Project Architecture** - Client, models, and server packages
- **Firebase Integration** - Automated setup and deployment
- **Platform Selection** - Choose which platforms to target

## Structure

```
Oracular/
├── oracular/          Dart CLI tool
├── oracular_gui/      Flutter GUI wizard
└── templates/       Project templates (editable)
    ├── arcane_app/         Basic multi-platform Flutter app
    ├── arcane_beamer_app/  Beamer navigation Flutter app
    ├── arcane_dock_app/    Desktop system tray app
    ├── arcane_cli_app/     Dart CLI application
    ├── arcane_models/      Shared data models package
    └── arcane_server/      Shelf-based REST API server
```

## Installation

```bash
dart pub global activate oracular
```

## Quick Start

```bash
# Interactive wizard
oracular

# Launch GUI wizard
oracular gui

# Create project directly
oracular create app --name my_app --org com.example
```

## Commands

### Project Creation

```bash
oracular                          # Interactive wizard
oracular gui                      # Launch GUI wizard
oracular create app               # Create project with prompts
oracular create templates         # List available templates
```

### Script Runner

Run scripts defined in your `pubspec.yaml`:

```bash
oracular scripts list             # List all scripts
oracular scripts exec build       # Run a script
oracular scripts exec br          # Abbreviation (build_runner)
oracular scripts exec tv          # Abbreviation (test_verbose)
```

Supports fuzzy matching and abbreviations (first letter of each word).

### Tool Verification

```bash
oracular check tools              # Verify all CLI tools
oracular check flutter            # Check Flutter installation
oracular check firebase           # Check Firebase CLI
oracular check docker             # Check Docker
oracular check gcloud             # Check Google Cloud SDK
oracular check doctor             # Run flutter doctor
```

### Firebase Deployment

```bash
oracular deploy all               # Deploy all Firebase resources
oracular deploy firestore         # Deploy Firestore rules
oracular deploy storage           # Deploy Storage rules
oracular deploy hosting           # Deploy to release hosting
oracular deploy hosting-beta      # Deploy to beta hosting
oracular deploy firebase-setup    # Initial Firebase setup
```

### Server Deployment

```bash
oracular deploy server-setup      # Generate Docker configs
oracular deploy server-build      # Build Docker image
```

## Templates

| Template | Type | Platforms | Description |
|----------|------|-----------|-------------|
| Basic Arcane | Flutter | All | Multi-platform app with Arcane UI |
| Beamer Navigation | Flutter | All | Declarative routing with Beamer |
| Desktop Tray | Flutter | Desktop | System tray/menu bar application |
| Dart CLI | Dart | - | Command-line interface app |

### Additional Packages

- **Models Package** - Shared data models for client and server
- **Server App** - Shelf-based REST API with Firebase integration

## Script Runner Examples

Add scripts to your `pubspec.yaml`:

```yaml
scripts:
  build: flutter build web --release
  deploy: firebase deploy --project my-project
  build_runner: dart run build_runner build --delete-conflicting-outputs
  test_verbose: dart test --reporter=expanded
  pod_install: cd ios && pod install --repo-update
```

Then run with abbreviations:

```bash
oracular scripts exec b           # build (unique prefix)
oracular scripts exec br          # build_runner
oracular scripts exec tv          # test_verbose
oracular scripts exec pi          # pod_install
```

## Development

See individual package READMEs:
- [CLI Development](oracular/README.md)
- [GUI Development](oracular_gui/README.md)

## License

MIT
