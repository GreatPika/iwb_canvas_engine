@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/tool_process_test_support.dart';

void main() {
  group('tool/lsp_find_thin_wrappers.dart', () {
    test('classifies pure and guarded forwarding wrappers', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFixture(sandbox);

        final result = await runSandboxTool(
          sandbox,
          'lsp_find_thin_wrappers.dart',
          args: const <String>['lib/src'],
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(
          result.stdout.toString(),
          contains('pure-forwarder: Wrapper.addNode -> addNode'),
        );
        expect(
          result.stdout.toString(),
          contains('guarded-forwarder: Wrapper.guardedAddNode -> addNode'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  });
}

Future<Directory> _createSandbox() {
  return createToolSandbox(
    tempPrefix: 'iwb_canvas_engine_lsp_find_thin_wrappers_tool_test_',
    toolFiles: const <String>[
      'tool/lsp_find_thin_wrappers.dart',
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

final class Wrapper {
  const Wrapper(this.sink);

  final Sink sink;

  void addNode(int value) {
    sink.addNode(value);
  }

  void guardedAddNode(int value) {
    if (value < 0) {
      return;
    }
    sink.addNode(value);
  }

  void richerAddNode(int value) {
    sink.addNode(value);
    _after();
  }

  void _after() {}
}
''');
}
