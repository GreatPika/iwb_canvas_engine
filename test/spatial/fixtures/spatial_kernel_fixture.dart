import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/touched_set.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_kernel.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_port.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_result.dart';

void main() {
  _testTouchedUpdate();
  _testReplacementRebuild();
  _testStructuralElementChangesTouchedUpdate();
  _testStructuralRevisionMismatchRebuild();
  _testNoFullCloneAndClearReset();
  _testStaleCandidatesRejected();
  _testFailedUpdatePreservesEntries();
  _testMissingTouchedHandleRejected();
  _testInvalidIndexBudgetExceeded();
}

void _testTouchedUpdate() {
  test('ordinary updates touch only changed ids and keep other candidates', () {
    final kernel = SpatialKernel();
    kernel.rebuild(_FramePort([_rect('a', order: 1), _rect('b', order: 2)]));
    final updated = _FramePort([
      _rect('a', order: 1, translation: const Offset(1000, 0)),
      _rect('b', order: 2),
    ]);

    kernel.applyTouched(
      updated,
      TouchedSet(transformedElementIds: [CanvasElementId('a')]),
    );

    expect(updated.elementHandlesCalls, 0);
    expect(updated.elementHandleForIdCalls, 1);
    _expectMovedCandidateQueries(kernel);
  });
}

void _testReplacementRebuild() {
  test('document replacement rebuilds the full spatial index', () {
    final kernel = SpatialKernel();
    kernel.rebuild(_FramePort([_rect('old', order: 1)]));
    final loaded = _FramePort([
      _rect('new-a', order: 1),
      _rect('new-b', order: 2, translation: const Offset(1000, 0)),
    ], structuralRevision: 1);

    kernel.applyTouched(loaded, TouchedSet(documentReplaced: true));

    expect(loaded.elementHandlesCalls, 1);
    expect(loaded.elementHandleForIdCalls, 0);
    expect(kernel.snapshot.entryCount, 2);
    expect(_ids(kernel.queryHit(_windowNearOrigin(1))), [
      CanvasElementId('new-a'),
    ]);
  });
}

void _testStructuralElementChangesTouchedUpdate() {
  test('element add remove deltas update touched entries only', () {
    final changed = _structuralAddRemoveTouchedOutcome();
    final replaced = _sameIdReplacementTouchedOutcome();

    expect(changed.elementHandlesCalls, 0);
    expect(changed.elementHandleForIdCalls, 3);
    expect(changed.candidateRevisions, {1});
    expect(changed.movedIds, [CanvasElementId('c')]);
    expect(replaced.elementHandlesCalls, 0);
    expect(replaced.elementHandleForIdCalls, 2);
    expect(replaced.originIds, isEmpty);
    expect(replaced.movedIds, [CanvasElementId('a')]);
  });
}

void _testStructuralRevisionMismatchRebuild() {
  test('ordinary delta with a new structural revision rebases handles', () {
    final kernel = SpatialKernel();
    kernel.rebuild(_FramePort([_rect('a', order: 1), _rect('b', order: 2)]));
    final changed = _FramePort([
      _rect('a', order: 1, translation: const Offset(1000, 0)),
      _rect('b', order: 2),
    ], structuralRevision: 1);

    kernel.applyTouched(
      changed,
      TouchedSet(transformedElementIds: [CanvasElementId('a')]),
    );

    final candidateRevisions = _candidateRevisions(
      kernel.queryHit(_windowNearOrigin(1)),
    );

    expect(changed.elementHandlesCalls, 0);
    expect(changed.elementHandleForIdCalls, 2);
    expect(candidateRevisions, {1});
  });
}

void _testNoFullCloneAndClearReset() {
  test('ordinary update avoids full clone and clear reset empties index', () {
    final kernel = SpatialKernel();
    kernel.rebuild(_FramePort([_rect('a', order: 1), _rect('b', order: 2)]));
    final before = kernel.snapshot;
    final updated = _FramePort([
      _rect('a', order: 1),
      _rect('b', order: 2, translation: const Offset(300, 0)),
    ]);

    kernel.applyTouched(
      updated,
      TouchedSet(geometryElementIds: [CanvasElementId('b')]),
    );

    expect(updated.elementHandlesCalls, 0);
    expect(kernel.snapshot.entryCount, before.entryCount);

    _applyAndExpectClearReset(kernel);
  });
}

