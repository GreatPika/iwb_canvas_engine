import 'package:test/test.dart';

import '../../tool/guardrails/src/geometry_spatial_guardrail_checks.dart';
import '../../tool/guardrails/src/guardrail_executor.dart';
import '../../tool/guardrails/src/guardrail_registry.dart';
import '../../tool/guardrails/src/guardrail_violation.dart';

void main() {
  test(
    'spatial stale candidate guardrail is registered and enforced',
    () async =>
        expect(await _registeredStaleCandidateGuardrailIsEnforced(), isTrue),
  );

  test(
    'stale candidate guardrail rejects early return before generation',
    () => expect(_earlyReturnBeforeGenerationIsRejected(), isTrue),
  );
}

Future<bool> _registeredStaleCandidateGuardrailIsEnforced() async {
  final isRegistered =
      guardrailInventory().containsKey(spatialStaleCandidateGuardrailId) &&
      guardrailRouteFor(spatialStaleCandidateGuardrailId) != null &&
      (await checkSpatialStaleCandidateRejected()).isEmpty;

  final violations = checkSpatialStaleCandidateRejectedSources(
    mapperPath: 'lib/src/geometry/spatial_candidate_handle_mapper.dart',
    mapperContent: 'FrameElementHandle call(FrameElementHandle h) => h;',
    queryStatePath: 'lib/src/geometry/spatial_kernel_query_state.dart',
    queryStateContent: 'return SpatialCandidatesResult(orderedCandidates: c);',
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
    queryStateContent: 'return SpatialStaleCandidateResult();',
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
    queryStateContent: 'return SpatialStaleCandidateResult();',
  );

  return isRegistered &&
      violations.length == 2 &&
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
        queryStateContent: 'return SpatialStaleCandidateResult();',
      );

  return earlyReturnBeforeGenerationCheck.length == 1 &&
      _isStaleCandidateViolation(earlyReturnBeforeGenerationCheck.single);
}

bool _isStaleCandidateViolation(GuardrailViolation violation) {
  return violation.guardrailId == spatialStaleCandidateGuardrailId;
}
