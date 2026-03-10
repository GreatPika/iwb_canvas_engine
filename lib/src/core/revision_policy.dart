import '../contract/validated/validated_value_support.dart';

const int kMaxInstanceRevision = validatedSafeIntegerMax;
const int kMaxControllerEpoch = validatedSafeIntegerMax;

class RevisionAllocatorState {
  RevisionAllocatorState({
    required int nextInstanceRevision,
    this.epochBumpRequested = false,
  }) : nextInstanceRevision = _requireRevisionCounter(
         nextInstanceRevision,
         name: 'nextInstanceRevision',
       );

  int nextInstanceRevision;
  bool epochBumpRequested;

  RevisionAllocatorState copy() => RevisionAllocatorState(
    nextInstanceRevision: nextInstanceRevision,
    epochBumpRequested: epochBumpRequested,
  );
}

RevisionAllocatorState createInitialRevisionAllocatorState({
  int nextInstanceRevision = 1,
}) {
  return RevisionAllocatorState(nextInstanceRevision: nextInstanceRevision);
}

int allocateNextInstanceRevision(RevisionAllocatorState state) {
  final out = state.nextInstanceRevision;
  if (out < kMaxInstanceRevision) {
    state.nextInstanceRevision = out + 1;
    return out;
  }
  state.nextInstanceRevision = 1;
  state.epochBumpRequested = true;
  return out;
}

int resolveImportedInstanceRevision(
  int instanceRevision, {
  required int Function() allocateNextInstanceRevision,
}) {
  if (instanceRevision > 0) {
    return instanceRevision;
  }
  return allocateNextInstanceRevision();
}

int resolveNextControllerEpoch({
  required int currentEpoch,
  required bool documentReplaced,
  required RevisionAllocatorState revisionState,
}) {
  _requireControllerEpoch(currentEpoch, name: 'currentEpoch');
  final needsEpochBump = documentReplaced || revisionState.epochBumpRequested;
  if (!needsEpochBump) {
    return currentEpoch;
  }
  if (currentEpoch == kMaxControllerEpoch) {
    throw StateError(
      'Controller epoch overflow: composite revision identity is exhausted.',
    );
  }
  return currentEpoch + 1;
}

RevisionAllocatorState resolvedCommittedRevisionAllocatorState(
  RevisionAllocatorState state,
) {
  return RevisionAllocatorState(
    nextInstanceRevision: state.nextInstanceRevision,
    epochBumpRequested: false,
  );
}

int Function() createLocalRevisionAllocator({int startRevision = 1}) {
  final state = createInitialRevisionAllocatorState(
    nextInstanceRevision: startRevision,
  );
  return () => allocateNextInstanceRevision(state);
}

int requireControllerEpoch(int value, {String name = 'controllerEpoch'}) {
  return _requireControllerEpoch(value, name: name);
}

int requireRevisionCounter(int value, {String name = 'nextInstanceRevision'}) {
  return _requireRevisionCounter(value, name: name);
}

int _requireControllerEpoch(int value, {required String name}) {
  if (value < 0 || value > kMaxControllerEpoch) {
    throw ArgumentError.value(
      value,
      name,
      'Must be within [0, $kMaxControllerEpoch].',
    );
  }
  return value;
}

int _requireRevisionCounter(int value, {required String name}) {
  if (value < 1 || value > kMaxInstanceRevision) {
    throw ArgumentError.value(
      value,
      name,
      'Must be within [1, $kMaxInstanceRevision].',
    );
  }
  return value;
}
