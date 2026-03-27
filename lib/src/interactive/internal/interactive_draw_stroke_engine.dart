import 'dart:ui';

import '../../core/action_events.dart';
import '../../core/input_sampling.dart';
import '../../core/interaction_types.dart';
import '../../core/scene_limits.dart';
import '../../contract/snapshot.dart';
import 'interactive_draw_action_emitter.dart';
import 'interactive_draw_path_buffer.dart';
import 'interactive_draw_style.dart';

class InteractiveDrawStrokeEngineCallbacks {
  const InteractiveDrawStrokeEngineCallbacks({
    required this.onStateChanged,
    required this.emitAction,
    required this.writeDrawStroke,
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
    required List<Offset> points,
    required double thickness,
    required Color color,
    required double opacity,
  })
  writeDrawStroke;
}

class InteractiveDrawStrokeEngine {
  InteractiveDrawStrokeEngine({required this.callbacks});

  final InteractiveDrawStrokeEngineCallbacks callbacks;
  late final InteractiveDrawActionEmitter _actionEmitter =
      InteractiveDrawActionEmitter(emitAction: callbacks.emitAction);

  final InteractiveDrawPathBuffer _pathBuffer = InteractiveDrawPathBuffer(
    softLimit: kInteractiveStrokePointsSoftLimit,
    trimTo: kInteractiveStrokePointsTrimTo,
  );

  List<Offset> get activeStrokePreviewPoints => _pathBuffer.points;
  bool get hasActiveStrokePoints => _pathBuffer.isNotEmpty;

  void resetGestureState() {
    _pathBuffer.clear();
  }

  void handleDown(Offset scenePoint) {
    _pathBuffer.start(scenePoint);
  }

  void handleMove(Offset scenePoint) {
    if (!_pathBuffer.appendMovePoint(scenePoint)) return;
    callbacks.onStateChanged();
  }

  void commitOnUp(
    int timestampMs,
    Offset scenePoint, {
    required InteractiveDrawStyle style,
  }) {
    if (_pathBuffer.isEmpty) return;
    _pathBuffer.appendTerminalPoint(scenePoint);

    final committedPoints = resamplePointsToLimit(
      _pathBuffer.points,
      limit: kMaxStrokePointsPerNode,
    );
    final isHighlighter = style.drawTool == DrawTool.highlighter;
    final thickness = isHighlighter
        ? style.highlighterThickness
        : style.penThickness;
    final strokeId = callbacks.writeDrawStroke(
      points: committedPoints,
      thickness: thickness,
      color: style.drawColor,
      opacity: isHighlighter ? style.highlighterOpacity : 1,
    );

    _actionEmitter.emitStrokeCommit(
      nodeId: strokeId,
      timestampMs: timestampMs,
      style: style,
      isHighlighter: isHighlighter,
      thickness: thickness,
    );

    _pathBuffer.clear();
  }
}
