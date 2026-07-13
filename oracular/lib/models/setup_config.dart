import 'dart:io';

import '../version.dart';
import 'template_info.dart';

/// Rendering strategy for Jaspr web sites.
///
/// Determines `jaspr.yaml` mode, whether `lib/main.server.dart` is kept,
/// whether the project ships a Dockerfile for a Cloud Run service, and
/// what `firebase.json` rewrites look like after [ConfigGenerator] runs.
enum JasprRenderMode {
  /// Client-only SPA. `jaspr build` emits `build/jaspr/index.html` plus
  /// a hydration bundle. No server runtime; hosted as static.
  csr,

  /// Static pre-render at build time. `jaspr build` runs every page once
  /// through `main.server.dart` to emit per-route HTML files, then ships
  /// them as static. SEO-friendly. No Cloud Run.
  ssg,

  /// Server-rendered at request time. `jaspr build` emits a Dart
  /// entrypoint; Oracular wraps it in a Docker image and deploys to
  /// Cloud Run. Firebase Hosting fronts the service via rewrites.
  ssr,

  /// Mix of [ssg] and [ssr] — some routes are statically pre-rendered
  /// at build time, others are rendered at request time on Cloud Run.
  /// Firebase Hosting rewrites only the dynamic prefixes to Cloud Run.
  hybrid,

  /// Jaspr static host with a Flutter web app embedded at
  /// [SetupConfig.embeddedFlutterMount]. Reserved for the
  /// `arcaneJasprFlutterEmbed` template; not applicable to other Jaspr
  /// templates.
  embed,
}

/// Extension helpers for [JasprRenderMode].
extension JasprRenderModeExtension on JasprRenderMode {
  /// Short display label (e.g. `CSR`, `SSG`).
  String get displayName {
    switch (this) {
      case JasprRenderMode.csr:
        return 'CSR';
      case JasprRenderMode.ssg:
        return 'SSG';
      case JasprRenderMode.ssr:
        return 'SSR';
      case JasprRenderMode.hybrid:
        return 'Hybrid';
      case JasprRenderMode.embed:
        return 'Embed';
    }
  }

  /// One-line description shown in wizard menus and generated docs.
  String get description {
    switch (this) {
      case JasprRenderMode.csr:
        return 'Client-only SPA, hosted as static; fastest to build.';
      case JasprRenderMode.ssg:
        return 'Static pre-render at build time, SEO-friendly, hosted as static.';
      case JasprRenderMode.ssr:
        return 'Server-rendered at request time, deploys to Cloud Run.';
      case JasprRenderMode.hybrid:
        return 'Mix of static + SSR routes, deploys to Cloud Run + Hosting.';
      case JasprRenderMode.embed:
        return 'Jaspr static site with a Flutter web app embedded at /app.';
    }
  }

  /// Value used in the `jaspr.yaml` `mode:` field.
  ///
  /// Both [ssg] and the host side of [embed] use `static` because the
  /// Jaspr CLI itself does the prerender pass via `main.server.dart`.
  /// [ssr] and [hybrid] use `server` because the binary serves requests
  /// at runtime.
  String get jasprYamlMode {
    switch (this) {
      case JasprRenderMode.csr:
        return 'client';
      case JasprRenderMode.ssg:
      case JasprRenderMode.embed:
        return 'static';
      case JasprRenderMode.ssr:
      case JasprRenderMode.hybrid:
        return 'server';
    }
  }

  /// True for modes that produce a Cloud Run service (Dart binary) in
  /// addition to whatever ends up on Firebase Hosting.
  bool get requiresCloudRun {
    return this == JasprRenderMode.ssr || this == JasprRenderMode.hybrid;
  }

  /// True for modes that emit a `main.server.dart` entrypoint that runs
  /// at build time (SSG / Embed prerender) or at runtime (SSR / Hybrid).
  bool get needsServerEntrypoint {
    return this != JasprRenderMode.csr;
  }

