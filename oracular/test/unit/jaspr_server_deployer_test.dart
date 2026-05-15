import 'dart:io';

import 'package:oracular/models/setup_config.dart';
import 'package:oracular/models/template_info.dart';
import 'package:oracular/services/jaspr_server_deployer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/process_runner_fakes.dart';

void main() {
  group('JasprServerDeployer.deploy', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'oracular_jaspr_deployer_',
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    SetupConfig configFor({
      JasprRenderMode mode = JasprRenderMode.ssr,
      String? projectId = 'test-project',
      String? serviceName,
    }) {
      return SetupConfig(
        appName: 'demo_app',
        orgDomain: 'com.test',
        baseClassName: 'DemoApp',
        template: TemplateType.arcaneJaspr,
        outputDir: tempDir.path,
        useFirebase: true,
        firebaseProjectId: projectId,
        jasprRenderMode: mode,
        jasprServerServiceName: serviceName,
      );
    }

    Future<void> scaffoldJaspr(SetupConfig cfg) async {
      final String webPath = p.join(cfg.outputDir, cfg.webPackageName);
      await Directory(webPath).create(recursive: true);
      // BuildOrchestrator.buildJasprServerImage looks for this file before
      // shelling out to docker build.
      await File(
        p.join(webPath, 'Dockerfile.jaspr'),
      ).writeAsString('FROM dart:stable');
    }

    /// Preflight successes: account (unset → no-op), AR API, Run API,
    /// AR repository describe (success → skip create). Total of 4
    /// scripted results, matching the order in [CloudRunPreflight.runAll].
    List<ProcessResult> preflightSuccesses() => <ProcessResult>[
      // gcloud config get-value account
      ProcessResult(exitCode: 0, stdout: '(unset)', stderr: ''),
      // gcloud services enable artifactregistry.googleapis.com
      ProcessResult(exitCode: 0, stdout: '', stderr: ''),
      // gcloud services enable run.googleapis.com
      ProcessResult(exitCode: 0, stdout: '', stderr: ''),
      // gcloud artifacts repositories describe oracular
      ProcessResult(exitCode: 0, stdout: '{}', stderr: ''),
    ];

    /// `git rev-parse --short HEAD` failing because the temp dir is not
    /// a git repo. Two of these get consumed in the happy path:
    /// one by BuildOrchestrator before the docker build, and one by
    /// JasprServerDeployer before the optional SHA-tag push.
    ProcessResult gitNotARepo() => ProcessResult(
      exitCode: 128,
      stdout: '',
      stderr: 'not a git repository',
    );

    test(
      'returns failure when render mode does not require Cloud Run',
      () async {
        final SetupConfig cfg = configFor(mode: JasprRenderMode.csr);
        await scaffoldJaspr(cfg);
        final CapturingProcessRunner runner = CapturingProcessRunner(
          <ProcessResult>[],
        );

        final JasprServerDeployer deployer = JasprServerDeployer(
          cfg,
          runner: runner,
        );
        final JasprServerDeployResult result = await deployer.deploy();

        expect(result.success, isFalse);
        expect(result.serviceUrl, isNull);
        expect(result.message, contains('does not'));
        expect(
          runner.invocations,
          isEmpty,
          reason: 'CSR projects must not shell out at all',
        );
      },
    );

    test('returns failure when firebaseProjectId is missing', () async {
      final SetupConfig cfg = configFor(projectId: null);
      await scaffoldJaspr(cfg);
      final CapturingProcessRunner runner = CapturingProcessRunner(
        <ProcessResult>[],
      );

      final JasprServerDeployer deployer = JasprServerDeployer(
        cfg,
        runner: runner,
      );
      final JasprServerDeployResult result = await deployer.deploy();

      expect(result.success, isFalse);
      expect(result.message, contains('FIREBASE_PROJECT_ID'));
      expect(runner.invocations, isEmpty);
    });

    test('returns failure when Jaspr project directory is missing', () async {
      final SetupConfig cfg = configFor();
      // Intentionally do NOT scaffold the web package directory.
      final CapturingProcessRunner runner = CapturingProcessRunner(
        <ProcessResult>[],
      );

      final JasprServerDeployer deployer = JasprServerDeployer(
        cfg,
        runner: runner,
      );
      final JasprServerDeployResult result = await deployer.deploy();

      expect(result.success, isFalse);
      expect(result.message, contains('not found'));
      expect(runner.invocations, isEmpty);
    });

    test('happy path runs preflight → build → push → deploy in order '
        'and returns the Cloud Run URL', () async {
      final SetupConfig cfg = configFor();
      await scaffoldJaspr(cfg);

      const String cloudRunUrl = 'https://demo-app-web-abc123-uc.a.run.app';

      final CapturingProcessRunner runner = CapturingProcessRunner(
        <ProcessResult>[
          ...preflightSuccesses(),
          // BuildOrchestrator: git rev-parse → not a git repo
          gitNotARepo(),
          // BuildOrchestrator: docker build -f Dockerfile.jaspr
          ProcessResult(exitCode: 0, stdout: '', stderr: ''),
          // docker push :latest
          ProcessResult(exitCode: 0, stdout: '', stderr: ''),
          // deployer: git rev-parse (for optional SHA push) → fail
          gitNotARepo(),
          // gcloud run deploy
          ProcessResult(exitCode: 0, stdout: '', stderr: ''),
          // gcloud run services describe → URL
          ProcessResult(exitCode: 0, stdout: cloudRunUrl, stderr: ''),
        ],
      );

      final JasprServerDeployer deployer = JasprServerDeployer(
        cfg,
        runner: runner,
      );
      final JasprServerDeployResult result = await deployer.deploy();

      expect(result.success, isTrue);
      expect(result.serviceUrl, equals(cloudRunUrl));
      expect(result.serviceName, equals('demo-app-web'));
      expect(result.region, equals('us-central1'));
      expect(
        result.imageTag,
        equals(
          'us-central1-docker.pkg.dev/test-project/oracular/'
          'demo-app-web:latest',
        ),
      );

      // Verify the gcloud / docker call order — the deploy is brittle
      // if these run out of sequence (e.g. push before build).
      final List<String> execs = runner.invocations
          .map((List<String> inv) => inv.first)
          .toList(growable: false);
      expect(
        execs,
        orderedEquals(<String>[
          'gcloud', // get-value account
          'gcloud', // services enable artifactregistry
          'gcloud', // services enable run
          'gcloud', // artifacts repositories describe
          'git', // rev-parse (BuildOrchestrator)
          'docker', // build
          'docker', // push :latest
          'git', // rev-parse (deployer SHA push)
          'gcloud', // run deploy
          'gcloud', // run services describe
        ]),
      );

      // Spot-check the docker build args — Dockerfile.jaspr + linux/amd64.
      final List<String> buildArgs = runner.invocations.firstWhere(
        (List<String> inv) => inv.first == 'docker' && inv.contains('build'),
      );
      expect(
        buildArgs,
        containsAllInOrder(<String>[
          'docker',
          'build',
          '--platform',
          'linux/amd64',
          '-f',
          'Dockerfile.jaspr',
        ]),
      );

      // And the gcloud run deploy args — service name, region, port,
      // unauthenticated, image tag.
      final List<String> deployArgs = runner.invocations.firstWhere(
        (List<String> inv) =>
            inv.first == 'gcloud' &&
            inv.length > 1 &&
            inv[1] == 'run' &&
            inv.length > 2 &&
            inv[2] == 'deploy',
      );
      expect(deployArgs, contains('--region=us-central1'));
      expect(deployArgs, contains('--allow-unauthenticated'));
      expect(deployArgs, contains('--port=8080'));
      expect(deployArgs, contains('--memory=512Mi'));
      expect(
        deployArgs,
        contains(
          '--image=us-central1-docker.pkg.dev/test-project/'
          'oracular/demo-app-web:latest',
        ),
      );
    });

    test('aborts on docker build failure without attempting push', () async {
      final SetupConfig cfg = configFor();
      await scaffoldJaspr(cfg);

      final CapturingProcessRunner runner = CapturingProcessRunner(
        <ProcessResult>[
          ...preflightSuccesses(),
          gitNotARepo(),
          // docker build fails
          ProcessResult(exitCode: 1, stdout: '', stderr: 'kaboom'),
        ],
      );

      final JasprServerDeployer deployer = JasprServerDeployer(
        cfg,
        runner: runner,
      );
      final JasprServerDeployResult result = await deployer.deploy();

      expect(result.success, isFalse);
      expect(result.message, contains('docker build failed'));
      // Verify push was NOT attempted: no `docker push` in invocations.
      final bool sawPush = runner.invocations.any(
        (List<String> inv) =>
            inv.first == 'docker' && inv.length > 1 && inv[1] == 'push',
      );
      expect(sawPush, isFalse);
    });

    test(
      'aborts on docker push failure without attempting gcloud run deploy',
      () async {
        final SetupConfig cfg = configFor();
        await scaffoldJaspr(cfg);

        final CapturingProcessRunner runner = CapturingProcessRunner(
          <ProcessResult>[
            ...preflightSuccesses(),
            gitNotARepo(),
            ProcessResult(exitCode: 0, stdout: '', stderr: ''), // docker build
            ProcessResult(exitCode: 1, stdout: '', stderr: 'AR auth missing'),
          ],
        );

        final JasprServerDeployer deployer = JasprServerDeployer(
          cfg,
          runner: runner,
        );
        final JasprServerDeployResult result = await deployer.deploy();

        expect(result.success, isFalse);
        expect(result.message, contains('docker push failed'));
        final bool sawRunDeploy = runner.invocations.any(
          (List<String> inv) =>
              inv.first == 'gcloud' &&
              inv.length > 2 &&
              inv[1] == 'run' &&
              inv[2] == 'deploy',
        );
        expect(sawRunDeploy, isFalse);
      },
    );

    test('aborts on gcloud run deploy failure', () async {
      final SetupConfig cfg = configFor();
      await scaffoldJaspr(cfg);

      final CapturingProcessRunner runner = CapturingProcessRunner(
        <ProcessResult>[
          ...preflightSuccesses(),
          gitNotARepo(),
          ProcessResult(exitCode: 0, stdout: '', stderr: ''), // docker build
          ProcessResult(exitCode: 0, stdout: '', stderr: ''), // docker push
          gitNotARepo(),
          ProcessResult(exitCode: 1, stdout: '', stderr: 'quota exhausted'),
        ],
      );

      final JasprServerDeployer deployer = JasprServerDeployer(
        cfg,
        runner: runner,
      );
      final JasprServerDeployResult result = await deployer.deploy();

      expect(result.success, isFalse);
      expect(result.message, contains('gcloud run deploy failed'));
    });

    test('respects custom jasprServerServiceName (and rewrites underscores '
        'to dashes for Cloud Run naming)', () async {
      final SetupConfig cfg = configFor(serviceName: 'custom_marketing_web');
      await scaffoldJaspr(cfg);

      const String url = 'https://custom-marketing-web-xyz789-uc.a.run.app';
      final CapturingProcessRunner runner =
          CapturingProcessRunner(<ProcessResult>[
            ...preflightSuccesses(),
            gitNotARepo(),
            ProcessResult(exitCode: 0, stdout: '', stderr: ''),
            ProcessResult(exitCode: 0, stdout: '', stderr: ''),
            gitNotARepo(),
            ProcessResult(exitCode: 0, stdout: '', stderr: ''),
            ProcessResult(exitCode: 0, stdout: url, stderr: ''),
          ]);

      final JasprServerDeployer deployer = JasprServerDeployer(
        cfg,
        runner: runner,
      );
      final JasprServerDeployResult result = await deployer.deploy();

      expect(result.success, isTrue);
      expect(result.serviceName, equals('custom-marketing-web'));
      expect(result.imageTag, contains('/custom-marketing-web:latest'));
    });

    test(
      'preflight short-circuit on wrong-project SA produces clear failure',
      () async {
        final SetupConfig cfg = configFor(projectId: 'project-a');
        await scaffoldJaspr(cfg);

        // Active account is an SA from a *different* project ⇒ preflight
        // returns false ⇒ deployer aborts before any docker/gcloud run.
        final CapturingProcessRunner runner = CapturingProcessRunner(
          <ProcessResult>[
            ProcessResult(
              exitCode: 0,
              stdout: 'svc@project-b.iam.gserviceaccount.com',
              stderr: '',
            ),
            // `gcloud auth list` invoked by preflight to suggest a fix.
            ProcessResult(
              exitCode: 0,
              stdout: 'svc@project-a.iam.gserviceaccount.com\nme@example.com',
              stderr: '',
            ),
          ],
        );

        final JasprServerDeployer deployer = JasprServerDeployer(
          cfg,
          runner: runner,
        );
        final JasprServerDeployResult result = await deployer.deploy();

        expect(result.success, isFalse);
        expect(result.message, contains('preflight failed'));
        // Confirm we never tried to build or push.
        final bool dockerInvoked = runner.invocations.any(
          (List<String> inv) => inv.first == 'docker',
        );
        expect(dockerInvoked, isFalse);
      },
    );
  });
}
