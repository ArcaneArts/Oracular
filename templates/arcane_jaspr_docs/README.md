# Arcane Jaspr Docs

Static documentation site built with Jaspr and Arcane Inkwell.

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
- `lib/main.server.dart` - Arcane Inkwell site configuration
- `lib/main.client.dart` - Client hydration entrypoint
- `web/` - Static assets

## Adding Pages

1. Create a markdown file in `content/`:
   ```markdown
   ---
   title: My Page
   description: Page description
   layout: kb
   ---

   # My Page

   Content here...
   ```

2. Arcane Inkwell builds sidebar navigation from your `content/` directory automatically.

## Deployment

Build and deploy to Firebase Hosting:

```bash
jaspr build && firebase deploy --only hosting
```
