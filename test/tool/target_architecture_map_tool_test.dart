@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('architecture atlas migration smoke checks', () {
    test('single atlas entrypoint routes to engine and proof maps', () {
      final source = File('docs/ARCHITECTURE_ATLAS.md').readAsStringSync();

      expect(source, contains('(architecture/overview.md)'));
      expect(source, contains('(proof_architecture/overview.md)'));
      expect(source, contains('(adr/0001_target_engine_architecture.md)'));
      expect(source, contains('(../KNOWN_ISSUES.md)'));
    });

    test('old target architecture directory is retired', () {
      expect(Directory('docs/target_architecture').existsSync(), isFalse);
    });

    test('existing runtime evidence moved under the engine atlas', () {
      for (final path in const <String>[
        'docs/architecture/evidence/add_node_write_flow.json',
        'docs/architecture/evidence/add_node_write_flow.md',
        'docs/architecture/evidence/replace_scene_write_flow.json',
        'docs/architecture/evidence/replace_scene_write_flow.md',
        'docs/architecture/evidence/commit_move_selection_flow.json',
        'docs/architecture/evidence/commit_move_selection_flow.md',
        'docs/architecture/evidence/composition_root_trace.json',
        'docs/architecture/evidence/composition_root_trace.md',
      ]) {
        expect(File(path).existsSync(), isTrue, reason: 'Missing $path');
      }
    });
  });
}
