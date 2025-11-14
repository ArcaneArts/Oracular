# Arcane Dock

System tray/menu bar application template for desktop platforms. Material Design-free architecture with window management and tray integration.

## Overview

Desktop template for applications that live in the system tray (macOS menu bar, Windows system tray, Linux notification area).

**Features:**
- Native system tray icon
- Popup window on tray click
- Auto-hide on blur
- Launch at startup support
- Cross-platform (macOS, Linux, Windows)
- Pure Arcane UI

**Best for:**
- System utilities and monitoring tools
- Background services with UI
- Always-available dashboards
- Menu bar applications
- Quick-access tools

## Quick Start

This template is used via the setup wizard:

```bash
cd ..
./setup.sh
```

Select "arcane_dock" when prompted.

## Structure

```
lib/
├── main.dart              # App entry, initialization, tray setup
├── screens/
│   └── dock_screen.dart   # Main popup UI
└── util/
    └── window_manager.dart # Tray & window management

assets/
├── icon.png               # App icon
└── tray.png               # System tray icon

macos/
└── Runner/
    ├── Info.plist         # LSUIElement configured
    ├── MainFlutterWindow.swift # launch_at_startup platform code
    └── *.entitlements     # Sandbox permissions
```

## Usage

**Run the app:**
```bash
flutter run -d macos  # or linux, or windows
```

**macOS CocoaPods:**
```bash
dart run pod_install_macos
```

## System Tray

**Icon requirements:**

macOS: 22x22 pixels (@1x), 44x44 (@2x), black with transparency (template image)
Linux: 22x22 pixels PNG, full color or monochrome
Windows: 16x16 or 32x32 pixels PNG or ICO

Replace `assets/tray.png` with your icon.

**Menu configuration:**

Edit `lib/util/window_manager.dart` in `initSystemTray()`:

```dart
final Menu menu = Menu(
  items: [
    MenuItem(key: 'show', label: 'Show'),
    MenuItem(key: 'settings', label: 'Settings'),
    MenuItem.separator(),
    MenuItem(key: 'exit', label: 'Quit'),
  ],
);
```

Handle menu clicks in `onTrayMenuItemClick()`.

## Window Management

**Customize window size:**

Edit `lib/util/window_manager.dart`:

```dart
static const wm.WindowOptions windowOptions = wm.WindowOptions(
  size: Size(400, 600),
  maximumSize: Size(400, 600),
  minimumSize: Size(400, 600),
  center: false,
  alwaysOnTop: true,
  skipTaskbar: true,
  titleBarStyle: wm.TitleBarStyle.hidden,
);
```

**Window positioning:**

The window automatically positions near the tray icon using `screen_retriever` to get cursor position.

## UI Customization

Edit `lib/screens/dock_screen.dart`:

```dart
Widget build(BuildContext context) {
  return Screen(
    backgroundColor: context.colorScheme.bg.primary,
    child: Collection(
      children: [
        Section(
          titleText: "Status",
          children: [
            Tile(
              titleText: "Online",
              leading: const Icon(Icons.check_circle),
            ),
          ],
        ),
        Section(
          titleText: "Settings",
          children: [
            Tile(
              titleText: "Launch at Startup",
              trailing: const Icon(Icons.chevron_forward_ionic),
              onPressed: () => _toggleAutolaunch(),
            ),
          ],
        ),
      ],
    ).padded(),
  );
}
```

## Launch at Startup

**Enable/disable:**

```dart
await launchAtStartup.enable();
await launchAtStartup.disable();
```

**Check status:**

```dart
final bool isEnabled = await launchAtStartup.isEnabled();
```

**Platform setup:**

macOS requires platform channel code in `MainFlutterWindow.swift` (included in template).

## Persistent Storage

**Settings with Hive:**

```dart
// Save setting
await boxSettings.put('autolaunch', true);

// Load setting
final autolaunch = boxSettings.get('autolaunch', defaultValue: false);
```

**Data storage:**

```dart
// Save data
await box.put('key', value);

// Load data
final value = box.get('key', defaultValue: 'default');
```

