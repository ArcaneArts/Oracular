---
title: Quick Start
description: Example page content for a Flutter-first Arcane Jaspr docs site
layout: kb
previous:
  url: /docs/installation
  title: Installation
---

# Quick Start

Use a simple counter app as the baseline example for the primary Arcane Jaspr surface.

```dart
import 'package:arcane_jaspr/arcane_jaspr.dart';

class CounterExample extends StatefulWidget {
  const CounterExample({super.key});

  @override
  State<CounterExample> createState() => _CounterExampleState();
}

class _CounterExampleState extends State<CounterExample> {
  int _count = 0;

  void _increment() {
    setState(() => _count += 1);
  }

  @override
  Widget build(BuildContext context) {
    return ArcaneBox(
      style: const ArcaneStyleData(
        display: Display.flex,
        flexDirection: FlexDirection.column,
        gap: Gap.md,
      ),
      children: [
        Text.heading3('Count: $_count'),
        Button.primary(
          label: 'Increment',
          onPressed: _increment,
        ),
      ],
    );
  }
}
```

Keep examples on this surface unless the page is explicitly about advanced HTML wrappers or raw Jaspr escape hatches.
