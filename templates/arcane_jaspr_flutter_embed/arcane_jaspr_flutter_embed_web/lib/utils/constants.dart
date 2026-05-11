/// Application constants for the embed host.
class AppConstants {
  AppConstants._();

  /// Site name displayed in header & meta tags.
  static const String appName = 'ArcaneJasprFlutterEmbedWeb';

  /// Short tagline / meta description.
  static const String appDescription =
      'A Jaspr static marketing site that hosts a Flutter web app at /app.';

  /// GitHub repository URL (leave empty to hide GitHub link).
  static const String githubUrl = '';

  /// Default mount path for the embedded Flutter web app.
  ///
  /// Must match `EMBEDDED_FLUTTER_MOUNT` in setup_config.env. Oracular's
  /// build pipeline assumes this path when invoking
  /// `flutter build web --base-href=<mount>/`.
  static const String embeddedFlutterMount = '/app';
}

/// Route constants for the Jaspr host.
abstract class AppRoutes {
  static const String home = '/';
  static const String about = '/about';
  static const String app = AppConstants.embeddedFlutterMount;
}
