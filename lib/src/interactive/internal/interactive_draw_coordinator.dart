import 'dart:ui';

import '../../core/action_events.dart';
import '../../core/interaction_types.dart';
import '../../core/nodes.dart' show SceneNode;
import '../../core/pointer_input.dart';
import '../../core/scene_spatial_index.dart';
import '../../public/snapshot.dart';
import 'interactive_draw_eraser_engine.dart';
import 'interactive_draw_line_engine.dart';
import 'interactive_draw_stroke_engine.dart';

class InteractiveDrawCoordinatorCallbacks {
  const InteractiveDrawCoordinatorCallbacks({
    required this.onStateChanged,
    required this.emitAction,
    required this.writeDrawStroke,
    required this.writeDrawLineFromWorldSegment,
    required this.querySpatialCandidates,
    required this.resolveSpatialCandidateNode,
    required this.writeEraseNodes,
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
  final NodeId Function({required Offset start, required Offset end})
  writeDrawLineFromWorldSegment;
  final List<SceneSpatialCandidate> Function(Rect bounds)
  querySpatialCandidates;
  final SceneNode? Function(SceneSpatialCandidate candidate)
  resolveSpatialCandidateNode;
  final int Function(Iterable<NodeId> ids) writeEraseNodes;
}

class InteractiveDrawCoordinator {
  InteractiveDrawCoordinator({required this.callbacks}) {
    _strokeEngine = InteractiveDrawStrokeEngine(
      callbacks: InteractiveDrawStrokeEngineCallbacks(
        onStateChanged: callbacks.onStateChanged,
        emitAction: callbacks.emitAction,
        writeDrawStroke: callbacks.writeDrawStroke,
      ),
    );
    _lineEngine = InteractiveDrawLineEngine(
      callbacks: InteractiveDrawLineEngineCallbacks(
        onStateChanged: callbacks.onStateChanged,
        emitAction: callbacks.emitAction,
        writeDrawLineFromWorldSegment: callbacks.writeDrawLineFromWorldSegment,
      ),
    );
    _eraserEngine = InteractiveDrawEraserEngine(
      callbacks: InteractiveDrawEraserEngineCallbacks(
        onStateChanged: callbacks.onStateChanged,
        querySpatialCandidates: callbacks.querySpatialCandidates,
        resolveSpatialCandidateNode: callbacks.resolveSpatialCandidateNode,
        writeEraseNodes: callbacks.writeEraseNodes,
      ),
    );
  }

  final InteractiveDrawCoordinatorCallbacks callbacks;

  late final InteractiveDrawStrokeEngine _strokeEngine;
  late final InteractiveDrawLineEngine _lineEngine;
  late final InteractiveDrawEraserEngine _eraserEngine;

  int? _activePointerId;
  Offset? _downScene;
  bool _moved = false;

  bool get hasActivePointer => _activePointerId != null;

  Offset? get pendingLineStart => _lineEngine.pendingLineStart;
  int? get pendingLineTimestampMs => _lineEngine.pendingLineTimestampMs;
  bool get hasPendingLineStart => _lineEngine.hasPendingLineStart;

  List<Offset> get activeStrokePreviewPoints =>
      _strokeEngine.activeStrokePreviewPoints;
  bool get hasActiveStrokePoints => _strokeEngine.hasActiveStrokePoints;

  Offset? get activeLinePreviewStart => _lineEngine.activeLinePreviewStart;
  Offset? get activeLinePreviewEnd => _lineEngine.activeLinePreviewEnd;

  int get activeEraserPointsLength => _eraserEngine.activeEraserPointsLength;
  int get debugEraserSpatialQueryCount =>
      _eraserEngine.debugEraserSpatialQueryCount;
  int get debugEraserPreciseSegmentChecks =>
      _eraserEngine.debugEraserPreciseSegmentChecks;

  void handlePointer(
    PointerSample sample,
    Offset scenePoint, {
    required DrawTool drawTool,
    required Color drawColor,
    required double penThickness,
    required double highlighterThickness,
    required double lineThickness,
    required double eraserThickness,
    required double highlighterOpacity,
    required double dragStartSlop,
  }) {
    if (_activePointerId != null && _activePointerId != sample.pointerId) {
      return;
    }

    switch (sample.phase) {
      case PointerPhase.down:
        _handleDown(sample.pointerId, scenePoint, drawTool: drawTool);
        break;
      case PointerPhase.move:
        _handleMove(
          sample.pointerId,
          scenePoint,
          drawTool: drawTool,
          dragStartSlop: dragStartSlop,
        );
        break;
      case PointerPhase.up:
        _handleUp(
          sample.pointerId,
          sample.timestampMs,
          scenePoint,
          drawTool: drawTool,
          drawColor: drawColor,
          penThickness: penThickness,
          highlighterThickness: highlighterThickness,
          lineThickness: lineThickness,
          eraserThickness: eraserThickness,
          highlighterOpacity: highlighterOpacity,
          dragStartSlop: dragStartSlop,
        );
        break;
      case PointerPhase.cancel:
        clearPendingLine();
        resetGestureState();
        callbacks.onStateChanged();
        break;
    }
  }

  void resetGestureState() {
    _activePointerId = null;
    _downScene = null;
    _moved = false;
    _strokeEngine.resetGestureState();
    _eraserEngine.resetGestureState();
    _lineEngine.resetGestureState();
  }

  void clearPendingLine() {
    _lineEngine.clearPendingLine();
  }

  void dispose() {
    _lineEngine.dispose();
  }

  void _handleDown(
    int pointerId,
    Offset scenePoint, {
    required DrawTool drawTool,
  }) {
    _activePointerId = pointerId;
    _downScene = scenePoint;
    _moved = false;

    switch (drawTool) {
      case DrawTool.pen:
      case DrawTool.highlighter:
        _strokeEngine.handleDown(scenePoint);
        break;
      case DrawTool.line:
        _lineEngine.handleDown();
        break;
      case DrawTool.eraser:
        _eraserEngine.handleDown(scenePoint);
        break;
    }
  }

  void _handleMove(
    int pointerId,
    Offset scenePoint, {
    required DrawTool drawTool,
    required double dragStartSlop,
  }) {
    if (_activePointerId != pointerId) return;

    switch (drawTool) {
      case DrawTool.pen:
      case DrawTool.highlighter:
        _strokeEngine.handleMove(scenePoint);
        break;
      case DrawTool.line:
        _moved = _lineEngine.handleMove(
          scenePoint,
          downScene: _downScene,
          moved: _moved,
          dragStartSlop: dragStartSlop,
        );
        break;
      case DrawTool.eraser:
        _eraserEngine.handleMove(scenePoint);
        break;
    }
  }

  void _handleUp(
    int pointerId,
    int timestampMs,
    Offset scenePoint, {
    required DrawTool drawTool,
    required Color drawColor,
    required double penThickness,
    required double highlighterThickness,
    required double lineThickness,
    required double eraserThickness,
    required double highlighterOpacity,
    required double dragStartSlop,
  }) {
    if (_activePointerId != pointerId) return;

    switch (drawTool) {
      case DrawTool.pen:
      case DrawTool.highlighter:
        _strokeEngine.commitOnUp(
          timestampMs,
          scenePoint,
          drawTool: drawTool,
          drawColor: drawColor,
          penThickness: penThickness,
          highlighterThickness: highlighterThickness,
          highlighterOpacity: highlighterOpacity,
        );
        break;
      case DrawTool.line:
        _lineEngine.commitOnUp(
          timestampMs,
          scenePoint,
          downScene: _downScene,
          moved: _moved,
          drawTool: drawTool,
          drawColor: drawColor,
          lineThickness: lineThickness,
          dragStartSlop: dragStartSlop,
        );
        break;
      case DrawTool.eraser:
        final deletedIds = _eraserEngine.commitOnUp(
          scenePoint,
          eraserThickness: eraserThickness,
        );
        if (deletedIds.isNotEmpty) {
          callbacks.emitAction(
            ActionType.erase,
            deletedIds,
            timestampMs,
            payload: <String, Object?>{'eraserThickness': eraserThickness},
          );
        }
        break;
    }

    _activePointerId = null;
    _downScene = null;
    _moved = false;
    _lineEngine.resetGestureState();
  }
}