  /// Parse a render mode from CLI string. Accepts both enum names
  /// (`csr`, `ssr`, ...) and a couple of common aliases (`static`,
  /// `client`, `server`).
  static JasprRenderMode? parse(String? value) {
    if (value == null) return null;
    final String lower = value.trim().toLowerCase();
    if (lower.isEmpty) return null;
    switch (lower) {
      case 'csr':
      case 'client':
        return JasprRenderMode.csr;
      case 'ssg':
      case 'static':
        return JasprRenderMode.ssg;
      case 'ssr':
      case 'server':
        return JasprRenderMode.ssr;
      case 'hybrid':
      case 'mixed':
        return JasprRenderMode.hybrid;
      case 'embed':
      case 'flutter-embed':
      case 'flutter_embed':
        return JasprRenderMode.embed;
    }
    return null;
  }
}

/// Configuration for project setup
class SetupConfig {
  /// App name in snake_case (e.g., my_app)
  final String appName;

  /// Organization domain in reverse notation (e.g., com.example)
  final String orgDomain;

  /// Base class name in PascalCase (e.g., MyApp)
  final String baseClassName;

  /// Selected template
  final TemplateType template;

  /// Oracular/template generation version that created this config.
  final String templateVersion;

  /// Output directory for created projects
  final String outputDir;

  /// Whether to create models package
  final bool createModels;

  /// Whether to create server app
  final bool createServer;

  /// Whether to enable Firebase
  final bool useFirebase;

  /// Firebase project ID (required if useFirebase is true)
  final String? firebaseProjectId;

  /// Whether to setup Cloud Run for server
  final bool setupCloudRun;

  /// Path to service account key file
  final String? serviceAccountKeyPath;

  /// Selected platforms for Flutter app
  final List<String> platforms;

  // ── End-to-end Firebase setup options (added in v3.2.0) ──────────────────

  /// Whether the orchestrator should deploy the release hosting site.
  /// Only meaningful when [TemplateTypeExtension.isFlutterApp] with web
  /// platform OR [TemplateTypeExtension.isJasprApp] is true.
  final bool deployHostingRelease;

  /// Whether the orchestrator should create and deploy the `<project>-beta`
  /// hosting site. Only meaningful when web hosting is supported.
  final bool deployHostingBeta;

  /// Region used to bootstrap the default Firestore database when missing.
  /// Common values: `nam5` (multi-region US), `eur3` (multi-region EU),
  /// `us-central1`, `europe-west1`. Defaults to `nam5`.
  final String firestoreRegion;

  /// Whether the orchestrator should ensure the default Firestore database
  /// exists (create on `NOT_FOUND`).
  final bool initializeFirestore;

  /// Whether the orchestrator should ensure the default Storage bucket
  /// exists.
  final bool initializeStorage;

  /// Whether the orchestrator should enable / hand off Email + Password auth.
  final bool enableEmailAuth;

  /// Whether the orchestrator should enable / hand off Google sign-in.
  /// Always falls back to a console hand-off because the OAuth client cannot
  /// be fully scripted.
  final bool enableGoogleAuth;

  /// Whether the orchestrator should hard-require a Blaze (pay-as-you-go)
  /// plan before attempting Cloud Run / cleanup setup. Defaults to true when
  /// [createServer] or [setupCloudRun] is true.
  final bool requireBlaze;

  /// Whether the orchestrator should install Artifact Registry cleanup
  /// policies for the server image. Defaults to true when [setupCloudRun] is
  /// true.
  final bool setupArtifactCleanup;

  /// Number of most-recent Artifact Registry image versions the cleanup
  /// policy should keep. Defaults to 5.
  final int artifactKeepRecent;

  /// Age (days) after which non-keep-listed Artifact Registry image versions
  /// are deleted. Defaults to 30.
  final int artifactDeleteOlderDays;

