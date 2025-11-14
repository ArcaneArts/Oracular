import 'dart:io';

import 'package:arcane/arcane.dart' hide Window, MenuItem;
import 'package:fast_log/fast_log.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart' as wm;

/// Window Manager for handling system tray and popup window
class WindowManager {
  /// Window configuration options
  static const wm.WindowOptions windowOptions = wm.WindowOptions(
    size: Size(400, 600),
    maximumSize: Size(400, 600),
    minimumSize: Size(400, 600),
    center: false,
    windowButtonVisibility: false,
    title: 'Arcane Dock',
    alwaysOnTop: false,
    backgroundColor: Color(0x00000000),
    skipTaskbar: true,
    titleBarStyle: wm.TitleBarStyle.hidden,
  );

  /// Initialize window manager and system tray
  static Future<void> init() async {
    verbose("Starting Window Manager");
    await wm.windowManager.ensureInitialized();

    verbose("Starting System Tray");
    await initSystemTray();

    verbose("Starting Screen Retriever");
    final Display primaryDisplay = await screenRetriever.getPrimaryDisplay();

    verbose("Initializing Window");
    await Window.initialize();

    verbose("Setting up window listeners");
    wm.windowManager.addListener(HideOnBlurWindowListener());

    verbose("Waiting for window to be ready");
    await wm.windowManager.waitUntilReadyToShow(windowOptions, () async {
      verbose("Window is ready. Hiding...");
      await wm.windowManager.hide();

      verbose("Setting window properties");
      await wm.windowManager.setBackgroundColor(Colors.transparent);
      await wm.windowManager.setMovable(false);

      verbose("Setting window position");
      await wm.windowManager.setPosition(
        Offset(
          primaryDisplay.size.width - windowOptions.size!.width,
          0,
        ),
      );

      verbose("Setting window effect");
      await Window.setEffect(
        effect: WindowEffect.menu,
        color: const Color(0x00000000),
      );

      verbose("Window initialization complete");
    });
  }

  /// Initialize system tray icon and menu
  static Future<void> initSystemTray() async {
    // Set tray icon
    // Use template icon for macOS to respect system theme
    await trayManager.setIcon(
      'assets/tray.png',
      isTemplate: Platform.isMacOS,
    );

    // Create tray context menu
    final Menu menu = Menu(
      items: [
        MenuItem(
          key: 'show',
          label: 'Show',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'settings',
          label: 'Settings',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'exit',
          label: 'Exit',
        ),
      ],
    );

    await trayManager.setContextMenu(menu);

    verbose("Registering system tray event handler");
    trayManager.addListener(ArcaneDockTrayListener());
    verbose("System tray ready");
  }

  /// Show the dock window at cursor position
  static Future<void> show() async {
    try {
      // Get cursor position
      final Offset cursor = await screenRetriever.getCursorScreenPoint();
      final Size windowSize = windowOptions.size!;

      // Get primary display bounds
      final Display primaryDisplay = await screenRetriever.getPrimaryDisplay();
      final Size screenSize = primaryDisplay.size;

      // Calculate window position centered under cursor
      // Ensure window stays within screen bounds
      double x = cursor.dx - (windowSize.width / 2);
      double y = cursor.dy + 10; // 10px below cursor

      // Constrain X position
      if (x < 0) {
        x = 0;
      } else if (x + windowSize.width > screenSize.width) {
        x = screenSize.width - windowSize.width;
      }

      // Constrain Y position
      if (y + windowSize.height > screenSize.height) {
        // Show above cursor if not enough space below
        y = cursor.dy - windowSize.height - 10;
      }

      await wm.windowManager.setPosition(Offset(x, y));
      await wm.windowManager.show();
      await wm.windowManager.focus();

      verbose("Window shown at position ($x, $y)");
    } catch (e) {
      error("Failed to show window: $e");
    }
  }

  /// Hide the dock window
  static Future<void> hide() async {
    try {
      await wm.windowManager.hide();
      verbose("Window hidden");
    } catch (e) {
      error("Failed to hide window: $e");
    }
  }

  /// Toggle window visibility
  static Future<void> toggle() async {
    final bool isVisible = await wm.windowManager.isVisible();
    if (isVisible) {
      await hide();
    } else {
      await show();
    }
  }

  /// Exit the application
  static Future<void> exit(int i) async {
    verbose("Exiting application");
    await wm.windowManager.destroy();
    exit(0);
  }
}

/// Tray listener for handling tray icon clicks
class ArcaneDockTrayListener implements TrayListener {
  @override
  void onTrayIconMouseDown() {
    // Left click - do nothing, wait for mouse up
  }

  @override
  void onTrayIconMouseUp() {
    // Left click released - show/hide window
    WindowManager.toggle();
  }

  @override
  void onTrayIconRightMouseDown() {
    // Right click - do nothing, wait for mouse up
  }

  @override
  void onTrayIconRightMouseUp() {
    // Right click released - show context menu
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    // Handle menu item clicks
    switch (menuItem.key) {
      case 'show':
        WindowManager.show();
        break;
      case 'settings':
        // TODO: Implement settings
        info("Settings clicked");
        WindowManager.show();
        break;
      case 'exit':
        WindowManager.exit(0);
        break;
      default:
        warn("Unknown menu item: ${menuItem.key}");
    }
  }
}

/// Window listener for hiding window when it loses focus
class HideOnBlurWindowListener implements wm.WindowListener {
  @override
  void onWindowBlur() {
    WindowManager.hide();
  }

  // Unused window events
  @override
  void onWindowClose() {}

  @override
  void onWindowDocked() {}

  @override
  void onWindowEnterFullScreen() {}

  @override
  void onWindowEvent(String eventName) {}

  @override
  void onWindowFocus() {}

  @override
  void onWindowLeaveFullScreen() {}

  @override
  void onWindowMaximize() {}

  @override
  void onWindowMinimize() {}

  @override
  void onWindowMove() {}

  @override
  void onWindowMoved() {}

  @override
  void onWindowResize() {}

  @override
  void onWindowResized() {}

  @override
  void onWindowRestore() {}

  @override
  void onWindowUndocked() {}

  @override
  void onWindowUnmaximize() {}
}
