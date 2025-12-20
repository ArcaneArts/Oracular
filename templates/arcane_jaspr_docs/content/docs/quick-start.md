---
title: Quick Start
description: Get up and running in 5 minutes
layout: docs
previous:
  url: /docs/installation
  title: Installation
---

# Quick Start

Get your first documentation page live in under 5 minutes.

## Create a New Page

Add a new markdown file to the `content/` directory:

```markdown
---
title: My New Page
description: A brief description
layout: docs
---

# My New Page

Your content here.
```

## Frontmatter

Each page starts with YAML frontmatter:

| Field | Description |
|-------|-------------|
| `title` | Page title (used in header and navigation) |
| `description` | Brief description for meta tags |
| `layout` | Layout to use (`docs` for documentation) |
| `previous` | Optional link to previous page |
| `next` | Optional link to next page |

## Markdown Features

The documentation supports standard Markdown plus:

### Code Blocks

Use triple backticks with a language identifier:

```dart
void main() {
  print('Hello, Jaspr!');
}
```

### Headings

Headings automatically get anchor links and appear in the table of contents.

### Links

Both internal and external links work:

- [Internal link](/docs)
- [External link](https://jaspr.site)

## Update Navigation

Edit `lib/components/docs_sidebar.dart` to add your page to the navigation:

```dart
SidebarItem(
  label: 'My New Page',
  icon: Icons.file,
  href: '/docs/my-new-page',
  active: currentPath == '/docs/my-new-page',
),
```

## Deploy

Build and deploy to any static hosting:

```bash
jaspr build
# Upload build/jaspr/ to your host
```
