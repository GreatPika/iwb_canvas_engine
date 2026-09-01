import 'dart:ui';

import '../contracts/public/canvas_actions.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_preview.dart';
import 'interaction_read_port.dart';
import 'interaction_runtime_intents.dart';
import 'pointer_session.dart';
import 'pointer_session_identity.dart';

// Start-to-terminal Move decisions intentionally retain the complete typed
// basis; splitting the decision would obscure the captured-identity invariant.
// ignore: coupling-between-object-classes, reason: Start-to-terminal decisions retain one typed basis.
final class MoveMachine {
  const MoveMachine();

  SelectedMoveStartDecision start(SelectedMoveStartFacts facts) {
    if (facts.selectedIds.isEmpty || facts.movableSelectedIds.isEmpty) {
      final unselectedMovableHit = _unselectedMovableHitDecision(facts);
      if (unselectedMovableHit.admitted) {
        return unselectedMovableHit;
      }

      return SelectedMoveStartDecision.rejected(
        suppressMarqueeDrag: facts.topmostHitId != null,
      );
    }
    if (facts.hitSelectedMovable || _admitsGroupUnionStart(facts)) {
      return SelectedMoveStartDecision.admitted(
        selectedIds: facts.selectedIds,
        movableIds: facts.movableSelectedIds,
        previousSelectionIds: facts.selectedIds,
        selectionRevision: facts.selectionRevision,
        basis: _selectedMoveBasis(
          participants: facts.movableParticipants,
          documentSummary: facts.documentSummary,
          selectionBoundsWorld: facts.selectionBoundsWorld,
        ),
      );
    }
    final unselectedMovableHit = _unselectedMovableHitDecision(facts);
    if (unselectedMovableHit.admitted) {
      return unselectedMovableHit;
    }

    return SelectedMoveStartDecision.rejected(
      suppressMarqueeDrag: facts.topmostHitId != null,
    );
  }

  SelectedMovePreviewDecision preview({
    required PointerSession session,
    required Offset currentWorld,
  }) {
    return SelectedMovePreviewDecision(
      delta: currentWorld - session.startWorld,
    );
  }

  SelectedMoveTerminalDecision terminal({
    required PointerSession session,
    required Offset terminalWorld,
    required SelectedMoveCommitFacts facts,
  }) {
    final proposedDelta = terminalWorld - session.startWorld;
    final selectionCapture = session.selectionCapture;
    final basis = session.selectedMoveBasis;
    if (proposedDelta == Offset.zero ||
        basis == null ||
        basis.participants.isEmpty ||
        facts.selectionRevision != selectionCapture.revision &&
            !session.provisionalSelectionReplacementApplied ||
        facts.controllerEpoch != session.controllerEpoch.value ||
        !facts.hasDocumentChangesAvailable ||
        !facts.participantsAreCurrent) {
      return const SelectedMoveTerminalDecision.cleanupOnly();
    }

    return SelectedMoveTerminalDecision.commit(
      sessionId: session.sessionId,
      pointerToken: session.token,
      proposedDelta: proposedDelta,
      selectedElementIdsBefore: selectionCapture.previousIds,
      movableIds: basis.participantIds,
      movedElements: basis.movedElements,
      documentSummary: basis.documentSummary,
      selectionBoundsWorld: basis.selectionBoundsWorld,
    );
  }
}

SelectedMoveStartDecision _unselectedMovableHitDecision(
  SelectedMoveStartFacts facts,
) {
  final hitId = facts.topmostMovableHitId;
  if (hitId == null || facts.selectedIds.contains(hitId)) {
    return const SelectedMoveStartDecision.rejected();
  }

  return SelectedMoveStartDecision.admitted(
    selectedIds: [hitId],
    movableIds: [hitId],
    previousSelectionIds: facts.selectedIds,
    selectionRevision: facts.selectionRevision,
    basis: _selectedMoveBasis(
      participants: facts.movableParticipants.where(
        (participant) => participant.element.id == hitId,
      ),
      documentSummary: facts.documentSummary,
      selectionBoundsWorld: _participantBounds(facts, hitId),
    ),
  );
}

