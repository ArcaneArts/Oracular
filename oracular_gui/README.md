```
██████╗ ██╗     ██╗   ██╗███╗   ██╗██████╗ ███████╗██████╗ ██╗     ███████╗██╗  ██╗     ██████╗ ██╗   ██╗██╗
██╔══██╗██║     ██║   ██║████╗  ██║██╔══██╗██╔════╝██╔══██╗██║     ██╔════╝╚██╗██╔╝    ██╔════╝ ██║   ██║██║
██████╔╝██║     ██║   ██║██╔██╗ ██║██║  ██║█████╗  ██████╔╝██║     █████╗   ╚███╔╝     ██║  ███╗██║   ██║██║
██╔══██╗██║     ██║   ██║██║╚██╗██║██║  ██║██╔══╝  ██╔══██╗██║     ██╔══╝   ██╔██╗     ██║   ██║██║   ██║██║
██████╔╝███████╗╚██████╔╝██║ ╚████║██████╔╝███████╗██║  ██║███████╗███████╗██╔╝ ██╗    ╚██████╔╝╚██████╔╝██║
╚═════╝ ╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝     ╚═════╝  ╚═════╝ ╚═╝
```

Visual project creation wizard for Arcane Templates.

## Features

- **Step-by-step Wizard** - Guided project configuration
- **Template Selection** - Choose from 4 project templates
- **Platform Selection** - Pick target platforms for Flutter apps
- **Additional Packages** - Optional models and server packages
- **Firebase Integration** - Configure Firebase project settings
- **Real-time Progress** - Live build log during project creation
- **Theme Support** - Light, dark, and system theme modes

## Platforms

- macOS
- Linux
- Windows

## Launch

From CLI:
```bash
oracular gui
```

Or run directly:
```bash
cd oracular_gui
flutter run
```

## Wizard Steps

### 1. Basics
- App name (snake_case)
- Organization domain (reverse domain)
- Base class name (auto-generated PascalCase)
- Output directory

### 2. Template Selection
| Template          | Type    | Platforms    |
|-------------------|---------|--------------|
| Basic Arcane      | Flutter | All          |
| Beamer Navigation | Flutter | All          |
| Desktop Tray      | Flutter | Desktop only |
| Dart CLI          | Dart    | -            |

### 3. Options
- **Platform Selection** - Choose which platforms to target (Flutter apps)
- **Models Package** - Shared data models for client/server
- **Server App** - Shelf-based REST API
- **Firebase** - Enable Firebase with project ID
- **Cloud Run** - Docker deployment setup (if server + Firebase)

### 4. Review
- Configuration summary
- List of projects to create
- Create button

### Progress Screen
- Real-time progress bar
- Live build log with colored output
- Success/error status

### Completion Screen
- Success confirmation
- Next steps with copy-able commands
- Create another or exit

## Development

### Setup

```bash
flutter pub get
```

### Run

```bash
flutter run
flutter run -d macos
flutter run -d linux
flutter run -d windows
```

### Build

```bash
flutter build macos
flutter build linux
flutter build windows
```

## Architecture

```
lib/
├── main.dart                    App entry & theme setup
├── screens/
│   ├── wizard_screen.dart       Main wizard orchestrator
│   └── wizard/                  Modular step widgets
│       ├── wizard.dart              Barrel export
│       ├── step_indicator.dart      Progress dots
│       ├── basics_step.dart         Step 1: Project basics
│       ├── template_step.dart       Step 2: Template selection
│       ├── options_step.dart        Step 3: Platform & options
│       ├── review_step.dart         Step 4: Review config
│       ├── progress_screen.dart     Creation progress
│       └── completion_screen.dart   Success screen
├── models/
│   └── wizard_config.dart       Configuration state & validation
└── services/
    └── project_service.dart     Project creation logic
```

## UI Components (Arcane)

The GUI uses the Arcane UI framework:

- `Screen` - Main screen container with `Bar` header
- `Collection` - Layout grouping
- `CardSection` - Settings groups with title/subtitle
- `RadioGroup`/`RadioCard` - Template selection
- `Tile` - List items with leading/trailing widgets
- `Switch` - Toggle options
- `Progress` - Branded progress bar
- `CenterBody` - Empty/success states
- `PrimaryButton`/`OutlineButton` - Actions

## Dependencies

- **arcane** - UI framework (shadcn_flutter variant)
- **pylon** - State management
- **file_picker** - Directory selection
- **path** - Path utilities
