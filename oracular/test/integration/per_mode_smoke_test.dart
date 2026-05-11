@TestOn('vm')
library;

//
// Per-render-mode smoke harness for the 2026-05-10 build/deploy/
// rendering-modes plan (T10.1). For each `JasprRenderMode` plus the
// embed template, this test:
//
//   1. Builds a `SetupConfig` with mode + template paired correctly.
//   2. Verifies `ConfigGenerator` emits the right firebase.json
//      rewrite signature for the mode (CSR/SSG → SPA, SSR/Hybrid →
//      Cloud Run rewrites, Embed → /app/** carve-out).
//   3. Drives `BuildOrchestrator.buildJaspr()` / `buildJasprServerImage()`
//      / `buildEmbeddedFlutter()` against a capturing `ProcessRunner`
//      and asserts the *exact* commands that would run on a real
//      machine. No `flutter` / `jaspr` / `docker` binaries are
//      invoked — the harness is intentionally hermetic so it can run
//      in CI without external toolchains.
//
// The point isn't to replace per-service unit tests (config_generator_test,
// jaspr_server_deployer_test, server_setup_test). It's to lock the
// *pipeline shape* per mode so a refactor in one service can't silently
// break the per-mode contract documented in §3 of the plan.

import 'dart:convert';
import 'dart:io';

import 'package:oracular/models/setup_config.dart';
import 'package:oracular/models/template_info.dart';
import 'package:oracular/services/build_orchestrator.dart';
import 'package:oracular/services/config_generator.dart';
import 'package:oracular/utils/process_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Capturing ProcessRunner. Records every invocation and replays
/// scripted results in order. Mirrors the shape used by
/// `server_setup_test.dart` and `jaspr_server_deployer_test.dart` so the
/// codebase stays consistent.
class _CapturingRunner extends ProcessRunner {
  final List<ProcessResult> results;
  final List<List<String>> invocations = <List<String>>[];
  final List<String?> workingDirectories = <String?>[];

