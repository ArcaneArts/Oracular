import 'dart:io';

String get _safeCurrentDir {
  try {
    return Directory.current.path;
  } catch (_) {
    return '/';
  }
}

/// Template types available for project creation
enum TemplateType {
  arcaneTemplate(
    number: 1,
    displayName: 'Basic Arcane',
    description: 'Multi-platform Flutter app with Arcane UI',
    directoryName: 'arcane_app',
    platforms: ['android', 'ios', 'web', 'linux', 'macos', 'windows'],
    isFlutter: true,
  ),
  arcaneBeamer(
    number: 2,
    displayName: 'Beamer Navigation',
    description: 'Multi-platform app with Beamer declarative routing',
    directoryName: 'arcane_beamer_app',
    platforms: ['android', 'ios', 'web', 'linux', 'macos', 'windows'],
    isFlutter: true,
  ),
  arcaneDock(
    number: 3,
    displayName: 'Desktop Tray App',
    description: 'System tray/menu bar application for desktop',
    directoryName: 'arcane_dock_app',
    platforms: ['linux', 'macos', 'windows'],
    isFlutter: true,
  ),
  arcaneCli(
    number: 4,
    displayName: 'Dart CLI',
    description: 'Command-line interface application',
    directoryName: 'arcane_cli_app',
    platforms: [],
    isFlutter: false,
  );

  final int number;
  final String displayName;
  final String description;
  final String directoryName;
  final List<String> platforms;
  final bool isFlutter;

  const TemplateType({
    required this.number,
    required this.displayName,
    required this.description,
    required this.directoryName,
    required this.platforms,
    required this.isFlutter,
  });

  bool get isDartCli => !isFlutter;

  /// Whether this template allows platform selection
  bool get allowsPlatformSelection => isFlutter && this != arcaneDock;
}

/// Configuration for project creation
class WizardConfig {
  /// App name in snake_case
  String appName;

  /// Organization domain in reverse notation (e.g., com.example)
  String orgDomain;

  /// Base class name in PascalCase
  String baseClassName;

  /// Selected template
  TemplateType template;

  /// Output directory
  String outputDir;

  /// Selected platforms for Flutter app
  List<String> selectedPlatforms;

  /// Whether to create models package
  bool createModels;

  /// Whether to create server app
  bool createServer;

  /// Whether to enable Firebase
  bool useFirebase;

  /// Firebase project ID
  String? firebaseProjectId;

  /// Whether to setup Cloud Run
  bool setupCloudRun;

  WizardConfig({
    this.appName = 'my_app',
    this.orgDomain = 'com.example',
    this.baseClassName = 'MyApp',
    this.template = TemplateType.arcaneTemplate,
    String? outputDir,
    List<String>? selectedPlatforms,
    this.createModels = false,
    this.createServer = false,
    this.useFirebase = false,
    this.firebaseProjectId,
    this.setupCloudRun = false,
  })  : outputDir = outputDir ?? _safeCurrentDir,
        selectedPlatforms =
            selectedPlatforms ?? TemplateType.arcaneTemplate.platforms.toList();

  /// Get models package name
  String get modelsPackageName => '${appName}_models';

  /// Get server package name
  String get serverPackageName => '${appName}_server';

  /// Update selected platforms when template changes
  void updateTemplate(TemplateType newTemplate) {
    template = newTemplate;
    // Reset to all available platforms for the new template
    selectedPlatforms = newTemplate.platforms.toList();
  }

  /// Toggle a platform selection
  void togglePlatform(String platform) {
    if (selectedPlatforms.contains(platform)) {
      selectedPlatforms.remove(platform);
    } else {
      selectedPlatforms.add(platform);
    }
  }

  /// Check if a platform is selected
  bool isPlatformSelected(String platform) {
    return selectedPlatforms.contains(platform);
  }

  /// Create a copy with updated values
  WizardConfig copyWith({
    String? appName,
    String? orgDomain,
    String? baseClassName,
    TemplateType? template,
    String? outputDir,
    List<String>? selectedPlatforms,
    bool? createModels,
    bool? createServer,
    bool? useFirebase,
    String? firebaseProjectId,
    bool? setupCloudRun,
  }) {
    return WizardConfig(
      appName: appName ?? this.appName,
      orgDomain: orgDomain ?? this.orgDomain,
      baseClassName: baseClassName ?? this.baseClassName,
      template: template ?? this.template,
      outputDir: outputDir ?? this.outputDir,
      selectedPlatforms: selectedPlatforms ?? this.selectedPlatforms,
      createModels: createModels ?? this.createModels,
      createServer: createServer ?? this.createServer,
      useFirebase: useFirebase ?? this.useFirebase,
      firebaseProjectId: firebaseProjectId ?? this.firebaseProjectId,
      setupCloudRun: setupCloudRun ?? this.setupCloudRun,
    );
  }

