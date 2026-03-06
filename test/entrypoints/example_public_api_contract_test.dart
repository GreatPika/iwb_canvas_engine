import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final RegExp _importDirectivePattern = RegExp(
  r'''^\s*import\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

void main() {
  test('example app imports only the public package entrypoint', () {
    final repoRoot = Directory.current;
    final exampleRoots = <String>['example/lib', 'example/test'];
    final violations = <String>[];

    for (final relativeRoot in exampleRoots) {
      final directory = Directory('${repoRoot.path}/$relativeRoot');
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        final content = entity.readAsStringSync();
        for (final match in _importDirectivePattern.allMatches(content)) {
          final uri = match.group(1);
          if (uri == null || !uri.startsWith('package:iwb_canvas_engine/')) {
            continue;
          }
          if (uri != 'package:iwb_canvas_engine/iwb_canvas_engine.dart') {
            violations.add('${entity.path}: $uri');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Example code must import only package:iwb_canvas_engine/iwb_canvas_engine.dart',
    );
  });
}
