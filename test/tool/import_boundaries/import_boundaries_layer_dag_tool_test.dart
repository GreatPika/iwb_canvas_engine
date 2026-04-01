@Tags(['tool'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../support/guardrails_tool_test_support.dart';
import '../support/tool_process_test_support.dart';

void main() {
  group('tool/check_import_boundaries.dart', () {
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

    test('allows view -> interactive import', () async {
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

    test('allows view -> interactive seam import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_view_pointer_semantics.dart',
          'abstract interface class SceneViewPointerSemanticsBridge {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/scene_view_interactive.dart',
          "import 'package:iwb_canvas_engine/src/interactive/scene_view_pointer_semantics.dart';\n",
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
            contains('view/internal boundary violation:'),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('rejects scene_view_interactive.dart -> any interactive/internal target',
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
          contains('view/internal boundary violation:'),
        );
        expect(
          result.stderr.toString(),
          contains(
            'scene_view_interactive.dart must not import interactive/internal/**',
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
