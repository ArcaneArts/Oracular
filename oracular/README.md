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

### Without installing the CLI

Every release also publishes per-template ZIPs to the
[GitHub Releases page](https://github.com/ArcaneArts/oracular/releases).
Each ZIP is self-contained: extract it, run `dart run setup.dart …`, and
you get the same scaffolded project that `oracular create` produces, but
without needing the CLI on your `$PATH`. The two flows are equivalent:

| Method | Command | When to use |
|--------|---------|-------------|
| CLI flow | `oracular create -y -t arcane_app -n my_app -o com.example` | Repeated scaffolding, full wizard, ongoing project management |
| ZIP flow | `dart run setup.dart --name my_app --org com.example` (after `unzip arcane_app-vX.Y.Z.zip`) | One-off scaffolding, CI, machines with only the Dart SDK |

The ZIP flow's `setup.dart` is mechanically derived from the same
`PlaceholderReplacer` / `TemplateCopier` services this CLI uses, so the
on-disk result is structurally identical. The bundled script also offers
to `dart pub global activate oracular <version>` at the end so the CLI
flow becomes available going forward — see the root README for details.

## Commands

### Project Creation

```bash
oracular                          # Interactive wizard
oracular create app               # Create new project
oracular create templates         # List available templates
```

### Guided Next Steps

Every generated project root gets a `GET_STARTED.md` with exact commands,
local folders, and Firebase/Google console links.

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
oracular check billing            # Detect Spark vs Blaze billing plan
```

### Firebase Deployment

End-to-end setup is one command:

```bash
oracular deploy firebase-setup-full   # Login → billing → bootstrap →
                                      # rules → web build → release +
                                      # beta hosting → server APIs →
                                      # cleanup. Idempotent — safe to
                                      # rerun. Works for Flutter web AND
                                      # both Jaspr modes (static + client).
```

Each stage is also independently re-runnable:

```bash
oracular deploy firebase-setup        # Alias for firebase-setup-full
oracular deploy firestore-init        # Create the default Firestore DB
oracular deploy storage-init          # Create the default Storage bucket
oracular deploy auth-providers        # Open console hand-off for Email
                                      # / Google providers
oracular deploy firestore             # Deploy Firestore rules/indexes
oracular deploy storage               # Deploy Storage rules
oracular deploy hosting-init          # Create `<project>-beta` site +
                                      # apply firebase target:apply
oracular deploy hosting               # Build web & deploy release channel
oracular deploy hosting-beta          # Build web & deploy beta channel
oracular deploy generate-configs      # Regenerate firebase.json/.firebaserc
oracular deploy all                   # Deploy all Firebase rules at once
```

### Server Deployment & Cleanup

```bash
oracular deploy server-setup          # Generate Dockerfiles & scripts
oracular deploy server-build          # Build production Docker image
oracular deploy artifact-cleanup      # Ensure Artifact Registry repo +
                                      # apply cleanup policy (keeps N
                                      # most-recent + deletes >Dd images)
oracular deploy cloudrun-prune        # Cap Cloud Run revisions at N
                                      # (preserves traffic-serving revs)
```

The generated `script_deploy.sh` (in your server package) runs both
cleanup steps automatically after every push to keep Artifact Registry
storage and Cloud Run revision counts bounded.

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
| 6 | Jaspr Docs | Jaspr | Static | Documentation site powered by Arcane Lexicon |

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
# Safe default: unit tests, template copy/permutation checks, and
# non-deploying integration checks. Live Firebase/GCP deployment suites
# are tagged out by default.
dart test

# Explicit opt-in for live Firebase/GCP deployment tests. Requires
# ../service-account.json (or the legacy test service-account file) and
# mutates the oraculartestdeployments Firebase project.
ORACULAR_RUN_DEPLOYMENT_TESTS=1 dart test -P live-deployment test/integration/deployment

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
