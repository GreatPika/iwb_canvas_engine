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
  SelectedMoveStartFacts selectedMoveStartFacts(
    SelectedMoveStartReadRequest request,
  ) {
    final context = _readContext();
    final selectedIds = _documentOrderIds(
      handles: context.handles,
      ids: context.selection.selectedElementIds,
    );
    final movableIds = _movableIds(context, selectedIds);
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
    final hitId = _hitTestPolicy.topmostHit(
      point: request.worldPosition,
      candidates: candidates.handles,
      resolve: _frame.resolveElement,
    );

    return SelectedMoveStartFacts(
      selectedIds: selectedIds,
      movableSelectedIds: movableIds,
      controllerEpoch: context.controllerEpoch,
      selectionRevision: context.selection.selectionRevision,
      hitSelectedMovable: hitId != null && movableIds.contains(hitId),
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

  bool _isMovable(FrameElementHandle handle) {
    final facts = _frame.resolveElement(handle);

    return facts != null &&
        facts.locationKind == FrameElementLocationKind.content &&
        facts.isVisible &&
        facts.isSelectable &&
        !facts.isLocked &&
        facts.isTransformable;
  }
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

Rect _normalizeRect(Rect rect) {
  return Rect.fromLTRB(
    rect.left < rect.right ? rect.left : rect.right,
    rect.top < rect.bottom ? rect.top : rect.bottom,
    rect.left < rect.right ? rect.right : rect.left,
    rect.top < rect.bottom ? rect.bottom : rect.top,
  );
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