void _testStaleCandidatesRejected() {
  test('stale structural revision and handle facts are rejected', () {
    final kernel = SpatialKernel();
    kernel.rebuild(_FramePort([_rect('a', order: 1)]));

    final stale = kernel.queryHit(_windowNearOrigin(99));
    expect(stale, isA<SpatialStaleCandidateResult>());

    final corrupt = _FramePort([_rect('a', order: 1, generation: 1)]);
    kernel.applyTouched(
      corrupt,
      TouchedSet(updatedElementIds: [CanvasElementId('a')]),
    );

    expect(kernel.snapshot.isInvalid, isTrue);
    expect(
      kernel.queryHit(_windowNearOrigin(0)),
      isA<SpatialInvalidIndexResult>(),
    );

    _expectOrderTokenMismatchRejected();
    _expectInvalidDeltaTriggersRebuild(kernel);
  });
}

void _testFailedUpdatePreservesEntries() {
  test(
    'failed staged update preserves entries and returns typed invalid results',
    () {
      final kernel = SpatialKernel();
      kernel.rebuild(_FramePort([_rect('a', order: 1), _rect('b', order: 2)]));
      final before = kernel.snapshot;
      final corrupt = _FramePort([
        _rect('a', order: 1, generation: 1),
        _rect('b', order: 2),
      ]);

      kernel.applyTouched(
        corrupt,
        TouchedSet(updatedElementIds: [CanvasElementId('a')]),
      );

      expect(kernel.snapshot.entryCount, before.entryCount);
      final invalid = kernel.queryPaint(_windowNearOrigin(0));
      expect(invalid, isA<SpatialInvalidIndexResult>());
      expect(invalid.candidates, isEmpty);
      expect(kernel.budgetCounters.invalidIndexProbeCount, 1);
    },
  );
}

void _testMissingTouchedHandleRejected() {
  test('missing non-removed touched handle keeps index invalid', () {
    final kernel = SpatialKernel();
    kernel.rebuild(_FramePort([_rect('a', order: 1), _rect('b', order: 2)]));

    kernel.applyTouched(
      _FramePort([_rect('b', order: 2)]),
      TouchedSet(updatedElementIds: [CanvasElementId('a')]),
    );

    expect(kernel.snapshot.entryCount, 2);
    expect(kernel.snapshot.isInvalid, isTrue);
    expect(
      kernel.queryHit(_windowNearOrigin(0)),
      isA<SpatialInvalidIndexResult>(),
    );
  });
}

void _testInvalidIndexBudgetExceeded() {
  test('invalid index over fallback budget returns no partial candidates', () {
    final kernel = SpatialKernel();
    kernel.rebuild(_FramePort(_manyRects(kCanvasMaxFallbackCandidates + 1)));
    final corrupt = _FramePort([_rect('e0', order: 0, generation: 1)]);
    kernel.applyTouched(
      corrupt,
      TouchedSet(updatedElementIds: [CanvasElementId('e0')]),
    );

    final result = kernel.queryHit(_windowNearOrigin(0));
    expect(result, isA<SpatialBudgetExceededResult>());
    expect(result.candidates, isEmpty);
    expect(kernel.budgetCounters.fallbackCandidateBudgetExceededCount, 1);
  });
}

List<CanvasElementId> _ids(SpatialQueryResult result) {
  return result.candidates.map((handle) => handle.id).toList();
}

void _expectMovedCandidateQueries(SpatialKernel kernel) {
  expect(_ids(kernel.queryHit(_windowNearOrigin(0))), [CanvasElementId('b')]);
  expect(_ids(kernel.queryHit(_windowAround(1000, 0))), [CanvasElementId('a')]);
  expect(_ids(kernel.queryMarquee(_windowAround(1000, 0))), [
    CanvasElementId('a'),
  ]);
  expect(_ids(kernel.queryEraser(_windowAround(1000, 0))), [
    CanvasElementId('a'),
  ]);
  final eraserOnly = SpatialKernel();
  eraserOnly.rebuild(_FramePort([_nonSelectableRect('eraser-only', order: 1)]));
  expect(_ids(eraserOnly.queryHit(_windowNearOrigin(0))), isEmpty);
  expect(_ids(eraserOnly.queryEraser(_windowNearOrigin(0))), [
    CanvasElementId('eraser-only'),
  ]);
}

