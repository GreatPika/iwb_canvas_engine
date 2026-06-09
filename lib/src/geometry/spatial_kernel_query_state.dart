import '../contracts/internal/frame_facts_port.dart';
import 'geometry_policy.dart';
import 'spatial_budget_counters.dart';
import 'spatial_query_policy.dart';
import 'spatial_query_result.dart';
import 'tile_index.dart';

typedef SpatialIndexQuery =
    SpatialQueryResult Function(
      SpatialQueryWindow window,
      TileQueryContext context,
    );

final class SpatialKernelQueryState {
  final SpatialBudgetCounters counters = SpatialBudgetCounters();
  int structuralRevision = 0;
  bool isInvalid = true;
  SpatialInvalidIndexReason invalidReason =
      SpatialInvalidIndexReason.rebuildNeeded;

  void markValid(int revision) {
    structuralRevision = revision;
    isInvalid = false;
  }

  void markRebuildNeeded(int revision) {
    structuralRevision = revision;
    isInvalid = true;
    invalidReason = SpatialInvalidIndexReason.rebuildNeeded;
  }

  void markFailedUpdate() {
    isInvalid = true;
    invalidReason = SpatialInvalidIndexReason.failedUpdate;
  }

  SpatialQueryResult runQuery(SpatialKernelQueryContext context) {
    if (isInvalid) {
      final queryTileBudgetResult = _queryTileBudgetResult(context, counters);
      if (queryTileBudgetResult != null) {
        return queryTileBudgetResult;
      }
      counters.recordInvalidIndexProbe();
      if (context.indexedEntryCount > kCanvasMaxFallbackCandidates) {
        counters.recordFallbackCandidateBudgetExceeded();

        return SpatialBudgetExceededResult(
          reason: SpatialBudgetExceededReason.fallbackCandidateBudgetExceeded,
          budget: kCanvasMaxFallbackCandidates,
          observed: context.indexedEntryCount,
        );
      }

      return _invalidFallbackResult(context, invalidReason);
    }
    if (context.window.structuralRevision != structuralRevision) {
      return SpatialStaleCandidateResult(
        expectedStructuralRevision: structuralRevision,
        observedStructuralRevision: context.window.structuralRevision,
      );
    }

    try {
      return context.query(
        context.window,
        TileQueryContext(
          counters: counters,
          candidateMapper: context.candidateMapper,
        ),
      );
    } on Object {
      counters.recordInvalidIndexProbe();

      return const SpatialInvalidIndexResult(
        reason: SpatialInvalidIndexReason.failedUpdate,
      );
    }
  }
}

SpatialQueryResult? _queryTileBudgetResult(
  SpatialKernelQueryContext context,
  SpatialBudgetCounters counters,
) {
  final queryTileCount = spatialTileCountFor(context.window.boundsWorld);
  if (queryTileCount <= kCanvasMaxQueryCells) {
    return null;
  }
  counters.recordQueryTileBudgetExceeded();

  return SpatialBudgetExceededResult(
    reason: SpatialBudgetExceededReason.queryTileBudgetExceeded,
    budget: kCanvasMaxQueryCells,
    observed: queryTileCount,
  );
}

SpatialQueryResult _invalidFallbackResult(
  SpatialKernelQueryContext context,
  SpatialInvalidIndexReason invalidReason,
) {
  final candidates = <FrameElementHandle>[];
  for (final handle in context.fallbackCandidates) {
    try {
      candidates.add(context.candidateMapper(handle));
    } on Object {
      continue;
    }
  }
  if (candidates.isEmpty) {
    return SpatialInvalidIndexResult(reason: invalidReason);
  }
  candidates.sort((left, right) => right.orderToken.compareTo(left.orderToken));

  return SpatialCandidatesResult(
    orderedCandidates: List.unmodifiable(candidates),
  );
}

final class SpatialKernelQueryContext {
  const SpatialKernelQueryContext({
    required this.window,
    required this.indexedEntryCount,
    required this.fallbackCandidates,
    required this.candidateMapper,
    required this.query,
  });

  final SpatialQueryWindow window;
  final int indexedEntryCount;
  final Iterable<FrameElementHandle> fallbackCandidates;
  final CandidateHandleMapper candidateMapper;
  final SpatialIndexQuery query;
}
