import 'dart:async';
import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../core/defaults.dart';
import '../core/geometry.dart';
import '../core/hit_test.dart';
import '../core/nodes.dart';
import '../core/scene.dart';
import 'action_events.dart';
import 'pointer_input.dart';

/// Interaction mode for the canvas.
enum CanvasMode { move, draw }

/// Active drawing tool when [CanvasMode.draw] is enabled.
enum DrawTool { pen, highlighter, line, eraser }

/// Mutable controller that owns the scene editing state and tool logic.
///
/// The controller is the primary integration point for apps:
/// - It mutates [scene] in response to pointer input and commands.
/// - It exposes selection state and marquee selection rectangle.
/// - It emits [actions] for app-level undo/redo integration.
/// - It emits [editTextRequests] when a text node should be edited.
class SceneController extends ChangeNotifier {
  /// Creates a controller that edits [scene].
  ///
  /// [nodeIdGenerator] lets you override how node IDs are produced for nodes
  /// created by this controller. By default, IDs are `node-{n}` with a
  /// per-controller counter and are guaranteed to be unique within the scene at
  /// generation time. If you override the generator, ensure IDs stay unique in
  /// the scene.
  SceneController({
    Scene? scene,
    PointerInputSettings? pointerSettings,
    double? dragStartSlop,
    NodeId Function()? nodeIdGenerator,
  }) : scene = scene ?? Scene(),
       pointerSettings = pointerSettings ?? const PointerInputSettings(),
       _dragStartSlop = dragStartSlop {
    _nodeIdGenerator = nodeIdGenerator ?? _defaultNodeIdGenerator;
  }

  final Scene scene;
  final PointerInputSettings pointerSettings;
  final double? _dragStartSlop;
  late final NodeId Function() _nodeIdGenerator;
  int _nodeIdSeed = 0;

  CanvasMode mode = CanvasMode.move;
  DrawTool drawTool = DrawTool.pen;
  Color drawColor = SceneDefaults.penColors.first;
  double penThickness = SceneDefaults.penThickness;
  double highlighterThickness = SceneDefaults.highlighterThickness;
  double lineThickness = SceneDefaults.penThickness;
  double eraserThickness = SceneDefaults.eraserThickness;
  double highlighterOpacity = SceneDefaults.highlighterOpacity;

  final LinkedHashSet<NodeId> _selectedNodeIds = LinkedHashSet<NodeId>();
  late final Set<NodeId> _selectedNodeIdsView = UnmodifiableSetView(
    _selectedNodeIds,
  );
  Rect? _selectionRect;

  final StreamController<ActionCommitted> _actions =
      StreamController<ActionCommitted>.broadcast(sync: true);
  final StreamController<EditTextRequested> _editTextRequests =
      StreamController<EditTextRequested>.broadcast(sync: true);
  int _actionCounter = 0;
  bool _repaintScheduled = false;
  int _repaintToken = 0;
  bool _isDisposed = false;
  bool _needsNotify = false;
  int _sceneRevision = 0;
  int _selectionRevision = 0;

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

  /// Synchronous broadcast stream of committed actions.
  ///
  /// Handlers must be fast and avoid blocking work.
  Stream<ActionCommitted> get actions => _actions.stream;

  /// Synchronous broadcast stream of text edit requests.
  ///
  /// Handlers must be fast and avoid blocking work.
  Stream<EditTextRequested> get editTextRequests => _editTextRequests.stream;

  /// Current selection snapshot.
  Set<NodeId> get selectedNodeIds => _selectedNodeIdsView;

  @visibleForTesting
  int get debugSceneRevision => _sceneRevision;

  @visibleForTesting
  int get debugSelectionRevision => _selectionRevision;

  /// Current marquee selection rectangle in scene coordinates.
  Rect? get selectionRect => _selectionRect;

  /// Pending first point for a two-tap line gesture, if any.
  Offset? get pendingLineStart => _pendingLineStart;

