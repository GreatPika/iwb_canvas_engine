import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/revision_policy.dart';

void main() {
  test('allocateNextInstanceRevision rolls over through epoch request', () {
    final state = createInitialRevisionAllocatorState(
      nextInstanceRevision: kMaxInstanceRevision,
    );

    final allocated = allocateNextInstanceRevision(state);

    expect(allocated, kMaxInstanceRevision);
    expect(state.nextInstanceRevision, 1);
    expect(state.epochBumpRequested, isTrue);
  });

  test('resolveNextControllerEpoch bumps on pending rollover request', () {
    final state = createInitialRevisionAllocatorState();
    state.epochBumpRequested = true;

    final nextEpoch = resolveNextControllerEpoch(
      currentEpoch: 7,
      documentReplaced: false,
      revisionState: state,
    );

    expect(nextEpoch, 8);
  });

  test(
    'resolveNextControllerEpoch keeps epoch stable without bump triggers',
    () {
      final state = createInitialRevisionAllocatorState();

      final nextEpoch = resolveNextControllerEpoch(
        currentEpoch: 7,
        documentReplaced: false,
        revisionState: state,
      );

      expect(nextEpoch, 7);
    },
  );

  test('resolveNextControllerEpoch fails fast on epoch overflow', () {
    final state = createInitialRevisionAllocatorState();
    state.epochBumpRequested = true;

    expect(
      () => resolveNextControllerEpoch(
        currentEpoch: kMaxControllerEpoch,
        documentReplaced: false,
        revisionState: state,
      ),
      throwsStateError,
    );
  });

  test('resolveNextControllerEpoch rejects invalid current epoch input', () {
    expect(
      () => resolveNextControllerEpoch(
        currentEpoch: kMaxControllerEpoch + 1,
        documentReplaced: false,
        revisionState: createInitialRevisionAllocatorState(),
      ),
      throwsArgumentError,
    );
  });

  test('resolveImportedInstanceRevision preserves valid existing revision', () {
    expect(
      resolveImportedInstanceRevision(9, allocateNextInstanceRevision: () => 1),
      9,
    );
  });

  test(
    'resolveImportedInstanceRevision allocates for non-positive revision',
    () {
      expect(
        resolveImportedInstanceRevision(
          0,
          allocateNextInstanceRevision: () => 7,
        ),
        7,
      );
    },
  );

  test('resolveNextControllerEpoch bumps on document replacement', () {
    final nextEpoch = resolveNextControllerEpoch(
      currentEpoch: 3,
      documentReplaced: true,
      revisionState: createInitialRevisionAllocatorState(),
    );

    expect(nextEpoch, 4);
  });

  test('resolvedCommittedRevisionAllocatorState clears pending epoch bump', () {
    final state = createInitialRevisionAllocatorState(nextInstanceRevision: 5)
      ..epochBumpRequested = true;

    final committed = resolvedCommittedRevisionAllocatorState(state);

    expect(committed.nextInstanceRevision, 5);
    expect(committed.epochBumpRequested, isFalse);
  });

  test('createLocalRevisionAllocator increments from the configured start', () {
    final allocate = createLocalRevisionAllocator(startRevision: 4);

    expect(allocate(), 4);
    expect(allocate(), 5);
  });

  test('requireControllerEpoch validates the public wrapper contract', () {
    expect(requireControllerEpoch(2), 2);
    expect(() => requireControllerEpoch(-1), throwsArgumentError);
  });

  test('requireRevisionCounter validates the public wrapper contract', () {
    expect(requireRevisionCounter(2), 2);
    expect(() => requireRevisionCounter(0), throwsArgumentError);
  });
}
