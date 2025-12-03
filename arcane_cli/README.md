# APPNAME CLI

Command-line interface for APPNAME built with the Arcane Templates CLI framework.

## Overview

This is a Dart-based CLI application that uses `cli_gen` for beautiful, type-safe command generation. The CLI integrates with your APPNAME ecosystem including models, server API, and Firebase services.

## Features

- **Type-Safe Commands**: Leverages `cli_gen` for automatic argument parsing and validation
- **Beautiful Help Text**: Auto-generated documentation from code comments
- **Config Management**: Built-in configuration file handling
- **Firebase Integration**: Admin SDK commands for Firestore and Auth (if enabled)
- **Server API Client**: Authenticated HTTP client for calling your server (if enabled)
- **Fast Logging**: Integrated `fast_log` for beautiful terminal output

## Quick Start

### Installation

```bash
# Get dependencies
dart pub get

# Generate CLI code
dart run build_runner build --delete-conflicting-outputs

# Run the CLI
dart run bin/main.dart --help
```

### Local Global Activation (Development)

To use `APPNAME` command globally on your machine during development:

```bash
# Activate from local path
dart pub global activate . --source=path

# Now use anywhere on YOUR machine
APPNAME --help
APPNAME hello greet "World"

# Deactivate when done
dart pub global deactivate APPNAME
```

## Publishing to pub.dev

To share your CLI so **anyone** can install it with a single command:

### 1. Prepare for Publishing

Edit `pubspec.yaml`:

```yaml
name: APPNAME
description: "A useful CLI tool that does X, Y, Z"  # Update this!
version: 1.0.0

# Add your repo info:
homepage: https://github.com/YOUR_USERNAME/APPNAME
repository: https://github.com/YOUR_USERNAME/APPNAME
issue_tracker: https://github.com/YOUR_USERNAME/APPNAME/issues

# Optional but recommended for discoverability:
topics:
  - cli
  - command-line
  - tools
```

### 2. Verify Before Publishing

```bash
# Check for any issues
dart pub publish --dry-run
```

Fix any warnings or errors before proceeding.

### 3. Publish to pub.dev

```bash
# Publish (requires pub.dev account)
dart pub publish
```

You'll need to authenticate with your Google account linked to pub.dev.

### 4. Users Can Now Install Globally!

Once published, anyone in the world can install your CLI:

```bash
# Install from pub.dev (works on any machine!)
dart pub global activate APPNAME

# Run your CLI
APPNAME --help
APPNAME hello greet "World"
```

### PATH Configuration

Users may need to add the pub cache bin to their PATH:

```bash
# macOS/Linux - add to ~/.bashrc or ~/.zshrc:
export PATH="$PATH:$HOME/.pub-cache/bin"

# Windows - add to PATH:
%LOCALAPPDATA%\Pub\Cache\bin
```

### Updating Published Versions

```bash
# Bump version in pubspec.yaml, then:
dart pub publish
```

Users update with:
```bash
dart pub global activate APPNAME  # Gets latest version
```

## Available Commands

### Hello Commands

Basic examples demonstrating CLI structure:

```bash
# Greet someone
APPNAME hello greet "Alice"

# Multiple greetings with enthusiasm
APPNAME hello greet "Bob" --times 3 --enthusiastic

# Show version
APPNAME hello version
```

### Config Commands

Manage application configuration (stored in `~/.APPNAME/config.yaml`):

```bash
# Initialize config file
APPNAME config init

# Set a value
APPNAME config set server_url https://api.example.com
APPNAME config set api_key your_secret_key

# Get a value
APPNAME config get server_url

# List all config
APPNAME config list

# Show config file path
APPNAME config path
```

### Firebase Integration (If Enabled)

When Firebase is enabled, the CLI has access to `fire_crud` and can interact with Firestore using your models. You can create custom commands that use FireCrud to perform type-safe database operations.

**Example: Creating a Firebase command**

```dart
import 'package:cli_annotations/cli_annotations.dart';
import 'package:fast_log/fast_log.dart';
import 'package:fire_crud/fire_crud.dart';
import 'package:APPNAME_models/APPNAME_models.dart';

part 'data_command.g.dart';

@cliSubcommand
class DataCommand extends _$DataCommand {
  @cliCommand
  Future<void> listUsers({int limit = 10}) async {
    info("Fetching users from Firestore...");

    final List<User> users = await User.fireCollection()
      .limit(limit)
      .get();

    for (final User user in users) {
      print('${user.id}: ${user.name}');
    }

    success("Listed ${users.length} user(s)");
  }

  @cliCommand
  Future<void> createUser(String name, String email) async {
    info("Creating user...");

    final User user = User(
      id: FireCrud.generateId(),
      name: name,
      email: email,
    );

    await user.save();
    success("User created: ${user.id}");
  }
}
```