  /// Number of most-recent Cloud Run revisions to keep. Older revisions that
  /// are not currently serving traffic are pruned. Defaults to 3.
  final int cloudRunKeepRevisions;

  // ── Jaspr render-mode options (added in 2026-05-10) ─────────────────────

  /// How the Jaspr site renders. Only meaningful when
  /// [TemplateTypeExtension.isJasprApp] is true.
  ///
  /// Defaults are template-driven (see [SetupConfig.new]):
  ///   * `arcaneJasprDocs` → [JasprRenderMode.ssg]
  ///   * `arcaneJasprFlutterEmbed` → [JasprRenderMode.embed]
  ///   * `arcaneJaspr` (and everything else) → [JasprRenderMode.csr]
  final JasprRenderMode jasprRenderMode;

  /// Cloud Run service name for the Jaspr server binary (SSR / hybrid).
  /// Defaults to `<appName>-web` so it never collides with the
  /// arcane_server service (`<appName>-server`).
  final String? jasprServerServiceName;

  /// Mount path for the embedded Flutter web app inside the Jaspr host
  /// site. Only meaningful when [template] is
  /// [TemplateType.arcaneJasprFlutterEmbed]. Defaults to `/app`.
  final String embeddedFlutterMount;

  /// URL prefixes that route to the Jaspr Cloud Run service instead of
  /// to static hosting. Only meaningful in hybrid mode. Defaults to
  /// `['/api', '/auth']` so the user has a sensible non-empty starting
  /// point; the firebase.json generator emits a `run:<service>` rewrite
  /// for every prefix listed here.
  final List<String> hybridDynamicPrefixes;

  SetupConfig({
    required this.appName,
    required this.orgDomain,
    required this.baseClassName,
    required this.template,
    required this.outputDir,
    String? templateVersion,
    this.createModels = false,
    this.createServer = false,
    this.useFirebase = false,
    this.firebaseProjectId,
    this.setupCloudRun = false,
    this.serviceAccountKeyPath,
    this.platforms = const [
      'android',
      'ios',
      'web',
      'linux',
      'macos',
      'windows',
    ],
    bool? deployHostingRelease,
    bool? deployHostingBeta,
    this.firestoreRegion = 'nam5',
    this.initializeFirestore = true,
    this.initializeStorage = true,
    this.enableEmailAuth = true,
    this.enableGoogleAuth = true,
    bool? requireBlaze,
    bool? setupArtifactCleanup,
    this.artifactKeepRecent = 5,
    this.artifactDeleteOlderDays = 30,
    this.cloudRunKeepRevisions = 3,
    JasprRenderMode? jasprRenderMode,
    this.jasprServerServiceName,
    this.embeddedFlutterMount = '/app',
    List<String>? hybridDynamicPrefixes,
  }) : templateVersion = templateVersion ?? oracularVersion,
       deployHostingRelease =
           deployHostingRelease ??
           _defaultSupportsWebHosting(template, platforms),
       deployHostingBeta =
           deployHostingBeta ?? _defaultSupportsWebHosting(template, platforms),
       requireBlaze = requireBlaze ?? (createServer || setupCloudRun),
       setupArtifactCleanup = setupArtifactCleanup ?? setupCloudRun,
       jasprRenderMode = jasprRenderMode ?? _defaultJasprRenderMode(template),
       hybridDynamicPrefixes =
           hybridDynamicPrefixes ?? const <String>['/api', '/auth'];

  /// Create config with defaults
  factory SetupConfig.defaults() {
    return SetupConfig(
      appName: 'my_app',
      orgDomain: 'com.example',
      baseClassName: 'MyApp',
      template: TemplateType.arcaneTemplate,
      outputDir: Directory.current.path,
      templateVersion: oracularVersion,
    );
  }

