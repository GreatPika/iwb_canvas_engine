@Tags(['tool'])
library;

import 'package:test/test.dart';

import '../support/guardrails_sandbox_support.dart';
import '../support/tool_diagnostic_matchers.dart';
import '../support/tool_process_test_support.dart';

void main() {
  group('tool/check_guardrails.dart', () {
    // INV:INV-ENG-MODEL-ARCHITECTURE-BOUNDARY
    // INV:INV-ENG-RUNTIME-SCENE-STRUCTURE-OWNER
    // INV:INV-ENG-RUNTIME-NODE-VALUE-OWNERS
    test('rejects part directives under lib/src/model', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/model/scene_value_validation.dart',
          '''
part 'scene_value_validation_support.dart';

void validateScene() {}
''',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/model/scene_value_validation_support.dart',
          '''
part of 'scene_value_validation.dart';

void validateSupport() {}
''',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'model architecture',
            detail: 'lib/src/model/** must stay part-free',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects document.dart importing scene_builder.dart again', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeSandboxFile(sandbox, 'lib/src/model/document.dart', '''
import 'scene_builder.dart';

void txnSceneFromSnapshot() {}
''');
        writeSandboxFile(
          sandbox,
          'lib/src/model/scene_builder.dart',
          'void sceneBuildFromSnapshot() {}\n',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'model architecture',
            detail: 'document.dart must consume scene_from_snapshot.dart',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'rejects non-model code importing internal model owner modules directly',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(sandbox, 'lib/src/controller/scene_runtime.dart', '''
import '../model/document_selection.dart';

void normalizeSelection() {}
''');
          writeSandboxFile(
            sandbox,
            'lib/src/model/document_selection.dart',
            'void txnNormalizeSelection() {}\n',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'model architecture',
              detail:
                  'canonical model facades instead of importing or '
                  're-exporting internal owner module',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects non-model code importing internal document patch owners directly',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(sandbox, 'lib/src/controller/scene_runtime.dart', '''
import '../model/document_node_patch_text.dart';

void patchTextNode() {}
''');
          writeSandboxFile(
            sandbox,
            'lib/src/model/document_node_patch_text.dart',
            'bool txnApplyTextNodePatch(Object node, Object patch, {required bool dryRun}) => false;\n',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'model architecture',
              detail:
                  'canonical model facades instead of importing or '
                  're-exporting internal owner module '
                  'document_node_patch_text.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects non-model code importing scene_builder.dart directly',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/serialization/scene_codec.dart',
            '''
import '../model/scene_builder.dart';

void decodeScene() {}
''',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/model/scene_builder.dart',
            'void sceneBuildFromJsonMap() {}\n',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'model architecture',
              detail:
                  'canonical model facades instead of importing or '
                  're-exporting internal owner module scene_builder.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects non-model code importing internal scene builder decode owners',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/serialization/scene_codec.dart',
            '''
import '../model/scene_builder_decode_scene.dart';

void decodeScene() {}
''',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/model/scene_builder_decode_scene.dart',
            'void sceneBuilderDecodeSceneSnapshotFromJson() {}\n',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'model architecture',
              detail:
                  'canonical model facades instead of importing or '
                  're-exporting internal owner module '
                  'scene_builder_decode_scene.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects non-model code importing scene_import_draft.dart directly',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/serialization/scene_codec.dart',
            '''
import '../model/scene_import_draft.dart';

void decodeScene() {}
''',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/model/scene_import_draft.dart',
            'class SceneImportDraft {}\n',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'model architecture',
              detail:
                  'canonical model facades instead of importing or '
                  're-exporting internal owner module scene_import_draft.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects non-model code importing scene_import_draft_from_snapshot.dart directly',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/serialization/scene_codec.dart',
            '''
import '../model/scene_import_draft_from_snapshot.dart';

void decodeScene() {}
''',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/model/scene_import_draft_from_snapshot.dart',
            'Object sceneImportDraftFromSnapshot(Object snapshot) => snapshot;\n',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'model architecture',
              detail:
                  'canonical model facades instead of importing or '
                  're-exporting internal owner module '
                  'scene_import_draft_from_snapshot.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects non-model code importing scene_from_import_draft.dart directly',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/serialization/scene_codec.dart',
            '''
import '../model/scene_from_import_draft.dart';

void decodeScene() {}
''',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/model/scene_from_import_draft.dart',
            'Object sceneFromImportDraft(Object draft) => draft;\n',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'model architecture',
              detail:
                  'canonical model facades instead of importing or '
                  're-exporting internal owner module '
                  'scene_from_import_draft.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('rejects controller direct scene.layers.add ownership', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeSandboxFile(sandbox, 'lib/src/controller/scene_runtime.dart', '''
import '../core/scene.dart';

class _SceneRuntime {
  void _touch(Scene scene) {
    scene.layers.add(Object());
  }
}
''');
        writeSandboxFile(sandbox, 'lib/src/core/scene.dart', '''
class Scene {
  final List<Object> layers = <Object>[];
}
''');

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'model architecture',
            detail:
                'controller code must not mutate scene.layers directly via .add(...); '
                'use model-owned scene layer mutation helpers instead.',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects controller direct scene.layers.removeAt ownership', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeSandboxFile(sandbox, 'lib/src/controller/scene_runtime.dart', '''
import '../core/scene.dart';

class _SceneRuntime {
  void _touch(Scene scene) {
    scene.layers.removeAt(0);
  }
}
''');
        writeSandboxFile(sandbox, 'lib/src/core/scene.dart', '''
class Scene {
  final List<Object> layers = <Object>[];
}
''');

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'model architecture',
            detail:
                'controller code must not mutate scene.layers directly via '
                '.removeAt(...); use model-owned scene layer mutation helpers instead.',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'rejects controller direct scene.layers index assignment ownership',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(sandbox, 'lib/src/controller/scene_runtime.dart', '''
import '../core/scene.dart';

class _SceneRuntime {
  void _touch(Scene scene) {
    scene.layers[0] = Object();
  }
}
''');
          writeSandboxFile(sandbox, 'lib/src/core/scene.dart', '''
class Scene {
  final List<Object> layers = <Object>[];
}
''');

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'model architecture',
              detail:
                  'controller code must not mutate scene.layers directly via '
                  '[]=; use model-owned scene layer mutation helpers instead.',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('rejects cascaded direct scene.layers mutations', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeSandboxFile(sandbox, 'lib/src/controller/scene_runtime.dart', '''
import '../core/scene.dart';

class _SceneRuntime {
  void _touch(Scene scene) {
    scene.layers
      ..clear()
      ..add(Object());
  }
}
''');
        writeSandboxFile(sandbox, 'lib/src/core/scene.dart', '''
class Scene {
  final List<Object> layers = <Object>[];
}
''');

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'model architecture',
            detail:
                'controller code must not mutate scene.layers directly via '
                '.clear(...); use model-owned scene layer mutation helpers instead.',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'allows controller scene layer mutation through document facade helper',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(sandbox, 'lib/src/controller/scene_runtime.dart', '''
import '../core/scene.dart';
import '../model/document.dart';

class _SceneRuntime {
  void _touch(Scene scene) {
    txnReplaceContentLayerInScene(
      scene: scene,
      layerIndex: 0,
      layer: Object(),
    );
  }
}
''');
          writeSandboxFile(sandbox, 'lib/src/core/scene.dart', '''
class Scene {
  final List<Object> layers = <Object>[];
}
''');
          writeSandboxFile(sandbox, 'lib/src/model/document.dart', '''
import '../core/scene.dart';

void txnReplaceContentLayerInScene({
  required Scene scene,
  required int layerIndex,
  required Object layer,
}) {}
''');

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, 0);
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('allows local layers collections inside controller code', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeSandboxFile(sandbox, 'lib/src/controller/scene_runtime.dart', '''
class _SceneRuntime {
  void _touch() {
    final layers = <Object>[];
    layers.add(Object());
    layers.insert(0, Object());
  }
}
''');

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, 0);
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('allows non-scene layers fields inside controller code', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeSandboxFile(sandbox, 'lib/src/controller/scene_runtime.dart', '''
class WidgetState {
  final List<Object> layers = <Object>[];
}

class _SceneRuntime {
  void _touch(WidgetState widget) {
    widget.layers.add(Object());
    widget.layers.insert(0, Object());
  }
}
''');

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, 0);
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'rejects constrained runtime owner fields as direct core storage',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(sandbox, 'lib/src/core/scene_node.dart', '''
class SceneNode {
  double hitPadding = 0;
}
''');

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'model architecture',
              detail:
                  'constrained runtime field hitPadding must not be stored as a direct core-owner field',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects non-model code importing split scene builder metadata owner',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/serialization/scene_codec.dart',
            '''
import '../model/scene_builder_decode_scene_metadata.dart';

void decodeSceneMetadata() {}
''',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/model/scene_builder_decode_scene_metadata.dart',
            'void sceneBuilderDecodeSceneMetadata() {}\n',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'model architecture',
              detail:
                  'canonical model facades instead of importing or '
                  're-exporting internal owner module '
                  'scene_builder_decode_scene_metadata.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects non-model code importing split document scene insert owner',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(sandbox, 'lib/src/controller/scene_runtime.dart', '''
import '../model/document_scene_insert.dart';

void inspectInsertOwner() {}
''');
          writeSandboxFile(
            sandbox,
            'lib/src/model/document_scene_insert.dart',
            'bool txnInsertNodeInScene() => true;\n',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'model architecture',
              detail:
                  'canonical model facades instead of importing or '
                  're-exporting internal owner module '
                  'document_scene_insert.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects non-model code importing scene node mapping common owner',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/serialization/scene_codec.dart',
            '''
import '../model/scene_node_boundary_mapping_common.dart';

void decodeScene() {}
''',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/model/scene_node_boundary_mapping_common.dart',
            'enum TextNodeSnapshotSizePolicy { preserveBoundarySize }\n',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'model architecture',
              detail:
                  'canonical model facades instead of importing or '
                  're-exporting internal owner module '
                  'scene_node_boundary_mapping_common.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects non-model code importing scene node mapping facade directly',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/serialization/scene_codec.dart',
            '''
import '../model/scene_node_boundary_mapping.dart';

void decodeScene() {}
''',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/model/scene_node_boundary_mapping.dart',
            'void sceneNodeFromSnapshotViaBoundarySchema() {}\n',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'model architecture',
              detail:
                  'canonical model facades instead of importing or '
                  're-exporting internal owner module '
                  'scene_node_boundary_mapping.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects non-model code importing scene_policy.dart directly',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/serialization/scene_codec.dart',
            '''
import '../model/scene_policy.dart';

void validateScene() {}
''',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/model/scene_policy.dart',
            'abstract final class ScenePolicy {}\n',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'model architecture',
              detail:
                  'canonical model facades instead of importing or '
                  're-exporting internal owner module scene_policy.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    // INV:INV-SER-IMPORT-DIAGNOSTIC-SURFACE
    test(
      'rejects non-model code importing scene_validation_path_surface.dart directly',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/serialization/scene_codec.dart',
            '''
import '../model/scene_validation_path_surface.dart';

void decodeScene() {}
''',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/model/scene_validation_path_surface.dart',
            'enum SceneValidationPathSurface { snapshot, jsonImport }\n',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'model architecture',
              detail:
                  'canonical model facades instead of importing or '
                  're-exporting internal owner module '
                  'scene_validation_path_surface.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    // INV:INV-SER-IMPORT-DIAGNOSTIC-SURFACE
    test(
      'rejects scene_policy.dart reintroducing direct import-range diagnostics',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(sandbox, 'lib/src/model/scene_policy.dart', '''
import '../contract/scene_data_exception.dart';

void validateImportDraft(double value) {
  throw SceneDataException.outOfRange(
    path: 'layers[0].nodes[0].start.x',
    min: -1,
    max: 1,
    source: value,
  );
}
''');

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'model architecture',
              detail:
                  'scene_policy.dart must not own direct import-range diagnostics',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects non-model code re-exporting restricted model owner modules',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(sandbox, 'lib/src/controller/model_barrel.dart', '''
export '../model/scene_builder.dart';
''');
          writeSandboxFile(
            sandbox,
            'lib/src/model/scene_builder.dart',
            'void sceneBuildFromJsonMap() {}\n',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'model architecture',
              detail:
                  'canonical model facades instead of importing or re-exporting '
                  'internal owner module scene_builder.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('rejects reintroduced removed residual model support files', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/model/scene_node_boundary_mapping_support.dart',
          'void legacySupport() {}\n',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'model architecture',
            detail:
                'removed residual seam '
                'scene_node_boundary_mapping_support.dart must not reappear',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('allows non-model imports of canonical model facades', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeSandboxFile(sandbox, 'lib/src/controller/scene_runtime.dart', '''
import '../model/scene_builder_api.dart';
import '../model/document.dart';
import '../model/scene_document_codec.dart';
import '../model/scene_value_validation.dart';

void useModelFacades() {}
''');
        writeSandboxFile(
          sandbox,
          'lib/src/model/scene_builder_api.dart',
          'void buildScene() {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/model/document.dart',
          'void txn() {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/model/scene_document_codec.dart',
          'void sceneDecodeDocumentFromJsonMap() {}\n',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/model/scene_value_validation.dart',
          'void validateScene() {}\n',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });
  });
}
