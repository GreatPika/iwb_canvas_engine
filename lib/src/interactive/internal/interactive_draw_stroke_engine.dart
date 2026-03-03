import 'dart:collection';
import 'dart:ui';

import '../../core/action_events.dart';
import '../../core/input_sampling.dart';
import '../../core/interaction_types.dart';
import '../../core/scene_limits.dart';
import '../../public/snapshot.dart';
import 'interactive_geometry.dart';

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

  final List<Offset> _activeStrokePoints = <Offset>[];
  late final UnmodifiableListView<Offset> _activeStrokePointsView =
      UnmodifiableListView<Offset>(_activeStrokePoints);

  List<Offset> get activeStrokePreviewPoints => _activeStrokePointsView;
  bool get hasActiveStrokePoints => _activeStrokePoints.isNotEmpty;

  void resetGestureState() {
    _activeStrokePoints.clear();
  }

  void handleDown(Offset scenePoint) {
    _activeStrokePoints
      ..clear()
      ..add(scenePoint);
  }

  void handleMove(Offset scenePoint) {
    if (_activeStrokePoints.isEmpty) return;
    if (!isDistanceAtLeast(
      _activeStrokePoints.last,
      scenePoint,
      kInputDecimationMinStepScene,
    )) {
      return;
    }
    _activeStrokePoints.add(scenePoint);
    enforceGestureBufferSoftLimit(
      _activeStrokePoints,
      softLimit: kInteractiveStrokePointsSoftLimit,
      trimTo: kInteractiveStrokePointsTrimTo,
    );
    callbacks.onStateChanged();
  }

  void commitOnUp(
    int timestampMs,
    Offset scenePoint, {
    required DrawTool drawTool,
    required Color drawColor,
    required double penThickness,
    required double highlighterThickness,
    required double highlighterOpacity,
  }) {
    if (_activeStrokePoints.isEmpty) return;
    if (isDistanceGreaterThan(_activeStrokePoints.last, scenePoint, 0)) {
      _activeStrokePoints.add(scenePoint);
    }

    final committedPoints = resamplePointsToLimit(
      _activeStrokePoints,
      limit: kMaxStrokePointsPerNode,
    );
    final strokeId = callbacks.writeDrawStroke(
      points: committedPoints,
      thickness: drawTool == DrawTool.highlighter
          ? highlighterThickness
          : penThickness,
      color: drawColor,
      opacity: drawTool == DrawTool.highlighter ? highlighterOpacity : 1,
    );

    callbacks.emitAction(
      drawTool == DrawTool.highlighter
          ? ActionType.drawHighlighter
          : ActionType.drawStroke,
      <NodeId>[strokeId],
      timestampMs,
      payload: <String, Object?>{
        'tool': drawTool.name,
        'color': drawColor.toARGB32(),
        'thickness': drawTool == DrawTool.highlighter
            ? highlighterThickness
            : penThickness,
      },
    );

    _activeStrokePoints.clear();
  }
}
