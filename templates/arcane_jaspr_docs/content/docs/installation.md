---
title: Installation
description: Set up the docs site and align package examples with the primary Arcane Jaspr surface
layout: kb
previous:
  url: /docs
  title: Introduction
next:
  url: /docs/quick-start
  title: Quick Start
---

# Installation

Set up the docs site first, then keep package examples aligned with the primary Arcane Jaspr import surface.

## Install Dependencies

```bash
dart pub get
```

## Run the Docs Site

```bash
jaspr serve
```

## Build Static Output

```bash
jaspr build
```

## Package Example Rule

Use this import in normal examples:

```dart
import 'package:arcane_jaspr/arcane_jaspr.dart';
```

Only add these when a page is explicitly about advanced escape hatches:

```dart
import 'package:arcane_jaspr/html.dart';
import 'package:arcane_jaspr/web.dart';
```
