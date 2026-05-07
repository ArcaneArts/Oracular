import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/setup_config.dart';
import '../models/template_info.dart';
import 'user_prompt.dart';

/// Shared setup guidance for post-create and deployment flows.
class SetupGuidance {
  static const String _firebaseConsoleBase =
      'https://console.firebase.google.com';
  static const String _firebaseHostingDocs =
      'https://firebase.google.com/docs/hosting';
  static const String _flutterFireSetupDocs =
      'https://firebase.google.com/docs/flutter/setup';
  static const String _flutterWebDeployDocs =
      'https://docs.flutter.dev/deployment/web';
  static const String _jasprDocs = 'https://docs.jaspr.site';
  static const String _cloudConsoleBase = 'https://console.cloud.google.com';

  static String projectGuidePath(SetupConfig config) {
    return p.join(config.outputDir, 'GET_STARTED.md');
  }

  static String mainProjectName(SetupConfig config) {
    return config.template.isJasprApp ? config.webPackageName : config.appName;
  }

  static String mainProjectPath(SetupConfig config) {
    return p.join(config.outputDir, mainProjectName(config));
  }

  static String mainProjectLabel(SetupConfig config) {
    return config.template.isJasprApp ? 'Web app' : 'Main application';
  }

  static bool supportsWebHosting(SetupConfig config) {
    return config.template.isJasprApp ||
        (config.template.isFlutterApp && config.platforms.contains('web'));
  }

  static String runCommand(SetupConfig config) {
    if (config.template.isFlutterApp) {
      return 'flutter run';
    }
    if (config.template.isJasprApp) {
      return 'jaspr serve';
    }
    return 'dart run bin/main.dart --help';
  }

  static List<String> createdProjectItems(SetupConfig config) {
    return <String>[
      '${mainProjectName(config)}/ - ${mainProjectLabel(config)}',
      if (config.template.isJasprDocs)
        '.oracular_deps/ - Local Arcane docs dependencies',
      if (config.createModels)
        '${config.modelsPackageName}/ - Shared models package',
      if (config.createServer)
        '${config.serverPackageName}/ - Server application',
      config.useFirebase
          ? 'config/ - Generated setup and Firebase configuration'
          : 'config/ - Generated setup configuration',
      'references/ - Arcane and project reference docs',
      'docs/ - Commands, how-to guides, troubleshooting',
      'GET_STARTED.md - Step-by-step setup guide',
    ];
  }

  static void printPostCreationChecklist(SetupConfig config) {
    UserPrompt.printDivider(title: 'Project Setup Checklist');

    final List<String> steps = <String>[
      'cd ${mainProjectPath(config)}',
      runCommand(config),
    ];

    if (config.useFirebase) {
      steps.add('cd ${config.outputDir}');
      steps.add('oracular deploy firebase-setup');
    }

    UserPrompt.printNumberedList(steps);

    if (config.useFirebase) {
      _printFirebaseChecklist(config);
    } else {
      _printEnableFirebaseLater(config);
    }

    if (config.template.isJasprDocs) {
      _printJasprDocsDependencyChecklist(config);
    }

    if (config.createServer) {
      _printServerChecklist(config);
    }

    print('');
    UserPrompt.printList(<String>[
      'Full setup guide: ${projectGuidePath(config)}',
      'Docs folder: ${p.join(config.outputDir, 'docs')}/',
      'Reopen the guide later with: oracular guide',
      'Open the docs folder with: oracular open docs',
    ]);
  }

  static void printHostingSuccess(SetupConfig config, {required bool beta}) {
    final String? projectId = config.firebaseProjectId;
    if (projectId == null) {
      return;
    }

    final String url = beta
        ? betaHostingUrl(projectId)
        : releaseHostingUrl(projectId);
    final String channel = beta ? 'beta' : 'release';

    print('');
    UserPrompt.printList(<String>[
      'Hosting channel: $channel',
      'Live URL: $url',
      linkLine('Hosting console', firebaseHostingConsoleUrl(projectId)),
    ]);
  }

