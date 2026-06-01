import 'dart:ui';

import '../contracts/public/canvas_actions.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_ids.dart';

abstract interface class InteractionReadPort {
  SelectedMoveStartFacts selectedMoveStartFacts(
    SelectedMoveStartReadRequest request,
  );

  SelectedMoveCommitFacts selectedMoveCommitFacts(
    SelectedMoveCommitReadRequest request,
  );

  MarqueeStartFacts marqueeStartFacts(MarqueeStartReadRequest request);

  MarqueeCommitFacts marqueeCommitFacts(MarqueeCommitReadRequest request);
}

final class SelectedMoveStartReadRequest {
  const SelectedMoveStartReadRequest({required this.worldPosition});

  final Offset worldPosition;
}

final class SelectedMoveStartFacts {
  SelectedMoveStartFacts({
    required Iterable<CanvasElementId> selectedIds,
    required Iterable<CanvasElementId> movableSelectedIds,
    required this.controllerEpoch,
    required this.selectionRevision,
    required this.hitSelectedMovable,
    this.query = const InteractionReadQueryFacts.notRun(),
  }) : selectedIds = List.unmodifiable(selectedIds),
       movableSelectedIds = List.unmodifiable(movableSelectedIds);

  final List<CanvasElementId> selectedIds;
  final List<CanvasElementId> movableSelectedIds;
  final int controllerEpoch;
  final int selectionRevision;
  final bool hitSelectedMovable;
  final InteractionReadQueryFacts query;
}

final class SelectedMoveCommitReadRequest {
  SelectedMoveCommitReadRequest({
    required Iterable<CanvasElementId> sessionSelectedIds,
    required Iterable<CanvasElementId> sessionMovableIds,
    required this.selectionRevision,
  }) : sessionSelectedIds = List.unmodifiable(sessionSelectedIds),
       sessionMovableIds = List.unmodifiable(sessionMovableIds);

  final List<CanvasElementId> sessionSelectedIds;
  final List<CanvasElementId> sessionMovableIds;
  final int selectionRevision;
}

final class SelectedMoveCommitFacts {
  SelectedMoveCommitFacts({
    required Iterable<CanvasElementId> movableIds,
    required Iterable<CanvasElementRead> movedElements,
    required this.documentSummary,
    required this.selectionBoundsWorld,
    required this.controllerEpoch,
    required this.selectionRevision,
    required this.hasDocumentChangesAvailable,
    Iterable<CanvasElementId> skippedSessionIds = const [],
  }) : movableIds = List.unmodifiable(movableIds),
       movedElements = List.unmodifiable(movedElements),
       _skippedSessionIds = List.unmodifiable(skippedSessionIds);

  final List<CanvasElementId> movableIds;
  final List<CanvasElementRead> movedElements;
  final CanvasDocumentSummary documentSummary;
  final Rect selectionBoundsWorld;
  final int controllerEpoch;
  final int selectionRevision;
  final bool hasDocumentChangesAvailable;
  final List<CanvasElementId> _skippedSessionIds;
  List<CanvasElementId> get skippedSessionIds => _skippedSessionIds;
}

final class MarqueeStartReadRequest {
  const MarqueeStartReadRequest();
}

final class MarqueeStartFacts {
  MarqueeStartFacts({
    required Iterable<CanvasElementId> previousSelectedIds,
    required this.controllerEpoch,
    required this.selectionRevision,
  }) : previousSelectedIds = List.unmodifiable(previousSelectedIds);

  final List<CanvasElementId> previousSelectedIds;
  final int controllerEpoch;
  final int selectionRevision;
}

final class MarqueeCommitReadRequest {
  const MarqueeCommitReadRequest({required this.rectWorld});

  final Rect rectWorld;
}

final class MarqueeCommitFacts {
  MarqueeCommitFacts({
    required Iterable<CanvasElementId> previousSelectedIds,
    required Iterable<CanvasElementId> nextSelectedIds,
    required this.controllerEpoch,
    required this.selectionRevision,
    required this.rectWorld,
    this.query = const InteractionReadQueryFacts.notRun(),
  }) : previousSelectedIds = List.unmodifiable(previousSelectedIds),
       nextSelectedIds = List.unmodifiable(nextSelectedIds);

  final List<CanvasElementId> previousSelectedIds;
  final List<CanvasElementId> nextSelectedIds;
  final int controllerEpoch;
  final int selectionRevision;
  final Rect rectWorld;
  final InteractionReadQueryFacts query;
}

enum InteractionReadQueryStatus {
  notRun,
  candidates,
  invalidIndex,
  staleIndex,
  budgetExceeded,
}

final class InteractionReadQueryFacts {
  const InteractionReadQueryFacts.notRun()
    : status = InteractionReadQueryStatus.notRun,
      candidateCount = 0,
      skippedCandidateCount = 0,
      budgetExceededReason = null,
      budget = null,
      observed = null,
      invalidIndexReason = null,
      expectedStructuralRevision = null,
      observedStructuralRevision = null;

  const InteractionReadQueryFacts.candidates({
    required this.candidateCount,
    required this.skippedCandidateCount,
  }) : status = InteractionReadQueryStatus.candidates,
       budgetExceededReason = null,
       budget = null,
       observed = null,
       invalidIndexReason = null,
       expectedStructuralRevision = null,
       observedStructuralRevision = null;

  const InteractionReadQueryFacts.invalidIndex({
    required this.invalidIndexReason,
  }) : status = InteractionReadQueryStatus.invalidIndex,
       candidateCount = 0,
       skippedCandidateCount = 0,
       budgetExceededReason = null,
       budget = null,
       observed = null,
       expectedStructuralRevision = null,
       observedStructuralRevision = null;

  const InteractionReadQueryFacts.staleIndex({
    required this.expectedStructuralRevision,
    required this.observedStructuralRevision,
  }) : status = InteractionReadQueryStatus.staleIndex,
       candidateCount = 0,
       skippedCandidateCount = 0,
       budgetExceededReason = null,
       budget = null,
       observed = null,
       invalidIndexReason = null;

  const InteractionReadQueryFacts.budgetExceeded({
    required this.budgetExceededReason,
    required this.budget,
    required this.observed,
  }) : status = InteractionReadQueryStatus.budgetExceeded,
       candidateCount = 0,
       skippedCandidateCount = 0,
       invalidIndexReason = null,
       expectedStructuralRevision = null,
       observedStructuralRevision = null;

  final InteractionReadQueryStatus status;
  final int candidateCount;
  final int skippedCandidateCount;
  final InteractionReadBudgetExceededReason? budgetExceededReason;
  final int? budget;
  final int? observed;
  final InteractionReadInvalidIndexReason? invalidIndexReason;
  final int? expectedStructuralRevision;
  final int? observedStructuralRevision;
}

enum InteractionReadBudgetExceededReason {
  queryTileBudgetExceeded,
  fallbackCandidateBudgetExceeded,
}

enum InteractionReadInvalidIndexReason { rebuildNeeded, failedUpdate }
