/// Input validation utilities for Oracular CLI

/// Validation result with optional error message
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult.valid() : isValid = true, errorMessage = null;
  const ValidationResult.invalid(this.errorMessage) : isValid = false;

  @override
  String toString() => isValid ? 'Valid' : 'Invalid: $errorMessage';
}

/// Validate that a string is not empty
ValidationResult validateNotEmpty(String value, String fieldName) {
  if (value.trim().isEmpty) {
    return ValidationResult.invalid('$fieldName cannot be empty');
  }
  return const ValidationResult.valid();
}

/// Validate app name (snake_case, no spaces, lowercase)
ValidationResult validateAppName(String name) {
  if (name.isEmpty) {
    return const ValidationResult.invalid('App name cannot be empty');
  }

  if (name.contains(' ')) {
    return const ValidationResult.invalid('App name cannot contain spaces');
  }

  if (name != name.toLowerCase()) {
    return const ValidationResult.invalid('App name must be lowercase');
  }

  // Check for valid snake_case pattern
  final RegExp validPattern = RegExp(r'^[a-z][a-z0-9_]*$');
  if (!validPattern.hasMatch(name)) {
    return const ValidationResult.invalid(
      'App name must start with a letter and contain only lowercase letters, numbers, and underscores',
    );
  }

  // Dart reserved words
  const List<String> reservedWords = <String>[
    'abstract',
    'as',
    'assert',
    'async',
    'await',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'covariant',
    'default',
    'deferred',
    'do',
    'dynamic',
    'else',
    'enum',
    'export',
    'extends',
    'extension',
    'external',
    'factory',
    'false',
    'final',
    'finally',
    'for',
    'function',
    'get',
    'hide',
    'if',
    'implements',
    'import',
    'in',
    'interface',
    'is',
    'late',
    'library',
    'mixin',
    'new',
    'null',
    'on',
    'operator',
    'part',
    'required',
    'rethrow',
    'return',
    'set',
    'show',
    'static',
    'super',
    'switch',
    'sync',
    'this',
    'throw',
    'true',
    'try',
    'typedef',
    'var',
    'void',
    'while',
    'with',
    'yield',
  ];

  if (reservedWords.contains(name)) {
    return ValidationResult.invalid('"$name" is a Dart reserved word');
  }

  return const ValidationResult.valid();
}

/// Validate Firebase project ID
ValidationResult validateFirebaseProjectId(String id) {
  if (id.isEmpty) {
    return const ValidationResult.invalid(
      'Firebase project ID cannot be empty',
    );
  }

  if (id.contains(' ')) {
    return const ValidationResult.invalid(
      'Firebase project ID cannot contain spaces',
    );
  }

  // Firebase project ID pattern: lowercase, numbers, hyphens
  final RegExp validPattern = RegExp(r'^[a-z][a-z0-9-]*[a-z0-9]$');
  if (!validPattern.hasMatch(id) && id.length > 1) {
    return const ValidationResult.invalid(
      'Firebase project ID must start with a letter, contain only lowercase letters, numbers, and hyphens, and end with a letter or number',
    );
  }

  // Single character check
  if (id.length == 1 && !RegExp(r'^[a-z]$').hasMatch(id)) {
    return const ValidationResult.invalid(
      'Firebase project ID must start with a letter',
    );
  }

  // Length check (Firebase allows 6-30 characters)
  if (id.length < 6 || id.length > 30) {
    return const ValidationResult.invalid(
      'Firebase project ID must be between 6 and 30 characters',
    );
  }

  return const ValidationResult.valid();
}

/// Validate organization domain (reverse notation like com.example)
ValidationResult validateOrgDomain(String domain) {
  if (domain.isEmpty) {
    return const ValidationResult.invalid(
      'Organization domain cannot be empty',
    );
  }

  if (domain.contains(' ')) {
    return const ValidationResult.invalid(
      'Organization domain cannot contain spaces',
    );
  }

  // Basic reverse domain notation pattern
  final RegExp validPattern = RegExp(r'^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$');
  if (!validPattern.hasMatch(domain.toLowerCase())) {
    return const ValidationResult.invalid(
      'Organization domain should be in reverse notation (e.g., com.example, art.arcane)',
    );
  }

  return const ValidationResult.valid();
}

/// Validate template selection (1-4 or template name)
ValidationResult validateTemplate(String template) {
  const List<String> validTemplates = <String>[
    '1',
    '2',
    '3',
    '4',
    'arcane_template',
    'arcane_beamer',
    'arcane_dock',
    'arcane_cli',
  ];

  if (!validTemplates.contains(template.toLowerCase())) {
    return const ValidationResult.invalid(
      'Template must be 1-4 or one of: arcane_template, arcane_beamer, arcane_dock, arcane_cli',
    );
  }

  return const ValidationResult.valid();
}

/// Validate directory path
ValidationResult validatePath(String path) {
  if (path.isEmpty) {
    return const ValidationResult.invalid('Path cannot be empty');
  }

  // Check for obviously invalid characters (platform-specific)
  final RegExp invalidChars = RegExp(r'[\x00-\x1F]');
  if (invalidChars.hasMatch(path)) {
    return const ValidationResult.invalid('Path contains invalid characters');
  }

  return const ValidationResult.valid();
}
