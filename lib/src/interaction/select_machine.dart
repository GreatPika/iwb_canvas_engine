import 'dart:ui';

import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_preview.dart';
import 'interaction_read_port.dart';
import 'pointer_session.dart';

final class SelectMachine {
  const SelectMachine();

  MarqueeStartDecision start(MarqueeStartFacts facts) {
    return MarqueeStartDecision(
      previousSelectionIds: facts.previousSelectedIds,
      selectionRevision: facts.selectionRevision,
    );
  }

  MarqueePreviewDecision initialPreview(Offset anchorWorld) {
    return MarqueePreviewDecision(
      rectWorld: _normalizedRect(anchorWorld, anchorWorld),
    );
  }

  MarqueePreviewDecision preview({
    required PointerSession session,
    required Offset currentWorld,
  }) {
    return MarqueePreviewDecision(
      rectWorld: _normalizedRect(session.startWorld, currentWorld),
    );
  }

  MarqueeTerminalDecision terminal({
    required PointerSession session,
    required MarqueeCommitFacts facts,
  }) {
    final selectionCapture = session.selectionCapture;
    if (facts.selectionRevision != selectionCapture.revision ||
        facts.controllerEpoch != session.controllerEpoch.value) {
      return const MarqueeTerminalDecision.cleanupOnly();
    }
    if (_idsEqual(facts.nextSelectedIds, selectionCapture.previousIds)) {
      return const MarqueeTerminalDecision.cleanupOnly();
    }

    return MarqueeTerminalDecision.commit(
      sessionId: session.sessionId,
      pointerToken: session.token,
      previousSelectionIds: selectionCapture.previousIds,
      nextSelectionIds: facts.nextSelectedIds,
      rectWorld: facts.rectWorld,
    );
  }
}

final class MarqueeStartDecision {
  MarqueeStartDecision({
    required Iterable<CanvasElementId> previousSelectionIds,
    required this.selectionRevision,
  }) : previousSelectionIds = List.unmodifiable(previousSelectionIds);

  final List<CanvasElementId> previousSelectionIds;
  final int selectionRevision;
}

final class MarqueePreviewDecision {
  const MarqueePreviewDecision({required this.rectWorld});

  final Rect rectWorld;
  CanvasPreviewState get preview => CanvasMarqueePreview(rect: rectWorld);
}

final class MarqueeTerminalDecision {
  const MarqueeTerminalDecision.cleanupOnly()
    : shouldCommit = false,
      intent = null;

  MarqueeTerminalDecision.commit({
    required PointerSessionId sessionId,
    required PointerSessionToken pointerToken,
    required Iterable<CanvasElementId> previousSelectionIds,
    required Iterable<CanvasElementId> nextSelectionIds,
    required Rect rectWorld,
  }) : shouldCommit = true,
       intent = MarqueeCommitIntent(
         sessionId: sessionId,
         pointerToken: pointerToken,
         previousSelectionIds: previousSelectionIds,
         nextSelectionIds: nextSelectionIds,
         rectWorld: rectWorld,
       );

  final bool shouldCommit;
  final MarqueeCommitIntent? intent;
}

final class MarqueeCommitIntent {
  MarqueeCommitIntent({
    required this.sessionId,
    required this.pointerToken,
    required Iterable<CanvasElementId> previousSelectionIds,
    required Iterable<CanvasElementId> nextSelectionIds,
    required this.rectWorld,
  }) : previousSelectionIds = List.unmodifiable(previousSelectionIds),
       nextSelectionIds = List.unmodifiable(nextSelectionIds);

  final PointerSessionId sessionId;
  final PointerSessionToken pointerToken;
  final List<CanvasElementId> previousSelectionIds;
  final List<CanvasElementId> nextSelectionIds;
  final Rect rectWorld;
}

Rect _normalizedRect(Offset a, Offset b) {
  return Rect.fromLTRB(
    a.dx < b.dx ? a.dx : b.dx,
    a.dy < b.dy ? a.dy : b.dy,
    a.dx > b.dx ? a.dx : b.dx,
    a.dy > b.dy ? a.dy : b.dy,
  );
}

bool _idsEqual(List<CanvasElementId> left, List<CanvasElementId> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }

  return true;
}
