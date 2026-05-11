# `setup.dart` — Full Usage Reference

`setup.dart` is the wizard-equivalent script that ships inside every
Oracular template ZIP. This document is the canonical flag reference;
it lives at `templates/SETUP_USAGE.md` in the
[oracular repo](https://github.com/ArcaneArts/oracular) and is mirrored
into the root of every released `<template>-v<X.Y.Z>.zip`.

> Looking for the per-ZIP overview? See `README.md` inside the ZIP.
> Looking for the source? See
> `scripts/setup_template_template.dart` in the oracular repo.

---

## Table of contents

- [Prerequisites](#prerequisites)
- [Argument summary](#argument-summary)
- [Required arguments](#required-arguments)
- [Optional arguments](#optional-arguments)
- [Oracular install offer](#oracular-install-offer)
- [Worked examples per template](#worked-examples-per-template)
- [Exit codes](#exit-codes)
- [FAQ](#faq)

---

## Prerequisites

| Tool | Minimum | Why |
|---|---|---|
| Dart SDK | **3.0** | `setup.dart` itself + `dart pub get`. |
| Flutter SDK | **3.22** | Only for Flutter templates (`arcane_app`, `arcane_beamer_app`, `arcane_dock_app`, `arcane_jaspr_flutter_embed`). |
| `unzip` / archive tool | any | Extract the released ZIP. |

`setup.dart` has **zero pub dependencies**. Just `dart run setup.dart`.

---

## Argument summary

```bash
dart run setup.dart \
  -n my_project           \   # --name      (required)
  -o com.example          \   # --org       (required)
  [-c MyProject]          \   # --class-name
  [-d ../my_project]      \   # --output-dir
  [-t arcane_app]         \   # --template
  [-R ssr]                \   # --render-mode    (Jaspr only)
  [-m]                    \   # --with-models
  [-s]                    \   # --with-server
  [-f]                    \   # --with-firebase
  [-p my-firebase-id]     \   # --firebase-project-id
  [-P android,ios,web]    \   # --platforms  (Flutter only)
  [--no-pub-get]                                  \
  [--install-oracular | --no-install-oracular]    \
  [--dry-run]             \
  [-y]                    \   # --yes (non-interactive)
  [-v]                    \   # --verbose
  [--no-color]            \
  [-h]                        # --help
```

---

## Required arguments

### `-n`, `--name <snake_case>`

Project name. Must be:

- Lowercase
- `snake_case` (letters, digits, underscores)
- Not a Dart reserved word (`class`, `import`, `void`, etc.)

The same value becomes the primary package's `name:` in `pubspec.yaml`
and is used as a substring inside file content and filenames everywhere
the template had `arcane_app` / `arcane_jaspr_app` / etc.

Companion packages derive their names from `--name`:

- `--with-models` → `<name>_models`
- `--with-server` → `<name>_server`
- Embed template's Jaspr-side host → `<name>_web`
- Embed template's Flutter-side guest → `<name>_app`

### `-o`, `--org <reverse.domain>`

Organization domain in reverse notation (`com.example`, `art.arcane`,
`io.github.username`). Used to derive:

- Android `applicationId` / package
- iOS / macOS `PRODUCT_BUNDLE_IDENTIFIER`
- Anywhere the template had `art.arcane.template`

---

## Optional arguments

### `-c`, `--class-name <PascalCase>`

Base PascalCase class name. Defaults to `snakeToPascal(--name)` (so
`my_app` becomes `MyApp`). Used as the prefix for generated class
names:

- `<className>App` for the primary widget
- `<className>Web` for the Jaspr host
- `<className>Server` for the server entry point
- `<className>Runner` for the CLI runner

### `-d`, `--output-dir <path>`

Where the project should land. Default: `.` (the current working
directory).

> `setup.dart` **refuses to write into the same directory the ZIP was
> extracted to.** Always pass `--output-dir` pointing somewhere else
> (e.g. `../my_project`) or `cd` somewhere neutral first.

### `-t`, `--template <name>`

Override the auto-detected template. Normally auto-detected from the
`VERSION` file inside the ZIP root. Use this only if you've moved
`setup.dart` to a directory without a `VERSION` file.

### `-R`, `--render-mode <mode>` *(Jaspr templates only)*

Sets the `jaspr.mode:` in the generated `pubspec.yaml` (jaspr_cli 0.20+
reads it from there) and mirrors the value in `jaspr.yaml` for older
versions. Valid values:

| Mode | Alias | jaspr.mode |
|---|---|---|
| `csr` | `client` | `client` |
| `ssg` | `static` | `static` |
| `ssr` | `server` | `server` |
| `hybrid` | `mixed` | `server` |
| `embed` | (locked for `arcane_jaspr_flutter_embed`) | `static` |

### `-m`, `--with-models`

Stage a `<name>_models/` companion package alongside the primary
project. Auto-wires it into the primary package's `pubspec.yaml` as a
`path: ../<name>_models` dependency.

When the template is Jaspr (`arcane_jaspr_app`, `arcane_jaspr_docs`,
`arcane_jaspr_flutter_embed`) or Dart-CLI (`arcane_cli_app`,
`arcane_server`), this also activates the bundled `_vendor/`
shims (`jpatch`, `artifact_gen`, `fire_crud_gen` where applicable) via
`dependency_overrides`.

> Looking for the models template payload? It lives in
> `arcane_models-v<X.Y.Z>.zip`. The packager bundles the right
> `_vendor/` shims into each Jaspr / CLI / server ZIP, but the
> `<name>_models` package source itself only ships in the dedicated
> ZIP or inside `arcane_templates_all-v<X.Y.Z>.zip`.

### `-s`, `--with-server`

Stage a `<name>_server/` companion package. Combined with
`--with-models`, the server pubspec also gets the models path-dep.

### `-f`, `--with-firebase`

Uncomment commented-out Firebase dependencies in the generated
`pubspec.yaml`: `firebase_core`, `firebase_auth`, `cloud_firestore`,
`firebase_storage`, `firebase_dart`, `arcane_fluf`, `arcane_auth`,
`fire_crud`. Requires `--firebase-project-id`.

### `-p`, `--firebase-project-id <id>`

Your Firebase project ID. Required when `--with-firebase` is set.
Validated against Firebase's documented format (lowercase, hyphens
allowed, 6-30 chars).

### `-P`, `--platforms <a,b,c>` *(Flutter templates only)*

Comma-separated subset of `android`, `ios`, `web`, `windows`, `macos`,
`linux`. Default = the template's full default set.

Note: `setup.dart` does **not** delete unused platform folders;
`flutter create` does. This flag is currently informational — the
generated project keeps all platform folders that the template
already had.

### `--no-pub-get`

Skip running `flutter pub get` / `dart pub get` at the end. Useful for:

- CI where you want to inspect generated files first
- Air-gapped machines (you'd run pub get manually with `--offline`)
- Speeding up `--dry-run`-like exploration

### `--install-oracular`

Install the matching `oracular` CLI at the end via
`dart pub global activate oracular <X.Y.Z>` without prompting. The
version is pinned to the template release version so `oracular` and
your templates stay in sync.

### `--no-install-oracular`

Skip the install offer entirely. Useful in CI. Without this flag,
non-TTY invocations skip the offer silently anyway, but explicit is
better than implicit.

### `--dry-run`

Show what `setup.dart` *would* do without touching the filesystem.
Useful to confirm flag combinations before committing. Implies
verbose-style output for the moves it would make.

### `-y`, `--yes`

Non-interactive. Skip every prompt and take defaults. Treated as
`--install-oracular` unless `--no-install-oracular` is also passed.

### `-v`, `--verbose`

Log every file touched (renames, content edits, vendor copies).

### `--no-color`

Disable ANSI color codes. Also respected if `$NO_COLOR` is set
([no-color.org](https://no-color.org/) convention).

### `-h`, `--help`

Print the inline help and exit.

---

## Oracular install offer

At the end of a successful run, `setup.dart` may offer to install the
`oracular` CLI. Behaviour:

| Flags | TTY? | Behaviour |
|---|---|---|
| (none) | yes | Prompt `[Y/n]` to install. |
| (none) | no (piped / CI) | Skip silently. |
| `--install-oracular` | any | Install without prompting. |
| `--no-install-oracular` | any | Skip without prompting. |
| `--yes` + (no install flags) | any | Treated as `--install-oracular`. |

When invoked, it runs:

```bash
dart pub global activate oracular <version>
```

…pinned to the template release version (so the CLI you get matches
the templates you just extracted). Failure to install is **non-fatal**;
your project is already scaffolded.

After install, `setup.dart` checks if `~/.pub-cache/bin` is on `PATH`
and prints a shell-aware export line if it isn't (bash / zsh / fish /
PowerShell).

---

## Worked examples per template

### `arcane_app` (Flutter, multi-platform)

```bash
unzip arcane_app-v3.5.0.zip -d /tmp/aa && cd /tmp/aa
dart run setup.dart \
  -n my_app -o com.example \
  -d ../my_app
```

With models + server + Firebase:

```bash
dart run setup.dart \
  -n my_app -o com.example \
  -d ../my_app \
  -m -s -f -p my-firebase-project
```

### `arcane_beamer_app` (Flutter + Beamer routing)

```bash
unzip arcane_beamer_app-v3.5.0.zip -d /tmp/ab && cd /tmp/ab
dart run setup.dart -n my_app -o com.example -d ../my_app
```

### `arcane_dock_app` (Desktop system tray)

```bash
unzip arcane_dock_app-v3.5.0.zip -d /tmp/ad && cd /tmp/ad
dart run setup.dart -n my_dock -o com.example -d ../my_dock
```

Desktop-only — pass `-P macos,windows,linux` if you'd like to remind
yourself, but the template already targets desktop by default.

### `arcane_cli_app` (Dart CLI)

```bash
unzip arcane_cli_app-v3.5.0.zip -d /tmp/cli && cd /tmp/cli
dart run setup.dart -n my_cli -o com.example -d ../my_cli
```

With models companion (uses `jpatch` shim):

```bash
dart run setup.dart -n my_cli -o com.example -d ../my_cli -m
```

### `arcane_jaspr_app` (Jaspr web app)

CSR (default-like):

```bash
unzip arcane_jaspr_app-v3.5.0.zip -d /tmp/jj && cd /tmp/jj
dart run setup.dart -n my_site -o com.example -d ../my_site -R csr
```

SSR (server-rendered):

```bash
dart run setup.dart -n my_site -o com.example -d ../my_site -R ssr
```

Hybrid + models + Firebase + auto-install oracular:

```bash
dart run setup.dart \
  -n my_site -o com.example -d ../my_site \
  -R hybrid -m -f -p my-firebase-id \
  --install-oracular
```

### `arcane_jaspr_docs` (Static documentation site)

```bash
unzip arcane_jaspr_docs-v3.5.0.zip -d /tmp/docs && cd /tmp/docs
dart run setup.dart -n my_docs -o com.example -d ../my_docs -R ssg
```

`ssg` is the default for docs; explicit is good for muscle memory.

### `arcane_jaspr_flutter_embed` (Jaspr host + Flutter guest)

```bash
unzip arcane_jaspr_flutter_embed-v3.5.0.zip -d /tmp/em && cd /tmp/em
dart run setup.dart -n my_site -o com.example -d ../my_site
```

This produces two siblings:

- `../my_site_web/` — the Jaspr host
- `../my_site_app/` — the Flutter guest, embeddable into the Jaspr
  pages

The `--render-mode` is implicitly `embed`.

### `arcane_models` (Standalone models package)

```bash
unzip arcane_models-v3.5.0.zip -d /tmp/mm && cd /tmp/mm
dart run setup.dart -n my_app -o com.example -d ../my_app_models
```

Produces a `<name>_models` package. Pair it with a Flutter / Jaspr /
CLI project that runs `setup.dart --with-models` and supplies the same
`--name` value.

### `arcane_server` (Shelf REST API)

```bash
unzip arcane_server-v3.5.0.zip -d /tmp/sv && cd /tmp/sv
dart run setup.dart -n my_app -o com.example -d ../my_app_server -m
```

Produces a `<name>_server` package. The `-m` adds a path-dep to a
sibling `<name>_models/` if you have one.

---

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success. |
| `64` | Usage error (bad / missing flag). |
| `65` | Validation error (bad `--name`, version mismatch, etc.). |
| `66` | Input file missing (template not found, setup script missing). |
| Other | Unexpected; surfaced from the underlying tool. |

---

## FAQ

**Q: Why does `setup.dart` refuse to write into its own dir?**

A: Because it copies the *contents* of that dir as the template
payload. Writing into the same dir would create infinite-recursion
edge cases.

**Q: Can I run `setup.dart` more than once on the same output dir?**

A: No. Re-runs are not idempotent; you'd end up with double-renamed
files and partial pubspec edits. Delete the output dir or pick a
fresh path.

**Q: I want a `--no-pub-get` plus offline `pub get` later. How?**

A:

```bash
dart run setup.dart … --no-pub-get
cd ../my_project
flutter pub get --offline    # or `dart pub get --offline`
```

**Q: I already have `oracular` installed at a different version. Will
the install offer downgrade it?**

A: No. If the detected version is **newer** than the template's
version, the prompt defaults to "No" and explains the situation. You
have to type `y` to downgrade.

**Q: Where do I find `<name>_models` and `<name>_server` ZIPs?**

A: They're separate per-template Release assets:

- `arcane_models-v<X.Y.Z>.zip`
- `arcane_server-v<X.Y.Z>.zip`

Or grab the bundle ZIP (`arcane_templates_all-v<X.Y.Z>.zip`) which
contains all 9 templates pre-grouped — `setup.dart`'s
`--with-models` / `--with-server` flags find them automatically.

**Q: Can I run `setup.dart` on Windows?**

A: Yes. PowerShell or cmd. The script handles path separators and
the install offer's `PATH` hint switches to PowerShell syntax.

**Q: How do I report a bug?**

A: <https://github.com/ArcaneArts/oracular/issues> — include the
contents of the `VERSION` file from the ZIP root.
