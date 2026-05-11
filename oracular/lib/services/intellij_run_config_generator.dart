import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

/// Generates IntelliJ / Android Studio run configurations for Oracular
/// projects.
///
/// Two flavors of configs are emitted, both as **Shell Script**
/// (`ShConfigurationType`) — a built-in plugin in every modern JetBrains
/// IDE so no extra install is required:
///
/// 1. **Per-Jaspr-package** ([generate]) — written into
///    `<packageDir>/.idea/runConfigurations/`:
///    * `Serve.run.xml`     — `jaspr serve --port N`
///    * `Build.run.xml`     — `jaspr build`
///    * `Killall_NNNN.run.xml` — kills any process listening on the
///      configured port (rescue when `Serve` was force-stopped and the
///      port is still bound)
///
/// 2. **Per-project-root** ([generateDeploy]) — written into
///    `<projectDir>/.idea/runConfigurations/`:
///    * `Deploy_All.run.xml` — `oracular deploy all`
///
///    The deploy config lives at the project root (where
///    `config/setup_config.env` lives) because `oracular deploy all` is
///    template-agnostic and reads its config from the root. It works
///    for any Oracular project (Flutter, Jaspr, server-only, etc.), so
///    the template-copier wires it for all templates.
///
/// All XML follows the on-disk format IntelliJ writes itself when you
/// create a Shell Script run config via the UI — round-tripping through
/// the IDE won't shuffle/reformat our output and create phantom diffs.
///
/// Why a service instead of dropping XML into the template tree?
///
/// 1. The Jaspr port is a runtime parameter — we'd otherwise need
///    separate "Killall :8080.run.xml" / "Killall :3000.run.xml"
///    template variants, or post-process the file with
///    [PlaceholderReplacer] (which only knows about package-name
///    placeholders).
/// 2. The same generator is reused by `oracular update runs` to add
///    the configs to projects that were scaffolded by an older Oracular
///    version — without touching anything else.
class IntellijRunConfigGenerator {
  /// Default port for `jaspr serve` (matches Jaspr's own default).
  static const int defaultPort = 8080;

  /// Generate the three run configurations into
  /// `[packageDir]/.idea/runConfigurations/`.
  ///
  /// * [packageDir] is the root of the Jaspr package (the directory that
  ///   contains `pubspec.yaml` + `web/`).
  /// * [port] is baked into the **Serve** and **Killall** scripts.
  ///   `Build.run.xml` doesn't depend on the port.
  /// * [overwrite] (default: true) — if false, existing files are kept
  ///   so user edits aren't clobbered. The wizard scaffold path keeps
  ///   the default `true` so re-runs always emit fresh configs;
  ///   `oracular update runs` uses `true` as well so the user gets the
  ///   latest port baked in.
  ///
  /// Returns the list of files actually written. Empty list means every
  /// candidate already existed and `overwrite` was false.
  static Future<List<String>> generate({
    required String packageDir,
    int port = defaultPort,
    bool overwrite = true,
  }) async {
    final Directory runConfigsDir = Directory(
      p.join(packageDir, '.idea', 'runConfigurations'),
    );
    if (!runConfigsDir.existsSync()) {
      await runConfigsDir.create(recursive: true);
    }

    final Map<String, String> files = <String, String>{
      'Serve.run.xml': serveXml(port: port),
      'Build.run.xml': buildXml(),
      _killallFileName(port): killallXml(port: port),
    };

    final List<String> written = <String>[];
    for (final MapEntry<String, String> entry in files.entries) {
      final File f = File(p.join(runConfigsDir.path, entry.key));
      if (!overwrite && f.existsSync()) {
        verbose('  Skipping existing ${entry.key}');
        continue;
      }
      await f.writeAsString(entry.value);
      written.add(f.path);
      verbose('  Wrote ${f.path}');
    }
    return written;
  }

  /// Remove old "Killall :NNNN.run.xml" files that don't match the
  /// current [port]. Used by `oracular update runs --port` so a port
  /// change doesn't leave stale configs littering the IDE.
  ///
  /// Returns the list of file paths deleted.
  static Future<List<String>> pruneStaleKillallConfigs({
    required String packageDir,
    required int currentPort,
  }) async {
    final Directory runConfigsDir = Directory(
      p.join(packageDir, '.idea', 'runConfigurations'),
    );
    if (!runConfigsDir.existsSync()) return <String>[];

    final RegExp killallPattern =
        RegExp(r'^Killall_?\s*:?\s*(\d+)\.run\.xml$');
    final String currentName = _killallFileName(currentPort);

    final List<String> deleted = <String>[];
    await for (final FileSystemEntity entity in runConfigsDir.list()) {
      if (entity is! File) continue;
      final String name = p.basename(entity.path);
      if (name == currentName) continue;
      if (killallPattern.hasMatch(name)) {
        await entity.delete();
        deleted.add(entity.path);
        verbose('  Pruned stale ${entity.path}');
      }
    }
    return deleted;
  }

  /// Filename used for the killall config. Keeping the port in the
  /// filename means the IDE shows the user "Killall :8080" in the run
  /// configuration dropdown without needing to open the config first.
  static String _killallFileName(int port) => 'Killall_$port.run.xml';

  // ───────────────────────── Deploy run config ─────────────────────────

  /// Filename written by [generateDeploy].
  ///
  /// Underscored because IntelliJ's on-disk format uses `_` for spaces
  /// in config filenames (the display name is still "Deploy All").
  static const String deployAllFileName = 'Deploy_All.run.xml';