  /// Create a copy with updated values
  SetupConfig copyWith({
    String? appName,
    String? orgDomain,
    String? baseClassName,
    TemplateType? template,
    String? templateVersion,
    String? outputDir,
    bool? createModels,
    bool? createServer,
    bool? useFirebase,
    String? firebaseProjectId,
    bool? setupCloudRun,
    String? serviceAccountKeyPath,
    List<String>? platforms,
    bool? deployHostingRelease,
    bool? deployHostingBeta,
    String? firestoreRegion,
    bool? initializeFirestore,
    bool? initializeStorage,
    bool? enableEmailAuth,
    bool? enableGoogleAuth,
    bool? requireBlaze,
    bool? setupArtifactCleanup,
    int? artifactKeepRecent,
    int? artifactDeleteOlderDays,
    int? cloudRunKeepRevisions,
    JasprRenderMode? jasprRenderMode,
    String? jasprServerServiceName,
    String? embeddedFlutterMount,
    List<String>? hybridDynamicPrefixes,
  }) {
    return SetupConfig(
      appName: appName ?? this.appName,
      orgDomain: orgDomain ?? this.orgDomain,
      baseClassName: baseClassName ?? this.baseClassName,
      template: template ?? this.template,
      templateVersion: templateVersion ?? this.templateVersion,
      outputDir: outputDir ?? this.outputDir,
      createModels: createModels ?? this.createModels,
      createServer: createServer ?? this.createServer,
      useFirebase: useFirebase ?? this.useFirebase,
      firebaseProjectId: firebaseProjectId ?? this.firebaseProjectId,
      setupCloudRun: setupCloudRun ?? this.setupCloudRun,
      serviceAccountKeyPath:
          serviceAccountKeyPath ?? this.serviceAccountKeyPath,
      platforms: platforms ?? this.platforms,
      deployHostingRelease: deployHostingRelease ?? this.deployHostingRelease,
      deployHostingBeta: deployHostingBeta ?? this.deployHostingBeta,
      firestoreRegion: firestoreRegion ?? this.firestoreRegion,
      initializeFirestore: initializeFirestore ?? this.initializeFirestore,
      initializeStorage: initializeStorage ?? this.initializeStorage,
      enableEmailAuth: enableEmailAuth ?? this.enableEmailAuth,
      enableGoogleAuth: enableGoogleAuth ?? this.enableGoogleAuth,
      requireBlaze: requireBlaze ?? this.requireBlaze,
      setupArtifactCleanup: setupArtifactCleanup ?? this.setupArtifactCleanup,
      artifactKeepRecent: artifactKeepRecent ?? this.artifactKeepRecent,
      artifactDeleteOlderDays:
          artifactDeleteOlderDays ?? this.artifactDeleteOlderDays,
      cloudRunKeepRevisions:
          cloudRunKeepRevisions ?? this.cloudRunKeepRevisions,
      jasprRenderMode: jasprRenderMode ?? this.jasprRenderMode,
      jasprServerServiceName:
          jasprServerServiceName ?? this.jasprServerServiceName,
      embeddedFlutterMount: embeddedFlutterMount ?? this.embeddedFlutterMount,
      hybridDynamicPrefixes:
          hybridDynamicPrefixes ?? this.hybridDynamicPrefixes,
    );
  }

  /// Get the app name for the models package
  String get modelsPackageName => '${appName}_models';

  /// Get the app name for the server
  String get serverPackageName => '${appName}_server';

  /// Get the app name for the web package (Jaspr)
  String get webPackageName => '${appName}_web';

  /// Get the server class name (PascalCase + Server)
  String get serverClassName => '${baseClassName}Server';

  /// Get the runner class name (PascalCase + Runner)
  String get runnerClassName => '${baseClassName}Runner';

  /// Get the web class name (PascalCase + Web)
  String get webClassName => '${baseClassName}Web';

  /// Package name for the embedded Flutter web app (only meaningful
  /// when [template] is [TemplateType.arcaneJasprFlutterEmbed]).
  String get embeddedFlutterPackageName => '${appName}_app';

