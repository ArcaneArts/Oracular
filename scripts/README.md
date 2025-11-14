# Setup Scripts & Automation

Modular shell scripts for automating Flutter project creation with Arcane templates. These scripts replace the old Occult CLI tool with better error handling, retry logic, and cross-platform support.

## 🚀 Quick Start

From the repository root:

```bash
./setup.sh
```

The interactive wizard automates the entire project setup process in minutes!

---

## 📋 Table of Contents

- [Automated Setup Wizard](#automated-setup-wizard)
- [Library Scripts](#library-scripts)
- [Manual Configuration Scripts](#manual-configuration-scripts)
- [Script Architecture](#script-architecture)
- [Retry Logic](#retry-logic)
- [Templates System](#templates-system)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

## 🧙 Automated Setup Wizard

### What It Does

The `setup.sh` script orchestrates the complete project setup:

1. **✅ Verify Prerequisites**
   - Checks Flutter, Dart, Firebase CLI, gcloud, Docker
   - Provides installation instructions for missing tools
   - macOS-specific checks (Homebrew, CocoaPods)

2. **📝 Gather Configuration**
   - Choose template (arcane_template or arcane_beamer)
   - Enter organization domain (e.g., com.mycompany)
   - Enter app name (e.g., my_awesome_app)
   - Choose Firebase integration (yes/no)
   - Choose Google Cloud Run deployment (yes/no)
   - Choose asset generation (yes/no for icons and splash)

3. **🏗️ Create 3-Project Architecture**
   - Client Flutter app with all platforms
   - Models package with User/Settings/ServerCommand templates
   - Server app with API/Service examples and Dockerfile

4. **📦 Install Dependencies**
   - Adds all Arcane packages
   - Configures Firebase dependencies (if enabled)
   - Installs development tools (build_runner, linters)
   - Automatic retry on network failures

5. **⚙️ Firebase Configuration**
   - Authenticates Firebase and gcloud
   - Runs FlutterFire configuration
   - Generates firebase.json and .firebaserc
   - Creates Firestore and Storage security rules
   - Sets up hosting targets (production + beta)

6. **🎨 Asset Generation**
   - Copies template assets (icon/splash)
   - Generates launcher icons for all platforms
   - Creates splash screens
   - Configures pubspec.yaml with asset paths

7. **🔧 Platform Configuration**
   - Sets Android minSDK to 23
   - Sets iOS deployment target to 13.0
   - Sets macOS deployment target to 10.15

8. **🐳 Server Setup**
   - Creates production Dockerfile (multi-stage build)
   - Creates development Dockerfile
   - Generates deployment script (script_deploy.sh)
   - Configures service account integration

9. **🚢 Firebase Deployment**
   - Deploys Firestore rules
   - Deploys Storage rules
   - Builds web app
   - Deploys to Firebase Hosting (production)
   - Optionally deploys beta hosting site

### Usage

```bash
# From repository root
./setup.sh
```

Follow the interactive prompts. The wizard will guide you through all options and handle errors automatically.

---

## 📚 Library Scripts

All core functionality is modular and reusable. Scripts are in `scripts/lib/`:

### 1. utils.sh

**Core utilities used by all scripts**

**Functions:**
- `log_info()`, `log_success()`, `log_error()`, `log_warning()` - Colored logging
- `log_step()` - Section headers
- `log_instruction()` - Special instructions for user
- `confirm()` - Yes/no prompts
- `require_tool()` - Check if CLI tool is installed
- `ensure_directory()` - Create directory if missing
- `snake_to_pascal()` - Convert snake_case to PascalCase
- `retry_command()` - **Automatic retry with user prompt**

**Retry Logic:**
```bash
retry_command "Description of operation" command arg1 arg2
```
- Automatically retries up to 2 times
- Then prompts: (r)etry, (s)kip, or (a)bort
- Used by all major operations for resilience

**Usage:**
```bash
source scripts/lib/utils.sh
log_info "Starting operation..."
retry_command "Installing dependencies" flutter pub get
```

---

### 2. check_tools.sh

**Verify CLI tool installation**

**Checks:**
- Flutter SDK (flutter --version)
- Firebase CLI (firebase --version)
- FlutterFire CLI (flutterfire --version)
- Google Cloud CLI (gcloud --version)
- Docker (docker --version)
- macOS-specific: Homebrew, CocoaPods

**Provides installation instructions for missing tools**

**Usage:**
```bash
# As standalone
./scripts/lib/check_tools.sh

# As library function
source scripts/lib/check_tools.sh
check_all_tools
```

**Returns:** 0 if all required tools present, 1 if any missing (with instructions)

---

### 3. create_projects.sh

**Create 3-project architecture**

**Creates:**
1. **Client App**: Full Flutter app with all platforms
2. **Models Package**: Dart package (no platforms)
3. **Server App**: Flutter app for Linux only

**Also:**
- Copies template pubspec.yaml (preserves comments)
- Replaces APPNAME placeholders
- Copies templates from models_template and server_template
- Generates .gitignore with Firebase keys excluded

**Usage:**
```bash
./scripts/lib/create_projects.sh <app_name> <organization>

# Example
./scripts/lib/create_projects.sh my_app com.mycompany
```

**Creates:**
```
my_app/              # Client (Flutter create --org com.mycompany)
my_app_models/       # Models (Dart package)
my_app_server/       # Server (Flutter create --platforms linux)
```

---

### 4. copy_templates.sh

**Copy and customize model/server templates**

**Copies:**
1. **models_template** → `{app_name}_models`
   - Pubspec with dependencies
   - User, UserSettings, ThemeMode models
   - ServerCommand, ServerResponse models
   - Registration and build_runner setup

2. **server_template** → `{app_name}_server`
   - Pubspec with shelf/firebase dependencies
   - 3 API examples (user, settings, command)
   - 3 Service examples (user, command, media)
   - RequestAuthenticator with timing attack protection
   - Dockerfile and script_deploy.sh

**Placeholder Replacement:**
- `APPNAME` → actual app name
- `FIREBASE_PROJECT_ID` → Firebase project ID (or placeholder)
- `APPNAMEServer` → PascalCase app name + Server

**Usage:**
```bash
source scripts/lib/copy_templates.sh
copy_models_template "my_app" "."
copy_server_template "my_app" "." "my-firebase-project"
```

---

### 5. add_dependencies.sh

**Install all dependencies with retry logic**

**Adds to Client:**
- Arcane packages (arcane, arcane_fluf, arcane_auth, arcane_user)
- State management (pylon, rxdart)
- Utilities (toxic, fast_log, serviced)
- Data (hive, fire_crud, artifact)
- Optional Firebase packages (if enabled)
- Dev dependencies (flutter_lints, flutter_launcher_icons, flutter_native_splash)

**Adds to Models:**
- artifact, crypto, fire_crud, toxic
- Dev: artifact_gen, build_runner, fire_crud_gen

**Adds to Server:**
- shelf, shelf_router, arcane_admin
- firebase_admin (for server-side Firestore)
- google_cloud_storage
- Dev: lints

**Automatic Retry:**
- All `flutter pub add` commands wrapped in `retry_command()`
- Network failures automatically retry
- User can manually retry/skip/abort

**Usage:**
```bash
./scripts/lib/add_dependencies.sh <app_name> <use_firebase>

# Example
./scripts/lib/add_dependencies.sh my_app yes
```

---

### 6. setup_firebase.sh

**Firebase and Google Cloud authentication**

**Operations:**
1. Firebase login (`firebase login`)
2. gcloud authentication (`gcloud auth login`)
3. FlutterFire configure (for client app)
4. Create service account JSON key
5. Download and store in config/keys/

**Handles:**
- Automatic login if not authenticated
- Prompts for Firebase project selection
- gcloud project configuration
- Service account key management

**Retry Logic:**
- All authentication steps use `retry_command()`
- Flaky network connections handled gracefully

**Usage:**
```bash
./scripts/lib/setup_firebase.sh <app_name> <firebase_project_id>

# Example
./scripts/lib/setup_firebase.sh my_app my-firebase-project
```

---

### 7. generate_configs.sh

**Create Firebase configuration files**

**Generates:**
1. **firebase.json**
   - Firestore rules path
   - Storage rules path
   - Hosting targets (release + beta)
   - Rewrites for SPA

2. **.firebaserc**
   - Default project
   - Hosting targets configuration

3. **config/firestore.rules**
   - Security rules with user/settings/capabilities pattern
   - isAuth(), isUser(), isAdmin() helper functions
   - Command/response patterns
   - Default deny-all with explicit allows

4. **config/firestore.indexes.json**
   - Empty indexes file

5. **config/storage.rules**
   - Default deny-all
   - User-specific file access pattern

**Templates Assets:**
- Copies assets from template (icons, splash)
- Updates pubspec.yaml with asset paths
- Configures flutter_native_splash and flutter_launcher_icons

**Usage:**
```bash
./scripts/lib/generate_configs.sh <app_name> <firebase_project_id>

# Example
./scripts/lib/generate_configs.sh my_app my-firebase-project
```

---

### 8. generate_assets.sh

**Generate app icons and splash screens**

**Operations:**
1. **Check for Assets**: Verifies assets/icon/icon.png and splash.png exist
2. **Generate Icons**: Runs `dart run flutter_launcher_icons`
   - Generates for iOS, Android, Web, macOS, Windows
3. **Generate Splash**: Runs `dart run flutter_native_splash:create`
   - Creates splash screens for all platforms

**Configurable:**
- Can skip icons: `configure_asset_generation()` sets GENERATE_ICONS
- Can skip splash: Sets GENERATE_SPLASH
- Called by setup.sh with user preferences

**Retry Logic:**
- Generation commands wrapped in `retry_command()`
- Handles transient failures

**Usage:**
```bash
./scripts/lib/generate_assets.sh <app_name>

# Example
./scripts/lib/generate_assets.sh my_app
```

---

### 9. setup_server.sh

**Create Dockerfiles and deployment scripts**

**Creates:**
1. **Dockerfile** (production)
   - Multi-stage build (build + runtime)
   - Linux AMD64 platform
   - Optimized for Cloud Run
   - Copies models into server

2. **Dockerfile-dev** (development)
   - Development environment
   - Hot reload support
   - Debug symbols included

3. **script_deploy.sh**
   - Automated deployment to Google Cloud Run
   - Builds Docker image
   - Pushes to Artifact Registry
   - Deploys to Cloud Run with env vars

**Placeholder Replacement:**
- APPNAME → app name
- FIREBASE_PROJECT_ID → Firebase project
- Configuration for region, memory, etc.

**Usage:**
```bash
./scripts/lib/setup_server.sh <app_name> <firebase_project_id>

# Example
./scripts/lib/setup_server.sh my_app my-firebase-project
```

---

### 10. deploy_firebase.sh

**Deploy to Firebase services**

**Operations:**
1. **deploy_firestore()** - Deploy Firestore rules
2. **deploy_storage()** - Deploy Storage rules
3. **build_web_app()** - Flutter web release build
4. **deploy_hosting_release()** - Deploy to production hosting
5. **deploy_hosting_beta()** - Deploy to beta hosting
6. **deploy_all_firebase()** - Orchestrate all deployments

**Beta Hosting Setup:**
- Provides instructions to create beta site in Firebase Console
- Confirms user created site before deploying
- Separate URL for staging/preview

**Retry Logic:**
- All firebase deploy commands wrapped in `retry_command()`
- Network failures handled gracefully
- Continues on non-critical failures with warnings

**Usage:**
```bash
# As standalone
./scripts/lib/deploy_firebase.sh <app_name>

# Or call functions directly
source scripts/lib/deploy_firebase.sh
deploy_firestore
deploy_hosting_release
```

---

## 🔧 Manual Configuration Scripts

Helper scripts for post-setup adjustments (in `scripts/`):

### set_android_min_sdk.sh

Updates Android minimum SDK version.

```bash
./scripts/set_android_min_sdk.sh <app_name> <min_sdk>

# Example
./scripts/set_android_min_sdk.sh my_app 23
```

**Modifies:** `android/app/build.gradle.kts`

---

### set_ios_platform_version.sh

Updates iOS deployment target.

```bash
./scripts/set_ios_platform_version.sh <app_name> <version>

# Example
./scripts/set_ios_platform_version.sh my_app 13.0
```

**Modifies:** `ios/Runner.xcodeproj/project.pbxproj`

---

### set_macos_platform_version.sh

Updates macOS deployment target.

```bash
./scripts/set_macos_platform_version.sh <app_name> <version>

# Example
./scripts/set_macos_platform_version.sh my_app 10.15
```

**Modifies:** `macos/Runner.xcodeproj/project.pbxproj` and `macos/Podfile`

---

## 🏗️ Script Architecture

### Design Principles

1. **Modular**: Each script is a reusable library
2. **Composable**: Scripts can be run standalone or sourced as functions
3. **Resilient**: All operations have retry logic
4. **Cross-platform**: Works on macOS and Linux
5. **Idempotent**: Safe to run multiple times

### Execution Flow

```
setup.sh (orchestrator)
  ├─> check_tools.sh (verify)
  ├─> create_projects.sh (create structure)
  │     └─> copy_templates.sh (templates)
  ├─> add_dependencies.sh (install packages)
  │     └─> retry_command() for each package
  ├─> setup_firebase.sh (auth & config)
  │     └─> generate_configs.sh (rules & config files)
  ├─> generate_assets.sh (icons & splash)
  ├─> Platform version scripts (Android/iOS/macOS)
  ├─> setup_server.sh (Dockerfiles)
  └─> deploy_firebase.sh (deploy)
        └─> retry_command() for each deployment
```

### Error Handling Strategy

1. **Automatic Retry**: Network operations retry 2 times automatically
2. **User Prompt**: After auto-retries, ask user (retry/skip/abort)
3. **Graceful Degradation**: Non-critical failures log warnings and continue
4. **Clear Messaging**: All errors explain what failed and how to fix

---

## 🔄 Retry Logic

### Why It's Important

Network operations can fail due to:
- Temporary network issues
- Rate limiting
- DNS resolution problems
- Server timeouts

### How It Works

```bash
retry_command "Installing dependencies" flutter pub get
```

**Flow:**
1. Attempt 1: Run command
2. If fails, automatic retry (attempt 2)
3. If fails again, automatic retry (attempt 3)
4. If fails third time, prompt user:
   - **(r)etry**: Try again (increments attempt counter)
   - **(s)kip**: Continue without this operation (returns 1)
   - **(a)bort**: Exit entire setup (exits with code 1)

### Operations Using Retry

All major operations use retry_command():
- flutter pub add (every package installation)
- flutter pub get (dependency resolution)
- firebase login, firebase deploy
- gcloud auth, gcloud commands
- dart run (asset generation)
- Flutter web builds

---

## 📋 Templates System

### Template Structure

```
arcane_templates/
├── arcane_template/         # Client template (no nav)
│   └── pubspec.yaml         # With dart run scripts
├── arcane_beamer/           # Client template (with Beamer)
│   └── pubspec.yaml
├── models_template/         # Shared models template
│   ├── lib/
│   │   ├── APPNAME_models.dart
│   │   └── models/
│   │       ├── user.dart
│   │       ├── user_settings.dart
│   │       └── server_command.dart
│   └── pubspec.yaml
└── server_template/         # Server template
    ├── lib/
    │   ├── main.dart
    │   ├── api/
    │   ├── service/
    │   └── util/
    ├── Dockerfile
    ├── script_deploy.sh
    └── pubspec.yaml
```

### Placeholder System

**During setup, these are replaced:**

| Placeholder | Replacement | Used In |
|-------------|-------------|---------|
| `APPNAME` | Your app name (snake_case) | All files |
| `APPNAMEServer` | YourAppServer (PascalCase) | Server Dart files |
| `FIREBASE_PROJECT_ID` | Your Firebase project ID | Config files, scripts |
| `APPNAME_models.dart` | your_app_models.dart | Models library file |

**How Replacement Works:**
```bash
# Find all relevant files and replace
find "$app_name" -type f \( -name "*.dart" -o -name "*.yaml" \) -exec \
    sed -i.bak "s/APPNAME/$app_name/g" {} \; -exec rm {}.bak \;

# Rename files
mv APPNAME_models.dart ${app_name}_models.dart
```

### Template Customization

**To customize templates:**

1. Modify files in `models_template/` or `server_template/`
2. Use `APPNAME` placeholders where needed
3. Add new models/APIs/services
4. Run setup.sh - changes automatically applied

**Templates are real production code from MyGuide v12!**

---

## 🐛 Troubleshooting

### Script Errors

**"Permission denied"**
```bash
chmod +x setup.sh
chmod +x scripts/*.sh
chmod +x scripts/lib/*.sh
```

**"No such file or directory"**
- Run from repository root (where setup.sh is located)
- Check paths in error messages

**"Command not found"**
- Run check_tools.sh to see what's missing
- Install required CLI tools

### Setup Failures

**Flutter pub get fails repeatedly**
```bash
# Clear Flutter cache
flutter pub cache repair

# Check internet connection
curl -I https://pub.dev

# Try manual installation
cd my_app
flutter pub get
```

**Firebase login fails**
```bash
# Clear Firebase credentials
firebase logout
firebase login --reauth

# Check browser opens for OAuth
# If not, use: firebase login --no-localhost
```

**Template files not found**
- Verify templates exist: `ls models_template/`, `ls server_template/`
- Check you're in repository root: `pwd`

### Retry Issues

**Stuck in retry loop**
- Press Ctrl+C to break
- Choose (a)bort when prompted
- Fix underlying issue (network, permissions, etc.)
- Re-run setup.sh

**Skip not working**
- (s)kip continues without that operation
- Check warnings for what was skipped
- You can manually complete skipped steps later

---

## 🤝 Contributing

### Adding New Scripts

1. Create in `scripts/lib/new_script.sh`
2. Follow template:

```bash
#!/bin/bash

# Brief description
# Detailed explanation of what this does

# Source utilities
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/utils.sh"

your_function() {
    local param="$1"

    log_step "Your Operation"

    if retry_command "Description" command args; then
        log_success "Operation succeeded"
        return 0
    else
        log_error "Operation failed"
        return 1
    fi
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    if [ $# -lt 1 ]; then
        echo "Usage: $0 <param>"
        exit 1
    fi

    your_function "$1"
fi
```

3. Add to setup.sh workflow
4. Update this README
5. Test on macOS and Linux

### Script Guidelines

- **Use retry_command()** for all network operations
- **Clear logging** with log_info, log_success, log_error
- **Validate inputs** early
- **Provide context** in error messages
- **Handle both macOS and Linux** (especially sed, grep)
- **Make idempotent** - safe to run multiple times
- **Document parameters** in script header

### Testing Checklist

- [ ] Run on macOS
- [ ] Run on Linux
- [ ] Test with network failures (disconnect mid-operation)
- [ ] Test retry prompts (r/s/a)
- [ ] Test skip functionality
- [ ] Verify cleanup on abort
- [ ] Check all logging output
- [ ] Verify placeholders replaced correctly

---

## 📚 Additional Resources

- **Main README**: [../README.md](../README.md)
- **Models Template**: [../models_template/README.md](../models_template/README.md)
- **Server Template**: [../server_template/README.md](../server_template/README.md)
- **Arcane Framework**: [github.com/ArcaneArts/arcane](https://github.com/ArcaneArts/arcane)

---

## 🎯 Recommended Workflow

### First Time Setup

```bash
# 1. Clone repository
git clone <repo-url>
cd arcane_templates

# 2. Make scripts executable
chmod +x setup.sh scripts/*.sh scripts/lib/*.sh

# 3. Run setup wizard
./setup.sh

# 4. Follow prompts
# - Choose template
# - Enter app details
# - Enable Firebase (if needed)
# - Let wizard do everything
```

### Daily Development

```bash
# Run your app
cd my_app
flutter run

# Make changes, hot reload is automatic

# Generate new assets
dart run gen_assets

# Deploy when ready
dart run deploy_web
```

### Updating Rules

```bash
# Edit rules
vim config/firestore.rules

# Deploy updated rules
cd my_app
dart run deploy_firestore
```

### Server Deployment

```bash
# Update server code
vim my_app_server/lib/api/new_api.dart

# Deploy to Cloud Run
cd my_app_server
./script_deploy.sh
```

---

**These scripts replace months of manual setup work with minutes of automation.** 🚀

Questions? Issues? Check the troubleshooting section or open a GitHub issue!
