import 'dart:ui';

import '../contracts/internal/frame_facts_port.dart';
import '../contracts/internal/selection_facts_port.dart';
import '../contracts/public/canvas_ids.dart';
import '../geometry/hit_test_policy.dart';
import '../geometry/spatial_kernel.dart';
import '../geometry/spatial_query_policy.dart';
import '../interaction/interaction_read_port.dart';
import 'runtime_interaction_read_mapping.dart';
import 'runtime_interaction_move_read_models.dart';

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
    HitTestPolicy hitTestPolicy = const HitTestPolicy(),
  }) : _frame = frame,
       _documentSummary = documentSummary,
       _selection = selection,
       _spatial = spatial,
       _controllerEpoch = controllerEpoch,
       _hitTestPolicy = hitTestPolicy;

  final FrameFactsPort _frame;
  final RuntimeDocumentSummaryReader _documentSummary;
  final SelectionFactsPort _selection;
  final SpatialKernel _spatial;
  final int Function() _controllerEpoch;
  final HitTestPolicy _hitTestPolicy;

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
          context.selection.selectionRevision == request.selectionRevision &&
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
      family: interactionElementFamily(facts),
      controllerEpoch: context.controllerEpoch,
      documentRevision: context.documentRevision,
      currentText: interactionTextValue(facts),
    );
  }

  // Eraser reads need corridor normalization, spatial candidates, exact hits,
  // and budget branching in one snapshot so preview and terminal decisions
  // cannot observe different committed facts.
  // ignore: halstead-volume, source-lines-of-code
  EraserReadFacts _eraserFacts(
    EraserReadRequest request, {
    required _EraserExactBudget budget,
  }) {
    final context = _readContext();
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
    final queryFacts = interactionQueryFacts(query, candidates);
    if (!interactionQueryHasCandidates(query) ||
        candidates.handles.length > budget.candidateLimit) {
      return EraserReadFacts(
        corridorPoints: corridor.points,
        erasedElementIds: const [],
        eraserThickness: request.eraserThickness,
        controllerEpoch: context.controllerEpoch,
        documentRevision: context.documentRevision,
        exactCheckCount: 0,
        exactBudgetExceeded: interactionQueryHasCandidates(query),
        query: queryFacts,
      );
    }

    final erasedIds = <CanvasElementId>[];
    var exactChecks = 0;
    for (final facts in candidates.facts) {
      exactChecks += 1;
      if (exactChecks > budget.exactCheckLimit) {
        return EraserReadFacts(
          corridorPoints: corridor.points,
          erasedElementIds: const [],
          eraserThickness: request.eraserThickness,
          controllerEpoch: context.controllerEpoch,
          documentRevision: context.documentRevision,
          exactCheckCount: exactChecks,
          exactBudgetExceeded: true,
          query: queryFacts,
        );
      }
      if (_hitTestPolicy.exactEraserHit(corridor: corridor, facts: facts)) {
        erasedIds.add(facts.id);
      }
    }

    return EraserReadFacts(
      corridorPoints: corridor.points,
      erasedElementIds: _documentOrderIds(
        handles: context.handles,
        ids: erasedIds,
      ),
      eraserThickness: request.eraserThickness,
      controllerEpoch: context.controllerEpoch,
      documentRevision: context.documentRevision,
      exactCheckCount: exactChecks,
      exactBudgetExceeded: false,
      query: queryFacts,
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
    if (!interactionQueryHasCandidates(query)) {
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
        family: interactionElementFamily(hitFacts),
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
