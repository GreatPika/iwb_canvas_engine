import 'package:test/test.dart';

import '../../tool/guardrails/src/geometry_spatial_guardrail_checks.dart';
import '../../tool/guardrails/src/guardrail_executor.dart';
import '../../tool/guardrails/src/guardrail_registry.dart';

void main() {
  test(
    'spatial ordinary update full-clone guardrail is registered and enforced',
    () async => expect(await _spatialKernelGuardrailIsEnforced(), isTrue),
  );

  test(
    'touched additions guardrail allows rebuild enumeration only',
    () => expect(_touchedAdditionsGuardrailIsEnforced(), isTrue),
  );
}

Future<bool> _spatialKernelGuardrailIsEnforced() async {
  final isRegistered =
      guardrailInventory().containsKey(spatialNoFullCloneGuardrailId) &&
      guardrailRouteFor(spatialNoFullCloneGuardrailId) != null &&
      (await checkSpatialNoFullCloneOrdinaryEdit()).isEmpty;

  return isRegistered &&
      _hasSpatialKernelViolation('''
void _applyPreparedTouchedDelta(frame, touchedSet, revision) {
  frame.elementHandles(frame.frameRevisions.structuralRevision);
}
''') &&
      _hasSpatialKernelViolation('''
void _applyPreparedTouchedDelta(frame, touchedSet, revision) => _clone(frame);

void _clone(frame) {
  spatialEntriesForFrame(frame: frame, geometryPolicy: policy);
}
''') &&
      _hasSpatialKernelViolation('''
final class SpatialKernel {
  void _applyPreparedTouchedDelta(frame, touchedSet, revision) {
    frame.elementHandles(frame.frameRevisions.structuralRevision);
  }
}
''') &&
      _hasSpatialKernelViolation('''
void _applyPreparedTouchedDelta(frame, touchedSet, revision) {
  final allHandles = frame.elementHandles;
  allHandles(frame.frameRevisions.structuralRevision);
}
''');
}

bool _touchedAdditionsGuardrailIsEnforced() {
  final rebuildAllowed = checkSpatialTouchedAdditionsSource(
    path: 'lib/src/geometry/spatial_entry_loader.dart',
    content: '''
void spatialEntriesForFrame(frame) {
  frame.elementHandles(frame.frameRevisions.structuralRevision);
}

void spatialAdditionsForTouches(frame, touchedSet) {
  frame.elementHandleForId(frame.frameRevisions.structuralRevision, id);
}
''',
  );

  final touchedAdditionsFullEnumeration = checkSpatialTouchedAdditionsSource(
    path: 'lib/src/geometry/spatial_entry_loader.dart',
    content: '''
void spatialAdditionsForTouches(frame, touchedSet) {
  frame.elementHandles(frame.frameRevisions.structuralRevision);
}
''',
  );

  final helperFullEnumeration = checkSpatialTouchedAdditionsSource(
    path: 'lib/src/geometry/spatial_entry_loader.dart',
    content: '''
void spatialAdditionsForTouches(frame, touchedSet) {
  _cloneTouched(frame);
}

void _cloneTouched(frame) {
  frame.elementHandles(frame.frameRevisions.structuralRevision);
}
''',
  );

  final touchedAdditionsFullEnumerationTearOff =
      checkSpatialTouchedAdditionsSource(
        path: 'lib/src/geometry/spatial_entry_loader.dart',
        content: '''
void spatialAdditionsForTouches(frame, touchedSet) {
  final allHandles = frame.elementHandles;
  allHandles(frame.frameRevisions.structuralRevision);
}
''',
      );

  final chainedHelperFullEnumeration = checkSpatialTouchedAdditionsSource(
    path: 'lib/src/geometry/spatial_entry_loader.dart',
    content: '''
void spatialAdditionsForTouches(frame, touchedSet) {
  _prepare(frame);
}

void _prepare(frame) {
  _cloneTouched(frame);
}

void _cloneTouched(frame) {
  frame.elementHandles(frame.frameRevisions.structuralRevision);
}
''',
  );

  final touchedAdditionsFullEntryHelper = checkSpatialTouchedAdditionsSource(
    path: 'lib/src/geometry/spatial_entry_loader.dart',
    content: '''
void spatialAdditionsForTouches(frame, touchedSet) {
  _fullEntries(frame);
}

void _fullEntries(frame) {
  spatialEntriesForFrame(frame: frame, geometryPolicy: policy);
}
''',
  );

  return rebuildAllowed.isEmpty &&
      touchedAdditionsFullEnumeration.length == 1 &&
      touchedAdditionsFullEnumeration.single.path ==
          'lib/src/geometry/spatial_entry_loader.dart' &&
      helperFullEnumeration.length == 1 &&
      touchedAdditionsFullEnumerationTearOff.length == 1 &&
      chainedHelperFullEnumeration.length == 1 &&
      touchedAdditionsFullEntryHelper.length == 1;
}

bool _hasSpatialKernelViolation(String content) {
  final violations = checkSpatialNoFullCloneOrdinaryEditSource(
    path: 'lib/src/geometry/spatial_kernel.dart',
    content: content,
  );

  return violations.length == 1 &&
      violations.single.guardrailId == spatialNoFullCloneGuardrailId;
}
