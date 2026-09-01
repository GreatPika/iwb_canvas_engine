import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/deletion_entry_projection_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/selection_facts_port.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_kernel.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_read_port.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_interaction_read_adapter.dart';

// This bounded-read fixture keeps the fake frame and ordering assertions
// together so the sparse terminal invariant is proved as one behavior instead
// of weakening it across separate setup paths.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void main() {
  test(
    'selected move reads derive selected facts from selected handle lookups',
    () {
      final frame = _CountingFrameFactsPort([
        _frameRectFacts('unselected-before', const Offset(-100, 0), 0),
        _frameRectFacts('selected-left', const Offset(0, 0), 1),
        _frameRectFacts('unselected-between', const Offset(100, 0), 2),
        _frameRectFacts('selected-right', const Offset(30, 0), 3),
        _frameRectFacts('unselected-after', const Offset(200, 0), 4),
        for (var index = 0; index < 40; index += 1)
          _frameRectFacts(
            'far-unselected-$index',
            Offset(10000 + index * 300, 0),
            5 + index,
          ),
      ]);
      final spatial = SpatialKernel()..rebuild(frame);
      frame.resetAccessCounts();
      final adapter = RuntimeInteractionReadAdapter(
        frame: frame,
        documentSummary: () => const CanvasDocumentSummary(
          elementCount: 45,
          layerCount: 1,
          resourceCount: 0,
        ),
        selection: _SelectionFactsFixture([
          CanvasElementId('selected-right'),
          CanvasElementId('selected-left'),
        ]),
        spatial: spatial,
        controllerEpoch: () => 0,
        deletionEntryProjection: const _NoDeletionEntryProjection(),
      );

      final orderingWork = <RuntimeSelectedMoveOrderingWorkEvent, int>{};
      final facts =
          RuntimeInteractionReadAdapter.observeSelectedMoveOrderingWork(
            (event) => orderingWork.update(
              event,
              (count) => count + 1,
              ifAbsent: () => 1,
            ),
            () => adapter.selectedMoveStartFacts(
              const SelectedMoveStartReadRequest(worldPosition: Offset(15, 0)),
            ),
          );

      expect(facts.selectedIds, [
        CanvasElementId('selected-left'),
        CanvasElementId('selected-right'),
      ]);
      expect(
        facts.selectedGroupBoundsWorld,
        const Rect.fromLTRB(-5, -5, 35, 5),
      );
      expect(facts.insideSelectedGroupUnion, isTrue);
      expect(frame.elementHandlesCalls, 0);
      expect(frame.elementHandleForIdCalls, lessThan(frame.factCount));
      expect(orderingWork[RuntimeSelectedMoveOrderingWorkEvent.sortStarted], 1);
      expect(
        orderingWork[RuntimeSelectedMoveOrderingWorkEvent
            .canonicalOrderComparison],
        1,
      );

      frame.resetAccessCounts();
      orderingWork.clear();
      final commit =
          RuntimeInteractionReadAdapter.observeSelectedMoveOrderingWork(
            (event) => orderingWork.update(
              event,
              (count) => count + 1,
              ifAbsent: () => 1,
            ),
            () => adapter.selectedMoveCommitFacts(
              SelectedMoveCommitReadRequest(
                sessionSelectedIds: facts.selectedIds,
                sessionMovableIds: facts.movableSelectedIds,
                selectionRevision: facts.selectionRevision,
              ),
            ),
          );

      expect(commit.movableIds, [
        CanvasElementId('selected-left'),
        CanvasElementId('selected-right'),
      ]);
      expect(
        commit.movedElements.map((element) => element.id),
        commit.movableIds,
      );
      expect(commit.skippedSessionIds, isEmpty);
      expect(commit.hasDocumentChangesAvailable, isTrue);
      expect(frame.elementHandlesCalls, 0);
      expect(frame.elementHandleForIdCalls, lessThanOrEqualTo(2));
      expect(frame.resolveElementCalls, lessThanOrEqualTo(4));
      expect(
        orderingWork[RuntimeSelectedMoveOrderingWorkEvent.sortStarted],
        isNull,
      );
      expect(
        orderingWork[RuntimeSelectedMoveOrderingWorkEvent
            .canonicalOrderComparison],
        1,
      );
    },
  );
  _testSelectedMoveReusesReverseOrderedCandidateFacts();
  _testSelectedMoveDirectFallbackBoundsParticipantProjectionWork();
  _testSelectedMoveTerminalResortsCurrentHandles();
}