  _CapturingRunner(this.results) : super(showVerbose: false);

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool inheritStdio = false,
  }) async {
    invocations.add(<String>[executable, ...arguments]);
    workingDirectories.add(workingDirectory);
    if (results.isEmpty) {
      return ProcessResult(
        exitCode: 1,
        stdout: '',
        stderr: 'no scripted result',
      );
    }
    return results.removeAt(0);
  }

  @override
  Future<ProcessResult?> runWithRetry(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    String? operationName,
    bool? interactive,
  }) {
    return run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('oracular_per_mode_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  // Stand-in for `<output>/<webPackageName>/` so BuildOrchestrator's
  // `projectDir.existsSync()` checks pass. We don't actually need any of
  // the template content — every external command is intercepted by
  // _CapturingRunner.
  Future<Directory> stagedJasprProject({
    required String appName,
    required bool withDockerfile,
  }) async {
    final Directory hostDir =
        Directory(p.join(tempDir.path, '${appName}_web'))..createSync();
    if (withDockerfile) {
      await File(p.join(hostDir.path, 'Dockerfile.jaspr'))
          .writeAsString('# stub');
    }
    return hostDir;
  }

  // Same idea for the Flutter guest in `embed`.
  Future<Directory> stagedEmbedGuest({required String appName}) async {
    final Directory guestDir =
        Directory(p.join(tempDir.path, '${appName}_app'))..createSync();
    // Pre-create the build/web folder so the copy step has something to
    // walk. Drop a single index.html in there so the copy is non-empty.
    final Directory buildWebDir =
        Directory(p.join(guestDir.path, 'build', 'web'))
          ..createSync(recursive: true);
    await File(p.join(buildWebDir.path, 'index.html'))
        .writeAsString('<html></html>');
    return guestDir;
  }

  // Pre-stage the host's web/index.html with the bootstrap markers so
  // the post-build embed step can enable injection without raising.
  Future<void> stageEmbedHostIndex(Directory hostDir, {required String mount}) async {
    final Directory webDir = Directory(p.join(hostDir.path, 'web'))
      ..createSync(recursive: true);
    await File(p.join(webDir.path, 'index.html')).writeAsString(
      '<!DOCTYPE html>\n'
      '<html>\n<head></head>\n<body>\n'
      '<!-- ORACULAR_FLUTTER_BOOTSTRAP_BEGIN\n'
      '<script src="$mount/flutter_bootstrap.js" async></script>\n'
      'ORACULAR_FLUTTER_BOOTSTRAP_END -->\n'
      '</body>\n</html>\n',
    );
  }

  SetupConfig baseConfig({
    required JasprRenderMode mode,
    TemplateType template = TemplateType.arcaneJaspr,
    String? jasprServiceName,
  }) {
    return SetupConfig(
      appName: 'demo',
      orgDomain: 'com.test',
      baseClassName: 'Demo',
      template: template,
      outputDir: tempDir.path,
      useFirebase: true,
      firebaseProjectId: 'demo-proj',
      jasprRenderMode: mode,
      jasprServerServiceName: jasprServiceName,
    );
  }

  // ─── Per-mode build pipeline ───────────────────────────────────────────

  group('BuildOrchestrator.buildJaspr per render mode', () {
    test('CSR: jaspr build only', () async {
      await stagedJasprProject(appName: 'demo', withDockerfile: false);
      final SetupConfig config = baseConfig(mode: JasprRenderMode.csr);
      final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[
        ProcessResult(exitCode: 0, stdout: '', stderr: ''),
      ]);
      final BuildOrchestrator orch =
          BuildOrchestrator(config, runner: runner);

      final BuildStepResult result = await orch.buildJaspr();

      expect(result.status, BuildStepStatus.success);
      expect(runner.invocations.length, 1);
      expect(runner.invocations.first, <String>['jaspr', 'build']);
      expect(config.hasJasprServer, isFalse,
          reason: 'CSR must never produce a Cloud Run image.');
    });

    test('SSG: jaspr build only', () async {
      await stagedJasprProject(appName: 'demo', withDockerfile: false);
      final SetupConfig config = baseConfig(mode: JasprRenderMode.ssg);
      final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[
        ProcessResult(exitCode: 0, stdout: '', stderr: ''),
      ]);
      final BuildOrchestrator orch =
          BuildOrchestrator(config, runner: runner);

      final BuildStepResult result = await orch.buildJaspr();

      expect(result.status, BuildStepStatus.success);
      expect(runner.invocations.single, <String>['jaspr', 'build']);
      expect(config.hasJasprServer, isFalse,
          reason: 'SSG must not produce a Cloud Run image.');
    });

    test('SSR: jaspr build + docker build (via buildJasprServerImage)', () async {
      final Directory hostDir = await stagedJasprProject(
        appName: 'demo',
        withDockerfile: true,
      );
      final SetupConfig config = baseConfig(mode: JasprRenderMode.ssr);

      // Three scripted results:
      //   1. `jaspr build`            → success
      //   2. `git rev-parse HEAD`     → success, empty stdout (no SHA tag)
      //   3. `docker build ...`       → success
      final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[
        ProcessResult(exitCode: 0, stdout: '', stderr: ''),
        ProcessResult(exitCode: 0, stdout: '', stderr: ''),
        ProcessResult(exitCode: 0, stdout: '', stderr: ''),
      ]);
      final BuildOrchestrator orch =
          BuildOrchestrator(config, runner: runner);

      final BuildStepResult build = await orch.buildJaspr();
      final BuildStepResult image = await orch.buildJasprServerImage();

      expect(build.status, BuildStepStatus.success);
      expect(image.status, BuildStepStatus.success);
      expect(config.hasJasprServer, isTrue);

      // Jaspr build ran in the host project.
      expect(runner.invocations[0], <String>['jaspr', 'build']);
      expect(runner.workingDirectories[0], hostDir.path);

      // git rev-parse was called for the SHA tag (returns empty stdout so
      // only the `:latest` tag is applied).
      expect(runner.invocations[1].first, 'git');
      expect(runner.invocations[1], containsAllInOrder(<String>['rev-parse']));

      // Docker build was tagged for Cloud Run / Artifact Registry.
      final List<String> docker = runner.invocations[2];
      expect(docker.first, 'docker');
      expect(docker, contains('build'));
      expect(docker, contains('-f'));
      expect(docker, contains('Dockerfile.jaspr'));
      final String tagArg = docker.firstWhere(
        (String s) => s.contains('us-central1-docker.pkg.dev'),
        orElse: () => '',
      );
      expect(tagArg, isNotEmpty,
          reason: 'docker build must tag against Artifact Registry.');
      expect(tagArg, contains('/demo-proj/'));
    });

    test('Hybrid: same as SSR + ConfigGenerator emits dynamic-prefix rewrites',
        () async {
      final Directory hostDir = await stagedJasprProject(
        appName: 'demo',
        withDockerfile: true,
      );
      final SetupConfig config = baseConfig(
        mode: JasprRenderMode.hybrid,
      ).copyWith(
        hybridDynamicPrefixes: const <String>['/api', '/auth', '/admin'],
      );
      // jaspr build + git rev-parse + docker build (see SSR test above).
      final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[
        ProcessResult(exitCode: 0, stdout: '', stderr: ''),
        ProcessResult(exitCode: 0, stdout: '', stderr: ''),
        ProcessResult(exitCode: 0, stdout: '', stderr: ''),
      ]);
      final BuildOrchestrator orch =
          BuildOrchestrator(config, runner: runner);

      final BuildStepResult build = await orch.buildJaspr();
      final BuildStepResult image = await orch.buildJasprServerImage();

      expect(build.status, BuildStepStatus.success);
      expect(image.status, BuildStepStatus.success);
      expect(runner.invocations[0], <String>['jaspr', 'build']);
      expect(runner.workingDirectories[0], hostDir.path);

      // ConfigGenerator must emit a rewrite per prefix that targets the
      // Cloud Run service (mode-specific contract from T5.4 / T7.1).
      final List<Object?> rewrites = await _rewritesFor(config);
      final Set<String> sources = <String>{
        for (final Object? r in rewrites)
          (r as Map<String, dynamic>)['source'] as String,
      };
      for (final String prefix in <String>['/api', '/auth', '/admin']) {
        expect(
          sources.any((String s) => s.startsWith(prefix)),
          isTrue,
          reason: 'Hybrid mode must have a rewrite for $prefix',
        );
      }
    });
  });

  // ─── Embed template: Flutter web guest + Jaspr host ───────────────────

  group('BuildOrchestrator.buildEmbeddedFlutter (embed template)', () {
    test('Flutter build + copy + index.html injection', () async {
      final Directory hostDir = await stagedJasprProject(
        appName: 'demo',
        withDockerfile: false,
      );
      await stagedEmbedGuest(appName: 'demo');
      await stageEmbedHostIndex(hostDir, mount: '/app');

      final SetupConfig config = baseConfig(
        mode: JasprRenderMode.embed,
        template: TemplateType.arcaneJasprFlutterEmbed,
      );

      // One scripted result for `flutter build web ...`. The copy +
      // index.html injection runs in-process (no external command).
      final _CapturingRunner runner = _CapturingRunner(<ProcessResult>[
        ProcessResult(exitCode: 0, stdout: '', stderr: ''),
      ]);
      final BuildOrchestrator orch =
          BuildOrchestrator(config, runner: runner);

      final BuildStepResult result = await orch.buildEmbeddedFlutter();

      expect(result.status, BuildStepStatus.success);
      expect(runner.invocations.length, 1);
      final List<String> built = runner.invocations.single;
      expect(built[0], 'flutter');
      expect(built, containsAllInOrder(<String>['build', 'web', '--release']));
      expect(
        built.any((String s) => s.startsWith('--base-href=')),
        isTrue,
        reason: 'flutter build web must include --base-href',
      );
      // Flutter web bundle must be copied under the Jaspr host.
      final File copied = File(
        p.join(hostDir.path, 'web', 'app', 'index.html'),
      );
      expect(copied.existsSync(), isTrue,
          reason: 'Flutter guest must be copied into <host>/web/app/');

      // Bootstrap script must be uncommented post-build.
      final String index = await File(
        p.join(hostDir.path, 'web', 'index.html'),
      ).readAsString();
      expect(index, contains('<script src="/app/flutter_bootstrap.js"'));
      expect(index.contains('ORACULAR_FLUTTER_BOOTSTRAP_BEGIN'), isTrue,
          reason: 'idempotent markers must remain in index.html');
    });
  });

  // ─── ConfigGenerator per-mode firebase.json snapshot ──────────────────

  group('ConfigGenerator.firebase.json per render mode', () {
    test('CSR → SPA fallback ("**" → /index.html), no Cloud Run rewrites',
        () async {
      final SetupConfig config = baseConfig(mode: JasprRenderMode.csr);
      final List<Object?> rewrites = await _rewritesFor(config);
      expect(rewrites, isNotEmpty);
      expect(
        rewrites.every((Object? r) =>
            (r as Map<String, dynamic>)['destination'] != null),
        isTrue,
      );
      expect(
        rewrites.any((Object? r) =>
            (r as Map<String, dynamic>).containsKey('run')),
        isFalse,
        reason: 'CSR must not have any Cloud Run rewrites.',
      );
    });

    test('SSG → no Cloud Run rewrites (static pre-render)', () async {
      final SetupConfig config = baseConfig(mode: JasprRenderMode.ssg);
      final List<Object?> rewrites = await _rewritesFor(config);
      expect(
        rewrites.any((Object? r) =>
            (r as Map<String, dynamic>).containsKey('run')),
        isFalse,
        reason: 'SSG must not have any Cloud Run rewrites.',
      );
    });

    test('SSR → catch-all Cloud Run rewrite', () async {
      final SetupConfig config = baseConfig(mode: JasprRenderMode.ssr);
      final List<Object?> rewrites = await _rewritesFor(config);
      final bool hasCatchAllRun = rewrites.any((Object? r) {
        final Map<String, dynamic> m = r as Map<String, dynamic>;
        return m.containsKey('run') && m['source'] == '**';
      });
      expect(hasCatchAllRun, isTrue,
          reason: 'SSR must rewrite ** → run:<service>.');
    });

    test('Embed → /app/** carve-out for the Flutter SPA', () async {
      final SetupConfig config = baseConfig(
        mode: JasprRenderMode.embed,
        template: TemplateType.arcaneJasprFlutterEmbed,
      );
      final List<Object?> rewrites = await _rewritesFor(config);
      final bool hasFlutterAppRewrite = rewrites.any((Object? r) {
        final Map<String, dynamic> m = r as Map<String, dynamic>;
        final String? source = m['source'] as String?;
        return source != null && source.startsWith('/app');
      });
      expect(hasFlutterAppRewrite, isTrue,
          reason: 'Embed mode must rewrite /app/** to the Flutter SPA.');
    });
  });
}

/// Generate firebase.json into `config.outputDir` and return the
/// rewrites array for the *release* hosting target. Mirrors the helper
/// in `config_generator_test.dart` so the per-mode contract has a
/// single source of truth.
Future<List<Object?>> _rewritesFor(
  SetupConfig config, {
  String target = 'release',
}) async {
  final ConfigGenerator gen = ConfigGenerator(config);
  await gen.generateAll();
  final File file = File(p.join(config.outputDir, 'firebase.json'));
  expect(file.existsSync(), isTrue,
      reason: 'firebase.json must be generated');
  final Map<String, Object?> decoded =
      json.decode(await file.readAsString()) as Map<String, Object?>;
  final List<Object?> hosting = decoded['hosting']! as List<Object?>;
  final Map<String, Object?> selected = hosting
      .cast<Map<String, Object?>>()
      .firstWhere((Map<String, Object?> t) => t['target'] == target);
  return selected['rewrites']! as List<Object?>;
}
