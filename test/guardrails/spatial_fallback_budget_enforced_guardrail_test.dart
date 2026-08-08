import 'package:test/test.dart';

import '../../tool/guardrails/src/geometry_spatial_guardrail_checks.dart';
import '../../tool/guardrails/src/guardrail_violation.dart';

void main() {
  test('spatial fallback budget guardrail rejects bypass shapes', () {
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
    _expectInvalidIndexFallbackRequiresCounter();
    _expectFullMaterializationBeforeBudgetViolatesTileIndex();
    _expectDirectCandidateAssignmentViolatesTileIndex();
    _expectDirectCandidateMutationViolatesTileIndex();
    _expectUncheckedCandidateBudgetResultViolatesTileIndex();
  });
}

void _expectInvalidIndexFallbackRequiresCounter() {
  final violations = checkSpatialFallbackBudgetEnforcedSources(
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

  _expectSingleViolationUnder(violations, 'query_state');
}

void _expectFullMaterializationBeforeBudgetViolatesTileIndex() {
  final violations = checkSpatialFallbackBudgetEnforcedSources(
    tileIndexPath: 'lib/src/geometry/tile_index.dart',
    tileIndexContent: _tileIndexWithFullMaterializationBeforeBudget(),
    queryStatePath: 'lib/src/geometry/spatial_kernel_query_state.dart',
    queryStateContent: _queryStateWithCandidateBudget(),
  );

  _expectSingleViolationUnder(violations, 'tile_index');
}

void _expectDirectCandidateAssignmentViolatesTileIndex() {
  final violations = checkSpatialFallbackBudgetEnforcedSources(
    tileIndexPath: 'lib/src/geometry/tile_index.dart',
    tileIndexContent:
        _tileIndexWithDirectCandidateAssignmentAndReachableHelper(),
    queryStatePath: 'lib/src/geometry/spatial_kernel_query_state.dart',
    queryStateContent: _queryStateWithCandidateBudget(),
  );

  _expectSingleViolationUnder(violations, 'tile_index');
}

void _expectDirectCandidateMutationViolatesTileIndex() {
  final violations = checkSpatialFallbackBudgetEnforcedSources(
    tileIndexPath: 'lib/src/geometry/tile_index.dart',
    tileIndexContent: _tileIndexWithDirectCandidateMutation(),
    queryStatePath: 'lib/src/geometry/spatial_kernel_query_state.dart',
    queryStateContent: _queryStateWithCandidateBudget(),
  );

  _expectSingleViolationUnder(violations, 'tile_index');
}

void _expectUncheckedCandidateBudgetResultViolatesTileIndex() {
  final violations = checkSpatialFallbackBudgetEnforcedSources(
    tileIndexPath: 'lib/src/geometry/tile_index.dart',
    tileIndexContent: _tileIndexWithUncheckedCandidateBudgetResult(),
    queryStatePath: 'lib/src/geometry/spatial_kernel_query_state.dart',
    queryStateContent: _queryStateWithCandidateBudget(),
  );

  _expectSingleViolationUnder(violations, 'tile_index');
}

void _expectSingleViolationUnder(
  Iterable<GuardrailViolation> violations,
  String pathPart,
) {
  expect(
    violations.where((violation) => violation.path.contains(pathPart)),
    hasLength(1),
  );
}

String _tileIndexWithFullMaterializationBeforeBudget() {
  return '''
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
''';
}

String _tileIndexWithDirectCandidateAssignmentAndReachableHelper() {
  return '''
SpatialQueryResult query(window, context) {
  final queryTileCount = spatialTileCountFor(window.boundsWorld);
  if (queryTileCount > kCanvasMaxQueryCells) {
    context.counters.recordQueryTileBudgetExceeded();
    return SpatialBudgetExceededResult(
      reason: SpatialBudgetExceededReason.queryTileBudgetExceeded,
    );
  }
  final candidates = {};
  for (final handle in page.values) {
    candidates[handle.id] = handle;
  }
  final budgetResult = _addUniqueCandidatesWithinBudget(
    candidates,
    context.outlierCandidates,
    context.counters,
  );
  if (budgetResult != null) {
    return budgetResult;
  }
  return spatialCandidateResultWithinBudget(
    candidates.values,
    context.counters,
  );
}

SpatialQueryResult? _addUniqueCandidatesWithinBudget(
  candidates,
  source,
  counters,
) {
  counters.recordFallbackCandidateBudgetExceeded();
  if (candidates.length > kCanvasMaxFallbackCandidates) {
    return SpatialBudgetExceededResult();
  }
  return null;
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
''';
}

String _tileIndexWithDirectCandidateMutation() {
  return '''
SpatialQueryResult query(window, context) {
  final queryTileCount = spatialTileCountFor(window.boundsWorld);
  if (queryTileCount > kCanvasMaxQueryCells) {
    context.counters.recordQueryTileBudgetExceeded();
    return SpatialBudgetExceededResult(
      reason: SpatialBudgetExceededReason.queryTileBudgetExceeded,
    );
  }
  final candidates = {};
  for (final handle in page.values) {
    candidates.putIfAbsent(handle.id, () => handle);
  }
  final budgetResult = _addUniqueCandidatesWithinBudget(
    candidates,
    context.outlierCandidates,
    context.counters,
  );
  if (budgetResult != null) {
    return budgetResult;
  }
  return spatialCandidateResultWithinBudget(
    candidates.values,
    context.counters,
  );
}

SpatialQueryResult? _addUniqueCandidatesWithinBudget(
  candidates,
  source,
  counters,
) {
  counters.recordFallbackCandidateBudgetExceeded();
  if (candidates.length > kCanvasMaxFallbackCandidates) {
    return SpatialBudgetExceededResult();
  }
  return null;
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
''';
}

String _tileIndexWithUncheckedCandidateBudgetResult() {
  return '''
SpatialQueryResult query(window, context) {
  final queryTileCount = spatialTileCountFor(window.boundsWorld);
  if (queryTileCount > kCanvasMaxQueryCells) {
    context.counters.recordQueryTileBudgetExceeded();
    return SpatialBudgetExceededResult(
      reason: SpatialBudgetExceededReason.queryTileBudgetExceeded,
    );
  }
  final candidates = {};
  final budgetResult = _addUniqueCandidatesWithinBudget(
    candidates,
    page.values,
    context.counters,
  );
  return spatialCandidateResultWithinBudget(
    candidates.values,
    context.counters,
  );
}

SpatialQueryResult? _addUniqueCandidatesWithinBudget(
  candidates,
  source,
  counters,
) {
  counters.recordFallbackCandidateBudgetExceeded();
  if (candidates.length > kCanvasMaxFallbackCandidates) {
    return SpatialBudgetExceededResult();
  }
  return null;
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
''';
}

String _queryStateWithCandidateBudget() {
  return '''
SpatialQueryResult runQuery(context) {
  if (context.indexedEntryCount > kCanvasMaxFallbackCandidates) {
    counters.recordFallbackCandidateBudgetExceeded();
    return SpatialBudgetExceededResult();
  }
  return SpatialInvalidIndexResult();
}
''';
}
