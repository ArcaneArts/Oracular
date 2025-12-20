---
title: Installation
description: How to install and set up the documentation site
layout: docs
previous:
  url: /docs
  title: Introduction
next:
  url: /docs/quick-start
  title: Quick Start
---

# Installation

Follow these steps to get the documentation site running locally.

## Prerequisites

Make sure you have the following installed:

- **Dart SDK** >= 3.10.0
- **Git** for version control

## Clone the Repository

```bash
git clone https://github.com/your-org/your-repo.git
cd your-repo
```

## Install Dependencies

```bash
dart pub get
```

## Run Development Server

```bash
dart run scripts/serve
```

Or using Jaspr directly:

```bash
jaspr serve
```

The site will be available at `http://localhost:8080`.

## Build for Production

```bash
jaspr build
```

This generates static files in `build/jaspr/` ready for deployment.

## Project Structure

```
your-project/
├── content/              # Markdown documentation
│   ├── index.md
│   └── docs/
├── lib/
│   ├── components/       # Reusable components
│   ├── layouts/          # Page layouts
│   └── main.server.dart  # Server entry point
├── web/                  # Static assets
└── pubspec.yaml          # Dependencies
```
