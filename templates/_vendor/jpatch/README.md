# jpatch (vendored, pure-Dart)

This directory is a pure-Dart shim of [`jpatch`](https://pub.dev/packages/jpatch)
1.0.1 that is automatically vendored by Oracular into generated projects when
the project mixes a Jaspr (or other pure-Dart) target with the `arcane_models`
package.

## Why this exists

`jpatch` 1.0.1 (from `arcane.art`) declares a Flutter SDK dependency in its
`pubspec.yaml`, even though every line of its source code is pure Dart with
no Flutter usage. That single declaration cascades:

```
arcane_models -> artifact -> json_compress -> jpatch -> flutter (SDK)
fire_crud ----------------> json_compress -> jpatch -> flutter (SDK)
```

The chain prevents pure-Dart consumers (Jaspr SSR/SSG, Dart-only servers,
CLIs) from sharing models with Flutter clients.

## How Oracular uses it

When `oracular create` produces a project that combines
`TemplateType.arcaneJaspr` (or any future pure-Dart template) with
`createModels = true`, Oracular:

1. Copies this directory to `<project>/.oracular_deps/jpatch/`.
2. Adds a `dependency_overrides` entry to the Jaspr web app's `pubspec.yaml`
   pointing at that path.

The shim has the same library name, version (`1.0.2`, the next version after
the published `1.0.1`), and public API as the upstream package, so it is
swap-in compatible.

## Removing this workaround

Once a Flutter-free `jpatch >= 1.0.2` is published to pub.dev, the
`dependency_overrides` block in the generated Jaspr `pubspec.yaml` (and this
vendored copy) can be deleted.
