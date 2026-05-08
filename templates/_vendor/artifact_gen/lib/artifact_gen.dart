// No-op shim for `artifact_gen`. Provided as a `dependency_override` for
// Oracular-scaffolded Jaspr web/docs apps that depend on `arcane_models`.
//
// See pubspec.yaml in this directory for the full rationale. Short version:
// the published `artifact_gen` pins `analyzer ^8.0.0` while `jaspr_builder`
// pins `analyzer ^10.0.0`; that conflict makes resolution impossible. Models
// are generated separately inside the models package, so the web app does
// not need to re-run these builders. The `auto_apply: dependents` directive
// in the upstream `artifact` package's `build.yaml` would otherwise force
// build_runner to import `package:artifact_gen/artifact_gen.dart`. This shim
// satisfies that import with a Builder that produces no output.

import 'package:build/build.dart';

Builder artifactBuilderBuildRunner(BuilderOptions _) => _NoopBuilder();

class _NoopBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions =>
      const <String, List<String>>{};

  @override
  Future<void> build(BuildStep buildStep) async {}
}