({
  int elementHandlesCalls,
  int elementHandleForIdCalls,
  Set<int> candidateRevisions,
  List<CanvasElementId> movedIds,
})
_structuralAddRemoveTouchedOutcome() {
  final kernel = SpatialKernel();
  kernel.rebuild(_FramePort([_rect('a', order: 1), _rect('b', order: 2)]));
  final changed = _FramePort([
    _rect('b', order: 1),
    _rect('c', order: 2, translation: const Offset(1000, 0)),
  ], structuralRevision: 1);

  kernel.applyTouched(
    changed,
    TouchedSet(
      addedElementIds: [CanvasElementId('c')],
      removedElementIds: [CanvasElementId('a')],
    ),
  );

  final candidateRevisions = _candidateRevisions(
    kernel.queryHit(_windowNearOrigin(1)),
  );
  final movedIds = _ids(kernel.queryHit(_windowAround(1000, 1)));

  return (
    elementHandlesCalls: changed.elementHandlesCalls,
    elementHandleForIdCalls: changed.elementHandleForIdCalls,
    candidateRevisions: candidateRevisions,
    movedIds: movedIds,
  );
}

({
  int elementHandlesCalls,
  int elementHandleForIdCalls,
  List<CanvasElementId> originIds,
  List<CanvasElementId> movedIds,
})
_sameIdReplacementTouchedOutcome() {
  final kernel = SpatialKernel();
  kernel.rebuild(_FramePort([_rect('a', order: 1)]));
  final replaced = _FramePort([
    _rect('a', order: 1, translation: const Offset(1000, 0)),
  ], structuralRevision: 1);

  kernel.applyTouched(
    replaced,
    TouchedSet(
      addedElementIds: [CanvasElementId('a')],
      removedElementIds: [CanvasElementId('a')],
    ),
  );

  final originIds = _ids(kernel.queryHit(_windowNearOrigin(1)));
  final movedIds = _ids(kernel.queryHit(_windowAround(1000, 1)));

  return (
    elementHandlesCalls: replaced.elementHandlesCalls,
    elementHandleForIdCalls: replaced.elementHandleForIdCalls,
    originIds: originIds,
    movedIds: movedIds,
  );
}

void _applyAndExpectClearReset(SpatialKernel kernel) {
  final cleared = _FramePort(const [], structuralRevision: 2);
  kernel.applyTouched(
    cleared,
    TouchedSet(
      removedElementIds: [CanvasElementId('a'), CanvasElementId('b')],
      selection: true,
    ),
  );

  expect(cleared.elementCountCalls, 1);
  expect(cleared.elementHandlesCalls, 0);
  expect(kernel.snapshot.entryCount, 0);
  expect(kernel.snapshot.hitTilePageCount, 0);
  expect(kernel.queryHit(_windowNearOrigin(2)).candidates, isEmpty);
  expect(kernel.queryPaint(_windowNearOrigin(2)).candidates, isEmpty);
}

void _expectInvalidDeltaTriggersRebuild(SpatialKernel kernel) {
  final recovered = _FramePort([_rect('a', order: 1), _rect('b', order: 2)]);
  kernel.applyTouched(
    recovered,
    TouchedSet(updatedElementIds: [CanvasElementId('b')]),
  );

  expect(recovered.elementHandlesCalls, 1);
  expect(recovered.elementHandleForIdCalls, 0);
  expect(kernel.snapshot.isInvalid, isFalse);
  expect(_ids(kernel.queryHit(_windowNearOrigin(0))), [
    CanvasElementId('b'),
    CanvasElementId('a'),
  ]);
}

void _expectOrderTokenMismatchRejected() {
  final kernel = SpatialKernel();
  kernel.rebuild(_FramePort([_rect('order', order: 1)]));
  final staleOrder = _FramePort(
    [_rect('order', order: 1)],
    staleHandleOrderTokens: {CanvasElementId('order'): 99},
  );

  kernel.applyTouched(
    staleOrder,
    TouchedSet(updatedElementIds: [CanvasElementId('order')]),
  );

  expect(kernel.snapshot.isInvalid, isTrue);
  expect(
    kernel.queryHit(_windowNearOrigin(0)),
    isA<SpatialInvalidIndexResult>(),
  );
}

SpatialQueryWindow _windowNearOrigin(int structuralRevision) {
  return SpatialQueryWindow(
    boundsWorld: const Rect.fromLTRB(-20, -20, 20, 20),
    structuralRevision: structuralRevision,
  );
}

