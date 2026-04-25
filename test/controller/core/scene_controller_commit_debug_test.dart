import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/controller/scene_store_controller.dart';

// INV:INV-ENG-PERFORMANCE-PROOF-CONTOUR

void main() {
  SceneSnapshot twoRectSnapshot() {
    return SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          id: 'layer-auto-0',
          nodes: <NodeSnapshot>[
            RectNodeSnapshot(id: 'r1', size: Size(10, 10)),
            RectNodeSnapshot(id: 'r2', size: Size(12, 12)),
          ],
        ),
      ],
    );
  }

  test('records state-changing commit attribution on debug seam', () {
    final controller = SceneStoreController(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeNodePatch(
        RectNodePatch(id: 'r1', strokeWidth: PatchField<double>.value(2)),
      );
    });

    final attribution = controller.debug.lastCommitAttribution;
    expect(attribution.stateCommitExecuted, 1);
    expect(attribution.effectsOnlyCommitExecuted, 0);
    expect(attribution.criticalValidationRan, 1);
    expect(attribution.criticalValidationFullScene, 0);
    expect(attribution.criticalValidationTrackedNodeCount, 1);
    expect(attribution.debugFullStoreInvariantPassRan, 1);
  });

  test('records effects-only commit attribution on debug seam', () {
    final controller = SceneStoreController(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.writeWithSceneWriter<void>((writer) {
      writer.writeSignalEnqueue(type: 'debug.effects-only');
    });

    final attribution = controller.debug.lastCommitAttribution;
    expect(attribution.stateCommitExecuted, 0);
    expect(attribution.effectsOnlyCommitExecuted, 1);
    expect(attribution.criticalValidationRan, 1);
    expect(attribution.criticalValidationFullScene, 0);
    expect(attribution.criticalValidationTrackedNodeCount, 0);
    expect(attribution.debugFullStoreInvariantPassRan, 1);
  });

  test('records no-op write attribution without validation pass', () {
    final controller = SceneStoreController(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((_) {});

    final attribution = controller.debug.lastCommitAttribution;
    expect(attribution.stateCommitExecuted, 0);
    expect(attribution.effectsOnlyCommitExecuted, 1);
    expect(attribution.criticalValidationRan, 0);
    expect(attribution.criticalValidationFullScene, 0);
    expect(attribution.criticalValidationTrackedNodeCount, 0);
    expect(attribution.debugFullStoreInvariantPassRan, 0);
  });

  test('commit attribution uses the invariant owner pass as stats source', () {
    final source = File(
      'lib/src/controller/scene_controller_commit_execution.dart',
    ).readAsStringSync();
    final invariantCall = source.indexOf('assertCriticalTxnStoreInvariants(');
    final describeCall = source.indexOf(
      'txnDescribeCriticalRuntimeValidationScope(',
    );
    final fullStoreMarker = source.indexOf(
      'debugState.recordDebugFullStoreInvariantPass();',
    );
    final fullStoreAssert = source.indexOf('debugAssertTxnStoreInvariants(');
    final debugAssertClosureStart = source.indexOf('assert(() {');
    final debugAssertClosureEnd = source.indexOf(
      '  }());',
      debugAssertClosureStart,
    );
    final debugAssertClosure = source.substring(
      debugAssertClosureStart,
      debugAssertClosureEnd,
    );

    expect(invariantCall, isNonNegative);
    expect(describeCall, -1);
    expect(fullStoreMarker, isNonNegative);
    expect(
      debugAssertClosure,
      isNot(contains('recordDebugFullStoreInvariantPass')),
    );
    expect(fullStoreMarker, lessThan(fullStoreAssert));
  });
}
