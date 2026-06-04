import 'dart:ui';

import '../contracts/public/canvas_actions.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_preview.dart';
import 'interaction_read_port.dart';
import 'interaction_runtime_intents.dart';
import 'pointer_session.dart';
import 'pointer_session_identity.dart';

final class MoveMachine {
  const MoveMachine();

  SelectedMoveStartDecision start(SelectedMoveStartFacts facts) {
    if (facts.selectedIds.isEmpty || facts.movableSelectedIds.isEmpty) {
      return const SelectedMoveStartDecision.rejected();
    }
    if (facts.hitSelectedMovable || _admitsGroupUnionStart(facts)) {
      return SelectedMoveStartDecision.admitted(
        selectedIds: facts.selectedIds,
        movableIds: facts.movableSelectedIds,
        selectionRevision: facts.selectionRevision,
      );
    }

    return const SelectedMoveStartDecision.rejected();
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
    if (proposedDelta == Offset.zero ||
        facts.movableIds.isEmpty ||
        facts.selectionRevision != selectionCapture.revision ||
        facts.controllerEpoch != session.controllerEpoch.value ||
        !facts.hasDocumentChangesAvailable) {
      return const SelectedMoveTerminalDecision.cleanupOnly();
    }

    return SelectedMoveTerminalDecision.commit(
      sessionId: session.sessionId,
      pointerToken: session.token,
      proposedDelta: proposedDelta,
      movableIds: facts.movableIds,
      movedElements: facts.movedElements,
      documentSummary: facts.documentSummary,
      selectionBoundsWorld: facts.selectionBoundsWorld,
    );
  }
}

bool _admitsGroupUnionStart(SelectedMoveStartFacts facts) {
  final bounds = facts.selectedGroupBoundsWorld;

  return facts.selectedIds.length > 1 &&
      facts.insideSelectedGroupUnion &&
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
  const SelectedMoveStartDecision.rejected()
    : admitted = false,
      selectedIds = const [],
      movableIds = const [],
      selectionRevision = 0;

  SelectedMoveStartDecision.admitted({
    required Iterable<CanvasElementId> selectedIds,
    required Iterable<CanvasElementId> movableIds,
    required this.selectionRevision,
  }) : admitted = true,
       selectedIds = List.unmodifiable(selectedIds),
       movableIds = List.unmodifiable(movableIds);

  final bool admitted;
  final List<CanvasElementId> selectedIds;
  final List<CanvasElementId> movableIds;
  final int selectionRevision;
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
    required Iterable<CanvasElementId> movableIds,
    required Iterable<CanvasElementRead> movedElements,
    required CanvasDocumentSummary documentSummary,
    required Rect selectionBoundsWorld,
  }) : shouldCommit = true,
       intent = SelectedMoveCommitIntent(
         sessionId: sessionId,
         pointerToken: pointerToken,
         proposedDelta: proposedDelta,
         movableIds: movableIds,
         movedElements: movedElements,
         documentSummary: documentSummary,
         selectionBoundsWorld: selectionBoundsWorld,
       );

  final bool shouldCommit;
  final SelectedMoveCommitIntent? intent;
}
