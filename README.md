# Arcane Templates

Complete Flutter project templates using the Arcane UI framework - Material Design-free UI with pure Arcane components.

## 🚀 Quick Start

**Use the interactive setup wizard to create your complete project in minutes:**

```bash
./setup.sh
```

The wizard handles everything automatically:
- ✅ CLI tools verification
- 🏗️ 3-project architecture creation (client, models, server)
- 📦 Automatic dependency installation
- 🔥 Optional Firebase integration
- 🎨 App icons and splash screens
- 🐳 Server Docker setup
- 🚢 Optional Firebase deployment

**This replaces the old Occult CLI tool!** Everything is automated with modular shell scripts.

**[📖 View Complete Setup Documentation](scripts/README.md)**

---

## 📦 Available Templates

### 1. arcane_template
**Pure Arcane UI without navigation framework**

Perfect for apps that need simple navigation or custom routing solutions.

**Features:**
- Material Design-free components
- Multi-platform support (Web, iOS, Android, Linux, macOS, Windows)
- Theme management (light/dark/system)
- Firebase ready (commented out, easily enabled)
- Server integration ready
- Comprehensive dart run scripts for all common tasks

**Use Cases:**
- Single-screen or simple apps
- Custom navigation requirements
- PWAs (Progressive Web Apps)
- Multi-platform desktop/mobile apps

[View Template →](arcane_template/)

### 2. arcane_beamer
**Arcane UI + Beamer Navigation**

Best for apps with complex navigation, deep linking, or web-first design.

