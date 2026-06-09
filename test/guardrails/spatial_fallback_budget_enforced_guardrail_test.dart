import 'package:test/test.dart';

import '../../tool/guardrails/src/geometry_spatial_guardrail_checks.dart';
import '../../tool/guardrails/src/guardrail_executor.dart';
import '../../tool/guardrails/src/guardrail_registry.dart';

void main() {
  test(
    'spatial fallback budget guardrail is registered and enforced',
    () async {
      expect(guardrailInventory(), contains(spatialFallbackBudgetGuardrailId));
      expect(guardrailRouteFor(spatialFallbackBudgetGuardrailId), isNotNull);
      expect(await checkSpatialFallbackBudgetEnforced(), isEmpty);

      final violations = checkSpatialFallbackBudgetEnforcedSources(
        tileIndexPath: 'lib/src/geometry/tile_index.dart',
        tileIndexContent:
            'return SpatialCandidatesResult(orderedCandidates: candidates);',
        queryStatePath: 'lib/src/geometry/spatial_kernel_query_state.dart',
        queryStateContent: 'return SpatialInvalidIndexResult(reason: reason);',
      );
      expect(violations, hasLength(2));
      expect(
        violations.map((violation) => violation.guardrailId),
        everyElement(spatialFallbackBudgetGuardrailId),
      );

      final invalidFallbackWithoutCounter =
          checkSpatialFallbackBudgetEnforcedSources(
            tileIndexPath: 'lib/src/geometry/tile_index.dart',
            tileIndexContent: '''
if (candidates.length > kCanvasMaxFallbackCandidates) {
  return SpatialBudgetExceededResult();
}
recordFallbackCandidateBudgetExceeded();
''',
            queryStatePath: 'lib/src/geometry/spatial_kernel_query_state.dart',
            queryStateContent: '''
if (context.indexedEntryCount > kCanvasMaxFallbackCandidates) {
  return SpatialBudgetExceededResult();
}
''',
          );
      expect(
        invalidFallbackWithoutCounter.where(
          (violation) => violation.path.contains('query_state'),
        ),
        hasLength(1),
      );

      final fullMaterializationBeforeBudget =
          checkSpatialFallbackBudgetEnforcedSources(
            tileIndexPath: 'lib/src/geometry/tile_index.dart',
            tileIndexContent: '''
SpatialQueryResult query(window, context) {
  final queryTileCount = spatialTileCountFor(window.boundsWorld);
  if (queryTileCount > kCanvasMaxQueryCells) {
    context.counters.recordQueryTileBudgetExceeded();
    return SpatialBudgetExceededResult(
      reason: SpatialBudgetExceededReason.queryTileBudgetExceeded,
    );
  }
  final candidates = {};
  candidates.addAll(page);
  return spatialCandidateResultWithinBudget(
    candidates.values,
    context.counters,
  );
}

SpatialQueryResult spatialCandidateResultWithinBudget(source, counters) {
  final candidates = [];
  for (final handle in source) {
    candidates.add(handle);
    if (candidates.length > kCanvasMaxFallbackCandidates) {
      counters.recordFallbackCandidateBudgetExceeded();
      return SpatialBudgetExceededResult();
    }
  }
  return SpatialCandidatesResult(orderedCandidates: candidates);
}
''',
            queryStatePath: 'lib/src/geometry/spatial_kernel_query_state.dart',
            queryStateContent: '''
SpatialQueryResult runQuery(context) {
  if (context.indexedEntryCount > kCanvasMaxFallbackCandidates) {
    counters.recordFallbackCandidateBudgetExceeded();
    return SpatialBudgetExceededResult();
  }
  return SpatialInvalidIndexResult();
}
''',
          );
      expect(
        fullMaterializationBeforeBudget.where(
          (violation) => violation.path.contains('tile_index'),
        ),
        hasLength(1),
      );
    },
  );
}
