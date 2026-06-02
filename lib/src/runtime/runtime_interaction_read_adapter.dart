import 'dart:ui';

import '../contracts/internal/frame_facts_port.dart';
import '../contracts/internal/selection_facts_port.dart';
import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_ids.dart';
import '../geometry/geometry_policy.dart';
import '../geometry/hit_test_policy.dart';
import '../geometry/spatial_kernel.dart';
import '../geometry/spatial_query_policy.dart';
import '../geometry/spatial_query_result.dart';
import '../interaction/interaction_read_port.dart';
import 'runtime_interaction_move_read_models.dart';

// The runtime read adapter intentionally names each read collaborator so the
// interaction owner receives one immutable fact seam without hiding ownership
// boundaries behind metric-only wrapper files.
// ignore: coupling-between-object-classes
final class RuntimeInteractionReadAdapter implements InteractionReadPort {
  const RuntimeInteractionReadAdapter({
    required FrameFactsPort frame,
    required RuntimeDocumentSummaryReader documentSummary,
    required SelectionFactsPort selection,
    required SpatialKernel spatial,
    required int Function() controllerEpoch,
    GeometryPolicy geometryPolicy = const GeometryPolicy(),
    HitTestPolicy hitTestPolicy = const HitTestPolicy(),
  }) : _frame = frame,
       _documentSummary = documentSummary,
       _selection = selection,
       _spatial = spatial,
       _controllerEpoch = controllerEpoch,
       _geometryPolicy = geometryPolicy,
       _hitTestPolicy = hitTestPolicy;