  /// Generate the project-level **Deploy All** run configuration into
  /// `[projectDir]/.idea/runConfigurations/`.
  ///
  /// Unlike [generate] (which targets a Jaspr web package), this writes
  /// to the **project root** — the directory that contains
  /// `config/setup_config.env`. That's because `oracular deploy all`
  /// reads its config from the root and orchestrates Firebase + server
  /// deployments for the whole project, regardless of which sub-package
  /// is currently focused in the IDE.
  ///
  /// * [projectDir] is the Oracular project root.
  /// * [overwrite] (default: true) — if false, existing
  ///   `Deploy_All.run.xml` is kept so user edits aren't clobbered.
  ///
  /// Returns the list of files actually written. Empty list means the
  /// candidate already existed and `overwrite` was false.
  static Future<List<String>> generateDeploy({
    required String projectDir,
    bool overwrite = true,
  }) async {
    final Directory runConfigsDir = Directory(
      p.join(projectDir, '.idea', 'runConfigurations'),
    );
    if (!runConfigsDir.existsSync()) {
      await runConfigsDir.create(recursive: true);
    }

    final File f = File(p.join(runConfigsDir.path, deployAllFileName));
    if (!overwrite && f.existsSync()) {
      verbose('  Skipping existing $deployAllFileName');
      return <String>[];
    }
    await f.writeAsString(deployAllXml());
    verbose('  Wrote ${f.path}');
    return <String>[f.path];
  }

  /// XML body for the `Deploy All` config (`oracular deploy all`).
  ///
  /// Working directory is `$PROJECT_DIR$` so the run uses whichever
  /// project root the user has open in IntelliJ — typically the
  /// Oracular project root that owns `config/setup_config.env`. The
  /// `oracular` CLI itself walks up looking for that file, so even
  /// nested package roots will resolve correctly as long as the
  /// project is somewhere in the ancestry.
  static String deployAllXml() {
    return _shConfig(
      name: 'Deploy All',
      scriptText: _xmlEscape('oracular deploy all'),
    );
  }

  // ────────────────────────── Jaspr config XML ──────────────────────────

  /// XML body for the `Serve` config.
  ///
  /// Uses `jaspr serve --port N` so editing this run config is enough to
  /// change the dev port; no env-var dance required.
  static String serveXml({required int port}) {
    final String script = _xmlEscape('jaspr serve --port $port');
    return _shConfig(
      name: 'Serve',
      scriptText: script,
    );
  }

  /// XML body for the `Build` config (`jaspr build`). Always builds the
  /// release web bundle into `build/jaspr/`. No port concerns here.
  static String buildXml() {
    return _shConfig(
      name: 'Build',
      scriptText: _xmlEscape('jaspr build'),
    );
  }

  /// XML body for the `Killall :PORT` config.
  ///
  /// The script is POSIX `/bin/sh`-compatible and works on macOS + most
  /// Linux distros (uses `lsof -ti`). It accepts an override port as the
  /// first script argument, so a power-user can tweak the run config's
  /// "Script Options" field to "3000" once and reuse the same config
  /// without regenerating. Default falls back to [port] if no arg given.
  static String killallXml({required int port}) {
    // Multi-line shell script encoded into IntelliJ's `value` attribute.
    // We embed actual newlines (\n) into the value via &#10; so the IDE
    // renders the script multi-line in the UI — IntelliJ strips literal
    // newlines from XML attribute values.
    final String raw = '''PORT="\${1:-$port}"
PIDS=\$(lsof -ti:\$PORT 2>/dev/null)
if [ -n "\$PIDS" ]; then
  echo "Killing processes on port \$PORT: \$PIDS"
  echo "\$PIDS" | xargs kill -9
  echo "Done."
else
  echo "No processes found on port \$PORT"
fi
''';
    return _shConfig(
      name: 'Killall :$port',
      scriptText: _xmlEscapeMultiline(raw),
    );
  }

  /// Build the actual `<configuration>` XML wrapper — every option below
  /// matches the on-disk format IntelliJ writes when you create a Shell
  /// Script run config via the UI. Mirroring it exactly means the IDE
  /// won't rewrite the file with a slightly different formatting on
  /// first open (which would create a phantom `git diff`).
  static String _shConfig({
    required String name,
    required String scriptText,
  }) {
    return '''<component name="ProjectRunConfigurationManager">
  <configuration default="false" name="${_xmlEscape(name)}" type="ShConfigurationType">
    <option name="SCRIPT_TEXT" value="$scriptText" />
    <option name="INDEPENDENT_SCRIPT_PATH" value="true" />
    <option name="SCRIPT_PATH" value="" />
    <option name="SCRIPT_OPTIONS" value="" />
    <option name="INDEPENDENT_SCRIPT_WORKING_DIRECTORY" value="true" />
    <option name="SCRIPT_WORKING_DIRECTORY" value="\$PROJECT_DIR\$" />
    <option name="INDEPENDENT_INTERPRETER_PATH" value="true" />
    <option name="INTERPRETER_PATH" value="/bin/sh" />
    <option name="INTERPRETER_OPTIONS" value="" />
    <option name="EXECUTE_IN_TERMINAL" value="true" />
    <option name="EXECUTE_SCRIPT_FILE" value="false" />
    <envs />
    <method v="2" />
  </configuration>
</component>
''';
  }

  /// Escape `&`, `<`, `>`, `"`, `'` for use inside an XML attribute value.
  static String _xmlEscape(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// Escape for an XML attribute value AND replace literal newlines with
  /// `&#10;` (IntelliJ uses the numeric entity to preserve multi-line
  /// shell scripts inside an attribute value).
  static String _xmlEscapeMultiline(String s) {
    return _xmlEscape(s).replaceAll('\n', '&#10;');
  }
}
