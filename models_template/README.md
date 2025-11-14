# Models Template

Shared data models package for Flutter applications. Provides type-safe Firestore models with code generation for client and server use.

## Overview

Package containing all shared data structures used across your Flutter app ecosystem.

**Includes:**
- User management models (User, settings, capabilities)
- Server communication (command/response patterns)
- Type-safe Firestore operations
- Automatic code generation

## Structure

```
lib/
├── APPNAME_models.dart        # Main library export
└── models/
    ├── user.dart              # User account model
    ├── user_settings.dart     # User preferences
    └── server_command.dart    # Server command/response
```

## Quick Start

### 1. Register Models

In your app's main entry (client or server):

```dart
import 'package:APPNAME_models/APPNAME_models.dart';

void main() {
  registerCrud(); // Register all FireCrud models
  runApp(MyApp());
}
```

### 2. Use in Client

```dart
// Get user
final user = await User.crud.get(userId);

// Get settings
final settings = await UserSettings.crud.get(userId, parent: user);

// Update theme
final updated = UserSettings(themeMode: ThemeMode.dark);
await UserSettings.crud.set(userId, updated, parent: user);
```

### 3. Use in Server

```dart
// Create user
final user = User(name: "John Doe", email: "john@example.com");
await User.crud.set(userId, user);

// Handle command
final command = ServerCommand(
  type: ServerCommandType.custom,
  user: userId,
  data: {"action": "process"},
  timestamp: DateTime.now(),
);
await ServerCommand.crud.add(command);
```

## Included Models

### User

Path: `/user/{userId}`

User account in the system.

**Fields:**
- `name: String` - Display name
- `email: String` - Email address
- `profileHash: String?` - Profile image hash (optional)

**Child Models:**
- UserSettings - User preferences
- UserCapabilities - User permissions (if needed)

**Usage:**
```dart
final user = User(name: "Jane", email: "jane@example.com");
await User.crud.set(userId, user);

// Stream updates
User.crud.stream(userId).listen((user) {
  print('User: ${user?.name}');
});
```

### UserSettings

Path: `/user/{userId}/data/settings`

User preferences stored as subcollection document.

**Fields:**
- `themeMode: ThemeMode` - Theme preference (light/dark/system)

**Usage:**
```dart
final user = await User.crud.get(userId);
final settings = await UserSettings.crud.get(userId, parent: user);

// Update
final updated = UserSettings(themeMode: ThemeMode.dark);
await UserSettings.crud.set(userId, updated, parent: user);
```

**Extend with more fields:**

```dart
@model
class UserSettings with ModelCrud {
  final ThemeMode themeMode;
  final String language;
  final bool notificationsEnabled;

  // Constructor, childModels...
}
```

Run `dart run build_runner` after changes.

### ServerCommand

Path: `/command/{commandId}`

Commands sent from client to server.

**Fields:**
- `type: ServerCommandType` - Command type enum
- `user: String` - User ID who issued command
- `data: Map<String, dynamic>` - Command parameters
- `timestamp: DateTime` - Creation time

**Usage:**
```dart
// Client: Send command
final command = ServerCommand(
  type: ServerCommandType.custom,
  user: currentUserId,
  data: {"action": "processData", "params": {"id": 123}},
  timestamp: DateTime.now(),
);
await ServerCommand.crud.add(command);

// Listen for response
ServerResponse.crud.stream(commandId, parent: command).listen((response) {
  if (response != null) {
    print('Success: ${response.success}');
  }
});
```

### ServerResponse

Path: `/command/{commandId}/response/{responseId}`

Server's response to a command (subcollection).

**Fields:**
- `user: String` - User ID (for security rules)
- `success: bool` - Whether command succeeded
- `data: Map<String, dynamic>` - Response data or error details
- `timestamp: DateTime` - Creation time

**Usage:**
```dart
// Server: Respond to command
final response = ServerResponse(
  user: command.user,
  success: true,
  data: {"result": "processed", "count": 5},
  timestamp: DateTime.now(),
);
await ServerResponse.crud.set("response", response, parent: command);
```

## Code Generation

### When to Generate

Run after:
- Adding new models
- Modifying existing models
- Adding/changing fields
- Changing field types

### Generate Command

```bash
cd APPNAME_models
dart run build_runner build --delete-conflicting-outputs
```

### What Gets Generated

- `.g.dart` files for each model
- Artifact serialization code
- FireCrud CRUD operations
- Type adapters (if using Hive)

Never edit `.g.dart` files manually - they are regenerated each time.

## Adding New Models

**Step 1:** Create model file (`lib/models/my_model.dart`):

```dart
import 'package:artifact/artifact.dart';
import 'package:fire_crud/fire_crud.dart';

part 'my_model.g.dart';

@model
class MyModel with ModelCrud {
  final String id;
  final String name;
  final DateTime createdAt;

  MyModel({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  @override
  List<FireModel<ModelCrud>> get childModels => [];
}
```

**Step 2:** Export from main library (`lib/APPNAME_models.dart`):

```dart
export 'models/my_model.dart';
```

**Step 3:** Register in CRUD (`lib/APPNAME_models.dart`):

```dart
void registerCrud() {
  FireCrud.i.register([
    FireModel<User>.artifact("user"),
    FireModel<UserSettings>.artifact("data", exclusiveDocumentId: "settings"),
    FireModel<MyModel>.artifact("mymodel"),  // Add
  ]);
}
```

**Step 4:** Generate code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

**Step 5:** Use model:

```dart
final model = MyModel(id: "123", name: "Test", createdAt: DateTime.now());
await MyModel.crud.set("123", model);
```

