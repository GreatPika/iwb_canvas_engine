@Tags(['tool'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tool/run_temp_pkg_test.dart capability-owner contract', () {
    test('public barrel consumer uses controller-owned capabilities', () async {
      final result = await _runTempPkgSnippet('''
test('controller-owned capabilities remain usable', () {
  final controller = SceneController(
    initialSnapshot: SceneSnapshot(
      layers: <ContentLayerSnapshot>[ContentLayerSnapshot(id: 'layer-1')],
    ),
  );
  addTearDown(controller.dispose);

  controller.interaction.setMode(CanvasMode.draw);
  controller.selection.clearSelection();
  controller.scene.write((txn) {
    expect(txn.snapshot.layers.single.id, 'layer-1');
    return null;
  });
});
''');

      expect(result.exitCode, 0, reason: result.stderr);
    });

    test(
      'public barrel consumer cannot instantiate capability owners',
      () async {
        for (final typeName in <String>[
          'SceneControllerInteraction',
          'SceneControllerSelection',
          'SceneControllerScene',
        ]) {
          final result = await _runTempPkgSnippet('''
test('direct construction is rejected for $typeName', () {
  $typeName();
});
''');

          expect(result.exitCode, isNonZero, reason: result.stdout);
          expect(result.stderr, contains(typeName));
        }
      },
    );
  });
}

Future<_ToolRunResult> _runTempPkgSnippet(String snippet) async {
  final process = await Process.start('dart', const <String>[
    'run',
    'tool/run_temp_pkg_test.dart',
    '--stdin',
  ], workingDirectory: Directory.current.path);
  process.stdin.write(snippet);
  await process.stdin.close();

  final stdout = await process.stdout
      .transform(SystemEncoding().decoder)
      .join();
  final stderr = await process.stderr
      .transform(SystemEncoding().decoder)
      .join();
  final exitCode = await process.exitCode;
  return _ToolRunResult(exitCode: exitCode, stdout: stdout, stderr: stderr);
}

final class _ToolRunResult {
  const _ToolRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}
