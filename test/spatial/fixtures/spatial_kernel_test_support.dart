import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/touched_set.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_kernel.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_result.dart';

List<CanvasElementId> spatialCandidateIds(SpatialQueryResult result) {
  return result.candidates.map((handle) => handle.id).toList();
}

void expectMovedSpatialCandidateQueries(SpatialKernel kernel) {
  expect(spatialCandidateIds(kernel.queryHit(spatialWindowNearOrigin(0))), [
    CanvasElementId('b'),
  ]);
  expect(spatialCandidateIds(kernel.queryHit(spatialWindowAround(1000, 0))), [
    CanvasElementId('a'),
  ]);
  expect(
    spatialCandidateIds(kernel.queryMarquee(spatialWindowAround(1000, 0))),
    [CanvasElementId('a')],
  );
  expect(
    spatialCandidateIds(kernel.queryEraser(spatialWindowAround(1000, 0))),
    [CanvasElementId('a')],
  );
  final eraserOnly = SpatialKernel();
  eraserOnly.rebuild(
    SpatialFrameFactsPortFixture([
      nonSelectableSpatialRect('eraser-only', order: 1),
    ]),
  );
  expect(
    spatialCandidateIds(eraserOnly.queryHit(spatialWindowNearOrigin(0))),
    isEmpty,
  );
  expect(
    spatialCandidateIds(eraserOnly.queryEraser(spatialWindowNearOrigin(0))),
    [CanvasElementId('eraser-only')],
  );
}

({
  int elementHandlesCalls,
  int elementHandleForIdCalls,
  Set<int> candidateRevisions,
  List<CanvasElementId> movedIds,
})
structuralAddRemoveTouchedOutcome() {
  final kernel = SpatialKernel();
  kernel.rebuild(
    SpatialFrameFactsPortFixture([
      spatialRect('a', order: 1),
      spatialRect('b', order: 2),
    ]),
  );
  final changed = SpatialFrameFactsPortFixture([
    spatialRect('b', order: 1),
    spatialRect('c', order: 2, translation: const Offset(1000, 0)),
  ], structuralRevision: 1);

  kernel.applyTouched(
    changed,
    TouchedSet(
      addedElementIds: [CanvasElementId('c')],
      removedElementIds: [CanvasElementId('a')],
    ),
  );

  final candidateRevisions = spatialCandidateRevisions(
    kernel.queryHit(spatialWindowNearOrigin(1)),
  );
  final movedIds = spatialCandidateIds(
    kernel.queryHit(spatialWindowAround(1000, 1)),
  );

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
sameIdReplacementTouchedOutcome() {
  final kernel = SpatialKernel();
  kernel.rebuild(SpatialFrameFactsPortFixture([spatialRect('a', order: 1)]));
  final replaced = SpatialFrameFactsPortFixture([
    spatialRect('a', order: 1, translation: const Offset(1000, 0)),
  ], structuralRevision: 1);

  kernel.applyTouched(
    replaced,
    TouchedSet(
      addedElementIds: [CanvasElementId('a')],
      removedElementIds: [CanvasElementId('a')],
    ),
  );

  final originIds = spatialCandidateIds(
    kernel.queryHit(spatialWindowNearOrigin(1)),
  );
  final movedIds = spatialCandidateIds(
    kernel.queryHit(spatialWindowAround(1000, 1)),
  );

  return (
    elementHandlesCalls: replaced.elementHandlesCalls,
    elementHandleForIdCalls: replaced.elementHandleForIdCalls,
    originIds: originIds,
    movedIds: movedIds,
  );
}

void applyAndExpectSpatialClearReset(SpatialKernel kernel) {
  final cleared = SpatialFrameFactsPortFixture(const [], structuralRevision: 2);
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
  expect(kernel.queryHit(spatialWindowNearOrigin(2)).candidates, isEmpty);
  expect(kernel.queryPaint(spatialWindowNearOrigin(2)).candidates, isEmpty);
}

void expectInvalidSpatialDeltaTriggersRebuild(SpatialKernel kernel) {
  final recovered = SpatialFrameFactsPortFixture([
    spatialRect('a', order: 1),
    spatialRect('b', order: 2),
  ]);
  kernel.applyTouched(
    recovered,
    TouchedSet(updatedElementIds: [CanvasElementId('b')]),
  );

  expect(recovered.elementHandlesCalls, 1);
  expect(recovered.elementHandleForIdCalls, 0);
  expect(kernel.snapshot.isInvalid, isFalse);
  expect(spatialCandidateIds(kernel.queryHit(spatialWindowNearOrigin(0))), [
    CanvasElementId('b'),
    CanvasElementId('a'),
  ]);
}

void expectSpatialOrderTokenMismatchRejected() {
  final kernel = SpatialKernel();
  kernel.rebuild(
    SpatialFrameFactsPortFixture([spatialRect('order', order: 1)]),
  );
  final staleOrder = SpatialFrameFactsPortFixture(
    [spatialRect('order', order: 1)],
    staleHandleOrderTokens: {CanvasElementId('order'): 99},
  );

  kernel.applyTouched(
    staleOrder,
    TouchedSet(updatedElementIds: [CanvasElementId('order')]),
  );

  expect(kernel.snapshot.isInvalid, isTrue);
  expect(
    kernel.queryHit(spatialWindowNearOrigin(0)),
    isA<SpatialInvalidIndexResult>(),
  );
}

SpatialQueryWindow spatialWindowNearOrigin(int structuralRevision) {
  return SpatialQueryWindow(
    boundsWorld: const Rect.fromLTRB(-20, -20, 20, 20),
    structuralRevision: structuralRevision,
  );
}

Set<int> spatialCandidateRevisions(SpatialQueryResult result) {
  return {for (final handle in result.candidates) handle.structuralRevision};
}

SpatialQueryWindow spatialWindowAround(double x, int structuralRevision) {
  return SpatialQueryWindow(
    boundsWorld: Rect.fromLTRB(x - 20, -20, x + 20, 20),
    structuralRevision: structuralRevision,
  );
}

List<FrameElementFacts> manySpatialRects(int count) {
  return [
    for (var index = 0; index < count; index += 1)
      spatialRect(
        'e$index',
        order: index,
        translation: Offset(index * 20.0, 0),
      ),
  ];
}

FrameElementFacts spatialRect(
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

FrameElementFacts nonSelectableSpatialRect(String id, {required int order}) {
  final source = spatialRect(id, order: order);

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

final class SpatialFrameFactsPortFixture implements FrameFactsPort {
  SpatialFrameFactsPortFixture(
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
  CanvasBackground get background => const CanvasBackground();

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
