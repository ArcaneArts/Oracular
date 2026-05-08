---
title: Welcome
description: Flutter-first documentation starter for Arcane Jaspr projects
keywords: [arcane, jaspr, dart, documentation, flutter]
image: /assets/og-image.png
layout: kb
---

# Welcome

This template is set up to document a Flutter-first Arcane Jaspr project.
Use it to teach the primary `package:arcane_jaspr/arcane_jaspr.dart` surface first, and keep advanced HTML or raw Jaspr APIs clearly separated.

## Per-page SEO

Add YAML frontmatter to any markdown file to control SEO for that page. The
fields below are picked up automatically by `jaspr_content` and emitted as
`<title>`, `<meta name="description">`, OpenGraph, and Twitter Card tags:

```yaml
---
title: My Page Title
description: A short summary that appears in search results and link previews.
keywords: [keyword1, keyword2]
image: /assets/my-page-share.png   # 1200x630 recommended
---
```

`web/robots.txt` and `web/sitemap.xml` are shipped automatically -
update `siteUrl` in `lib/utils/constants.dart` to your real domain.

## Start Here

- [Installation](/docs/installation)
- [Quick Start](/docs/quick-start)
- [Deployment Guide](/guides/deployment)

## Documentation Rule

Code samples in this template should read like normal Flutter-style Arcane Jaspr code, not like low-level HTML or raw Jaspr code.
