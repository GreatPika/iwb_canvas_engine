// The adapter explicitly names its fact owners. Keeping those imports local
// makes the read boundary auditable instead of hiding dependencies in a barrel.
// ignore_for_file: number-of-imports

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../contracts/internal/deletion_entry_projection_port.dart';
import '../contracts/internal/frame_facts_port.dart';
import '../contracts/internal/selection_facts_port.dart';
import '../contracts/public/canvas_ids.dart';
import '../geometry/hit_test_policy.dart';
import '../geometry/spatial_kernel.dart';
import '../geometry/spatial_query_policy.dart';
import '../interaction/interaction_read_port.dart';
import 'runtime_interaction_read_mapping.dart';
import 'runtime_interaction_move_read_models.dart';

@visibleForTesting
enum RuntimeEraserEntryRouteWorkKind {
  terminalReadStarted,
  exactHitIdsReady,
  entriesReady,
}

@visibleForTesting
final class RuntimeEraserEntryRouteWorkEvent {
  const RuntimeEraserEntryRouteWorkEvent({
    required this.kind,
    this.exactHitIds = const [],
    this.entries = const [],
  });

  final RuntimeEraserEntryRouteWorkKind kind;
  final List<CanvasElementId> exactHitIds;
  final List<DeletionEntryFacts> entries;
}

final Object _eraserEntryRouteWorkZoneKey = Object();

