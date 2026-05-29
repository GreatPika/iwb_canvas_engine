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
    },
  );
}
