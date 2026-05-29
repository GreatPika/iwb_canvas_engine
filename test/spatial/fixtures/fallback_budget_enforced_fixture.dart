import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_ids.dart';
import 'package:iwb_canvas_engine/src/geometry/geometry_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_budget_counters.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_membership.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_port.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_result.dart';
import 'package:iwb_canvas_engine/src/geometry/tile_index.dart';

void main() {
  _testTileBudgetResult();
  _testFallbackCandidateBudget();
  _testOrdinaryTileQueryDoesNotUseFallback();
}

void _testTileBudgetResult() {
  test('query tile budget returns no partial candidates', () {
    final counters = SpatialBudgetCounters();
    final fallback = _CountingHandles(1);
    final result = TileIndex().query(
      _overBudgetWindow(),
      TileQueryContext(counters: counters, fallbackCandidates: fallback),
    );

    expect(result, isA<SpatialBudgetExceededResult>());
    final budget = result as SpatialBudgetExceededResult;
    expect(budget.reason, SpatialBudgetExceededReason.queryTileBudgetExceeded);
    expect(budget.budget, kCanvasMaxQueryCells);
    expect(budget.observed, greaterThan(kCanvasMaxQueryCells));
    expect(budget.candidates, isEmpty);
    expect(counters.queryTileBudgetExceededCount, 1);
    expect(counters.fallbackCandidateBudgetExceededCount, 0);
    expect(fallback.visited, 0);
  });
}

void _testFallbackCandidateBudget() {
  test('fallback candidate budget returns no partial candidates', () {
    final counters = SpatialBudgetCounters();
    final fallback = _CountingHandles(kCanvasMaxFallbackCandidates + 10);
    final result = TileIndex().query(
      _ordinaryWindow(),
      TileQueryContext(counters: counters, outlierCandidates: fallback),
    );

    expect(result, isA<SpatialBudgetExceededResult>());
    final budget = result as SpatialBudgetExceededResult;
    expect(
      budget.reason,
      SpatialBudgetExceededReason.fallbackCandidateBudgetExceeded,
    );
    expect(budget.candidates, isEmpty);
    expect(counters.queryTileBudgetExceededCount, 0);
    expect(counters.fallbackCandidateBudgetExceededCount, 1);
    expect(fallback.visited, fallback.count);
  });
}

void _testOrdinaryTileQueryDoesNotUseFallback() {
  test(
    'ordinary tile query unions tiles and outliers without fallback scan',
    () {
      final tiles = TileIndex();
      final membership = SpatialMembership.fromBounds(
        handle: _handle('tile-a', 2),
        boundsWorld: const Rect.fromLTRB(0, 0, 100, 100),
        indexKind: SpatialIndexKind.hit,
      );
      tiles.put(membership);
      final result = tiles.query(
        const SpatialQueryWindow(
          boundsWorld: Rect.fromLTRB(0, 0, 100, 100),
          structuralRevision: 1,
        ),
        TileQueryContext(
          counters: SpatialBudgetCounters(),
          outlierCandidates: [_handle('outlier-a', 1)],
          fallbackCandidates: _ThrowingHandles(),
        ),
      );

      expect(result.candidates.map((handle) => handle.id), [
        CanvasElementId('tile-a'),
        CanvasElementId('outlier-a'),
      ]);
    },
  );
}

SpatialQueryWindow _overBudgetWindow() {
  return const SpatialQueryWindow(
    boundsWorld: Rect.fromLTWH(
      0,
      0,
      kCanvasSpatialCellSize * 225,
      kCanvasSpatialCellSize * 225,
    ),
    structuralRevision: 1,
  );
}

SpatialQueryWindow _ordinaryWindow() {
  return const SpatialQueryWindow(
    boundsWorld: Rect.fromLTRB(0, 0, 100, 100),
    structuralRevision: 1,
  );
}

FrameElementHandle _handle(String id, int orderToken) {
  return FrameElementHandle(
    id: CanvasElementId(id),
    structuralRevision: 1,
    generation: 0,
    orderToken: orderToken,
  );
}

final class _CountingHandles extends Iterable<FrameElementHandle> {
  _CountingHandles(this.count);

  final int count;
  int visited = 0;

  @override
  Iterator<FrameElementHandle> get iterator => _handles().iterator;

  Iterable<FrameElementHandle> _handles() sync* {
    for (var index = 0; index < count; index += 1) {
      visited += 1;
      yield _handle('fallback-$index', index);
    }
  }
}

final class _ThrowingHandles extends Iterable<FrameElementHandle> {
  @override
  Iterator<FrameElementHandle> get iterator {
    throw StateError('fallback candidates should not be read');
  }
}
