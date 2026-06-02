import 'dart:ui';

import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_preview.dart';

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

final class PointerSessionSelectionCapture {
  PointerSessionSelectionCapture({
    required Iterable<CanvasElementId> selectedIds,
    required Iterable<CanvasElementId> movableIds,
    required Iterable<CanvasElementId> previousIds,
    required this.revision,
  }) : selectedIds = List.unmodifiable(selectedIds),
       movableIds = List.unmodifiable(movableIds),
       previousIds = List.unmodifiable(previousIds);

  final List<CanvasElementId> selectedIds;
  final List<CanvasElementId> movableIds;
  final List<CanvasElementId> previousIds;
  final int revision;
}

final class PointerSession {
  PointerSession._({
    required this.kind,
    required this.token,
    required this.controllerEpoch,
    required this.sessionId,
    required this.pointerId,
    required _PointerSessionPayload payload,
  }) : _payload = payload;

  factory PointerSession.selectedMove({
    required PointerSessionToken token,
    required PointerControllerEpoch controllerEpoch,
    required PointerSessionId sessionId,
    required int pointerId,
    required Offset startWorld,
    required Offset currentWorld,
    required Iterable<CanvasElementId> capturedSelectedIds,
    required Iterable<CanvasElementId> capturedMovableIds,
    required Iterable<CanvasElementId> previousSelectionIds,
    required int capturedSelectionRevision,
    required CanvasPreviewState lastPreview,
  }) {
    return PointerSession._(
      kind: PointerSessionKind.moveModePointer,
      token: token,
      controllerEpoch: controllerEpoch,
      sessionId: sessionId,
      pointerId: pointerId,
      payload: _SelectedMovePointerPayload(
        startWorld: startWorld,
        currentWorld: currentWorld,
        capturedSelectedIds: capturedSelectedIds,
        capturedMovableIds: capturedMovableIds,
        previousSelectionIds: previousSelectionIds,
        capturedSelectionRevision: capturedSelectionRevision,
        lastPreview: lastPreview,
      ),
    );
  }

  factory PointerSession.marquee({
    required PointerSessionToken token,
    required PointerControllerEpoch controllerEpoch,
    required PointerSessionId sessionId,
    required int pointerId,
    required Offset startWorld,
    required Offset currentWorld,
    required Iterable<CanvasElementId> previousSelectionIds,
    required int capturedSelectionRevision,
    required CanvasPreviewState lastPreview,
  }) {
    return PointerSession._(
      kind: PointerSessionKind.moveModeMarquee,
      token: token,
      controllerEpoch: controllerEpoch,
      sessionId: sessionId,
      pointerId: pointerId,
      payload: _MarqueePointerPayload(
        startWorld: startWorld,
        currentWorld: currentWorld,
        previousSelectionIds: previousSelectionIds,
        capturedSelectionRevision: capturedSelectionRevision,
        lastPreview: lastPreview,
      ),
    );
  }

  factory PointerSession.drawModePointer({
    required PointerSessionToken token,
    required PointerControllerEpoch controllerEpoch,
    required PointerSessionId sessionId,
    required int pointerId,
    required Offset startWorld,
    required Offset currentWorld,
    required CanvasPreviewState lastPreview,
    bool ownsPendingLine = false,
  }) {
    return PointerSession._(
      kind: PointerSessionKind.drawModePointer,
      token: token,
      controllerEpoch: controllerEpoch,
      sessionId: sessionId,
      pointerId: pointerId,
      payload: _DrawPointerPayload(
        startWorld: startWorld,
        currentWorld: currentWorld,
        lastPreview: lastPreview,
        ownsPendingLine: ownsPendingLine,
      ),
    );
  }

  final PointerSessionKind kind;
  final PointerSessionToken token;
  final PointerControllerEpoch controllerEpoch;
  final PointerSessionId sessionId;
  final int pointerId;
  final _PointerSessionPayload _payload;

