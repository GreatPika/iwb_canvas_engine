import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/touched_set.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_kernel.dart';

import 'spatial_kernel_test_support.dart';

void main() {
  _testOrdinaryTouchedUpdate();
  _testReplacementRebuild();
  _testClearResetCancelsPendingReplacementRebuild();
  _testStructuralElementChangesTouchedUpdate();
  _testUpdateThenRemove();
  _testStructuralRevisionRebase();
  _testEmptyLayerStructuralRevisionRebase();
}

void _testOrdinaryTouchedUpdate() {
  test('ordinary updates touch only changed ids and keep other candidates', () {
    final kernel = SpatialKernel();
    kernel.rebuild(
      SpatialFrameFactsPortFixture([
        spatialRect('a', order: 1),
        spatialRect('b', order: 2),
      ]),
    );
    final updated = SpatialFrameFactsPortFixture([
      spatialRect('a', order: 1, translation: const Offset(1000, 0)),
      spatialRect('b', order: 2),
    ]);

    kernel.applyTouched(
      updated,
      TouchedSet(transformedElementIds: [CanvasElementId('a')]),
    );

    expect(updated.elementHandlesCalls, 0);
    expect(updated.elementHandleForIdCalls, 1);
    expectMovedSpatialCandidateQueries(kernel);
  });
}

void _testReplacementRebuild() {
  test('document replacement rebuilds lazily on the first spatial query', () {
    final kernel = SpatialKernel();
    kernel.rebuild(
      SpatialFrameFactsPortFixture([spatialRect('old', order: 1)]),
    );
    final loaded = SpatialFrameFactsPortFixture([
      spatialRect('new-a', order: 1),
      spatialRect('new-b', order: 2, translation: const Offset(1000, 0)),
    ], structuralRevision: 1);

    kernel.applyTouched(loaded, TouchedSet(documentReplaced: true));

    expect(kernel.snapshot.isInvalid, isTrue);
    expectReplacementScheduledForLazyRebuild(kernel, loaded);
  });
}

void _testClearResetCancelsPendingReplacementRebuild() {
  test('clear reset cancels pending replacement rebuild', () {
    final kernel = SpatialKernel();
    kernel.rebuild(
      SpatialFrameFactsPortFixture([spatialRect('old', order: 1)]),
    );
    final loaded = SpatialFrameFactsPortFixture([
      spatialRect('loaded', order: 1),
    ], structuralRevision: 1);
    final cleared = SpatialFrameFactsPortFixture(
      const [],
      structuralRevision: 2,
    );

    kernel.applyTouched(loaded, TouchedSet(documentReplaced: true));
    kernel.applyTouched(
      cleared,
      TouchedSet(removedElementIds: [CanvasElementId('loaded')]),
    );

    expect(kernel.snapshot.isInvalid, isFalse);
    expect(kernel.snapshot.entryCount, 0);
    expect(
      spatialCandidateIds(kernel.queryHit(spatialWindowNearOrigin(2))),
      <CanvasElementId>[],
    );
    expect(loaded.elementHandlesCalls, 0);
  });
}

void _testStructuralElementChangesTouchedUpdate() {
  test('element add remove deltas update touched entries only', () {
    final changed = structuralAddRemoveTouchedOutcome();
    final replaced = sameIdReplacementTouchedOutcome();

    expect(changed.elementHandlesCalls, 0);
    expect(changed.elementHandleForIdCalls, 4);
    expect(changed.candidateRevisions, {1});
    expect(changed.movedIds, [CanvasElementId('c')]);
    expect(replaced.elementHandlesCalls, 0);
    expect(replaced.elementHandleForIdCalls, 2);
    expect(replaced.originIds, isEmpty);
    expect(replaced.movedIds, [CanvasElementId('a')]);
  });
}

void _testUpdateThenRemove() {
  test(
    'update then remove in one edit applies removal without invalidating',
    () {
      final kernel = SpatialKernel();
      kernel.rebuild(
        SpatialFrameFactsPortFixture([
          spatialRect('a', order: 1),
          spatialRect('b', order: 2),
        ]),
      );
      final removed = SpatialFrameFactsPortFixture([
        spatialRect('b', order: 2),
      ], structuralRevision: 1);

      kernel.applyTouched(
        removed,
        TouchedSet(
          removedElementIds: [CanvasElementId('a')],
          updatedElementIds: [CanvasElementId('a')],
          geometryElementIds: [CanvasElementId('a')],
        ),
      );

      expect(removed.elementHandlesCalls, 0);
      expect(kernel.snapshot.isInvalid, isFalse);
      expect(kernel.snapshot.entryCount, 1);
      expect(spatialCandidateIds(kernel.queryHit(spatialWindowNearOrigin(1))), [
        CanvasElementId('b'),
      ]);
      expect(removed.elementHandleForIdCalls, 2);
    },
  );
}

void _testStructuralRevisionRebase() {
  test('ordinary delta with a new structural revision rebases handles', () {
    final kernel = SpatialKernel();
    kernel.rebuild(
      SpatialFrameFactsPortFixture([
        spatialRect('a', order: 1),
        spatialRect('b', order: 2),
      ]),
    );
    final changed = SpatialFrameFactsPortFixture([
      spatialRect('a', order: 1, translation: const Offset(1000, 0)),
      spatialRect('b', order: 2),
    ], structuralRevision: 1);

    kernel.applyTouched(
      changed,
      TouchedSet(transformedElementIds: [CanvasElementId('a')]),
    );

    final candidateRevisions = spatialCandidateRevisions(
      kernel.queryHit(spatialWindowNearOrigin(1)),
    );

    expect(changed.elementHandlesCalls, 0);
    expect(changed.elementHandleForIdCalls, 2);
    expect(candidateRevisions, {1});
  });
}

void _testEmptyLayerStructuralRevisionRebase() {
  test('empty layer changes rebind candidates without rebuilding elements', () {
    final kernel = SpatialKernel();
    kernel.rebuild(
      SpatialFrameFactsPortFixture([
        spatialRect('a', order: 1),
        spatialRect('b', order: 2),
      ]),
    );
    final layerOnly = SpatialFrameFactsPortFixture([
      spatialRect('a', order: 1),
      spatialRect('b', order: 2),
    ], structuralRevision: 1);

    kernel.applyTouched(
      layerOnly,
      TouchedSet(layerIds: [CanvasLayerId('empty-layer')]),
    );

    expect(layerOnly.elementHandlesCalls, 0);
    expect(layerOnly.elementHandleForIdCalls, 0);
    expect(kernel.snapshot.isInvalid, isFalse);
    expect(kernel.snapshot.entryCount, 2);
    expect(
      spatialCandidateRevisions(kernel.queryHit(spatialWindowNearOrigin(1))),
      {1},
    );
  });
}
