@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/tool_process_test_support.dart';

void main() {
  group('tool/lsp_find_symbols.dart', () {
    test('finds matching workspace symbols and filters by path', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFixture(sandbox);

        final result = await runSandboxTool(
          sandbox,
          'lsp_find_symbols.dart',
          args: const <String>[
            'addNode',
            '--path-contains=lib/src/flow.dart',
            '--limit=10',
          ],
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(result.stdout.toString(), contains('Wrapper'));
        expect(result.stdout.toString(), contains('Sink'));
        expect(result.stdout.toString(), contains('lib/src/flow.dart'));
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  });
}

Future<Directory> _createSandbox() {
  return createToolSandbox(
    tempPrefix: 'iwb_canvas_engine_lsp_find_symbols_tool_test_',
    toolFiles: const <String>[
      'tool/lsp_find_symbols.dart',
      'tool/src/lsp',
      'tool/src/tool_command_result.dart',
    ],
  );
}

void _writeFixture(Directory sandbox) {
  writeSandboxFile(sandbox, 'lib/src/flow.dart', '''
abstract interface class Sink {
  void addNode(int value);
}

final class SinkImpl implements Sink {
  @override
  void addNode(int value) {
    writeAddNode(value);
  }

  void writeAddNode(int value) {}
}

final class Wrapper {
  const Wrapper(this.sink);

  final Sink sink;

  void addNode(int value) {
    sink.addNode(value);
  }
}
''');
}
