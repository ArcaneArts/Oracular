import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:fast_log/fast_log.dart';
import 'package:web/web.dart' as web;

/// Bridge between the Jaspr-host-initialized Firebase JS SDK and the
/// Flutter guest's Dart-side Firebase wrappers.
///
/// When the host's `web/index.html` includes the Firebase JS SDK and
/// assigns `window.__ORACULAR_FIREBASE__ = firebase.initializeApp(...)`,
/// this class lets the Flutter guest reuse that initialized app rather
/// than calling `Firebase.initializeApp()` itself (which would throw
/// `duplicate-app`).
///
/// If the host did not initialize Firebase (the template ships with the
/// initialization block commented out), this bridge is a no-op and the
/// caller can fall back to its own `Firebase.initializeApp` flow.
///
/// **Why a bridge?** Two reasons:
///   1. Avoid the duplicate-app crash when both packages bootstrap the
///      same FirebaseConfig.
///   2. Share a single auth session between the Jaspr-rendered marketing
///      pages and the Flutter app, so users only sign in once.
class FirebaseBridge {
  FirebaseBridge._();

  /// Returns `true` when `window.__ORACULAR_FIREBASE__` is present.
  static bool get hostInitializedFirebase {
    try {
      // Probe `window['__ORACULAR_FIREBASE__']` through `dart:js_interop`.
      // We deliberately avoid `package:web`'s `hasProperty` because it is
      // not part of the public Window surface in the current SDK; instead
      // we treat the window as a generic JSObject for property access.
      final web.Window win = web.window;
      final JSAny? value = (win as JSObject).getProperty<JSAny?>(
        '__ORACULAR_FIREBASE__'.toJS,
      );
      return value != null;
    } catch (_) {
      return false;
    }
  }

  /// If the Jaspr host bootstrapped Firebase JS SDK, do whatever Dart-side
  /// wiring is needed (e.g. delaying `Firebase.initializeApp` so it
  /// resolves to the existing default app).
  ///
  /// Implementation note: until the Dart-side wrappers expose a way to
  /// adopt an externally-initialized JS app, this method only logs that
  /// the host's FirebaseApp is reachable. Once `firebase_core_web` exposes
  /// `FirebaseAppPlatform.adoptDefaultApp`, replace the log with an
  /// adoption call.
  static Future<void> maybeAdoptHostFirebase() async {
    if (hostInitializedFirebase) {
      verbose('FirebaseBridge: host has already initialized Firebase JS SDK; '
          'guest will reuse the default app at runtime.');
    } else {
      verbose('FirebaseBridge: host did NOT initialize Firebase; '
          'guest can call Firebase.initializeApp() directly if needed.');
    }
  }
}
