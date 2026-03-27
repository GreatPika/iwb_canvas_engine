import 'dart:async';
import 'dart:ui';

import '../../core/action_events.dart';
import '../../core/input_sampling.dart';
import '../../contract/snapshot.dart';
import 'interactive_draw_action_emitter.dart';
import 'interactive_draw_style.dart';

typedef InteractiveDrawLineUp = ({
  int timestampMs,
  Offset scenePoint,
  Offset? downScene,
  bool moved,
  double dragStartSlop,
});

class InteractiveDrawLineEngineCallbacks {
  const InteractiveDrawLineEngineCallbacks({
    required this.onStateChanged,
    required this.emitAction,
    required this.writeDrawLineFromWorldSegment,
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
  writeDrawLineFromWorldSegment;
}

class InteractiveDrawLineEngine {
  InteractiveDrawLineEngine({required this.callbacks});

  final InteractiveDrawLineEngineCallbacks callbacks;
  late final InteractiveDrawActionEmitter _actionEmitter =
      InteractiveDrawActionEmitter(emitAction: callbacks.emitAction);

  Offset? _activeLinePreviewStart;
  Offset? _activeLinePreviewEnd;

  Offset? _pendingLineStart;
  int? _pendingLineTimestampMs;
  Timer? _pendingLineTimer;

  static const Duration _pendingLineTimeout = Duration(seconds: 10);

  Offset? get pendingLineStart => _pendingLineStart;
  int? get pendingLineTimestampMs => _pendingLineTimestampMs;
  bool get hasPendingLineStart => _pendingLineStart != null;

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
    _setPendingLineStart(null, null);
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
    required double dragStartSlop,
  }) {
    if (downScene == null) return moved;
    if (!moved && isDistanceAtMost(downScene, scenePoint, dragStartSlop)) {
      return moved;
    }
    final didMove = true;
    if (_pendingLineStart != null) {
      _clearPendingLine();
    }
    _setActiveLinePreview(downScene, scenePoint);
    callbacks.onStateChanged();
    return didMove;
  }

  void commitOnUp(
    InteractiveDrawLineUp interaction, {
    required InteractiveDrawStyle style,
  }) {
    final down = interaction.downScene;
    if (down == null) return;

    final isTap = isDistanceAtMost(
      down,
      interaction.scenePoint,
      interaction.dragStartSlop,
    );
    if (!isTap || interaction.moved) {
      _commitDraggedLine(interaction, down: down, style: style);
      return;
    }

    if (_pendingLineStart == null) {
      _setPendingLineStart(interaction.scenePoint, interaction.timestampMs);
      return;
    }

    final start = _pendingLineStart;
    if (start == null) return;
    _clearPendingLine();
    _emitLineCommit(
      timestampMs: interaction.timestampMs,
      start: start,
      end: interaction.scenePoint,
      style: style,
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
    _clearPendingLine();
  }

  void _emitLineCommit({
    required int timestampMs,
    required Offset start,
    required Offset end,
    required InteractiveDrawStyle style,
  }) {
    final lineId = callbacks.writeDrawLineFromWorldSegment(
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

  void _setPendingLineStart(Offset? start, int? timestampMs) {
    if (_pendingLineStart == start && _pendingLineTimestampMs == timestampMs) {
      return;
    }
    _pendingLineTimer?.cancel();
    _pendingLineTimer = null;
    _pendingLineStart = start;
    _pendingLineTimestampMs = timestampMs;
    if (_pendingLineStart != null) {
      _pendingLineTimer = Timer(_pendingLineTimeout, _clearPendingLine);
    }
    callbacks.onStateChanged();
  }
}
