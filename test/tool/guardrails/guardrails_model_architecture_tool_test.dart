@Tags(['tool'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../support/guardrails_tool_test_support.dart';
import '../support/tool_process_test_support.dart';

void main() {
  group('tool/check_guardrails.dart', () {
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

    test('allows non-model imports of canonical model facades', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeSandboxFile(sandbox, 'lib/src/controller/scene_runtime.dart', '''
import '../model/document.dart';
import '../model/scene_document_codec.dart';
import '../model/scene_value_validation.dart';

void useModelFacades() {}
''');
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
