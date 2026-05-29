import 'dart:collection';

import '../contracts/internal/frame_facts_port.dart';
import '../contracts/public/canvas_ids.dart';
import 'geometry_policy.dart';
import 'spatial_budget_counters.dart';
import 'spatial_membership.dart';
import 'spatial_query_port.dart';
import 'spatial_query_result.dart';

final class TileIndex {
  final Map<SpatialTileCoord, Map<CanvasElementId, FrameElementHandle>> _pages =
      {};

  int get pageCount => _pages.length;

  bool contains(CanvasElementId id) {
    return _pages.values.any((page) => page.containsKey(id));
  }

  void put(SpatialMembership membership) {
    if (membership.isOutlier || membership.tiles.isEmpty) {
      return;
    }
    for (final tile in membership.tiles) {
      final page = _pages.putIfAbsent(tile, LinkedHashMap.new);
      page[membership.id] = membership.handle;
    }
  }

  void remove(SpatialMembership membership) {
    for (final tile in membership.tiles) {
      final page = _pages[tile];
      page?.remove(membership.id);
      if (page != null && page.isEmpty) {
        _pages.remove(tile);
      }
    }
  }

  SpatialQueryResult query(
    SpatialQueryWindow window, {
    required SpatialBudgetCounters counters,
    Iterable<FrameElementHandle> outlierCandidates = const [],
    Iterable<FrameElementHandle> fallbackCandidates = const [],
  }) {
    final queryTileCount = spatialTileCountFor(window.boundsWorld);
    if (queryTileCount > kCanvasMaxQueryCells) {
      counters.recordQueryTileBudgetExceeded();

      return _candidateResultWithinBudget(
        fallbackCandidates,
        counters,
        budgetReason:
            SpatialBudgetExceededReason.fallbackCandidateBudgetExceeded,
      );
    }
    final candidates = <CanvasElementId, FrameElementHandle>{};
    for (final tile in spatialTilesFor(window.boundsWorld)) {
      candidates.addAll(_pages[tile] ?? const {});
    }
    for (final handle in outlierCandidates) {
      candidates[handle.id] = handle;
    }

    return _candidateResultWithinBudget(
      candidates.values,
      counters,
      budgetReason: SpatialBudgetExceededReason.fallbackCandidateBudgetExceeded,
    );
  }
}

SpatialQueryResult _candidateResultWithinBudget(
  Iterable<FrameElementHandle> source,
  SpatialBudgetCounters counters, {
  required SpatialBudgetExceededReason budgetReason,
}) {
  final candidates = <FrameElementHandle>[];
  for (final handle in source) {
    candidates.add(handle);
    if (candidates.length > kCanvasMaxFallbackCandidates) {
      counters.recordFallbackCandidateBudgetExceeded();

      return SpatialBudgetExceededResult(
        reason: budgetReason,
        budget: kCanvasMaxFallbackCandidates,
        observed: candidates.length,
      );
    }
  }
  candidates.sort((left, right) => right.orderToken.compareTo(left.orderToken));

  return SpatialCandidatesResult(
    orderedCandidates: List.unmodifiable(candidates),
  );
}
