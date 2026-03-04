```
 ██████╗ ██████╗  █████╗  ██████╗██╗   ██╗██╗      █████╗ ██████╗
██╔═══██╗██╔══██╗██╔══██╗██╔════╝██║   ██║██║     ██╔══██╗██╔══██╗
██║   ██║██████╔╝███████║██║     ██║   ██║██║     ███████║██████╔╝
██║   ██║██╔══██╗██╔══██║██║     ██║   ██║██║     ██╔══██║██╔══██╗
╚██████╔╝██║  ██║██║  ██║╚██████╗╚██████╔╝███████╗██║  ██║██║  ██║
 ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝
```

Command-line interface for Arcane project scaffolding and script running.

## Installation

```bash
dart pub global activate oracular
```

## Commands

### Project Creation

```bash
oracular                          # Interactive wizard
oracular create app               # Create new project
oracular create templates         # List available templates
```

### Script Runner

Run scripts from `pubspec.yaml` with fuzzy matching:

```bash
oracular scripts list             # List all available scripts
oracular scripts exec <name>      # Execute a script
oracular scripts exec build       # Exact match
oracular scripts exec br          # Abbreviation (build_runner)
oracular scripts exec tv          # Abbreviation (test_verbose)
oracular scripts exec --stream    # Stream output in real-time
```

**Matching modes:**
- Exact: `build_runner`
- Case-insensitive: `Build_Runner`
- Prefix: `build` (if unique)
- Contains: `runner` (if unique)
- Abbreviation: `br` = `build_runner`, `df` = `deploy_firebase`

### Tool Verification

```bash
oracular check tools              # Verify all required CLI tools
oracular check flutter            # Check Flutter installation
oracular check firebase           # Check Firebase CLI tools
oracular check docker             # Check Docker installation
oracular check gcloud             # Check Google Cloud SDK
oracular check server             # Check server deployment tools
oracular check doctor             # Run flutter doctor -v
```

### Firebase Deployment

```bash
oracular deploy all               # Deploy all Firebase resources
oracular deploy firestore         # Deploy Firestore rules/indexes
oracular deploy storage           # Deploy Storage rules
oracular deploy hosting           # Build web & deploy to release
oracular deploy hosting-beta      # Build web & deploy to beta
oracular deploy firebase-setup    # Initial Firebase/FlutterFire setup
oracular deploy generate-configs  # Generate Firebase config files
```

### Server Deployment

```bash
oracular deploy server-setup      # Generate Dockerfiles & scripts
oracular deploy server-build      # Build production Docker image
```

### Configuration

```bash
oracular config show              # Display current configuration
oracular config path              # Show config file path
```

## Templates

### Flutter Templates (Native Apps)

| # | Name | Type | Platforms | Description |
|---|------|------|-----------|-------------|
| 1 | Basic Arcane | Flutter | All | Multi-platform app with Arcane UI |
| 2 | Beamer Navigation | Flutter | All | Declarative routing with Beamer |
| 3 | Desktop Tray | Flutter | Desktop | System tray/menu bar app |

### Jaspr Templates (Web)

| # | Name | Type | Output | Description |
|---|------|------|--------|-------------|
| 5 | Jaspr Web App | Jaspr | SPA | Interactive web app with Arcane Jaspr 3.x |
| 6 | Jaspr Docs | Jaspr | Static | Documentation site powered by Arcane Inkwell |

### Dart Templates

| # | Name | Type | Description |
|---|------|------|-------------|
| 4 | Dart CLI | Dart | Command-line interface application |

### Additional Packages

- **Models Package** (`<app>_models`) - Shared data models with Artifact serialization
- **Server App** (`<app>_server`) - Shelf REST API with FireCrud integration

## Platform Comparison

See the full [Platform Comparison Guide](../docs/PLATFORM_COMPARISON.md) for detailed pros/cons between Flutter and Jaspr.

| Consideration | Flutter + Arcane | Jaspr + Arcane Jaspr |
|---------------|------------------|----------------------|
| Best For | Native apps, offline-first | Websites, SEO, static sites |
| Output | Native binaries | HTML/CSS/JS |
| SEO Support | Limited | Full |
| Bundle Size | 2-5MB+ | 100-500KB |
| Platforms | iOS, Android, Desktop, Web | Web only |

## Development

### Setup

```bash
dart pub get
dart run build_runner build --delete-conflicting-outputs
```

### Run Locally

```bash
dart run bin/main.dart --help
dart run bin/main.dart scripts list
```

### Local Testing

```bash
# Activate from source
dart pub global activate . --source=path

# Test commands
oracular --help
oracular scripts list

# Deactivate
dart pub global deactivate oracular
```

### Watch Mode

```bash
dart run build_runner watch -d
```

### Scripts (via Oracular)

```bash
oracular scripts exec build       # Run build_runner
oracular scripts exec test        # Run tests
oracular scripts exec activate    # Activate locally
```

## Adding Commands

1. Create file in `lib/commands/`

```dart
import 'package:cli_annotations/cli_annotations.dart';
import 'package:fast_log/fast_log.dart';

part 'my_command.g.dart';

@cliSubcommand
class MyCommand extends _$MyCommand {
  @cliCommand
  Future<void> action(String param, {bool flag = false}) async {
    info("Running with $param, flag=$flag");
  }
}
```

2. Register in `lib/oracular.dart`

```dart
import 'commands/my_command.dart';

// In OracularRunner class:
@cliMount
MyCommand get my => MyCommand();
```

3. Generate code

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Architecture

```
lib/
├── oracular.dart          CLI runner & command mounts
├── commands/                Command implementations
│   ├── check_command.dart      Tool verification
│   ├── config_command.dart     Configuration management
│   ├── create_command.dart     Project creation
│   ├── deploy_command.dart     Firebase/server deployment
│   └── script_command.dart     Script runner
├── services/                Business logic
│   ├── script_runner.dart      Pubspec script execution
│   ├── template_copier.dart    Template file copying
│   ├── project_creator.dart    Flutter/Dart project creation
│   ├── dependency_manager.dart Dependency management
│   └── ...
├── models/                  Data structures
└── utils/                   Utilities
```

## Publishing

```bash
dart pub publish --dry-run      # Verify
dart pub publish                # Publish to pub.dev
```