// This one flow ties candidate work to the ordered start facts it returns.
// ignore: halstead-volume, source-lines-of-code
void _testSelectedMoveReusesReverseOrderedCandidateFacts() {
  test(
    'selected move reuses reverse-ordered candidate facts for full coverage',
    () {
      final lower = _frameRectFacts('lower', Offset.zero, 0);
      final middle = _frameRectFacts('middle', Offset.zero, 1);
      final upper = _frameRectFacts('upper', Offset.zero, 2);
      final frame = _CountingFrameFactsPort([lower, middle, upper]);
      final adapter = RuntimeInteractionReadAdapter(
        frame: frame,
        documentSummary: () => const CanvasDocumentSummary(
          elementCount: 3,
          layerCount: 1,
          resourceCount: 0,
        ),
        selection: _SelectionFactsFixture([lower.id, middle.id, upper.id]),
        spatial: SpatialKernel()..rebuild(frame),
        controllerEpoch: () => 0,
        deletionEntryProjection: const _NoDeletionEntryProjection(),
      );

      frame.resetAccessCounts();
      final projectionWork = <RuntimeSelectedMoveOrderingWorkEvent, int>{};
      final facts =
          RuntimeInteractionReadAdapter.observeSelectedMoveOrderingWork(
            (event) => projectionWork.update(
              event,
              (count) => count + 1,
              ifAbsent: () => 1,
            ),
            () => adapter.selectedMoveStartFacts(
              const SelectedMoveStartReadRequest(worldPosition: Offset.zero),
            ),
          );

      expect(facts.movableParticipants.map((item) => item.element.id), [
        lower.id,
        middle.id,
        upper.id,
      ]);
      expect(
        projectionWork[RuntimeSelectedMoveOrderingWorkEvent
            .participantCandidateCompared],
        3,
      );
      expect(
        projectionWork[RuntimeSelectedMoveOrderingWorkEvent
            .participantDirectlyResolved],
        isNull,
      );
      expect(frame.resolveElementCalls, 14);
    },
  );
}

// The selected and unrelated-candidate setup must remain together to prove
// direct fallback work stays below the former participant-by-candidate scan.
// ignore: halstead-volume, source-lines-of-code
void _testSelectedMoveDirectFallbackBoundsParticipantProjectionWork() {
  test(
    'selected move directly resolves participants outside hit candidates',
    () {
      final selectedLower = _frameRectFacts(
        'selected-lower',
        const Offset(-10000, 0),
        0,
      );
      final selectedUpper = _frameRectFacts(
        'selected-upper',
        const Offset(-11000, 0),
        1,
      );
      final frame = _CountingFrameFactsPort([
        selectedLower,
        selectedUpper,
        for (var index = 0; index < 3; index += 1)
          _frameRectFacts(
            'locked-candidate-$index',
            Offset.zero,
            2 + index,
            isLocked: true,
          ),
      ]);
      final adapter = RuntimeInteractionReadAdapter(
        frame: frame,
        documentSummary: () => const CanvasDocumentSummary(
          elementCount: 5,
          layerCount: 1,
          resourceCount: 0,
        ),
        selection: _SelectionFactsFixture([selectedLower.id, selectedUpper.id]),
        spatial: SpatialKernel()..rebuild(frame),
        controllerEpoch: () => 0,
        deletionEntryProjection: const _NoDeletionEntryProjection(),
      );

      final projectionWork = <RuntimeSelectedMoveOrderingWorkEvent, int>{};
      final facts =
          RuntimeInteractionReadAdapter.observeSelectedMoveOrderingWork(
            (event) => projectionWork.update(
              event,
              (count) => count + 1,
              ifAbsent: () => 1,
            ),
            () => adapter.selectedMoveStartFacts(
              const SelectedMoveStartReadRequest(worldPosition: Offset.zero),
            ),
          );

      final observedProjectionWork =
          (projectionWork[RuntimeSelectedMoveOrderingWorkEvent
                  .participantCandidateCompared] ??
              0) +
          (projectionWork[RuntimeSelectedMoveOrderingWorkEvent
                  .participantDirectlyResolved] ??
              0);
      expect(facts.movableParticipants.map((item) => item.element.id), [
        selectedLower.id,
        selectedUpper.id,
      ]);
      expect(facts.query.candidateCount, 3);
      expect(
        projectionWork[RuntimeSelectedMoveOrderingWorkEvent
            .participantCandidateCompared],
        isNull,
      );
      expect(
        projectionWork[RuntimeSelectedMoveOrderingWorkEvent
            .participantDirectlyResolved],
        facts.movableParticipants.length,
      );
      expect(
        observedProjectionWork,
        lessThanOrEqualTo(
          facts.movableParticipants.length + facts.query.candidateCount,
        ),
      );
    },
  );
}

