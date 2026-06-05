import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'ReleaseReadiness stays graph-checkable without public runtime surface',
    () {
      final declaration = File('tool/bench/src/release_readiness.dart');

      expect(declaration.existsSync(), isTrue);
      expect(
        declaration.readAsStringSync(),
        contains('final class ReleaseReadiness'),
      );
      expect(
        File('lib/iwb_canvas_engine.dart').readAsStringSync(),
        isNot(contains('ReleaseReadiness')),
      );

      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) {
          continue;
        }
        final source = file.readAsStringSync();
        expect(source, isNot(contains('ReleaseReadiness')), reason: file.path);
        expect(source, isNot(contains('tool/bench')), reason: file.path);
        expect(
          source,
          isNot(contains('release_readiness.dart')),
          reason: file.path,
        );
      }
    },
  );
}
