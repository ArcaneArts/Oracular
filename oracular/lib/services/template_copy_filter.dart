class TemplateCopyFilter {
  static const Set<String> skippedDirectories = <String>{
    '.dart_tool',
    '.idea',
    '.git',
    'build',
    '.gradle',
    'Pods',
  };

  static const Set<String> skippedFiles = <String>{
    '.DS_Store',
    'pubspec.lock',
    '.flutter-plugins',
    '.flutter-plugins-dependencies',
    '.packages',
    '.metadata',
  };

  static bool shouldSkipDirectory(String dirName) {
    return skippedDirectories.contains(dirName);
  }

  static bool shouldSkipFile(String fileName) {
    return fileName.endsWith('.g.dart') || skippedFiles.contains(fileName);
  }
}
