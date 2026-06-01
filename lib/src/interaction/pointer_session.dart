import 'dart:ui';

import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_preview.dart';
import '../contracts/public/canvas_tools.dart';

enum PointerSessionKind { moveModePointer, moveModeMarquee, drawModePointer }

final class PointerSessionToken {
  const PointerSessionToken(this.value);

  final int value;
}

final class PointerControllerEpoch {
  const PointerControllerEpoch(this.value);

  final int value;
}

final class PointerSessionId {
  const PointerSessionId(this.value);

  final int value;
}

final class PointerSession {
  PointerSession({
    required this.kind,
    required this.token,
    required this.controllerEpoch,
    required this.sessionId,
    required this.pointerId,
    required this.toolMode,
    required this.startWorld,
    required this.currentWorld,
    required Iterable<CanvasElementId> capturedSelectedIds,
    required Iterable<CanvasElementId> capturedMovableIds,
    required Iterable<CanvasElementId> previousSelectionIds,
    required this.capturedSelectionRevision,
    required this.lastPreview,
  }) : capturedSelectedIds = List.unmodifiable(capturedSelectedIds),
       capturedMovableIds = List.unmodifiable(capturedMovableIds),
       previousSelectionIds = List.unmodifiable(previousSelectionIds);

  final PointerSessionKind kind;
  final PointerSessionToken token;
  final PointerControllerEpoch controllerEpoch;
  final PointerSessionId sessionId;
  final int pointerId;
  final CanvasInteractionMode toolMode;
  final Offset startWorld;
  final Offset currentWorld;
  final List<CanvasElementId> capturedSelectedIds;
  final List<CanvasElementId> capturedMovableIds;
  final List<CanvasElementId> previousSelectionIds;
  final int capturedSelectionRevision;
  final CanvasPreviewState lastPreview;

  PointerSession updateCurrentWorld(Offset value) {
    return PointerSession(
      kind: kind,
      token: token,
      controllerEpoch: controllerEpoch,
      sessionId: sessionId,
      pointerId: pointerId,
      toolMode: toolMode,
      startWorld: startWorld,
      currentWorld: value,
      capturedSelectedIds: capturedSelectedIds,
      capturedMovableIds: capturedMovableIds,
      previousSelectionIds: previousSelectionIds,
      capturedSelectionRevision: capturedSelectionRevision,
      lastPreview: lastPreview,
    );
  }
}
