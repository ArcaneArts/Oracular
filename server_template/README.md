# APPNAME Server

Backend server for APPNAME built with Flutter and Shelf - provides REST API endpoints, server-side Firestore operations, and Google Cloud Storage integration.

## 📋 Overview

Production-ready Flutter server with:

- **REST API**: Shelf router with clean endpoint organization
- **Firebase Admin**: Server-side Firestore and Storage access
- **Authentication**: Signature-based request auth with timing attack protection
- **Services Layer**: Business logic separated from API endpoints
- **Docker**: Production and development containerization
- **Cloud Run**: One-command deployment to Google Cloud

## 🏗️ Structure

```
lib/
├── main.dart                  # Server entry point & routing
├── api/                       # API endpoint handlers
│   ├── user_api.dart          # User management endpoints
│   ├── settings_api.dart      # User settings endpoints
│   └── command_api.dart       # Command execution endpoints
├── service/                   # Business logic services
│   ├── user_service.dart      # User operations
│   ├── command_service.dart   # Command processing
│   └── media_service.dart     # Media/file management
└── util/                      # Utilities
    └── request_authenticator.dart  # Auth middleware

Dockerfile                     # Production container
Dockerfile-dev                 # Development container
script_deploy.sh              # Cloud Run deployment script
```

## 🚀 Quick Start

### 1. Register Models

In `lib/main.dart`, models are automatically registered:

```dart
void main() async {
  registerCrud();  // From APPNAME_models
  // Server initialization
}
```

### 2. Run Locally

```bash
# Linux (native)
flutter run -d linux

# Docker (development)
docker build -f Dockerfile-dev -t APPNAME-server-dev .
docker run -p 8080:8080 APPNAME-server-dev
```

**Server starts on:** `http://localhost:8080`

### 3. Test Endpoints

```bash
# Health check
curl http://localhost:8080/keepAlive

# Server info
curl http://localhost:8080/info

# User info (requires auth)
curl http://localhost:8080/api/user/info/USER_ID \
  -H "x-user-id: USER_ID" \
  -H "x-signature-hash: SIGNATURE"
```

## 🌐 API Endpoints

### User API (`/api/user`)

User management operations.

#### GET `/api/user/info/<userId>`

Get user information by ID.

**Headers:**
- `x-user-id: string` - Authenticated user ID
- `x-signature-hash: string` - Request signature

**Response:**
```json
{
  "userId": "user123",
  "name": "John Doe",
  "email": "john@example.com"
}
```

**Error Responses:**
- `404` - User not found
- `401` - Unauthorized
- `500` - Server error

**Example:**
```dart
Future<Response> _getUserInfo(Request request, String userId) async {
  try {
    final user = await APPNAMEServer.svcUser.getUser(userId);
    if (user == null) {
      return Response.notFound('{"error": "User not found"}');
    }

    return Response.ok(jsonEncode({
      'userId': userId,
      'name': user.name,
      'email': user.email,
    }), headers: {'Content-Type': 'application/json'});
  } catch (e) {
    return Response.internalServerError(body: '{"error": "$e"}');
  }
}
```

---

#### POST `/api/user/update/<userId>`

Update user information.

**Headers:**
- `x-user-id: string` - Authenticated user ID
- `x-signature-hash: string` - Request signature

**Body:**
```json
{
  "name": "John Doe Updated",
  "email": "john.new@example.com"
}
```

**Response:**
```json
{
  "success": true,
  "message": "User updated"
}
```

---

#### GET `/api/user/list`

List users with pagination.

**Query Parameters:**
- `limit` (optional, default: 10) - Number of users per page
- `offset` (optional, default: 0) - Pagination offset

**Response:**
```json
{
  "users": [
    {"userId": "1", "name": "User 1", "email": "user1@example.com"},
    {"userId": "2", "name": "User 2", "email": "user2@example.com"}
  ],
  "total": 2
}
```

---

### Settings API (`/api/settings`)

User settings management.

#### GET `/api/settings/<userId>`

Get user settings.

**Response:**
```json
{
  "themeMode": "dark"
}
```

---

#### POST `/api/settings/<userId>/theme`

Update user theme preference.

**Body:**
```json
{
  "themeMode": "dark"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Theme updated"
}
```

---

### Command API (`/api/command`)

Server command execution.

