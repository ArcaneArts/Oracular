/// The entrypoint for the **client** app (hydration).
library;

import 'package:jaspr/client.dart';

import 'main.client.options.dart';

void main() {
  // Initialize the client environment with generated options
  Jaspr.initializeApp(options: defaultClientOptions);

  // ClientApp automatically loads and renders all @client annotated components
  runApp(const ClientApp());
}