Then register it in your CLI runner and run code generation:
```bash
dart run build_runner build --delete-conflicting-outputs
APPNAME data list-users --limit 5
APPNAME data create-user "Alice" "alice@example.com"
```

### Server Commands (If Enabled)

Call your APPNAME server API:

```bash
# Ping server health check
APPNAME server ping

# Get server info
APPNAME server info

# Configure server connection
APPNAME server configure --url https://your-server.com --key your_api_key

# Test authenticated API call
APPNAME server test
```

**Configuration:**
- Server URL: Set via `--url` flag, environment variable `APPNAME_SERVER_URL`, or config file
- API Key: Set via `--key` flag, environment variable `APPNAME_API_KEY`, or config file

## Development

### Project Structure

```
APPNAME/
├── bin/
│   └── main.dart              # Entry point
├── lib/
│   ├── APPNAME.dart           # Main CLI runner
│   └── commands/              # Command implementations
│       ├── hello_command.dart
│       ├── config_command.dart
│       ├── firebase_command.dart  # (if Firebase enabled)
│       └── server_command.dart    # (if server enabled)
├── pubspec.yaml
└── README.md
```

### Adding New Commands

1. **Create Command File** in `lib/commands/`:

```dart
import 'package:cli_annotations/cli_annotations.dart';
import 'package:fast_log/fast_log.dart';

part 'my_command.g.dart';

@cliSubcommand
class MyCommand extends _$MyCommand {
  /// My custom command description
  @cliCommand
  Future<void> doSomething(String param) async {
    info("Executing command...");
    print("Result: $param");
  }
}
```

2. **Register in Runner** (`lib/APPNAME.dart`):

```dart
import 'commands/my_command.dart';

@cliRunner
class APPNAMERunner extends _$APPNAMERunner {
  // ...

  @cliMount
  MyCommand get my => MyCommand();
}
```

3. **Generate Code**:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Code Generation Workflow

The CLI uses `cli_gen` for code generation:

```bash
# One-time build
dart run build_runner build --delete-conflicting-outputs

# Watch mode (auto-rebuild on changes)
dart run build_runner watch -d
```

Generated files (`.g.dart`) are automatically created and should be committed to version control.

## Environment Variables

Configure the CLI via environment variables:

```bash
# Server configuration
export APPNAME_SERVER_URL=https://api.example.com
export APPNAME_API_KEY=your_secret_key

# Run CLI
APPNAME server ping
```

## Configuration File

Config is stored in `~/.APPNAME/config.yaml`:

```yaml
# APPNAME Configuration
app_name: APPNAME
version: 1.0.0
server_url: https://api.example.com
api_key: your_secret_key
```

## Integration

### With Models Package

If the models package exists, it's automatically included:

```dart
import 'package:APPNAME_models/APPNAME_models.dart';

// Use models in your commands
final user = User(id: '123', name: 'Alice');
```

### With Server Package

Call your server API with automatic signature authentication:

```dart
final response = await _apiRequest('GET', '/api/users');
```

### With Firebase

Use Firebase Admin SDK for server-side operations:

```dart
await ArcaneAdmin.initialize(
  projectId: 'FIREBASE_PROJECT_ID',
  serviceAccountKeyPath: 'path/to/key.json',
);

final users = await ArcaneAdmin.auth.listUsers();
```

## Troubleshooting

### Build Runner Issues

```bash
# Clean and rebuild
dart pub get
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

### Firebase Issues

- Ensure service account key is in the correct location
- Verify Firebase project ID matches your project
- Check that service account has necessary permissions

### Server Connection Issues

- Verify server URL is correct and accessible
- Ensure API key is configured
- Check that server is running: `APPNAME server ping`

## Learn More

- [cli_gen Documentation](https://pub.dev/packages/cli_gen)
- [Arcane Templates](https://github.com/ArcaneArts/arcane_templates)
- [fast_log](https://pub.dev/packages/fast_log)

## License

Generated from Arcane Templates - Part of the APPNAME project.