// This keeps session capture, structural reorder, and terminal assertions in
// one flow so the current-order fallback cannot be proved by disconnected
// setup helpers.
// ignore: halstead-volume, source-lines-of-code
void _testSelectedMoveTerminalResortsCurrentHandles() {
  test(
    'selected move terminal sorts current handles after structural reorder',
    () {
      final leftId = CanvasElementId('selected-left');
      final rightId = CanvasElementId('selected-right');
      final frame = _CountingFrameFactsPort([
        _frameRectFacts(leftId.value, Offset.zero, 1),
        _frameRectFacts(rightId.value, const Offset(30, 0), 3),
      ]);
      final adapter = RuntimeInteractionReadAdapter(
        frame: frame,
        documentSummary: () => const CanvasDocumentSummary(
          elementCount: 2,
          layerCount: 1,
          resourceCount: 0,
        ),
        selection: _SelectionFactsFixture([rightId, leftId]),
        spatial: SpatialKernel()..rebuild(frame),
        controllerEpoch: () => 0,
        deletionEntryProjection: const _NoDeletionEntryProjection(),
      );
      final start = adapter.selectedMoveStartFacts(
        const SelectedMoveStartReadRequest(worldPosition: Offset(15, 0)),
      );
      expect(start.movableSelectedIds, [leftId, rightId]);

      frame.reorder({leftId: 3, rightId: 1});
      frame.resetAccessCounts();
      final orderingWork = <RuntimeSelectedMoveOrderingWorkEvent, int>{};
      final commit =
          RuntimeInteractionReadAdapter.observeSelectedMoveOrderingWork(
            (event) => orderingWork.update(
              event,
              (count) => count + 1,
              ifAbsent: () => 1,
            ),
            () => adapter.selectedMoveCommitFacts(
              SelectedMoveCommitReadRequest(
                sessionSelectedIds: start.selectedIds,
                sessionMovableIds: start.movableSelectedIds,
                selectionRevision: start.selectionRevision,
              ),
            ),
          );

      expect(commit.movableIds, [rightId, leftId]);
      expect(commit.movedElements.map((element) => element.id), [
        rightId,
        leftId,
      ]);
      expect(frame.elementHandlesCalls, 0);
      expect(frame.elementHandleForIdCalls, lessThanOrEqualTo(2));
      expect(frame.resolveElementCalls, lessThanOrEqualTo(4));
      expect(orderingWork[RuntimeSelectedMoveOrderingWorkEvent.sortStarted], 1);
    },
  );
}

final class _NoDeletionEntryProjection implements DeletionEntryProjectionPort {
  const _NoDeletionEntryProjection();

