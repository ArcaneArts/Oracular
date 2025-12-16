import 'dart:io';

/// Display utilities (banners, boxes, lists, dividers)
class DisplayPrompt {
  /// Print a header banner
  static void printBanner(String title, {String? subtitle}) {
    // Calculate width based on content
    int maxContentLen = title.length;
    if (subtitle != null && subtitle.length > maxContentLen) {
      maxContentLen = subtitle.length;
    }
    // Inner width includes space padding on each side
    final int innerWidth = (maxContentLen + 4).clamp(38, 78);
    final String line = '\u2550' * innerWidth;

    print('');
    print('\u2554$line\u2557');
    _printBannerLine(title, innerWidth);
    if (subtitle != null) {
      _printBannerLine(subtitle, innerWidth);
    }
    print('\u255a$line\u255d');
    print('');
  }

  static void _printBannerLine(String text, int innerWidth) {
    // Content width is innerWidth minus 2 for space padding
    final int contentWidth = innerWidth - 2;
    final int leftPad = (contentWidth - text.length) ~/ 2;
    final int rightPad = contentWidth - text.length - leftPad;
    final String content = ' ' * leftPad + text + ' ' * rightPad;
    print('\u2551 $content \u2551');
  }

  /// Print a section divider
  static void printDivider({String? title, int width = 60}) {
    print('');
    if (title != null) {
      final int padding = (width - title.length - 2) ~/ 2;
      print('${'\u2500' * padding} $title ${'\u2500' * padding}');
    } else {
      print('\u2500' * width);
    }
    print('');
  }

  /// Show a pretty configuration preview box
  static void printConfigPreview(
    Map<String, String> config, {
    String title = 'Configuration Preview',
  }) {
    // Calculate width based on longest content
    int maxContentLen = title.length;
    for (final MapEntry<String, String> entry in config.entries) {
      final int lineLen = '${entry.key}: ${entry.value}'.length;
      if (lineLen > maxContentLen) maxContentLen = lineLen;
    }
    // Box structure: │ content │ = content + 4 chars for "│ " and " │"
    // Line width = content width + 2 for the spaces inside borders
    final int innerWidth = (maxContentLen + 2).clamp(38, 78);
    final String line = '\u2500' * innerWidth;

    print('');
    print('\u256d$line\u256e');
    _printBoxLine(title, innerWidth, center: true);
    print('\u251c$line\u2524');

    for (final MapEntry<String, String> entry in config.entries) {
      _printBoxLine('${entry.key}: ${entry.value}', innerWidth);
    }

    print('\u2570$line\u256f');
  }

  static void _printBoxLine(String text, int innerWidth, {bool center = false}) {
    // innerWidth is the width between the │ chars (includes the space padding)
    // So actual content area is innerWidth - 2 for the spaces
    final int contentWidth = innerWidth - 2;
    String content;
    if (center) {
      final int leftPad = (contentWidth - text.length) ~/ 2;
      final int rightPad = contentWidth - text.length - leftPad;
      content = ' ' * leftPad + text + ' ' * rightPad;
    } else {
      content = text.length > contentWidth
          ? text.substring(0, contentWidth)
          : text.padRight(contentWidth);
    }
    print('\u2502 $content \u2502');
  }

  /// Print a list of items with bullets
  static void printList(List<String> items, {String bullet = '•'}) {
    for (final String item in items) {
      print('  $bullet $item');
    }
  }

  /// Print a numbered list
  static void printNumberedList(List<String> items) {
    for (int i = 0; i < items.length; i++) {
      print('  ${i + 1}. ${items[i]}');
    }
  }

  /// Print a success box
  static void printSuccessBox(String message, {List<String>? details}) {
    print('');
    print('┌${'─' * (message.length + 6)}┐');
    print('│  ✓ $message  │');
    print('└${'─' * (message.length + 6)}┘');
    if (details != null && details.isNotEmpty) {
      printList(details);
    }
    print('');
  }

  /// Print an error box
  static void printErrorBox(String message, {String? hint}) {
    print('');
    print('┌${'─' * (message.length + 6)}┐');
    print('│  ✗ $message  │');
    print('└${'─' * (message.length + 6)}┘');
    if (hint != null) {
      print('  Hint: $hint');
    }
    print('');
  }

  /// Press enter to continue
  static Future<void> pressEnter({
    String message = 'Press Enter to continue...',
  }) async {
    stdout.write(message);
    stdin.readLineSync();
  }

  /// Clear the terminal screen
  static void clearScreen() {
    if (Platform.isWindows) {
      // Windows
      print(Process.runSync('cls', [], runInShell: true).stdout);
    } else {
      // Unix-like (macOS, Linux)
      stdout.write('\x1B[2J\x1B[0;0H');
    }
  }
}
