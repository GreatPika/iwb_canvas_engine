import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../utils/public_entrypoint_contract.dart';

Matcher _diagnostic({required String category, required String detail}) {
  return allOf(contains('$category violation:'), contains(detail));
}

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
          allOf(
            contains('layer layout violation:'),
            contains('uses unapproved top-level layer "unknown"'),
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
          allOf(
            contains('layer layout violation:'),
            contains('uses deleted top-level layer "public"'),
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects reintroduced deleted public layer without imports', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(
          sandbox,
          'lib/src/public/value.dart',
          'class DeletedLayerValue {}\n',
        );

        final result = await _runTool(sandbox, 'check_import_boundaries.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          allOf(
            contains('layer layout violation:'),
            contains('uses deleted top-level layer "public"'),
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects unknown top-level lib/src layer without imports', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(
          sandbox,
          'lib/src/unknown/value.dart',
          'class UnknownValue {}\n',
        );

        final result = await _runTool(sandbox, 'check_import_boundaries.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          allOf(
            contains('layer layout violation:'),
            contains('uses unapproved top-level layer "unknown"'),
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
            allOf(
              contains('layer layout violation:'),
              contains('uses unapproved top-level layer "unknown"'),
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

    test(
      'allows top-level lib/src file without treating it as a layer',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeFile(sandbox, 'lib/src/version.dart', 'const version = 1;\n');
          _writeFile(
            sandbox,
            'lib/src/core/value.dart',
            'class CoreValue {}\n',
          );

          final result = await _runTool(
            sandbox,
            'check_import_boundaries.dart',
          );
          expect(result.exitCode, 0, reason: result.stderr.toString());
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('allows approved contract top-level layer without imports', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(
          sandbox,
          'lib/src/contract/value.dart',
          'class ContractValue {}\n',
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
          _diagnostic(
            category: 'controller structure',
            detail: 'internal/** must not import commands/**',
          ),
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
          _diagnostic(
            category: 'controller structure',
            detail: 'commands/** must not import other commands',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects commands part directives', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(
          sandbox,
          'lib/src/controller/commands/a/a.dart',
          "part 'a.part.dart';\n",
        );

        final result = await _runTool(sandbox, 'check_import_boundaries.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          _diagnostic(
            category: 'controller structure',
            detail: 'commands/** must not use part/part of directives',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('allows multiline import/export with show/hide combinators', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(
          sandbox,
          'lib/src/render/painter.dart',
          'class Painter {}\nclass InternalPainter {}\n',
        );
        _writeFile(sandbox, 'lib/src/view/widget.dart', '''
import
  'package:iwb_canvas_engine/src/render/painter.dart'
  show Painter;
export
  'package:iwb_canvas_engine/src/render/painter.dart'
  hide InternalPainter;

class Widget {}
''');

        final result = await _runTool(sandbox, 'check_import_boundaries.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects conditional import branch to forbidden layer', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(
          sandbox,
          'lib/src/contract/safe.dart',
          'class SafeContract {}\n',
        );
        _writeFile(sandbox, 'lib/src/core/value.dart', 'class CoreValue {}\n');
        _writeFile(sandbox, 'lib/src/contract/value.dart', '''
import 'package:iwb_canvas_engine/src/contract/safe.dart'
    if (dart.library.io) 'package:iwb_canvas_engine/src/core/value.dart';

class ContractValue extends SafeContract {}
''');

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

    test('rejects multiline commands part of directives', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(sandbox, 'lib/src/controller/commands/a/a.dart', '''
part
  of 'a_parent.dart';
''');

        final result = await _runTool(sandbox, 'check_import_boundaries.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          _diagnostic(
            category: 'controller structure',
            detail: 'commands/** must not use part/part of directives',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects internal -> scene_controller import', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(
          sandbox,
          'lib/src/controller/internal/b.dart',
          "import 'package:iwb_canvas_engine/src/controller/scene_controller.dart';\n",
        );

        final result = await _runTool(sandbox, 'check_import_boundaries.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          _diagnostic(
            category: 'controller structure',
            detail:
                'internal/** must not import controller/scene_controller.dart',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects internal -> disallowed external package import', () async {
      final sandbox = await _createSandbox();
      try {
        _writeFile(
          sandbox,
          'lib/src/controller/internal/b.dart',
          "import 'package:external/pkg.dart';\n",
        );

        final result = await _runTool(sandbox, 'check_import_boundaries.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          _diagnostic(
            category: 'controller structure',
            detail: 'internal/** has a disallowed external package import',
          ),
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
          allOf(
            contains('layer layout violation:'),
            contains('uses unapproved top-level layer "unknown"'),
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

    test('rejects reintroduced deleted public layer without imports', () async {
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
          'lib/src/public/value.dart',
          'class PublicValue {}\n',
        );

        final result = await _runTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          allOf(
            contains('layer layout violation:'),
            contains('uses deleted top-level layer "public"'),
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects unknown top-level lib/src layer without imports', () async {
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
          'lib/src/unknown/value.dart',
          'class UnknownValue {}\n',
        );

        final result = await _runTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          allOf(
            contains('layer layout violation:'),
            contains('uses unapproved top-level layer "unknown"'),
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'allows top-level lib/src file without treating it as a layer',
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
          _writeFile(sandbox, 'lib/src/version.dart', 'const version = 1;\n');

          final result = await _runTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, 0, reason: result.stderr.toString());
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('allows approved contract top-level layer without imports', () async {
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
          'lib/src/contract/value.dart',
          'class ContractValue {}\n',
        );

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
        _writeCanonicalPublicExportScaffold(sandbox);

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
          _writeCanonicalPublicExportScaffold(sandbox);
          _writeFile(
            sandbox,
            'lib/iwb_canvas_engine.dart',
            canonicalPublicEntrypoint(withInlineComments: true),
          );

          final result = await _runTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, 0, reason: result.stderr.toString());
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('allows multiline export directives in root lib entrypoint', () async {
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
        _writeCanonicalPublicExportScaffold(sandbox);
        _writeFile(
          sandbox,
          'lib/iwb_canvas_engine.dart',
          canonicalPublicEntrypoint().replaceFirst(
            "export 'src/contract/node_patch.dart';",
            "export\n  'src/contract/node_patch.dart';",
          ),
        );

        final result = await _runTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

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
          _diagnostic(
            category: 'public entrypoint',
            detail:
                'root lib/*.dart files must contain only '
                'library/docs/comments/export directives',
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
            _diagnostic(
              category: 'public entrypoint',
              detail:
                  'root lib/*.dart files must contain only '
                  'library/docs/comments/export directives',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('rejects stale non-contract export scan policy entry', () async {
      final sandbox = await _createSandbox();
      try {
        _writeCanonicalPublicExportScaffold(sandbox);
        _writeFile(
          sandbox,
          'lib/iwb_canvas_engine.dart',
          canonicalPublicEntrypoint().replaceFirst(
            '$canonicalViewPublicExportDirective\n',
            '',
          ),
        );

        final result = await _runTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          allOf(
            _diagnostic(
              category: 'public entrypoint',
              detail:
                  'exported API policy entry '
                  '/lib/src/view/scene_view_interactive.dart is stale',
            ),
            contains('view widgets expose framework UI types'),
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

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
          _writeCanonicalPublicExportScaffold(sandbox);
          _writeFile(
            sandbox,
            'lib/iwb_canvas_engine.dart',
            canonicalPublicEntrypoint(withTrailingLogicAfterFirstExport: true),
          );

          final result = await _runTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            _diagnostic(
              category: 'public entrypoint',
              detail:
                  'root lib/*.dart files must contain only '
                  'library/docs/comments/export directives',
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
          _diagnostic(
            category: 'public entrypoint',
            detail: 'advanced.dart is forbidden',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects mutable core exports from iwb_canvas_engine.dart', () async {
      final sandbox = await _createSandbox();
      try {
        _writeCanonicalPublicExportScaffold(sandbox);
        _writeFile(
          sandbox,
          'lib/iwb_canvas_engine.dart',
          "${canonicalPublicEntrypoint()}export 'src/core/scene.dart';\n",
        );

        final result = await _runTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          _diagnostic(
            category: 'public export',
            detail:
                'lib/iwb_canvas_engine.dart must not export mutable core model',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'rejects conditional import/export branch in exported contract API to disallowed layers',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeCanonicalPublicExportScaffold(sandbox);
          _writeFile(sandbox, 'lib/src/contract/node_patch.dart', '''
export 'package:iwb_canvas_engine/src/contract/node_spec.dart'
    if (dart.library.io) 'package:iwb_canvas_engine/src/view/scene_view_interactive.dart';

class NodePatch {}
''');

          final result = await _runTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            _diagnostic(
              category: 'public export',
              detail:
                  'must not import/export controller/**, render/**, view/**, or serialization/**',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects conditional export of mutable core from iwb_canvas_engine.dart',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeCanonicalPublicExportScaffold(sandbox);
          _writeFile(
            sandbox,
            'lib/iwb_canvas_engine.dart',
            canonicalPublicEntrypoint().replaceFirst(
              "export 'src/contract/node_patch.dart';",
              "export 'src/contract/node_patch.dart' if (dart.library.io) 'src/core/scene.dart';",
            ),
          );

          final result = await _runTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            _diagnostic(
              category: 'public export',
              detail:
                  'lib/iwb_canvas_engine.dart must not export mutable core model',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects non-contract export without mutable-type leak scan policy',
      () async {
        // INV:INV-G-PUBLIC-ENTRYPOINTS
        final sandbox = await _createSandbox();
        try {
          _writeCanonicalPublicExportScaffold(sandbox);
          _writeFile(
            sandbox,
            'lib/iwb_canvas_engine.dart',
            "${canonicalPublicEntrypoint()}export 'src/view/foo.dart';\n",
          );
          _writeFile(sandbox, 'lib/src/view/foo.dart', '''
class SceneView {}
''');

          final result = await _runTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            _diagnostic(
              category: 'public entrypoint',
              detail:
                  'must declare a mutable-type leak scan policy in '
                  'tool/check_guardrails.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects scene/writeFindNode/writeMark*/id-bookkeeping in exported txn API',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeCanonicalPublicExportScaffold(sandbox);
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
              _diagnostic(
                category: 'public contract',
                detail:
                    'exported SceneWriteTxn must not expose raw scene access',
              ),
              _diagnostic(
                category: 'public contract',
                detail: 'exported SceneWriteTxn must not expose writeFindNode',
              ),
              _diagnostic(
                category: 'public contract',
                detail:
                    'exported SceneWriteTxn must not expose writeMark* '
                    'escape hatches',
              ),
              _diagnostic(
                category: 'public contract',
                detail:
                    'exported SceneWriteTxn must not expose node-id '
                    'bookkeeping methods',
              ),
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'skips mutable-type leak scan for explicitly classified exported view API',
      () async {
        // INV:INV-ENG-NO-EXTERNAL-MUTATION
        final sandbox = await _createSandbox();
        try {
          _writeCanonicalPublicExportScaffold(sandbox);
          _writeFile(sandbox, 'lib/src/view/scene_view_interactive.dart', '''
abstract class SceneView {
  Scene get scene;
}
''');

          final result = await _runTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, 0, reason: result.stderr.toString());
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects mutable core type in exported public API signature',
      () async {
        // INV:INV-ENG-NO-EXTERNAL-MUTATION
        final sandbox = await _createSandbox();
        try {
          _writeCanonicalPublicExportScaffold(sandbox);
          _writeFile(sandbox, 'lib/src/contract/snapshot.dart', '''
abstract class Foo {
  Scene get scene;
}
''');

          final result = await _runTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            _diagnostic(
              category: 'public contract',
              detail: 'exported API must not expose mutable core types',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects multiline mutable core type in exported public API signature',
      () async {
        final sandbox = await _createSandbox();
        try {
          _writeCanonicalPublicExportScaffold(sandbox);
          _writeFile(sandbox, 'lib/src/contract/snapshot.dart', '''
abstract class Foo {
  Scene
  get scene;
}
''');

          final result = await _runTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            _diagnostic(
              category: 'public contract',
              detail: 'exported API must not expose mutable core types',
            ),
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
          _diagnostic(
            category: 'controller API',
            detail:
                'mutating symbol "replaceScene" must be routed through '
                'write*/txn* transaction API',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects exported contract import from controller layer', () async {
      final sandbox = await _createSandbox();
      try {
        _writeCanonicalPublicExportScaffold(sandbox);
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
          _diagnostic(
            category: 'public export',
            detail:
                'exported contract/** and the model facade must not '
                'import/export controller/**, render/**, view/**, or '
                'serialization/**',
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
      'accepts guarded multiline interactive entrypoint signatures',
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
  void handlePointer(
    int value,
  ) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  set mode(
    int value,
  ) {
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
            _diagnostic(
              category: 'interactive API',
              detail:
                  'public SceneControllerInteractive entrypoints must guard '
                  'resolver purity with _ensurePublicSideEffectAllowed',
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
            _diagnostic(
              category: 'interactive API',
              detail:
                  'dispose() must guard resolver purity with '
                  'allowAfterDispose: true',
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
dev_dependencies:
  analyzer: ^8.4.0
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
  _copyFile(
    '$sourceRoot/tool/src/layer_guardrails.dart',
    '${sandbox.path}/tool/src/layer_guardrails.dart',
  );

  return sandbox;
}

void _writeCanonicalPublicExportScaffold(Directory sandbox) {
  _writeFile(
    sandbox,
    'lib/iwb_canvas_engine.dart',
    canonicalPublicEntrypoint(),
  );
  for (final filePath in canonicalPublicExportFiles) {
    _writeFile(sandbox, filePath, '// stub\n');
  }
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
