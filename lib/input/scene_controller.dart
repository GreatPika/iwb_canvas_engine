import 'dart:async';
import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../core/defaults.dart';
import '../core/geometry.dart';
import '../core/hit_test.dart';
import '../core/nodes.dart';
import '../core/scene.dart';
import 'action_events.dart';
import 'pointer_input.dart';

enum CanvasMode { move, draw }

enum DrawTool { pen, highlighter, line, eraser }

class SceneController extends ChangeNotifier {
  SceneController({
    Scene? scene,
    PointerInputSettings? pointerSettings,
    double? dragStartSlop,
    NodeId Function()? nodeIdGenerator,
  })  : scene = scene ?? Scene(),
        pointerSettings = pointerSettings ?? const PointerInputSettings(),
        _dragStartSlop = dragStartSlop,
        _nodeIdGenerator = nodeIdGenerator ?? _defaultNodeIdGenerator;

  final Scene scene;
  final PointerInputSettings pointerSettings;
  final double? _dragStartSlop;
  final NodeId Function() _nodeIdGenerator;
  static int _nodeIdSeed = 0;

  CanvasMode mode = CanvasMode.move;
  DrawTool drawTool = DrawTool.pen;
  Color drawColor = SceneDefaults.penColors.first;
  double penThickness = SceneDefaults.penThickness;
  double highlighterThickness = SceneDefaults.highlighterThickness;
  double lineThickness = SceneDefaults.penThickness;
  double eraserThickness = SceneDefaults.eraserThickness;
  double highlighterOpacity = SceneDefaults.highlighterOpacity;

  final LinkedHashSet<NodeId> _selectedNodeIds = LinkedHashSet<NodeId>();
  Rect? _selectionRect;

  final StreamController<ActionCommitted> _actions =
      StreamController<ActionCommitted>.broadcast(sync: true);
  int _actionCounter = 0;

  int? _activePointerId;
  Offset? _pointerDownScene;
  Offset? _lastDragScene;
  _DragTarget _dragTarget = _DragTarget.none;
  bool _dragMoved = false;
  bool _pendingClearSelection = false;

  int? _drawPointerId;
  Offset? _drawDownScene;
  Offset? _lastDrawScene;
  bool _drawMoved = false;
  StrokeNode? _activeStroke;
  LineNode? _activeLine;
  Layer? _activeDrawLayer;
  final List<Offset> _eraserPoints = <Offset>[];

  Offset? _pendingLineStart;
  int? _pendingLineTimestampMs;

  Stream<ActionCommitted> get actions => _actions.stream;

  Set<NodeId> get selectedNodeIds => Set.unmodifiable(_selectedNodeIds);

  Rect? get selectionRect => _selectionRect;

  double get dragStartSlop => _dragStartSlop ?? pointerSettings.tapSlop;

  static NodeId _defaultNodeIdGenerator() {
    final id = _nodeIdSeed++;
    return 'node-$id';
  }

  @override
  void dispose() {
    _actions.close();
    super.dispose();
  }

  void setMode(CanvasMode value) {
    if (mode == value) return;
    if (mode == CanvasMode.move) {
      _resetDrag();
    } else {
      _resetDraw();
    }
    mode = value;
    _setSelectionRect(null);
    notifyListeners();
  }

