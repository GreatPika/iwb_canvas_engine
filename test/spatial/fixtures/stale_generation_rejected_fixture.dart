import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/touched_set.dart';
import 'package:iwb_canvas_engine/src/geometry/geometry_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_kernel.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_result.dart';

import 'spatial_kernel_test_support.dart';

void main() {
  test('stale structural revision and handle facts are rejected', () {
    final kernel = SpatialKernel();
    kernel.rebuild(SpatialFrameFactsPortFixture([spatialRect('a', order: 1)]));

    final stale = kernel.queryHit(spatialWindowNearOrigin(99));
    expect(stale, isA<SpatialStaleCandidateResult>());
    final staleOverBudget = kernel.queryHit(_overBudgetWindow(99));
    expect(staleOverBudget, isA<SpatialStaleCandidateResult>());
    expect(kernel.budgetCounters.queryTileBudgetExceededCount, 0);

    final corrupt = SpatialFrameFactsPortFixture([
      spatialRect('a', order: 1, generation: 1),
    ]);
    kernel.applyTouched(
      corrupt,
      TouchedSet(updatedElementIds: [CanvasElementId('a')]),
    );

    expect(kernel.snapshot.isInvalid, isTrue);
    expect(
      kernel.queryHit(spatialWindowNearOrigin(0)),
      isA<SpatialCandidatesResult>(),
    );

    expectSpatialOrderTokenMismatchRejected();
    expectInvalidSpatialDeltaTriggersRebuild(kernel);
  });
}

SpatialQueryWindow _overBudgetWindow(int structuralRevision) {
  return SpatialQueryWindow(
    boundsWorld: Rect.fromLTWH(
      0,
      0,
      (kCanvasMaxQueryCells + 1) * kCanvasSpatialCellSize.toDouble(),
      kCanvasSpatialCellSize.toDouble(),
    ),
    structuralRevision: structuralRevision,
  );
}
