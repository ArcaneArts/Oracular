# Web Assets

This folder is served from `/assets/` at runtime.

## Required for full SEO

| File | Recommended size | Purpose |
| --- | --- | --- |
| `icon.png` | 512x512 PNG, transparent | Favicon, apple-touch-icon, PWA icon |
| `og-image.png` | 1200x630 PNG/JPG | Social-share preview (Facebook, LinkedIn, Discord, etc.) |
| `twitter-image.png` *(optional)* | 1200x630 PNG/JPG | Falls back to `og-image.png` if absent |

The site-wide defaults are referenced from:
- `web/index.html` (static fallback for crawlers without JS)
- `lib/seo/seo.dart` via `SeoConfig.defaultOgImage`

After deploying, run https://www.opengraph.xyz/ and https://cards-dev.twitter.com/validator
against your live URL to confirm all previews work.
