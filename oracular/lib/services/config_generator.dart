import 'dart:convert';
import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../models/setup_config.dart';
import '../models/template_info.dart';

/// Service for generating configuration files
class ConfigGenerator {
  final SetupConfig config;

  ConfigGenerator(this.config);

  /// Default Cloud Run region for `run:` rewrites in firebase.json.
  /// Kept in sync with [JasprServerDeployer.deploy] and
  /// [ServerSetup.deployToCloudRun] so rewrites point at the actual
  /// deployed service.
  static const String _cloudRunRegion = 'us-central1';

  /// Generate firebase.json
  Future<void> generateFirebaseJson() async {
    if (config.firebaseProjectId == null) {
      warn('Firebase project ID not set, skipping firebase.json');
      return;
    }

    info('Generating firebase.json (render mode: '
        '${config.jasprRenderMode.displayName})...');

    final String hostingPublicPath = _hostingPublicPath();
    final List<Map<String, Object>> rewrites = _hostingRewrites();
    final String rewritesJson = _renderRewrites(rewrites);

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
      "public": "$hostingPublicPath",
      "ignore": [
        "firebase.json",
        "**/.*",
        "**/node_modules/**"
      ],
      "rewrites": $rewritesJson
    },
    {
      "target": "beta",
      "public": "$hostingPublicPath",
      "ignore": [
        "firebase.json",
        "**/.*",
        "**/node_modules/**"
      ],
      "rewrites": $rewritesJson
    }
  ]
}
''';

    final File file = File(p.join(config.outputDir, 'firebase.json'));
    await file.writeAsString(content);
    success('Generated: firebase.json');
  }

  /// Resolve hosting output folder for the selected template.
  ///
  /// The Jaspr CLI's output layout depends on the render mode:
  ///   * CSR / SSG / Embed → `build/jaspr/` (assets at top level)
  ///   * SSR / Hybrid      → `build/jaspr/web/` (server binary at
  ///                          `build/jaspr/app`, client bundle nested
  ///                          under `web/`)
  ///
  /// Firebase Hosting must point at the directory that contains the
  /// hydration bundle + prerendered HTML files; for SSR/Hybrid that's
  /// the nested `web/` subdir.
  String _hostingPublicPath() {
    if (config.template.isJasprApp) {
      final bool serverModeBuild = config.jasprRenderMode.requiresCloudRun;
      return serverModeBuild
          ? '${config.webPackageName}/build/jaspr/web'
          : '${config.webPackageName}/build/jaspr';
    }
    return '${config.appName}/build/web';
  }

  /// Build the hosting `rewrites` array for the current render mode.
  ///
  /// The shape is mode-driven (plan §4.7 — Render-Mode Coverage Matrix):
  ///
  ///   * CSR (Flutter web or Jaspr CSR): SPA fallback only
  ///     (`{ source: "**", destination: "/index.html" }`).
  ///   * SSG: no rewrites needed — every route is prerendered to an
  ///     HTML file on disk, so Firebase Hosting serves it directly.
  ///   * SSR: every request flows through Cloud Run
  ///     (`{ source: "**", run: { serviceId, region } }`).
  ///   * Hybrid: each prefix in [SetupConfig.hybridDynamicPrefixes]
  ///     forwards to Cloud Run; everything else falls back to the
  ///     prerendered SPA shell.
  ///   * Embed: the Flutter mount at [SetupConfig.embeddedFlutterMount]
  ///     gets its own SPA fallback so Flutter web routing works inside
  ///     `/app/**`; the rest of the site keeps the Jaspr SPA fallback.
  ///
  /// Returns an empty list for SSG so the JSON serializer emits `[]`.
  List<Map<String, Object>> _hostingRewrites() {
    // Non-Jaspr templates (Flutter web on arcane_app / arcane_beamer)
    // always get the SPA fallback. The render-mode dispatch below
    // applies only to Jaspr.
    if (!config.template.isJasprApp) {
      return <Map<String, Object>>[_spaFallback()];
    }

    switch (config.jasprRenderMode) {
      case JasprRenderMode.csr:
        return <Map<String, Object>>[_spaFallback()];

      case JasprRenderMode.ssg:
        // Pure static: no rewrites. Hosting serves the prerendered
        // `*.html` for every route. We still emit `[]` rather than
        // dropping the key so the JSON shape stays consistent.
        return const <Map<String, Object>>[];

      case JasprRenderMode.ssr:
        return <Map<String, Object>>[
          _cloudRunRewrite(source: '**'),
        ];

      case JasprRenderMode.hybrid:
        // One Cloud Run rewrite per configured dynamic prefix, then the
        // SPA fallback for everything else. Order matters: Firebase
        // Hosting evaluates rewrites top-down and stops at the first
        // match, so the prefixes MUST precede the `**` SPA catch-all.
        final List<Map<String, Object>> result = <Map<String, Object>>[];
        for (final String prefix in config.hybridDynamicPrefixes) {
          final String normalized = _normalizeDynamicPrefix(prefix);
          if (normalized.isEmpty) continue;
          result.add(_cloudRunRewrite(source: normalized));
        }
        result.add(_spaFallback());
        return result;

      case JasprRenderMode.embed:
        final String mount = _normalizedMount();
        return <Map<String, Object>>[
          // Flutter SPA: route any deep-link inside /<mount>/** through
          // the Flutter index.html so the in-app router can pick up the
          // path. Without this, hard-refreshing /app/profile would 404.
          <String, Object>{
            'source': '$mount/**',
            'destination': '$mount/index.html',
          },
          // Jaspr SPA fallback for the rest of the site.
          _spaFallback(),
        ];
    }
  }

  /// `{ "source": "**", "destination": "/index.html" }` — the standard
  /// SPA fallback used by CSR / hybrid / embed.
  Map<String, Object> _spaFallback() {
    return <String, Object>{
      'source': '**',
      'destination': '/index.html',
    };
  }

  /// `{ "source": <source>, "run": { "serviceId": ..., "region": ... } }`
  /// — Firebase Hosting → Cloud Run rewrite.
  Map<String, Object> _cloudRunRewrite({required String source}) {
    return <String, Object>{
      'source': source,
      'run': <String, Object>{
        'serviceId': config.effectiveJasprServerServiceName,
        'region': _cloudRunRegion,
      },
    };
  }

  /// Normalize a user-supplied hybrid dynamic prefix to a Firebase
  /// Hosting glob pattern.
  ///
  /// Accepts inputs like `/api`, `api`, `/api/`, `/api/**` and returns
  /// the canonical glob form (`/api/**`). An empty / whitespace-only
  /// value yields the empty string so the caller can skip it.
  static String _normalizeDynamicPrefix(String prefix) {
    String value = prefix.trim();
    if (value.isEmpty) return '';
    if (!value.startsWith('/')) value = '/$value';
    if (value.endsWith('/**')) return value;
    if (value.endsWith('/')) return '$value**';
    return '$value/**';
  }

  /// Normalize [SetupConfig.embeddedFlutterMount] to the leading-slash
  /// no-trailing-slash form expected by firebase.json globs.
  String _normalizedMount() {
    String value = config.embeddedFlutterMount.trim();
    if (value.isEmpty) value = '/app';
    if (!value.startsWith('/')) value = '/$value';
    if (value.endsWith('/')) value = value.substring(0, value.length - 1);
    return value;
  }

  /// Serialize the rewrites array as JSON, indented to align with the
  /// surrounding firebase.json template.
  String _renderRewrites(List<Map<String, Object>> rewrites) {
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    final String raw = encoder.convert(rewrites);
    // Reindent each line by 6 spaces so the array sits inside the
    // hosting target block at the right column.
    final List<String> lines = raw.split('\n');
    for (int i = 1; i < lines.length; i++) {
      lines[i] = '      ${lines[i]}';
    }
    return lines.join('\n');
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
