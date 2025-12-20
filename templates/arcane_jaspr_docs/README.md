# Arcane Jaspr Docs

Static documentation site built with Jaspr and Arcane UI.

## Development

```bash
# Install dependencies
dart pub get

# Run development server
jaspr serve

# Build for production
jaspr build
```

## Structure

- `content/` - Markdown documentation files
- `lib/components/` - Reusable UI components
- `lib/layouts/` - Page layouts
- `web/` - Static assets

## Adding Pages

1. Create a markdown file in `content/`:
   ```markdown
   ---
   title: My Page
   description: Page description
   layout: docs
   ---

   # My Page

   Content here...
   ```

2. Add navigation in `lib/components/docs_sidebar.dart`

## Deployment

Build and deploy to Firebase Hosting:

```bash
jaspr build && firebase deploy --only hosting
```
