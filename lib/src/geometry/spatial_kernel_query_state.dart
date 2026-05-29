import 'spatial_budget_counters.dart';
import 'spatial_query_port.dart';
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

  void markFailedUpdate() {
    isInvalid = true;
    invalidReason = SpatialInvalidIndexReason.failedUpdate;
  }

  SpatialQueryResult runQuery(SpatialKernelQueryContext context) {
    if (isInvalid) {
      counters.recordInvalidIndexProbe();
      if (context.indexedEntryCount > kCanvasMaxFallbackCandidates) {
        counters.recordFallbackCandidateBudgetExceeded();

        return SpatialBudgetExceededResult(
          reason: SpatialBudgetExceededReason.fallbackCandidateBudgetExceeded,
          budget: kCanvasMaxFallbackCandidates,
          observed: context.indexedEntryCount,
        );
      }

      return SpatialInvalidIndexResult(reason: invalidReason);
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

final class SpatialKernelQueryContext {
  const SpatialKernelQueryContext({
    required this.window,
    required this.indexedEntryCount,
    required this.candidateMapper,
    required this.query,
  });

  final SpatialQueryWindow window;
  final int indexedEntryCount;
  final CandidateHandleMapper candidateMapper;
  final SpatialIndexQuery query;
}