  static void printBetaSiteHint(String projectId) {
    print('');
    UserPrompt.printList(<String>[
      'If this is your first beta deploy, create the beta site once:',
      '  firebase hosting:sites:create $projectId-beta --project $projectId',
      'Then retry: oracular deploy hosting-beta',
    ]);
  }

  static String linkLine(String label, String url) {
    return '$label: $url';
  }

  static String firebaseOverviewUrl(String projectId) {
    return '$_firebaseConsoleBase/project/$projectId/overview';
  }

  static String firebaseHostingConsoleUrl(String projectId) {
    return '$_firebaseConsoleBase/project/$projectId/hosting';
  }

  static String firebaseAuthenticationConsoleUrl(String projectId) {
    return '$_firebaseConsoleBase/project/$projectId/authentication';
  }

  static String firebaseFirestoreConsoleUrl(String projectId) {
    return '$_firebaseConsoleBase/project/$projectId/firestore';
  }

  static String firebaseStorageConsoleUrl(String projectId) {
    return '$_firebaseConsoleBase/project/$projectId/storage';
  }

  static String firebaseServiceAccountUrl(String projectId) {
    return '$_firebaseConsoleBase/project/$projectId/settings/serviceaccounts/adminsdk';
  }

  static String cloudRunConsoleUrl(String projectId) {
    return '$_cloudConsoleBase/run?project=$projectId';
  }

  static String releaseHostingUrl(String projectId) {
    return 'https://$projectId.web.app';
  }

  static String betaHostingUrl(String projectId) {
    return 'https://$projectId-beta.web.app';
  }

  static void _printFirebaseChecklist(SetupConfig config) {
    final String? projectId = config.firebaseProjectId;
    if (projectId == null) {
      return;
    }

    UserPrompt.printDivider(title: 'Firebase & Hosting');

    final List<String> deploySteps = <String>[
      'oracular deploy firestore',
      'oracular deploy storage',
      if (supportsWebHosting(config)) 'oracular deploy hosting',
      if (supportsWebHosting(config)) 'oracular deploy hosting-beta',
    ];

    UserPrompt.printNumberedList(deploySteps);

    if (!supportsWebHosting(config)) {
      print('');
      UserPrompt.printList(<String>[
        'Web hosting is currently unavailable because web is not enabled.',
        'To add web support later:',
        '  cd ${mainProjectPath(config)}',
        '  flutter create --platforms=web .',
      ]);
    } else {
      printBetaSiteHint(projectId);
    }

    print('');
    print('Helpful links:');
    UserPrompt.printList(<String>[
      linkLine('Firebase project overview', firebaseOverviewUrl(projectId)),
      linkLine('Hosting console', firebaseHostingConsoleUrl(projectId)),
      linkLine('Firebase Hosting docs', _firebaseHostingDocs),
      linkLine('Release URL (after deploy)', releaseHostingUrl(projectId)),
      linkLine('Beta URL (after deploy)', betaHostingUrl(projectId)),
      if (config.template.isFlutterApp)
        linkLine('Flutter web deployment docs', _flutterWebDeployDocs),
      if (config.template.isJasprApp) linkLine('Jaspr docs', _jasprDocs),
    ]);
  }

  static void _printEnableFirebaseLater(SetupConfig config) {
    final String configPath = p.join(
      config.outputDir,
      'config',
      'setup_config.env',
    );

    UserPrompt.printDivider(title: 'Enable Firebase Later');
    UserPrompt.printList(<String>[
      'Edit $configPath and set:',
      '  USE_FIREBASE=yes',
      '  FIREBASE_PROJECT_ID=<your-project-id>',
      'Then run: oracular deploy firebase-setup',
    ]);

    print('');
    print('Helpful links:');
    UserPrompt.printList(<String>[
      linkLine('Firebase console', _firebaseConsoleBase),
      linkLine('FlutterFire setup docs', _flutterFireSetupDocs),
    ]);
  }

