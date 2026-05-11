import 'package:arcane/arcane.dart';

import 'app.dart';
import 'firebase_bridge.dart';

void main() async {
  // If the Jaspr host bootstrapped Firebase JS SDK, we reuse that
  // initialization on the Dart side instead of calling
  // `Firebase.initializeApp()` (which would fail with `duplicate-app`).
  await FirebaseBridge.maybeAdoptHostFirebase();

  runApp('arcane_jaspr_flutter_embed_app', const EmbeddedApp());
}
