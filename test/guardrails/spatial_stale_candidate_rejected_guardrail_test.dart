import 'package:test/test.dart';

import '../../tool/guardrails/src/geometry_spatial_guardrail_checks.dart';
import '../../tool/guardrails/src/guardrail_violation.dart';

void main() {
  test(
    'spatial stale candidate guardrail rejects missing checks',
    () => expect(_registeredStaleCandidateGuardrailIsEnforced(), isTrue),
  );

  test(
    'stale candidate guardrail rejects early return before generation',
    () => expect(_earlyReturnBeforeGenerationIsRejected(), isTrue),
  );

  test(
    'stale candidate guardrail rejects ignored mismatch checks',
    () => expect(_ignoredMismatchChecksAreRejected(), isTrue),
  );

  test(
    'stale candidate guardrail rejects structural-stale handle return',
    () => expect(_structuralStaleHandleReturnIsRejected(), isTrue),
  );
}

bool _registeredStaleCandidateGuardrailIsEnforced() {
  final violations = checkSpatialStaleCandidateRejectedSources(
    mapperPath: 'lib/src/geometry/spatial_candidate_handle_mapper.dart',
    mapperContent: 'FrameElementHandle call(FrameElementHandle h) => h;',
    queryStatePath: 'lib/src/geometry/spatial_kernel_query_state.dart',
    queryStateContent:
        'SpatialQueryResult runQuery() => SpatialCandidatesResult(orderedCandidates: c);',
  );

  final missingGenerationCheck = checkSpatialStaleCandidateRejectedSources(
    mapperPath: 'lib/src/geometry/spatial_candidate_handle_mapper.dart',
    mapperContent: '''
FrameElementHandle call(FrameElementHandle handle) {
  if (handle.structuralRevision == _structuralRevision) {
    return handle;
  }

  return frame.elementHandleForId(_structuralRevision, handle.id)!;
}
''',
    queryStatePath: 'lib/src/geometry/spatial_kernel_query_state.dart',
    queryStateContent: _typedStaleQueryState,
  );

  final missingOrderTokenCheck = checkSpatialStaleCandidateRejectedSources(
    mapperPath: 'lib/src/geometry/spatial_candidate_handle_mapper.dart',
    mapperContent: '''
FrameElementHandle call(FrameElementHandle handle) {
  final current = frame.elementHandleForId(_structuralRevision, handle.id)!;
  if (handle.generation != current.generation) {
    throw StateError('stale');
  }
  if (handle.structuralRevision == _structuralRevision) {
    return handle;
  }
}
''',
    queryStatePath: 'lib/src/geometry/spatial_kernel_query_state.dart',
    queryStateContent: _typedStaleQueryState,
  );

  return violations.length == 2 &&
      violations.every(_isStaleCandidateViolation) &&
      missingGenerationCheck.length == 1 &&
      _isStaleCandidateViolation(missingGenerationCheck.single) &&
      missingOrderTokenCheck.length == 1 &&
      _isStaleCandidateViolation(missingOrderTokenCheck.single);
}

bool _earlyReturnBeforeGenerationIsRejected() {
  final earlyReturnBeforeGenerationCheck =
      checkSpatialStaleCandidateRejectedSources(
        mapperPath: 'lib/src/geometry/spatial_candidate_handle_mapper.dart',
        mapperContent: '''
FrameElementHandle call(FrameElementHandle handle) {
  if (handle.structuralRevision == _structuralRevision) {
    return handle;
  }

  final current = frame.elementHandleForId(_structuralRevision, handle.id)!;
  if (handle.generation != current.generation) {
    throw StateError('stale');
  }
}
''',
        queryStatePath: 'lib/src/geometry/spatial_kernel_query_state.dart',
        queryStateContent: _typedStaleQueryState,
      );

  return earlyReturnBeforeGenerationCheck.length == 1 &&
      _isStaleCandidateViolation(earlyReturnBeforeGenerationCheck.single);
}

bool _ignoredMismatchChecksAreRejected() {
  final ignoredMismatchCheck = checkSpatialStaleCandidateRejectedSources(
    mapperPath: 'lib/src/geometry/spatial_candidate_handle_mapper.dart',
    mapperContent: '''
FrameElementHandle call(FrameElementHandle handle) {
  final current = frame.elementHandleForId(_structuralRevision, handle.id)!;
  if (handle.structuralRevision == _structuralRevision) {
    final stale = handle.generation != current.generation ||
        handle.orderToken != current.orderToken;
    return handle;
  }

  return current;
}
''',
    queryStatePath: 'lib/src/geometry/spatial_kernel_query_state.dart',
    queryStateContent: _typedStaleQueryState,
  );

  return ignoredMismatchCheck.length == 1 &&
      _isStaleCandidateViolation(ignoredMismatchCheck.single);
}

bool _structuralStaleHandleReturnIsRejected() {
  final structuralStaleReturnCheck = checkSpatialStaleCandidateRejectedSources(
    mapperPath: 'lib/src/geometry/spatial_candidate_handle_mapper.dart',
    mapperContent: '''
FrameElementHandle call(FrameElementHandle handle) {
  final current = frame.elementHandleForId(_structuralRevision, handle.id)!;
  if (handle.structuralRevision == _structuralRevision) {
    if (handle.generation != current.generation ||
        handle.orderToken != current.orderToken) {
      throw StateError('stale');
    }

    return handle;
  }

  return handle;
}
''',
    queryStatePath: 'lib/src/geometry/spatial_kernel_query_state.dart',
    queryStateContent: _typedStaleQueryState,
  );

  return structuralStaleReturnCheck.length == 1 &&
      _isStaleCandidateViolation(structuralStaleReturnCheck.single);
}

const _typedStaleQueryState = '''
SpatialQueryResult runQuery() {
  return SpatialStaleCandidateResult();
}
''';

bool _isStaleCandidateViolation(GuardrailViolation violation) {
  return violation.guardrailId == spatialStaleCandidateGuardrailId;
}
