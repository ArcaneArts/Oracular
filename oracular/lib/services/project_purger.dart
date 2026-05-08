import 'dart:io';

import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;

import '../models/setup_config.dart';
import '../models/template_info.dart';

/// Result of a [ProjectPurger.dryRun] call describing exactly what the
/// rebuild step would delete. Returned to the user so they can confirm
/// before any data is touched.
class PurgeReport {
  /// Absolute paths to directories that will be deleted on rebuild.
  final List<String> directoriesToDelete;

  /// Absolute paths that already do not exist (informational only).
  final List<String> alreadyMissing;

  /// Sanity-check guard: paths the purger refused to delete because they
  /// fall outside [SetupConfig.outputDir] or look suspicious. Always empty
  /// in practice — kept so unit tests can assert the purger is paranoid.
  final List<String> rejected;

  const PurgeReport({
    required this.directoriesToDelete,
    required this.alreadyMissing,
    required this.rejected,
  });

  bool get isEmpty =>
      directoriesToDelete.isEmpty &&
      alreadyMissing.isEmpty &&
      rejected.isEmpty;
}

/// Service that knows exactly which directories Oracular's wizard /
/// `create` flow added to [SetupConfig.outputDir] so they can be deleted
/// surgically without touching Firebase config, service-account JSON,
/// the saved `setup_config.env`, or any user-authored files.
///
/// Used by `oracular rebuild` and the wizard's "rebuild" affordance to
/// reset the scaffolding without forcing the user back through the
/// Firebase + IAM gauntlet.
class ProjectPurger {
  final SetupConfig config;
  final Directory _outputRoot;

  ProjectPurger(this.config) : _outputRoot = Directory(config.outputDir);

  // ──────────────────────────────────────────────────────────────────────
  // PUBLIC API
  // ──────────────────────────────────────────────────────────────────────

  /// Compute (without deleting) every directory the rebuild step would
  /// purge. Safe to call on partial / broken projects — missing entries
  /// are reported in [PurgeReport.alreadyMissing] instead of raising.
  PurgeReport dryRun() {
    final List<String> toDelete = <String>[];
    final List<String> missing = <String>[];
    final List<String> rejected = <String>[];

    for (final String candidate in _candidatePaths()) {
      final String abs = p.normalize(p.absolute(candidate));

      // Sanity check #1: must live inside outputDir.
      if (!_isInsideOutput(abs)) {
        rejected.add(abs);
        continue;
      }

      // Sanity check #2: must not be the outputDir itself.
      if (p.equals(abs, _outputRoot.path)) {
        rejected.add(abs);
        continue;
      }

      // Sanity check #3: must not be a Firebase artefact / config file.
      if (_isProtectedPath(abs)) {
        rejected.add(abs);
        continue;
      }

      if (Directory(abs).existsSync()) {
        toDelete.add(abs);
      } else {
        missing.add(abs);
      }
    }

    return PurgeReport(
      directoriesToDelete: toDelete,
      alreadyMissing: missing,
      rejected: rejected,
    );
  }

  /// Delete every directory listed in [PurgeReport.directoriesToDelete].
  /// Idempotent — directories that disappear between [dryRun] and [purge]
  /// are silently skipped. Returns the number of directories actually
  /// deleted.
  Future<int> purge({PurgeReport? plan}) async {
    final PurgeReport p = plan ?? dryRun();
    int deleted = 0;
    for (final String path in p.directoriesToDelete) {
      final Directory dir = Directory(path);
      if (!dir.existsSync()) {
        verbose('  Already gone: $path');
        continue;
      }
      try {
        await dir.delete(recursive: true);
        verbose('  Deleted: $path');
        deleted++;
      } catch (e) {
        warn('  Could not delete $path: $e');
      }
    }
    return deleted;
  }

  // ──────────────────────────────────────────────────────────────────────
  // INTERNALS
  // ──────────────────────────────────────────────────────────────────────

  /// All candidate paths the wizard /
  /// [TemplateCopier.copyAll] would have created. Order matters for the
  /// dry-run report — list in the same order the wizard scaffolded them
  /// so the user sees a familiar shape.
  Iterable<String> _candidatePaths() sync* {
    // 1. Main app — Jaspr uses webPackageName, Flutter/CLI use appName.
    final String mainAppName = config.template.isJasprApp
        ? config.webPackageName
        : config.appName;
    yield p.join(_outputRoot.path, mainAppName);

    // 2. Shared models package.
    if (config.createModels) {
      yield p.join(_outputRoot.path, config.modelsPackageName);
    }

    // 3. Server package.
    if (config.createServer) {
      yield p.join(_outputRoot.path, config.serverPackageName);
    }

    // 4. Vendored shim packages (.oracular_deps/jpatch, /artifact_gen, …).
    //    Always candidate-listed — present whenever Jaspr+models or
    //    pure-Dart+models was scaffolded; absent otherwise (and reported
    //    as already-missing).
    yield p.join(_outputRoot.path, '.oracular_deps');

    // 5. References folder copied verbatim from templates/references/.
    yield p.join(_outputRoot.path, 'references');
  }

  /// Whether [absPath] is inside [SetupConfig.outputDir]. Defends against
  /// path traversal in `appName` / `outputDir` by normalising both sides
  /// before comparison.
  bool _isInsideOutput(String absPath) {
    final String root = p.normalize(_outputRoot.path);
    if (absPath == root) return false;
    final String relative = p.relative(absPath, from: root);
    return !relative.startsWith('..') && !p.isAbsolute(relative);
  }

  /// Reject any path the wizard never creates as a managed directory:
  ///   * `config/`         — saved [SetupConfig]
  ///   * `docs/`           — generated docs
  ///   * `firebase.json`   — Firebase config
  ///   * `.firebaserc`     — Firebase project pin
  ///   * `firestore.rules` — security rules
  ///   * `firestore.indexes.json`
  ///   * `storage.rules`
  ///   * `*.json`          — service account keys (never auto-deleted)
  ///   * `GET_STARTED.md`  — generated guide (regenerated on rebuild)
  bool _isProtectedPath(String absPath) {
    final String name = p.basename(absPath).toLowerCase();
    const Set<String> protectedNames = <String>{
      'config',
      'docs',
      'firebase.json',
      '.firebaserc',
      'firestore.rules',
      'firestore.indexes.json',
      'storage.rules',
      'get_started.md',
    };
    if (protectedNames.contains(name)) return true;

    // Reject service-account JSON files at the output root.
    if (name.endsWith('.json') && p.equals(p.dirname(absPath), _outputRoot.path)) {
      return true;
    }
    return false;
  }
}
