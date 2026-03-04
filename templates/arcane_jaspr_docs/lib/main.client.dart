/// The entrypoint for the **client** app (hydration).
library;

import 'package:jaspr/client.dart';

void main() {
  // Initialize the client environment with generated options
  Jaspr.initializeApp();

  // ClientApp automatically loads and renders all @client annotated components
  runApp(const ClientApp());
}