// The runtime read adapter intentionally names each read collaborator so the
// interaction owner receives one immutable fact seam without hiding ownership
// boundaries behind metric-only wrapper files.
// Keeping the read intents together makes cross-tool committed-fact ordering
// auditable at the runtime boundary instead of scattering it across wrappers.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class RuntimeInteractionReadAdapter implements InteractionReadPort {
  const RuntimeInteractionReadAdapter({
    required FrameFactsPort frame,
    required RuntimeDocumentSummaryReader documentSummary,
    required SelectionFactsPort selection,
    required SpatialKernel spatial,
    required int Function() controllerEpoch,
    required DeletionEntryProjectionPort deletionEntryProjection,
    Set<Object>? eraserElementKinds,
    HitTestPolicy hitTestPolicy = const HitTestPolicy(),
  }) : _frame = frame,
       _documentSummary = documentSummary,
       _selection = selection,
       _spatial = spatial,
       _controllerEpoch = controllerEpoch,
       _deletionEntryProjection = deletionEntryProjection,
       _eraserElementKinds = eraserElementKinds,
       _hitTestPolicy = hitTestPolicy;

  final FrameFactsPort _frame;
  final RuntimeDocumentSummaryReader _documentSummary;
  final SelectionFactsPort _selection;
  final SpatialKernel _spatial;
  final int Function() _controllerEpoch;
  final DeletionEntryProjectionPort _deletionEntryProjection;
  final Set<Object>? _eraserElementKinds;
  final HitTestPolicy _hitTestPolicy;

  /// Assertion-gated route facts let fixtures isolate terminal read-to-entry
  /// work without adding release counters, state, or a second route pass.
  @visibleForTesting
  static T observeEraserEntryRouteWork<T>(
    void Function(RuntimeEraserEntryRouteWorkEvent event) sink,
    T Function() operation,
  ) => runZoned(operation, zoneValues: {_eraserEntryRouteWorkZoneKey: sink});

  static bool _recordEraserEntryRouteWork(
    RuntimeEraserEntryRouteWorkEvent event,
  ) {
    final sink = Zone.current[_eraserEntryRouteWorkZoneKey];
    if (sink is void Function(RuntimeEraserEntryRouteWorkEvent)) {
      sink(event);
    }
    return true;
  }

  @override
  // Move-start reads keep selection ids, exact hit facts, group bounds, and
  // occlusion in one snapshot so the gesture owner cannot mix revisions.
  // ignore: halstead-volume, source-lines-of-code
  SelectedMoveStartFacts selectedMoveStartFacts(
    SelectedMoveStartReadRequest request,
  ) {
    final context = _selectedMoveStartReadContext();
    final selectedHandles = _selectedHandlesInDocumentOrder(
      structuralRevision: context.structuralRevision,
      ids: context.selection.selectedElementIds,
    );
    final selectedIds = _idsForHandles(selectedHandles);
    final movableIds = _movableIdsFromHandles(selectedHandles);
    final query = _spatial.queryHit(
      SpatialQueryWindow(
        boundsWorld: _pointQueryWindow(request.worldPosition),
        structuralRevision: context.structuralRevision,
      ),
    );
    final candidates = resolveInteractionCandidates(
      query,
      resolve: _frame.resolveElement,
    );
    final hit = _hitTestPolicy.topmostHitResult(
      point: request.worldPosition,
      candidates: candidates.handles,
      resolve: _frame.resolveElement,
    );
    final hitFacts = hit == null
        ? null
        : interactionFactsForId(candidates, hit.id);
    final contentQuery = _spatial.queryContext(
      SpatialQueryWindow(
        boundsWorld: _pointQueryWindow(request.worldPosition),
        structuralRevision: context.structuralRevision,
      ),
    );
    final contentCandidates = resolveInteractionCandidates(
      contentQuery,
      resolve: _frame.resolveElement,
    );
    final contentQueryFacts = interactionQueryFacts(
      contentQuery,
      contentCandidates,
    );
    final contentHit = _hitTestPolicy.topmostContextHitResult(
      point: request.worldPosition,
      candidates: contentCandidates.handles,
      resolve: _frame.resolveElement,
    );
    final selectedGroup = _selectedGroupFacts(
      selectedHandles: selectedHandles,
      selectedIds: selectedIds,
      point: request.worldPosition,
      occlusion: (
        topmostContentHit: contentHit,
        isReliable: _hasReliableCandidateFacts(contentQueryFacts),
      ),
    );

    return SelectedMoveStartFacts(
      selectedIds: selectedIds,
      movableSelectedIds: movableIds,
      controllerEpoch: context.controllerEpoch,
      selectionRevision: context.selection.selectionRevision,
      hitSelectedMovable: hit != null && movableIds.contains(hit.id),
      topmostMovableHitId: _movableHitId(hitFacts),
      topmostHitId: hit?.id,
      topmostHitOrderToken: hit?.orderToken,
      selectedGroupBoundsWorld: selectedGroup.boundsWorld,
      selectedTopOrderToken: selectedGroup.topOrderToken,
      insideSelectedGroupUnion: selectedGroup.insideUnion,
      groupUnionOccludedByHigherOrderHit: selectedGroup.occluded,
      groupUnionOcclusionReliable: selectedGroup.occlusionReliable,
      query: interactionQueryFacts(query, candidates),
    );
  }

  @override
  SelectedMoveCommitFacts selectedMoveCommitFacts(
    SelectedMoveCommitReadRequest request,
  ) {
    final context = _readContext();
    final sessionSelectedIds = request.sessionSelectedIds.toSet();
    final requestedMovableIds = request.sessionMovableIds.where(
      sessionSelectedIds.contains,
    );
    final movableIds = _movableIds(context, requestedMovableIds);
    final moveReadModels = selectedMoveReadModels(
      RuntimeSelectedMoveReadModelInputs(
        frame: _frame,
        documentSummary: _documentSummary,
        handles: context.handles,
        movableIds: movableIds,
      ),
    );
    final skippedIds = request.sessionMovableIds
        .where((id) => !movableIds.contains(id))
        .toList(growable: false);

    return SelectedMoveCommitFacts(
      movableIds: movableIds,
      movedElements: moveReadModels.movedElements,
      documentSummary: moveReadModels.documentSummary,
      selectionBoundsWorld: moveReadModels.selectionBoundsWorld,
      controllerEpoch: context.controllerEpoch,
      selectionRevision: context.selection.selectionRevision,
      hasDocumentChangesAvailable:
          _selectedMoveCommitSelectionIsCurrent(context.selection, request) &&
          movableIds.isNotEmpty,
      skippedSessionIds: skippedIds,
    );
  }

  @override
  MarqueeStartFacts marqueeStartFacts(MarqueeStartReadRequest request) {
    final context = _readContext();

    return MarqueeStartFacts(
      previousSelectedIds: _documentOrderIds(
        handles: context.handles,
        ids: context.selection.selectedElementIds,
      ),
      controllerEpoch: context.controllerEpoch,
      selectionRevision: context.selection.selectionRevision,
    );
  }

  @override
  MarqueeCommitFacts marqueeCommitFacts(MarqueeCommitReadRequest request) {
    final context = _readContext();
    final rect = _normalizeRect(request.rectWorld);
    if (rect.width == 0 && rect.height == 0) {
      return _pointSelectionCommitFacts(context: context, rect: rect);
    }
    final query = _spatial.queryMarquee(
      SpatialQueryWindow(
        boundsWorld: rect,
        structuralRevision: context.structuralRevision,
      ),
    );
    final candidates = resolveInteractionCandidates(
      query,
      resolve: _frame.resolveElement,
    );
    final hitIds = {
      for (final facts in candidates.facts)
        if (_hitTestPolicy.exactMarquee(marquee: rect, facts: facts)) facts.id,
    };

    return MarqueeCommitFacts(
      previousSelectedIds: _documentOrderIds(
        handles: context.handles,
        ids: context.selection.selectedElementIds,
      ),
      nextSelectedIds: _documentOrderIds(handles: context.handles, ids: hitIds),
      controllerEpoch: context.controllerEpoch,
      selectionRevision: context.selection.selectionRevision,
      rectWorld: rect,
      query: interactionQueryFacts(query, candidates),
    );
  }

  MarqueeCommitFacts _pointSelectionCommitFacts({
    required _InteractionReadContext context,
    required Rect rect,
  }) {
    final point = rect.center;
    final query = _spatial.queryHit(
      SpatialQueryWindow(
        boundsWorld: _pointQueryWindow(point),
        structuralRevision: context.structuralRevision,
      ),
    );
    final candidates = resolveInteractionCandidates(
      query,
      resolve: _frame.resolveElement,
    );
    final hitId = _hitTestPolicy.topmostHit(
      point: point,
      candidates: candidates.handles,
      resolve: _frame.resolveElement,
    );
    final hitIds = hitId == null ? const <CanvasElementId>[] : [hitId];

    return MarqueeCommitFacts(
      previousSelectedIds: _documentOrderIds(
        handles: context.handles,
        ids: context.selection.selectedElementIds,
      ),
      nextSelectedIds: _documentOrderIds(handles: context.handles, ids: hitIds),
      controllerEpoch: context.controllerEpoch,
      selectionRevision: context.selection.selectionRevision,
      rectWorld: rect,
      query: interactionQueryFacts(query, candidates),
    );
  }

  @override
  EraserReadFacts eraserPreviewFacts(EraserReadRequest request) {
    final budget = _hitTestPolicy.geometryPolicy.eraserPreviewBudgetInputs(
      request.corridorPoints.length,
    );

    return _eraserFacts(
      request,
      terminal: false,
      budget: (
        candidateLimit: budget.candidateLimit,
        exactCheckLimit: budget.exactCheckLimit,
      ),
    );
  }

  @override
  EraserReadFacts eraserTerminalFacts(EraserReadRequest request) {
    final budget = _hitTestPolicy.geometryPolicy.eraserTerminalBudgetInputs();

    return _eraserFacts(
      request,
      terminal: true,
      budget: (
        candidateLimit: budget.candidateLimit,
        exactCheckLimit: budget.exactCheckLimit,
      ),
    );
  }

  @override
  ContextTargetReadOutcome directContextTargetFacts(
    ContextTargetReadRequest request,
  ) {
    return _contextTargetFacts(request);
  }

  @override
  ContextTargetReadOutcome pendingContextTapFacts(
    ContextTargetReadRequest request,
  ) {
    return _contextTargetFacts(request);
  }

  @override
  ContextTargetReadOutcome secondContextTapFacts(
    ContextTargetReadRequest request,
  ) {
    return _contextTargetFacts(request);
  }

  @override
  TextCommitGuardReadFacts textCommitGuardFacts(
    TextCommitGuardReadRequest request,
  ) {
    final context = _readContext();
    final handle = _frame.elementHandleForId(
      context.structuralRevision,
      request.targetElementId,
    );
    final facts = handle == null ? null : _frame.resolveElement(handle);
    if (facts == null ||
        facts.locationKind != FrameElementLocationKind.content ||
        !facts.isVisible) {
      return TextCommitGuardReadFacts.missing(
        targetElementId: request.targetElementId,
        controllerEpoch: context.controllerEpoch,
        documentRevision: context.documentRevision,
      );
    }

    return TextCommitGuardReadFacts.current(
      targetElementId: request.targetElementId,
      targetKind: facts.kind,
      generation: facts.generation,
      elementRevision: facts.revision,
      controllerEpoch: context.controllerEpoch,
      documentRevision: context.documentRevision,
      currentText: interactionTextValue(facts),
    );
  }

  // Eraser reads need corridor normalization, spatial candidates, exact hits,
  // and budget branching in one snapshot so preview and terminal decisions
  // cannot observe different committed facts. Splitting those reads merely for
  // a metric would make that snapshot ownership less obvious.
  // ignore: halstead-volume, source-lines-of-code, maintainability-index
  EraserReadFacts _eraserFacts(
    EraserReadRequest request, {
    required _EraserExactBudget budget,
    required bool terminal,
  }) {
    if (terminal) {
      assert(
        _recordEraserEntryRouteWork(
          const RuntimeEraserEntryRouteWorkEvent(
            kind: RuntimeEraserEntryRouteWorkKind.terminalReadStarted,
          ),
        ),
        'eraser entry route work observation failed',
      );
    }
    final context = _eraserReadContext();
    final corridor = _hitTestPolicy.geometryPolicy.corridorEnvelope(
      points: request.corridorPoints,
      eraserThickness: request.eraserThickness,
      hitPadding: 0,
    );
    final query = _spatial.queryEraser(
      SpatialQueryWindow(
        boundsWorld: corridor.envelopeWorld,
        structuralRevision: context.structuralRevision,
      ),
    );
    final candidates = resolveInteractionCandidates(
      query,
      resolve: _frame.resolveElement,
    );
    final admittedCandidates = _eraserCandidates(candidates);
    final rawQueryFacts = interactionQueryFacts(query, candidates);
    final queryFacts =
        rawQueryFacts.status == InteractionReadQueryStatus.candidates
        ? InteractionReadQueryFacts.candidates(
            candidateCount: admittedCandidates.handles.length,
            skippedCandidateCount: candidates.skippedCandidateCount,
          )
        : rawQueryFacts;
    final snapshot = (
      terminal: terminal,
      corridorPoints: corridor.points,
      eraserThickness: request.eraserThickness,
      controllerEpoch: context.controllerEpoch,
      documentRevision: context.documentRevision,
      query: queryFacts,
    );
    if (!interactionQueryHasCandidates(query) ||
        admittedCandidates.handles.length > budget.candidateLimit) {
      return _finalizeEraserFacts(snapshot, (
        exactCheckCount: 0,
        exactBudgetExceeded:
            admittedCandidates.handles.length > budget.candidateLimit,
        exactHits: const <_EraserExactHit>[],
        projectTerminalEntries: false,
      ));
    }

    final exactHits = <_EraserExactHit>[];
    var exactChecks = 0;
    for (final facts in admittedCandidates.facts) {
      exactChecks += 1;
      if (exactChecks > budget.exactCheckLimit) {
        return _finalizeEraserFacts(snapshot, (
          exactCheckCount: exactChecks,
          exactBudgetExceeded: true,
          exactHits: const <_EraserExactHit>[],
          projectTerminalEntries: false,
        ));
      }
      if (_hitTestPolicy.exactEraserHit(corridor: corridor, facts: facts)) {
        exactHits.add(_EraserExactHit(facts.id, facts.orderToken));
      }
    }

    return _finalizeEraserFacts(snapshot, (
      exactCheckCount: exactChecks,
      exactBudgetExceeded: false,
      exactHits: exactHits,
      projectTerminalEntries: true,
    ));
  }

  EraserReadFacts _finalizeEraserFacts(
    _EraserFactsSnapshot snapshot,
    _EraserExactReadResult result,
  ) {
    if (!snapshot.terminal) {
      return EraserReadFacts.preview(
        corridorPoints: snapshot.corridorPoints,
        erasedElementIds: _orderedEraserIds(result.exactHits),
        eraserThickness: snapshot.eraserThickness,
        controllerEpoch: snapshot.controllerEpoch,
        documentRevision: snapshot.documentRevision,
        exactCheckCount: result.exactCheckCount,
        exactBudgetExceeded: result.exactBudgetExceeded,
        query: snapshot.query,
      );
    }
    final entries = result.projectTerminalEntries
        ? _terminalEraserEntries(
            List.unmodifiable(result.exactHits.map((hit) => hit.id)),
          )
        : const <DeletionEntryFacts>[];
    return EraserReadFacts.terminal(
      corridorPoints: snapshot.corridorPoints,
      erasedEntries: entries,
      eraserThickness: snapshot.eraserThickness,
      controllerEpoch: snapshot.controllerEpoch,
      documentRevision: snapshot.documentRevision,
      exactCheckCount: result.exactCheckCount,
      exactBudgetExceeded: result.exactBudgetExceeded,
      query: snapshot.query,
    );
  }

  List<CanvasElementId> _orderedEraserIds(List<_EraserExactHit> hits) {
    if (hits.length < 2) {
      return List.unmodifiable(hits.map((hit) => hit.id));
    }
    hits.sort((left, right) => left.orderToken.compareTo(right.orderToken));
    return List.unmodifiable(hits.map((hit) => hit.id));
  }

  List<DeletionEntryFacts> _terminalEraserEntries(
    List<CanvasElementId> exactHitIds,
  ) {
    assert(
      _recordEraserEntryRouteWork(
        RuntimeEraserEntryRouteWorkEvent(
          kind: RuntimeEraserEntryRouteWorkKind.exactHitIdsReady,
          exactHitIds: exactHitIds,
        ),
      ),
      'eraser entry route work observation failed',
    );
    final entries = _deletionEntryProjection.projectDeletionEntries(
      exactHitIds,
    );
    assert(
      _recordEraserEntryRouteWork(
        RuntimeEraserEntryRouteWorkEvent(
          kind: RuntimeEraserEntryRouteWorkKind.entriesReady,
          entries: entries,
        ),
      ),
      'eraser entry route work observation failed',
    );
    return entries;
  }

  RuntimeResolvedSpatialCandidates _eraserCandidates(
    RuntimeResolvedSpatialCandidates candidates,
  ) {
    final allowedKinds = _eraserElementKinds;
    if (allowedKinds == null) {
      return candidates;
    }

    final handles = <FrameElementHandle>[];
    final facts = <FrameElementFacts>[];
    for (var index = 0; index < candidates.facts.length; index += 1) {
      final factsAtIndex = candidates.facts[index];
      if (!allowedKinds.contains(factsAtIndex.kind)) {
        continue;
      }
      handles.add(candidates.handles[index]);
      facts.add(factsAtIndex);
    }

    return RuntimeResolvedSpatialCandidates(
      handles: List.unmodifiable(handles),
      facts: List.unmodifiable(facts),
      skippedCandidateCount: candidates.skippedCandidateCount,
    );
  }

  // Context target reads must atomically resolve topmost content, immutable
  // snapshot, bounds, generation, and observation revision for one request.
  // ignore: halstead-volume
  ContextTargetReadOutcome _contextTargetFacts(
    ContextTargetReadRequest request,
  ) {
    final context = _readContext();
    final query = _spatial.queryContext(
      SpatialQueryWindow(
        boundsWorld: _pointQueryWindow(request.worldPosition),
        structuralRevision: context.structuralRevision,
      ),
    );
    final candidates = resolveInteractionCandidates(
      query,
      resolve: _frame.resolveElement,
    );
    final queryFacts = interactionQueryFacts(query, candidates);
    if (!_hasReliableCandidateFacts(queryFacts)) {
      return RejectedContextTargetRead(query: queryFacts);
    }

    return _admittedContextTarget(
      request: request,
      context: context,
      candidates: candidates,
      queryFacts: queryFacts,
    );
  }

  ContextTargetReadOutcome _admittedContextTarget({
    required ContextTargetReadRequest request,
    required _InteractionReadContext context,
    required RuntimeResolvedSpatialCandidates candidates,
    required InteractionReadQueryFacts queryFacts,
  }) {
    final hitId = _hitTestPolicy.topmostContextHit(
      point: request.worldPosition,
      candidates: candidates.handles,
      resolve: _frame.resolveElement,
    );
    final hitFacts = hitId == null
        ? null
        : interactionFactsForId(candidates, hitId);
    if (hitFacts == null) {
      return AdmittedContextTargetRead(
        ContextTargetReadFacts.emptyCanvas(
          controllerEpoch: context.controllerEpoch,
          documentRevision: context.documentRevision,
          query: queryFacts,
        ),
      );
    }

    return AdmittedContextTargetRead(
      ContextTargetReadFacts.contentElement(
        elementId: hitFacts.id,
        elementKind: hitFacts.kind,
        elementSnapshot: interactionElementSnapshot(hitFacts),
        boundsWorld: _hitTestPolicy.geometryPolicy
            .boundsFor(hitFacts)
            .paintBoundsWorld,
        generation: hitFacts.generation,
        elementRevision: hitFacts.revision,
        controllerEpoch: context.controllerEpoch,
        documentRevision: context.documentRevision,
        query: queryFacts,
      ),
    );
  }

  _InteractionReadContext _readContext() {
    final structuralRevision = _frame.frameRevisions.structuralRevision;

    return _InteractionReadContext(
      controllerEpoch: _controllerEpoch(),
      documentRevision: _frame.frameRevisions.documentRevision,
      structuralRevision: structuralRevision,
      handles: _frame.elementHandles(structuralRevision),
      selection: _selection.selectionFacts,
    );
  }

  _EraserReadContext _eraserReadContext() {
    final revisions = _frame.frameRevisions;

    return _EraserReadContext(
      controllerEpoch: _controllerEpoch(),
      documentRevision: revisions.documentRevision,
      structuralRevision: revisions.structuralRevision,
    );
  }

  _SelectedMoveStartReadContext _selectedMoveStartReadContext() {
    final structuralRevision = _frame.frameRevisions.structuralRevision;

    return _SelectedMoveStartReadContext(
      controllerEpoch: _controllerEpoch(),
      structuralRevision: structuralRevision,
      selection: _selection.selectionFacts,
    );
  }

  List<CanvasElementId> _movableIds(
    _InteractionReadContext context,
    Iterable<CanvasElementId> ids,
  ) {
    final requestedIds = ids.toSet();

    return [
      for (final handle in context.handles)
        if (requestedIds.contains(handle.id) && _isMovable(handle)) handle.id,
    ];
  }

  List<FrameElementHandle> _selectedHandlesInDocumentOrder({
    required int structuralRevision,
    required Iterable<CanvasElementId> ids,
  }) {
    final handles = <FrameElementHandle>[];
    for (final id in ids) {
      final handle = _frame.elementHandleForId(structuralRevision, id);
      if (handle != null) {
        _insertHandleByOrder(handles, handle);
      }
    }

    return List.unmodifiable(handles);
  }

  List<CanvasElementId> _idsForHandles(Iterable<FrameElementHandle> handles) {
    return List.unmodifiable([for (final handle in handles) handle.id]);
  }

  List<CanvasElementId> _movableIdsFromHandles(
    Iterable<FrameElementHandle> handles,
  ) {
    return List.unmodifiable([
      for (final handle in handles)
        if (_isMovable(handle)) handle.id,
    ]);
  }

  bool _isMovable(FrameElementHandle handle) {
    final facts = _frame.resolveElement(handle);

    return facts != null &&
        facts.locationKind == FrameElementLocationKind.content &&
        facts.isVisible &&
        facts.isSelectable &&
        !facts.isLocked &&
        facts.isTransformable;
  }

  // Group union admission facts stay together because bounds, top order, and
  // occlusion are one invariant over the same selected handles.
  // ignore: halstead-volume
  _SelectedGroupMoveStartFacts _selectedGroupFacts({
    required List<FrameElementHandle> selectedHandles,
    required List<CanvasElementId> selectedIds,
    required Offset point,
    required _SelectedGroupOcclusionRead occlusion,
  }) {
    if (selectedIds.isEmpty) {
      return const _SelectedGroupMoveStartFacts.none();
    }
    final selected = selectedIds.toSet();
    final facts = [
      for (final handle in selectedHandles) _frame.resolveElement(handle),
    ].whereType<FrameElementFacts>().toList(growable: false);
    if (facts.isEmpty) {
      return const _SelectedGroupMoveStartFacts.none();
    }
    final topOrderToken = _topOrderToken(facts);
    if (facts.length < 2) {
      return _SelectedGroupMoveStartFacts(
        boundsWorld: null,
        topOrderToken: topOrderToken,
        insideUnion: false,
        occluded: false,
        occlusionReliable: occlusion.isReliable,
      );
    }
    final bounds = _unionPaintBounds(facts, policy: _hitTestPolicy);
    final insideUnion = _rectContainsPointInclusive(bounds, point);
    final topmostContentHit = occlusion.topmostContentHit;
    final occluded =
        insideUnion &&
        topmostContentHit != null &&
        topmostContentHit.orderToken > topOrderToken &&
        !selected.contains(topmostContentHit.id);

    return _SelectedGroupMoveStartFacts(
      boundsWorld: bounds,
      topOrderToken: topOrderToken,
      insideUnion: insideUnion,
      occluded: occluded,
      occlusionReliable: occlusion.isReliable,
    );
  }
}

