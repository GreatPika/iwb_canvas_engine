import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/touched_set.dart';
import 'package:iwb_canvas_engine/src/geometry/geometry_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_budget_counters.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_kernel.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_result.dart';

import 'spatial_kernel_test_support.dart';

void main() {
  _testFailedUpdatePreservesEntries();
  _testMissingTouchedHandleRejected();
  _testInvalidIndexBudgetExceeded();
  _testInvalidIndexQueryTileBudgetExceeded();
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

void _testInvalidIndexQueryTileBudgetExceeded() {
  // Assertions live in the focused helper so the over-budget window setup stays
  // readable at the regression site.
  // ignore: missing-test-assertion
  test(
    'invalid index over query tile budget returns no fallback candidates',
    () {
      final kernel = SpatialKernel();
      kernel.rebuild(
        SpatialFrameFactsPortFixture([spatialRect('e0', order: 0)]),
      );
      final corrupt = SpatialFrameFactsPortFixture([
        spatialRect('e0', order: 0, generation: 1),
      ]);
      kernel.applyTouched(
        corrupt,
        TouchedSet(updatedElementIds: [CanvasElementId('e0')]),
      );

      _expectInvalidIndexQueryTileBudgetExceeded(
        kernel.queryHit(_overBudgetWindow(kernel)),
        kernel.budgetCounters,
      );
    },
  );
}

SpatialQueryWindow _overBudgetWindow(SpatialKernel kernel) {
  return SpatialQueryWindow(
    boundsWorld: Rect.fromLTWH(
      0,
      0,
      (kCanvasMaxQueryCells + 1) * kCanvasSpatialCellSize.toDouble(),
      kCanvasSpatialCellSize.toDouble(),
    ),
    structuralRevision: kernel.snapshot.structuralRevision,
  );
}

void _expectInvalidIndexQueryTileBudgetExceeded(
  SpatialQueryResult result,
  SpatialBudgetCounters counters,
) {
  expect(result, isA<SpatialBudgetExceededResult>());
  final budget = result as SpatialBudgetExceededResult;
  expect(budget.reason, SpatialBudgetExceededReason.queryTileBudgetExceeded);
  expect(budget.budget, kCanvasMaxQueryCells);
  expect(budget.observed, greaterThan(kCanvasMaxQueryCells));
  expect(counters.queryTileBudgetExceededCount, 1);
  expect(counters.fallbackCandidateBudgetExceededCount, 0);
  expect(counters.invalidIndexProbeCount, 0);
}