## Logging

Logs written to `~/Documents/ArcaneDock/arcane_dock.log`:

```dart
info('Information message');
verbose('Detailed message');
warn('Warning message');
error('Error message');
success('Success message');
```

Log file automatically rotates when exceeding 1MB.

## Platform-Specific Notes

**macOS:**

`LSUIElement` set to `true` in `Info.plist` to hide dock icon. App only appears in menu bar.

Platform channel code in `MainFlutterWindow.swift` enables `launch_at_startup` plugin.

**Linux:**

Requires `libappindicator3-dev`:
```bash
sudo apt-get install libappindicator3-dev  # Ubuntu/Debian
sudo dnf install libappindicator-gtk3-devel # Fedora
```

GNOME users: Install [AppIndicator extension](https://extensions.gnome.org/extension/615/appindicator-support/)

**Windows:**

No additional setup required. Tray icon works out of the box.

## Common Use Cases

**System monitor:**

```dart
Timer.periodic(Duration(seconds: 5), (timer) {
  final status = checkSystemStatus();
  updateTrayIcon(status);
  setState(() => _status = status);
});
```

**Clipboard manager:**

```dart
Timer.periodic(Duration(milliseconds: 500), (timer) async {
  final data = await Clipboard.getData('text/plain');
  if (data?.text != _lastClipboard) {
    _addToHistory(data?.text);
    _lastClipboard = data?.text;
  }
});
```

**API dashboard:**

```dart
Timer.periodic(Duration(minutes: 5), (timer) async {
  final response = await http.get(apiUrl);
  setState(() => _data = jsonDecode(response.body));
});
```

## Best Practices

**Keep window lightweight:**

Popup should load instantly. Avoid heavy operations in build().

**Handle errors silently:**

Tray apps run in background. Log errors instead of showing dialogs.

**Minimize resource usage:**

Use reasonable timer intervals. Cancel timers when not needed.

**Update tray icon for status:**

```dart
await trayManager.setIcon(
  isOnline ? 'assets/tray_online.png' : 'assets/tray_offline.png',
  isTemplate: Platform.isMacOS,
);
```

**Test on all platforms:**

Behavior varies by platform. Use platform checks when needed.

## Troubleshooting

**macOS: App shows in Dock**

Add `LSUIElement` to `macos/Runner/Info.plist`:
```xml
<key>LSUIElement</key>
<true/>
```

Then rebuild:
```bash
flutter clean && flutter run -d macos
```

**Linux: Tray icon not showing**

Install system tray support and enable in desktop environment (see Platform-Specific Notes).

**Windows: Window position incorrect**

Debug screen detection:
```dart
final Display display = await screenRetriever.getPrimaryDisplay();
final Offset cursor = await screenRetriever.getCursorScreenPoint();
print('Screen: ${display.size}, Cursor: $cursor');
```

**CocoaPods fails**

Clean and retry:
```bash
cd macos && rm -rf Pods Podfile.lock && pod install --repo-update && cd ..
```

**Plugin exception (macOS)**

Ensure `MainFlutterWindow.swift` has platform channel code for `launch_at_startup`. Template includes this automatically.

## Dependencies

Core packages:
- arcane - UI framework
- tray_manager - System tray icon and menu
- window_manager - Window positioning
- screen_retriever - Screen info and cursor position
- flutter_acrylic - Window blur effects
- launch_at_startup - Autolaunch configuration
- hive/hive_flutter - Persistent storage
- fast_log - Logging

## Documentation

- [Main README](../README.md) - All templates overview
- [tray_manager](https://pub.dev/packages/tray_manager) - Tray manager package docs
- [window_manager](https://pub.dev/packages/window_manager) - Window manager package docs
- [ArcaneDesign.txt](../references/ArcaneDesign.txt) - Complete component reference

## Related Templates

- **arcane_template** - Basic multi-platform template
- **arcane_beamer** - Template with Beamer navigation
- **server_template** - Backend server
- **models_template** - Shared data models

See [main README](../README.md) for details.