**Everything in arcane_template, plus:**
- Declarative routing with Beamer
- Deep linking support (mobile & web)
- Clean URLs on web (path-based strategy, no # in URLs)
- Centralized route management
- Web-first navigation patterns
- Route guards and redirects

**Use Cases:**
- Multi-screen applications
- Web apps with shareable URLs
- Apps requiring deep linking
- Complex navigation flows

[View Template →](arcane_beamer/)

---

## 🎯 What's Included

### UI Framework
- **Arcane Components**: Screen, Bar, Collection, Section, Tile, Card, Gap, Buttons, and more
- **Arcane Extensions**: arcane_fluf, arcane_auth, arcane_user
- **Theme System**: Built-in light/dark/system theme toggle with context extension

### State Management
- **Pylon**: Immutable and mutable state management with reactive rebuilds
- **RxDart**: Reactive programming support for streams and observables

### Data Layer
- **FireCrud**: Firestore CRUD operations with type-safe models (optional)
- **Hive**: Local storage and caching
- **Artifact**: Data serialization and codec system

### Backend (Server Template)
- **Shelf Router**: HTTP routing and middleware
- **Firebase Admin**: Firestore server-side operations
- **Google Cloud Storage**: File and media management
- **Request Authentication**: Signature-based auth with timing attack protection
- **Docker**: Production-ready containerization

### Utilities
- **Toxic**: Flutter utility extensions (pad, sized, centered, etc.)
- **Fast Log**: Production logging system
- **Serviced**: Service layer management
- **Many more**: http, crypto, file_picker, cached_network_image, etc.

---

## 🏗️ Project Architecture

The setup wizard creates a professional 3-project architecture:

```
your-project-root/
├── your_app/              # Main Flutter client application
│   ├── lib/
│   │   ├── main.dart
│   │   └── screens/
│   ├── android/
│   ├── ios/
│   ├── web/
│   ├── macos/
│   ├── linux/
│   ├── windows/
│   ├── assets/
│   │   └── icon/
│   └── pubspec.yaml       # With dart run scripts
│
├── your_app_models/       # Shared Dart package for data models
│   ├── lib/
│   │   ├── your_app_models.dart
│   │   └── models/
│   │       ├── user.dart
│   │       ├── user_settings.dart
│   │       └── server_command.dart
│   └── pubspec.yaml
│
├── your_app_server/       # Flutter server application
│   ├── lib/
│   │   ├── main.dart
│   │   ├── api/           # REST API endpoints
│   │   ├── service/       # Business logic
│   │   └── util/          # Authentication, helpers
│   ├── Dockerfile
│   ├── script_deploy.sh
│   └── pubspec.yaml
│
├── config/                # Configuration files
│   ├── keys/              # Service account keys (gitignored)
│   ├── firebase.json
│   ├── firestore.rules
│   ├── firestore.indexes.json
│   └── storage.rules
│
├── firebase.json
├── .firebaserc
└── .gitignore
```

**Architecture Benefits:**
- ✅ **Separation of concerns**: Client, models, and server are independent
- ✅ **Code sharing**: Models used by both client and server (type-safe)
- ✅ **Independent deployment**: Deploy client and server separately
- ✅ **Better testing**: Test each layer independently
- ✅ **Scalability**: Easy to add microservices or additional clients

---

## ⚡ Features

### 🎨 Pure Arcane UI
- No Material Design dependency - pure Arcane components
- Consistent, modern design language
- Highly customizable theming system
- Beautiful glassmorphic effects and animations
- Dark mode support out of the box

### 🔥 Firebase Integration (Optional)
- **Authentication**: Email, Google, Apple sign-in
- **Cloud Firestore**: NoSQL database with security rules
- **Cloud Storage**: File storage with security rules
- **Analytics & Crashlytics**: User insights and error tracking
- **Firebase Hosting**: Web app hosting with multiple targets (production + beta)
- **Pre-configured rules**: Secure defaults with user/settings/capabilities patterns

### 🌐 Multi-Platform Support
- **Web**: PWA support, clean URLs (Beamer), responsive design
- **Mobile**: iOS and Android with native features
- **Desktop**: Windows, macOS, Linux with Arcane Desktop components

### 🚢 Server Deployment
- **Docker containerization**: Multi-stage builds for optimal size
- **Google Cloud Run**: Serverless container deployment
- **Service account integration**: Secure Firebase Admin access
- **Automatic deployment scripts**: One command to deploy
- **Environment configuration**: Easy secrets management

### 🎯 Developer Experience
- **Hot reload**: Instant feedback during development
- **Fast build times**: Optimized for quick iteration
- **Type-safe architecture**: Catch errors at compile time
- **Comprehensive documentation**: Everything you need to know
- **Dart run scripts**: Common tasks accessible from IDE or CLI

---

## 🔧 Dart Run Scripts

After setup, your client app includes convenient dart run scripts:

### Firebase Deployment
```bash
dart run deploy_firebase       # Deploy all Firebase services
dart run deploy_firestore      # Deploy Firestore rules only
dart run deploy_storage        # Deploy Storage rules only
dart run deploy_hosting        # Deploy to production hosting
dart run deploy_hosting_beta   # Deploy to beta hosting
```

### Web Building & Deployment
```bash
dart run build_web            # Build web release
dart run deploy_web           # Build + deploy to production
```

### Asset Generation
```bash
dart run gen_icons            # Generate app launcher icons
dart run gen_splash           # Generate splash screens
dart run gen_assets           # Generate both icons and splash
```

### Platform Setup
```bash
dart run pod_install_ios      # Clean + reinstall iOS CocoaPods
dart run pod_install_macos    # Clean + reinstall macOS CocoaPods
```

These scripts are defined in your app's `pubspec.yaml` and run from the app directory.

---

## 📚 Documentation

### Setup & Configuration
- **[Setup Script Documentation](scripts/README.md)** - Complete wizard guide
- **[Models Template Guide](models_template/README.md)** - Shared models package
- **[Server Template Guide](server_template/README.md)** - Backend server setup

### Library References
Comprehensive documentation for all included libraries in `SoftwareThings/`:

**UI & Design:**
- **[ArcaneDesign.txt](SoftwareThings/ArcaneDesign.txt)** - Complete Arcane UI component reference
- **[ArcaneShadDesign.txt](SoftwareThings/ArcaneShadDesign.txt)** - Advanced component patterns
- **[ArcaneDesktop.txt](SoftwareThings/ArcaneDesktop.txt)** - Desktop-specific features (tray, window effects)
- **[ArcaneSourcecode.txt](SoftwareThings/ArcaneSourcecode.txt)** - Internal component architecture

**State & Data:**
- **[Pylon.txt](SoftwareThings/Pylon.txt)** - Complete state management guide
- **[FireCrud.txt](SoftwareThings/FireCrud.txt)** - Firestore CRUD operations
- **[Artifact.txt](SoftwareThings/Artifact.txt)** - Data serialization and codecs

**Utilities:**
- **[Toxic.txt](SoftwareThings/Toxic.txt)** - Flutter utility extensions

---

## 🎓 Prerequisites

### Required
- **Flutter SDK** (latest stable)
- **Dart SDK** (included with Flutter)

### Optional (Based on Features)
- **Firebase CLI** (for Firebase integration)
- **FlutterFire CLI** (for Firebase configuration)
- **Google Cloud CLI** (for server deployment to Cloud Run)
- **Docker** (for server containerization)
- **npm** (for Firebase CLI installation)

### macOS Development
- **Homebrew** (package manager)
- **CocoaPods** (for iOS/macOS dependencies)

**The setup wizard checks all prerequisites and provides installation instructions!**

---

## 🚀 Example Workflow

### Create New Project

```bash
# Run the setup wizard
./setup.sh
```

Follow the prompts:
1. Choose template (arcane_template or arcane_beamer)
2. Enter organization domain (e.g., com.mycompany)
3. Enter app name (e.g., my_awesome_app)
4. Choose Firebase integration (yes/no)
5. Choose Google Cloud Run deployment (yes/no)

The wizard creates everything automatically!

### Development

```bash
# Run your app
cd my_awesome_app
flutter run

# Run on specific device
flutter run -d chrome          # Web browser
flutter run -d macos           # macOS desktop
flutter run -d linux           # Linux desktop

# Hot reload is automatic - just save your files!
```

### Generate Assets

```bash
# From your app directory
cd my_awesome_app

# Generate new icons and splash
dart run gen_assets

# Or individually
dart run gen_icons
dart run gen_splash
```

### Deploy to Firebase

```bash
# Build and deploy web app
dart run deploy_web

# Deploy only Firestore rules
dart run deploy_firestore

# Deploy everything
dart run deploy_firebase
```

### Deploy Server to Cloud Run

```bash
cd my_awesome_app_server
./script_deploy.sh
```

---

## 🌟 What Makes This Different?

### vs. Standard Flutter Templates
- ✅ **No Material Design** - Pure Arcane UI framework
- ✅ **Production-ready architecture** - 3-project structure
- ✅ **Firebase pre-configured** - Security rules included
- ✅ **Backend server included** - Full-stack from the start
- ✅ **Complete automation** - One script does everything
- ✅ **Dart run scripts** - Common tasks accessible from IDE

### vs. Occult CLI
- ✅ **No Dart installation needed** - Pure Bash scripts
- ✅ **Modular, understandable** - Easy to customize
- ✅ **Better error handling** - Retry logic for all operations
- ✅ **More comprehensive** - Templates from real production code
- ✅ **Cross-platform** - Works on macOS and Linux

### vs. Other Templates
- ✅ **Real-world patterns** - From production MyGuide v12 app
- ✅ **User system included** - User, settings, capabilities
- ✅ **Authentication** - Signature-based server auth
- ✅ **Deployment scripts** - Docker + Cloud Run ready
- ✅ **Security best practices** - Firestore/Storage rules included

---

## 🛠️ Advanced Usage

### Skip Asset Generation

If you want to skip icon and splash screen generation:

```bash
# Edit generated project's pubspec.yaml to customize assets
# Then run generation manually when ready
cd my_app
dart run gen_assets
```

### Custom Platform Versions

```bash
# From project root after setup
./scripts/set_android_min_sdk.sh my_app 24
./scripts/set_ios_platform_version.sh my_app 14.0
./scripts/set_macos_platform_version.sh my_app 11.0
```

### Deploy Beta Hosting

1. Create beta site in Firebase Console:
   - Open: https://console.firebase.google.com/project/YOUR_PROJECT/hosting/sites
   - Click "Add another site"
   - Enter Site ID: `your-project-id-beta`

2. Deploy:
```bash
cd my_app
dart run deploy_hosting_beta
```

### Update Firebase Rules

After modifying `config/firestore.rules` or `config/storage.rules`:

```bash
cd my_app
dart run deploy_firestore   # Update Firestore rules
dart run deploy_storage     # Update Storage rules
```

---

## 🤝 Contributing

Contributions are welcome! Here's how:

1. **Fork** the repository
2. **Create** your feature branch (`git checkout -b feature/AmazingFeature`)
3. **Add** scripts to `scripts/lib/` with proper error handling
4. **Update** documentation (this README and scripts/README.md)
5. **Test** on both macOS and Linux
6. **Commit** your changes (`git commit -m 'Add AmazingFeature'`)
7. **Push** to the branch (`git push origin feature/AmazingFeature`)
8. **Open** a Pull Request

### Script Guidelines
- Use modular functions in `scripts/lib/`
- Add retry logic with `retry_command()` from `utils.sh`
- Include detailed logging (log_info, log_success, log_error)
- Support both macOS and Linux (sed, grep, find differences)
- Provide clear error messages and recovery suggestions

---

## 🐛 Troubleshooting

### Setup Issues

**"Command not found" errors:**
- The wizard checks prerequisites and provides installation instructions
- Follow the prompts to install missing tools

**Flutter pub get failures:**
- The wizard includes automatic retry logic
- Check your internet connection
- Try running `flutter pub cache repair`

**Firebase login issues:**
- Run `firebase login --reauth` to refresh authentication
- Make sure you have Owner or Editor role on Firebase project

### Build Issues

**Android build errors:**
```bash
cd my_app/android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

**iOS/macOS pod install errors:**
```bash
cd my_app
dart run pod_install_ios    # or pod_install_macos
```

**Web build errors:**
- Clear browser cache
- Run `flutter clean && flutter pub get`
- Check that you're using path URL strategy (already configured)

### Server Deployment Issues

**Docker build errors:**
- Make sure Docker daemon is running
- Check that you have enough disk space
- Verify Dockerfile syntax

**Cloud Run deployment errors:**
- Check that you're authenticated: `gcloud auth list`
- Verify project: `gcloud config get-value project`
- Check Cloud Run API is enabled in Google Cloud Console

---

## 📝 License

See [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **[Arcane Framework](https://github.com/ArcaneArts/arcane)** - Material Design-free Flutter UI
- **[Beamer Navigation](https://github.com/slovnicki/beamer)** - Declarative routing
- **[Flutter Team](https://flutter.dev)** - Amazing framework
- **Occult CLI** - Original inspiration for project automation

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/arcane_templates/issues)
- **Flutter Community**: [flutter.dev/community](https://flutter.dev/community)
- **Arcane Discord**: Ask in the Arcane community
- **Stack Overflow**: Tag with `flutter` and `arcane`

---

## ⭐ Star the Repo!

If you find this template useful, please consider giving it a star on GitHub!

---

**Ready to build something amazing with Arcane?** 🚀

```bash
./setup.sh
```

Choose your template, configure your project, and start building in minutes!