#### POST `/api/command/execute`

Execute a server command.

**Body:**
```json
{
  "type": "custom",
  "user": "user123",
  "data": {
    "action": "processData",
    "params": {"id": 123}
  }
}
```

**Response:**
```json
{
  "commandId": "cmd_abc123",
  "status": "processing"
}
```

---

#### GET `/api/command/status/<commandId>`

Get command execution status.

**Response:**
```json
{
  "commandId": "cmd_abc123",
  "status": "completed",
  "result": {
    "success": true,
    "data": {"processed": 5}
  }
}
```

---

### System Endpoints

#### GET `/keepAlive`

Health check endpoint for Cloud Run.

**Response:**
```json
{
  "status": "alive",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

---

#### GET `/info`

Server version and configuration info.

**Response:**
```json
{
  "name": "APPNAME Server",
  "version": "1.0.0",
  "environment": "production"
}
```

---

## 🔧 Services Layer

Services contain business logic, keeping API handlers thin.

### UserService

**Location:** `lib/service/user_service.dart`

User-related operations.

**Methods:**

```dart
// Get user by ID
Future<User?> getUser(String userId)

// Create new user
Future<void> createUser(String userId, String name, String email)

// Update user theme
Future<void> updateTheme(String userId, ThemeMode themeMode)
```

**Example:**
```dart
class UserService {
  Future<User?> getUser(String userId) async {
    try {
      return await User.crud.get(userId);
    } catch (e) {
      error("Failed to get user $userId: $e");
      return null;
    }
  }

  Future<void> updateTheme(String userId, ThemeMode themeMode) async {
    try {
      final user = await getUser(userId);
      if (user == null) throw Exception("User not found");

      final updatedSettings = UserSettings(themeMode: themeMode);
      await UserSettings.crud.set(userId, updatedSettings, parent: user);

      verbose("Updated theme for user $userId to ${themeMode.name}");
    } catch (e) {
      error("Failed to update theme for user $userId: $e");
      rethrow;
    }
  }
}
```

**Access:** `APPNAMEServer.svcUser.getUser(userId)`

---

### CommandService

**Location:** `lib/service/command_service.dart`

Server command processing.

**Methods:**

```dart
// Execute command
Future<void> executeCommand(ServerCommand command)

// Listen for incoming commands
void startCommandListener()
```

**Example:**
```dart
class CommandService {
  void startCommandListener() {
    ServerCommand.crud.collection().snapshots().listen((snapshot) {
      for (var doc in snapshot.docs) {
        final command = ServerCommand.crud.fromDoc(doc);
        executeCommand(command);
      }
    });
  }

  Future<void> executeCommand(ServerCommand command) async {
    try {
      // Process command based on type
      final result = await _processCommand(command);

      // Send response
      final response = ServerResponse(
        user: command.user,
        success: true,
        data: result,
        timestamp: DateTime.now(),
      );

      await ServerResponse.crud.set("response", response, parent: command);
    } catch (e) {
      error("Command execution failed: $e");
    }
  }
}
```

**Access:** `APPNAMEServer.svcCommand.executeCommand(command)`

---

### MediaService

**Location:** `lib/service/media_service.dart`

Google Cloud Storage file management.

**Methods:**

```dart
// Upload file
Future<String> uploadFile(String userId, List<int> bytes, String filename)

// Get file URL
Future<String?> getFileUrl(String userId, String filename)

// Delete file
Future<void> deleteFile(String userId, String filename)
```

**Example:**
```dart
class MediaService {
  late final gcs.Bucket bucket;

  void initialize(String bucketName) {
    bucket = gcs.Bucket(storage, bucketName);
  }

