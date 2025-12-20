/// The entrypoint for the **server** app (static generation).
library;

import 'package:jaspr/server.dart';
import 'package:jaspr_content/jaspr_content.dart';

import 'layouts/arcane_docs_layout.dart';

import 'main.server.options.dart';

void main() {
  Jaspr.initializeApp(options: defaultServerOptions);

  runApp(
    ContentApp(
      directory: 'content',
      parsers: [
        MarkdownParser(),
      ],
      layouts: [
        ArcaneDocsLayout(),
      ],
      extensions: [
        HeadingAnchorsExtension(),
        TableOfContentsExtension(),
      ],
    ),
  );
}
