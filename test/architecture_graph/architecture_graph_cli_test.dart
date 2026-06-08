import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'architecture graph commands no longer require phase arguments',
    () async {
      final check = await _run('tool/architecture_graph/check.dart');
      final generateCheck = await _run(
        'tool/architecture_graph/generate_views.dart',
        '--check',
      );

      expect(check.exitCode, 0);
      expect(check.stdout, contains('Architecture graph closure passed.'));
      expect(generateCheck.exitCode, 0);
    },
  );

  test('architecture graph commands reject old phase arguments', () async {
    final check = await _run(
      'tool/architecture_graph/check.dart',
      '--phase=P14',
    );
    final generateCheck = await _run(
      'tool/architecture_graph/generate_views.dart',
      '--phase=P14',
      '--check',
    );

    expect(check.exitCode, 64);
    expect(check.stderr, contains('tool/architecture_graph/check.dart'));
    expect(generateCheck.exitCode, 64);
    expect(
      generateCheck.stderr,
      contains('tool/architecture_graph/generate_views.dart'),
    );
  });
}

Future<ProcessResult> _run(String path, [String? firstArg, String? secondArg]) {
  return Process.run('dart', ['run', path, ?firstArg, ?secondArg]);
}
