import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../core/defaults.dart';
import '../core/geometry.dart';
import '../core/hit_test.dart';
import '../core/nodes.dart';
import '../core/scene.dart';
import '../core/transform2d.dart';
import 'action_events.dart';
import 'internal/contracts.dart';
import 'pointer_input.dart';
import 'slices/move/move_mode_engine.dart';
import 'slices/repaint/repaint_scheduler.dart';
import 'slices/selection/selection_model.dart';
import 'slices/signals/action_dispatcher.dart';
import 'types.dart';

export 'types.dart';

double _maxSingularValue2x2(double a, double b, double c, double d) {
  final t = a * a + b * b + c * c + d * d;
  final det = a * d - b * c;
  final discSquared = t * t - 4 * det * det;
  final disc = math.sqrt(math.max(0, discSquared));
  final lambdaMax = (t + disc) / 2;
  return math.sqrt(math.max(0, lambdaMax));
}

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
    _repaintScheduler = RepaintScheduler(notifyListeners: notifyListeners);
    _actionDispatcher = ActionDispatcher();
    _selectionModel = SelectionModel();
    _moveModeEngine = MoveModeEngine(_contracts);
  }

  final Scene scene;
  final PointerInputSettings pointerSettings;
  final double? _dragStartSlop;
  late final InputSliceContracts _contracts = _SceneControllerContracts(this);
  late final NodeId Function() _nodeIdGenerator;
  late final RepaintScheduler _repaintScheduler;
  late final ActionDispatcher _actionDispatcher;
  late final SelectionModel _selectionModel;
  late final MoveModeEngine _moveModeEngine;
  int _nodeIdSeed = 0;

  CanvasMode _mode = CanvasMode.move;
  DrawTool _drawTool = DrawTool.pen;
  Color _drawColor = SceneDefaults.penColors.first;
  double _penThickness = SceneDefaults.penThickness;
  double _highlighterThickness = SceneDefaults.highlighterThickness;
  double _lineThickness = SceneDefaults.penThickness;
  double _eraserThickness = SceneDefaults.eraserThickness;
  double _highlighterOpacity = SceneDefaults.highlighterOpacity;

  CanvasMode get mode => _mode;

  DrawTool get drawTool => _drawTool;

  Color get drawColor => _drawColor;

  double get penThickness => _penThickness;
  set penThickness(double value) {
    if (_penThickness == value) return;
    _penThickness = value;
    _contracts.markSceneGeometryChanged();
    _contracts.requestRepaintOncePerFrame();
  }

  double get highlighterThickness => _highlighterThickness;
  set highlighterThickness(double value) {
    if (_highlighterThickness == value) return;
    _highlighterThickness = value;
    _contracts.markSceneGeometryChanged();
    _contracts.requestRepaintOncePerFrame();
  }

  double get lineThickness => _lineThickness;
  set lineThickness(double value) {
    if (_lineThickness == value) return;
    _lineThickness = value;
    _contracts.markSceneGeometryChanged();
    _contracts.requestRepaintOncePerFrame();
  }

  double get eraserThickness => _eraserThickness;
  set eraserThickness(double value) {
    if (_eraserThickness == value) return;
    _eraserThickness = value;
    _contracts.markSceneGeometryChanged();
    _contracts.requestRepaintOncePerFrame();
  }

  double get highlighterOpacity => _highlighterOpacity;
  set highlighterOpacity(double value) {
    if (_highlighterOpacity == value) return;
    _highlighterOpacity = value;
    _contracts.markSceneGeometryChanged();
    _contracts.requestRepaintOncePerFrame();
  }

  int _sceneRevision = 0;

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
  Stream<ActionCommitted> get actions => _actionDispatcher.actions;

  /// Synchronous broadcast stream of text edit requests.
  ///
  /// Handlers must be fast and avoid blocking work.
  Stream<EditTextRequested> get editTextRequests =>
      _actionDispatcher.editTextRequests;

  /// Current selection snapshot.
  Set<NodeId> get selectedNodeIds => _selectionModel.selectedNodeIds;

  @visibleForTesting
  int get debugSceneRevision => _sceneRevision;

  @visibleForTesting
  int get debugSelectionRevision => _selectionModel.selectionRevision;

  @visibleForTesting
  int get debugMoveGestureBuildCount =>
      _moveModeEngine.debugMoveGestureBuildCount;

  @visibleForTesting
  List<SceneNode>? get debugMoveGestureNodes =>
      _moveModeEngine.debugMoveGestureNodes;

  /// Current marquee selection rectangle in scene coordinates.
  Rect? get selectionRect => _selectionModel.selectionRect;

  /// Axis-aligned world bounds of the current transformable selection.
  ///
  /// Returns `null` when no transformable, unlocked nodes are selected.
  Rect? get selectionBoundsWorld {
    final nodes = _selectedTransformableNodesInSceneOrder()
        .where((node) => !node.isLocked)
        .toList(growable: false);
    if (nodes.isEmpty) return null;
    Rect? bounds;
    for (final node in nodes) {
      final nodeBounds = node.boundsWorld;
      bounds = bounds == null ? nodeBounds : bounds.expandToInclude(nodeBounds);
    }
    return bounds;
  }

  /// Center of [selectionBoundsWorld] when selection is non-empty.
  Offset? get selectionCenterWorld => selectionBoundsWorld?.center;

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
    _selectionModel.debugSetSelection(nodeIds);
  }

  @visibleForTesting
  void debugSetSelectionRect(Rect? rect) {
    _selectionModel.debugSetSelectionRect(rect);
  }

  /// Returns the first node with [id], or `null` if it does not exist.
  SceneNode? getNode(NodeId id) => findNode(id)?.node;

  /// Finds a node by [id] and returns its location in the scene.
  ///
  /// Returns `null` when the node is not present.
  ({SceneNode node, int layerIndex, int nodeIndex})? findNode(NodeId id) {
    for (var layerIndex = 0; layerIndex < scene.layers.length; layerIndex++) {
      final layer = scene.layers[layerIndex];
      for (var nodeIndex = 0; nodeIndex < layer.nodes.length; nodeIndex++) {
        final node = layer.nodes[nodeIndex];
        if (node.id == id) {
          return (node: node, layerIndex: layerIndex, nodeIndex: nodeIndex);
        }
      }
    }
    return null;
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
    _repaintScheduler.dispose();
    _actionDispatcher.dispose();
    super.dispose();
  }

  /// Switches between move and draw modes.
  void setMode(CanvasMode value) {
    if (_mode == value) return;
    if (_mode == CanvasMode.move) {
      _resetDrag();
    } else {
      _resetDraw();
    }
    _mode = value;
    _contracts.setSelectionRect(null, notify: false);
    _contracts.markSceneGeometryChanged();
    _contracts.notifyNow();
  }

  /// Changes the active drawing tool and resets draw state.
  void setDrawTool(DrawTool tool) {
    if (_drawTool == tool) return;
    _drawTool = tool;
    _resetDraw();
    _contracts.markSceneGeometryChanged();
    _contracts.notifyNow();
  }

  /// Sets the current drawing color.
  void setDrawColor(Color value) {
    if (_drawColor == value) return;
    _drawColor = value;
    _contracts.markSceneGeometryChanged();
    _contracts.notifyNow();
  }

  /// Updates the scene background color.
  void setBackgroundColor(Color value) {
    if (scene.background.color == value) return;
    scene.background.color = value;
    _contracts.markSceneGeometryChanged();
    _contracts.notifyNow();
  }

  /// Enables or disables the background grid.
  void setGridEnabled(bool value) {
    if (scene.background.grid.isEnabled == value) return;
    scene.background.grid.isEnabled = value;
    _contracts.markSceneGeometryChanged();
    _contracts.notifyNow();
  }

  /// Sets the grid cell size in scene units.
  void setGridCellSize(double value) {
    if (scene.background.grid.cellSize == value) return;
    scene.background.grid.cellSize = value;
    _contracts.markSceneGeometryChanged();
    _contracts.notifyNow();
  }

  /// Updates the scene camera offset.
  void setCameraOffset(Offset value) {
    _setCameraOffset(value);
  }

  /// Restores minimal invariants after external mutations to [scene].
  ///
  /// For example, it drops selection for nodes that were removed directly.
  void notifySceneChanged() {
    final selectedNodeIds = _selectionModel.selectedNodeIds;
    if (selectedNodeIds.isNotEmpty) {
      final existingIds = <NodeId>{};
      for (final layer in scene.layers) {
        for (final node in layer.nodes) {
          existingIds.add(node.id);
        }
      }
      _contracts.setSelection(
        selectedNodeIds.where(existingIds.contains),
        notify: false,
      );
    }
    _contracts.markSceneStructuralChanged();
    _contracts.notifyNow();
  }

  /// Runs [fn] to mutate [scene] and schedules the appropriate updates.
  ///
  /// Prefer this helper over touching `scene.layers` directly:
  /// - When [structural] is true (add/remove/reorder nodes/layers), this calls
  ///   [notifySceneChanged] to restore minimal invariants (e.g. selection).
  /// - When [structural] is false (geometry-only changes), this schedules a
  ///   repaint once per frame.
  void mutate(void Function(Scene scene) fn, {bool structural = false}) {
    fn(scene);
    if (structural) {
      notifySceneChanged();
      return;
    }
    _contracts.markSceneGeometryChanged();
    _contracts.requestRepaintOncePerFrame();
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
    _contracts.markSceneStructuralChanged();
    _contracts.notifyNow();
  }

  /// Removes a node by [id], clears its selection, and emits an action.
  void removeNode(NodeId id, {int? timestampMs}) {
    for (final layer in scene.layers) {
      final index = layer.nodes.indexWhere((node) => node.id == id);
      if (index == -1) continue;

      layer.nodes.removeAt(index);
      _contracts.setSelection(
        _selectionModel.selectedNodeIds.where((candidate) => candidate != id),
        notify: false,
      );
      _contracts.markSceneStructuralChanged();
      _contracts.emitAction(ActionType.delete, [
        id,
      ], timestampMs ?? DateTime.now().millisecondsSinceEpoch);
      _contracts.notifyNow();
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
      _contracts.markSceneStructuralChanged();
      _contracts.emitAction(
        ActionType.move,
        [id],
        timestampMs ?? DateTime.now().millisecondsSinceEpoch,
        payload: <String, Object?>{
          'sourceLayerIndex': layerIndex,
          'targetLayerIndex': targetLayerIndex,
        },
      );
      _contracts.notifyNow();
      return;
    }
  }

  /// Clears the current selection.
  void clearSelection() {
    if (_selectionModel.selectedNodeIds.isEmpty) return;
    _contracts.setSelection(const <NodeId>[], notify: false);
    _contracts.notifyNow();
  }

  /// Replaces the selection with [nodeIds].
  ///
  /// This is intended for app-driven selection UIs (layers panel, object list).
  void setSelection(Iterable<NodeId> nodeIds) {
    _contracts.setSelection(nodeIds);
  }

  /// Toggles selection for a single node [id].
  void toggleSelection(NodeId id) {
    final selectedNodeIds = _selectionModel.selectedNodeIds;
    if (selectedNodeIds.contains(id)) {
      _contracts.setSelection(
        selectedNodeIds.where((candidate) => candidate != id),
      );
    } else {
      _contracts.setSelection(<NodeId>[...selectedNodeIds, id]);
    }
  }

  /// Selects all nodes in the scene.
  ///
  /// When [onlySelectable] is true, includes only nodes with `isSelectable`.
  void selectAll({bool onlySelectable = true}) {
    final ids = <NodeId>[];
    for (final layer in scene.layers) {
      for (final node in layer.nodes) {
        if (!node.isVisible) continue;
        if (onlySelectable && !node.isSelectable) continue;
        ids.add(node.id);
      }
    }
    _contracts.setSelection(ids);
  }

  /// Rotates the transformable selection by 90 degrees.
  void rotateSelection({required bool clockwise, int? timestampMs}) {
    final nodes = _selectedTransformableNodesInSceneOrder()
        .where((node) => !node.isLocked)
        .toList(growable: false);
    if (nodes.isEmpty) return;

    final center = _selectionCenter(nodes);
    final pivot = Transform2D.translation(center);
    final unpivot = Transform2D.translation(Offset(-center.dx, -center.dy));
    final rotation = Transform2D.rotationDeg(clockwise ? 90.0 : -90.0);
    final delta = pivot.multiply(rotation).multiply(unpivot);

    for (final node in nodes) {
      node.transform = delta.multiply(node.transform);
    }

    _contracts.emitAction(
      ActionType.transform,
      nodes.map((node) => node.id).toList(growable: false),
      timestampMs ?? DateTime.now().millisecondsSinceEpoch,
      payload: <String, Object?>{'delta': delta.toJsonMap()},
    );
    _contracts.markSceneGeometryChanged();
    _contracts.notifyNow();
  }

  /// Flips the transformable selection horizontally around its center.
  void flipSelectionVertical({int? timestampMs}) {
    final nodes = _selectedTransformableNodesInSceneOrder()
        .where((node) => !node.isLocked)
        .toList(growable: false);
    if (nodes.isEmpty) return;

    final center = _selectionCenter(nodes);
    final delta = Transform2D(
      a: -1,
      b: 0,
      c: 0,
      d: 1,
      tx: 2 * center.dx,
      ty: 0,
    );

    for (final node in nodes) {
      node.transform = delta.multiply(node.transform);
    }

    _contracts.emitAction(
      ActionType.transform,
      nodes.map((node) => node.id).toList(growable: false),
      timestampMs ?? DateTime.now().millisecondsSinceEpoch,
      payload: <String, Object?>{'delta': delta.toJsonMap()},
    );
    _contracts.markSceneGeometryChanged();
    _contracts.notifyNow();
  }

  /// Flips the transformable selection vertically around its center.
  void flipSelectionHorizontal({int? timestampMs}) {
    final nodes = _selectedTransformableNodesInSceneOrder()
        .where((node) => !node.isLocked)
        .toList(growable: false);
    if (nodes.isEmpty) return;

    final center = _selectionCenter(nodes);
    final delta = Transform2D(
      a: 1,
      b: 0,
      c: 0,
      d: -1,
      tx: 0,
      ty: 2 * center.dy,
    );

    for (final node in nodes) {
      node.transform = delta.multiply(node.transform);
    }

    _contracts.emitAction(
      ActionType.transform,
      nodes.map((node) => node.id).toList(growable: false),
      timestampMs ?? DateTime.now().millisecondsSinceEpoch,
      payload: <String, Object?>{'delta': delta.toJsonMap()},
    );
    _contracts.markSceneGeometryChanged();
    _contracts.notifyNow();
  }

  /// Deletes deletable selected nodes and emits an action.
  void deleteSelection({int? timestampMs}) {
    final selectedNodeIds = _selectionModel.selectedNodeIds;
    if (selectedNodeIds.isEmpty) return;
    final deletableIds = <NodeId>[];

    for (final layer in scene.layers) {
      layer.nodes.removeWhere((node) {
        if (!selectedNodeIds.contains(node.id)) return false;
        if (!node.isDeletable) return false;
        deletableIds.add(node.id);
        return true;
      });
    }

    if (deletableIds.isEmpty) return;
    _contracts.setSelection(
      selectedNodeIds.where((id) => !deletableIds.contains(id)),
      notify: false,
    );
    _contracts.markSceneStructuralChanged();
    _contracts.emitAction(
      ActionType.delete,
      deletableIds,
      timestampMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    _contracts.notifyNow();
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
    _contracts.setSelection(const <NodeId>[], notify: false);
    _contracts.markSceneStructuralChanged();
    _contracts.emitAction(
      ActionType.clear,
      clearedIds,
      timestampMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    _contracts.notifyNow();
  }

  /// Handles a pointer sample and updates the controller state.
  ///
  /// [PointerSample.position] must be provided in view/screen coordinates (the
  /// same space as `PointerEvent.localPosition`). The controller converts it to
  /// scene coordinates using `scene.camera.offset`.
  ///
  /// The controller processes at most one active pointer per mode; additional
  /// pointers are ignored until the active one ends.
  void handlePointer(PointerSample sample) {
    if (mode == CanvasMode.move) {
      _moveModeEngine.handlePointer(sample);
    } else {
      _handleDrawModePointer(sample);
    }
  }

  /// Handles pointer signals such as double-tap text edit requests.
  ///
  /// The controller currently reacts only to `doubleTap` signals in move mode:
  /// if the top-most hit node is a [TextNode], an [EditTextRequested] event is
  /// emitted.
  ///
  /// The emitted [EditTextRequested.position] is in view/screen coordinates.
  void handlePointerSignal(PointerSignal signal) {
    if (signal.type != PointerSignalType.doubleTap) return;
    if (mode != CanvasMode.move) return;

    final scenePoint = _contracts.toScenePoint(signal.position);
    final hit = hitTestTopNode(_contracts.scene, scenePoint);
    if (hit is TextNode) {
      _contracts.emitEditTextRequested(
        EditTextRequested(
          nodeId: hit.id,
          timestampMs: signal.timestampMs,
          position: signal.position,
        ),
      );
    }
  }

  void _handleDrawModePointer(PointerSample sample) {
    if (_drawPointerId != null && _drawPointerId != sample.pointerId) {
      return;
    }

    _expirePendingLine(sample.timestampMs);
    final scenePoint = _contracts.toScenePoint(sample.position);

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

  void _handleDrawDown(PointerSample sample, Offset scenePoint) {
    _drawPointerId = sample.pointerId;
    _drawDownScene = scenePoint;
    _lastDrawScene = scenePoint;
    _drawMoved = false;

    switch (_contracts.drawTool) {
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
    if (!_drawMoved && totalDelta.distance > _contracts.dragStartSlop) {
      _drawMoved = true;
    }

    switch (_contracts.drawTool) {
      case DrawTool.pen:
      case DrawTool.highlighter:
        _appendStrokePoint(scenePoint);
        break;
      case DrawTool.line:
        _updateLineDrag(scenePoint);
        break;
      case DrawTool.eraser:
        _eraserPoints.add(scenePoint);
        _contracts.requestRepaintOncePerFrame();
        break;
    }
    _lastDrawScene = scenePoint;
  }

  void _handleDrawUp(PointerSample sample, Offset scenePoint) {
    if (_drawPointerId != sample.pointerId) return;

    switch (_contracts.drawTool) {
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
    _contracts.notifyNowIfNeeded();
  }

  void _handleDrawCancel() {
    _resetDraw();
    _contracts.notifyNowIfNeeded();
  }

  void _startStroke(Offset scenePoint) {
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
    _activeLine = null;
    _activeDrawLayer = _ensureAnnotationLayer();
    _activeDrawLayer!.nodes.add(stroke);
    _contracts.markSceneStructuralChanged();
    _contracts.requestRepaintOncePerFrame();
  }

  void _appendStrokePoint(Offset scenePoint) {
    final stroke = _activeStroke;
    if (stroke == null) return;
    if (stroke.points.isNotEmpty &&
        (scenePoint - stroke.points.last).distance == 0) {
      return;
    }
    stroke.points.add(scenePoint);
    _contracts.requestRepaintOncePerFrame();
  }

  void _finishStroke(int timestampMs, Offset scenePoint) {
    final stroke = _activeStroke;
    if (stroke == null) return;
    if (stroke.points.isEmpty ||
        (scenePoint - stroke.points.last).distance > 0) {
      stroke.points.add(scenePoint);
    }
    stroke.normalizeToLocalCenter();
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

  void _startLineGesture(Offset scenePoint) {
    _activeLine = null;
    _activeStroke = null;
    _drawMoved = false;
    _drawDownScene = scenePoint;
  }

  void _updateLineDrag(Offset scenePoint) {
    if (_drawDownScene == null) return;
    final totalDelta = scenePoint - _drawDownScene!;
    if (!_drawMoved && totalDelta.distance <= _contracts.dragStartSlop) {
      return;
    }

    if (_pendingLineStart != null) {
      _clearPendingLine();
    }

    if (_activeLine == null) {
      final drawColor = _contracts.drawColor;
      final line = LineNode(
        id: _contracts.newNodeId(),
        start: _drawDownScene!,
        end: scenePoint,
        thickness: _contracts.lineThickness,
        color: drawColor,
      );
      _activeLine = line;
      _activeDrawLayer = _ensureAnnotationLayer();
      _activeDrawLayer!.nodes.add(line);
      _contracts.markSceneStructuralChanged();
    } else {
      _activeLine!.end = scenePoint;
    }
    _contracts.requestRepaintOncePerFrame();
  }

  void _finishLineGesture(int timestampMs, Offset scenePoint) {
    if (_activeLine != null) {
      final line = _activeLine!;
      if (line.end != scenePoint) {
        line.end = scenePoint;
      }
      line.normalizeToLocalCenter();
      _contracts.markSceneGeometryChanged();
      _activeLine = null;
      _activeDrawLayer = null;
      final drawTool = _contracts.drawTool;
      final drawColor = _contracts.drawColor;
      _contracts.emitAction(
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
        (scenePoint - _drawDownScene!).distance <= _contracts.dragStartSlop;
    if (!isTap) return;

    if (_pendingLineStart == null) {
      _setPendingLineStart(scenePoint, timestampMs);
      return;
    }

    final start = _pendingLineStart!;
    final line = LineNode.fromWorldSegment(
      id: _contracts.newNodeId(),
      start: start,
      end: scenePoint,
      thickness: _contracts.lineThickness,
      color: _contracts.drawColor,
    );
    _setPendingLineStart(null, null);
    _activeDrawLayer = _ensureAnnotationLayer();
    _activeDrawLayer!.nodes.add(line);
    _activeDrawLayer = null;
    _contracts.markSceneStructuralChanged();
    final drawTool = _contracts.drawTool;
    final drawColor = _contracts.drawColor;
    _contracts.emitAction(
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
    _contracts.markSceneStructuralChanged();
    _contracts.emitAction(
      ActionType.erase,
      deletedNodeIds,
      timestampMs,
      payload: <String, Object?>{'eraserThickness': _contracts.eraserThickness},
    );
  }

  List<NodeId> _eraseAnnotations(List<Offset> eraserPoints) {
    final deleted = <NodeId>[];
    if (eraserPoints.isEmpty) return deleted;

    for (final layer in scene.layers) {
      if (layer.isBackground) continue;
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
    final inverse = line.transform.invert();
    if (inverse == null) return false;
    final localEraserPoints = eraserPoints
        .map(inverse.applyToPoint)
        .toList(growable: false);
    final sigmaMax = _maxSingularValue2x2(
      inverse.a,
      inverse.b,
      inverse.c,
      inverse.d,
    );
    final threshold =
        line.thickness / 2 + (_contracts.eraserThickness / 2) * sigmaMax;
    if (localEraserPoints.length == 1) {
      final distance = distancePointToSegment(
        localEraserPoints.first,
        line.start,
        line.end,
      );
      return distance <= threshold;
    }
    for (var i = 0; i < localEraserPoints.length - 1; i++) {
      final a = localEraserPoints[i];
      final b = localEraserPoints[i + 1];
      final distance = distanceSegmentToSegment(a, b, line.start, line.end);
      if (distance <= threshold) {
        return true;
      }
    }
    return false;
  }

  bool _eraserHitsStroke(List<Offset> eraserPoints, StrokeNode stroke) {
    final inverse = stroke.transform.invert();
    if (inverse == null) return false;
    final localEraserPoints = eraserPoints
        .map(inverse.applyToPoint)
        .toList(growable: false);
    final sigmaMax = _maxSingularValue2x2(
      inverse.a,
      inverse.b,
      inverse.c,
      inverse.d,
    );
    final threshold =
        stroke.thickness / 2 + (_contracts.eraserThickness / 2) * sigmaMax;
    if (stroke.points.isEmpty) return false;
    if (stroke.points.length == 1) {
      final point = stroke.points.first;
      for (final eraserPoint in localEraserPoints) {
        if ((eraserPoint - point).distance <= threshold) {
          return true;
        }
      }
      return false;
    }

    if (localEraserPoints.length == 1) {
      final eraserPoint = localEraserPoints.first;
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

    for (var i = 0; i < localEraserPoints.length - 1; i++) {
      final eraserA = localEraserPoints[i];
      final eraserB = localEraserPoints[i + 1];
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

  List<SceneNode> _selectedTransformableNodesInSceneOrder() {
    final nodes = <SceneNode>[];
    final selectedNodeIds = _contracts.selectedNodeIds;
    if (selectedNodeIds.isEmpty) return nodes;

    for (final layer in scene.layers) {
      for (final node in layer.nodes) {
        if (!selectedNodeIds.contains(node.id)) continue;
        if (!node.isTransformable) continue;
        nodes.add(node);
      }
    }
    return nodes;
  }

  Offset _selectionCenter(List<SceneNode> nodes) {
    Rect? bounds;
    for (final node in nodes) {
      final nodeBounds = node.boundsWorld;
      bounds = bounds == null ? nodeBounds : bounds.expandToInclude(nodeBounds);
    }
    return bounds?.center ?? Offset.zero;
  }

  bool _setSelection(Iterable<NodeId> nodeIds, {bool notify = true}) {
    final didChange = _selectionModel.setSelection(nodeIds);
    if (!didChange) return false;
    _contracts.markSelectionChanged();
    if (notify) {
      _contracts.requestRepaintOncePerFrame();
    }
    return true;
  }

  void _setSelectionRect(Rect? rect, {bool notify = true}) {
    final didChange = _selectionModel.setSelectionRect(rect);
    if (!didChange) return;
    _contracts.markSceneGeometryChanged();
    if (notify) {
      _contracts.requestRepaintOncePerFrame();
    }
  }

  void _resetDrag() => _moveModeEngine.reset();

  void _resetDrawPointer() {
    _drawPointerId = null;
    _drawDownScene = null;
    _lastDrawScene = null;
    _drawMoved = false;
  }

  void _resetDraw() {
    if (_activeStroke != null && _activeDrawLayer != null) {
      _activeDrawLayer!.nodes.remove(_activeStroke);
      _contracts.markSceneStructuralChanged();
    }
    if (_activeLine != null && _activeDrawLayer != null) {
      _activeDrawLayer!.nodes.remove(_activeLine);
      _contracts.markSceneStructuralChanged();
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
    final drawTool = _contracts.drawTool;
    return drawTool == DrawTool.highlighter
        ? _contracts.highlighterThickness
        : _contracts.penThickness;
  }

  void _setPendingLineStart(Offset? start, int? timestampMs) {
    if (_pendingLineStart == start && _pendingLineTimestampMs == timestampMs) {
      return;
    }
    _pendingLineStart = start;
    _pendingLineTimestampMs = timestampMs;
    _contracts.requestRepaintOncePerFrame();
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
    _contracts.markSceneGeometryChanged();
    if (notify) {
      _contracts.requestRepaintOncePerFrame();
    }
  }

  void _markSceneGeometryChanged() {
    _repaintScheduler.markNeedsNotify();
  }

  void _markSceneStructuralChanged() {
    _sceneRevision++;
    _markSceneGeometryChanged();
  }

  void _markSelectionChanged() {
    _selectionModel.markSelectionChanged();
    _markSceneGeometryChanged();
  }

  void requestRepaintOncePerFrame() =>
      _repaintScheduler.requestRepaintOncePerFrame();
}

class _SceneControllerContracts implements InputSliceContracts {
  _SceneControllerContracts(this._controller);

  final SceneController _controller;

  @override
  Scene get scene => _controller.scene;

  @override
  Offset toScenePoint(Offset viewPoint) =>
      toScene(viewPoint, _controller.scene.camera.offset);

  @override
  double get dragStartSlop => _controller.dragStartSlop;

  @override
  Set<NodeId> get selectedNodeIds => _controller.selectedNodeIds;

  @override
  bool setSelection(Iterable<NodeId> ids, {bool notify = true}) =>
      _controller._setSelection(ids, notify: notify);

  @override
  Rect? get selectionRect => _controller.selectionRect;

  @override
  void setSelectionRect(Rect? rect, {bool notify = true}) =>
      _controller._setSelectionRect(rect, notify: notify);

  @override
  int get sceneRevision => _controller._sceneRevision;

  @override
  int get selectionRevision => _controller._selectionModel.selectionRevision;

  @override
  void markSceneGeometryChanged() => _controller._markSceneGeometryChanged();

  @override
  void markSceneStructuralChanged() =>
      _controller._markSceneStructuralChanged();

  @override
  void markSelectionChanged() => _controller._markSelectionChanged();

  @override
  void requestRepaintOncePerFrame() => _controller.requestRepaintOncePerFrame();

  @override
  void notifyNow() => _controller._repaintScheduler.notifyNow();

  @override
  bool get needsNotify => _controller._repaintScheduler.needsNotify;

  @override
  void notifyNowIfNeeded() {
    if (needsNotify) {
      notifyNow();
    }
  }

  @override
  void emitAction(
    ActionType type,
    List<NodeId> nodeIds,
    int timestampMs, {
    Map<String, Object?>? payload,
  }) => _controller._actionDispatcher.emitAction(
    type,
    nodeIds,
    timestampMs,
    payload: payload,
  );

  @override
  void emitEditTextRequested(EditTextRequested req) =>
      _controller._actionDispatcher.emitEditTextRequested(req);

  @override
  NodeId newNodeId() => _controller._nodeIdGenerator();

  @override
  DrawTool get drawTool => _controller.drawTool;

  @override
  Color get drawColor => _controller.drawColor;

  @override
  double get penThickness => _controller.penThickness;

  @override
  double get highlighterThickness => _controller.highlighterThickness;

  @override
  double get lineThickness => _controller.lineThickness;

  @override
  double get eraserThickness => _controller.eraserThickness;

  @override
  double get highlighterOpacity => _controller.highlighterOpacity;
}
