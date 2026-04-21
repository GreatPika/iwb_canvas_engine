import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// INV:INV-ENG-CONTROLLER-COMMIT-RUNTIME-BOUNDARY
// INV:INV-ENG-TXN-FINALIZED-BEFORE-COMMIT-PLAN

String _extractMethodBody({
  required String source,
  required String methodStart,
}) {
  final startIndex = source.indexOf(methodStart);
  if (startIndex < 0) {
    throw StateError('Method signature not found: $methodStart');
  }
  var bodyStart = -1;
  var parenDepth = 0;
  for (var i = startIndex; i < source.length; i++) {
    final char = source[i];
    if (char == '(') {
      parenDepth += 1;
    } else if (char == ')') {
      if (parenDepth > 0) {
        parenDepth -= 1;
      }
    } else if (char == '{' && parenDepth == 0) {
      bodyStart = i;
      break;
    }
  }
  if (bodyStart < 0) {
    throw StateError('Method body start not found: $methodStart');
  }

  var depth = 1;
  for (var i = bodyStart + 1; i < source.length; i++) {
    final char = source[i];
    if (char == '{') {
      depth += 1;
    } else if (char == '}') {
      depth -= 1;
      if (depth == 0) {
        return source.substring(bodyStart + 1, i);
      }
    }
  }
  throw StateError('Method body end not found: $methodStart');
}

void main() {
  test(
    'scene store controller public facade no longer keeps commit runtime helpers',
    () {
      final controllerSource = File(
        'lib/src/controller/scene_store_controller.dart',
      ).readAsStringSync();
      final runtimeSource = File(
        'lib/src/controller/scene_controller_commit_runtime.dart',
      ).readAsStringSync();
      final planSource = File(
        'lib/src/controller/scene_controller_commit_plan.dart',
      ).readAsStringSync();
      final finalizerSource = File(
        'lib/src/controller/selection_post_apply_finalizer.dart',
      ).readAsStringSync();
      final executionSource = File(
        'lib/src/controller/scene_controller_commit_execution.dart',
      ).readAsStringSync();
      final debugSource = File(
        'lib/src/controller/scene_controller_commit_debug.dart',
      ).readAsStringSync();
      final postCommitSource = File(
        'lib/src/controller/scene_controller_post_commit_lifecycle.dart',
      ).readAsStringSync();

      expect(controllerSource, contains('class SceneStoreController'));
      expect(
        controllerSource,
        isNot(contains('class SceneControllerPostCommitLifecycle')),
      );
      expect(
        controllerSource,
        isNot(contains('sealed class ControllerCommitPlan')),
      );
      expect(
        controllerSource,
        isNot(contains('class SceneControllerCommitPlanner')),
      );

      expect(runtimeSource, contains('class SceneControllerCommitRuntime'));
      expect(runtimeSource, contains('class SceneControllerCommittedWrite'));
      expect(
        runtimeSource,
        isNot(contains('class SceneControllerPostCommitLifecycle')),
      );
      expect(
        runtimeSource,
        isNot(contains('sealed class ControllerCommitPlan')),
      );
      expect(runtimeSource, contains('deriveControllerCommitInitialPhases('));
      expect(
        runtimeSource,
        isNot(contains('class SceneControllerCommitPlanner')),
      );
      expect(
        postCommitSource,
        contains('class SceneControllerPostCommitLifecycle'),
      );
      expect(
        File(
          'lib/src/controller/internal/selection_normalizer.dart',
        ).existsSync(),
        isFalse,
      );
      expect(planSource, contains('sealed class ControllerCommitPlan'));
      expect(
        planSource,
        contains('List<String> deriveControllerCommitInitialPhases'),
      );
      expect(
        planSource,
        contains('ControllerCommitPlan buildControllerCommitPlan'),
      );
      expect(
        planSource,
        contains('List<String> resolveControllerCommitPhases'),
      );
      expect(planSource, isNot(contains('class SceneControllerCommitPlanner')));
      expect(
        executionSource,
        contains('class SceneControllerWriteCommitResult'),
      );
      expect(
        finalizerSource,
        contains('void finalizePostApplySelection(TxnContext ctx)'),
      );
      expect(
        executionSource,
        contains('class SceneControllerCommitExecutionContext'),
      );
      expect(debugSource, contains('class SceneControllerCommitDebugState'));
      expect(planSource, isNot(contains('txnNormalizeSelection(')));
    },
  );

  test('scene store controller write facade delegates into commit runtime', () {
    final controllerSource = File(
      'lib/src/controller/scene_store_controller.dart',
    ).readAsStringSync();
    final body = _extractMethodBody(
      source: controllerSource,
      methodStart: 'T write<T>(T Function(SceneWriteTxn txn) fn)',
    );

    expect(body, contains('return _commitRuntime.write(fn);'));
    expect(body, isNot(contains('final createdCtx = TxnContext(')));
    expect(body, isNot(contains('final writer = SceneWriter(')));
    expect(body, isNot(contains('_txnWriteCommit(')));
  });

  test(
    'scene store controller repaint facade delegates into commit runtime',
    () {
      final controllerSource = File(
        'lib/src/controller/scene_store_controller.dart',
      ).readAsStringSync();
      final body = _extractMethodBody(
        source: controllerSource,
        methodStart: 'void requestRepaint()',
      );

      expect(body, contains('_commitRuntime.requestRepaint();'));
      expect(body, isNot(contains('_postCommitLifecycle')));
      expect(body, isNot(contains('_repaintFlag')));
    },
  );
}