  void setDrawTool(DrawTool tool) {
    if (drawTool == tool) return;
    drawTool = tool;
    _resetDraw();
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedNodeIds.isEmpty) return;
    _selectedNodeIds.clear();
    notifyListeners();
  }

  void handlePointer(PointerSample sample) {
    if (mode == CanvasMode.move) {
      _handleMoveModePointer(sample);
    } else {
      _handleDrawModePointer(sample);
    }
  }

  void _handleMoveModePointer(PointerSample sample) {
    if (_activePointerId != null && _activePointerId != sample.pointerId) {
      return;
    }

    final scenePoint = toScene(sample.position, scene.camera.offset);

    switch (sample.phase) {
      case PointerPhase.down:
        _handleDown(sample, scenePoint);
        break;
      case PointerPhase.move:
        _handleMove(sample, scenePoint);
        break;
      case PointerPhase.up:
        _handleUp(sample, scenePoint);
        break;
      case PointerPhase.cancel:
        _handleCancel();
        break;
    }
  }

  void _handleDrawModePointer(PointerSample sample) {
    if (_drawPointerId != null && _drawPointerId != sample.pointerId) {
      return;
    }

    _expirePendingLine(sample.timestampMs);
    final scenePoint = toScene(sample.position, scene.camera.offset);

    switch (sample.phase) {
      case PointerPhase.down:
        _handleDrawDown(sample, scenePoint);
        break;
      case PointerPhase.move:
        _handleDrawMove(sample, scenePoint);
        break;
      case PointerPhase.up:
        _handleDrawUp(sample, scenePoint);
        break;
      case PointerPhase.cancel:
        _handleDrawCancel();
        break;
    }
  }

  void _handleDown(PointerSample sample, Offset scenePoint) {
    _activePointerId = sample.pointerId;
    _pointerDownScene = scenePoint;
    _lastDragScene = scenePoint;
    _dragMoved = false;
    _pendingClearSelection = false;

    final hit = hitTestTopNode(scene, scenePoint);
    if (hit != null) {
      _dragTarget = _DragTarget.move;
      if (!_selectedNodeIds.contains(hit.id)) {
        _setSelection({hit.id});
      }
      return;
    }

    _dragTarget = _DragTarget.marquee;
    _pendingClearSelection = true;
  }

  void _handleMove(PointerSample sample, Offset scenePoint) {
    if (_activePointerId != sample.pointerId) return;
    if (_pointerDownScene == null || _lastDragScene == null) return;

    final totalDelta = scenePoint - _pointerDownScene!;
    if (!_dragMoved && totalDelta.distance > dragStartSlop) {
      _dragMoved = true;
      if (_dragTarget == _DragTarget.marquee) {
        if (_pendingClearSelection) {
          _selectedNodeIds.clear();
          _pendingClearSelection = false;
        }
      }
    }

    if (!_dragMoved) return;

    if (_dragTarget == _DragTarget.move) {
      final delta = scenePoint - _lastDragScene!;
      if (delta == Offset.zero) return;
      _applyMoveDelta(delta);
      _lastDragScene = scenePoint;
      notifyListeners();
      return;
    }

    if (_dragTarget == _DragTarget.marquee) {
      _setSelectionRect(Rect.fromPoints(_pointerDownScene!, scenePoint));
    }
  }

  void _handleUp(PointerSample sample, Offset scenePoint) {
    if (_activePointerId != sample.pointerId) return;

    if (_dragTarget == _DragTarget.move) {
      if (_dragMoved) {
        _commitMove(sample.timestampMs, scenePoint);
      }
    } else if (_dragTarget == _DragTarget.marquee) {
      if (_dragMoved && _selectionRect != null) {
        _commitMarquee(sample.timestampMs);
      } else if (_pendingClearSelection) {
        clearSelection();
      }
    }

    _resetDrag();
  }

  void _handleCancel() {
    _resetDrag();
  }

  void _handleDrawDown(PointerSample sample, Offset scenePoint) {
    _drawPointerId = sample.pointerId;
    _drawDownScene = scenePoint;
    _lastDrawScene = scenePoint;
    _drawMoved = false;

    switch (drawTool) {
      case DrawTool.pen:
      case DrawTool.highlighter:
        _startStroke(scenePoint);
        break;
      case DrawTool.line:
        _startLineGesture(scenePoint);
        break;
      case DrawTool.eraser:
        _eraserPoints
          ..clear()
          ..add(scenePoint);
        break;
    }
  }

  void _handleDrawMove(PointerSample sample, Offset scenePoint) {
    if (_drawPointerId != sample.pointerId) return;
    if (_drawDownScene == null || _lastDrawScene == null) return;

    final totalDelta = scenePoint - _drawDownScene!;
    if (!_drawMoved && totalDelta.distance > dragStartSlop) {
      _drawMoved = true;
    }

    switch (drawTool) {
      case DrawTool.pen:
      case DrawTool.highlighter:
        _appendStrokePoint(scenePoint);
        break;
      case DrawTool.line:
        _updateLineDrag(scenePoint);
        break;
      case DrawTool.eraser:
        _eraserPoints.add(scenePoint);
        break;
    }
    _lastDrawScene = scenePoint;
  }

  void _handleDrawUp(PointerSample sample, Offset scenePoint) {
    if (_drawPointerId != sample.pointerId) return;

    switch (drawTool) {
      case DrawTool.pen:
      case DrawTool.highlighter:
        _finishStroke(sample.timestampMs, scenePoint);
        break;
      case DrawTool.line:
        _finishLineGesture(sample.timestampMs, scenePoint);
        break;
      case DrawTool.eraser:
        _finishErase(sample.timestampMs, scenePoint);
        break;
    }

    _resetDrawPointer();
  }

  void _handleDrawCancel() {
    _resetDraw();
  }

  void _commitMove(int timestampMs, Offset scenePoint) {
    final movedNodeIds = _selectedMovableNodeIds();
    if (movedNodeIds.isNotEmpty) {
      final delta = scenePoint - (_pointerDownScene ?? scenePoint);
      _emitAction(
        ActionType.move,
        movedNodeIds,
        timestampMs,
        payload: <String, Object?>{
          'deltaX': delta.dx,
          'deltaY': delta.dy,
        },
      );
    }
  }

  void _commitMarquee(int timestampMs) {
    final rect = _normalizeRect(_selectionRect!);
    final selected = _nodesIntersecting(rect);
    _selectionRect = null;
    _setSelection(selected, notify: false);
    notifyListeners();
    _emitAction(ActionType.selectMarquee, selected, timestampMs);
  }

  void _applyMoveDelta(Offset delta) {
    if (delta == Offset.zero) return;

    for (final node in _selectedNodesInSceneOrder()) {
      if (node.isLocked) continue;
      node.position = node.position + delta;
    }
  }

  void _startStroke(Offset scenePoint) {
    final stroke = StrokeNode(
      id: _nodeIdGenerator(),
      points: [scenePoint],
      thickness: _strokeThicknessForTool(),
      color: drawColor,
      opacity: drawTool == DrawTool.highlighter
          ? highlighterOpacity
          : 1,
    );
    _activeStroke = stroke;
    _activeLine = null;
    _activeDrawLayer = _ensureAnnotationLayer();
    _activeDrawLayer!.nodes.add(stroke);
    notifyListeners();
  }

  void _appendStrokePoint(Offset scenePoint) {
    final stroke = _activeStroke;
    if (stroke == null) return;
    if (stroke.points.isNotEmpty &&
        (scenePoint - stroke.points.last).distance == 0) {
      return;
    }
    stroke.points.add(scenePoint);
    notifyListeners();
  }

  void _finishStroke(int timestampMs, Offset scenePoint) {
    final stroke = _activeStroke;
    if (stroke == null) return;
    if (stroke.points.isEmpty ||
        (scenePoint - stroke.points.last).distance > 0) {
      stroke.points.add(scenePoint);
    }
    _activeStroke = null;
    _activeDrawLayer = null;
    notifyListeners();
    _emitAction(
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

  void _startLineGesture(Offset scenePoint) {
    _activeLine = null;
    _activeStroke = null;
    _drawMoved = false;
    _drawDownScene = scenePoint;
  }

  void _updateLineDrag(Offset scenePoint) {
    if (_drawDownScene == null) return;
    final totalDelta = scenePoint - _drawDownScene!;
    if (!_drawMoved && totalDelta.distance <= dragStartSlop) {
      return;
    }

    if (_pendingLineStart != null) {
      _clearPendingLine();
    }

    if (_activeLine == null) {
      final line = LineNode(
        id: _nodeIdGenerator(),
        start: _drawDownScene!,
        end: scenePoint,
        thickness: lineThickness,
        color: drawColor,
      );
      _activeLine = line;
      _activeDrawLayer = _ensureAnnotationLayer();
      _activeDrawLayer!.nodes.add(line);
    } else {
      _activeLine!.end = scenePoint;
    }
    notifyListeners();
  }

  void _finishLineGesture(int timestampMs, Offset scenePoint) {
    if (_activeLine != null) {
      _activeLine!.end = scenePoint;
      final line = _activeLine!;
      _activeLine = null;
      _activeDrawLayer = null;
      notifyListeners();
      _emitAction(
        ActionType.drawLine,
        [line.id],
        timestampMs,
        payload: <String, Object?>{
          'tool': drawTool.name,
          'color': drawColor.toARGB32(),
          'thickness': line.thickness,
        },
      );
      return;
    }

    if (_drawDownScene == null) return;

    final isTap =
        (scenePoint - _drawDownScene!).distance <= dragStartSlop;
    if (!isTap) return;

    if (_pendingLineStart == null) {
      _pendingLineStart = scenePoint;
      _pendingLineTimestampMs = timestampMs;
      return;
    }

    final start = _pendingLineStart!;
    final line = LineNode(
      id: _nodeIdGenerator(),
      start: start,
      end: scenePoint,
      thickness: lineThickness,
      color: drawColor,
    );
    _pendingLineStart = null;
    _pendingLineTimestampMs = null;
    _activeDrawLayer = _ensureAnnotationLayer();
    _activeDrawLayer!.nodes.add(line);
    _activeDrawLayer = null;
    notifyListeners();
    _emitAction(
      ActionType.drawLine,
      [line.id],
      timestampMs,
      payload: <String, Object?>{
        'tool': drawTool.name,
        'color': drawColor.toARGB32(),
        'thickness': line.thickness,
      },
    );
  }

  void _finishErase(int timestampMs, Offset scenePoint) {
    if (_eraserPoints.isEmpty) {
      _eraserPoints.add(scenePoint);
    } else if ((_eraserPoints.last - scenePoint).distance > 0) {
      _eraserPoints.add(scenePoint);
    }

    final deletedNodeIds = _eraseAnnotations(_eraserPoints);
    _eraserPoints.clear();
    if (deletedNodeIds.isEmpty) {
      notifyListeners();
      return;
    }
    notifyListeners();
    _emitAction(
      ActionType.erase,
      deletedNodeIds,
      timestampMs,
      payload: <String, Object?>{
        'eraserThickness': eraserThickness,
      },
    );
  }

  List<NodeId> _eraseAnnotations(List<Offset> eraserPoints) {
    final deleted = <NodeId>[];
    if (eraserPoints.isEmpty) return deleted;

    for (final layer in scene.layers) {
      layer.nodes.removeWhere((node) {
        if (node is! StrokeNode && node is! LineNode) return false;
        if (!node.isDeletable) return false;
        final hit = _eraserHitsNode(eraserPoints, node);
        if (hit) {
          deleted.add(node.id);
        }
        return hit;
      });
    }
    return deleted;
  }

  bool _eraserHitsNode(List<Offset> eraserPoints, SceneNode node) {
    if (node is LineNode) {
      return _eraserHitsLine(eraserPoints, node);
    }
    if (node is StrokeNode) {
      return _eraserHitsStroke(eraserPoints, node);
    }
    return false;
  }

  bool _eraserHitsLine(List<Offset> eraserPoints, LineNode line) {
    final threshold = eraserThickness / 2 + line.thickness / 2;
    if (eraserPoints.length == 1) {
      final distance = distancePointToSegment(
        eraserPoints.first,
        line.start,
        line.end,
      );
      return distance <= threshold;
    }
    for (var i = 0; i < eraserPoints.length - 1; i++) {
      final a = eraserPoints[i];
      final b = eraserPoints[i + 1];
      final distance = distanceSegmentToSegment(a, b, line.start, line.end);
      if (distance <= threshold) {
        return true;
      }
    }
    return false;
  }

  bool _eraserHitsStroke(List<Offset> eraserPoints, StrokeNode stroke) {
    final threshold = eraserThickness / 2 + stroke.thickness / 2;
    if (stroke.points.isEmpty) return false;
    if (stroke.points.length == 1) {
      final point = stroke.points.first;
      for (final eraserPoint in eraserPoints) {
        if ((eraserPoint - point).distance <= threshold) {
          return true;
        }
      }
      return false;
    }

    if (eraserPoints.length == 1) {
      final eraserPoint = eraserPoints.first;
      for (var i = 0; i < stroke.points.length - 1; i++) {
        final a = stroke.points[i];
        final b = stroke.points[i + 1];
        final distance = distancePointToSegment(eraserPoint, a, b);
        if (distance <= threshold) {
          return true;
        }
      }
      return false;
    }

    for (var i = 0; i < eraserPoints.length - 1; i++) {
      final eraserA = eraserPoints[i];
      final eraserB = eraserPoints[i + 1];
      for (var j = 0; j < stroke.points.length - 1; j++) {
        final strokeA = stroke.points[j];
        final strokeB = stroke.points[j + 1];
        final distance = distanceSegmentToSegment(
          eraserA,
          eraserB,
          strokeA,
          strokeB,
        );
        if (distance <= threshold) {
          return true;
        }
      }
    }
    return false;
  }

  List<SceneNode> _selectedNodesInSceneOrder() {
    final nodes = <SceneNode>[];
    if (_selectedNodeIds.isEmpty) return nodes;

    for (final layer in scene.layers) {
      for (final node in layer.nodes) {
        if (_selectedNodeIds.contains(node.id)) {
          nodes.add(node);
        }
      }
    }
    return nodes;
  }

  List<NodeId> _selectedMovableNodeIds() {
    final ids = <NodeId>[];
    for (final node in _selectedNodesInSceneOrder()) {
      if (node.isLocked) continue;
      ids.add(node.id);
    }
    return ids;
  }

  List<NodeId> _nodesIntersecting(Rect rect) {
    final ids = <NodeId>[];
    for (final layer in scene.layers) {
      for (final node in layer.nodes) {
        if (!node.isVisible || !node.isSelectable) continue;
        if (node.aabb.overlaps(rect)) {
          ids.add(node.id);
        }
      }
    }
    return ids;
  }

  bool _setSelection(Iterable<NodeId> nodeIds, {bool notify = true}) {
    final next = LinkedHashSet<NodeId>.from(nodeIds);
    if (_selectedNodeIds.length == next.length &&
        _selectedNodeIds.containsAll(next)) {
      return false;
    }
    _selectedNodeIds
      ..clear()
      ..addAll(next);
    if (notify) {
      notifyListeners();
    }
    return true;
  }

  void _setSelectionRect(Rect? rect) {
    if (_selectionRect == rect) return;
    _selectionRect = rect;
    notifyListeners();
  }

  void _resetDrag() {
    _activePointerId = null;
    _pointerDownScene = null;
    _lastDragScene = null;
    _dragTarget = _DragTarget.none;
    _dragMoved = false;
    _pendingClearSelection = false;
    _setSelectionRect(null);
  }

  void _resetDrawPointer() {
    _drawPointerId = null;
    _drawDownScene = null;
    _lastDrawScene = null;
    _drawMoved = false;
  }

  void _resetDraw() {
    if (_activeStroke != null && _activeDrawLayer != null) {
      _activeDrawLayer!.nodes.remove(_activeStroke);
    }
    if (_activeLine != null && _activeDrawLayer != null) {
      _activeDrawLayer!.nodes.remove(_activeLine);
    }
    _activeStroke = null;
    _activeLine = null;
    _activeDrawLayer = null;
    _eraserPoints.clear();
    _resetDrawPointer();
    _clearPendingLine();
  }

  Layer _ensureAnnotationLayer() {
    for (var i = scene.layers.length - 1; i >= 0; i--) {
      final layer = scene.layers[i];
      if (!layer.isBackground) {
        return layer;
      }
    }
    final layer = Layer();
    scene.layers.add(layer);
    return layer;
  }

  double _strokeThicknessForTool() {
    return drawTool == DrawTool.highlighter
        ? highlighterThickness
        : penThickness;
  }

  void _clearPendingLine() {
    _pendingLineStart = null;
    _pendingLineTimestampMs = null;
  }

  void _expirePendingLine(int timestampMs) {
    final pendingTimestamp = _pendingLineTimestampMs;
    if (pendingTimestamp == null) return;
    if (timestampMs - pendingTimestamp > 10000) {
      _clearPendingLine();
    }
  }

  void _emitAction(
    ActionType type,
    List<NodeId> nodeIds,
    int timestampMs, {
    Map<String, Object?>? payload,
  }) {
    _actions.add(
      ActionCommitted(
        actionId: 'a${_actionCounter++}',
        type: type,
        nodeIds: List<NodeId>.from(nodeIds),
        timestampMs: timestampMs,
        payload: payload,
      ),
    );
  }
}

enum _DragTarget { none, move, marquee }

Rect _normalizeRect(Rect rect) {
  final left = rect.left < rect.right ? rect.left : rect.right;
  final right = rect.left < rect.right ? rect.right : rect.left;
  final top = rect.top < rect.bottom ? rect.top : rect.bottom;
  final bottom = rect.top < rect.bottom ? rect.bottom : rect.top;
  return Rect.fromLTRB(left, top, right, bottom);
}
