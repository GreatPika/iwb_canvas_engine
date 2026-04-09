@Tags(['tool'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../support/guardrails_tool_test_support.dart';
import '../support/tool_process_test_support.dart';

void main() {
  group('tool/check_guardrails.dart', () {
    // INV:INV-ENG-CONTROLLER-NO-FULL-VIEW-RENDER-STATE
    test(
      'allows SceneStoreController to stay on SceneRenderState without full view render-state import',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            '''
import '../contract/scene_render_state.dart';

class SceneStoreController implements SceneRenderState {
  final int controllerEpoch = 0;

  SceneRenderState? currentState;
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
      'rejects controller-layer import of scene_view_render_state.dart',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            '''
import '../contract/scene_view_render_state.dart';

class SceneStoreController {
  final int controllerEpoch = 0;
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'controller layer must not import '
                  'scene_view_render_state.dart',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    test(
      'rejects SceneStoreController implementing SceneViewRenderState',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_store_controller.dart',
            '''
class SceneStoreController implements SceneViewRenderState {
  final int controllerEpoch = 0;
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'SceneStoreController must not implement SceneViewRenderState',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );

    // INV:INV-ENG-WRITE-ONLY-MUTATION
    test('rejects mutating symbol outside write/txn prefixes', () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeSandboxFile(sandbox, 'lib/src/controller/store.dart', '''
class Store {
  int controllerEpoch = 0;

  void replaceScene() {}
}
''');

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
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

    test(
      'rejects direct selection writer mutation bypass outside canonical ops',
      () async {
        final sandbox = await createGuardrailsSandbox();
        try {
          writeSandboxFile(
            sandbox,
            'lib/src/controller/scene_writer_selection.dart',
            '''
List<String>? sceneWriterWriteSelectionReplaceResult(Object writer, Set<String> ids) {
  final ctx = writer.runtime.ctx;
  ctx.workingSelection
    ..clear()
    ..addAll(ids);
  return ids.toList();
}
''',
          );

          final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
          expect(result.exitCode, isNonZero);
          expect(
            result.stderr.toString(),
            diagnostic(
              category: 'controller API',
              detail:
                  'selection writer entrypoints must route through canonical '
                  'selection-state mutation ops instead of touching '
                  'workingSelection/changeSet directly',
            ),
          );
        } finally {
          sandbox.deleteSync(recursive: true);
        }
      },
    );
  });
}
