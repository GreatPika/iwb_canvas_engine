import 'dart:ui';

import '../contracts/internal/frame_facts_port.dart';
import '../contracts/internal/selection_facts_port.dart';
import '../contracts/public/canvas_ids.dart';
import '../geometry/hit_test_policy.dart';
import '../geometry/spatial_kernel.dart';
import '../geometry/spatial_query_policy.dart';
import '../geometry/spatial_query_result.dart';
import '../interaction/interaction_read_port.dart';

// The runtime read adapter intentionally names each read collaborator so the
// interaction owner receives one immutable fact seam without hiding ownership
// boundaries behind metric-only wrapper files.
// ignore: coupling-between-object-classes
final class RuntimeInteractionReadAdapter implements InteractionReadPort {
  const RuntimeInteractionReadAdapter({
    required FrameFactsPort frame,
    required SelectionFactsPort selection,
    required SpatialKernel spatial,
    required int Function() controllerEpoch,
    HitTestPolicy hitTestPolicy = const HitTestPolicy(),
  }) : _frame = frame,
       _selection = selection,
       _spatial = spatial,
       _controllerEpoch = controllerEpoch,
       _hitTestPolicy = hitTestPolicy;

  final FrameFactsPort _frame;
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
    final skippedIds = request.sessionMovableIds
        .where((id) => !movableIds.contains(id))
        .toList(growable: false);

    return SelectedMoveCommitFacts(
      movableIds: movableIds,
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

  _InteractionReadContext _readContext() {
    final structuralRevision = _frame.frameRevisions.structuralRevision;

    return _InteractionReadContext(
      controllerEpoch: _controllerEpoch(),
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
    required this.structuralRevision,
    required this.handles,
    required this.selection,
  });

  final int controllerEpoch;
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
