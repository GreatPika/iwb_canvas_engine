import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tool/check_import_boundaries.dart', () {
    test('allows view -> render import', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(
          sandbox,
          'lib/src/render/painter.dart',
          'class Painter {}\n',
        );
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

    test('rejects core -> controller import', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(
          sandbox,
          'lib/src/controller/types.dart',
          'class ControllerType {}\n',
        );
        _writeFile(
          sandbox,
          'lib/src/core/value.dart',
          "import 'package:iwb_canvas_engine/src/controller/types.dart';\n",
        );

        final result = await _runTool(sandbox, 'check_import_boundaries.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains(
            'layer boundary violation: core/** must not import controller/**',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects internal -> commands import', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(
          sandbox,
          'lib/src/controller/commands/a/a.dart',
          'class CommandA {}\n',
        );
        _writeFile(
          sandbox,
          'lib/src/controller/internal/b.dart',
          "import 'package:iwb_canvas_engine/src/controller/commands/a/a.dart';\n",
        );

        final result = await _runTool(sandbox, 'check_import_boundaries.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('internal/** must not import commands/**'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects cross-command import', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(
          sandbox,
          'lib/src/controller/commands/a/a.dart',
          'class CommandA {}\n',
        );
        _writeFile(
          sandbox,
          'lib/src/controller/commands/b/b.dart',
          "import 'package:iwb_canvas_engine/src/controller/commands/a/a.dart';\n",
        );

        final result = await _runTool(sandbox, 'check_import_boundaries.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('commands/** must not import other commands'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  });

  group('tool/check_guardrails.dart', () {
    // INV:INV-ENG-TXN-ATOMIC-COMMIT
    // INV:INV-G-PUBLIC-ENTRYPOINTS
    // INV:INV-ENG-SAFE-TXN-API
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

    test('rejects advanced.dart entrypoint', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(sandbox, 'lib/advanced.dart', '// forbidden entrypoint\n');

        final result = await _runTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('advanced.dart entrypoint is forbidden'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects mutable core exports from iwb_canvas_engine.dart', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(
          sandbox,
          'lib/iwb_canvas_engine.dart',
          "export 'src/core/scene.dart';\n",
        );

        final result = await _runTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('iwb_canvas_engine.dart must not export mutable core model'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'rejects scene/writeFindNode/writeMark*/id-bookkeeping in public txn API',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeFile(
            sandbox,
            'lib/iwb_canvas_engine.dart',
            "export 'src/public/scene_write_txn.dart';\n",
          );
          _writeFile(sandbox, 'lib/src/public/scene_write_txn.dart', '''
abstract interface class SceneWriteTxn {
  Object get scene;
  Object? writeFindNode(String id);
  void writeMarkVisualChanged();
  String writeNewNodeId();
}
''');

          final result = await _runTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            anyOf(
              contains('must not expose raw scene access'),
              contains('must not expose writeFindNode'),
              contains('must not expose writeMark* escape hatches'),
              contains('must not expose node-id bookkeeping methods'),
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects mutable core type in exported public API signature',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeFile(
            sandbox,
            'lib/iwb_canvas_engine.dart',
            "export 'src/public/foo.dart';\n",
          );
          _writeFile(sandbox, 'lib/src/public/foo.dart', '''
abstract class Foo {
  Scene get scene;
}
''');

          final result = await _runTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains('must not expose mutable core types'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

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
