import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../models/setup_config.dart';

/// Service for generating configuration files
class ConfigGenerator {
  final SetupConfig config;

  ConfigGenerator(this.config);

  /// Generate firebase.json
  Future<void> generateFirebaseJson() async {
    if (config.firebaseProjectId == null) {
      warn('Firebase project ID not set, skipping firebase.json');
      return;
    }

    info('Generating firebase.json...');

    final String content =
        '''
{
  "firestore": {
    "rules": "config/firestore.rules",
    "indexes": "config/firestore.indexes.json"
  },
  "storage": {
    "rules": "config/storage.rules"
  },
  "hosting": [
    {
      "target": "release",
      "public": "${config.appName}/build/web",
      "ignore": [
        "firebase.json",
        "**/.*",
        "**/node_modules/**"
      ],
      "rewrites": [
        {
          "source": "**",
          "destination": "/index.html"
        }
      ]
    },
    {
      "target": "beta",
      "public": "${config.appName}/build/web",
      "ignore": [
        "firebase.json",
        "**/.*",
        "**/node_modules/**"
      ],
      "rewrites": [
        {
          "source": "**",
          "destination": "/index.html"
        }
      ]
    }
  ]
}
''';

    final File file = File(p.join(config.outputDir, 'firebase.json'));
    await file.writeAsString(content);
    success('Generated: firebase.json');
  }

  /// Generate .firebaserc
  Future<void> generateFirebaseRc() async {
    if (config.firebaseProjectId == null) {
      warn('Firebase project ID not set, skipping .firebaserc');
      return;
    }

    info('Generating .firebaserc...');

    final String content =
        '''
{
  "projects": {
    "default": "${config.firebaseProjectId}"
  },
  "targets": {
    "${config.firebaseProjectId}": {
      "hosting": {
        "release": [
          "${config.firebaseProjectId}"
        ],
        "beta": [
          "${config.firebaseProjectId}-beta"
        ]
      }
    }
  },
  "etags": {}
}
''';

    final File file = File(p.join(config.outputDir, '.firebaserc'));
    await file.writeAsString(content);
    success('Generated: .firebaserc');
  }

  /// Generate Firestore rules
  Future<void> generateFirestoreRules() async {
    info('Generating Firestore rules...');

    final String content = '''
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper functions
    function isAuth() {
      return request.auth != null;
    }

    function getCapabilities() {
      return get(/databases/\$(database)/documents/user/\$(request.auth.uid)/data/capabilities).data;
    }

    function isAdmin() {
      return isAuth() && getCapabilities().admin == true;
    }

    function isUser(id) {
      return isAuth() && request.auth.uid == id;
    }

    // Default deny all
    match /{document=**} {
      allow read, write: if false;
    }

    // Commands collection (users can write, server can read)
    match /commands/{command} {
      allow create: if isAuth() && request.resource.data.uid == request.auth.uid;
      allow read, update, delete: if isAuth() && resource.data.uid == request.auth.uid;
    }

    // User documents
    match /user/{userId} {
      allow read: if isUser(userId) || isAdmin();
      allow write: if isUser(userId);

      // User settings subcollection
      match /data/settings {
        allow read, write: if isUser(userId);
      }

      // User capabilities subcollection (admin only write)
      match /data/capabilities {
        allow read: if isUser(userId);
        allow write: if isAdmin();
      }
    }
  }
}
''';

    final Directory configDir = Directory(p.join(config.outputDir, 'config'));
    if (!configDir.existsSync()) {
      await configDir.create(recursive: true);
    }

    final File file = File(p.join(configDir.path, 'firestore.rules'));
    await file.writeAsString(content);
    success('Generated: config/firestore.rules');
  }

  /// Generate Firestore indexes
  Future<void> generateFirestoreIndexes() async {
    info('Generating Firestore indexes...');

    final String content = '''
{
  "indexes": [],
  "fieldOverrides": []
}
''';

    final Directory configDir2 = Directory(p.join(config.outputDir, 'config'));
    if (!configDir2.existsSync()) {
      await configDir2.create(recursive: true);
    }

    final File file2 = File(p.join(configDir2.path, 'firestore.indexes.json'));
    await file2.writeAsString(content);
    success('Generated: config/firestore.indexes.json');
  }

  /// Generate Storage rules
  Future<void> generateStorageRules() async {
    info('Generating Storage rules...');

    final String content = '''
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Default: deny all access
    match /{allPaths=**} {
      allow read, write: if false;
    }

    // User-specific storage
    match /users/{userId}/{allPaths=**} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null && request.auth.uid == userId
                   && request.resource.size < 10 * 1024 * 1024; // 10MB max
    }

    // Public assets (read-only)
    match /public/{allPaths=**} {
      allow read: if true;
      allow write: if false;
    }
  }
}
''';

    final Directory configDir3 = Directory(p.join(config.outputDir, 'config'));
    if (!configDir3.existsSync()) {
      await configDir3.create(recursive: true);
    }

    final File file3 = File(p.join(configDir3.path, 'storage.rules'));
    await file3.writeAsString(content);
    success('Generated: config/storage.rules');
  }

  /// Generate all Firebase configuration files
  Future<void> generateAll() async {
    info('Generating Firebase configuration files...');

    await generateFirebaseJson();
    await generateFirebaseRc();
    await generateFirestoreRules();
    await generateFirestoreIndexes();
    await generateStorageRules();

    success('All configuration files generated');
  }
}
