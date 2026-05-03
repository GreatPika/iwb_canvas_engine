@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/tool_process_test_support.dart';

void main() {
  group('tool/lsp_find_boundary_bypasses.dart', () {
    test(
      'reports methods whose primary flow skips the required seam',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeFixture(sandbox);

          final result = await runSandboxTool(
            sandbox,
            'lsp_find_boundary_bypasses.dart',
            args: const <String>[
              'lib/src/flow.dart',
              'Owner',
              '--must-pass=Boundary',
              '--depth=5',
            ],
          );

          expect(result.exitCode, isNonZero);
          final stdout = result.stdout.toString();
          expect(stdout, contains('Owner.removeNode'));
          expect(stdout, isNot(contains('Owner.addNode\n')));
          expect(stdout, contains('flow: Sink.addNode'));
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );
  });
}

Future<Directory> _createSandbox() {
  return createToolSandbox(
    tempPrefix: 'iwb_canvas_engine_lsp_find_boundary_bypasses_tool_test_',
    toolFiles: const <String>[
      'tool/lsp_find_boundary_bypasses.dart',
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

  void removeNode(int value) {
    boundary.sink.addNode(value);
  }
}
''');
}
