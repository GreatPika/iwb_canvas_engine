import 'dart:ui';

import '../contracts/public/canvas_actions.dart';
import '../contracts/public/canvas_document.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_preview.dart';
import 'draw_stroke_machine.dart';
import 'eraser_machine.dart';
import 'interaction_read_port.dart';
import 'line_machine.dart';
import 'pointer_session_identity.dart';

enum PointerSessionKind {
  moveModePointer,
  moveModeMarquee,
  drawModePointer,
  drawEraserPointer,
  drawLineFirstTap,
  drawLineEndpoint,
}

final class PointerControllerEpoch {
  const PointerControllerEpoch(this.value);

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

/// Immutable facts retained for the lifetime of one selected-move gesture.
final class SelectedMoveSessionBasis {
  SelectedMoveSessionBasis({
    required Iterable<SelectedMoveParticipantFacts> participants,
    required this.documentSummary,
    required this.selectionBoundsWorld,
  }) : participants = List.unmodifiable(participants) {
    participantIds = List<CanvasElementId>.unmodifiable(
      this.participants.map((participant) => participant.element.id),
    );
    // This membership view duplicates the ordered ID view only for hot-path
    // lookups. Both values are derived here from the same immutable
    // participants, and Move/frame fixtures validate their captured identity.
    participantIdSet = Set<CanvasElementId>.unmodifiable(participantIds);
    movedElements = List<CanvasElementRead>.unmodifiable(
      this.participants.map((participant) => participant.element),
    );
  }