typedef _SelectedGroupOcclusionRead = ({
  bool isReliable,
  HitTestResult? topmostContentHit,
});

bool _hasReliableCandidateFacts(InteractionReadQueryFacts query) {
  return query.status == InteractionReadQueryStatus.candidates &&
      query.skippedCandidateCount == 0;
}

typedef _EraserExactBudget = ({int candidateLimit, int exactCheckLimit});

typedef _EraserFactsSnapshot = ({
  bool terminal,
  List<Offset> corridorPoints,
  double eraserThickness,
  int controllerEpoch,
  int documentRevision,
  InteractionReadQueryFacts query,
});

typedef _EraserExactReadResult = ({
  int exactCheckCount,
  bool exactBudgetExceeded,
  List<_EraserExactHit> exactHits,
  bool projectTerminalEntries,
});

final class _EraserExactHit {
  const _EraserExactHit(this.id, this.orderToken);

  final CanvasElementId id;
  final int orderToken;
}

final class _EraserReadContext {
  const _EraserReadContext({
    required this.controllerEpoch,
    required this.documentRevision,
    required this.structuralRevision,
  });

  final int controllerEpoch;
  final int documentRevision;
  final int structuralRevision;
}

List<CanvasElementId> _documentOrderIds({
  required Iterable<FrameElementHandle> handles,
  required Iterable<CanvasElementId> ids,
}) {
  final allowed = ids.toSet();

  return List.unmodifiable([
    for (final handle in handles)
      if (allowed.contains(handle.id)) handle.id,
  ]);
}

