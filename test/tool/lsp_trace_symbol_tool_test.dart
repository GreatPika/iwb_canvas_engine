@Tags(['tool'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'support/tool_process_test_support.dart';

void main() {
  group('tool/lsp_trace_symbol.dart', () {
    test(
      'reports implementations and incoming calls for an interface method',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeFixture(sandbox);

          final result = await runSandboxTool(
            sandbox,
            'lsp_trace_symbol.dart',
            args: const <String>[
              'lib/src/flow.dart',
              'Sink.addNode',
              '--depth=1',
            ],
          );

          expect(result.exitCode, 0, reason: result.stderr.toString());
          expect(
            result.stdout.toString(),
            contains('Implementations:\n- lib/src/flow.dart'),
          );
          expect(result.stdout.toString(), contains('Incoming calls:'));
          expect(result.stdout.toString(), contains('Wrapper.addNode'));
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('writes json and mermaid artifacts', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFixture(sandbox);

        final result = await runSandboxTool(
          sandbox,
          'lsp_trace_symbol.dart',
          args: const <String>[
            'lib/src/flow.dart',
            'Sink.addNode',
            '--json-out=artifacts/trace.json',
            '--mermaid-out=artifacts/trace.md',
          ],
        );

        expect(result.exitCode, 0, reason: result.stderr.toString());
        final jsonFile = File('${sandbox.path}/artifacts/trace.json');
        final mermaidFile = File('${sandbox.path}/artifacts/trace.md');
        expect(jsonFile.existsSync(), isTrue);
        expect(mermaidFile.existsSync(), isTrue);
        expect(
          jsonFile.readAsStringSync(),
          contains('"symbol": "Sink.addNode"'),
        );
        final jsonMap =
            jsonDecode(jsonFile.readAsStringSync()) as Map<String, Object?>;
        final referencePaths =
            (jsonMap['referencesByFile'] as Map<String, Object?>).keys.toList();
        expect(referencePaths, orderedEquals(referencePaths.toList()..sort()));
        _expectCallTreeSorted(jsonMap['incoming'] as List<Object?>);
        _expectCallTreeSorted(jsonMap['outgoing'] as List<Object?>);
        expect(mermaidFile.readAsStringSync(), contains('```mermaid'));
        expect(mermaidFile.readAsStringSync(), contains('flowchart LR'));
        expect(mermaidFile.readAsStringSync(), contains('```'));
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  });
}

void _expectCallTreeSorted(List<Object?> nodes) {
  final mappedNodes = nodes.cast<Map<String, Object?>>();
  final keys = mappedNodes.map(_callTreeSortKey).toList();
  expect(keys, orderedEquals(keys.toList()..sort()));
  for (final node in mappedNodes) {
    _expectCallTreeSorted(node['children'] as List<Object?>);
  }
}

String _callTreeSortKey(Map<String, Object?> node) {
  return [
    node['path'] as String? ?? '',
    node['detail'] as String? ?? '',
    node['name'] as String? ?? '',
  ].join('\u{0}');
}

Future<Directory> _createSandbox() {
  return createToolSandbox(
    tempPrefix: 'iwb_canvas_engine_lsp_trace_symbol_tool_test_',
    toolFiles: const <String>[
      'tool/lsp_trace_symbol.dart',
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
