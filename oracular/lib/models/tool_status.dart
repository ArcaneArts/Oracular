/// Status of a CLI tool
class ToolStatus {
  final String name;
  final bool isInstalled;
  final String? version;
  final String? installInstructions;
  final bool isRequired;

  ToolStatus({
    required this.name,
    required this.isInstalled,
    this.version,
    this.installInstructions,
    this.isRequired = false,
  });

  /// Create a status for an installed tool
  factory ToolStatus.installed(
    String name,
    String version, {
    bool isRequired = false,
  }) {
    return ToolStatus(
      name: name,
      isInstalled: true,
      version: version,
      isRequired: isRequired,
    );
  }

  /// Create a status for a missing tool
  factory ToolStatus.missing(
    String name,
    String installInstructions, {
    bool isRequired = false,
  }) {
    return ToolStatus(
      name: name,
      isInstalled: false,
      installInstructions: installInstructions,
      isRequired: isRequired,
    );
  }

  @override
  String toString() {
    if (isInstalled) {
      return '$name: $version ✓';
    } else {
      return '$name: Not installed ${isRequired ? '(REQUIRED)' : '(optional)'}';
    }
  }
}

/// Summary of all tool checks
class ToolCheckResult {
  final List<ToolStatus> tools;
  final bool allRequiredInstalled;
  final List<ToolStatus> missingRequired;
  final List<ToolStatus> missingOptional;

  ToolCheckResult({required this.tools})
    : allRequiredInstalled = tools
          .where((ToolStatus t) => t.isRequired && !t.isInstalled)
          .isEmpty,
      missingRequired = tools
          .where((ToolStatus t) => t.isRequired && !t.isInstalled)
          .toList(),
      missingOptional = tools
          .where((ToolStatus t) => !t.isRequired && !t.isInstalled)
          .toList();

  /// Get all installed tools
  List<ToolStatus> get installed => tools.where((ToolStatus t) => t.isInstalled).toList();

  /// Get all missing tools
  List<ToolStatus> get missing => tools.where((ToolStatus t) => !t.isInstalled).toList();

  /// Print a summary to console
  void printSummary() {
    print('');
    print('Tool Check Results:');
    print('\u2500' * 60);

    for (final ToolStatus tool in tools) {
      final String status = tool.isInstalled ? '\u2713' : '\u2717';
      final String required = tool.isRequired ? ' (required)' : '';
      final String version = tool.isInstalled ? ' - ${tool.version}' : '';
      print('  [$status] ${tool.name}$required$version');
    }

    print('\u2500' * 60);

    if (allRequiredInstalled) {
      print('\u2713 All required tools are installed');
    } else {
      print('\u2717 Missing required tools:');
      for (final ToolStatus tool in missingRequired) {
        print('  - ${tool.name}');
        if (tool.installInstructions != null) {
          print('    Install: ${tool.installInstructions}');
        }
      }
    }

    if (missingOptional.isNotEmpty) {
      print('');
      print('Optional tools not installed:');
      for (final ToolStatus tool in missingOptional) {
        print('  - ${tool.name}');
        if (tool.installInstructions != null) {
          print('    Install: ${tool.installInstructions}');
        }
      }
    }
  }
}
