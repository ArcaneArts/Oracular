# {{TEMPLATE_NAME}}

Oracular template release **v{{VERSION}}** (build `{{BUILD_ID}}`).

> This README ships inside every per-template ZIP. The packager
> substitutes `{{TEMPLATE_NAME}}`, `{{VERSION}}`, `{{BUILD_ID}}`,
> `{{VENDORED_SHIMS}}`, and `{{COMPANIONS}}` at build time.

---

## What this is

This ZIP contains:

- A copy of the [Oracular](https://github.com/ArcaneArts/oracular)
  `{{TEMPLATE_NAME}}` template at the source revision tagged
  `templates-v{{VERSION}}`.
- `setup.dart` — a self-contained, dependency-free script that
  scaffolds the template into a working project. Same end result as
  running `oracular create -y -t {{TEMPLATE_NAME}}` would produce, but
  with zero install required beyond the Dart SDK.
- `SETUP_USAGE.md` — the full flag reference for `setup.dart`.
- `VERSION` — build manifest (version, build-id, template name).
- `LICENSE` — Oracular license.
- `_vendor/` — bundled shim packages: **{{VENDORED_SHIMS}}**.
  Activated automatically by `setup.dart` when `--with-models` is set
  on a Jaspr or Dart-CLI template.

This file is generated; do not edit by hand inside a checked-out
repository. To change its layout, edit
`templates/RELEASE_README_TEMPLATE.md` in the
[oracular repo](https://github.com/ArcaneArts/oracular).

---

## How to use it

```bash
# 1. Extract somewhere outside the ZIP root.
unzip {{TEMPLATE_NAME}}-v{{VERSION}}.zip -d /tmp/{{TEMPLATE_NAME}}-extract
cd /tmp/{{TEMPLATE_NAME}}-extract

# 2. Run setup.dart, telling it where the final project should land.
dart run setup.dart \
  --name my_project \
  --org com.example \
  --output-dir ../my_project

# 3. Use the project.
cd ../my_project
# Flutter apps:
flutter run -d chrome
# Dart CLI / server / models:
dart run
```

> `setup.dart` refuses to write into the extracted ZIP root itself.
> Always point `--output-dir` somewhere outside.

`--name` is required and must be lowercase `snake_case`.
`--org` is required and must look like `com.example` (reverse domain).

If you skip `--output-dir` the project is created in the current
working directory, which is the extracted ZIP root unless you've
moved up first. Either pass `--output-dir ..` or `cd` somewhere
neutral first.

---

## Setup script flags

| Flag | Required | Description |
|---|---|---|
| `-n`, `--name <snake_case>` | yes | Project name (lowercase, snake_case). |
| `-o`, `--org <reverse.domain>` | yes | Organization domain. |
| `-c`, `--class-name <PascalCase>` | no | Base class name (derived from `--name` if omitted). |
| `-d`, `--output-dir <path>` | no | Where to write the project (default: `.`). |
| `-t`, `--template <name>` | no | Override auto-detected template (taken from `VERSION` file). |
| `-R`, `--render-mode <mode>` | Jaspr only | `csr`, `ssg`, `ssr`, `hybrid`, or `embed`. See *Render modes* below. |
| `-m`, `--with-models` | no | Stage an `<name>_models` companion package alongside. |
| `-s`, `--with-server` | no | Stage an `<name>_server` companion package alongside. |
| `-f`, `--with-firebase` | no | Uncomment Firebase deps in the generated `pubspec.yaml`. |
| `-p`, `--firebase-project-id <id>` | with `--with-firebase` | Your Firebase project ID. |
| `-P`, `--platforms <a,b,c>` | Flutter only | Subset like `android,ios,web`. Default is the template's max set. |
| `--no-pub-get` | no | Skip `flutter pub get` / `dart pub get` at the end. |
| `--install-oracular` | no | Install the matching `oracular` CLI without prompting. |
| `--no-install-oracular` | no | Skip the install offer entirely (CI-safe). |
| `--dry-run` | no | Show planned changes; touch nothing on disk. |
| `-y`, `--yes` | no | Non-interactive; takes all defaults. Implies `--install-oracular`. |
| `-v`, `--verbose` | no | Log every file touched. |
| `--no-color` | no | Disable ANSI colors. |
| `-h`, `--help` | no | Print full help. |

See `SETUP_USAGE.md` for examples per template.

---

## Render modes (Jaspr templates only)

Only `arcane_jaspr_app`, `arcane_jaspr_docs`, and
`arcane_jaspr_flutter_embed` use `--render-mode`. Map:

| Mode | `pubspec.yaml` `jaspr.mode` | Description |
|---|---|---|
| `csr` / `client` | `client` | Client-only build (`flutter build web`-equivalent for Jaspr). |
| `ssg` / `static` | `static` | Static site generation. Default for `arcane_jaspr_docs`. |
| `ssr` / `server` | `server` | Server-side rendering with a long-running process. |
| `hybrid` / `mixed` | `server` | SSR + client hydration. |
| `embed` | `static` | Reserved for `arcane_jaspr_flutter_embed`; ships dual-package output (a Flutter guest plus a Jaspr host). |

`setup.dart` patches the right `pubspec.yaml` and `jaspr.yaml` lines so
`jaspr_cli` picks the mode up automatically.

---

## Companion packages

Supported companions: **{{COMPANIONS}}**.

| Flag | Effect |
|---|---|
| `--with-models` | Stages `<name>_models/` as a sibling, wires it into the primary package's `pubspec.yaml` as a `path:` dep, and (Jaspr/CLI/server only) activates the bundled `jpatch` / `artifact_gen` / `fire_crud_gen` shims via `dependency_overrides`. |
| `--with-server` | Stages `<name>_server/` as a sibling. Combined with `--with-models`, the server pubspec also gets the models path-dep. |

If you didn't download the matching `arcane_models-v{{VERSION}}.zip`
or `arcane_server-v{{VERSION}}.zip`, `setup.dart` prints a friendly
hint pointing at the Release page rather than failing.

Alternatively, download the **bundle ZIP**
(`arcane_templates_all-v{{VERSION}}.zip`) which contains all 9
templates pre-grouped — `setup.dart`'s `--with-models` /
`--with-server` flags find their companions there automatically.

---

## Vendored shims

This ZIP includes: **{{VENDORED_SHIMS}}**.

These exist because Jaspr / Dart-CLI templates rely on
`build_runner`-style code generation that has an `analyzer ^7.x`
dependency, which conflicts with Jaspr's transitively-pinned
`analyzer ^10.x`. The shims publish minimal API-compatible package
versions that resolve under `analyzer 10`. They're activated only when
`--with-models` is set and only for the templates that need them.

You can inspect, fork, or replace them yourself — they're just
ordinary path-dep packages copied into
`<output-dir>/.oracular_deps/` and referenced via
`dependency_overrides` in the generated `pubspec.yaml`.

---

## Where to file bugs

- **Setup script issues** (anything between `dart run setup.dart` and
  the project being scaffolded): file under the
  [oracular issue tracker](https://github.com/ArcaneArts/oracular/issues)
  with the prefix `[setup.dart]`.
- **Template content issues** (the contents of the scaffolded project
  itself, not the setup flow): same tracker, prefix
  `[{{TEMPLATE_NAME}}]`.
- **Release / packaging issues** (missing files, wrong version
  numbers, corrupted ZIPs): same tracker, prefix `[release]`.

Include `VERSION` file contents in every report.

---

## License

The Oracular `LICENSE` file in this ZIP root applies to the template
payload + `setup.dart` itself. Generated project code is yours under
that same license.
