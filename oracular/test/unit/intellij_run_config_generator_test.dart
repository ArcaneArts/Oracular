import 'dart:io';

import 'package:oracular/services/intellij_run_config_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('IntellijRunConfigGenerator.generate', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp
          .createTemp('oracular_intellij_runconfig_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('writes Serve, Build, and Killall run configs into '
        '.idea/runConfigurations/ with the right filenames', () async {
      final List<String> written =
          await IntellijRunConfigGenerator.generate(packageDir: tempDir.path);

      expect(written, hasLength(3));
      final List<String> names =
          written.map((String f) => p.basename(f)).toList()..sort();
      expect(names, equals(<String>[
        'Build.run.xml',
        'Killall_8080.run.xml',
        'Serve.run.xml',
      ]));

      // All three live under the canonical IntelliJ runConfigurations dir.
      for (final String f in written) {
        expect(p.dirname(f), endsWith('${p.separator}.idea'
            '${p.separator}runConfigurations'));
        expect(File(f).existsSync(), isTrue);
      }
    });

    test('Serve config invokes `jaspr serve --port N` with the chosen '
        'port baked in', () async {
      await IntellijRunConfigGenerator.generate(
        packageDir: tempDir.path,
        port: 3000,
      );

      final String serve = await File(p.join(
        tempDir.path,
        '.idea',
        'runConfigurations',
        'Serve.run.xml',
      )).readAsString();

      expect(serve, contains('name="Serve"'));
      expect(serve, contains('type="ShConfigurationType"'),
          reason: 'must use the Shell Script run-config type so no '
              'extra plugin is needed');
      expect(serve, contains('jaspr serve --port 3000'));
      expect(serve, contains('EXECUTE_IN_TERMINAL'));
      expect(serve, contains(r'$PROJECT_DIR$'),
          reason: 'working dir should be the package root, not absolute');
    });

    test('Build config invokes `jaspr build` and is port-agnostic',
        () async {
      await IntellijRunConfigGenerator.generate(
        packageDir: tempDir.path,
        port: 4242,
      );

      final String build = await File(p.join(
        tempDir.path,
        '.idea',
        'runConfigurations',
        'Build.run.xml',
      )).readAsString();

      expect(build, contains('name="Build"'));
      expect(build, contains('jaspr build'));
      // Build does NOT mention port — it's a release build, not a
      // dev server.
      expect(build, isNot(contains('--port')));
    });

    test(
      'Killall config: filename includes port, script kills processes on '
      'that port via lsof + xargs, and falls back to the baked-in port '
      'if no script-options arg is provided',
      () async {
        await IntellijRunConfigGenerator.generate(
          packageDir: tempDir.path,
          port: 5555,
        );

        final File killallFile = File(p.join(
          tempDir.path,
          '.idea',
          'runConfigurations',
          'Killall_5555.run.xml',
        ));
        expect(killallFile.existsSync(), isTrue,
            reason: 'filename must encode the port');

        final String body = await killallFile.readAsString();
        expect(body, contains('name="Killall :5555"'));
        expect(body, contains('lsof -ti'));
        expect(body, contains('xargs kill -9'));
        // The shell `${1:-PORT}` pattern lets a power-user pass a
        // different port via "Script Options" without regenerating.
        expect(body, contains(r'${1:-5555}'),
            reason: 'must allow runtime override via script options arg');
      },
    );

    test('XML is well-formed for all three configs', () async {
      // Sanity: every generated file should round-trip through the
      // SDK's XML parser. Catches missed escaping (e.g. unescaped `&`
      // or `<` inside a SCRIPT_TEXT value).
      final List<String> written =
          await IntellijRunConfigGenerator.generate(
        packageDir: tempDir.path,
        port: 8080,
      );

      for (final String f in written) {
        final String body = await File(f).readAsString();
        expect(
          () => parseXml(body),
          returnsNormally,
          reason: '$f must be valid XML, got:\n$body',
        );
      }
    });

    test('overwrite=false keeps user-edited files', () async {
      // First pass: generate everything fresh.
      final List<String> first =
          await IntellijRunConfigGenerator.generate(packageDir: tempDir.path);
      expect(first, hasLength(3));

      // Pretend the user edited Serve.run.xml.
      final File serve = File(p.join(
        tempDir.path,
        '.idea',
        'runConfigurations',
        'Serve.run.xml',
      ));
      const String userEdit = '<!-- user edit -->';
      await serve.writeAsString(userEdit);

      // Second pass with overwrite=false: every file already exists,
      // so nothing is written.
      final List<String> second = await IntellijRunConfigGenerator.generate(
        packageDir: tempDir.path,
        overwrite: false,
      );
      expect(second, isEmpty);
      expect(await serve.readAsString(), equals(userEdit),
          reason: 'overwrite=false must preserve user edits');
    });

    test('overwrite=true (default) refreshes files even if they exist',
        () async {
      await IntellijRunConfigGenerator.generate(packageDir: tempDir.path);
      final File serve = File(p.join(
        tempDir.path,
        '.idea',
        'runConfigurations',
        'Serve.run.xml',
      ));
      const String userEdit = '<!-- user edit -->';
      await serve.writeAsString(userEdit);

      final List<String> rewritten =
          await IntellijRunConfigGenerator.generate(packageDir: tempDir.path);
      expect(rewritten, hasLength(3));
      expect(await serve.readAsString(), isNot(equals(userEdit)),
          reason: 'overwrite=true (default) must refresh the file');
      expect(await serve.readAsString(), contains('jaspr serve'));
    });

    test('creates the .idea/runConfigurations directory when missing',
        () async {
      // tempDir starts empty — no .idea, no runConfigurations.
      expect(
        Directory(p.join(tempDir.path, '.idea', 'runConfigurations'))
            .existsSync(),
        isFalse,
      );

      await IntellijRunConfigGenerator.generate(packageDir: tempDir.path);

      expect(
        Directory(p.join(tempDir.path, '.idea', 'runConfigurations'))
            .existsSync(),
        isTrue,
      );
    });
  });

  group('IntellijRunConfigGenerator.pruneStaleKillallConfigs', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp
          .createTemp('oracular_intellij_prune_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('removes Killall_NNNN.run.xml for stale ports but keeps the '
        'current one', () async {
      // First, generate configs for port 8080.
      await IntellijRunConfigGenerator.generate(
        packageDir: tempDir.path,
        port: 8080,
      );
      // Drop a stale config from a previous port.
      final File stale = File(p.join(
        tempDir.path,
        '.idea',
        'runConfigurations',
        'Killall_3000.run.xml',
      ));
      await stale.writeAsString('<!-- stale -->');
      expect(stale.existsSync(), isTrue);

      // Now prune for the current port (8080).
      final List<String> deleted =
          await IntellijRunConfigGenerator.pruneStaleKillallConfigs(
        packageDir: tempDir.path,
        currentPort: 8080,
      );

      expect(deleted, hasLength(1));
      expect(deleted.first, equals(stale.path));
      expect(stale.existsSync(), isFalse,
          reason: 'stale Killall_3000 should be deleted');
      expect(
        File(p.join(tempDir.path, '.idea', 'runConfigurations',
                'Killall_8080.run.xml'))
            .existsSync(),
        isTrue,
        reason: 'current Killall_8080 must be preserved',
      );
    });

    test('does not touch Serve / Build configs', () async {
      await IntellijRunConfigGenerator.generate(packageDir: tempDir.path);

      final List<String> deleted =
          await IntellijRunConfigGenerator.pruneStaleKillallConfigs(
        packageDir: tempDir.path,
        currentPort: 8080,
      );
      expect(deleted, isEmpty);

      for (final String name in <String>[
        'Serve.run.xml',
        'Build.run.xml',
        'Killall_8080.run.xml',
      ]) {
        expect(
          File(p.join(tempDir.path, '.idea', 'runConfigurations', name))
              .existsSync(),
          isTrue,
          reason: '$name must survive a prune',
        );
      }
    });

    test('returns an empty list when runConfigurations dir does not exist',
        () async {
      final List<String> deleted =
          await IntellijRunConfigGenerator.pruneStaleKillallConfigs(
        packageDir: tempDir.path,
        currentPort: 8080,
      );
      expect(deleted, isEmpty);
    });
  });

  group('IntellijRunConfigGenerator XML helpers', () {
    test('Serve XML escapes special characters that could appear in port',
        () {
      // Defensive: unlikely in practice, but if a future caller
      // passes a string-ish port, the XML must still be valid.
      final String body = IntellijRunConfigGenerator.serveXml(port: 8080);
      expect(() => parseXml(body), returnsNormally);
      expect(body, contains('jaspr serve --port 8080'));
    });

    test('Killall XML uses &#10; for newlines (IntelliJ multi-line script '
        'attribute convention)', () {
      final String body =
          IntellijRunConfigGenerator.killallXml(port: 9090);
      // The script body should include the newline entity at least
      // a few times — one per shell line.
      expect('&#10;'.allMatches(body).length, greaterThan(2));
      expect(() => parseXml(body), returnsNormally);
    });

    test('Deploy All XML invokes `oracular deploy all` and is well-formed',
        () {
      final String body = IntellijRunConfigGenerator.deployAllXml();
      expect(() => parseXml(body), returnsNormally);
      expect(body, contains('name="Deploy All"'));
      expect(body, contains('type="ShConfigurationType"'),
          reason: 'must use the Shell Script run-config type so no '
              'extra plugin is needed');
      expect(body, contains('oracular deploy all'),
          reason: 'must invoke the actual deploy command');
      expect(body, contains(r'$PROJECT_DIR$'),
          reason: 'working dir should be the project root, not absolute');
      expect(body, contains('EXECUTE_IN_TERMINAL'),
          reason: 'deploy is interactive (prompts for service account, '
              'permissions, etc.) so must run in the IDE terminal');
    });
  });

  group('IntellijRunConfigGenerator.generateDeploy', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp
          .createTemp('oracular_intellij_deploy_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('writes Deploy_All.run.xml into .idea/runConfigurations/',
        () async {
      final List<String> written =
          await IntellijRunConfigGenerator.generateDeploy(
        projectDir: tempDir.path,
      );

      expect(written, hasLength(1));
      expect(p.basename(written.first), equals('Deploy_All.run.xml'));
      expect(
        p.dirname(written.first),
        endsWith('${p.separator}.idea${p.separator}runConfigurations'),
      );
      expect(File(written.first).existsSync(), isTrue);

      final String body = await File(written.first).readAsString();
      expect(body, contains('name="Deploy All"'));
      expect(body, contains('oracular deploy all'));
    });

    test('creates the .idea/runConfigurations directory when missing',
        () async {
      // tempDir starts empty — no .idea, no runConfigurations.
      expect(
        Directory(p.join(tempDir.path, '.idea', 'runConfigurations'))
            .existsSync(),
        isFalse,
      );

      await IntellijRunConfigGenerator.generateDeploy(
        projectDir: tempDir.path,
      );

      expect(
        Directory(p.join(tempDir.path, '.idea', 'runConfigurations'))
            .existsSync(),
        isTrue,
      );
    });

    test('overwrite=false keeps user-edited Deploy_All.run.xml', () async {
      // First pass: generate fresh.
      final List<String> first =
          await IntellijRunConfigGenerator.generateDeploy(
        projectDir: tempDir.path,
      );
      expect(first, hasLength(1));

      // Pretend the user customized the deploy script.
      final File deploy = File(first.first);
      const String userEdit = '<!-- user customized -->';
      await deploy.writeAsString(userEdit);

      // Second pass with overwrite=false: file exists, nothing written.
      final List<String> second =
          await IntellijRunConfigGenerator.generateDeploy(
        projectDir: tempDir.path,
        overwrite: false,
      );
      expect(second, isEmpty);
      expect(await deploy.readAsString(), equals(userEdit),
          reason: 'overwrite=false must preserve user edits');
    });

    test('overwrite=true (default) refreshes Deploy_All.run.xml even if '
        'it exists', () async {
      await IntellijRunConfigGenerator.generateDeploy(
        projectDir: tempDir.path,
      );
      final File deploy = File(p.join(
        tempDir.path,
        '.idea',
        'runConfigurations',
        'Deploy_All.run.xml',
      ));
      const String userEdit = '<!-- user edit -->';
      await deploy.writeAsString(userEdit);

      final List<String> rewritten =
          await IntellijRunConfigGenerator.generateDeploy(
        projectDir: tempDir.path,
      );
      expect(rewritten, hasLength(1));
      expect(await deploy.readAsString(), isNot(equals(userEdit)),
          reason: 'overwrite=true (default) must refresh the file');
      expect(await deploy.readAsString(), contains('oracular deploy all'));
    });

    test('coexists with Jaspr generate() — both can target the same dir',
        () async {
      // Real scenario: a Jaspr web package ALSO has a Deploy config at
      // its root (e.g., when the Jaspr package IS the project root).
      // Both calls must work without stepping on each other.
      await IntellijRunConfigGenerator.generate(packageDir: tempDir.path);
      await IntellijRunConfigGenerator.generateDeploy(
        projectDir: tempDir.path,
      );

      final Directory configsDir = Directory(p.join(
        tempDir.path,
        '.idea',
        'runConfigurations',
      ));
      final List<String> names = configsDir
          .listSync()
          .whereType<File>()
          .map((File f) => p.basename(f.path))
          .toList()
        ..sort();
      expect(
        names,
        equals(<String>[
          'Build.run.xml',
          'Deploy_All.run.xml',
          'Killall_8080.run.xml',
          'Serve.run.xml',
        ]),
        reason: 'all 4 configs must coexist',
      );
    });
  });
}