  static void _printServerChecklist(SetupConfig config) {
    UserPrompt.printDivider(title: 'Server Deployment');
    final String serverServiceAccountPath = p.join(
      config.outputDir,
      config.serverPackageName,
      'service-account.json',
    );

    UserPrompt.printNumberedList(<String>[
      'cd ${p.join(config.outputDir, config.serverPackageName)}',
      './script_deploy.sh',
    ]);

    print('');
    UserPrompt.printList(<String>[
      'Use service account key file name: service-account.json',
      'Server key path: $serverServiceAccountPath',
      'When replacing keys, keep only the 2 latest backups (.bak.1 and .bak.2).',
    ]);

    if (config.firebaseProjectId != null) {
      print('');
      UserPrompt.printList(<String>[
        linkLine(
          'Service account keys',
          firebaseServiceAccountUrl(config.firebaseProjectId!),
        ),
      ]);
    }
  }

  static void _printJasprDocsDependencyChecklist(SetupConfig config) {
    final String depsPath = p.join(config.outputDir, '.oracular_deps');
    final String docsPubspec = p.join(
      config.outputDir,
      config.webPackageName,
      'pubspec.yaml',
    );

    UserPrompt.printDivider(title: 'Jaspr Docs Dependencies');
    UserPrompt.printList(<String>[
      'Local dependencies are copied to $depsPath.',
      'Keep .oracular_deps/ next to ${config.webPackageName}/.',
      'If you move folders, update path dependencies in $docsPubspec.',
    ]);
  }

  static Future<File> writeProjectGuide(SetupConfig config) async {
    final File guide = File(projectGuidePath(config));
    await guide.parent.create(recursive: true);
    await guide.writeAsString(projectGuideMarkdown(config));
    return guide;
  }

  static String projectGuideMarkdown(SetupConfig config) {
    final StringBuffer buffer = StringBuffer();
    final String mainPath = mainProjectPath(config);
    final String configPath = p.join(
      config.outputDir,
      'config',
      'setup_config.env',
    );

    buffer.writeln('# ${config.baseClassName} Setup Guide');
    buffer.writeln();
    buffer.writeln('Generated by Oracular for `${config.appName}`.');
    buffer.writeln();

    buffer.writeln('## 1. Open And Run');
    buffer.writeln();
    buffer.writeln('- Main project: `$mainPath`');
    buffer.writeln('- Run:');
    buffer.writeln();
    buffer.writeln('```bash');
    buffer.writeln('cd $mainPath');
    buffer.writeln(runCommand(config));
    buffer.writeln('```');
    buffer.writeln();

    buffer.writeln('## 2. Created Folders');
    buffer.writeln();
    for (final String item in createdProjectItems(config)) {
      buffer.writeln('- $item');
    }
    buffer.writeln();

    buffer.writeln('## 3. Oracular Commands');
    buffer.writeln();
    buffer.writeln('```bash');
    buffer.writeln('oracular guide');
    buffer.writeln('oracular open guide');
    buffer.writeln('oracular open app');
    buffer.writeln('oracular open root');
    if (config.useFirebase) {
      buffer.writeln('oracular open firebase');
      buffer.writeln('oracular open auth');
      buffer.writeln('oracular open firestore');
      buffer.writeln('oracular open storage');
      if (supportsWebHosting(config)) {
        buffer.writeln('oracular open hosting');
      }
    }
    if (config.createServer) {
      buffer.writeln('oracular open server');
      if (config.firebaseProjectId != null) {
        buffer.writeln('oracular open service-account');
        buffer.writeln('oracular open cloud-run');
      }
    }
    buffer.writeln('```');
    buffer.writeln();

    if (config.useFirebase && config.firebaseProjectId != null) {
      _writeFirebaseGuide(buffer, config);
    } else {
      buffer.writeln('## 4. Enable Firebase Later');
      buffer.writeln();
      buffer.writeln('- Edit `$configPath`.');
      buffer.writeln('- Set `USE_FIREBASE=yes`.');
      buffer.writeln('- Set `FIREBASE_PROJECT_ID=<your-project-id>`.');
      buffer.writeln('- Run `oracular deploy firebase-setup`.');
      buffer.writeln('- Open Firebase: <$_firebaseConsoleBase>');
      buffer.writeln();
    }

    if (config.createServer) {
      _writeServerGuide(buffer, config);
    }

    if (config.template.isJasprDocs) {
      buffer.writeln('## Jaspr Docs Dependencies');
      buffer.writeln();
      buffer.writeln(
        '- Local deps: `${p.join(config.outputDir, '.oracular_deps')}`',
      );
      buffer.writeln(
        '- Keep `.oracular_deps/` next to `${config.webPackageName}/`.',
      );
      buffer.writeln();
    }

    buffer.writeln('## Troubleshooting');
    buffer.writeln();
    buffer.writeln('- Check tools: `oracular check tools`');
    buffer.writeln('- Check Firebase tools: `oracular check firebase`');
    buffer.writeln(
      '- Regenerate Firebase config: `oracular deploy generate-configs`',
    );

    return buffer.toString();
  }

