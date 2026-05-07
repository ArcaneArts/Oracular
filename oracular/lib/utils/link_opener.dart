import 'dart:io';

/// Opens local paths and web URLs with the host operating system.
class LinkOpener {
  static Future<bool> open(String target) async {
    final (String executable, List<String> arguments) = _commandFor(target);
    final ProcessResult result = await Process.run(executable, arguments);
    return result.exitCode == 0;
  }

  static (String, List<String>) _commandFor(String target) {
    if (Platform.isMacOS) {
      return ('open', <String>[target]);
    }

    if (Platform.isWindows) {
      return ('cmd', <String>['/c', 'start', '', target]);
    }

    return ('xdg-open', <String>[target]);
  }
}