SelectedMoveSessionBasis _selectedMoveBasis({
  required Iterable<SelectedMoveParticipantFacts> participants,
  required CanvasDocumentSummary documentSummary,
  required Rect selectionBoundsWorld,
}) {
  return SelectedMoveSessionBasis(
    participants: participants,
    documentSummary: documentSummary,
    selectionBoundsWorld: selectionBoundsWorld,
  );
}

Rect _participantBounds(SelectedMoveStartFacts facts, CanvasElementId id) {
  for (final participant in facts.movableParticipants) {
    if (participant.element.id == id) {
      return participant.element.boundsWorld;
    }
  }

  return Rect.zero;
}

bool _admitsGroupUnionStart(SelectedMoveStartFacts facts) {
  final bounds = facts.selectedGroupBoundsWorld;

  return facts.selectedIds.length > 1 &&
      facts.insideSelectedGroupUnion &&
      facts.groupUnionOcclusionReliable &&
      !facts.groupUnionOccludedByHigherOrderHit &&
      facts.query.status == InteractionReadQueryStatus.candidates &&
      facts.query.skippedCandidateCount == 0 &&
      facts.selectedTopOrderToken != null &&
      bounds != null &&
      _isFiniteNonEmptyRect(bounds);
}

bool _isFiniteNonEmptyRect(Rect rect) {
  return rect.left.isFinite &&
      rect.top.isFinite &&
      rect.right.isFinite &&
      rect.bottom.isFinite &&
      !rect.isEmpty;
}

final class SelectedMoveStartDecision {
  const SelectedMoveStartDecision.rejected({this.suppressMarqueeDrag = false})
    : admitted = false,
      selectedIds = const [],
      movableIds = const [],
      previousSelectionIds = const [],
      selectionRevision = 0,
      basis = null;

  SelectedMoveStartDecision.admitted({
    required Iterable<CanvasElementId> selectedIds,
    required Iterable<CanvasElementId> movableIds,
    required Iterable<CanvasElementId> previousSelectionIds,
    required this.selectionRevision,
    required this.basis,
    this.suppressMarqueeDrag = false,
  }) : admitted = true,
       selectedIds = List.unmodifiable(selectedIds),
       movableIds = List.unmodifiable(movableIds),
       previousSelectionIds = List.unmodifiable(previousSelectionIds);

  final bool admitted;
  final List<CanvasElementId> selectedIds;
  final List<CanvasElementId> movableIds;
  final List<CanvasElementId> previousSelectionIds;
  final int selectionRevision;
  final SelectedMoveSessionBasis? basis;
  final bool suppressMarqueeDrag;
}

final class SelectedMovePreviewDecision {
  const SelectedMovePreviewDecision({required this.delta});

  final Offset delta;
  CanvasPreviewState get preview => CanvasSelectedMovePreview(delta: delta);
}

final class SelectedMoveTerminalDecision {
  const SelectedMoveTerminalDecision.cleanupOnly()
    : intent = null,
      shouldCommit = false;

  SelectedMoveTerminalDecision.commit({
    required PointerSessionId sessionId,
    required PointerSessionToken pointerToken,
    required Offset proposedDelta,
    required Iterable<CanvasElementId> selectedElementIdsBefore,
    required Iterable<CanvasElementId> movableIds,
    required Iterable<CanvasElementRead> movedElements,
    required CanvasDocumentSummary documentSummary,
    required Rect selectionBoundsWorld,
  }) : shouldCommit = true,
       intent = SelectedMoveCommitIntent(
         sessionId: sessionId,
         pointerToken: pointerToken,
         proposedDelta: proposedDelta,
         selectedElementIdsBefore: selectedElementIdsBefore,
         movableIds: movableIds,
         movedElements: movedElements,
         documentSummary: documentSummary,
         selectionBoundsWorld: selectionBoundsWorld,
       );

  final bool shouldCommit;
  final SelectedMoveCommitIntent? intent;
}
