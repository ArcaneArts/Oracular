// No-op shim for `fire_crud_gen`. Provided as a `dependency_override` for
// Oracular-scaffolded Jaspr web/docs apps that depend on `arcane_models`.
//
// See `lib/artifact_gen.dart` (sibling shim package) for the full rationale.
// Same analyzer version conflict, same fix. The upstream `fire_crud` package's
// `build.yaml` references `package:fire_crud_gen/crud_builder.dart` with
// `auto_apply: dependents`. This shim satisfies that import with a no-op
// Builder so resolution succeeds.

import 'package:build/build.dart';

Builder modelCrudBuilder(BuilderOptions _) => _NoopBuilder();

class _NoopBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions =>
      const <String, List<String>>{};

  @override
  Future<void> build(BuildStep buildStep) async {}
}