  /// Class name for the embedded Flutter web app.
  String get embeddedFlutterClassName => '${baseClassName}App';

  /// Effective Cloud Run service name for the Jaspr server binary.
  /// Falls back to `<appName>-web` when [jasprServerServiceName] is null.
  /// Dashes-not-underscores because Cloud Run rejects underscores in
  /// service names.
  String get effectiveJasprServerServiceName {
    final String raw = jasprServerServiceName ?? '${appName}_web';
    return raw.replaceAll('_', '-');
  }

  /// True when this configuration produces a Cloud Run service for the
  /// Jaspr binary (SSR / hybrid). Independent of the arcane_server
  /// template; both can be true at once.
  bool get hasJasprServer {
    return template.isJasprApp && jasprRenderMode.requiresCloudRun;
  }

  /// True when this configuration produces a Flutter web app that ships
  /// inside the Jaspr build output (the `embed` mode of the
  /// arcaneJasprFlutterEmbed template).
  bool get hasEmbeddedFlutter {
    return template == TemplateType.arcaneJasprFlutterEmbed ||
        jasprRenderMode == JasprRenderMode.embed;
  }

  /// Whether this configuration produces a deployable web build for either
  /// Flutter web or any Jaspr template (static or client). Used by the
  /// orchestrator to gate hosting / build / deploy steps.
  bool get supportsWebHosting {
    return template.isJasprApp ||
        (template.isFlutterApp && platforms.contains('web'));
  }

  /// Save configuration to file
  Future<void> saveToFile(String path) async {
    final String content =
        '''
# Oracular Setup Configuration
# Generated: ${DateTime.now().toIso8601String()}

APP_NAME=$appName
ORG_DOMAIN=$orgDomain
BASE_CLASS_NAME=$baseClassName
TEMPLATE_NAME=${template.name}
TEMPLATE_VERSION=$templateVersion
OUTPUT_DIR=$outputDir
PLATFORMS=${platforms.join(',')}
CREATE_MODELS=${createModels ? 'yes' : 'no'}
CREATE_SERVER=${createServer ? 'yes' : 'no'}
USE_FIREBASE=${useFirebase ? 'yes' : 'no'}
${firebaseProjectId != null ? 'FIREBASE_PROJECT_ID=$firebaseProjectId' : '# FIREBASE_PROJECT_ID='}
SETUP_CLOUD_RUN=${setupCloudRun ? 'yes' : 'no'}
${serviceAccountKeyPath != null ? 'SERVICE_ACCOUNT_KEY=$serviceAccountKeyPath' : '# SERVICE_ACCOUNT_KEY='}
DEPLOY_HOSTING_RELEASE=${deployHostingRelease ? 'yes' : 'no'}
DEPLOY_HOSTING_BETA=${deployHostingBeta ? 'yes' : 'no'}
FIRESTORE_REGION=$firestoreRegion
INITIALIZE_FIRESTORE=${initializeFirestore ? 'yes' : 'no'}
INITIALIZE_STORAGE=${initializeStorage ? 'yes' : 'no'}
ENABLE_EMAIL_AUTH=${enableEmailAuth ? 'yes' : 'no'}
ENABLE_GOOGLE_AUTH=${enableGoogleAuth ? 'yes' : 'no'}
REQUIRE_BLAZE=${requireBlaze ? 'yes' : 'no'}
SETUP_ARTIFACT_CLEANUP=${setupArtifactCleanup ? 'yes' : 'no'}
ARTIFACT_KEEP_RECENT=$artifactKeepRecent
ARTIFACT_DELETE_OLDER_DAYS=$artifactDeleteOlderDays
CLOUD_RUN_KEEP_REVISIONS=$cloudRunKeepRevisions
JASPR_RENDER_MODE=${jasprRenderMode.name}
${jasprServerServiceName != null ? 'JASPR_SERVER_SERVICE_NAME=$jasprServerServiceName' : '# JASPR_SERVER_SERVICE_NAME='}
EMBEDDED_FLUTTER_MOUNT=$embeddedFlutterMount
HYBRID_DYNAMIC_PREFIXES=${hybridDynamicPrefixes.join(',')}
''';

    await File(path).writeAsString(content);
  }

