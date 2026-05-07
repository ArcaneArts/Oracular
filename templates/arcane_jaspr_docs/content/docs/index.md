---
title: Introduction
description: Primary documentation path for a Flutter-first Arcane Jaspr project
layout: kb
---

# Introduction

Use this docs template to document the primary Arcane Jaspr surface first.

## Primary Import

```dart
import 'package:arcane_jaspr/arcane_jaspr.dart';
```

## Advanced Imports

```dart
import 'package:arcane_jaspr/html.dart';
import 'package:arcane_jaspr/web.dart';
```

Keep advanced imports out of the default getting-started path unless the page is explicitly about those escape hatches.

## Same UI in Plain Jaspr

Use a plain Jaspr example early in the docs when you want to explain the baseline that Arcane Jaspr is trying to improve on.

```dart
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

dom.article(
  classes: 'rounded-xl border border-slate-200 bg-white p-6 shadow-sm',
  [
    dom.p(
      classes: 'text-sm font-medium uppercase tracking-[0.2em] text-slate-500',
      [text('Pro workspace')],
    ),
    dom.h2(
      classes: 'mt-3 text-2xl font-semibold text-slate-950',
      [text('Ship dashboards faster')],
    ),
    dom.p(
      classes: 'mt-3 text-sm leading-6 text-slate-600',
      [
        text(
          'Invite teammates, share reports, and manage releases with one workspace.',
        ),
      ],
    ),
    dom.div(
      classes: 'mt-5 flex gap-3',
      [
        dom.button(
          classes: 'rounded-md bg-slate-950 px-4 py-2 text-sm font-medium text-white',
          events: {'click': (_) {}},
          [text('Start trial')],
        ),
        dom.button(
          classes: 'rounded-md border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700',
          [text('Preview plans')],
        ),
      ],
    ),
  ],
)
```

## Build With Arcane Jaspr

Follow the plain Jaspr example with the Arcane version so readers can immediately see the Flutter-first intent.

```dart
import 'package:arcane_jaspr/arcane_jaspr.dart';

Card.outlined(
  fillWidth: true,
  child: Column(
    gap: 16,
    children: [
      const Text.label('Pro workspace'),
      const Text.heading2('Ship dashboards faster'),
      const Text.body(
        'Invite teammates, share reports, and manage releases with one workspace.',
      ),
      ButtonGroup(
        children: [
          Button.primary(
            label: 'Start trial',
            onPressed: () {},
            showArrow: true,
          ),
          Button.secondary(
            label: 'Preview plans',
            onPressed: () {},
          ),
        ],
      ),
    ],
  ),
)
```

## Comparison Guidance

- Plain Jaspr is DOM-first. It exposes tags, classes, and web event wiring directly.
- Arcane Jaspr is widget-first. It keeps layout, intent, and component variants on the surface.
- The recommended framing is Flutter parity: readers should understand that Arcane Jaspr exists to make common app UI code read closer to Flutter than to manual DOM composition.

## Suggested First Pages

- [Installation](/docs/installation)
- [Quick Start](/docs/quick-start)
- [Deployment Guide](/guides/deployment)
