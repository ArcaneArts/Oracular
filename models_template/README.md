# APPNAME Models

Shared data models package for APPNAME - provides type-safe Firestore models with code generation for both client and server applications.

## 📋 Overview

This package contains all shared data structures used across your Flutter app ecosystem:

- **User Management**: User accounts, settings, and capabilities
- **Server Communication**: Command/response patterns for server interactions
- **Type Safety**: Shared models ensure consistency between client and server
- **Code Generation**: Automatic serialization with artifact_gen and fire_crud_gen

## 🏗️ Structure

```
lib/
├── APPNAME_models.dart        # Main library export
└── models/
    ├── user.dart              # User account model
    ├── user_settings.dart     # User preferences (theme, etc.)
    └── server_command.dart    # Server command/response models
```

## 🚀 Quick Start

### 1. Register Models

In your app's main entry point (client or server):

```dart
import 'package:APPNAME_models/APPNAME_models.dart';

void main() {
  // Register all FireCrud models before using them
  registerCrud();

  // Your app initialization
  runApp(MyApp());
}
```

### 2. Use Models in Client

```dart
import 'package:APPNAME_models/APPNAME_models.dart';

// Get current user
final user = await User.crud.get(userId);
print('User: ${user.name} (${user.email})');

// Get user settings
final settings = await UserSettings.crud.get(userId, parent: user);
print('Theme: ${settings.themeMode.name}');

// Update theme
final updatedSettings = UserSettings(themeMode: ThemeMode.dark);
await UserSettings.crud.set(userId, updatedSettings, parent: user);
```

### 3. Use Models in Server

```dart
import 'package:APPNAME_models/APPNAME_models.dart';

// Create new user
final newUser = User(
  name: "John Doe",
  email: "john@example.com",
);
await User.crud.set(userId, newUser);

// Handle server command
final command = ServerCommand(
  type: ServerCommandType.custom,
  user: userId,
  data: {"action": "process"},
  timestamp: DateTime.now(),
);
await ServerCommand.crud.add(command);
```

## 📦 Included Models

### User

**Path:** `/user/{userId}`

Represents a user account in the system.

**Fields:**
- `name: String` - User's display name
- `email: String` - User's email address
- `profileHash: String?` - Optional profile image hash for Gravatar/cache busting

**Child Models:**
- `UserSettings` - User preferences
- `UserCapabilities` - User permissions (if needed)

**Example:**
```dart
final user = User(
  name: "Jane Smith",
  email: "jane@example.com",
  profileHash: "abc123",
);

// Save to Firestore
await User.crud.set(userId, user);

// Get from Firestore
final fetchedUser = await User.crud.get(userId);

// Stream updates
User.crud.stream(userId).listen((user) {
  print('User updated: ${user?.name}');
});
```

---

### UserSettings

**Path:** `/user/{userId}/data/settings`

User preferences and configuration stored as a subcollection document.

**Fields:**
- `themeMode: ThemeMode` - User's theme preference (light/dark/system)

**Example:**
```dart
// Get settings
final user = await User.crud.get(userId);
final settings = await UserSettings.crud.get(userId, parent: user);

// Update theme
final updatedSettings = UserSettings(themeMode: ThemeMode.dark);
await UserSettings.crud.set(userId, updatedSettings, parent: user);

// Stream settings changes
UserSettings.crud.stream(userId, parent: user).listen((settings) {
  print('Theme changed to: ${settings?.themeMode.name}');
});
```

**Extending UserSettings:**

Add more preferences as needed:

```dart
@model
class UserSettings with ModelCrud {
  final ThemeMode themeMode;
  final String language;           // Add new field
  final bool notificationsEnabled; // Add new field

  UserSettings({
    this.themeMode = ThemeMode.system,
    this.language = 'en',
    this.notificationsEnabled = true,
  });

  @override
  List<FireModel<ModelCrud>> get childModels => [];
}
```

Then run: `dart run build_runner`

---

### ThemeMode (Enum)

Enum for theme preferences.

**Values:**
- `ThemeMode.light` - Force light theme
- `ThemeMode.dark` - Force dark theme
- `ThemeMode.system` - Use system theme preference

**Example:**
```dart
// Use in settings
final settings = UserSettings(themeMode: ThemeMode.dark);

// Switch theme
switch (settings.themeMode) {
  case ThemeMode.light:
    // Apply light theme
    break;
  case ThemeMode.dark:
    // Apply dark theme
    break;
  case ThemeMode.system:
    // Use system theme
    break;
}

// Serialize/deserialize automatically handled by artifact
```

---

### ServerCommand

**Path:** `/command/{commandId}`

Commands sent from client to server for processing.

**Fields:**
- `type: ServerCommandType` - Command type enum
- `user: String` - User ID who issued command
- `data: Map<String, dynamic>` - Command parameters
- `timestamp: DateTime` - When command was created

