import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tool/check_import_boundaries.dart', () {
    test('allows contract -> contract export', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(
          sandbox,
          'lib/src/contract/value.dart',
          'class ContractValue {}\n',
        );
        _writeFile(
          sandbox,
          'lib/src/contract/api.dart',
          "export 'package:iwb_canvas_engine/src/contract/value.dart';\n",
        );

        final result = await _runTool(sandbox, 'check_import_boundaries.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('allows model facade -> model and contract imports', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(
          sandbox,
          'lib/src/model/document.dart',
          'class DocumentModel {}\n',
        );
        _writeFile(
          sandbox,
          'lib/src/contract/snapshot.dart',
          'class SceneSnapshot {}\n',
        );
        _writeFile(sandbox, 'lib/src/model/scene_builder_api.dart', '''
import 'package:iwb_canvas_engine/src/model/document.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';

class SceneBuilder {
  SceneSnapshot build(DocumentModel document) => SceneSnapshot();
}
''');

        final result = await _runTool(sandbox, 'check_import_boundaries.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects contract -> core/transform2d import', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(
          sandbox,
          'lib/src/core/transform2d.dart',
          'class Transform2D {}\n',
        );
        _writeFile(
          sandbox,
          'lib/src/contract/value.dart',
          "import 'package:iwb_canvas_engine/src/core/transform2d.dart';\n",
        );

        final result = await _runTool(sandbox, 'check_import_boundaries.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('layer DAG violation: contract/** must not import core/**'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects contract -> core/nodes import', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(
          sandbox,
          'lib/src/core/nodes.dart',
          'enum PathFillRule { nonZero }\n',
        );
        _writeFile(
          sandbox,
          'lib/src/contract/value.dart',
          "import 'package:iwb_canvas_engine/src/core/nodes.dart';\n",
        );

        final result = await _runTool(sandbox, 'check_import_boundaries.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('layer DAG violation: contract/** must not import core/**'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects arbitrary contract -> core import', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(sandbox, 'lib/src/core/value.dart', 'class CoreValue {}\n');
        _writeFile(
          sandbox,
          'lib/src/contract/value.dart',
          "import 'package:iwb_canvas_engine/src/core/value.dart';\n",
        );

        final result = await _runTool(sandbox, 'check_import_boundaries.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('layer DAG violation: contract/** must not import core/**'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects core -> unknown target layer import', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(
          sandbox,
          'lib/src/unknown/value.dart',
          'class UnknownValue {}\n',
        );
        _writeFile(
          sandbox,
          'lib/src/core/value.dart',
          "import 'package:iwb_canvas_engine/src/unknown/value.dart';\n",
        );

        final result = await _runTool(sandbox, 'check_import_boundaries.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains(
            'layer classification violation: unresolved target layer for /lib/src/unknown/value.dart',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects core -> reintroduced deleted public layer import', () async {
      final sandbox = await _createSandbox();
      try {
        final deletedLayerSegments = ['src', 'public', 'value.dart'];
        final deletedLayerPathSuffix = deletedLayerSegments.join('/');
        final deletedLayerFilePath = 'lib/$deletedLayerPathSuffix';
        final deletedLayerImportTarget =
            'package:iwb_canvas_engine/$deletedLayerPathSuffix';
        final deletedLayerRepoPath = '/lib/$deletedLayerPathSuffix';

        _writeFile(
          sandbox,
          deletedLayerFilePath,
          'class DeletedLayerValue {}\n',
        );
        _writeFile(
          sandbox,
          'lib/src/core/value.dart',
          "import '$deletedLayerImportTarget';\n",
        );

        final result = await _runTool(sandbox, 'check_import_boundaries.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains(
            'layer classification violation: unresolved target layer for $deletedLayerRepoPath',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects higher layers -> unknown target layer imports', () async {
      const layerCases = <({String filePath, String label})>[
        (filePath: 'lib/src/model/value.dart', label: 'model'),
        (filePath: 'lib/src/controller/value.dart', label: 'controller'),
        (filePath: 'lib/src/interactive/value.dart', label: 'interactive'),
        (filePath: 'lib/src/render/value.dart', label: 'render'),
        (filePath: 'lib/src/serialization/value.dart', label: 'serialization'),
        (filePath: 'lib/src/view/value.dart', label: 'view'),
      ];

      for (final layerCase in layerCases) {
        final sandbox = await _createSandbox();
        try {
          _writeFile(
            sandbox,
            'lib/src/unknown/value.dart',
            'class UnknownValue {}\n',
          );
          _writeFile(
            sandbox,
            layerCase.filePath,
            "import 'package:iwb_canvas_engine/src/unknown/value.dart';\n",
          );

          final result = await _runTool(
            sandbox,
            'check_import_boundaries.dart',
          );
          expect(
            result.exitCode,
            isNonZero,
            reason: '${layerCase.label} unexpectedly imported unknown layer',
          );
          expect(
            result.stderr.toString(),
            contains(
              'layer classification violation: unresolved target layer for /lib/src/unknown/value.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      }
    });

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

    test('allows view -> interactive import', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(
          sandbox,
          'lib/src/interactive/controller.dart',
          'class InteractiveController {}\n',
        );
        _writeFile(
          sandbox,
          'lib/src/view/widget.dart',
          "import 'package:iwb_canvas_engine/src/interactive/controller.dart';\n",
        );

        final result = await _runTool(sandbox, 'check_import_boundaries.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('allows serialization -> model import', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(
          sandbox,
          'lib/src/model/document.dart',
          'class Document {}\n',
        );
        _writeFile(
          sandbox,
          'lib/src/serialization/codec.dart',
          "import 'package:iwb_canvas_engine/src/model/document.dart';\n",
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
            'layer DAG violation: core/** must not import controller/**',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects core -> model import', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(sandbox, 'lib/src/model/types.dart', 'class ModelType {}\n');
        _writeFile(
          sandbox,
          'lib/src/core/value.dart',
          "import 'package:iwb_canvas_engine/src/model/types.dart';\n",
        );

        final result = await _runTool(sandbox, 'check_import_boundaries.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('layer DAG violation: core/** must not import model/**'),
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

    test('rejects unknown layer under lib/src', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(sandbox, 'lib/src/unknown/z.dart', 'class Unknown {}\n');

        final result = await _runTool(sandbox, 'check_import_boundaries.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains(
            'layer classification violation: file is under lib/src/** but has no known layer',
          ),
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
    // INV:INV-ENG-INTERACTIVE-RESOLVER-PURITY
    test('does not require API_GUIDE.md', () async {
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

    test('allows export-only root lib entrypoint files', () async {
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
        _writeFile(sandbox, 'lib/iwb_canvas_engine.dart', '''
/// Public API exports for tests.
library;

export 'src/contract/foo.dart'
    show Foo;
''');
        _writeFile(sandbox, 'lib/src/contract/foo.dart', '''
abstract class Foo {}
''');

        final result = await _runTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'allows export-only root lib entrypoint files with inline block comments',
      () async {
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
          _writeFile(sandbox, 'lib/iwb_canvas_engine.dart', '''
library;

/* comment before export */
export /* inline */ 'src/contract/foo.dart'
    show /* inline */ Foo;
''');
          _writeFile(sandbox, 'lib/src/contract/foo.dart', '''
abstract class Foo {}
''');

          final result = await _runTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, 0, reason: result.stderr.toString());
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('rejects executable logic in root lib entrypoint files', () async {
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
        _writeFile(sandbox, 'lib/iwb_canvas_engine.dart', '''
library;

void bootstrap() {}
''');

        final result = await _runTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains(
            'root lib/*.dart files must contain only library/docs/comments/export directives',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'rejects executable logic after inline block comment in root entrypoint',
      () async {
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
          _writeFile(sandbox, 'lib/iwb_canvas_engine.dart', '''
library;

/* safe comment */ void bootstrap() {}
''');

          final result = await _runTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains(
              'root lib/*.dart files must contain only library/docs/comments/export directives',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects executable logic after export and inline block comment',
      () async {
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
          _writeFile(sandbox, 'lib/iwb_canvas_engine.dart', '''
library;

export 'src/contract/foo.dart'; /* c */ class A {}
''');
          _writeFile(sandbox, 'lib/src/contract/foo.dart', '''
abstract class Foo {}
''');

          final result = await _runTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains(
              'root lib/*.dart files must contain only library/docs/comments/export directives',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

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
      'rejects scene/writeFindNode/writeMark*/id-bookkeeping in exported txn API',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeFile(
            sandbox,
            'lib/iwb_canvas_engine.dart',
            "export 'src/contract/scene_write_txn.dart';\n",
          );
          _writeFile(sandbox, 'lib/src/contract/scene_write_txn.dart', '''
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
            "export 'src/contract/foo.dart';\n",
          );
          _writeFile(sandbox, 'lib/src/contract/foo.dart', '''
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

    test('rejects exported contract import from controller layer', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(sandbox, 'lib/iwb_canvas_engine.dart', '''
library;

export 'src/contract/snapshot.dart';
''');
        _writeFile(sandbox, 'lib/src/controller/store.dart', '''
class Store {
  int controllerEpoch = 0;
}
''');
        _writeFile(
          sandbox,
          'lib/src/controller/types.dart',
          'class ControllerType {}\n',
        );
        _writeFile(
          sandbox,
          'lib/src/contract/snapshot.dart',
          "import 'package:iwb_canvas_engine/src/controller/types.dart';\n",
        );

        final result = await _runTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains(
            'exported contract/model API must not import/export controller/render/view/serialization internals',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'accepts guarded public interactive entrypoints in SceneControllerInteractive',
      () async {
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
          _writeFile(
            sandbox,
            'lib/src/interactive/scene_controller_interactive.dart',
            '''
class SceneControllerInteractive {
  int get value => 1;

  void handlePointer() {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  set mode(int value) {
    _ensurePublicSideEffectAllowed('mode');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}
''',
          );

          final result = await _runTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, 0, reason: result.stderr.toString());
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects public interactive method without resolver purity guard',
      () async {
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
          _writeFile(
            sandbox,
            'lib/src/interactive/scene_controller_interactive.dart',
            '''
class SceneControllerInteractive {
  void handlePointer() {
    print('missing guard');
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}
''',
          );

          final result = await _runTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains(
              'public interactive entrypoints must guard resolver purity with _ensurePublicSideEffectAllowed',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects dispose without allowAfterDispose true in purity guard',
      () async {
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
          _writeFile(
            sandbox,
            'lib/src/interactive/scene_controller_interactive.dart',
            '''
class SceneControllerInteractive {
  void dispose() {
    _ensurePublicSideEffectAllowed('dispose');
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}
''',
          );

          final result = await _runTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains(
              'dispose() must guard resolver purity with allowAfterDispose: true',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );
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
