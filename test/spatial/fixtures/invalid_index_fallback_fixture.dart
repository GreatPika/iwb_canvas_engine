import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/touched_set.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_kernel.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_result.dart';

import 'spatial_kernel_test_support.dart';

void main() {
  _testFailedUpdatePreservesEntries();
  _testMissingTouchedHandleRejected();
  _testInvalidIndexBudgetExceeded();
}

void _testFailedUpdatePreservesEntries() {
  test(
    'failed staged update preserves entries and returns typed invalid results',
    () {
      final kernel = SpatialKernel();
      kernel.rebuild(
        SpatialFrameFactsPortFixture([
          spatialRect('a', order: 1),
          spatialRect('b', order: 2),
        ]),
      );
      final before = kernel.snapshot;
      final corrupt = SpatialFrameFactsPortFixture([
        spatialRect('a', order: 1, generation: 1),
        spatialRect('b', order: 2),
      ]);

      kernel.applyTouched(
        corrupt,
        TouchedSet(updatedElementIds: [CanvasElementId('a')]),
      );

      expect(kernel.snapshot.entryCount, before.entryCount);
      final fallback = kernel.queryPaint(spatialWindowNearOrigin(0));
      expect(fallback, isA<SpatialCandidatesResult>());
      expect(spatialCandidateIds(fallback), [
        CanvasElementId('b'),
        CanvasElementId('a'),
      ]);
      expect(kernel.budgetCounters.invalidIndexProbeCount, 1);
    },
  );
}

void _testMissingTouchedHandleRejected() {
  test('missing non-removed touched handle keeps index invalid', () {
    final kernel = SpatialKernel();
    kernel.rebuild(
      SpatialFrameFactsPortFixture([
        spatialRect('a', order: 1),
        spatialRect('b', order: 2),
      ]),
    );

    kernel.applyTouched(
      SpatialFrameFactsPortFixture([spatialRect('b', order: 2)]),
      TouchedSet(updatedElementIds: [CanvasElementId('a')]),
    );

    expect(kernel.snapshot.entryCount, 2);
    expect(kernel.snapshot.isInvalid, isTrue);
    final fallback = kernel.queryHit(spatialWindowNearOrigin(0));
    expect(fallback, isA<SpatialCandidatesResult>());
    expect(spatialCandidateIds(fallback), [CanvasElementId('b')]);
  });
}

void _testInvalidIndexBudgetExceeded() {
  test('invalid index over fallback budget returns no partial candidates', () {
    final kernel = SpatialKernel();
    kernel.rebuild(
      SpatialFrameFactsPortFixture(
        manySpatialRects(kCanvasMaxFallbackCandidates + 1),
      ),
    );
    final corrupt = SpatialFrameFactsPortFixture([
      spatialRect('e0', order: 0, generation: 1),
    ]);
    kernel.applyTouched(
      corrupt,
      TouchedSet(updatedElementIds: [CanvasElementId('e0')]),
    );

    final result = kernel.queryHit(spatialWindowNearOrigin(0));
    expect(result, isA<SpatialBudgetExceededResult>());
    expect(kernel.budgetCounters.fallbackCandidateBudgetExceededCount, 1);
  });
}