  Offset get startWorld => _payload.startWorld;
  Offset get currentWorld => _payload.currentWorld;
  PointerSessionSelectionCapture get selectionCapture =>
      _payload.selectionCapture;
  bool get ownsPendingLine => _payload.ownsPendingLine;

  PointerSession updateCurrentWorld(Offset value) {
    return PointerSession._(
      kind: kind,
      token: token,
      controllerEpoch: controllerEpoch,
      sessionId: sessionId,
      pointerId: pointerId,
      payload: _payload.updateCurrentWorld(value),
    );
  }
}

sealed class _PointerSessionPayload {
  const _PointerSessionPayload({
    required this.startWorld,
    required this.currentWorld,
    required this.lastPreview,
  });

  final Offset startWorld;
  final Offset currentWorld;
  final CanvasPreviewState lastPreview;

  PointerSessionSelectionCapture get selectionCapture =>
      PointerSessionSelectionCapture(
        selectedIds: const [],
        movableIds: const [],
        previousIds: const [],
        revision: 0,
      );
  bool get ownsPendingLine => false;

  _PointerSessionPayload updateCurrentWorld(Offset value);
}

final class _SelectedMovePointerPayload extends _PointerSessionPayload {
  _SelectedMovePointerPayload({
    required super.startWorld,
    required super.currentWorld,
    required Iterable<CanvasElementId> capturedSelectedIds,
    required Iterable<CanvasElementId> capturedMovableIds,
    required Iterable<CanvasElementId> previousSelectionIds,
    required this.capturedSelectionRevision,
    required super.lastPreview,
  }) : capturedSelectedIds = List.unmodifiable(capturedSelectedIds),
       capturedMovableIds = List.unmodifiable(capturedMovableIds),
       previousSelectionIds = List.unmodifiable(previousSelectionIds);

  final List<CanvasElementId> capturedSelectedIds;
  final List<CanvasElementId> capturedMovableIds;
  final List<CanvasElementId> previousSelectionIds;
  final int capturedSelectionRevision;

  @override
  PointerSessionSelectionCapture get selectionCapture =>
      PointerSessionSelectionCapture(
        selectedIds: capturedSelectedIds,
        movableIds: capturedMovableIds,
        previousIds: previousSelectionIds,
        revision: capturedSelectionRevision,
      );

  @override
  _PointerSessionPayload updateCurrentWorld(Offset value) {
    return _SelectedMovePointerPayload(
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

final class _MarqueePointerPayload extends _PointerSessionPayload {
  _MarqueePointerPayload({
    required super.startWorld,
    required super.currentWorld,
    required Iterable<CanvasElementId> previousSelectionIds,
    required this.capturedSelectionRevision,
    required super.lastPreview,
  }) : previousSelectionIds = List.unmodifiable(previousSelectionIds);

  final List<CanvasElementId> previousSelectionIds;
  final int capturedSelectionRevision;

  @override
  PointerSessionSelectionCapture get selectionCapture =>
      PointerSessionSelectionCapture(
        selectedIds: const [],
        movableIds: const [],
        previousIds: previousSelectionIds,
        revision: capturedSelectionRevision,
      );

  @override
  _PointerSessionPayload updateCurrentWorld(Offset value) {
    return _MarqueePointerPayload(
      startWorld: startWorld,
      currentWorld: value,
      previousSelectionIds: previousSelectionIds,
      capturedSelectionRevision: capturedSelectionRevision,
      lastPreview: lastPreview,
    );
  }
}

final class _DrawPointerPayload extends _PointerSessionPayload {
  const _DrawPointerPayload({
    required super.startWorld,
    required super.currentWorld,
    required super.lastPreview,
    required this.ownsPendingLine,
  });
  @override
  final bool ownsPendingLine;

  @override
  _PointerSessionPayload updateCurrentWorld(Offset value) {
    return _DrawPointerPayload(
      startWorld: startWorld,
      currentWorld: value,
      lastPreview: lastPreview,
      ownsPendingLine: ownsPendingLine,
    );
  }
}
