/// Application constants
class AppConstants {
  AppConstants._();

  /// Application name displayed in header & meta tags
  static const String appName = 'ArcaneJasprApp';

  /// Short tagline / meta description
  static const String appDescription =
      'A modern web application built with Jaspr and Arcane UI';

  /// GitHub repository URL (leave empty to hide GitHub link)
  static const String githubUrl = '';
}

/// Route constants for the application.
abstract class AppRoutes {
  static const String home = '/';
  static const String about = '/about';
}

/// API configuration.
abstract class ApiConfig {
  // Server API URL - update with your production URL
  static const String? serverApiUrl = null;
}

/// Site-wide SEO configuration.
///
/// All values here are baked into both the static `web/index.html`
/// (what crawlers without JS see) and the [Seo] widget (what JS-aware
/// crawlers and social previewers see after hydration).
///
/// Update these values when deploying to production. The placeholders
/// using `https://example.com` should be replaced with your real domain
/// for canonical URLs and OpenGraph share images to work correctly.
abstract class SeoConfig {
  /// The canonical, fully-qualified URL of your site (no trailing slash).
  ///
  /// Used for `<link rel="canonical">`, OpenGraph `og:url`, and JSON-LD
  /// `WebSite` schema. **Replace this with your real domain.**
  static const String siteUrl = 'https://example.com';

  /// Human-readable site name (used in OG `og:site_name` and JSON-LD).
  static const String siteName = AppConstants.appName;

  /// Default site-level description shown when no per-page description is set.
  static const String defaultDescription = AppConstants.appDescription;

  /// Default share image (absolute URL or path relative to [siteUrl]).
  ///
  /// 1200x630 PNG/JPG is the safest size for OG / Twitter card.
  static const String defaultOgImage = '/assets/og-image.png';

  /// BCP-47 language tag for the site (e.g. `en`, `en-US`, `de-DE`).
  static const String locale = 'en';

  /// OpenGraph locale (e.g. `en_US`).
  static const String ogLocale = 'en_US';

  /// Twitter handle for the site account, including `@` (or empty to omit).
  static const String twitterHandle = '';

  /// Theme color shown in mobile address bars / PWA installs.
  static const String themeColor = '#10b981';

  /// Background color while the loading screen is up.
  static const String backgroundColor = '#09090b';

  /// Organization or author name (used for JSON-LD `Organization` schema).
  static const String organizationName = AppConstants.appName;

  /// Organization logo URL (absolute or relative to [siteUrl]).
  static const String organizationLogo = '/assets/icon.png';

  /// Default robots policy. Use `noindex, nofollow` while in development.
  static const String defaultRobots = 'index, follow';

  /// Returns an absolute URL for [path].
  ///
  /// - If [path] is already absolute (starts with `http`), it is returned unchanged.
  /// - Otherwise it is appended to [siteUrl] (with a single `/` between them).
  static String absoluteUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final String trimmedSite = siteUrl.endsWith('/')
        ? siteUrl.substring(0, siteUrl.length - 1)
        : siteUrl;
    final String trimmedPath = path.startsWith('/') ? path : '/$path';
    return '$trimmedSite$trimmedPath';
  }
}
