@Tags(['tool'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../tool/trace_export_namespace.dart' as trace_export_namespace_tool;

void main() {
  group('tool/trace_export_namespace.dart', () {
    test('reports transitive owner files from re-export chains', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFixture(sandbox);

        final result = await trace_export_namespace_tool
            .runTraceExportNamespaceTool(const <String>[
              'lib/iwb_canvas_engine.dart',
            ], root: sandbox);

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(
          result.stdout.toString(),
          contains('Transitively exported owner files: 1'),
        );
        expect(result.stdout.toString(), contains('/lib/src/c.dart'));
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('writes json and markdown artifacts', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFixture(sandbox);

        final result = await trace_export_namespace_tool
            .runTraceExportNamespaceTool(const <String>[
              'lib/iwb_canvas_engine.dart',
              '--json-out=artifacts/export_namespace.json',
              '--md-out=artifacts/export_namespace.md',
            ], root: sandbox);

        expect(result.exitCode, 0, reason: result.stderr.toString());
        final jsonFile = File(
          '${sandbox.path}/artifacts/export_namespace.json',
        );
        final markdownFile = File(
          '${sandbox.path}/artifacts/export_namespace.md',
        );
        expect(jsonFile.existsSync(), isTrue);
        expect(markdownFile.existsSync(), isTrue);

        final jsonMap =
            jsonDecode(jsonFile.readAsStringSync()) as Map<String, Object?>;
        expect(jsonMap['entrypoint'], equals('/lib/iwb_canvas_engine.dart'));
        final transitiveSymbols =
            (jsonMap['transitivelyExportedSymbols'] as List<Object?>)
                .cast<Map<String, Object?>>();
        expect(
          transitiveSymbols.any(
            (symbol) =>
                symbol['name'] == 'Forwarded' &&
                symbol['ownerPath'] == '/lib/src/c.dart' &&
                symbol['directlyExportedOwner'] == false,
          ),
          isTrue,
        );
        expect(
          markdownFile.readAsStringSync(),
          contains('# Export Namespace Trace'),
        );
        expect(markdownFile.readAsStringSync(), contains('```mermaid'));
        expect(
          markdownFile.readAsStringSync(),
          contains('/lib/iwb_canvas_engine.dart'),
        );
        expect(markdownFile.readAsStringSync(), contains('/lib/src/a.dart'));
        expect(markdownFile.readAsStringSync(), contains('/lib/src/c.dart'));
        expect(markdownFile.readAsStringSync(), contains('-->'));
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  });
}

Future<Directory> _createSandbox() {
  return Directory.systemTemp.createTemp(
    'iwb_canvas_engine_trace_export_namespace_tool_test_',
  );
}

void _writeFixture(Directory sandbox) {
  _writeFile(sandbox, 'pubspec.yaml', '''
name: iwb_canvas_engine
environment:
  sdk: ">=3.9.0 <4.0.0"
dev_dependencies:
  analyzer: ^8.4.0
''');

  _writeFile(sandbox, 'lib/iwb_canvas_engine.dart', '''
library;

export 'src/a.dart' show PublicClass, Forwarded;
''');

  _writeFile(sandbox, 'lib/src/a.dart', '''
class PublicClass {}

export 'c.dart' show Forwarded;
''');

  _writeFile(sandbox, 'lib/src/c.dart', '''
class Forwarded {}
''');
}

void _writeFile(Directory root, String relativePath, String content) {
  final file = File('${root.path}/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}