## Parent-Child Relationships

Define subcollections with `childModels`:

```dart
@model
class Parent with ModelCrud {
  final String name;

  Parent({required this.name});

  @override
  List<FireModel<ModelCrud>> get childModels => [
    FireModel<Child>.artifact("children"),
  ];
}

@model
class Child with ModelCrud {
  final String data;

  Child({required this.data});

  @override
  List<FireModel<ModelCrud>> get childModels => [];
}
```

**Usage:**
```dart
// Save parent
final parent = Parent(name: "Parent");
await Parent.crud.set("parent1", parent);

// Save child
final child = Child(data: "Child data");
await Child.crud.set("child1", child, parent: parent);

// Path: /parent/parent1/children/child1
```

## Firestore Rules

Models are secured by rules in `config/firestore.rules`.

### User Rules

```javascript
match /user/{user} {
  allow read,create: if isUser(user);
  allow update: if isAdmin();

  match /data/settings {
    allow read,write: if isUser(user);
  }
}
```

### Command/Response Rules

```javascript
match /command/{command} {
  allow create: if isAuth() && isUser(request.resource.data.user);

  match /response/{response} {
    allow read: if isAuth() && isUser(resource.data.user);
  }
}
```

### Deploy Rules

After modifying rules:

```bash
cd APPNAME
dart run deploy_firestore
```

## Best Practices

**1. Immutable Models:**

```dart
@model
class ImmutableModel with ModelCrud {
  final String id;
  final String name;

  const ImmutableModel({required this.id, required this.name});

  ImmutableModel copyWith({String? id, String? name}) {
    return ImmutableModel(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  List<FireModel<ModelCrud>> get childModels => [];
}
```

**2. Validation:**

```dart
@model
class ValidatedModel with ModelCrud {
  final String email;

  ValidatedModel({required this.email}) {
    if (!email.contains('@')) {
      throw ArgumentError('Invalid email');
    }
  }

  @override
  List<FireModel<ModelCrud>> get childModels => [];
}
```

**3. Computed Properties:**

```dart
@model
class User with ModelCrud {
  final String firstName;
  final String lastName;

  User({required this.firstName, required this.lastName});

  String get fullName => '$firstName $lastName';

  @override
  List<FireModel<ModelCrud>> get childModels => [];
}
```

**4. Timestamps:**

```dart
@model
class TimestampedModel with ModelCrud {
  final DateTime createdAt;
  final DateTime? updatedAt;

  TimestampedModel({required this.createdAt, this.updatedAt});

  @override
  List<FireModel<ModelCrud>> get childModels => [];
}
```

**5. Optional Fields:**

```dart
@model
class FlexibleModel with ModelCrud {
  final String requiredField;
  final String? optionalField;
  final int? optionalNumber;

  FlexibleModel({
    required this.requiredField,
    this.optionalField,
    this.optionalNumber,
  });

  @override
  List<FireModel<ModelCrud>> get childModels => [];
}
```

## Testing

**Unit tests:**

```dart
import 'package:test/test.dart';
import 'package:APPNAME_models/APPNAME_models.dart';

void main() {
  group('User Model', () {
    test('creates user with required fields', () {
      final user = User(name: 'Test', email: 'test@example.com');
      expect(user.name, 'Test');
      expect(user.email, 'test@example.com');
      expect(user.profileHash, isNull);
    });
  });
}
```

## Dependencies

**Core:**
- artifact - Data serialization
- crypto - Hashing
- fire_crud - Firestore CRUD
- toxic - Dart utility extensions

**Dev:**
- artifact_gen - Code generation
- build_runner - Runs generators
- fire_crud_gen - FireCrud boilerplate
- lints - Dart linting

## Examples

### Complete User Flow

```dart
import 'package:APPNAME_models/APPNAME_models.dart';

Future<void> userFlow(String userId) async {
  // Create user
  final user = User(name: "Alice", email: "alice@example.com");
  await User.crud.set(userId, user);

  // Create settings
  final settings = UserSettings(themeMode: ThemeMode.dark);
  await UserSettings.crud.set(userId, settings, parent: user);

  // Read
  final fetchedUser = await User.crud.get(userId);
  final fetchedSettings = await UserSettings.crud.get(userId, parent: fetchedUser!);

  print('User: ${fetchedUser.name}, Theme: ${fetchedSettings?.themeMode.name}');

  // Update
  final updated = UserSettings(themeMode: ThemeMode.light);
  await UserSettings.crud.set(userId, updated, parent: fetchedUser);

  // Delete (cascades to subcollections)
  await User.crud.delete(userId);
}
```

### Server Command Flow

```dart
Future<Map<String, dynamic>> sendCommand(
  String userId,
  String action,
  Map<String, dynamic> params,
) async {
  // Create command
  final command = ServerCommand(
    type: ServerCommandType.custom,
    user: userId,
    data: {"action": action, "params": params},
    timestamp: DateTime.now(),
  );

  // Send to Firestore
  final commandId = await ServerCommand.crud.add(command);

  // Wait for response
  final response = await ServerResponse.crud
      .stream("response", parent: command)
      .firstWhere((r) => r != null);

  return response.data;
}
```

## Documentation

- [Main README](../README.md) - Project overview
- [Server Template](../server_template/README.md) - Backend server guide
- [FireCrud Documentation](../references/FireCrud.txt) - Complete CRUD guide
- [Artifact Documentation](../references/Artifact.txt) - Serialization guide

## Related Templates

- **arcane_template** - Client application
- **arcane_beamer** - Client with navigation
- **arcane_dock** - System tray application
- **server_template** - Backend server

See [main README](../README.md) for details.