  /// Timestamp for the pending two-tap line start, if any.
  int? get pendingLineTimestampMs => _pendingLineTimestampMs;

  /// Whether a two-tap line start is waiting for the second tap.
  bool get hasPendingLineStart => _pendingLineStart != null;

  /// Pointer slop threshold used to treat a drag as a move.
  double get dragStartSlop => _dragStartSlop ?? pointerSettings.tapSlop;

  @visibleForTesting
  void debugSetSelection(Iterable<NodeId> nodeIds) {
    _selectedNodeIds
      ..clear()
      ..addAll(nodeIds);
  }

  @visibleForTesting
  void debugSetSelectionRect(Rect? rect) {
    _selectionRect = rect;
  }

  NodeId _defaultNodeIdGenerator() {
    while (true) {
      final id = 'node-$_nodeIdSeed';
      _nodeIdSeed += 1;
      if (!_sceneContainsNodeId(id)) {
        return id;
      }
    }
  }

  bool _sceneContainsNodeId(NodeId id) {
    for (final layer in scene.layers) {
      for (final node in layer.nodes) {
        if (node.id == id) return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cancelScheduledRepaint();
    _actions.close();
    _editTextRequests.close();
    super.dispose();
  }

  /// Switches between move and draw modes.
  void setMode(CanvasMode value) {
    if (mode == value) return;
    if (mode == CanvasMode.move) {
      _resetDrag(notify: false);
    } else {
      _resetDraw();
    }
    mode = value;
    _setSelectionRect(null, notify: false);
    _needsNotify = true;
    _notifyNow();
  }

  /// Changes the active drawing tool and resets draw state.
  void setDrawTool(DrawTool tool) {
    if (drawTool == tool) return;
    drawTool = tool;
    _resetDraw();
    _needsNotify = true;
    _notifyNow();
  }

  /// Sets the current drawing color.
  void setDrawColor(Color value) {
    if (drawColor == value) return;
    drawColor = value;
    _needsNotify = true;
    _notifyNow();
  }

  /// Updates the scene background color.
  void setBackgroundColor(Color value) {
    if (scene.background.color == value) return;
    scene.background.color = value;
    _needsNotify = true;
    _notifyNow();
  }

  /// Enables or disables the background grid.
  void setGridEnabled(bool value) {
    if (scene.background.grid.isEnabled == value) return;
    scene.background.grid.isEnabled = value;
    _needsNotify = true;
    _notifyNow();
  }

  /// Sets the grid cell size in scene units.
  void setGridCellSize(double value) {
    if (scene.background.grid.cellSize == value) return;
    scene.background.grid.cellSize = value;
    _needsNotify = true;
    _notifyNow();
  }

  /// Updates the scene camera offset.
  void setCameraOffset(Offset value) {
    _setCameraOffset(value);
  }

  /// Restores minimal invariants after external mutations to [scene].
  ///
  /// For example, it drops selection for nodes that were removed directly.
  void notifySceneChanged() {
    if (_selectedNodeIds.isNotEmpty) {
      final existingIds = <NodeId>{};
      for (final layer in scene.layers) {
        for (final node in layer.nodes) {
          existingIds.add(node.id);
        }
      }
      _setSelection(
        _selectedNodeIds.where(existingIds.contains),
        notify: false,
      );
    }
    _markSceneStructuralChanged();
    _notifyNow();
  }

  /// Adds [node] to the target layer and notifies listeners.
  ///
  /// Throws [RangeError] if [layerIndex] is out of bounds.
  void addNode(SceneNode node, {int layerIndex = 0}) {
    if (layerIndex < 0) {
      throw RangeError.range(layerIndex, 0, null, 'layerIndex');
    }

    if (scene.layers.isEmpty) {
      if (layerIndex != 0) {
        throw RangeError.range(layerIndex, 0, 0, 'layerIndex');
      }
      scene.layers.add(Layer());
    }

    if (layerIndex >= scene.layers.length) {
      throw RangeError.range(
        layerIndex,
        0,
        scene.layers.length - 1,
        'layerIndex',
      );
    }

    scene.layers[layerIndex].nodes.add(node);
    _markSceneStructuralChanged();
    _notifyNow();
  }

  /// Removes a node by [id], clears its selection, and emits an action.
  void removeNode(NodeId id, {int? timestampMs}) {
    for (final layer in scene.layers) {
      final index = layer.nodes.indexWhere((node) => node.id == id);
      if (index == -1) continue;

      layer.nodes.removeAt(index);
      _setSelection(
        _selectedNodeIds.where((candidate) => candidate != id),
        notify: false,
      );
      _markSceneStructuralChanged();
      _emitAction(ActionType.delete, [
        id,
      ], timestampMs ?? DateTime.now().millisecondsSinceEpoch);
      _notifyNow();
      return;
    }
  }

  /// Moves a node by [id] to another layer and emits an action.
  ///
  /// Throws [RangeError] if [targetLayerIndex] is out of bounds.
  void moveNode(NodeId id, {required int targetLayerIndex, int? timestampMs}) {
    if (scene.layers.isEmpty) {
      throw RangeError.range(targetLayerIndex, 0, 0, 'targetLayerIndex');
    }
    if (targetLayerIndex < 0 || targetLayerIndex >= scene.layers.length) {
      throw RangeError.range(
        targetLayerIndex,
        0,
        scene.layers.length - 1,
        'targetLayerIndex',
      );
    }

    for (var layerIndex = 0; layerIndex < scene.layers.length; layerIndex++) {
      final layer = scene.layers[layerIndex];
      final nodeIndex = layer.nodes.indexWhere((node) => node.id == id);
      if (nodeIndex == -1) continue;

      if (layerIndex == targetLayerIndex) return;

      final node = layer.nodes.removeAt(nodeIndex);
      scene.layers[targetLayerIndex].nodes.add(node);
      _markSceneStructuralChanged();
      _emitAction(
        ActionType.move,
        [id],
        timestampMs ?? DateTime.now().millisecondsSinceEpoch,
        payload: <String, Object?>{
          'sourceLayerIndex': layerIndex,
          'targetLayerIndex': targetLayerIndex,
        },
      );
      _notifyNow();
      return;
    }
  }

  /// Clears the current selection.
  void clearSelection() {
    if (_selectedNodeIds.isEmpty) return;
    _setSelection(const <NodeId>[], notify: false);
    _notifyNow();
  }

  /// Rotates the transformable selection by 90 degrees.
  void rotateSelection({required bool clockwise, int? timestampMs}) {
    final nodes = _selectedTransformableNodesInSceneOrder();
    if (nodes.isEmpty) return;

    final center = _selectionCenter(nodes);
    final delta = clockwise ? 90.0 : -90.0;
    for (final node in nodes) {
      _rotateNode(node, center, delta);
    }

    _emitAction(
      ActionType.rotate,
      nodes.map((node) => node.id).toList(growable: false),
      timestampMs ?? DateTime.now().millisecondsSinceEpoch,
      payload: <String, Object?>{'clockwise': clockwise},
    );
    _needsNotify = true;
    _notifyNow();
  }

  /// Flips the transformable selection horizontally around its center.
  void flipSelectionVertical({int? timestampMs}) {
    final nodes = _selectedTransformableNodesInSceneOrder();
    if (nodes.isEmpty) return;

    final center = _selectionCenter(nodes);
    for (final node in nodes) {
      _flipNodeVertical(node, center.dx);
    }

    _emitAction(
      ActionType.flip,
      nodes.map((node) => node.id).toList(growable: false),
      timestampMs ?? DateTime.now().millisecondsSinceEpoch,
      payload: const <String, Object?>{'axis': 'vertical'},
    );
    _needsNotify = true;
    _notifyNow();
  }

  /// Flips the transformable selection vertically around its center.
  void flipSelectionHorizontal({int? timestampMs}) {
    final nodes = _selectedTransformableNodesInSceneOrder();
    if (nodes.isEmpty) return;

    final center = _selectionCenter(nodes);
    for (final node in nodes) {
      _flipNodeHorizontal(node, center.dy);
    }

    _emitAction(
      ActionType.flip,
      nodes.map((node) => node.id).toList(growable: false),
      timestampMs ?? DateTime.now().millisecondsSinceEpoch,
      payload: const <String, Object?>{'axis': 'horizontal'},
    );
    _needsNotify = true;
    _notifyNow();
  }

  /// Deletes deletable selected nodes and emits an action.
  void deleteSelection({int? timestampMs}) {
    if (_selectedNodeIds.isEmpty) return;
    final deletableIds = <NodeId>[];

    for (final layer in scene.layers) {
      layer.nodes.removeWhere((node) {
        if (!_selectedNodeIds.contains(node.id)) return false;
        if (!node.isDeletable) return false;
        deletableIds.add(node.id);
        return true;
      });
    }

    if (deletableIds.isEmpty) return;
    _setSelection(
      _selectedNodeIds.where((id) => !deletableIds.contains(id)),
      notify: false,
    );
    _markSceneStructuralChanged();
    _emitAction(
      ActionType.delete,
      deletableIds,
      timestampMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    _notifyNow();
  }

  /// Clears all non-background layers and emits an action.
  void clearScene({int? timestampMs}) {
    final clearedIds = <NodeId>[];
    for (final layer in scene.layers) {
      if (layer.isBackground) continue;
      for (final node in layer.nodes) {
        clearedIds.add(node.id);
      }
      layer.nodes.clear();
    }

    if (clearedIds.isEmpty) return;
    _setSelection(const <NodeId>[], notify: false);
    _markSceneStructuralChanged();
    _emitAction(
      ActionType.clear,
      clearedIds,
      timestampMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    _notifyNow();
  }

  /// Handles a pointer sample and updates the controller state.
  void handlePointer(PointerSample sample) {
    if (mode == CanvasMode.move) {
      _handleMoveModePointer(sample);
    } else {
      _handleDrawModePointer(sample);
    }
  }

  /// Handles pointer signals such as double-tap text edit requests.
  void handlePointerSignal(PointerSignal signal) {
    if (signal.type != PointerSignalType.doubleTap) return;
    if (mode != CanvasMode.move) return;

    final scenePoint = toScene(signal.position, scene.camera.offset);
    final hit = hitTestTopNode(scene, scenePoint);
    if (hit is TextNode) {
      _editTextRequests.add(
        EditTextRequested(
          nodeId: hit.id,
          timestampMs: signal.timestampMs,
          position: signal.position,
        ),
      );
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
      requestRepaintOncePerFrame();
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
        _setSelection(const <NodeId>[], notify: false);
      }
    }

    _resetDrag(notify: false);
    if (_needsNotify) {
      _notifyNow();
    }
  }

  void _handleCancel() {
    _resetDrag(notify: false);
    if (_needsNotify) {
      _notifyNow();
    }
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
        requestRepaintOncePerFrame();
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
    if (_needsNotify) {
      _notifyNow();
    }
  }

  void _handleDrawCancel() {
    _resetDraw();
    if (_needsNotify) {
      _notifyNow();
    }
  }

  void _commitMove(int timestampMs, Offset scenePoint) {
    final movedNodeIds = _selectedMovableNodeIds();
    if (movedNodeIds.isNotEmpty) {
      final delta = scenePoint - (_pointerDownScene ?? scenePoint);
      _emitAction(
        ActionType.move,
        movedNodeIds,
        timestampMs,
        payload: <String, Object?>{'deltaX': delta.dx, 'deltaY': delta.dy},
      );
    }
  }

  void _commitMarquee(int timestampMs) {
    final rect = _normalizeRect(_selectionRect!);
    final selected = _nodesIntersecting(rect);
    _setSelectionRect(null, notify: false);
    _setSelection(selected, notify: false);
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
      opacity: drawTool == DrawTool.highlighter ? highlighterOpacity : 1,
    );
    _activeStroke = stroke;
    _activeLine = null;
    _activeDrawLayer = _ensureAnnotationLayer();
    _activeDrawLayer!.nodes.add(stroke);
    _markSceneStructuralChanged();
    requestRepaintOncePerFrame();
  }

  void _appendStrokePoint(Offset scenePoint) {
    final stroke = _activeStroke;
    if (stroke == null) return;
    if (stroke.points.isNotEmpty &&
        (scenePoint - stroke.points.last).distance == 0) {
      return;
    }
    stroke.points.add(scenePoint);
    requestRepaintOncePerFrame();
  }

  void _finishStroke(int timestampMs, Offset scenePoint) {
    final stroke = _activeStroke;
    if (stroke == null) return;
    var didMutateGeometry = false;
    if (stroke.points.isEmpty ||
        (scenePoint - stroke.points.last).distance > 0) {
      stroke.points.add(scenePoint);
      didMutateGeometry = true;
    }
    _activeStroke = null;
    _activeDrawLayer = null;
    if (didMutateGeometry) {
      _needsNotify = true;
    }
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
      _markSceneStructuralChanged();
    } else {
      _activeLine!.end = scenePoint;
    }
    requestRepaintOncePerFrame();
  }

  void _finishLineGesture(int timestampMs, Offset scenePoint) {
    if (_activeLine != null) {
      final line = _activeLine!;
      if (line.end != scenePoint) {
        line.end = scenePoint;
        _needsNotify = true;
      }
      _activeLine = null;
      _activeDrawLayer = null;
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

    final isTap = (scenePoint - _drawDownScene!).distance <= dragStartSlop;
    if (!isTap) return;

    if (_pendingLineStart == null) {
      _setPendingLineStart(scenePoint, timestampMs);
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
    _setPendingLineStart(null, null);
    _activeDrawLayer = _ensureAnnotationLayer();
    _activeDrawLayer!.nodes.add(line);
    _activeDrawLayer = null;
    _markSceneStructuralChanged();
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
    if (_eraserPoints.isNotEmpty &&
        (_eraserPoints.last - scenePoint).distance > 0) {
      _eraserPoints.add(scenePoint);
    }

    final deletedNodeIds = _eraseAnnotations(_eraserPoints);
    _eraserPoints.clear();
    if (deletedNodeIds.isEmpty) {
      return;
    }
    _markSceneStructuralChanged();
    _emitAction(
      ActionType.erase,
      deletedNodeIds,
      timestampMs,
      payload: <String, Object?>{'eraserThickness': eraserThickness},
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

  List<SceneNode> _selectedTransformableNodesInSceneOrder() {
    final nodes = <SceneNode>[];
    if (_selectedNodeIds.isEmpty) return nodes;

    for (final layer in scene.layers) {
      for (final node in layer.nodes) {
        if (!_selectedNodeIds.contains(node.id)) continue;
        if (!node.isTransformable) continue;
        nodes.add(node);
      }
    }
    return nodes;
  }

  Offset _selectionCenter(List<SceneNode> nodes) {
    Rect? bounds;
    for (final node in nodes) {
      final aabb = node.aabb;
      bounds = bounds == null ? aabb : bounds.expandToInclude(aabb);
    }
    return bounds?.center ?? Offset.zero;
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
    _selectionRevision++;
    _needsNotify = true;
    if (notify) {
      requestRepaintOncePerFrame();
    }
    return true;
  }

  void _setSelectionRect(Rect? rect, {bool notify = true}) {
    if (_selectionRect == rect) return;
    _selectionRect = rect;
    _needsNotify = true;
    if (notify) {
      requestRepaintOncePerFrame();
    }
  }

  void _resetDrag({bool notify = true}) {
    _activePointerId = null;
    _pointerDownScene = null;
    _lastDragScene = null;
    _dragTarget = _DragTarget.none;
    _dragMoved = false;
    _pendingClearSelection = false;
    _setSelectionRect(null, notify: false);
    if (notify) {
      requestRepaintOncePerFrame();
    }
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
      _markSceneStructuralChanged();
    }
    if (_activeLine != null && _activeDrawLayer != null) {
      _activeDrawLayer!.nodes.remove(_activeLine);
      _markSceneStructuralChanged();
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

  void _setPendingLineStart(Offset? start, int? timestampMs) {
    if (_pendingLineStart == start && _pendingLineTimestampMs == timestampMs) {
      return;
    }
    _pendingLineStart = start;
    _pendingLineTimestampMs = timestampMs;
    requestRepaintOncePerFrame();
  }

  void _clearPendingLine() {
    _setPendingLineStart(null, null);
  }

  void _expirePendingLine(int timestampMs) {
    final pendingTimestamp = _pendingLineTimestampMs;
    if (pendingTimestamp == null) return;
    if (timestampMs - pendingTimestamp > 10000) {
      _clearPendingLine();
    }
  }

  void _setCameraOffset(Offset value, {bool notify = true}) {
    if (scene.camera.offset == value) return;
    scene.camera.offset = value;
    _needsNotify = true;
    if (notify) {
      requestRepaintOncePerFrame();
    }
  }

  void _markSceneStructuralChanged() {
    _sceneRevision++;
    _needsNotify = true;
  }

  void _cancelScheduledRepaint() {
    _repaintScheduled = false;
    _repaintToken++;
  }

  void requestRepaintOncePerFrame() {
    if (_isDisposed) return;
    if (_repaintScheduled) return;

    _repaintScheduled = true;
    final token = ++_repaintToken;

    try {
      SchedulerBinding.instance.scheduleFrameCallback((_) {
        if (_isDisposed) return;
        if (token != _repaintToken) return;
        _repaintScheduled = false;
        _needsNotify = false;
        notifyListeners();
      });

      SchedulerBinding.instance.ensureVisualUpdate();
    } on FlutterError {
      // If no binding exists yet (e.g. in certain tests or during early init),
      // fall back to an immediate notification.
      _notifyNow();
    }
  }

  void _notifyNow() {
    _cancelScheduledRepaint();
    notifyListeners();
    _needsNotify = false;
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

  void _rotateNode(SceneNode node, Offset center, double delta) {
    if (node is LineNode) {
      node.start = rotatePoint(node.start, center, delta);
      node.end = rotatePoint(node.end, center, delta);
      return;
    }
    if (node is StrokeNode) {
      for (var i = 0; i < node.points.length; i++) {
        node.points[i] = rotatePoint(node.points[i], center, delta);
      }
      return;
    }
    node.position = rotatePoint(node.position, center, delta);
    node.rotationDeg += delta;
  }

  void _flipNodeVertical(SceneNode node, double axisX) {
    if (node is LineNode) {
      node.start = reflectPointVertical(node.start, axisX);
      node.end = reflectPointVertical(node.end, axisX);
      return;
    }
    if (node is StrokeNode) {
      for (var i = 0; i < node.points.length; i++) {
        node.points[i] = reflectPointVertical(node.points[i], axisX);
      }
      return;
    }
    node.position = reflectPointVertical(node.position, axisX);
    node.scaleX = -node.scaleX;
  }

  void _flipNodeHorizontal(SceneNode node, double axisY) {
    if (node is LineNode) {
      node.start = reflectPointHorizontal(node.start, axisY);
      node.end = reflectPointHorizontal(node.end, axisY);
      return;
    }
    if (node is StrokeNode) {
      for (var i = 0; i < node.points.length; i++) {
        node.points[i] = reflectPointHorizontal(node.points[i], axisY);
      }
      return;
    }
    node.position = reflectPointHorizontal(node.position, axisY);
    node.scaleY = -node.scaleY;
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
