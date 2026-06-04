import 'dart:ui';

import '../contracts/public/canvas_actions.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_element.dart';
import '../contracts/public/canvas_ids.dart';

// The interaction read port is the single immutable fact boundary for pointer
// decisions; splitting it by tool would let active gesture owners reassemble
// committed facts piecemeal.
// ignore: coupling-between-object-classes
abstract interface class InteractionReadPort {
  SelectedMoveStartFacts selectedMoveStartFacts(
    SelectedMoveStartReadRequest request,
  );

  SelectedMoveCommitFacts selectedMoveCommitFacts(
    SelectedMoveCommitReadRequest request,
  );

  MarqueeStartFacts marqueeStartFacts(MarqueeStartReadRequest request);

  MarqueeCommitFacts marqueeCommitFacts(MarqueeCommitReadRequest request);

  EraserReadFacts eraserPreviewFacts(EraserReadRequest request);

  EraserReadFacts eraserTerminalFacts(EraserReadRequest request);

  ContextTargetReadOutcome directContextTargetFacts(
    ContextTargetReadRequest request,
  );

  ContextTargetReadOutcome pendingContextTapFacts(
    ContextTargetReadRequest request,
  );

  ContextTargetReadOutcome secondContextTapFacts(
    ContextTargetReadRequest request,
  );

  TextCommitGuardReadFacts textCommitGuardFacts(
    TextCommitGuardReadRequest request,
  );
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
    this.topmostHitId,
    this.topmostHitOrderToken,
    this.selectedGroupBoundsWorld,
    this.selectedTopOrderToken,
    this.insideSelectedGroupUnion = false,
    this.groupUnionOccludedByHigherOrderHit = false,
    this.query = const InteractionReadQueryFacts.notRun(),
  }) : selectedIds = List.unmodifiable(selectedIds),
       movableSelectedIds = List.unmodifiable(movableSelectedIds);

  final List<CanvasElementId> selectedIds;
  final List<CanvasElementId> movableSelectedIds;
  final int controllerEpoch;
  final int selectionRevision;
  final bool hitSelectedMovable;
  final CanvasElementId? topmostHitId;
  final int? topmostHitOrderToken;
  final Rect? selectedGroupBoundsWorld;
  final int? selectedTopOrderToken;
  final bool insideSelectedGroupUnion;
  final bool groupUnionOccludedByHigherOrderHit;
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

final class EraserReadRequest {
  EraserReadRequest({
    required Iterable<Offset> corridorPoints,
    required this.eraserThickness,
  }) : corridorPoints = List.unmodifiable(corridorPoints);

  final List<Offset> corridorPoints;
  final double eraserThickness;
}

final class EraserReadFacts {
  EraserReadFacts({
    required Iterable<Offset> corridorPoints,
    required Iterable<CanvasElementId> erasedElementIds,
    required this.eraserThickness,
    required this.controllerEpoch,
    required this.documentRevision,
    required this.exactCheckCount,
    required this.exactBudgetExceeded,
    this.query = const InteractionReadQueryFacts.notRun(),
  }) : corridorPoints = List.unmodifiable(corridorPoints),
       erasedElementIds = List.unmodifiable(erasedElementIds);

  final List<Offset> corridorPoints;
  final List<CanvasElementId> erasedElementIds;
  final double eraserThickness;
  final int controllerEpoch;
  final int documentRevision;
  final int exactCheckCount;
  final bool exactBudgetExceeded;
  final InteractionReadQueryFacts query;
}

final class ContextTargetReadRequest {
  const ContextTargetReadRequest({required this.worldPosition});

  final Offset worldPosition;
}

sealed class ContextTargetReadOutcome {
  const ContextTargetReadOutcome();

  InteractionReadQueryFacts get query;
}

final class AdmittedContextTargetRead extends ContextTargetReadOutcome {
  const AdmittedContextTargetRead(this.facts);

  final ContextTargetReadFacts facts;

  @override
  InteractionReadQueryFacts get query => facts.query;
}

final class RejectedContextTargetRead extends ContextTargetReadOutcome {
  const RejectedContextTargetRead({required this.query});

  @override
  final InteractionReadQueryFacts query;
}

enum ContextActionReadTargetKind { contentElement, emptyCanvas }

enum InteractionElementFamily { image, path, text, stroke, line, rect }

final class ContextTargetReadFacts {
  const ContextTargetReadFacts.emptyCanvas({
    required this.controllerEpoch,
    required this.documentRevision,
    this.query = const InteractionReadQueryFacts.notRun(),
  }) : kind = ContextActionReadTargetKind.emptyCanvas,
       elementId = null,
       elementKind = null,
       elementSnapshot = null,
       boundsWorld = null,
       generation = null,
       elementRevision = null,
       family = null;

  const ContextTargetReadFacts.contentElement({
    required this.elementId,
    required this.elementKind,
    required this.elementSnapshot,
    required this.boundsWorld,
    required this.generation,
    required this.elementRevision,
    required this.family,
    required this.controllerEpoch,
    required this.documentRevision,
    this.query = const InteractionReadQueryFacts.notRun(),
  }) : kind = ContextActionReadTargetKind.contentElement;

  final ContextActionReadTargetKind kind;
  final CanvasElementId? elementId;
  final CanvasElementKind? elementKind;
  final CanvasElement? elementSnapshot;
  final Rect? boundsWorld;
  final int? generation;
  final int? elementRevision;
  final InteractionElementFamily? family;
  final int controllerEpoch;
  final int documentRevision;
  final InteractionReadQueryFacts query;
}

final class TextCommitGuardReadRequest {
  const TextCommitGuardReadRequest({required this.targetElementId});

  final CanvasElementId targetElementId;
}

final class TextCommitGuardReadFacts {
  const TextCommitGuardReadFacts.missing({
    required this.targetElementId,
    required this.controllerEpoch,
    required this.documentRevision,
  }) : exists = false,
       targetKind = null,
       generation = null,
       elementRevision = null,
       family = null,
       currentText = null;

  const TextCommitGuardReadFacts.current({
    required this.targetElementId,
    required this.targetKind,
    required this.generation,
    required this.elementRevision,
    required this.family,
    required this.controllerEpoch,
    required this.documentRevision,
    this.currentText,
  }) : exists = true;

  final CanvasElementId targetElementId;
  final bool exists;
  final CanvasElementKind? targetKind;
  final int? generation;
  final int? elementRevision;
  final InteractionElementFamily? family;
  final int controllerEpoch;
  final int documentRevision;
  final String? currentText;
}