  static void _writeFirebaseGuide(StringBuffer buffer, SetupConfig config) {
    final String projectId = config.firebaseProjectId!;

    buffer.writeln('## 4. Firebase Setup');
    buffer.writeln();
    buffer.writeln('1. Open Firebase project overview:');
    buffer.writeln('   <${firebaseOverviewUrl(projectId)}>');
    buffer.writeln('2. Click **Build > Authentication > Get started**.');
    buffer.writeln('   <${firebaseAuthenticationConsoleUrl(projectId)}>');
    buffer.writeln(
      '3. Click **Build > Firestore Database > Create database** '
      'if your app needs Firestore.',
    );
    buffer.writeln('   <${firebaseFirestoreConsoleUrl(projectId)}>');
    buffer.writeln(
      '4. Click **Build > Storage > Get started** if your app uploads files.',
    );
    buffer.writeln('   <${firebaseStorageConsoleUrl(projectId)}>');
    if (supportsWebHosting(config)) {
      buffer.writeln('5. Click **Build > Hosting** to inspect deploys.');
      buffer.writeln('   <${firebaseHostingConsoleUrl(projectId)}>');
    }
    buffer.writeln();
    buffer.writeln('Then run:');
    buffer.writeln();
    buffer.writeln('```bash');
    buffer.writeln('cd ${config.outputDir}');
    buffer.writeln('oracular deploy firebase-setup');
    buffer.writeln('oracular deploy firestore');
    buffer.writeln('oracular deploy storage');
    if (supportsWebHosting(config)) {
      buffer.writeln('oracular deploy hosting');
      buffer.writeln('oracular deploy hosting-beta');
    }
    buffer.writeln('```');
    buffer.writeln();
  }

  static void _writeServerGuide(StringBuffer buffer, SetupConfig config) {
    final String serverPath = p.join(config.outputDir, config.serverPackageName);
    final String keyPath = p.join(serverPath, 'service-account.json');

    buffer.writeln('## Server Deployment');
    buffer.writeln();
    buffer.writeln('- Server project: `$serverPath`');
    buffer.writeln('- Service account key path: `$keyPath`');
    if (config.firebaseProjectId != null) {
      buffer.writeln('- Generate a service account key here:');
      buffer.writeln(
        '  <${firebaseServiceAccountUrl(config.firebaseProjectId!)}>',
      );
      buffer.writeln('- Cloud Run console:');
      buffer.writeln('  <${cloudRunConsoleUrl(config.firebaseProjectId!)}>');
    }
    buffer.writeln();
    buffer.writeln('Run:');
    buffer.writeln();
    buffer.writeln('```bash');
    buffer.writeln('cd $serverPath');
    buffer.writeln('./script_deploy.sh');
    buffer.writeln('```');
    buffer.writeln();
  }
}