  /// Load configuration from file
  static Future<SetupConfig?> loadFromFile(String path) async {
    final File file = File(path);
    if (!file.existsSync()) return null;

    final String content = await file.readAsString();
    final Map<String, String> values = <String, String>{};

    for (final String line in content.split('\n')) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final List<String> parts = trimmed.split('=');
      if (parts.length >= 2) {
        values[parts[0].trim()] = parts.sublist(1).join('=').trim();
      }
    }

    final String templateName = values['TEMPLATE_NAME'] ?? 'arcane_template';
    final TemplateType template = TemplateType.values.firstWhere(
      (TemplateType t) => t.name == templateName,
      orElse: () => TemplateType.arcaneTemplate,
    );

    final List<String> platforms = _parsePlatforms(
      values['PLATFORMS'],
      template,
    );

    return SetupConfig(
      appName: values['APP_NAME'] ?? 'my_app',
      orgDomain: values['ORG_DOMAIN'] ?? 'com.example',
      baseClassName: values['BASE_CLASS_NAME'] ?? 'MyApp',
      template: template,
      templateVersion: values['TEMPLATE_VERSION'],
      outputDir: values['OUTPUT_DIR'] ?? Directory.current.path,
      platforms: platforms,
      createModels: _parseBool(values['CREATE_MODELS']),
      createServer: _parseBool(values['CREATE_SERVER']),
      useFirebase: _parseBool(values['USE_FIREBASE']),
      firebaseProjectId: values['FIREBASE_PROJECT_ID'],
      setupCloudRun: _parseBool(values['SETUP_CLOUD_RUN']),
      serviceAccountKeyPath: values['SERVICE_ACCOUNT_KEY'],
      deployHostingRelease: _parseOptionalBool(
        values['DEPLOY_HOSTING_RELEASE'],
      ),
      deployHostingBeta: _parseOptionalBool(values['DEPLOY_HOSTING_BETA']),
      firestoreRegion: values['FIRESTORE_REGION'] ?? 'nam5',
      initializeFirestore: _parseBool(
        values['INITIALIZE_FIRESTORE'],
        defaultValue: true,
      ),
      initializeStorage: _parseBool(
        values['INITIALIZE_STORAGE'],
        defaultValue: true,
      ),
      enableEmailAuth: _parseBool(
        values['ENABLE_EMAIL_AUTH'],
        defaultValue: true,
      ),
      enableGoogleAuth: _parseBool(
        values['ENABLE_GOOGLE_AUTH'],
        defaultValue: true,
      ),
      requireBlaze: _parseOptionalBool(values['REQUIRE_BLAZE']),
      setupArtifactCleanup: _parseOptionalBool(
        values['SETUP_ARTIFACT_CLEANUP'],
      ),
      artifactKeepRecent: _parseInt(
        values['ARTIFACT_KEEP_RECENT'],
        defaultValue: 5,
      ),
      artifactDeleteOlderDays: _parseInt(
        values['ARTIFACT_DELETE_OLDER_DAYS'],
        defaultValue: 30,
      ),
      cloudRunKeepRevisions: _parseInt(
        values['CLOUD_RUN_KEEP_REVISIONS'],
        defaultValue: 3,
      ),
      jasprRenderMode: JasprRenderModeExtension.parse(
        values['JASPR_RENDER_MODE'],
      ),
      jasprServerServiceName: values['JASPR_SERVER_SERVICE_NAME'],
      embeddedFlutterMount: values['EMBEDDED_FLUTTER_MOUNT'] ?? '/app',
      hybridDynamicPrefixes: _parseHybridPrefixes(
        values['HYBRID_DYNAMIC_PREFIXES'],
      ),
    );
  }

  /// Convert to YAML string for display
  String toYamlString() {
    final buffer = StringBuffer();
    buffer.writeln('app_name: $appName');
    buffer.writeln('org_domain: $orgDomain');
    buffer.writeln('base_class_name: $baseClassName');
    buffer.writeln('template: ${template.displayName}');
    buffer.writeln('template_version: $templateVersion');
    buffer.writeln('output_dir: $outputDir');
    buffer.writeln('platforms: ${platforms.join(', ')}');
    buffer.writeln('create_models: $createModels');
    buffer.writeln('create_server: $createServer');
    buffer.writeln('use_firebase: $useFirebase');
    buffer.writeln('firebase_project_id: ${firebaseProjectId ?? 'N/A'}');
    buffer.writeln('setup_cloud_run: $setupCloudRun');
    buffer.writeln('deploy_hosting_release: $deployHostingRelease');
    buffer.writeln('deploy_hosting_beta: $deployHostingBeta');
    buffer.writeln('firestore_region: $firestoreRegion');
    buffer.writeln('initialize_firestore: $initializeFirestore');
    buffer.writeln('initialize_storage: $initializeStorage');
    buffer.writeln('enable_email_auth: $enableEmailAuth');
    buffer.writeln('enable_google_auth: $enableGoogleAuth');
    buffer.writeln('require_blaze: $requireBlaze');
    buffer.writeln('setup_artifact_cleanup: $setupArtifactCleanup');
    buffer.writeln('artifact_keep_recent: $artifactKeepRecent');
    buffer.writeln('artifact_delete_older_days: $artifactDeleteOlderDays');
    buffer.writeln('cloud_run_keep_revisions: $cloudRunKeepRevisions');
    if (template.isJasprApp) {
      buffer.writeln('jaspr_render_mode: ${jasprRenderMode.name}');
      if (hasJasprServer) {
        buffer.writeln(
          'jaspr_server_service: $effectiveJasprServerServiceName',
        );
      }
      if (hasEmbeddedFlutter) {
        buffer.writeln('embedded_flutter_mount: $embeddedFlutterMount');
      }
      if (jasprRenderMode == JasprRenderMode.hybrid) {
        buffer.writeln(
          'hybrid_dynamic_prefixes: ${hybridDynamicPrefixes.join(', ')}',
        );
      }
    }
    return buffer.toString();
  }

  /// Convert to map for display
  Map<String, String> toDisplayMap() {
    return {
      'App Name': appName,
      'Organization': orgDomain,
      'Class Name': baseClassName,
      'Template': template.displayName,
      'Template Version': templateVersion,
      'Output Dir': outputDir,
      // Only show platforms for Flutter templates
      if (template.isFlutterApp) 'Platforms': platforms.join(', '),
      'Models Package': createModels ? 'Yes' : 'No',
      'Server App': createServer ? 'Yes' : 'No',
      'Firebase': useFirebase ? 'Yes' : 'No',
      if (useFirebase && firebaseProjectId != null)
        'Firebase Project': firebaseProjectId!,
      if (createServer) 'Cloud Run': setupCloudRun ? 'Yes' : 'No',
      if (useFirebase && supportsWebHosting)
        'Hosting (release)': deployHostingRelease ? 'Auto' : 'Manual',
      if (useFirebase && supportsWebHosting)
        'Hosting (beta)': deployHostingBeta ? 'Auto' : 'Manual',
      if (useFirebase) 'Firestore Region': firestoreRegion,
      if (useFirebase) 'Init Firestore': initializeFirestore ? 'Yes' : 'No',
      if (useFirebase) 'Init Storage': initializeStorage ? 'Yes' : 'No',
      if (useFirebase) 'Email Auth': enableEmailAuth ? 'Yes' : 'No',
      if (useFirebase) 'Google Auth': enableGoogleAuth ? 'Hand-off' : 'Skip',
      if (createServer || setupCloudRun)
        'Require Blaze': requireBlaze ? 'Yes' : 'No',
      if (setupCloudRun)
        'Artifact Cleanup': setupArtifactCleanup
            ? 'keep $artifactKeepRecent / delete >${artifactDeleteOlderDays}d'
            : 'No',
      if (setupCloudRun) 'Cloud Run Revisions': 'keep $cloudRunKeepRevisions',
      if (template.isJasprApp) 'Render Mode': jasprRenderMode.displayName,
      if (hasJasprServer)
        'Jaspr Cloud Run Service': effectiveJasprServerServiceName,
      if (hasEmbeddedFlutter) 'Embedded Flutter Mount': embeddedFlutterMount,
      if (jasprRenderMode == JasprRenderMode.hybrid)
        'Hybrid Dynamic Paths': hybridDynamicPrefixes.join(', '),
    };
  }

  @override
  String toString() =>
      'SetupConfig(appName: $appName, template: ${template.name})';

  static List<String> _parsePlatforms(String? value, TemplateType template) {
    if (value == null) {
      return template.supportedPlatforms;
    }

    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return <String>[];
    }

    return trimmed
        .split(',')
        .map((String platform) => platform.trim())
        .where((String platform) => platform.isNotEmpty)
        .toList();
  }

  static bool _parseBool(String? value, {bool defaultValue = false}) {
    if (value == null) {
      return defaultValue;
    }
    final String lower = value.trim().toLowerCase();
    if (lower.isEmpty) {
      return defaultValue;
    }
    return lower == 'yes' || lower == 'true' || lower == '1';
  }

  /// Parse a tri-state boolean: returns null when the key is absent so the
  /// constructor can fall back to its template-derived default.
  static bool? _parseOptionalBool(String? value) {
    if (value == null) {
      return null;
    }
    final String lower = value.trim().toLowerCase();
    if (lower.isEmpty) {
      return null;
    }
    return lower == 'yes' || lower == 'true' || lower == '1';
  }

  static int _parseInt(String? value, {required int defaultValue}) {
    if (value == null) {
      return defaultValue;
    }
    return int.tryParse(value.trim()) ?? defaultValue;
  }

  /// Default for [deployHostingRelease] / [deployHostingBeta]: true if the
  /// template can produce a deployable web build, false otherwise.
  static bool _defaultSupportsWebHosting(
    TemplateType template,
    List<String> platforms,
  ) {
    if (template.isJasprApp) {
      return true;
    }
    if (template.isFlutterApp && platforms.contains('web')) {
      return true;
    }
    return false;
  }

  /// Default [jasprRenderMode] derived from [template]. Non-Jaspr
  /// templates still get a value (`csr`) for serialization simplicity,
  /// but it's ignored everywhere thanks to `template.isJasprApp` gates.
  static JasprRenderMode _defaultJasprRenderMode(TemplateType template) {
    switch (template) {
      case TemplateType.arcaneJasprDocs:
        return JasprRenderMode.ssg;
      case TemplateType.arcaneJasprFlutterEmbed:
        return JasprRenderMode.embed;
      case TemplateType.arcaneJaspr:
      case TemplateType.arcaneTemplate:
      case TemplateType.arcaneBeamer:
      case TemplateType.arcaneDock:
      case TemplateType.arcaneCli:
        return JasprRenderMode.csr;
    }
  }

  /// Parse the comma-separated `HYBRID_DYNAMIC_PREFIXES` env value.
  /// Empty / missing falls back to the constructor default (handled by
  /// the null-coalesce in [SetupConfig.new]).
  static List<String>? _parseHybridPrefixes(String? value) {
    if (value == null) return null;
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return const <String>[];
    return trimmed
        .split(',')
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList(growable: false);
  }
}
