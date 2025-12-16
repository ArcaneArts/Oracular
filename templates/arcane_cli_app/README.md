# arcane_cli_app CLI

Command-line interface for arcane_cli_app built with the Arcane Templates CLI framework.

## Overview

This is a Dart-based CLI application that uses `darted_cli` for declarative, clean command structure. The CLI integrates with your arcane_cli_app ecosystem including models, server API, and Firebase services.

## Features

- **Declarative Commands**: Uses `darted_cli` for clean, no-codegen command structure
- **Interactive Prompts**: Built-in `interact` package for arrow-key menus, confirmations, and inputs
- **Beautiful Help Text**: Auto-generated documentation from command definitions
- **Config Management**: Built-in configuration file handling
- **Firebase Integration**: Admin SDK commands for Firestore and Auth (if enabled)
- **Server API Client**: Authenticated HTTP client for calling your server (if enabled)
- **Fast Logging**: Integrated `fast_log` for beautiful terminal output

## Quick Start

### Installation

```bash
# Get dependencies
dart pub get

# Run the CLI
dart run bin/main.dart --help
```

### Local Global Activation (Development)

To use `arcane_cli_app` command globally on your machine during development:

```bash
# Activate from local path
dart pub global activate . --source=path

# Now use anywhere on YOUR machine
arcane_cli_app --help
arcane_cli_app hello greet --name "World"

# Deactivate when done
dart pub global deactivate arcane_cli_app
```

## Publishing to pub.dev

To share your CLI so **anyone** can install it with a single command:

### 1. Prepare for Publishing

Edit `pubspec.yaml`:

```yaml
name: arcane_cli_app
description: "A useful CLI tool that does X, Y, Z"  # Update this!
version: 1.0.0

# Add your repo info:
homepage: https://github.com/YOUR_USERNAME/arcane_cli_app
repository: https://github.com/YOUR_USERNAME/arcane_cli_app
issue_tracker: https://github.com/YOUR_USERNAME/arcane_cli_app/issues

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
dart pub global activate arcane_cli_app

# Run your CLI
arcane_cli_app --help
arcane_cli_app hello greet --name "World"
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
dart pub global activate arcane_cli_app  # Gets latest version
```

## Available Commands

### Hello Commands

Basic examples demonstrating CLI structure:

```bash
# Greet someone
arcane_cli_app hello greet --name "Alice"

# Multiple greetings with enthusiasm
arcane_cli_app hello greet --name "Bob" --times --enthusiastic

# Show version
arcane_cli_app hello version
```

### Config Commands

Manage application configuration (stored in `~/.arcane_cli_app/config.yaml`):

```bash
# Initialize config file
arcane_cli_app config init

# Set a value
arcane_cli_app config set --key server_url --value https://api.example.com
arcane_cli_app config set --key api_key --value your_secret_key

# Get a value
arcane_cli_app config get --key server_url

# List all config
arcane_cli_app config list

# Show config file path
arcane_cli_app config path
```

### Firebase Integration (If Enabled)

When Firebase is enabled, the CLI has access to `fire_crud` and can interact with Firestore using your models. You can create custom commands that use FireCrud to perform type-safe database operations.

**Example: Creating a Firebase command**

```dart
// lib/cli/handlers/data_handlers.dart
import 'package:fast_log/fast_log.dart';
import 'package:fire_crud/fire_crud.dart';
import 'package:arcane_models/arcane_models.dart';

Future<void> handleListUsers(Map<String, dynamic> args, Map<String, dynamic> flags) async {
  final limit = int.tryParse(args['limit'] as String? ?? '10') ?? 10;

  info("Fetching users from Firestore...");

  final List<User> users = await User.fireCollection()
    .limit(limit)
    .get();

  for (final User user in users) {
    print('${user.id}: ${user.name}');
  }

  success("Listed ${users.length} user(s)");
}

Future<void> handleCreateUser(Map<String, dynamic> args, Map<String, dynamic> flags) async {
  final name = args['name'] as String?;
  final email = args['email'] as String?;

  if (name == null || email == null) {
    error('Please provide both name and email');
    return;
  }

  info("Creating user...");

  final User user = User(
    id: FireCrud.generateId(),
    name: name,
    email: email,
  );

  await user.save();
  success("User created: ${user.id}");
}
```

