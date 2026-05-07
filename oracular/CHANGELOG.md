## 3.1.1

### Changed
- **Service account key prompt**: instead of asking the user to type a long
  absolute path (which the terminal input clips), Oracular now opens the
  destination folder in Finder/Explorer/file manager, instructs the user to
  drop their `*.json` key file into that folder, and auto-detects/renames it
  to `service-account.json`. Press Enter when done, or type `skip` to add it
  later. Multiple JSON files are disambiguated with a numbered picker.
- **Multi-select / picker viewport**: each major section in the wizard
  (Template Selection, Target Platforms, Additional Packages, Cloud Services)
  now starts with a clean screen and a compact context strip showing the
  choices made so far. Fixes the issue where pressing arrow keys inside the
  Target Platforms multi-select made the console "go up" and look awful as
  the prompt redrew over previously printed help text.

## 3.1.0

### Added
- Wizard intro now asks for the **target location** up front. Press Enter to use
  the current directory, type an absolute or relative path, or use `~` as a
  shortcut for your home directory. Missing directories can be auto-created.
- Pure-Dart `jpatch` shim vendored under `templates/_vendor/jpatch/` and
  auto-injected into Jaspr/Dart-CLI projects that depend on `arcane_models`,
  so pure-Dart targets resolve **without** dragging in the Flutter SDK.
- Spinner prompts now accept a `failedMessage` so failed steps render an `✗`
  with stderr output instead of a misleading `✓`.

### Changed
- Templates upgraded to `arcane_jaspr ^3.3.0` with `arcane_jaspr_shadcn` pulled
  via git from the monorepo. `app.dart` switched from `child:` to the new
  `home:` API.
- `arcane_jaspr_docs` template now references `arcane_jaspr_shadcn` and
  `arcane_lexicon` via git deps instead of brittle `.oracular_deps/...` paths.
- `arcane_models` template no longer pulls in `arcane_admin` (which dragged
  Flutter into pure-Dart consumers).
- `arcane_server` template uses `listenPortFromEnvironment()` from current
  `google_cloud`.
- Pinned `package_info_plus` / `launch_at_startup` / etc. across templates to
  versions that actually resolve, removed unused `interact` dep from
  `arcane_cli_app`.
- Spinner-wrapped CLI processes now run in non-interactive mode so they can't
  deadlock waiting for TTY input behind the spinner.

### Fixed
- **Firebase web app provisioning**: switched all `firebase apps:*` calls to
  `--json` mode with explicit success/failure detection, fixing the
  `Failed to create Firebase web app` / `Failed to list Firebase web apps`
  cascade when configuring FlutterFire for Jaspr projects.
- **Wizard reporting failures as success**: the wizard now tracks failed steps
  and prints a `✗ Project Created With Issues` banner with the list of failed
  steps when anything went wrong, instead of always printing the success box.
- **Spinner showing `✓ Done` on failure**: the spinner now renders `✗` with
  the actual error message on failure.
- **Jaspr + server + models permutation**: end-to-end resolution and
  compilation now works (no Flutter SDK leakage) and is covered by integration
  tests.
- `addModelsDependency` no longer skips the dependency when the package name
  appears in a comment, and no longer crashes on regex matches that span
  newlines.

## 3.0.0

### Added
- New `oracular gitignore` command to add the standard `.gitignore` to any project
  - Use `--force` or `-f` to overwrite an existing `.gitignore`
- Comprehensive `.gitignore` added to all templates with Jaspr support
- Jaspr-specific ignores: `.jaspr/`, `web/main.dart.js`, `web/main.dart.js.deps`, `web/main.dart.js.map`, `web/main.dart.mjs`

### Fixed
- Jaspr and models package creation now deletes the auto-generated `example/` folder

## 2.2.2

### Fixed
- Template download failing due to case sensitivity in GitHub archive prefix (`oracular-master` vs `Oracular-master`)

## 2.2.0

- **Template Updates - arcane_jaspr_docs**:
  - Full theme switching system with 18 theme presets (colors, neutrals, OLED)
  - CSS variable-based theming using `ArcaneThemeProvider`
  - Theme persistence via localStorage
  - Search functionality with keyboard navigation
  - Code block copy buttons
  - Stateful theme toggle (sun/moon icons)
  - Updated sidebar with `ArcaneSideContent` and modern styling
  - Removed index.html for static mode compatibility

- **Template Updates - arcane_jaspr_app**:
  - Added shared `AppHeader` component with theme toggle
  - Stateful `App` component with dark/light mode switching
  - CSS variable-based theming using `ArcaneThemeProvider`
  - Theme persistence via localStorage
  - Updated screens to use shared header (DRY)
  - Added `AppConstants` class for centralized configuration
  - Theme initialization script in index.html (prevents flash)
  - Modern scrollbar and focus state styling

## 2.1.0

- **CLI Improvements**:
  - Interactive prompts for project configuration
  - Template-specific next steps in success message

## 2.0.0

- **Template Distribution**: Templates are now downloaded from GitHub at runtime
  - No longer bundled in the package - keeps install size small
  - Cached locally at `~/.oracular/templates/`
  - Automatic version checking and updates
- **New `templates` command**: Manage template cache
  - `oracular templates status` - Show cache status
  - `oracular templates update` - Download/update templates
  - `oracular templates clear` - Clear the cache
  - `oracular templates path` - Show cache location
- **CLI Framework**: Migrated to darted_cli
- **Script Runner**: Fuzzy matching with abbreviation support
- **Complete rewrite** of project scaffolding system

## 1.0.0

- Initial version.
