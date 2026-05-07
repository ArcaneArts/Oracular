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
├── docs/              Documentation and guides
└── templates/         Project templates (editable)
    ├── arcane_app/           Basic multi-platform Flutter app
    ├── arcane_beamer_app/    Beamer navigation Flutter app
    ├── arcane_dock_app/      Desktop system tray app
    ├── arcane_jaspr_app/     Jaspr web application
    ├── arcane_jaspr_docs/    Jaspr static documentation site
    ├── arcane_cli_app/       Dart CLI application
    ├── arcane_models/        Shared data models package
    └── arcane_server/        Shelf-based REST API server
```

## Installation

```bash
dart pub global activate oracular
```

## Quick Start

```bash
# Interactive wizard
oracular

# Create project directly
oracular create app --name my_app --org com.example
```

## Commands

### Project Creation

```bash
oracular                          # Interactive wizard
oracular create app               # Create project with prompts
oracular create templates         # List available templates
```

### Guided Next Steps

Generated projects include `GET_STARTED.md`, plus shortcut commands for the
folders and setup consoles users need next.

```bash
oracular guide                    # Regenerate the setup guide
oracular guide --print            # Print the guide in the terminal
oracular open guide               # Open GET_STARTED.md
oracular open app                 # Open the main app folder
oracular open firebase            # Open Firebase project overview
oracular open auth                # Open Firebase Authentication
oracular open firestore           # Open Firestore Database
oracular open storage             # Open Firebase Storage
oracular open hosting             # Open Firebase Hosting
oracular open server              # Open the server package
oracular open service-account     # Open Firebase service account keys
oracular open cloud-run           # Open Google Cloud Run
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

### Flutter Templates (Native Apps)

| Template | Platforms | Description |
|----------|-----------|-------------|
| Basic Arcane | All | Multi-platform app with Arcane UI |
| Beamer Navigation | All | Declarative routing with Beamer |
| Desktop Tray | Desktop | System tray/menu bar application |

### Jaspr Templates (Web)

| Template | Output | Description |
|----------|--------|-------------|
| Jaspr Web App | SPA | Interactive web application with Arcane Jaspr |
| Jaspr Docs | Static | Documentation site with markdown support |

### Dart Templates

| Template | Description |
|----------|-------------|
| Dart CLI | Command-line interface application |

### Additional Packages

- **Models Package** - Shared data models for client and server
- **Server App** - Shelf-based REST API with Firebase integration

## Choosing Between Flutter and Jaspr

Not sure which platform to use? See our comprehensive [Platform Comparison Guide](docs/PLATFORM_COMPARISON.md) for detailed pros/cons analysis.

**Quick Decision:**
- Need native mobile/desktop apps? Use **Flutter + Arcane**
- Building a website with SEO requirements? Use **Jaspr + Arcane Jaspr**
- Want fast initial page loads? Use **Jaspr + Arcane Jaspr**
- Need offline-first functionality? Use **Flutter + Arcane**

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

See the [CLI Development](oracular/README.md) README.

## License

MIT
