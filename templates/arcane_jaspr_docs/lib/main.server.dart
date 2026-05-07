/// The entrypoint for the **server** app (static generation).
library;

import 'package:arcane_jaspr_shadcn/arcane_jaspr_shadcn.dart';
import 'package:arcane_lexicon/arcane_lexicon.dart' hide runApp;
import 'package:jaspr/server.dart';
import 'main.server.options.dart';
import 'utils/constants.dart';

const String baseUrl = String.fromEnvironment('BASE_URL', defaultValue: '');

void main() async {
  Jaspr.initializeApp(options: defaultServerOptions);

  runApp(
    await KnowledgeBaseApp.create(
      config: SiteConfig(
        name: 'Arcane Jaspr Docs',
        description: 'Documentation for arcane_jaspr_docs',
        contentDirectory: 'content',
        baseUrl: baseUrl,
        githubUrl: AppConstants.githubUrl,
        searchEnabled: true,
        tocEnabled: true,
        themeToggleEnabled: true,
        pageNavEnabled: true,
        navigationBarEnabled: true,
        navigationBarPosition: KBNavigationBarPosition.top,
        defaultTheme: KBThemeMode.dark,
        showEditLink: true,
        editBranch: 'main',
      ),
      stylesheet: const ShadcnStylesheet(theme: ShadcnTheme.midnight),
    ),
  );
}
