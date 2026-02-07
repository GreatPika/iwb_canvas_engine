import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../core/defaults.dart';
import '../core/geometry.dart';
import '../core/grid_safety_limits.dart';
import '../core/hit_test.dart';
import '../core/nodes.dart';
import '../core/scene.dart';
import 'action_events.dart';
import 'internal/contracts.dart';
import 'internal/selection_geometry.dart';
import 'pointer_input.dart';
import 'slices/commands/scene_commands.dart';
import 'slices/draw/draw_mode_engine.dart';
import 'slices/move/move_mode_engine.dart';
import 'slices/repaint/repaint_scheduler.dart';
import 'slices/selection/selection_model.dart';
import 'slices/signals/action_dispatcher.dart';
import 'types.dart';

export 'types.dart';

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
  /// per-controller counter. The default counter starts at `max(existing node-n)+1`
  /// for the provided scene to avoid O(N) scans during bulk node creation.
  ///
  /// IDs are guaranteed to be unique within the scene at generation time. If
  /// you override the generator, ensure IDs stay unique in the scene.
  ///
  /// You can reconfigure [pointerSettings], [dragStartSlop], and
  /// [nodeIdGenerator] at runtime via [reconfigureInput].
  ///
  /// Constructor policy:
  /// - validates scene invariants and throws [ArgumentError] for unrecoverable
  ///   violations,
  /// - canonicalizes recoverable background-layer invariants:
  ///   - creates a background layer at index 0 when missing,
  ///   - moves background layer to index 0 when misordered.
  SceneController({
    Scene? scene,
    PointerInputSettings? pointerSettings,
    double? dragStartSlop,
    NodeId Function()? nodeIdGenerator,
  }) : scene = scene ?? Scene(),
       _inputConfig = _InputConfig(
         pointerSettings: pointerSettings ?? const PointerInputSettings(),
         dragStartSlop: dragStartSlop,
         nodeIdGenerator: nodeIdGenerator,
       ) {
    _validateSceneOrThrow(this.scene);
    _nodeIdSeed = _initialDefaultNodeIdSeed(this.scene);
    _repaintScheduler = RepaintScheduler(notifyListeners: notifyListeners);
    _actionDispatcher = ActionDispatcher();
    _selectionModel = SelectionModel();
    _moveModeEngine = MoveModeEngine(_contracts);
    _drawModeEngine = DrawModeEngine(_contracts);
    _sceneCommands = SceneCommands(_contracts);
  }

  final Scene scene;
  _InputConfig _inputConfig;
  _InputConfig? _pendingInputConfig;
  late final InputSliceContracts _contracts = _SceneControllerContracts(this);
  late final RepaintScheduler _repaintScheduler;
  late final ActionDispatcher _actionDispatcher;
  late final SelectionModel _selectionModel;
  late final MoveModeEngine _moveModeEngine;
  late final DrawModeEngine _drawModeEngine;
  late final SceneCommands _sceneCommands;
  int _nodeIdSeed = 0;
  int _timestampCursorMs = -1;

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
    _requireFinitePositive(
      value,
      argumentName: 'penThickness',
      message: 'Must be a finite number > 0.',
    );
    if (_penThickness == value) return;
    _penThickness = value;
    _contracts.markSceneGeometryChanged();
    _contracts.requestRepaintOncePerFrame();
  }

  double get highlighterThickness => _highlighterThickness;
  set highlighterThickness(double value) {
    _requireFinitePositive(
      value,
      argumentName: 'highlighterThickness',
      message: 'Must be a finite number > 0.',
    );
    if (_highlighterThickness == value) return;
    _highlighterThickness = value;
    _contracts.markSceneGeometryChanged();
    _contracts.requestRepaintOncePerFrame();
  }

  double get lineThickness => _lineThickness;
  set lineThickness(double value) {
    _requireFinitePositive(
      value,
      argumentName: 'lineThickness',
      message: 'Must be a finite number > 0.',
    );
    if (_lineThickness == value) return;
    _lineThickness = value;
    _contracts.markSceneGeometryChanged();
    _contracts.requestRepaintOncePerFrame();
  }

  double get eraserThickness => _eraserThickness;
  set eraserThickness(double value) {
    _requireFinitePositive(
      value,
      argumentName: 'eraserThickness',
      message: 'Must be a finite number > 0.',
    );
    if (_eraserThickness == value) return;
    _eraserThickness = value;
    _contracts.markSceneGeometryChanged();
    _contracts.requestRepaintOncePerFrame();
  }

  double get highlighterOpacity => _highlighterOpacity;
  set highlighterOpacity(double value) {
    _requireFiniteInUnitInterval(
      value,
      argumentName: 'highlighterOpacity',
      message: 'Must be a finite number within [0,1].',
    );
    if (_highlighterOpacity == value) return;
    _highlighterOpacity = value;
    _contracts.markSceneGeometryChanged();
    _contracts.requestRepaintOncePerFrame();
  }

  int _sceneRevision = 0;

  /// Synchronous broadcast stream of committed actions.
  ///
  /// Emitted [ActionCommitted.timestampMs] values use the engine's internal
  /// monotonic timeline. External timestamps are treated as hints and are
  /// normalized to avoid time going backwards.
  ///
  /// Handlers must be fast and avoid blocking work.
  Stream<ActionCommitted> get actions => _actionDispatcher.actions;

  /// Synchronous broadcast stream of text edit requests.
  ///
  /// Emitted [EditTextRequested.timestampMs] values use the same internal
  /// monotonic timeline as [actions].
  ///
  /// Handlers must be fast and avoid blocking work.
  Stream<EditTextRequested> get editTextRequests =>
      _actionDispatcher.editTextRequests;

  /// Pointer gesture thresholds and timing settings used by this controller.
  PointerInputSettings get pointerSettings => _inputConfig.pointerSettings;

  /// Current selection snapshot.
  Set<NodeId> get selectedNodeIds => _selectionModel.selectedNodeIds;

  @visibleForTesting
  int get debugSceneRevision => _sceneRevision;

  @visibleForTesting
  int get debugSelectionRevision => _selectionModel.selectionRevision;

  @visibleForTesting
  int get debugSelectionRectRevision => _selectionModel.selectionRectRevision;

  @visibleForTesting
  int get debugContractsSelectionRectRevision =>
      _contracts.selectionRectRevision;

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
    final nodes = selectedTransformableNodesInSceneOrder(
      scene,
      _contracts.selectedNodeIds,
    ).where((node) => !node.isLocked).toList(growable: false);
    if (nodes.isEmpty) return null;
    return boundsWorldForNodes(nodes);
  }

  /// Center of [selectionBoundsWorld] when selection is non-empty.
  Offset? get selectionCenterWorld => selectionBoundsWorld?.center;

  /// Pending first point for a two-tap line gesture, if any.
  Offset? get pendingLineStart => _drawModeEngine.pendingLineStart;

  /// Timestamp for the pending two-tap line start, if any.
  int? get pendingLineTimestampMs => _drawModeEngine.pendingLineTimestampMs;

  /// Whether a two-tap line start is waiting for the second tap.
  bool get hasPendingLineStart => _drawModeEngine.hasPendingLineStart;

  /// Pointer slop threshold used to treat a drag as a move.
  double get dragStartSlop =>
      _inputConfig.dragStartSlop ?? pointerSettings.tapSlop;

  /// Atomically updates pointer input configuration at runtime.
  ///
  /// The update applies immediately when no pointer gesture is active.
  /// If a gesture is in progress, the new configuration is stored and applied
  /// after the active pointer ends (`up`/`cancel`).
  ///
  /// This method never emits actions, does not mutate scene/selection, and
  /// does not trigger repaint by itself.
  void reconfigureInput({
    required PointerInputSettings pointerSettings,
    required double? dragStartSlop,
    required NodeId Function()? nodeIdGenerator,
  }) {
    final nextConfig = _InputConfig(
      pointerSettings: pointerSettings,
      dragStartSlop: dragStartSlop,
      nodeIdGenerator: nodeIdGenerator,
    );
    if (nextConfig.equivalentTo(_inputConfig)) {
      _pendingInputConfig = null;
      return;
    }
    if (_hasActivePointer) {
      _pendingInputConfig = nextConfig;
      return;
    }
    _pendingInputConfig = null;
    _applyInputConfig(nextConfig);
  }

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

  NodeId _newNodeId() {
    final custom = _inputConfig.nodeIdGenerator;
    if (custom != null) {
      return custom();
    }
    return _defaultNodeIdGenerator();
  }

  static int _initialDefaultNodeIdSeed(Scene scene) {
    var maxId = -1;
    for (final layer in scene.layers) {
      for (final node in layer.nodes) {
        final id = node.id;
        if (!id.startsWith('node-')) continue;
        final n = int.tryParse(id.substring('node-'.length));
        if (n == null || n < 0) continue;
        if (n > maxId) maxId = n;
      }
    }
    return maxId + 1;
  }

  static void _validateSceneOrThrow(Scene scene) {
    _validateUnrecoverableSceneInvariants(scene);
    _canonicalizeRecoverableSceneInvariants(scene);
  }

  static void _validateUnrecoverableSceneInvariants(Scene scene) {
    _requireFiniteOffset(
      scene.camera.offset,
      argumentName: 'scene.camera.offset',
      message: 'Camera offset must be finite.',
    );
    _requireNotEmpty(
      scene.palette.penColors,
      argumentName: 'scene.palette.penColors',
      message: 'Palette penColors must not be empty.',
    );
    _requireNotEmpty(
      scene.palette.backgroundColors,
      argumentName: 'scene.palette.backgroundColors',
      message: 'Palette backgroundColors must not be empty.',
    );
    _requireNotEmpty(
      scene.palette.gridSizes,
      argumentName: 'scene.palette.gridSizes',
      message: 'Palette gridSizes must not be empty.',
    );

    final grid = scene.background.grid;
    _requireFinite(
      grid.cellSize,
      argumentName: 'scene.background.grid.cellSize',
      message: 'Grid cell size must be finite.',
    );
    if (grid.isEnabled) {
      _requireFinitePositive(
        grid.cellSize,
        argumentName: 'scene.background.grid.cellSize',
        message: 'Grid cell size must be > 0 when grid is enabled.',
      );
    }

    var backgroundCount = 0;
    for (final layer in scene.layers) {
      if (layer.isBackground) {
        backgroundCount += 1;
      }
      if (backgroundCount > 1) {
        throw ArgumentError.value(
          scene.layers,
          'scene.layers',
          'Scene must contain at most one background layer.',
        );
      }
    }
  }

  static void _canonicalizeRecoverableSceneInvariants(Scene scene) {
    final grid = scene.background.grid;
    if (grid.isEnabled && grid.cellSize < kMinGridCellSize) {
      grid.cellSize = kMinGridCellSize;
    }

    var backgroundIndex = -1;
    for (var i = 0; i < scene.layers.length; i++) {
      if (scene.layers[i].isBackground) {
        backgroundIndex = i;
        break;
      }
    }

    if (backgroundIndex == -1) {
      scene.layers.insert(0, Layer(isBackground: true));
      return;
    }
    if (backgroundIndex == 0) return;

    final backgroundLayer = scene.layers.removeAt(backgroundIndex);
    scene.layers.insert(0, backgroundLayer);
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
      _drawModeEngine.reset();
    }
    _applyPendingInputConfigIfIdle();
    _mode = value;
    _contracts.setSelectionRect(null, notify: false);
    _contracts.markSceneGeometryChanged();
    _contracts.notifyNow();
  }

  /// Changes the active drawing tool and resets draw state.
  void setDrawTool(DrawTool tool) {
    if (_drawTool == tool) return;
    _drawTool = tool;
    _drawModeEngine.reset();
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
    _requireFinitePositive(
      value,
      argumentName: 'value',
      message: 'Grid cell size must be a finite number > 0.',
    );
    final resolvedValue = scene.background.grid.isEnabled
        ? value.clamp(kMinGridCellSize, double.infinity).toDouble()
        : value;
    if (scene.background.grid.cellSize == resolvedValue) return;
    scene.background.grid.cellSize = resolvedValue;
    _contracts.markSceneGeometryChanged();
    _contracts.notifyNow();
  }

  /// Updates the scene camera offset.
  ///
  /// Throws [ArgumentError] when [value] contains non-finite components.
  void setCameraOffset(Offset value) {
    _setCameraOffset(value);
  }

  /// Restores minimal invariants after external mutations to [scene].
  ///
  /// For example, it drops selection for nodes that were removed directly.
  void notifySceneChanged() {
    _sceneCommands.notifySceneChanged();
  }

  /// Runs [fn] to mutate [scene] as a geometry-only edit and schedules repaint.
  ///
  /// Use [mutateStructural] for structural edits (add/remove/reorder layers or
  /// nodes). In debug mode, structural edits inside [mutate] trigger an assert.
  void mutate(void Function(Scene scene) fn) {
    _sceneCommands.mutate(fn);
  }

  /// Runs [fn] to mutate [scene] structurally and restores minimal invariants.
  ///
  /// Structural edits include add/remove/reorder of layers or nodes.
  /// This path calls [notifySceneChanged] semantics immediately.
  void mutateStructural(void Function(Scene scene) fn) {
    _sceneCommands.mutateStructural(fn);
  }

  /// Adds [node] to the target layer and notifies listeners.
  ///
  /// When [layerIndex] is omitted, the node is added to the first
  /// non-background layer. If none exists, a new non-background layer is
  /// created and used.
  ///
  /// Adds [node] to [layerIndex] when provided.
  ///
  /// Throws [RangeError] when [layerIndex] is invalid.
  /// Throws [ArgumentError] when a node with the same [SceneNode.id] already
  /// exists in the scene.
  void addNode(SceneNode node, {int? layerIndex}) {
    _sceneCommands.addNode(node, layerIndex: layerIndex);
  }

  /// Removes a node by [id], clears its selection, and emits an action.
  void removeNode(NodeId id, {int? timestampMs}) {
    _sceneCommands.removeNode(id, timestampMs: timestampMs);
  }

  /// Moves a node by [id] to another layer and emits an action.
  ///
  /// Throws [RangeError] if [targetLayerIndex] is out of bounds.
  void moveNode(NodeId id, {required int targetLayerIndex, int? timestampMs}) {
    _sceneCommands.moveNode(
      id,
      targetLayerIndex: targetLayerIndex,
      timestampMs: timestampMs,
    );
  }

  /// Clears the current selection.
  void clearSelection() {
    _sceneCommands.clearSelection();
  }

  /// Replaces the selection with [nodeIds].
  ///
  /// This is intended for app-driven selection UIs (layers panel, object list).
  void setSelection(Iterable<NodeId> nodeIds) {
    _sceneCommands.setSelection(nodeIds);
  }

  /// Toggles selection for a single node [id].
  void toggleSelection(NodeId id) {
    _sceneCommands.toggleSelection(id);
  }

  /// Selects all nodes in the scene.
  ///
  /// When [onlySelectable] is true, includes only nodes with `isSelectable`.
  void selectAll({bool onlySelectable = true}) {
    _sceneCommands.selectAll(onlySelectable: onlySelectable);
  }

  /// Rotates the transformable selection by 90 degrees.
  void rotateSelection({required bool clockwise, int? timestampMs}) {
    _sceneCommands.rotateSelection(
      clockwise: clockwise,
      timestampMs: timestampMs,
    );
  }

  /// Flips the transformable selection horizontally around its center.
  void flipSelectionVertical({int? timestampMs}) {
    _sceneCommands.flipSelectionVertical(timestampMs: timestampMs);
  }

  /// Flips the transformable selection vertically around its center.
  void flipSelectionHorizontal({int? timestampMs}) {
    _sceneCommands.flipSelectionHorizontal(timestampMs: timestampMs);
  }

  /// Deletes deletable selected nodes and emits an action.
  void deleteSelection({int? timestampMs}) {
    _sceneCommands.deleteSelection(timestampMs: timestampMs);
  }

  /// Clears all non-background layers and emits an action.
  void clearScene({int? timestampMs}) {
    _sceneCommands.clearScene(timestampMs: timestampMs);
  }

  /// Handles a pointer sample and updates the controller state.
  ///
  /// [PointerSample.position] must be provided in view/screen coordinates (the
  /// same space as `PointerEvent.localPosition`). The controller converts it to
  /// scene coordinates using `scene.camera.offset`.
  ///
  /// [PointerSample.timestampMs] is treated as a timestamp hint. The controller
  /// normalizes it into an internal monotonic timeline before dispatching to
  /// move/draw engines.
  ///
  /// The controller processes at most one active pointer per mode; additional
  /// pointers are ignored until the active one ends.
  void handlePointer(PointerSample sample) {
    final resolvedSample = PointerSample(
      pointerId: sample.pointerId,
      position: sample.position,
      timestampMs: _resolveTimestampMs(sample.timestampMs),
      phase: sample.phase,
      kind: sample.kind,
    );
    if (mode == CanvasMode.move) {
      _moveModeEngine.handlePointer(resolvedSample);
    } else {
      _drawModeEngine.handlePointer(resolvedSample);
    }
    _applyPendingInputConfigIfIdle();
  }

  /// Handles pointer signals such as double-tap text edit requests.
  ///
  /// The controller currently reacts only to `doubleTap` signals in move mode:
  /// if the top-most hit node is a [TextNode], an [EditTextRequested] event is
  /// emitted.
  ///
  /// [PointerSignal.timestampMs] is treated as a timestamp hint and normalized
  /// before emitting [EditTextRequested].
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
          timestampMs: _contracts.resolveTimestampMs(signal.timestampMs),
          position: signal.position,
        ),
      );
    }
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

  bool get _hasActivePointer =>
      _moveModeEngine.hasActivePointer || _drawModeEngine.hasActivePointer;

  void _applyInputConfig(_InputConfig config) {
    _inputConfig = config;
  }

  void _applyPendingInputConfigIfIdle() {
    if (_hasActivePointer) return;
    final pending = _pendingInputConfig;
    if (pending == null) return;
    _pendingInputConfig = null;
    _applyInputConfig(pending);
  }

  void _resetDrag() => _moveModeEngine.reset();

  void _setCameraOffset(Offset value, {bool notify = true}) {
    _requireFiniteOffset(
      value,
      argumentName: 'value',
      message: 'Camera offset must be finite.',
    );
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

  int _resolveTimestampMs(int? hintTimestampMs) {
    final next = _timestampCursorMs + 1;
    final resolved = hintTimestampMs == null || hintTimestampMs < next
        ? next
        : hintTimestampMs;
    _timestampCursorMs = resolved;
    return resolved;
  }

  void requestRepaintOncePerFrame() =>
      _repaintScheduler.requestRepaintOncePerFrame();

  static void _requireFinite(
    double value, {
    required String argumentName,
    required String message,
  }) {
    if (value.isFinite) return;
    throw ArgumentError.value(value, argumentName, message);
  }

  static void _requireFinitePositive(
    double value, {
    required String argumentName,
    required String message,
  }) {
    if (value.isFinite && value > 0) return;
    throw ArgumentError.value(value, argumentName, message);
  }

  static void _requireFiniteInUnitInterval(
    double value, {
    required String argumentName,
    required String message,
  }) {
    if (value.isFinite && value >= 0 && value <= 1) return;
    throw ArgumentError.value(value, argumentName, message);
  }

  static void _requireFiniteOffset(
    Offset value, {
    required String argumentName,
    required String message,
  }) {
    if (value.dx.isFinite && value.dy.isFinite) return;
    throw ArgumentError.value(value, argumentName, message);
  }

  static void _requireNotEmpty(
    List<Object?> values, {
    required String argumentName,
    required String message,
  }) {
    if (values.isNotEmpty) return;
    throw ArgumentError.value(values, argumentName, message);
  }
}