  Future<String> uploadFile(
    String userId,
    List<int> bytes,
    String filename,
  ) async {
    try {
      final path = 'users/$userId/$filename';
      await bucket.writeBytes(path, bytes);

      verbose("Uploaded file: $path");
      return path;
    } catch (e) {
      error("Failed to upload file: $e");
      rethrow;
    }
  }
}
```

**Access:** `APPNAMEServer.svcMedia.uploadFile(...)`

---

## 🔐 Authentication

### Request Authentication

**Location:** `lib/util/request_authenticator.dart`

Signature-based authentication with timing attack protection.

**Headers Required:**
- `x-user-id: string` - User making the request
- `x-signature-hash: string` - HMAC signature of request

**How It Works:**

1. Client creates signature:
```dart
final signature = generateSignature(userId, timestamp, secretKey);
```

2. Client sends headers:
```
x-user-id: user123
x-signature-hash: abc123...
```

3. Server validates:
```dart
final isValid = authenticator.verify(request);
if (!isValid) {
  return Response.unauthorized('Invalid signature');
}
```

**Timing Attack Protection:**

Uses constant-time comparison to prevent timing attacks:

```dart
bool _constantTimeCompare(String a, String b) {
  if (a.length != b.length) return false;

  var result = 0;
  for (var i = 0; i < a.length; i++) {
    result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }

  return result == 0;
}
```

### Special Endpoints

**Backend Key Authentication** (`/backend/*`):
- Uses `_backendKey` for internal server-to-server calls
- Header: `x-backend-key: YOUR_BACKEND_KEY`

**GCP Event Authentication** (`/event/*`):
- Uses JWT validation for Google Cloud events
- Header: `Authorization: Bearer JWT_TOKEN`

### Setting Up Auth Keys

1. **Update backend key** in `lib/util/request_authenticator.dart`:
```dart
static const String _backendKey = "your-secure-backend-key-here";
```

2. **Generate user signatures** on client:
```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

String generateSignature(String userId, String secret) {
  final key = utf8.encode(secret);
  final bytes = utf8.encode(userId + DateTime.now().toIso8601String());
  final hmac = Hmac(sha256, key);
  final digest = hmac.convert(bytes);
  return digest.toString();
}
```

---

## 🐳 Docker

### Production Dockerfile

**Multi-stage build for optimal size:**

```dockerfile
# Stage 1: Build
FROM ubuntu:24.04 AS build
# Install Flutter, build server

# Stage 2: Runtime
FROM ubuntu:24.04
# Copy only built binary
# Minimal runtime environment
```

**Features:**
- Small image size (~50MB runtime)
- Linux AMD64 platform
- Models copied into server
- Non-root user for security

### Development Dockerfile

**Hot reload and debugging:**

```dockerfile
FROM ubuntu:24.04
# Install Flutter SDK
# Mount source code as volume
# Enable debug symbols
```

**Usage:**
```bash
docker build -f Dockerfile-dev -t APPNAME-server-dev .
docker run -p 8080:8080 -v $(pwd):/app APPNAME-server-dev
```

---

## 🚢 Deployment

### Prerequisites

1. **Google Cloud Project** with:
   - Artifact Registry repository
   - Cloud Run API enabled
   - Service account with Firestore/Storage permissions

2. **Local Tools:**
   - Docker installed
   - gcloud CLI authenticated
   - Firebase service account key in `config/keys/`

### Automated Deployment

Use the provided deployment script:

```bash
./script_deploy.sh
```

**Script Steps:**
1. Copies models directory into server
2. Builds Docker image for linux/amd64
3. Tags image for Artifact Registry
4. Pushes image to Google Cloud
5. Deploys to Cloud Run with environment variables

### Manual Deployment

```bash
# 1. Copy models
cp -r ../APPNAME_models ./

# 2. Build image
docker build --platform linux/amd64 -t APPNAME-server .

# 3. Tag for registry
docker tag APPNAME-server \
  us-central1-docker.pkg.dev/PROJECT_ID/REGISTRY/APPNAME-server:latest

# 4. Push to registry
docker push us-central1-docker.pkg.dev/PROJECT_ID/REGISTRY/APPNAME-server:latest

# 5. Deploy to Cloud Run
gcloud run deploy APPNAME-server \
  --image us-central1-docker.pkg.dev/PROJECT_ID/REGISTRY/APPNAME-server:latest \
  --region us-central1 \
  --platform managed \
  --memory 1Gi \
  --cpu 1 \
  --set-env-vars GOOGLE_CLOUD_PROJECT=PROJECT_ID \
  --allow-unauthenticated
```

### Environment Variables

Set in Cloud Run:

| Variable | Value | Purpose |
|----------|-------|---------|
| `GOOGLE_CLOUD_PROJECT` | Your project ID | Firebase/GCS authentication |
| `PORT` | 8080 | Server port (auto-set by Cloud Run) |
| `ENVIRONMENT` | production | Environment flag |

### Configuration

**Update these placeholders:**

1. **`lib/main.dart`** - Bucket name:
```dart
APPNAMEServer.svcMedia.initialize("FIREBASE_PROJECT_ID.appspot.com");
```

2. **`lib/util/request_authenticator.dart`** - Backend key:
```dart
static const String _backendKey = "your-secure-key-here";
```

3. **`script_deploy.sh`** - Project settings:
```bash
PROJECT_ID="your-project-id"
REGION="us-central1"
REGISTRY="your-registry"
```

---

## ➕ Adding New Endpoints

### Step 1: Create API Class

Create `lib/api/my_api.dart`:

```dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../main.dart';

class MyAPI implements Routing {
  @override
  String get prefix => "/api/my";

  @override
  Router get router => Router()
    ..get("/hello", _hello)
    ..post("/process", _process);

  Future<Response> _hello(Request request) async {
    return Response.ok(
      jsonEncode({"message": "Hello from MyAPI"}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _process(Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    // Process data
    final result = await APPNAMEServer.svcMy.processData(data);

    return Response.ok(
      jsonEncode({"result": result}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
```

### Step 2: Register in Main

Add to `lib/main.dart`:

```dart
class APPNAMEServer implements Routing {
  // Add API property
  static late MyAPI apiMy;

  // Initialize in _startAPIs
  Future<void> _startAPIs() async {
    apiUser = UserAPI();
    apiSettings = SettingsAPI();
    apiCommand = CommandAPI();
    apiMy = MyAPI();  // Add your API
  }

  // Mount in router
  @override
  Router get router => Router()
    ..mount(apiUser.prefix, apiUser.router.call)
    ..mount(apiSettings.prefix, apiSettings.router.call)
    ..mount(apiCommand.prefix, apiCommand.router.call)
    ..mount(apiMy.prefix, apiMy.router.call)  // Mount your API
    ..get("/keepAlive", _requestGetKeepAlive)
    ..get("/info", _requestGetInfo);
}
```

### Step 3: Test

```bash
curl http://localhost:8080/api/my/hello
```

---

## ➕ Adding New Services

### Step 1: Create Service Class

Create `lib/service/my_service.dart`:

```dart
import 'package:fast_log/fast_log.dart';

class MyService {
  Future<String> processData(Map<String, dynamic> data) async {
    try {
      verbose("Processing data: $data");

      // Your business logic here
      final result = "processed";

      verbose("Data processed successfully");
      return result;
    } catch (e) {
      error("Failed to process data: $e");
      rethrow;
    }
  }
}
```

### Step 2: Register in Main

Add to `lib/main.dart`:

```dart
class APPNAMEServer implements Routing {
  // Add service property
  static late MyService svcMy;

  // Initialize in _startServices
  Future<void> _startServices() async {
    svcUser = UserService();
    svcCommand = CommandService();
    svcMedia = MediaService();
    svcMy = MyService();  // Add your service
  }
}
```

### Step 3: Use in APIs

```dart
final result = await APPNAMEServer.svcMy.processData(data);
```

---

## 📝 Logging

Uses **fast_log** package for structured logging.

### Log Levels

```dart
import 'package:fast_log/fast_log.dart';

// Verbose - detailed info
verbose("User fetched: $userId");

// Info - general info
info("Server started on port 8080");

// Warning - potential issues
warn("Deprecated endpoint used");

// Error - errors that don't crash
error("Failed to process: $e");

// Fatal - critical errors
fatal("Database connection lost");
```

### Configure Logging

In `lib/main.dart`:

```dart
void main() async {
  // Set log level
  Logger.level = LogLevel.verbose; // or info, warn, error

  // Start server
  await APPNAMEServer.start();
}
```

---

## 🧪 Testing

### Unit Tests

Test services independently:

```dart
import 'package:test/test.dart';
import 'package:APPNAME_server/service/user_service.dart';

void main() {
  group('UserService', () {
    late UserService service;

    setUp(() {
      service = UserService();
    });

    test('gets user by ID', () async {
      final user = await service.getUser('test_user');
      expect(user, isNotNull);
      expect(user?.name, 'Test User');
    });
  });
}
```

### Integration Tests

Test API endpoints:

```dart
import 'package:test/test.dart';
import 'package:shelf/shelf.dart';

void main() {
  group('User API', () {
    test('GET /api/user/info returns user', () async {
      final api = UserAPI();
      final request = Request('GET', Uri.parse('/api/user/info/user123'));

      final response = await api._getUserInfo(request, 'user123');

      expect(response.statusCode, 200);
    });
  });
}
```

---

## 🐛 Troubleshooting

### Server Won't Start

**Check port availability:**
```bash
lsof -i :8080
# Kill process if needed
kill -9 <PID>
```

**Check Firebase credentials:**
```bash
ls config/keys/service-account.json
# Should exist and be valid JSON
```

### Docker Build Fails

**Platform mismatch:**
```bash
# Always specify platform for Cloud Run
docker build --platform linux/amd64 -t server .
```

**Out of disk space:**
```bash
docker system prune -a
```

### Cloud Run Deployment Fails

**Authentication:**
```bash
gcloud auth list
gcloud config set project YOUR_PROJECT_ID
```

**Permissions:**
- Ensure service account has Firestore/Storage roles
- Check Cloud Run API is enabled
- Verify Artifact Registry exists

### Request Authentication Fails

**Check signature generation:**
- Use same secret key on client and server
- Include timestamp in signature (prevent replay attacks)
- Use HMAC SHA-256

**Debug headers:**
```dart
print('User ID: ${request.headers['x-user-id']}');
print('Signature: ${request.headers['x-signature-hash']}');
```

---

## 📚 Dependencies

| Package | Purpose |
|---------|---------|
| `shelf` | HTTP server framework |
| `shelf_router` | Request routing |
| `arcane_admin` | Firebase Admin SDK wrapper |
| `firebase_admin` | Firebase server-side access |
| `google_cloud_storage` | GCS file operations |
| `APPNAME_models` | Shared data models |
| `crypto` | Signature generation/verification |
| `fast_log` | Structured logging |
| `universal_io` | Cross-platform IO |

---

## 🔗 Related Documentation

- **[Main README](../README.md)** - Project overview
- **[Models Template](../models_template/README.md)** - Shared models guide
- **[Setup Scripts](../scripts/README.md)** - Automation tools
- **[Firebase Documentation](https://firebase.google.com/docs)** - Firebase features
- **[Cloud Run Documentation](https://cloud.google.com/run/docs)** - Deployment guide

---

## 🎯 Best Practices

### 1. Separate Concerns

Keep API handlers thin, move logic to services:

```dart
// ❌ Bad - Logic in API
Future<Response> _updateUser(Request request) async {
  final user = await User.crud.get(userId);
  // ... lots of business logic ...
}

// ✅ Good - Logic in service
Future<Response> _updateUser(Request request) async {
  await APPNAMEServer.svcUser.updateUser(userId, data);
  return Response.ok('{"success": true}');
}
```

### 2. Error Handling

Always catch and log errors:

```dart
try {
  final result = await riskyOperation();
  return Response.ok(jsonEncode(result));
} catch (e) {
  error("Operation failed: $e");
  return Response.internalServerError(
    body: '{"error": "Operation failed"}',
  );
}
```

### 3. Input Validation

Validate all input data:

```dart
Future<Response> _createUser(Request request) async {
  final body = await request.readAsString();
  final data = jsonDecode(body) as Map<String, dynamic>;

  // Validate required fields
  if (!data.containsKey('name') || !data.containsKey('email')) {
    return Response.badRequest(
      body: '{"error": "Missing required fields"}',
    );
  }

  // Validate email format
  if (!data['email'].contains('@')) {
    return Response.badRequest(
      body: '{"error": "Invalid email"}',
    );
  }

  // Process valid data
  await APPNAMEServer.svcUser.createUser(data);
  return Response.ok('{"success": true}');
}
```

### 4. Use Middleware

Add common functionality via middleware:

```dart
// CORS middleware
Handler _cors() {
  return createMiddleware(
    requestHandler: (request) {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      return null;
    },
    responseHandler: (response) {
      return response.change(headers: _corsHeaders);
    },
  );
}
```

### 5. Secure Sensitive Data

Never log sensitive information:

```dart
// ❌ Bad
verbose("User password: ${data['password']}");

// ✅ Good
verbose("User authenticated: $userId");
```

---

**This server template provides a production-ready foundation for your Flutter backend!** 🚀

Deploy to Cloud Run in minutes, scale automatically, and focus on building features!
