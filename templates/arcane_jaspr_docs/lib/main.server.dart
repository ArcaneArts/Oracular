/// The entrypoint for the **server** app (static generation).
library;

import 'package:arcane_inkwell/arcane_inkwell.dart' hide runApp;
import 'package:jaspr/server.dart';
import 'utils/constants.dart';

const String baseUrl = String.fromEnvironment('BASE_URL', defaultValue: '');

void main() async {
  Jaspr.initializeApp();

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
