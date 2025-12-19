import 'dart:io';

import 'template_info.dart';

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

  SetupConfig({
    required this.appName,
    required this.orgDomain,
    required this.baseClassName,
    required this.template,
    required this.outputDir,
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
  });

  /// Create config with defaults
  factory SetupConfig.defaults() {
    return SetupConfig(
      appName: 'my_app',
      orgDomain: 'com.example',
      baseClassName: 'MyApp',
      template: TemplateType.arcaneTemplate,
      outputDir: Directory.current.path,
    );
  }

  /// Create a copy with updated values
  SetupConfig copyWith({
    String? appName,
    String? orgDomain,
    String? baseClassName,
    TemplateType? template,
    String? outputDir,
    bool? createModels,
    bool? createServer,
    bool? useFirebase,
    String? firebaseProjectId,
    bool? setupCloudRun,
    String? serviceAccountKeyPath,
    List<String>? platforms,
  }) {
    return SetupConfig(
      appName: appName ?? this.appName,
      orgDomain: orgDomain ?? this.orgDomain,
      baseClassName: baseClassName ?? this.baseClassName,
      template: template ?? this.template,
      outputDir: outputDir ?? this.outputDir,
      createModels: createModels ?? this.createModels,
      createServer: createServer ?? this.createServer,
      useFirebase: useFirebase ?? this.useFirebase,
      firebaseProjectId: firebaseProjectId ?? this.firebaseProjectId,
      setupCloudRun: setupCloudRun ?? this.setupCloudRun,
      serviceAccountKeyPath:
          serviceAccountKeyPath ?? this.serviceAccountKeyPath,
      platforms: platforms ?? this.platforms,
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
OUTPUT_DIR=$outputDir
PLATFORMS=${platforms.join(',')}
CREATE_MODELS=${createModels ? 'yes' : 'no'}
CREATE_SERVER=${createServer ? 'yes' : 'no'}
USE_FIREBASE=${useFirebase ? 'yes' : 'no'}
${firebaseProjectId != null ? 'FIREBASE_PROJECT_ID=$firebaseProjectId' : '# FIREBASE_PROJECT_ID='}
SETUP_CLOUD_RUN=${setupCloudRun ? 'yes' : 'no'}
${serviceAccountKeyPath != null ? 'SERVICE_ACCOUNT_KEY=$serviceAccountKeyPath' : '# SERVICE_ACCOUNT_KEY='}
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

    return SetupConfig(
      appName: values['APP_NAME'] ?? 'my_app',
      orgDomain: values['ORG_DOMAIN'] ?? 'com.example',
      baseClassName: values['BASE_CLASS_NAME'] ?? 'MyApp',
      template: template,
      outputDir: values['OUTPUT_DIR'] ?? Directory.current.path,
      platforms: (values['PLATFORMS'] ?? 'android,ios,web,linux,macos,windows')
          .split(','),
      createModels: values['CREATE_MODELS'] == 'yes',
      createServer: values['CREATE_SERVER'] == 'yes',
      useFirebase: values['USE_FIREBASE'] == 'yes',
      firebaseProjectId: values['FIREBASE_PROJECT_ID'],
      setupCloudRun: values['SETUP_CLOUD_RUN'] == 'yes',
      serviceAccountKeyPath: values['SERVICE_ACCOUNT_KEY'],
    );
  }

  /// Convert to YAML string for display
  String toYamlString() {
    final buffer = StringBuffer();
    buffer.writeln('app_name: $appName');
    buffer.writeln('org_domain: $orgDomain');
    buffer.writeln('base_class_name: $baseClassName');
    buffer.writeln('template: ${template.displayName}');
    buffer.writeln('output_dir: $outputDir');
    buffer.writeln('platforms: ${platforms.join(', ')}');
    buffer.writeln('create_models: $createModels');
    buffer.writeln('create_server: $createServer');
    buffer.writeln('use_firebase: $useFirebase');
    buffer.writeln('firebase_project_id: ${firebaseProjectId ?? 'N/A'}');
    buffer.writeln('setup_cloud_run: $setupCloudRun');
    return buffer.toString();
  }

  /// Convert to map for display
  Map<String, String> toDisplayMap() {
    return {
      'App Name': appName,
      'Organization': orgDomain,
      'Class Name': baseClassName,
      'Template': template.displayName,
      'Output Dir': outputDir,
      // Only show platforms for Flutter templates
      if (template.isFlutterApp) 'Platforms': platforms.join(', '),
      'Models Package': createModels ? 'Yes' : 'No',
      'Server App': createServer ? 'Yes' : 'No',
      'Firebase': useFirebase ? 'Yes' : 'No',
      if (useFirebase && firebaseProjectId != null)
        'Firebase Project': firebaseProjectId!,
      if (createServer) 'Cloud Run': setupCloudRun ? 'Yes' : 'No',
    };
  }

  @override
  String toString() =>
      'SetupConfig(appName: $appName, template: ${template.name})';
}
