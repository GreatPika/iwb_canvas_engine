@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../support/guardrails_tool_test_support.dart';
import '../support/tool_process_test_support.dart';

void writeContractBridgeSurfaces(Directory sandbox) {
  writeSandboxFile(
    sandbox,
    'lib/src/contract/internal/node_boundary_schema.dart',
    'class NodeBoundarySchema {}\n',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/contract/internal/snapshot_fast_path.dart',
    'class SnapshotFastPath {}\n',
  );
}

void main() {
  group('tool/check_import_boundaries.dart', () {
    // INV:INV-G-LAYER-DAG
    // INV:INV-ENG-VIEW-POINTER-SEMANTICS-BOUNDARY
    test('allows contract -> contract export', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/contract/value.dart',
          'class ContractValue {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/contract/api.dart',
          "export 'package:iwb_canvas_engine/src/contract/value.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('allows model facade -> model and contract imports', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/model/document.dart',
          'class DocumentModel {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/contract/snapshot.dart',
          'class SceneSnapshot {}\n',
        );
        writeSandboxFile(sandbox, 'lib/src/model/scene_builder_api.dart', '''
import 'package:iwb_canvas_engine/src/model/document.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';

class SceneBuilder {
  SceneSnapshot build(DocumentModel document) => SceneSnapshot();
}
''');

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects contract -> core/transform2d import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/core/transform2d.dart',
          'class Transform2D {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/contract/value.dart',
          "import 'package:iwb_canvas_engine/src/core/transform2d.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
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
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/core/nodes.dart',
          'enum PathFillRule { nonZero }\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/contract/value.dart',
          "import 'package:iwb_canvas_engine/src/core/nodes.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
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
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/core/value.dart',
          'class CoreValue {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/contract/value.dart',
          "import 'package:iwb_canvas_engine/src/core/value.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('layer DAG violation: contract/** must not import core/**'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('allows view -> render import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/render/painter.dart',
          'class Painter {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/widget.dart',
          "import 'package:iwb_canvas_engine/src/render/painter.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('allows scene_view_interactive.dart -> interactive import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          'class SceneController {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_interactive.dart',
          "import 'package:iwb_canvas_engine/src/interactive/scene_controller.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects contract -> core pointer_input_tracker import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/core/pointer_input_tracker.dart',
          'class PointerSample {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/contract/scene_view_runtime.dart',
          "import 'package:iwb_canvas_engine/src/core/pointer_input_tracker.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('layer DAG violation: contract/** must not import core/**'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('allows interactive -> core pointer_input_tracker import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/core/pointer_input_tracker.dart',
          'class PointerSample {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          "import 'package:iwb_canvas_engine/src/core/pointer_input_tracker.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('allows view -> core pointer_input_tracker import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/core/pointer_input_tracker.dart',
          'class PointerSample {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_pointer_router.dart',
          "import 'package:iwb_canvas_engine/src/core/pointer_input_tracker.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects non-shell view -> interactive import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          'class SceneController {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_render_surface.dart',
          "import 'package:iwb_canvas_engine/src/interactive/scene_controller.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('view runtime boundary violation:'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('allows interactive -> same-layer internal relative import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/interactive_runtime.dart',
          'class InteractiveRuntime {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          '''
import 'internal/interactive_runtime.dart';

class SceneController {
  final InteractiveRuntime runtime = InteractiveRuntime();
}
''',
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects interactive -> model import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/model/document.dart',
          'class DocumentModel {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          "import 'package:iwb_canvas_engine/src/model/document.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains(
            'layer DAG violation: interactive/** must not import model/**',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects render -> model import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/model/document.dart',
          'class DocumentModel {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/render/painter.dart',
          "import 'package:iwb_canvas_engine/src/model/document.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('layer DAG violation: render/** must not import model/**'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects view -> model import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/model/document.dart',
          'class DocumentModel {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/widget.dart',
          "import 'package:iwb_canvas_engine/src/model/document.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('layer DAG violation: view/** must not import model/**'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'rejects scene_view_render_surface.dart -> scene_controller_internal_access.dart',
      () async {
        final sandbox = await createImportBoundariesSandbox();
        try {
          writeSandboxFile(
            sandbox,
            'lib/src/interactive/internal/scene_controller_internal_access.dart',
            'class SceneControllerInternalAccess {}\n',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/view/scene_view_render_surface.dart',
            "import 'package:iwb_canvas_engine/src/interactive/internal/scene_controller_internal_access.dart';\n",
          );

          final result = await runSandboxTool(
            sandbox,
            'check_import_boundaries.dart',
          );
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains('view runtime boundary violation:'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects scene_view_interactive.dart -> any interactive/internal target',
      () async {
        final sandbox = await createImportBoundariesSandbox();
        try {
          writeSandboxFile(
            sandbox,
            'lib/src/interactive/internal/interactive_pointer_normalizer.dart',
            'class InteractivePointerNormalizer {}\n',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/view/scene_view_interactive.dart',
            "import 'package:iwb_canvas_engine/src/interactive/internal/interactive_pointer_normalizer.dart';\n",
          );

          final result = await runSandboxTool(
            sandbox,
            'check_import_boundaries.dart',
          );
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains('view runtime boundary violation:'),
          );
          expect(
            result.stderr.toString(),
            contains('view/** may reach interactive/** only through'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects view -> interactive/internal relative import as view runtime boundary violation',
      () async {
        final sandbox = await createImportBoundariesSandbox();
        try {
          writeSandboxFile(
            sandbox,
            'lib/src/interactive/internal/interactive_pointer_normalizer.dart',
            'class InteractivePointerNormalizer {}\n',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/view/scene_view_interactive.dart',
            '''
import '../interactive/internal/interactive_pointer_normalizer.dart';

class SceneViewInteractive {}
''',
          );

          final result = await runSandboxTool(
            sandbox,
            'check_import_boundaries.dart',
          );
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains('view runtime boundary violation:'),
          );
          expect(
            result.stderr.toString(),
            contains('view/** may reach interactive/** only through'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects view export -> interactive/internal target as view runtime boundary violation',
      () async {
        final sandbox = await createImportBoundariesSandbox();
        try {
          writeSandboxFile(
            sandbox,
            'lib/src/interactive/internal/interactive_pointer_normalizer.dart',
            'class InteractivePointerNormalizer {}\n',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/view/scene_view_interactive.dart',
            '''
export 'package:iwb_canvas_engine/src/interactive/internal/interactive_pointer_normalizer.dart';
''',
          );

          final result = await runSandboxTool(
            sandbox,
            'check_import_boundaries.dart',
          );
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains('view runtime boundary violation:'),
          );
          expect(
            result.stderr.toString(),
            contains('view/** may reach interactive/** only through'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects render -> controller/internal target as cross-layer internal boundary violation',
      () async {
        final sandbox = await createImportBoundariesSandbox();
        try {
          writeSandboxFile(
            sandbox,
            'lib/src/controller/internal/runtime.dart',
            'class ControllerRuntime {}\n',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/render/painter.dart',
            "import 'package:iwb_canvas_engine/src/controller/internal/runtime.dart';\n",
          );

          final result = await runSandboxTool(
            sandbox,
            'check_import_boundaries.dart',
          );
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains('cross-layer internal boundary violation:'),
          );
          expect(
            result.stderr.toString(),
            contains('render/** must not import controller/internal/**'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects model -> non-bridge contract/internal target as cross-layer internal boundary violation',
      () async {
        final sandbox = await createImportBoundariesSandbox();
        try {
          writeSandboxFile(
            sandbox,
            'lib/src/contract/internal/unlisted_internal.dart',
            'class UnlistedInternal {}\n',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/model/document.dart',
            "import 'package:iwb_canvas_engine/src/contract/internal/unlisted_internal.dart';\n",
          );

          final result = await runSandboxTool(
            sandbox,
            'check_import_boundaries.dart',
          );
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains('cross-layer internal boundary violation:'),
          );
          expect(
            result.stderr.toString(),
            contains('model/** must not import contract/internal/**'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('allows model -> snapshot_fast_path bridge import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeContractBridgeSurfaces(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/model/document.dart',
          "import 'package:iwb_canvas_engine/src/contract/internal/snapshot_fast_path.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('allows serialization -> node_boundary_schema bridge import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeContractBridgeSurfaces(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/serialization/scene_codec.dart',
          "import 'package:iwb_canvas_engine/src/contract/internal/node_boundary_schema.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects view -> node_boundary_schema bridge import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeContractBridgeSurfaces(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_interactive.dart',
          "import 'package:iwb_canvas_engine/src/contract/internal/node_boundary_schema.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('bridge boundary violation:'),
        );
        expect(
          result.stderr.toString(),
          contains(
            'view/** must not import contract/internal/node_boundary_schema.dart',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('allows view -> interactive public barrel re-export', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          'class SceneController {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/interactive_api.dart',
          "export 'src/interactive/scene_controller.dart';\n",
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_interactive.dart',
          "import 'package:iwb_canvas_engine/interactive_api.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'rejects view -> interactive/internal barrel re-export as view runtime boundary violation',
      () async {
        final sandbox = await createImportBoundariesSandbox();
        try {
          writeSandboxFile(
            sandbox,
            'lib/src/interactive/internal/interactive_pointer_normalizer.dart',
            'class InteractivePointerNormalizer {}\n',
          );
          writeSandboxFile(
            sandbox,
            'lib/interactive_internal_api.dart',
            "export 'src/interactive/internal/interactive_pointer_normalizer.dart';\n",
          );
          writeSandboxFile(
            sandbox,
            'lib/src/view/scene_view_interactive.dart',
            "import 'package:iwb_canvas_engine/interactive_internal_api.dart';\n",
          );

          final result = await runSandboxTool(
            sandbox,
            'check_import_boundaries.dart',
          );
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains('view runtime boundary violation:'),
          );
          expect(
            result.stderr.toString(),
            contains('view/** may reach interactive/** only through'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('allows model -> bridge barrel re-export', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeContractBridgeSurfaces(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/contract_bridge.dart',
          "export 'src/contract/internal/snapshot_fast_path.dart';\n",
        );
        writeSandboxFile(
          sandbox,
          'lib/src/model/document.dart',
          "import 'package:iwb_canvas_engine/contract_bridge.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects view -> bridge barrel re-export', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeContractBridgeSurfaces(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/contract_bridge.dart',
          "export 'src/contract/internal/node_boundary_schema.dart';\n",
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_interactive.dart',
          "import 'package:iwb_canvas_engine/contract_bridge.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('bridge boundary violation:'),
        );
        expect(
          result.stderr.toString(),
          contains(
            'view/** must not import contract/internal/node_boundary_schema.dart',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('allows serialization -> model import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/model/types.dart',
          'class ModelType {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/serialization/codec.dart',
          "import 'package:iwb_canvas_engine/src/model/types.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects model -> serialization import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/serialization/codec.dart',
          'class SceneCodec {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/model/types.dart',
          "import 'package:iwb_canvas_engine/src/serialization/codec.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains(
            'layer DAG violation: model/** must not import serialization/**',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects core -> controller import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/controller/store.dart',
          'class Store {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/core/value.dart',
          "import 'package:iwb_canvas_engine/src/controller/store.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
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
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/model/types.dart',
          'class ModelType {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/core/value.dart',
          "import 'package:iwb_canvas_engine/src/model/types.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('layer DAG violation: core/** must not import model/**'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('allows multiline import/export with show/hide combinators', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/render/painter.dart',
          'class Painter {}\nclass InternalPainter {}\n',
        );
        writeSandboxFile(sandbox, 'lib/src/view/widget.dart', '''
import
  'package:iwb_canvas_engine/src/render/painter.dart'
  show Painter;
export
  'package:iwb_canvas_engine/src/render/painter.dart'
  hide InternalPainter;

class Widget {}
''');

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('allows documentation links inside lib/src', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(sandbox, 'lib/src/core/value.dart', '''
/// See [CoreValue].
class CoreValue {}
''');

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'rejects doc import link as contract -> core boundary bypass',
      () async {
        final sandbox = await createImportBoundariesSandbox();
        try {
          writeSandboxFile(sandbox, 'lib/src/core/value.dart', '''
class CoreValue {}
''');
          writeSandboxFile(sandbox, 'lib/src/contract/value.dart', '''
/// @docImport '../core/value.dart';
/// See [CoreValue].
class ContractValue {}
''');

          final result = await runSandboxTool(
            sandbox,
            'check_import_boundaries.dart',
          );
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains('layer DAG violation: contract/** must not link core/**'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects part directive as contract -> core boundary bypass',
      () async {
        final sandbox = await createImportBoundariesSandbox();
        try {
          writeSandboxFile(sandbox, 'lib/src/contract/value.dart', '''
part '../core/value.part.dart';

class ContractValue {}
''');
          writeSandboxFile(sandbox, 'lib/src/core/value.part.dart', '''
part of '../contract/value.dart';

class CoreValuePart {}
''');

          final result = await runSandboxTool(
            sandbox,
            'check_import_boundaries.dart',
          );
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains('layer DAG violation: contract/** must not part core/**'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects part of directive as core -> model boundary bypass',
      () async {
        final sandbox = await createImportBoundariesSandbox();
        try {
          writeSandboxFile(sandbox, 'lib/src/model/value.dart', '''
part '../core/value.part.dart';

class ModelValue {}
''');
          writeSandboxFile(sandbox, 'lib/src/core/value.part.dart', '''
part of '../model/value.dart';

class CoreValuePart {}
''');

          final result = await runSandboxTool(
            sandbox,
            'check_import_boundaries.dart',
          );
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            contains('layer DAG violation: core/** must not part of model/**'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('rejects conditional import branch to forbidden layer', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/contract/safe.dart',
          'class SafeContract {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/core/value.dart',
          'class CoreValue {}\n',
        );
        writeSandboxFile(sandbox, 'lib/src/contract/value.dart', '''
import 'package:iwb_canvas_engine/src/contract/safe.dart'
    if (dart.library.io) 'package:iwb_canvas_engine/src/core/value.dart';

class ContractValue extends SafeContract {}
''');

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          contains('layer DAG violation: contract/** must not import core/**'),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  });
}
