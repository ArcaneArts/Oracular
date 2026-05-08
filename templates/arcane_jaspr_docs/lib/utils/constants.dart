/// Application constants for the documentation site.
///
/// SEO is handled automatically by [KnowledgeBaseApp] / `jaspr_content`:
///
/// - `<title>`, `<meta name="description">`, OpenGraph and Twitter Card
///   tags are emitted per page from each markdown file's YAML frontmatter
///   (e.g. `title`, `description`, `image`, `keywords`).
/// - `web/sitemap.xml` is regenerated at build time from the navigation
///   manifest by `arcane_lexicon`'s [SitemapGenerator] when [siteUrl] is set.
/// - `web/robots.txt` is shipped statically in the [web/] folder.
class AppConstants {
  AppConstants._();

  /// Site name displayed in header and title.
  static const String siteName = 'Arcane Jaspr Docs';

  /// Site description for meta tags. Used as fallback when a markdown page
  /// has no `description` frontmatter.
  static const String siteDescription = 'Documentation for arcane_jaspr_docs';

  /// GitHub repository URL (leave empty to hide GitHub link).
  static const String githubUrl = '';

  /// The canonical, fully-qualified URL of your site (no trailing slash).
  ///
  /// Used by [SitemapGenerator] to produce absolute `<loc>` URLs and by
  /// `web/robots.txt`. **Replace this with your real domain** once you
  /// know where the docs will be hosted.
  static const String siteUrl = 'https://example.com';

  /// Base URL for the site (for subdirectory hosting like GitHub Pages).
  /// Use '' for root hosting, or '/project-name' for subdirectory hosting.
  static const String baseUrl = '';
}
