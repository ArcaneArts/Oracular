/// The entrypoint for the **server** app (static generation).
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_content/jaspr_content.dart';
import 'package:fast_log/fast_log.dart';

import 'layouts/arcane_docs_layout.dart';

import 'main.server.options.dart';

void main() {
  info('arcane_jaspr_docs starting (static mode)...');

  Jaspr.initializeApp(options: defaultServerOptions);

  runApp(
    ContentApp(
      parsers: [
        MarkdownParser(),
      ],
      loaders: [
        FilesystemLoader(directory: 'content'),
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

  success('arcane_jaspr_docs running');
}
