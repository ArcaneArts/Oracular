---
title: Deployment
description: Deploy your documentation to production
layout: docs
---

# Deployment

Deploy your static documentation site to various hosting providers.

## Firebase Hosting

The template includes Firebase Hosting configuration.

### Setup

1. Install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

3. Initialize (already done in template):
   ```bash
   firebase init hosting
   ```

### Deploy

Build and deploy in one command:

```bash
jaspr build && firebase deploy --only hosting
```

Or use the script:

```bash
dart run scripts/firebase_deploy
```

## Other Providers

Since the output is static HTML, you can deploy anywhere:

### Vercel

```bash
jaspr build
vercel deploy build/jaspr
```

### Netlify

```bash
jaspr build
netlify deploy --dir=build/jaspr --prod
```

### GitHub Pages

1. Build the site
2. Copy `build/jaspr/` contents to your `gh-pages` branch
3. Enable GitHub Pages in repository settings

## Environment Variables

For different environments, update `lib/utils/constants.dart`:

```dart
static const String baseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: '/',
);
```

Then build with:

```bash
jaspr build --define=BASE_URL=https://your-domain.com
```
