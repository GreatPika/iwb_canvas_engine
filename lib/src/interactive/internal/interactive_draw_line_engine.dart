import 'dart:async';
import 'dart:ui';

import '../../core/action_events.dart';
import '../../core/input_sampling.dart';
import '../../contract/snapshot.dart';
import 'interactive_draw_action_emitter.dart';
import 'interactive_draw_style.dart';
import 'pointer_session_token.dart';

typedef InteractiveDrawLineUp = ({
  int timestampMs,
  Offset scenePoint,
  Offset? downScene,
  bool moved,
  double dragStartSlop,
  InteractiveDrawStyle? capturedStyle,
  PointerSessionToken? sessionToken,
});

final class _PendingLineState {
  _PendingLineState({
    required this.start,
    required this.timestampMs,
    required this.capturedStyle,
    required this.sessionToken,
    required this.timeoutTimer,
  });

  final Offset start;
  final int timestampMs;
  final InteractiveDrawStyle capturedStyle;
  final PointerSessionToken? sessionToken;
  final Timer timeoutTimer;

  void dispose() {
    timeoutTimer.cancel();
  }
}

class InteractiveDrawLineEngineCallbacks {
  const InteractiveDrawLineEngineCallbacks({
    required this.onStateChanged,
    required this.emitAction,
    required this.commitDrawLineFromWorldSegment,
  });

  final VoidCallback onStateChanged;
  final void Function(
    ActionType type,
    List<NodeId> nodeIds,
    int timestampMs, {
    Map<String, Object?>? payload,
  })
  emitAction;
  final NodeId Function({
    required Offset start,
    required Offset end,
    required double thickness,
    required Color color,
    required double opacity,
  })
  commitDrawLineFromWorldSegment;
}

class InteractiveDrawLineEngine {
  InteractiveDrawLineEngine({required this.callbacks});

  final InteractiveDrawLineEngineCallbacks callbacks;
  late final InteractiveDrawActionEmitter _actionEmitter =
      InteractiveDrawActionEmitter(emitAction: callbacks.emitAction);

  Offset? _activeLinePreviewStart;
  Offset? _activeLinePreviewEnd;

  _PendingLineState? _pendingLine;

  static const Duration _pendingLineTimeout = Duration(seconds: 10);

  Offset? get pendingLineStart => _pendingLine?.start;
  int? get pendingLineTimestampMs => _pendingLine?.timestampMs;
  bool get hasPendingLineStart => _pendingLine != null;
  InteractiveDrawStyle? get pendingLineStyle => _pendingLine?.capturedStyle;

  Offset? get activeLinePreviewStart => _activeLinePreviewStart;
  Offset? get activeLinePreviewEnd => _activeLinePreviewEnd;

  void resetGestureState() {
    _setActiveLinePreview(null, null);
  }

  void resetOwnedState() {
    resetGestureState();
    _clearPendingLine();
  }

  void _clearPendingLine() {
    _setPendingLine(null);
  }

  bool clearPendingLineOwnedBy(PointerSessionToken? sessionToken) {
    final pendingLine = _pendingLine;
    if (pendingLine == null || pendingLine.sessionToken != sessionToken) {
      return false;
    }
    _clearPendingLine();
    return true;
  }

  bool detachPendingLine(PointerSessionToken token) {
    return clearPendingLineOwnedBy(token);
  }

  void dispose() {
    resetOwnedState();
  }

  void handleDown() {
    _setActiveLinePreview(null, null);
  }

  bool handleMove(
    Offset scenePoint, {
    required Offset? downScene,
    required bool moved,
    required PointerSessionToken? sessionToken,
    required double dragStartSlop,
  }) {
    if (downScene == null) return moved;
    if (!moved && isDistanceAtMost(downScene, scenePoint, dragStartSlop)) {
      return moved;
    }
    final didMove = true;
    clearPendingLineOwnedBy(sessionToken);
    _setActiveLinePreview(downScene, scenePoint);
    callbacks.onStateChanged();
    return didMove;
  }

  void commitOnUp(InteractiveDrawLineUp interaction) {
    final down = interaction.downScene;
    final capturedStyle = interaction.capturedStyle;
    if (down == null || capturedStyle == null) return;

    final isTap = isDistanceAtMost(
      down,
      interaction.scenePoint,
      interaction.dragStartSlop,
    );
    if (!isTap || interaction.moved) {
      _commitDraggedLine(interaction, down: down, style: capturedStyle);
      return;
    }

    final pendingLine = _pendingLine;
    if (pendingLine == null) {
      _setPendingLine(
        _createPendingLine(
          start: interaction.scenePoint,
          timestampMs: interaction.timestampMs,
          capturedStyle: capturedStyle,
          sessionToken: interaction.sessionToken,
        ),
      );
      return;
    }

    if (pendingLine.sessionToken != interaction.sessionToken) {
      _setPendingLine(
        _createPendingLine(
          start: interaction.scenePoint,
          timestampMs: interaction.timestampMs,
          capturedStyle: capturedStyle,
          sessionToken: interaction.sessionToken,
        ),
      );
      return;
    }

    _clearPendingLine();
    _emitLineCommit(
      timestampMs: interaction.timestampMs,
      start: pendingLine.start,
      end: interaction.scenePoint,
      style: pendingLine.capturedStyle,
    );
  }

  void _commitDraggedLine(
    InteractiveDrawLineUp interaction, {
    required Offset down,
    required InteractiveDrawStyle style,
  }) {
    _emitLineCommit(
      timestampMs: interaction.timestampMs,
      start: down,
      end: interaction.scenePoint,
      style: style,
    );
    clearPendingLineOwnedBy(interaction.sessionToken);
  }

  void _emitLineCommit({
    required int timestampMs,
    required Offset start,
    required Offset end,
    required InteractiveDrawStyle style,
  }) {
    final lineId = callbacks.commitDrawLineFromWorldSegment(
      start: start,
      end: end,
      thickness: style.lineThickness,
      color: style.drawColor,
      opacity: 1,
    );
    _actionEmitter.emitLineCommit(
      nodeId: lineId,
      timestampMs: timestampMs,
      style: style,
    );
  }

  void _setActiveLinePreview(Offset? start, Offset? end) {
    if (_activeLinePreviewStart == start && _activeLinePreviewEnd == end) {
      return;
    }
    _activeLinePreviewStart = start;
    _activeLinePreviewEnd = end;
    callbacks.onStateChanged();
  }

  _PendingLineState _createPendingLine({
    required Offset start,
    required int timestampMs,
    required InteractiveDrawStyle capturedStyle,
    required PointerSessionToken? sessionToken,
  }) {
    late final _PendingLineState pendingLine;
    final timeoutTimer = Timer(_pendingLineTimeout, () {
      if (identical(_pendingLine, pendingLine)) {
        _clearPendingLine();
      }
    });
    pendingLine = _PendingLineState(
      start: start,
      timestampMs: timestampMs,
      capturedStyle: capturedStyle,
      sessionToken: sessionToken,
      timeoutTimer: timeoutTimer,
    );
    return pendingLine;
  }

  void _setPendingLine(_PendingLineState? pendingLine) {
    if (_pendingLine == pendingLine) {
      return;
    }
    _pendingLine?.dispose();
    _pendingLine = pendingLine;
    callbacks.onStateChanged();
  }
}