/// Minimal XML parser sanity check.
///
/// Walks character-by-character with a state machine so quoted
/// attribute values (which may legally contain `>` after escaping or
/// `&` entities) don't trip us up, and so self-closing tags like
/// `<envs />` are correctly recognised. Returns void on success;
/// throws [FormatException] on malformed XML.
void parseXml(String body) {
  final List<String> stack = <String>[];
  int i = 0;
  while (i < body.length) {
    if (body[i] != '<') {
      i++;
      continue;
    }

    // Find the matching `>`, skipping over attribute values quoted
    // with " or '.
    int j = i + 1;
    bool inQuote = false;
    String quoteChar = '';
    while (j < body.length) {
      final String c = body[j];
      if (inQuote) {
        if (c == quoteChar) inQuote = false;
      } else if (c == '"' || c == "'") {
        inQuote = true;
        quoteChar = c;
      } else if (c == '>') {
        break;
      }
      j++;
    }
    if (j >= body.length) {
      throw FormatException('Unclosed `<` starting at offset $i');
    }

    final String inner = body.substring(i + 1, j);

    // Skip comments and processing instructions.
    if (inner.startsWith('!') || inner.startsWith('?')) {
      i = j + 1;
      continue;
    }

    final bool isClosing = inner.startsWith('/');
    final bool isSelfClosing = inner.endsWith('/');

    // Tag name is the first whitespace-delimited token, minus any
    // leading `/` (closing) or trailing `/` (self-close).
    String token = isClosing ? inner.substring(1) : inner;
    if (isSelfClosing && token.endsWith('/')) {
      token = token.substring(0, token.length - 1);
    }
    final String name = token.trim().split(RegExp(r'\s')).first.trim();

    if (isClosing) {
      if (stack.isEmpty || stack.last != name) {
        throw FormatException('Unmatched closing tag </$name>');
      }
      stack.removeLast();
    } else if (!isSelfClosing) {
      stack.add(name);
    }

    i = j + 1;
  }

  if (stack.isNotEmpty) {
    throw FormatException('Unclosed tags: ${stack.join(', ')}');
  }
}