Then add to your commands tree:
```dart
// lib/cli/commands.dart
DartedCommand(
  name: 'data',
  helperDescription: 'Firestore data operations',
  subCommands: [
    DartedCommand(
      name: 'list-users',
      helperDescription: 'List users from Firestore',
      arguments: [DartedArgument(name: 'limit', abbreviation: 'l', defaultValue: '10')],
      callback: (args, flags) => handleListUsers(args ?? {}, _boolToMap(flags)),
    ),
    DartedCommand(
      name: 'create-user',
      helperDescription: 'Create a new user',
      arguments: [
        DartedArgument(name: 'name', abbreviation: 'n'),
        DartedArgument(name: 'email', abbreviation: 'e'),
      ],
      callback: (args, flags) => handleCreateUser(args ?? {}, _boolToMap(flags)),
    ),
  ],
),
```

### Server Commands (If Enabled)

Call your arcane_cli_app server API:

```bash
# Ping server health check
arcane_cli_app server ping

# Get server info
arcane_cli_app server info

# Configure server connection
arcane_cli_app server configure --url https://your-server.com --key your_api_key

# Test authenticated API call
arcane_cli_app server test
```

**Configuration:**
- Server URL: Set via `--url` flag, environment variable `arcane_cli_app_SERVER_URL`, or config file
- API Key: Set via `--key` flag, environment variable `arcane_cli_app_API_KEY`, or config file

## Development

### Project Structure

```
arcane_cli_app/
├── bin/
│   └── main.dart              # Entry point
├── lib/
│   └── cli/
│       ├── commands.dart      # Declarative command tree
│       └── handlers/          # Command implementations
│           ├── hello_handlers.dart
│           ├── config_handlers.dart
│           └── server_handlers.dart  # (if server enabled)
├── pubspec.yaml
└── README.md
```

### Adding New Commands

1. **Create Handler File** in `lib/cli/handlers/`:

```dart
// lib/cli/handlers/my_handlers.dart
import 'package:fast_log/fast_log.dart';

Future<void> handleDoSomething(Map<String, dynamic> args, Map<String, dynamic> flags) async {
  final param = args['param'] as String?;

  info("Executing command...");
  print("Result: $param");
  success("Done!");
}
```

2. **Add to Command Tree** (`lib/cli/commands.dart`):

```dart
import 'handlers/my_handlers.dart';

final List<DartedCommand> commandsTree = [
  // ... existing commands ...

  DartedCommand(
    name: 'my',
    helperDescription: 'My custom commands',
    subCommands: [
      DartedCommand(
        name: 'do-something',
        helperDescription: 'Execute my custom action',
        arguments: [DartedArgument(name: 'param', abbreviation: 'p')],
        callback: (args, flags) => handleDoSomething(args ?? {}, _boolToMap(flags)),
      ),
    ],
  ),
];
```

3. **Run**:

```bash
dart run bin/main.dart my do-something --param "hello"
```

No code generation needed!

## Environment Variables

Configure the CLI via environment variables:

```bash
# Server configuration
export arcane_cli_app_SERVER_URL=https://api.example.com
export arcane_cli_app_API_KEY=your_secret_key

# Run CLI
arcane_cli_app server ping
```

## Configuration File

Config is stored in `~/.arcane_cli_app/config.yaml`:

```yaml
# arcane_cli_app Configuration
app_name: arcane_cli_app
version: 1.0.0
server_url: https://api.example.com
api_key: your_secret_key
```

## Integration

### With Models Package

If the models package exists, it's automatically included:

```dart
import 'package:arcane_models/arcane_models.dart';

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

### Dependency Issues

```bash
# Clean and reinstall
dart pub get
```

### Firebase Issues

- Ensure service account key is in the correct location
- Verify Firebase project ID matches your project
- Check that service account has necessary permissions

### Server Connection Issues

- Verify server URL is correct and accessible
- Ensure API key is configured
- Check that server is running: `arcane_cli_app server ping`

## Learn More

- [darted_cli Documentation](https://pub.dev/packages/darted_cli)
- [interact Documentation](https://pub.dev/packages/interact)
- [Arcane Templates](https://github.com/ArcaneArts/arcane_templates)
- [fast_log](https://pub.dev/packages/fast_log)

## License

Generated from Arcane Templates - Part of the arcane_cli_app project.