  final List<SelectedMoveParticipantFacts> participants;
  late final List<CanvasElementId> participantIds;
  late final Set<CanvasElementId> participantIdSet;
  late final List<CanvasElementRead> movedElements;
  final CanvasDocumentSummary documentSummary;
  final Rect selectionBoundsWorld;
}

// One active pointer can carry move, marquee, stroke, or line payloads. Keeping
// those variants in this value keeps token/session identity updates atomic.
// ignore: coupling-between-object-classes, number-of-methods
final class PointerSession {
  const PointerSession._({
    required this.kind,
    required this.token,
    required this.controllerEpoch,
    required this.sessionId,
    required this.pointerId,
    required this.dragStartSlop,
    required this.dragPreviewStarted,
    required this.provisionalSelectionReplacementApplied,
    required this.provisionalSelectionReplacementRevision,
    required this.marqueeCommitSuppressed,
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
    required SelectedMoveSessionBasis basis,
    required CanvasPreviewState lastPreview,
    required double dragStartSlop,
    bool provisionalSelectionReplacementApplied = false,
    int? provisionalSelectionReplacementRevision,
  }) {
    return PointerSession._(
      kind: PointerSessionKind.moveModePointer,
      token: token,
      controllerEpoch: controllerEpoch,
      sessionId: sessionId,
      pointerId: pointerId,
      dragStartSlop: dragStartSlop,
      dragPreviewStarted: false,
      provisionalSelectionReplacementApplied:
          provisionalSelectionReplacementApplied,
      provisionalSelectionReplacementRevision:
          provisionalSelectionReplacementRevision,
      marqueeCommitSuppressed: false,
      payload: _SelectedMovePointerPayload(
        startWorld: startWorld,
        currentWorld: currentWorld,
        capturedSelectedIds: capturedSelectedIds,
        capturedMovableIds: capturedMovableIds,
        previousSelectionIds: previousSelectionIds,
        capturedSelectionRevision: capturedSelectionRevision,
        basis: basis,
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
    required double dragStartSlop,
    bool suppressCommit = false,
  }) {
    return PointerSession._(
      kind: PointerSessionKind.moveModeMarquee,
      token: token,
      controllerEpoch: controllerEpoch,
      sessionId: sessionId,
      pointerId: pointerId,
      dragStartSlop: dragStartSlop,
      dragPreviewStarted: false,
      provisionalSelectionReplacementApplied: false,
      provisionalSelectionReplacementRevision: null,
      marqueeCommitSuppressed: suppressCommit,
      payload: _MarqueePointerPayload(
        startWorld: startWorld,
        currentWorld: currentWorld,
        previousSelectionIds: previousSelectionIds,
        capturedSelectionRevision: capturedSelectionRevision,
        lastPreview: lastPreview,
      ),
    );
  }

  factory PointerSession.drawStroke({
    required PointerSessionToken token,
    required PointerControllerEpoch controllerEpoch,
    required PointerSessionId sessionId,
    required int pointerId,
    required Offset startWorld,
    required Offset currentWorld,
    required PointerStrokeCapture stroke,
    required double dragStartSlop,
  }) {
    return PointerSession._(
      kind: PointerSessionKind.drawModePointer,
      token: token,
      controllerEpoch: controllerEpoch,
      sessionId: sessionId,
      pointerId: pointerId,
      dragStartSlop: dragStartSlop,
      dragPreviewStarted: false,
      provisionalSelectionReplacementApplied: false,
      provisionalSelectionReplacementRevision: null,
      marqueeCommitSuppressed: false,
      payload: _DrawStrokePointerPayload(
        startWorld: startWorld,
        currentWorld: currentWorld,
        stroke: stroke,
      ),
    );
  }

  factory PointerSession.eraser({
    required PointerSessionToken token,
    required PointerControllerEpoch controllerEpoch,
    required PointerSessionId sessionId,
    required int pointerId,
    required Offset startWorld,
    required Offset currentWorld,
    required PointerEraserCapture eraser,
    required CanvasPreviewState lastPreview,
    required double dragStartSlop,
  }) {
    return PointerSession._(
      kind: PointerSessionKind.drawEraserPointer,
      token: token,
      controllerEpoch: controllerEpoch,
      sessionId: sessionId,
      pointerId: pointerId,
      dragStartSlop: dragStartSlop,
      dragPreviewStarted: false,
      provisionalSelectionReplacementApplied: false,
      provisionalSelectionReplacementRevision: null,
      marqueeCommitSuppressed: false,
      payload: _EraserPointerPayload(
        startWorld: startWorld,
        currentWorld: currentWorld,
        eraser: eraser,
        lastPreview: lastPreview,
      ),
    );
  }

  factory PointerSession.lineFirstTap({
    required PointerSessionToken token,
    required PointerControllerEpoch controllerEpoch,
    required PointerSessionId sessionId,
    required int pointerId,
    required Offset startWorld,
    required Offset currentWorld,
    required PointerLineFirstTapCapture firstTap,
    required double dragStartSlop,
  }) {
    return PointerSession._(
      kind: PointerSessionKind.drawLineFirstTap,
      token: token,
      controllerEpoch: controllerEpoch,
      sessionId: sessionId,
      pointerId: pointerId,
      dragStartSlop: dragStartSlop,
      dragPreviewStarted: false,
      provisionalSelectionReplacementApplied: false,
      provisionalSelectionReplacementRevision: null,
      marqueeCommitSuppressed: false,
      payload: _LineFirstTapPointerPayload(
        startWorld: startWorld,
        currentWorld: currentWorld,
        firstTap: firstTap,
      ),
    );
  }

  factory PointerSession.lineEndpoint({
    required PointerSessionToken token,
    required PointerControllerEpoch controllerEpoch,
    required PointerSessionId sessionId,
    required int pointerId,
    required Offset startWorld,
    required Offset currentWorld,
    required PointerLineEndpointCapture line,
    required double dragStartSlop,
  }) {
    return PointerSession._(
      kind: PointerSessionKind.drawLineEndpoint,
      token: token,
      controllerEpoch: controllerEpoch,
      sessionId: sessionId,
      pointerId: pointerId,
      dragStartSlop: dragStartSlop,
      dragPreviewStarted: false,
      provisionalSelectionReplacementApplied: false,
      provisionalSelectionReplacementRevision: null,
      marqueeCommitSuppressed: false,
      payload: _LineEndpointPointerPayload(
        startWorld: startWorld,
        currentWorld: currentWorld,
        line: line,
      ),
    );
  }

  final PointerSessionKind kind;
  final PointerSessionToken token;
  final PointerControllerEpoch controllerEpoch;
  final PointerSessionId sessionId;
  final int pointerId;
  final double dragStartSlop;
  final bool dragPreviewStarted;
  final bool provisionalSelectionReplacementApplied;
  final int? provisionalSelectionReplacementRevision;
  final bool marqueeCommitSuppressed;
  final _PointerSessionPayload _payload;

  Offset get startWorld => _payload.startWorld;
  Offset get currentWorld => _payload.currentWorld;
  PointerSessionSelectionCapture get selectionCapture =>
      _payload.selectionCapture;
  SelectedMoveSessionBasis? get selectedMoveBasis => switch (_payload) {
    _SelectedMovePointerPayload(:final basis) => basis,
    _ => null,
  };
  PointerStrokeCapture? get strokeCapture => _payload.strokeCapture;
  PointerEraserCapture? get eraserCapture => _payload.eraserCapture;
  PointerLineFirstTapCapture? get lineFirstTapCapture =>
      _payload.lineFirstTapCapture;
  PointerLineEndpointCapture? get lineEndpointCapture =>
      _payload.lineEndpointCapture;

  PointerSession updateCurrentWorld(Offset value) {
    return PointerSession._(
      kind: kind,
      token: token,
      controllerEpoch: controllerEpoch,
      sessionId: sessionId,
      pointerId: pointerId,
      dragStartSlop: dragStartSlop,
      dragPreviewStarted: dragPreviewStarted,
      provisionalSelectionReplacementApplied:
          provisionalSelectionReplacementApplied,
      provisionalSelectionReplacementRevision:
          provisionalSelectionReplacementRevision,
      marqueeCommitSuppressed: marqueeCommitSuppressed,
      payload: _payload.updateCurrentWorld(value),
    );
  }

  PointerSession markProvisionalSelectionReplacementApplied({
    required int selectionRevision,
  }) {
    return PointerSession._(
      kind: kind,
      token: token,
      controllerEpoch: controllerEpoch,
      sessionId: sessionId,
      pointerId: pointerId,
      dragStartSlop: dragStartSlop,
      dragPreviewStarted: dragPreviewStarted,
      provisionalSelectionReplacementApplied: true,
      provisionalSelectionReplacementRevision: selectionRevision,
      marqueeCommitSuppressed: marqueeCommitSuppressed,
      payload: _payload,
    );
  }

  PointerSession markDragPreviewStarted() {
    if (dragPreviewStarted) {
      return this;
    }

    return PointerSession._(
      kind: kind,
      token: token,
      controllerEpoch: controllerEpoch,
      sessionId: sessionId,
      pointerId: pointerId,
      dragStartSlop: dragStartSlop,
      dragPreviewStarted: true,
      provisionalSelectionReplacementApplied:
          provisionalSelectionReplacementApplied,
      provisionalSelectionReplacementRevision:
          provisionalSelectionReplacementRevision,
      marqueeCommitSuppressed: marqueeCommitSuppressed,
      payload: _payload,
    );
  }

  PointerSession asSelectionTerminalSession({
    required Iterable<CanvasElementId> previousSelectionIds,
    required int selectionRevision,
    required Offset terminalWorld,
  }) {
    return PointerSession._(
      kind: PointerSessionKind.moveModeMarquee,
      token: token,
      controllerEpoch: controllerEpoch,
      sessionId: sessionId,
      pointerId: pointerId,
      dragStartSlop: dragStartSlop,
      dragPreviewStarted: dragPreviewStarted,
      provisionalSelectionReplacementApplied:
          provisionalSelectionReplacementApplied,
      provisionalSelectionReplacementRevision:
          provisionalSelectionReplacementRevision,
      marqueeCommitSuppressed: marqueeCommitSuppressed,
      payload: _MarqueePointerPayload(
        startWorld: terminalWorld,
        currentWorld: terminalWorld,
        previousSelectionIds: previousSelectionIds,
        capturedSelectionRevision: selectionRevision,
        lastPreview: const CanvasNoPreview(),
      ),
    );
  }

  PointerSession updateStroke({
    required Offset currentWorld,
    required PointerStrokeCapture stroke,
  }) {
    return PointerSession._(
      kind: kind,
      token: token,
      controllerEpoch: controllerEpoch,
      sessionId: sessionId,
      pointerId: pointerId,
      dragStartSlop: dragStartSlop,
      dragPreviewStarted: dragPreviewStarted,
      provisionalSelectionReplacementApplied:
          provisionalSelectionReplacementApplied,
      provisionalSelectionReplacementRevision:
          provisionalSelectionReplacementRevision,
      marqueeCommitSuppressed: marqueeCommitSuppressed,
      payload: _payload.updateStroke(
        currentWorld: currentWorld,
        stroke: stroke,
      ),
    );
  }

  PointerSession updateEraser({
    required Offset currentWorld,
    required PointerEraserCapture eraser,
    required CanvasPreviewState lastPreview,
  }) {
    return PointerSession._(
      kind: kind,
      token: token,
      controllerEpoch: controllerEpoch,
      sessionId: sessionId,
      pointerId: pointerId,
      dragStartSlop: dragStartSlop,
      dragPreviewStarted: dragPreviewStarted,
      provisionalSelectionReplacementApplied:
          provisionalSelectionReplacementApplied,
      provisionalSelectionReplacementRevision:
          provisionalSelectionReplacementRevision,
      marqueeCommitSuppressed: marqueeCommitSuppressed,
      payload: _payload.updateEraser(
        currentWorld: currentWorld,
        eraser: eraser,
        lastPreview: lastPreview,
      ),
    );
  }

  PointerSession updateLineEndpoint({
    required Offset currentWorld,
    required PointerLineEndpointCapture line,
  }) {
    return PointerSession._(
      kind: kind,
      token: token,
      controllerEpoch: controllerEpoch,
      sessionId: sessionId,
      pointerId: pointerId,
      dragStartSlop: dragStartSlop,
      dragPreviewStarted: dragPreviewStarted,
      provisionalSelectionReplacementApplied:
          provisionalSelectionReplacementApplied,
      provisionalSelectionReplacementRevision:
          provisionalSelectionReplacementRevision,
      marqueeCommitSuppressed: marqueeCommitSuppressed,
      payload: _payload.updateLineEndpoint(
        currentWorld: currentWorld,
        line: line,
      ),
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
  PointerStrokeCapture? get strokeCapture => null;
  PointerEraserCapture? get eraserCapture => null;
  PointerLineFirstTapCapture? get lineFirstTapCapture => null;
  PointerLineEndpointCapture? get lineEndpointCapture => null;

  _PointerSessionPayload updateCurrentWorld(Offset value);
  _PointerSessionPayload updateStroke({
    required Offset currentWorld,
    required PointerStrokeCapture stroke,
  }) {
    return updateCurrentWorld(currentWorld);
  }

  _PointerSessionPayload updateEraser({
    required Offset currentWorld,
    required PointerEraserCapture eraser,
    required CanvasPreviewState lastPreview,
  }) {
    return updateCurrentWorld(currentWorld);
  }

  _PointerSessionPayload updateLineEndpoint({
    required Offset currentWorld,
    required PointerLineEndpointCapture line,
  }) {
    return updateCurrentWorld(currentWorld);
  }
}

final class _SelectedMovePointerPayload extends _PointerSessionPayload {
  _SelectedMovePointerPayload({
    required super.startWorld,
    required super.currentWorld,
    required Iterable<CanvasElementId> capturedSelectedIds,
    required Iterable<CanvasElementId> capturedMovableIds,
    required Iterable<CanvasElementId> previousSelectionIds,
    required this.capturedSelectionRevision,
    required this.basis,
    required super.lastPreview,
  }) : capturedSelectedIds = List.unmodifiable(capturedSelectedIds),
       capturedMovableIds = List.unmodifiable(capturedMovableIds),
       previousSelectionIds = List.unmodifiable(previousSelectionIds);

  final List<CanvasElementId> capturedSelectedIds;
  final List<CanvasElementId> capturedMovableIds;
  final List<CanvasElementId> previousSelectionIds;
  final int capturedSelectionRevision;
  final SelectedMoveSessionBasis basis;

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
      basis: basis,
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

final class _DrawStrokePointerPayload extends _PointerSessionPayload {
  _DrawStrokePointerPayload({
    required super.startWorld,
    required super.currentWorld,
    required this.stroke,
  }) : super(lastPreview: stroke.preview);

  final PointerStrokeCapture stroke;

  @override
  PointerStrokeCapture get strokeCapture => stroke;

  @override
  _PointerSessionPayload updateCurrentWorld(Offset value) {
    return _DrawStrokePointerPayload(
      startWorld: startWorld,
      currentWorld: value,
      stroke: stroke,
    );
  }

  @override
  _PointerSessionPayload updateStroke({
    required Offset currentWorld,
    required PointerStrokeCapture stroke,
  }) {
    return _DrawStrokePointerPayload(
      startWorld: startWorld,
      currentWorld: currentWorld,
      stroke: stroke,
    );
  }
}

final class _EraserPointerPayload extends _PointerSessionPayload {
  const _EraserPointerPayload({
    required super.startWorld,
    required super.currentWorld,
    required this.eraser,
    required super.lastPreview,
  });

  final PointerEraserCapture eraser;

  @override
  PointerEraserCapture get eraserCapture => eraser;

  @override
  _PointerSessionPayload updateCurrentWorld(Offset value) {
    return _EraserPointerPayload(
      startWorld: startWorld,
      currentWorld: value,
      eraser: eraser,
      lastPreview: lastPreview,
    );
  }

  @override
  _PointerSessionPayload updateEraser({
    required Offset currentWorld,
    required PointerEraserCapture eraser,
    required CanvasPreviewState lastPreview,
  }) {
    return _EraserPointerPayload(
      startWorld: startWorld,
      currentWorld: currentWorld,
      eraser: eraser,
      lastPreview: lastPreview,
    );
  }
}

final class _LineFirstTapPointerPayload extends _PointerSessionPayload {
  _LineFirstTapPointerPayload({
    required super.startWorld,
    required super.currentWorld,
    required this.firstTap,
  }) : super(lastPreview: const CanvasNoPreview());

  final PointerLineFirstTapCapture firstTap;

  @override
  PointerLineFirstTapCapture get lineFirstTapCapture => firstTap;

  @override
  _PointerSessionPayload updateCurrentWorld(Offset value) {
    return _LineFirstTapPointerPayload(
      startWorld: startWorld,
      currentWorld: value,
      firstTap: firstTap,
    );
  }
}

final class _LineEndpointPointerPayload extends _PointerSessionPayload {
  _LineEndpointPointerPayload({
    required super.startWorld,
    required super.currentWorld,
    required this.line,
  }) : super(lastPreview: line.preview);

  final PointerLineEndpointCapture line;

  @override
  PointerLineEndpointCapture get lineEndpointCapture => line;

  @override
  _PointerSessionPayload updateCurrentWorld(Offset value) {
    return _LineEndpointPointerPayload(
      startWorld: startWorld,
      currentWorld: value,
      line: line,
    );
  }

  @override
  _PointerSessionPayload updateLineEndpoint({
    required Offset currentWorld,
    required PointerLineEndpointCapture line,
  }) {
    return _LineEndpointPointerPayload(
      startWorld: startWorld,
      currentWorld: currentWorld,
      line: line,
    );
  }
}