**Example:**
```dart
// Client: Send command to server
final command = ServerCommand(
  type: ServerCommandType.custom,
  user: currentUserId,
  data: {
    "action": "processData",
    "params": {"id": 123}
  },
  timestamp: DateTime.now(),
);

final commandId = await ServerCommand.crud.add(command);

// Listen for response
ServerResponse.crud.stream(
  commandId,
  parent: command,
).listen((response) {
  if (response != null) {
    print('Response: ${response.data}');
    print('Success: ${response.success}');
  }
});
```

---

### ServerResponse

**Path:** `/command/{commandId}/response/{responseId}`

Server's response to a command, stored as subcollection of command.

**Fields:**
- `user: String` - User ID (for security rules)
- `success: bool` - Whether command succeeded
- `data: Map<String, dynamic>` - Response data or error details
- `timestamp: DateTime` - When response was created

**Example:**
```dart
// Server: Respond to command
final response = ServerResponse(
  user: command.user,
  success: true,
  data: {
    "result": "processed",
    "itemsAffected": 5
  },
  timestamp: DateTime.now(),
);

await ServerResponse.crud.set(
  "response",
  response,
  parent: command,
);
```

---

### ServerCommandType (Enum)

Enum defining available server command types.

**Values:**
- `ServerCommandType.custom` - Custom command (default)

**Extend with your own types:**

```dart
@model
enum ServerCommandType {
  custom,
  processData,
  exportReport,
  sendEmail,
  generatePDF,
}
```

Run: `dart run build_runner`

---

## 🔧 Code Generation

### When to Generate

Run code generation after:
- Adding new models
- Modifying existing models
- Adding new fields
- Changing field types

### Generate Command

```bash
# From models directory
cd APPNAME_models

# Run build_runner
dart run build_runner build --delete-conflicting-outputs

# Or use the script
dart run build_runner
```

### What Gets Generated

- `.g.dart` files for each model
- Artifact serialization code
- FireCrud CRUD operations
- Type adapters for Hive (if used)

### Generated Files

```
lib/models/
├── user.dart
├── user.g.dart              # Generated serialization
├── user_settings.dart
├── user_settings.g.dart     # Generated serialization
├── server_command.dart
└── server_command.g.dart    # Generated serialization
```

**Never edit `.g.dart` files manually** - they are regenerated each time!

---

## ➕ Adding New Models

### Step 1: Create Model File

Create `lib/models/my_model.dart`:

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

### Step 2: Export from Main Library

Add to `lib/APPNAME_models.dart`:

```dart
export 'models/my_model.dart';
```

### Step 3: Register in CRUD

Add to `registerCrud()` in `lib/APPNAME_models.dart`:

```dart
void registerCrud() {
  FireCrud.i.register([
    FireModel<User>.artifact("user"),
    FireModel<UserSettings>.artifact("data", exclusiveDocumentId: "settings"),
    FireModel<ServerCommand>.artifact("command"),
    FireModel<ServerResponse>.artifact("response"),
    FireModel<MyModel>.artifact("mymodel"),  // Add your model
  ]);
}
```

### Step 4: Generate Code

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Step 5: Use Your Model

```dart
// Create
final myModel = MyModel(
  id: "123",
  name: "Test",
  createdAt: DateTime.now(),
);

await MyModel.crud.set("123", myModel);

// Read
final model = await MyModel.crud.get("123");

// Update
final updated = MyModel(
  id: model.id,
  name: "Updated Name",
  createdAt: model.createdAt,
);
await MyModel.crud.set(model.id, updated);

// Delete
await MyModel.crud.delete("123");

// Stream
MyModel.crud.stream("123").listen((model) {
  print('Model updated: ${model?.name}');
});
```

---

## 🔗 Model Relationships

### Parent-Child Relationships

Use `childModels` to define subcollections:

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

// Get child
final fetchedChild = await Child.crud.get("child1", parent: parent);

// Path: /parent/parent1/children/child1
```

---

## 📜 Firestore Rules Integration

Models are secured by Firestore rules in `config/firestore.rules`.

### User Rules

```javascript
match /user/{user} {
  allow read,create: if isUser(user);
  allow update: if isAdmin();

  match /data/settings {
    allow read,write: if isUser(user);
  }

  match /data/capabilities {
    allow read: if isUser(user);
    allow write: if isAdmin();
  }
}
```

**Security:**
- Users can read/create their own user document
- Only admins can update user documents
- Users can read/write their own settings
- Only admins can write capabilities

### Command/Response Rules

```javascript
match /command/{command} {
  allow create: if isAuth() && isUser(request.resource.data.user);

  match /response/{response} {
    allow read: if isAuth() && isUser(resource.data.user);
  }
}
```

**Security:**
- Users can create commands for themselves
- Users can only read responses for their own commands
- Server writes responses via service account (bypasses rules)

### Update Rules

After modifying rules in `config/firestore.rules`:

```bash
# From your client app directory
cd APPNAME
dart run deploy_firestore
```

---

## 🎯 Best Practices

### 1. Immutable Models

Models should be immutable for better state management:

```dart
@model
class ImmutableModel with ModelCrud {
  final String id;
  final String name;

  // Const constructor
  const ImmutableModel({
    required this.id,
    required this.name,
  });