  @override
  DeletionEntryProjection projectDeletionEntries(
    Iterable<CanvasElementId> ids,
  ) => const DeletionEntryProjection.empty();
}

FrameElementFacts _frameRectFacts(
  String id,
  Offset offset,
  int orderToken, {
  bool isLocked = false,
}) {
  return FrameElementFacts(
    id: CanvasElementId(id),
    kind: CanvasElementKind.rect,
    revision: 0,
    generation: 0,
    orderToken: orderToken,
    locationKind: FrameElementLocationKind.content,
    transform: CanvasTransform.translation(offset),
    opacity: 1,
    hitPadding: 0,
    isVisible: true,
    isSelectable: true,
    isLocked: isLocked,
    isDeletable: true,
    isTransformable: true,
    metadata: const CanvasMetadata.empty(),
    size: const Size(10, 10),
  );
}

final class _SelectionFactsFixture implements SelectionFactsPort {
  _SelectionFactsFixture(Iterable<CanvasElementId> ids)
    : _selectionFacts = SelectionFacts(
        selectedElementIds: ids,
        selectionRevision: 0,
      );

  final SelectionFacts _selectionFacts;

  @override
  SelectionFacts get selectionFacts => _selectionFacts;
}

// The fake implements the full frame fact seam so the bounded-read test can
// count broad handle scans separately from selected-id lookups.
// ignore: number-of-methods
final class _CountingFrameFactsPort implements FrameFactsPort {
  _CountingFrameFactsPort(List<FrameElementFacts> facts)
    : _facts = facts,
      _factsById = {for (final facts in facts) facts.id: facts},
      _orderTokens = {for (final facts in facts) facts.id: facts.orderToken};

  final List<FrameElementFacts> _facts;
  final Map<CanvasElementId, FrameElementFacts> _factsById;
  final Map<CanvasElementId, int> _orderTokens;
  int _structuralRevision = 0;
  int elementCountCalls = 0;
  int elementHandlesCalls = 0;
  int elementHandleForIdCalls = 0;
  int resolveElementCalls = 0;
  int get factCount => _facts.length;

  void reorder(Map<CanvasElementId, int> orderTokens) {
    _orderTokens.addAll(orderTokens);
    _structuralRevision += 1;
  }

  @override
  CanvasBackground get background => const CanvasBackground();

  @override
  FrameRevisionFacts get frameRevisions {
    return FrameRevisionFacts(
      documentRevision: _structuralRevision,
      structuralRevision: _structuralRevision,
      boundsRevision: 0,
      elementVisualRevision: 0,
      backgroundRevision: 0,
      gridRevision: 0,
      resourceRevision: 0,
    );
  }

  void resetAccessCounts() {
    elementCountCalls = 0;
    elementHandlesCalls = 0;
    elementHandleForIdCalls = 0;
    resolveElementCalls = 0;
  }

  @override
  int elementCount(int structuralRevision) {
    elementCountCalls += 1;

    return _facts.length;
  }

  @override
  List<FrameElementHandle> elementHandles(int structuralRevision) {
    elementHandlesCalls += 1;

    return [for (final facts in _facts) _handleFor(facts)];
  }

  @override
  FrameElementHandle? elementHandleForId(
    int structuralRevision,
    CanvasElementId id,
  ) {
    elementHandleForIdCalls += 1;
    final facts = _factsById[id];

    return facts == null ? null : _handleFor(facts);
  }

  @override
  FrameElementFacts? resolveElement(FrameElementHandle handle) {
    resolveElementCalls += 1;
    final facts = _factsById[handle.id];

    return facts != null && _orderTokens[handle.id] == handle.orderToken
        ? facts
        : null;
  }

  @override
  FrameResourceDescriptorFacts? resourceDescriptor(CanvasResourceId id) {
    return null;
  }

  FrameElementHandle _handleFor(FrameElementFacts facts) {
    return FrameElementHandle(
      id: facts.id,
      structuralRevision: _structuralRevision,
      generation: facts.generation,
      orderToken: _orderTokens[facts.id]!,
    );
  }
}
