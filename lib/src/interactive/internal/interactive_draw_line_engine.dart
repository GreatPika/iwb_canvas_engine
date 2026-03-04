import 'dart:async';
import 'dart:ui';

import '../../core/action_events.dart';
import '../../core/input_sampling.dart';
import '../../core/interaction_types.dart';
import '../../contract/snapshot.dart';

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
  final NodeId Function({required Offset start, required Offset end})
  writeDrawLineFromWorldSegment;
}

class InteractiveDrawLineEngine {
  InteractiveDrawLineEngine({required this.callbacks});

  final InteractiveDrawLineEngineCallbacks callbacks;

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

  void clearPendingLine() {
    _setPendingLineStart(null, null);
  }

  void dispose() {
    _pendingLineTimer?.cancel();
    _pendingLineTimer = null;
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
      clearPendingLine();
    }
    _setActiveLinePreview(downScene, scenePoint);
    callbacks.onStateChanged();
    return didMove;
  }

  void commitOnUp(
    int timestampMs,
    Offset scenePoint, {
    required Offset? downScene,
    required bool moved,
    required DrawTool drawTool,
    required Color drawColor,
    required double lineThickness,
    required double dragStartSlop,
  }) {
    final down = downScene;
    if (down == null) return;

    final isTap = isDistanceAtMost(down, scenePoint, dragStartSlop);
    if (!isTap || moved) {
      final lineId = callbacks.writeDrawLineFromWorldSegment(
        start: down,
        end: scenePoint,
      );
      callbacks.emitAction(
        ActionType.drawLine,
        <NodeId>[lineId],
        timestampMs,
        payload: <String, Object?>{
          'tool': drawTool.name,
          'color': drawColor.toARGB32(),
          'thickness': lineThickness,
        },
      );
      clearPendingLine();
      return;
    }

    if (_pendingLineStart == null) {
      _setPendingLineStart(scenePoint, timestampMs);
      return;
    }

    final start = _pendingLineStart!;
    clearPendingLine();
    final lineId = callbacks.writeDrawLineFromWorldSegment(
      start: start,
      end: scenePoint,
    );
    callbacks.emitAction(
      ActionType.drawLine,
      <NodeId>[lineId],
      timestampMs,
      payload: <String, Object?>{
        'tool': drawTool.name,
        'color': drawColor.toARGB32(),
        'thickness': lineThickness,
      },
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
      _pendingLineTimer = Timer(_pendingLineTimeout, clearPendingLine);
    }
    callbacks.onStateChanged();
  }
}