Rect _pointQueryWindow(Offset point) {
  return Rect.fromCircle(center: point, radius: 0.5);
}

CanvasElementId? _movableHitId(FrameElementFacts? facts) {
  if (facts == null || facts.isLocked || !facts.isTransformable) {
    return null;
  }

  return facts.id;
}

bool _selectedMoveCommitSelectionIsCurrent(
  SelectionFacts selection,
  SelectedMoveCommitReadRequest request,
) {
  if (selection.selectionRevision == request.selectionRevision) {
    return true;
  }
  if (!request.provisionalSelectionReplacementApplied) {
    return false;
  }
  if (selection.selectionRevision !=
      request.provisionalSelectionReplacementRevision) {
    return false;
  }

  return _sameIdSet(selection.selectedElementIds, request.sessionSelectedIds);
}

bool _sameIdSet(
  Iterable<CanvasElementId> left,
  Iterable<CanvasElementId> right,
) {
  final leftSet = left.toSet();
  final rightSet = right.toSet();

  return leftSet.length == rightSet.length && leftSet.containsAll(rightSet);
}

void _insertHandleByOrder(
  List<FrameElementHandle> ordered,
  FrameElementHandle handle,
) {
  for (var index = 0; index < ordered.length; index += 1) {
    if (handle.orderToken < ordered[index].orderToken) {
      ordered.insert(index, handle);

      return;
    }
  }
  ordered.add(handle);
}