class _InputConfig {
  const _InputConfig({
    required this.pointerSettings,
    required this.dragStartSlop,
    required this.nodeIdGenerator,
  });

  final PointerInputSettings pointerSettings;
  final double? dragStartSlop;
  final NodeId Function()? nodeIdGenerator;

  bool equivalentTo(_InputConfig other) {
    return _equivalentPointerSettings(other.pointerSettings) &&
        dragStartSlop == other.dragStartSlop &&
        identical(nodeIdGenerator, other.nodeIdGenerator);
  }

  bool _equivalentPointerSettings(PointerInputSettings other) {
    final current = pointerSettings;
    return current.tapSlop == other.tapSlop &&
        current.doubleTapSlop == other.doubleTapSlop &&
        current.doubleTapMaxDelayMs == other.doubleTapMaxDelayMs &&
        current.deferSingleTap == other.deferSingleTap;
  }
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
  int get selectionRectRevision =>
      _controller._selectionModel.selectionRectRevision;

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
  }) {
    _controller._actionDispatcher.emitAction(
      type,
      nodeIds,
      timestampMs,
      payload: payload,
    );
  }

  @override
  void emitEditTextRequested(EditTextRequested req) =>
      _controller._actionDispatcher.emitEditTextRequested(req);

  @override
  int resolveTimestampMs(int? hintTimestampMs) =>
      _controller._resolveTimestampMs(hintTimestampMs);

  @override
  NodeId newNodeId() => _controller._newNodeId();

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
