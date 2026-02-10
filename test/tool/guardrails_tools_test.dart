import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tool/check_import_boundaries.dart', () {
    test('allows view -> render import', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(sandbox, 'lib/src/render/painter.dart', 'class Painter {}\n');
        _writeFile(
          sandbox,
          'lib/src/view/widget.dart',
          "import 'package:iwb_canvas_engine/src/render/painter.dart';\n",
        );

        final result = await _runTool(sandbox, 'check_import_boundaries.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects core -> input import', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(sandbox, 'lib/src/input/types.dart', 'class InputType {}\n');
        _writeFile(
          sandbox,
          'lib/src/core/value.dart',
          "import 'package:iwb_canvas_engine/src/input/types.dart';\n",
        );

        final result = await _runTool(sandbox, 'check_import_boundaries.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('layer boundary violation: core/** must not import input/**'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects cross-slice import', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(
          sandbox,
          'lib/src/input/slices/a/a.dart',
          'class SliceA {}\n',
        );
        _writeFile(
          sandbox,
          'lib/src/input/slices/b/b.dart',
          "import 'package:iwb_canvas_engine/src/input/slices/a/a.dart';\n",
        );

        final result = await _runTool(sandbox, 'check_import_boundaries.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('slices/** must not import other slices'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  });

  group('tool/check_guardrails.dart', () {
    // INV:INV-V2-TXN-ATOMIC-COMMIT
    test('passes for write/txn APIs and controllerEpoch usage', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(sandbox, 'lib/src/controller/store.dart', '''
class Store {
  int controllerEpoch = 0;

  void writeMutations() {}

  void txnCommit() {
    writeMutations();
  }
}
''');

        final result = await _runTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects mutating symbol outside write/txn prefixes', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(sandbox, 'lib/src/controller/store.dart', '''
class Store {
  int controllerEpoch = 0;

  void replaceScene() {}
}
''');

        final result = await _runTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('must be routed through write*/txn* transaction API'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects public import from input layer', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(sandbox, 'lib/src/input/types.dart', 'class InputType {}\n');
        _writeFile(
          sandbox,
          'lib/src/public/snapshot.dart',
          "import 'package:iwb_canvas_engine/src/input/types.dart';\n",
        );

        final result = await _runTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains(
            'public must not import/export input/render/view/serialization internals',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  });
}

Future<Directory> _createSandbox() async {
  final sandbox = await Directory.systemTemp.createTemp(
    'iwb_canvas_engine_tool_test_',
  );

  _writeFile(sandbox, 'pubspec.yaml', '''
name: iwb_canvas_engine
environment:
  sdk: ">=3.0.0 <4.0.0"
''');

  final sourceRoot = Directory.current.path;
  _copyFile(
    '$sourceRoot/tool/check_import_boundaries.dart',
    '${sandbox.path}/tool/check_import_boundaries.dart',
  );
  _copyFile(
    '$sourceRoot/tool/check_guardrails.dart',
    '${sandbox.path}/tool/check_guardrails.dart',
  );

  return sandbox;
}

void _copyFile(String from, String to) {
  final source = File(from);
  final target = File(to);
  target.parent.createSync(recursive: true);
  source.copySync(target.path);
}

void _writeFile(Directory root, String relativePath, String content) {
  final file = File('${root.path}/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

Future<ProcessResult> _runTool(Directory sandbox, String toolFileName) {
  return Process.run('dart', <String>[
    'run',
    'tool/$toolFileName',
  ], workingDirectory: sandbox.path);
}
