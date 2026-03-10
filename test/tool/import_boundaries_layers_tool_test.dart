@Tags(['tool'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'support/guardrails_tool_test_support.dart';
import 'support/tool_process_test_support.dart';

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

    test('rejects core -> unknown target layer import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/unknown/value.dart',
          'class UnknownValue {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/core/value.dart',
          "import 'package:iwb_canvas_engine/src/unknown/value.dart';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
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
      final sandbox = await createImportBoundariesSandbox();
      try {
        final deletedLayerSegments = ['src', 'public', 'value.dart'];
        final deletedLayerPathSuffix = deletedLayerSegments.join('/');
        final deletedLayerFilePath = 'lib/$deletedLayerPathSuffix';
        final deletedLayerImportTarget =
            'package:iwb_canvas_engine/$deletedLayerPathSuffix';

        writeSandboxFile(
          sandbox,
          deletedLayerFilePath,
          'class DeletedLayerValue {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/core/value.dart',
          "import '$deletedLayerImportTarget';\n",
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
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
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/public/value.dart',
          'class DeletedLayerValue {}\n',
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
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
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/unknown/value.dart',
          'class UnknownValue {}\n',
        );

        final result = await runSandboxTool(
          sandbox,
          'check_import_boundaries.dart',
        );
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
        final sandbox = await createImportBoundariesSandbox();
        try {
          writeSandboxFile(
            sandbox,
            'lib/src/unknown/value.dart',
            'class UnknownValue {}\n',
          );
          writeSandboxFile(
            sandbox,
            layerCase.filePath,
            "import 'package:iwb_canvas_engine/src/unknown/value.dart';\n",
          );

          final result = await runSandboxTool(
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

    test(
      'allows top-level lib/src file without treating it as a layer',
      () async {
        final sandbox = await createImportBoundariesSandbox();
        try {
          writeSandboxFile(
            sandbox,
            'lib/src/version.dart',
            'const version = 1;\n',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/core/value.dart',
            'class CoreValue {}\n',
          );

          final result = await runSandboxTool(
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
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/contract/value.dart',
          'class ContractValue {}\n',
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
          'lib/src/interactive/controller.dart',
          'class InteractiveController {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/view/widget.dart',
          "import 'package:iwb_canvas_engine/src/interactive/controller.dart';\n",
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

    test('allows serialization -> model import', () async {
      final sandbox = await createImportBoundariesSandbox();
      try {
        writeSandboxFile(
          sandbox,
          'lib/src/model/document.dart',
          'class Document {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/serialization/codec.dart',
          "import 'package:iwb_canvas_engine/src/model/document.dart';\n",
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
          'lib/src/serialization/codec_guards.dart',
          'void guardCodec() {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/model/scene_builder.dart',
          "import 'package:iwb_canvas_engine/src/serialization/codec_guards.dart';\n",
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
          'lib/src/controller/types.dart',
          'class ControllerType {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/core/value.dart',
          "import 'package:iwb_canvas_engine/src/controller/types.dart';\n",
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