Set<int> _candidateRevisions(SpatialQueryResult result) {
  return {for (final handle in result.candidates) handle.structuralRevision};
}

SpatialQueryWindow _windowAround(double x, int structuralRevision) {
  return SpatialQueryWindow(
    boundsWorld: Rect.fromLTRB(x - 20, -20, x + 20, 20),
    structuralRevision: structuralRevision,
  );
}

List<FrameElementFacts> _manyRects(int count) {
  return [
    for (var index = 0; index < count; index += 1)
      _rect('e$index', order: index, translation: Offset(index * 20.0, 0)),
  ];
}

FrameElementFacts _rect(
  String id, {
  required int order,
  int generation = 0,
  Offset translation = Offset.zero,
}) {
  return FrameElementFacts(
    id: CanvasElementId(id),
    kind: CanvasElementKind.rect,
    revision: 0,
    generation: generation,
    orderToken: order,
    locationKind: FrameElementLocationKind.content,
    transform: CanvasTransform.translation(translation),
    opacity: 1,
    hitPadding: 0,
    isVisible: true,
    isSelectable: true,
    isLocked: false,
    isDeletable: true,
    isTransformable: true,
    metadata: const CanvasMetadata.empty(),
    size: const Size(10, 10),
  );
}

FrameElementFacts _nonSelectableRect(String id, {required int order}) {
  final source = _rect(id, order: order);

  return FrameElementFacts(
    id: source.id,
    kind: source.kind,
    revision: source.revision,
    generation: source.generation,
    orderToken: source.orderToken,
    locationKind: source.locationKind,
    transform: source.transform,
    opacity: source.opacity,
    hitPadding: source.hitPadding,
    isVisible: source.isVisible,
    isSelectable: false,
    isLocked: source.isLocked,
    isDeletable: source.isDeletable,
    isTransformable: source.isTransformable,
    metadata: source.metadata,
    size: source.size,
  );
}

final class _FramePort implements FrameFactsPort {
  _FramePort(
    this._facts, {
    this.structuralRevision = 0,
    Map<CanvasElementId, int> staleHandleOrderTokens = const {},
  }) : _staleHandleOrderTokens = staleHandleOrderTokens;

  final List<FrameElementFacts> _facts;
  final int structuralRevision;
  final Map<CanvasElementId, int> _staleHandleOrderTokens;
  int elementCountCalls = 0;
  int elementHandlesCalls = 0;
  int elementHandleForIdCalls = 0;

  @override
  FrameRevisionFacts get frameRevisions {
    return FrameRevisionFacts(
      documentRevision: structuralRevision,
      structuralRevision: structuralRevision,
      boundsRevision: structuralRevision,
      elementVisualRevision: structuralRevision,
      backgroundRevision: 0,
      gridRevision: 0,
      resourceRevision: 0,
    );
  }

  @override
  int elementCount(int structuralRevision) {
    elementCountCalls += 1;
    if (structuralRevision != this.structuralRevision) {
      return 0;
    }

    return _facts.length;
  }

  @override
  List<FrameElementHandle> elementHandles(int structuralRevision) {
    elementHandlesCalls += 1;
    if (structuralRevision != this.structuralRevision) {
      return const [];
    }

    return [for (final facts in _facts) _handleFor(facts)];
  }

  @override
  FrameElementHandle? elementHandleForId(
    int structuralRevision,
    CanvasElementId id,
  ) {
    elementHandleForIdCalls += 1;
    if (structuralRevision != this.structuralRevision) {
      return null;
    }

    for (final facts in _facts) {
      if (facts.id == id) {
        return _handleFor(facts);
      }
    }

    return null;
  }

  @override
  FrameElementFacts? resolveElement(FrameElementHandle handle) {
    for (final facts in _facts) {
      if (facts.id == handle.id &&
          handle.structuralRevision == structuralRevision &&
          handle.generation == 0 &&
          handle.orderToken == facts.orderToken) {
        return facts;
      }
    }

    return null;
  }

  @override
  FrameResourceDescriptorFacts? resourceDescriptor(CanvasResourceId id) {
    return null;
  }

  FrameElementHandle _handleFor(FrameElementFacts facts) {
    return FrameElementHandle(
      id: facts.id,
      structuralRevision: structuralRevision,
      generation: 0,
      orderToken: _staleHandleOrderTokens[facts.id] ?? facts.orderToken,
    );
  }
}