  // CopyWith method for updates
  ImmutableModel copyWith({
    String? id,
    String? name,
  }) {
    return ImmutableModel(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  List<FireModel<ModelCrud>> get childModels => [];
}
```

### 2. Validation

Add validation in constructors:

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

### 3. Computed Properties

Add getters for computed values:

```dart
@model
class User with ModelCrud {
  final String firstName;
  final String lastName;

  User({
    required this.firstName,
    required this.lastName,
  });

  // Computed property
  String get fullName => '$firstName $lastName';

  @override
  List<FireModel<ModelCrud>> get childModels => [];
}
```

### 4. Timestamps

Always include timestamps:

```dart
@model
class TimestampedModel with ModelCrud {
  final DateTime createdAt;
  final DateTime? updatedAt;

  TimestampedModel({
    required this.createdAt,
    this.updatedAt,
  });

  @override
  List<FireModel<ModelCrud>> get childModels => [];
}
```

### 5. Optional Fields

Use nullable types for optional data:

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

---

## 🔍 Testing Models

### Unit Tests

```dart
import 'package:test/test.dart';
import 'package:APPNAME_models/APPNAME_models.dart';

void main() {
  group('User Model', () {
    test('creates user with required fields', () {
      final user = User(
        name: 'Test User',
        email: 'test@example.com',
      );

      expect(user.name, 'Test User');
      expect(user.email, 'test@example.com');
      expect(user.profileHash, isNull);
    });

    test('creates user with profile hash', () {
      final user = User(
        name: 'Test User',
        email: 'test@example.com',
        profileHash: 'abc123',
      );

      expect(user.profileHash, 'abc123');
    });
  });
}
```

---

## 📚 Dependencies

This package uses:

| Package | Purpose |
|---------|---------|
| `artifact` | Data serialization and codecs |
| `crypto` | Hashing (for profile images, signatures) |
| `fire_crud` | Firestore CRUD operations |
| `toxic` | Dart utility extensions |

**Dev Dependencies:**

| Package | Purpose |
|---------|---------|
| `artifact_gen` | Code generation for @model classes |
| `build_runner` | Runs code generators |
| `fire_crud_gen` | Generates FireCrud boilerplate |
| `lints` | Dart linting rules |

---

## 🚀 Deployment

### Deploy Firestore Rules

When you add new models or change paths:

```bash
# From client app directory
cd APPNAME
dart run deploy_firestore
```

This deploys `config/firestore.rules` to Firebase.

### Verify Rules

Test your rules in Firebase Console:
1. Open Firebase Console
2. Go to Firestore Database → Rules
3. Click "Rules Playground"
4. Test read/write operations

---

## 🔗 Related Documentation

- **[Main README](../README.md)** - Project overview
- **[Server Template](../server_template/README.md)** - Backend server guide
- **[Setup Scripts](../scripts/README.md)** - Automation tools
- **[FireCrud Documentation](../SoftwareThings/FireCrud.txt)** - Complete CRUD guide
- **[Artifact Documentation](../SoftwareThings/Artifact.txt)** - Serialization guide

---

## 🎓 Examples

### Complete User Flow

```dart
import 'package:APPNAME_models/APPNAME_models.dart';

Future<void> userFlow(String userId) async {
  // 1. Create user
  final user = User(
    name: "Alice",
    email: "alice@example.com",
  );
  await User.crud.set(userId, user);

  // 2. Create settings
  final settings = UserSettings(
    themeMode: ThemeMode.dark,
  );
  await UserSettings.crud.set(userId, settings, parent: user);

  // 3. Read user and settings
  final fetchedUser = await User.crud.get(userId);
  final fetchedSettings = await UserSettings.crud.get(
    userId,
    parent: fetchedUser!,
  );

  print('User: ${fetchedUser.name}');
  print('Theme: ${fetchedSettings?.themeMode.name}');

  // 4. Update settings
  final updatedSettings = UserSettings(
    themeMode: ThemeMode.light,
  );
  await UserSettings.crud.set(userId, updatedSettings, parent: fetchedUser);

  // 5. Delete user (cascades to subcollections)
  await User.crud.delete(userId);
}
```

### Server Command Flow

```dart
import 'package:APPNAME_models/APPNAME_models.dart';

Future<Map<String, dynamic>> sendCommand(
  String userId,
  String action,
  Map<String, dynamic> params,
) async {
  // 1. Create command
  final command = ServerCommand(
    type: ServerCommandType.custom,
    user: userId,
    data: {
      "action": action,
      "params": params,
    },
    timestamp: DateTime.now(),
  );

  // 2. Send to Firestore
  final commandId = await ServerCommand.crud.add(command);
  print('Command sent: $commandId');

  // 3. Wait for response
  final response = await ServerResponse.crud
      .stream("response", parent: command)
      .firstWhere((r) => r != null);

  // 4. Return result
  return response.data;
}

// Usage
final result = await sendCommand(
  currentUserId,
  "processData",
  {"items": [1, 2, 3]},
);
print('Result: $result');
```

---

**This models package provides the foundation for type-safe, scalable data management across your entire application stack.** 🚀
