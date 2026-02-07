import 'dart:ui' show Offset;

import '../../../../core/nodes.dart';
import '../../../../core/scene.dart';
import '../../../action_events.dart';
import '../../../internal/contracts.dart';
import '../../../types.dart';

class StrokeTool {
  StrokeTool(this._contracts, {required Layer Function() ensureAnnotationLayer})
    : _ensureAnnotationLayer = ensureAnnotationLayer;

  final InputSliceContracts _contracts;
  final Layer Function() _ensureAnnotationLayer;

  StrokeNode? _activeStroke;
  Layer? _activeDrawLayer;

  void handleDown(Offset scenePoint) {
    final drawTool = _contracts.drawTool;
    final drawColor = _contracts.drawColor;
    final stroke = StrokeNode(
      id: _contracts.newNodeId(),
      points: [scenePoint],
      thickness: _strokeThicknessForTool(),
      color: drawColor,
      opacity: drawTool == DrawTool.highlighter
          ? _contracts.highlighterOpacity
          : 1,
    );
    _activeStroke = stroke;
    _activeDrawLayer = _ensureAnnotationLayer();
    _activeDrawLayer!.nodes.add(stroke);
    _contracts.markSceneStructuralChanged();
    _contracts.requestRepaintOncePerFrame();
  }

  void handleMove(Offset scenePoint) {
    final stroke = _activeStroke;
    if (stroke == null) return;
    if (stroke.points.isNotEmpty &&
        (scenePoint - stroke.points.last).distance == 0) {
      return;
    }
    stroke.points.add(scenePoint);
    _contracts.requestRepaintOncePerFrame();
  }

  void handleUp(int timestampMs, Offset scenePoint) {
    final stroke = _activeStroke;
    if (stroke == null) return;
    if (stroke.points.isEmpty ||
        (scenePoint - stroke.points.last).distance > 0) {
      stroke.points.add(scenePoint);
    }
    try {
      stroke.normalizeToLocalCenter();
    } catch (_) {
      _abortActiveStroke();
      return;
    }
    _activeStroke = null;
    _activeDrawLayer = null;
    _contracts.markSceneGeometryChanged();
    final drawTool = _contracts.drawTool;
    final drawColor = _contracts.drawColor;
    _contracts.emitAction(
      drawTool == DrawTool.highlighter
          ? ActionType.drawHighlighter
          : ActionType.drawStroke,
      [stroke.id],
      timestampMs,
      payload: <String, Object?>{
        'tool': drawTool.name,
        'color': drawColor.toARGB32(),
        'thickness': stroke.thickness,
      },
    );
  }

  void reset() {
    if (_activeStroke != null && _activeDrawLayer != null) {
      _activeDrawLayer!.nodes.remove(_activeStroke);
      _contracts.markSceneStructuralChanged();
    }
    _activeStroke = null;
    _activeDrawLayer = null;
  }

  void _abortActiveStroke() {
    if (_activeStroke != null && _activeDrawLayer != null) {
      _activeDrawLayer!.nodes.remove(_activeStroke);
      _contracts.markSceneStructuralChanged();
    }
    _activeStroke = null;
    _activeDrawLayer = null;
  }

  double _strokeThicknessForTool() {
    final drawTool = _contracts.drawTool;
    return drawTool == DrawTool.highlighter
        ? _contracts.highlighterThickness
        : _contracts.penThickness;
  }
}