  final FrameFactsPort _frame;
  final RuntimeDocumentSummaryReader _documentSummary;
  final SelectionFactsPort _selection;
  final SpatialKernel _spatial;
  final int Function() _controllerEpoch;
  final GeometryPolicy _geometryPolicy;
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
    final candidates = _resolvedCandidates(query);
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
      query: _queryFacts(query, candidates),
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
    final candidates = _resolvedCandidates(query);
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
      query: _queryFacts(query, candidates),
    );
  }

  @override
  EraserReadFacts eraserPreviewFacts(EraserReadRequest request) {
    return _eraserFacts(
      request,
      budget: _geometryPolicy.eraserPreviewBudgetInputs(
        request.corridorPoints.length,
      ),
    );
  }

  @override
  EraserReadFacts eraserTerminalFacts(EraserReadRequest request) {
    return _eraserFacts(
      request,
      budget: _geometryPolicy.eraserTerminalBudgetInputs(),
    );
  }

  @override
  ContextTargetReadFacts directContextTargetFacts(
    ContextTargetReadRequest request,
  ) {
    return _contextTargetFacts(request);
  }

  @override
  ContextTargetReadFacts pendingContextTapFacts(
    ContextTargetReadRequest request,
  ) {
    return _contextTargetFacts(request);
  }

  @override
  ContextTargetReadFacts secondContextTapFacts(
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
      family: _elementFamily(facts.kind),
      controllerEpoch: context.controllerEpoch,
      documentRevision: context.documentRevision,
      currentText: facts.kind == CanvasElementKind.text ? facts.text : null,
    );
  }

  EraserReadFacts _eraserFacts(
    EraserReadRequest request, {
    required EraserExactBudgetInputs budget,
  }) {
    final context = _readContext();
    final corridor = _geometryPolicy.corridorEnvelope(
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
    final candidates = _resolvedCandidates(query);
    final queryFacts = _queryFacts(query, candidates);
    if (query is! SpatialCandidatesResult ||
        candidates.handles.length > budget.candidateLimit) {
      return EraserReadFacts(
        corridorPoints: corridor.points,
        erasedElementIds: const [],
        eraserThickness: request.eraserThickness,
        controllerEpoch: context.controllerEpoch,
        documentRevision: context.documentRevision,
        exactCheckCount: 0,
        exactBudgetExceeded: query is SpatialCandidatesResult,
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

  ContextTargetReadFacts _contextTargetFacts(ContextTargetReadRequest request) {
    final context = _readContext();
    final query = _spatial.queryEraser(
      SpatialQueryWindow(
        boundsWorld: _pointQueryWindow(request.worldPosition),
        structuralRevision: context.structuralRevision,
      ),
    );
    final candidates = _resolvedCandidates(query);
    final hitId = _hitTestPolicy.topmostContextHit(
      point: request.worldPosition,
      candidates: candidates.handles,
      resolve: _frame.resolveElement,
    );
    final hitFacts = hitId == null ? null : _factsForId(candidates, hitId);
    if (hitFacts == null) {
      return ContextTargetReadFacts.emptyCanvas(
        controllerEpoch: context.controllerEpoch,
        documentRevision: context.documentRevision,
        query: _queryFacts(query, candidates),
      );
    }

    return ContextTargetReadFacts.contentElement(
      elementId: hitFacts.id,
      elementKind: hitFacts.kind,
      elementSnapshot: _elementSnapshot(hitFacts),
      boundsWorld: _geometryPolicy.boundsFor(hitFacts).paintBoundsWorld,
      generation: hitFacts.generation,
      elementRevision: hitFacts.revision,
      family: _elementFamily(hitFacts.kind),
      controllerEpoch: context.controllerEpoch,
      documentRevision: context.documentRevision,
      query: _queryFacts(query, candidates),
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

  _ResolvedSpatialCandidates _resolvedCandidates(SpatialQueryResult query) {
    if (query is! SpatialCandidatesResult) {
      return const _ResolvedSpatialCandidates();
    }
    final handles = <FrameElementHandle>[];
    final facts = <FrameElementFacts>[];
    var skipped = 0;
    for (final handle in query.orderedCandidates) {
      final resolved = _frame.resolveElement(handle);
      if (resolved == null) {
        skipped += 1;
        continue;
      }
      handles.add(handle);
      facts.add(resolved);
    }

    return _ResolvedSpatialCandidates(
      handles: List.unmodifiable(handles),
      facts: List.unmodifiable(facts),
      skippedCandidateCount: skipped,
    );
  }
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

Rect _normalizeRect(Rect rect) {
  return Rect.fromLTRB(
    rect.left < rect.right ? rect.left : rect.right,
    rect.top < rect.bottom ? rect.top : rect.bottom,
    rect.left < rect.right ? rect.right : rect.left,
    rect.top < rect.bottom ? rect.bottom : rect.top,
  );
}

InteractionReadQueryFacts _queryFacts(
  SpatialQueryResult query,
  _ResolvedSpatialCandidates candidates,
) {
  return switch (query) {
    SpatialCandidatesResult(:final orderedCandidates) =>
      InteractionReadQueryFacts.candidates(
        candidateCount: orderedCandidates.length,
        skippedCandidateCount: candidates.skippedCandidateCount,
      ),
    SpatialInvalidIndexResult(:final reason) =>
      InteractionReadQueryFacts.invalidIndex(
        invalidIndexReason: _invalidIndexReason(reason),
      ),
    SpatialStaleCandidateResult(
      :final expectedStructuralRevision,
      :final observedStructuralRevision,
    ) =>
      InteractionReadQueryFacts.staleIndex(
        expectedStructuralRevision: expectedStructuralRevision,
        observedStructuralRevision: observedStructuralRevision,
      ),
    SpatialBudgetExceededResult(
      :final reason,
      :final budget,
      :final observed,
    ) =>
      InteractionReadQueryFacts.budgetExceeded(
        budgetExceededReason: _budgetExceededReason(reason),
        budget: budget,
        observed: observed,
      ),
  };
}

InteractionReadInvalidIndexReason _invalidIndexReason(
  SpatialInvalidIndexReason reason,
) {
  return switch (reason) {
    SpatialInvalidIndexReason.rebuildNeeded =>
      InteractionReadInvalidIndexReason.rebuildNeeded,
    SpatialInvalidIndexReason.failedUpdate =>
      InteractionReadInvalidIndexReason.failedUpdate,
  };
}

InteractionReadBudgetExceededReason _budgetExceededReason(
  SpatialBudgetExceededReason reason,
) {
  return switch (reason) {
    SpatialBudgetExceededReason.queryTileBudgetExceeded =>
      InteractionReadBudgetExceededReason.queryTileBudgetExceeded,
    SpatialBudgetExceededReason.fallbackCandidateBudgetExceeded =>
      InteractionReadBudgetExceededReason.fallbackCandidateBudgetExceeded,
  };
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

final class _ResolvedSpatialCandidates {
  const _ResolvedSpatialCandidates({
    this.handles = const [],
    this.facts = const [],
    this.skippedCandidateCount = 0,
  });

  final List<FrameElementHandle> handles;
  final List<FrameElementFacts> facts;
  final int skippedCandidateCount;
}

FrameElementFacts? _factsForId(
  _ResolvedSpatialCandidates candidates,
  CanvasElementId id,
) {
  for (final facts in candidates.facts) {
    if (facts.id == id) {
      return facts;
    }
  }

  return null;
}

InteractionElementFamily _elementFamily(CanvasElementKind kind) {
  return switch (kind) {
    CanvasElementKind.image => InteractionElementFamily.image,
    CanvasElementKind.path => InteractionElementFamily.path,
    CanvasElementKind.text => InteractionElementFamily.text,
    CanvasElementKind.stroke => InteractionElementFamily.stroke,
    CanvasElementKind.line => InteractionElementFamily.line,
    CanvasElementKind.rect => InteractionElementFamily.rect,
  };
}

// Reconstructing the immutable public snapshot here keeps context requests on
// the frame/read boundary instead of exposing a full document projection.
// ignore: cyclomatic-complexity
CanvasElement _elementSnapshot(FrameElementFacts facts) {
  return switch (facts.kind) {
    CanvasElementKind.image => CanvasImageElement(
      id: facts.id,
      resourceId: _requiredFact(facts.resourceId, facts, 'resourceId'),
      size: _requiredFact(facts.size, facts, 'size'),
      naturalSize: facts.naturalSize,
      revision: facts.revision,
      transform: facts.transform,
      opacity: facts.opacity,
      hitPadding: facts.hitPadding,
      isVisible: facts.isVisible,
      isSelectable: facts.isSelectable,
      isLocked: facts.isLocked,
      isDeletable: facts.isDeletable,
      isTransformable: facts.isTransformable,
      metadata: facts.metadata,
    ),
    CanvasElementKind.path => CanvasPathElement(
      id: facts.id,
      svgPathData: _requiredFact(facts.svgPathData, facts, 'svgPathData'),
      fillColor: facts.fillColor,
      strokeColor: facts.strokeColor,
      strokeWidth: facts.strokeWidth ?? 0,
      fillRule: facts.fillRule ?? CanvasPathFillRule.nonZero,
      revision: facts.revision,
      transform: facts.transform,
      opacity: facts.opacity,
      hitPadding: facts.hitPadding,
      isVisible: facts.isVisible,
      isSelectable: facts.isSelectable,
      isLocked: facts.isLocked,
      isDeletable: facts.isDeletable,
      isTransformable: facts.isTransformable,
      metadata: facts.metadata,
    ),
    CanvasElementKind.text => CanvasTextElement(
      id: facts.id,
      text: _requiredFact(facts.text, facts, 'text'),
      color: facts.textColor ?? const Color(0xFF000000),
      textDirection: facts.textDirection ?? TextDirection.ltr,
      fontSize: facts.fontSize ?? 24,
      align: facts.textAlign ?? TextAlign.left,
      isBold: facts.isBold ?? false,
      isItalic: facts.isItalic ?? false,
      isUnderline: facts.isUnderline ?? false,
      fontFamily: facts.fontFamily,
      maxWidth: facts.maxWidth,
      lineHeight: facts.lineHeight,
      revision: facts.revision,
      transform: facts.transform,
      opacity: facts.opacity,
      hitPadding: facts.hitPadding,
      isVisible: facts.isVisible,
      isSelectable: facts.isSelectable,
      isLocked: facts.isLocked,
      isDeletable: facts.isDeletable,
      isTransformable: facts.isTransformable,
      metadata: facts.metadata,
    ),
    CanvasElementKind.stroke => CanvasStrokeElement(
      id: facts.id,
      points: facts.points,
      thickness: _requiredFact(facts.thickness, facts, 'thickness'),
      color: facts.color ?? const Color(0xFF000000),
      revision: facts.revision,
      transform: facts.transform,
      opacity: facts.opacity,
      hitPadding: facts.hitPadding,
      isVisible: facts.isVisible,
      isSelectable: facts.isSelectable,
      isLocked: facts.isLocked,
      isDeletable: facts.isDeletable,
      isTransformable: facts.isTransformable,
      metadata: facts.metadata,
    ),
    CanvasElementKind.line => CanvasLineElement(
      id: facts.id,
      start: _requiredFact(facts.start, facts, 'start'),
      end: _requiredFact(facts.end, facts, 'end'),
      thickness: _requiredFact(facts.thickness, facts, 'thickness'),
      color: facts.color ?? const Color(0xFF000000),
      revision: facts.revision,
      transform: facts.transform,
      opacity: facts.opacity,
      hitPadding: facts.hitPadding,
      isVisible: facts.isVisible,
      isSelectable: facts.isSelectable,
      isLocked: facts.isLocked,
      isDeletable: facts.isDeletable,
      isTransformable: facts.isTransformable,
      metadata: facts.metadata,
    ),
    CanvasElementKind.rect => CanvasRectElement(
      id: facts.id,
      size: _requiredFact(facts.size, facts, 'size'),
      fillColor: facts.fillColor,
      strokeColor: facts.strokeColor,
      strokeWidth: facts.strokeWidth ?? 0,
      revision: facts.revision,
      transform: facts.transform,
      opacity: facts.opacity,
      hitPadding: facts.hitPadding,
      isVisible: facts.isVisible,
      isSelectable: facts.isSelectable,
      isLocked: facts.isLocked,
      isDeletable: facts.isDeletable,
      isTransformable: facts.isTransformable,
      metadata: facts.metadata,
    ),
  };
}

T _requiredFact<T>(T? value, FrameElementFacts facts, String field) {
  if (value == null) {
    throw StateError(
      'Missing $field for ${facts.kind.name} element ${facts.id.value}.',
    );
  }

  return value;
}
