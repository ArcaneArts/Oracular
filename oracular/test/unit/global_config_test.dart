import 'dart:io';

import 'package:oracular/models/template_info.dart';
import 'package:oracular/utils/global_config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('OracularGlobalConfig', () {
    test('normalizes known key aliases', () {
      expect(OracularGlobalConfig.normalizeKey('org'), equals('org'));
      expect(OracularGlobalConfig.normalizeKey('organization'), equals('org'));
      expect(
        OracularGlobalConfig.normalizeKey('output-dir'),
        equals('output_dir'),
      );
      expect(
        OracularGlobalConfig.normalizeKey('firebase_project'),
        equals('firebase_project_id'),
      );
      expect(
        OracularGlobalConfig.normalizeKey('jaspr-render-mode'),
        equals('render_mode'),
      );
    });

    test('derives project creation defaults from loaded values', () {
      final values = <String, String>{
        'org': 'art.arcane',
        'default_template': 'arcane_jaspr_docs',
        'firebase_project_id': 'arcane-prod',
        'service_account_key': '~/keys/service-account.json',
        'render_mode': 'ssg',
      };

      expect(OracularGlobalConfig.defaultOrg(values), equals('art.arcane'));
      expect(
        OracularGlobalConfig.defaultTemplate(values),
        equals(TemplateType.arcaneJasprDocs),
      );
      expect(
        OracularGlobalConfig.defaultFirebaseProjectId(values),
        equals('arcane-prod'),
      );
      expect(
        OracularGlobalConfig.defaultServiceAccountKey(values),
        equals('~/keys/service-account.json'),
      );
      expect(OracularGlobalConfig.defaultRenderMode(values), equals('ssg'));
    });

    test('resolves output directory defaults', () {
      expect(
        OracularGlobalConfig.defaultOutputDir(const <String, String>{}),
        equals(Directory.current.path),
      );

      expect(
        OracularGlobalConfig.defaultOutputDir(const <String, String>{
          'output_dir': 'relative_projects',
        }),
        equals(p.normalize(p.absolute('relative_projects'))),
      );
    });

    test('falls back to the default app template for invalid config value', () {
      expect(
        OracularGlobalConfig.defaultTemplate(const <String, String>{
          'default_template': 'nope',
        }),
        equals(TemplateType.arcaneTemplate),
      );
    });
  });
}