Rect _normalizeRect(Rect rect) {
  return Rect.fromLTRB(
    rect.left < rect.right ? rect.left : rect.right,
    rect.top < rect.bottom ? rect.top : rect.bottom,
    rect.left < rect.right ? rect.right : rect.left,
    rect.top < rect.bottom ? rect.bottom : rect.top,
  );
}

Rect _unionPaintBounds(
  List<FrameElementFacts> facts, {
  required HitTestPolicy policy,
}) {
  final geometry = policy.geometryPolicy;
  var bounds = geometry.boundsFor(facts.first).paintBoundsWorld;
  for (final row in facts.skip(1)) {
    bounds = bounds.expandToInclude(geometry.boundsFor(row).paintBoundsWorld);
  }

  return bounds;
}

int _topOrderToken(List<FrameElementFacts> facts) {
  var topOrderToken = facts.first.orderToken;
  for (final row in facts.skip(1)) {
    if (row.orderToken > topOrderToken) {
      topOrderToken = row.orderToken;
    }
  }

  return topOrderToken;
}

bool _rectContainsPointInclusive(Rect rect, Offset point) {
  return point.dx >= rect.left &&
      point.dx <= rect.right &&
      point.dy >= rect.top &&
      point.dy <= rect.bottom;
}

final class _SelectedGroupMoveStartFacts {
  const _SelectedGroupMoveStartFacts({
    required this.boundsWorld,
    required this.topOrderToken,
    required this.insideUnion,
    required this.occluded,
    required this.occlusionReliable,
  });

  const _SelectedGroupMoveStartFacts.none()
    : boundsWorld = null,
      topOrderToken = null,
      insideUnion = false,
      occluded = false,
      occlusionReliable = false;

  final Rect? boundsWorld;
  final int? topOrderToken;
  final bool insideUnion;
  final bool occluded;
  final bool occlusionReliable;
}

final class _SelectedMoveStartReadContext {
  const _SelectedMoveStartReadContext({
    required this.controllerEpoch,
    required this.structuralRevision,
    required this.selection,
  });

  final int controllerEpoch;
  final int structuralRevision;
  final SelectionFacts selection;
}

final class _InteractionReadContext {
  const _InteractionReadContext({
    required this.controllerEpoch,
    required this.documentRevision,
    required this.structuralRevision,
    required this.handles,
    required this.selection,
  });

  final int controllerEpoch;
  final int documentRevision;
  final int structuralRevision;
  final List<FrameElementHandle> handles;
  final SelectionFacts selection;
}
