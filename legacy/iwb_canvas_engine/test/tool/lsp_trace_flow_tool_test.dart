@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/tool_process_test_support.dart';

void main() {
  group('tool/lsp_trace_flow.dart', () {
    test(
      'stitches interface and implementation into one primary flow',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeFixture(sandbox);

          final result = await runSandboxTool(
            sandbox,
            'lsp_trace_flow.dart',
            args: const <String>[
              'lib/src/flow.dart',
              'Owner.addNode',
              '--depth=5',
            ],
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());
          final stdout = result.stdout.toString();
          expect(stdout, contains('start: Owner.addNode'));
          expect(stdout, contains('call: Boundary.addNode'));
          expect(stdout, contains('call: Sink.addNode'));
          expect(stdout, contains('implementation: SinkImpl.addNode'));
          expect(stdout, contains('call: SinkImpl.writeAddNode'));
          expect(stdout, contains('side-branch: Sink.schedule'));
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );
  });
}

Future<Directory> _createSandbox() {
  return createToolSandbox(
    tempPrefix: 'iwb_canvas_engine_lsp_trace_flow_tool_test_',
    toolFiles: const <String>[
      'tool/lsp_trace_flow.dart',
      'tool/src/lsp',
      'tool/src/tool_command_result.dart',
    ],
  );
}

void _writeFixture(Directory sandbox) {
  writeSandboxFile(sandbox, 'lib/src/flow.dart', '''
abstract interface class Sink {
  void addNode(int value);
  void schedule();
}

final class SinkImpl implements Sink {
  @override
  void addNode(int value) {
    writeAddNode(value);
  }

  @override
  void schedule() {}

  void writeAddNode(int value) {}
}

final class Boundary {
  const Boundary(this.sink);

  final Sink sink;

  void addNode(int value) {
    sink.addNode(value);
    sink.schedule();
  }
}

final class Owner {
  const Owner(this.boundary);

  final Boundary boundary;

  void addNode(int value) {
    boundary.addNode(value);
  }
}
''');
}
