---
title: Welcome
description: Documentation for your project
layout: docs
---

# Welcome to the Documentation

This is your documentation site built with **Jaspr** and **Arcane UI**.

## Features

- **Static Generation** - Pre-rendered HTML for fast loading
- **Markdown Support** - Write docs in Markdown with frontmatter
- **Arcane Theming** - Beautiful dark-first design
- **Table of Contents** - Auto-generated from headings
- **Navigation** - Sidebar with grouped sections

## Getting Started

Check out the [Installation](/docs/installation) guide to get started, or jump to the [Quick Start](/docs/quick-start) for a rapid overview.

## Structure

Your documentation is organized in the `content/` directory:

```
content/
  index.md          # This page
  docs/
    index.md        # /docs landing page
    installation.md # /docs/installation
    quick-start.md  # /docs/quick-start
  guides/
    deployment.md   # /guides/deployment
```

Each markdown file becomes a route based on its path.
