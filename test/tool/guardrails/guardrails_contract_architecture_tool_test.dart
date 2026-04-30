@Tags(['tool'])
library;

import 'package:test/test.dart';

import '../support/guardrails_sandbox_support.dart';
import '../support/tool_diagnostic_matchers.dart';
import '../support/tool_process_test_support.dart';

void main() {
  group('tool/check_guardrails.dart', () {
    // INV:INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY
    test(
      'allows canonical contract internal surfaces for non-contract code',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/model/scene_snapshot_from_scene.dart',
            '''
import '../contract/internal/node_boundary_schema.dart';
import '../contract/internal/snapshot_fast_path.dart';

void materializeSceneSnapshot() {
  nodeSnapshotFieldSchema();
  materializeSceneSnapshotEdge();
}
''',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/contract/internal/node_boundary_schema.dart',
            'void nodeSnapshotFieldSchema() {}\n',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/contract/internal/snapshot_fast_path.dart',
            'void materializeSceneSnapshotEdge() {}\n',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, 0);
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test('rejects part directives under lib/src/contract', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
part 'internal/snapshot_fast_path.part.dart';

void sceneSnapshot() {}
''');
        writeSandboxFile(
          sandbox,
          'lib/src/contract/internal/snapshot_fast_path.part.dart',
          '''
part of '../snapshot.dart';

void privilegedSnapshotAssembly() {}
''',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'contract architecture',
            detail: 'lib/src/contract/** must stay part-free',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rejects removed residual contract seams that reappear', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/contract/internal/node_spec_fast_path.part.dart',
          'void imageNodeSpecFromValidated() {}\n',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'contract architecture',
            detail:
                'removed residual seam node_spec_fast_path.part.dart must '
                'not reappear',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    });

    test(
      'rejects non-contract code importing internal schema owner modules directly',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/serialization/scene_codec.dart',
            '''
import '../contract/internal/node_boundary_schema_spec.dart';

void decodeScene() {}
''',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/contract/internal/node_boundary_schema_spec.dart',
            'void decodeNodeSpecField() {}\n',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'contract architecture',
              detail:
                  'canonical contract surfaces instead of importing or '
                  're-exporting internal contract module '
                  'node_boundary_schema_spec.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects non-contract code importing internal snapshot backing directly',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/model/scene_snapshot_from_scene.dart',
            '''
import '../contract/internal/snapshot_backing.dart';

void buildSceneBacking() {}
''',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/contract/internal/snapshot_backing.dart',
            'void sceneSnapshotBackingFromValidated() {}\n',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'contract architecture',
              detail:
                  'canonical contract surfaces instead of importing or '
                  're-exporting internal contract module '
                  'snapshot_backing.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects non-contract code importing unsafe snapshot materialization directly',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/model/scene_snapshot_from_scene.dart',
            '''
import '../contract/internal/unsafe_snapshot_materialization.dart';

void decodeScene() {}
''',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/contract/internal/unsafe_snapshot_materialization.dart',
            'void unsafeMaterializeSceneSnapshot() {}\n',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'contract architecture',
              detail:
                  'canonical contract surfaces instead of importing or '
                  're-exporting internal contract module '
                  'unsafe_snapshot_materialization.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects non-contract code importing internal spec and patch fast paths directly',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/model/scene_builder_decode_node_family.dart',
            '''
export '../contract/internal/node_spec_fast_path.dart';
import '../contract/internal/node_patch_fast_path.dart';

void buildNodeBoundary() {}
''',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/contract/internal/node_spec_fast_path.dart',
            'void imageNodeSpecFromValidated() {}\n',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/contract/internal/node_patch_fast_path.dart',
            'void imageNodePatchFromValidated() {}\n',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'contract architecture',
              detail:
                  'canonical contract surfaces instead of importing or '
                  're-exporting internal contract module '
                  'node_spec_fast_path.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects arbitrary new non-canonical contract internal modules',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/model/scene_snapshot_from_scene.dart',
            '''
import '../contract/internal/future_owner.dart';

void buildSceneSnapshot() {}
''',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/contract/internal/future_owner.dart',
            'void futureOwnerHook() {}\n',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'contract architecture',
              detail:
                  'canonical contract surfaces instead of importing or '
                  're-exporting internal contract module future_owner.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'allows JSON object-key diagnostics sourced from the offending key',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/contract/scene_data_exception.dart',
            '''
class SceneDataException {
  static void jsonObjectKeysMustBeStrings({String? path, Object? source}) {}
}
''',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/contract/validated/validated_value_support.dart',
            '''
import '../scene_data_exception.dart';

void requireJsonObjectKeys(Map<Object?, Object?> raw) {
  for (final entry in raw.entries) {
    final key = entry.key;
    if (key is! String) {
      SceneDataException.jsonObjectKeysMustBeStrings(source: key);
    }
  }
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, 0);
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects JSON object-key diagnostics sourced from the whole object',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/contract/scene_data_exception.dart',
            '''
class SceneDataException {
  static void jsonObjectKeysMustBeStrings({String? path, Object? source}) {}
}
''',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/contract/validated/validated_value_support.dart',
            '''
import '../scene_data_exception.dart';

void requireJsonObjectKeys(Map<Object?, Object?> raw) {
  for (final entry in raw.entries) {
    final key = entry.key;
    if (key is! String) {
      SceneDataException.jsonObjectKeysMustBeStrings(source: raw);
    }
  }
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'contract architecture',
              detail:
                  'jsonObjectKeysMustBeStrings diagnostics must pass the '
                  'offending object key as source',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects JSON object-key diagnostics sourced from a key-suffixed alias',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeMinimalControllerStore(sandbox);
          writeSandboxFile(
            sandbox,
            'lib/src/contract/scene_data_exception.dart',
            '''
class SceneDataException {
  static void jsonObjectKeysMustBeStrings({String? path, Object? source}) {}
}
''',
          );
          writeSandboxFile(
            sandbox,
            'lib/src/contract/validated/validated_value_support.dart',
            '''
import '../scene_data_exception.dart';

void requireJsonObjectKeys(Map<Object?, Object?> raw) {
  final rawKey = raw;
  SceneDataException.jsonObjectKeysMustBeStrings(source: rawKey);
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'contract architecture',
              detail:
                  'jsonObjectKeysMustBeStrings diagnostics must pass the '
                  'offending object key as source',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );
  });
}