  /// Convert to map for display
  Map<String, String> toDisplayMap() {
    return {
      'App Name': appName,
      'Organization': orgDomain,
      'Class Name': baseClassName,
      'Template': template.displayName,
      'Output Directory': outputDir,
      'Platforms': template.platforms.isEmpty
          ? 'Dart CLI (no Flutter)'
          : selectedPlatforms.join(', '),
      'Models Package': createModels ? 'Yes' : 'No',
      'Server App': createServer ? 'Yes' : 'No',
      'Firebase': useFirebase ? 'Yes' : 'No',
      if (useFirebase &&
          firebaseProjectId != null &&
          firebaseProjectId!.isNotEmpty)
        'Firebase Project': firebaseProjectId!,
      if (createServer) 'Cloud Run': setupCloudRun ? 'Yes' : 'No',
    };
  }
}

/// Validation result
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult.valid() : isValid = true, errorMessage = null;
  const ValidationResult.invalid(this.errorMessage) : isValid = false;
}

/// Validators for wizard inputs
class WizardValidators {
  static final _dartReservedWords = {
    'abstract', 'as', 'assert', 'async', 'await', 'break', 'case', 'catch',
    'class', 'const', 'continue', 'covariant', 'default', 'deferred', 'do',
    'dynamic', 'else', 'enum', 'export', 'extends', 'extension', 'external',
    'factory', 'false', 'final', 'finally', 'for', 'Function', 'get', 'hide',
    'if', 'implements', 'import', 'in', 'interface', 'is', 'late', 'library',
    'mixin', 'new', 'null', 'on', 'operator', 'part', 'required', 'rethrow',
    'return', 'set', 'show', 'static', 'super', 'switch', 'sync', 'this',
    'throw', 'true', 'try', 'typedef', 'var', 'void', 'while', 'with', 'yield',
  };

  static ValidationResult validateAppName(String name) {
    if (name.isEmpty) {
      return const ValidationResult.invalid('App name cannot be empty');
    }

    if (name.contains(' ')) {
      return const ValidationResult.invalid('App name cannot contain spaces');
    }

    if (name != name.toLowerCase()) {
      return const ValidationResult.invalid('App name must be lowercase');
    }

    if (RegExp(r'^[0-9]').hasMatch(name)) {
      return const ValidationResult.invalid(
          'App name cannot start with a number');
    }

    if (_dartReservedWords.contains(name)) {
      return ValidationResult.invalid('"$name" is a Dart reserved word');
    }

    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
      return const ValidationResult.invalid(
          'App name must use only lowercase letters, numbers, and underscores');
    }

    return const ValidationResult.valid();
  }

  static ValidationResult validateFirebaseProjectId(String id) {
    if (id.isEmpty) {
      return const ValidationResult.invalid(
          'Firebase project ID cannot be empty');
    }

    if (id.contains(' ')) {
      return const ValidationResult.invalid(
          'Firebase project ID cannot contain spaces');
    }

    if (id.length < 6) {
      return const ValidationResult.invalid(
          'Firebase project ID must be at least 6 characters');
    }

    if (id.length > 30) {
      return const ValidationResult.invalid(
          'Firebase project ID must be at most 30 characters');
    }

    if (!RegExp(r'^[a-z][a-z0-9-]*[a-z0-9]$').hasMatch(id)) {
      return const ValidationResult.invalid(
          'Firebase project ID must start with a letter, contain only lowercase letters, numbers, and hyphens');
    }

    return const ValidationResult.valid();
  }

  static ValidationResult validateOrgDomain(String domain) {
    if (domain.isEmpty) {
      return const ValidationResult.invalid(
          'Organization domain cannot be empty');
    }

    if (domain.contains(' ')) {
      return const ValidationResult.invalid(
          'Organization domain cannot contain spaces');
    }

    final parts = domain.split('.');
    if (parts.length < 2) {
      return const ValidationResult.invalid(
          'Organization domain needs at least 2 parts (e.g., com.example)');
    }

    return const ValidationResult.valid();
  }
}

/// Convert snake_case to PascalCase
String snakeToPascal(String snake) {
  return snake
      .split('_')
      .map((word) =>
          word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
      .join('');
}
