import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../core/action_events.dart';
import '../core/grid_safety_limits.dart';
import '../core/interaction_types.dart';
import '../core/tool_defaults.dart';
import '../contract/canvas_pointer_input.dart';
import '../contract/node_patch.dart';
import '../contract/node_spec.dart';
import '../contract/scene_defaults.dart';
import '../contract/scene_render_state.dart';
import '../contract/scene_write_txn.dart';
import '../contract/snapshot.dart';
import '../contract/transform2d.dart';
import '../controller/scene_controller.dart';
import '../core/pointer_input.dart';
import '../model/document.dart' show txnSceneFromSnapshot;
import 'internal/interactive_draw_line_engine.dart' show InteractiveDrawStyle;
import 'internal/interactive_event_dispatcher.dart';
import 'internal/interactive_geometry.dart';
import 'internal/interactive_runtime.dart';
import 'internal/interactive_runtime_callbacks.dart';
import 'internal/interactive_selection_actions.dart';

typedef MoveCommitDeltaResolver =
    Offset Function({
      required SceneSnapshot snapshot,
      required List<NodeSnapshot> movedNodes,
      required Offset proposedDelta,
    });

int sceneControllerInteractiveInternalEpoch(
  SceneControllerInteractive controller,
) {
  return controller._core.controllerEpoch;
}

Offset sceneControllerInteractiveInternalPreviewDeltaForNode(
  SceneControllerInteractive controller,
  NodeId nodeId,
) {
  return controller._runtime.debugMoveSession.movePreviewDeltaForNode(nodeId);
}

void sceneControllerInteractiveInternalSetBeforePointerDispatchHook(
  SceneControllerInteractive controller,
  VoidCallback? hook,
) {
  controller._runtime.setBeforePointerDispatchHook(hook);
}

Offset sceneControllerInteractiveInternalRunMoveCommitDeltaResolverForTest(
  SceneControllerInteractive controller, {
  required SceneSnapshot snapshot,
  required List<NodeSnapshot> movedNodes,
  required Offset proposedDelta,
}) {
  return controller._runMoveCommitDeltaResolver(
    snapshot: snapshot,
    movedNodes: movedNodes,
    proposedDelta: proposedDelta,
  );
}

void sceneControllerInteractiveInternalEnforceGestureBufferSoftLimitForTest(
  SceneControllerInteractive _, {
  required List<Offset> points,
  required int softLimit,
  required int trimTo,
}) {
  enforceGestureBufferSoftLimit(points, softLimit: softLimit, trimTo: trimTo);
}

int sceneControllerInteractiveInternalActiveEraserPointsLength(
  SceneControllerInteractive controller,
) {
  return controller._runtime.activeEraserPointsLength;
}

int sceneControllerInteractiveInternalEraserSpatialQueryCount(
  SceneControllerInteractive controller,
) {
  // Test-only metric: number of coarse spatial queries used by last eraser
  // commit. Helps keep complexity guards deterministic across environments.
  return controller._runtime.debugEraserSpatialQueryCount;
}

int sceneControllerInteractiveInternalEraserPreciseSegmentCheckCount(
  SceneControllerInteractive controller,
) {
  // Test-only metric: number of exact segment-to-segment checks during last
  // eraser commit. Used as primary perf acceptance signal.
  return controller._runtime.debugEraserPreciseSegmentChecks;
}

class SceneControllerInteractive extends ChangeNotifier
    implements SceneRenderState {
  SceneControllerInteractive({
    SceneSnapshot? initialSnapshot,
    PointerInputSettings? pointerSettings,
    double? dragStartSlop,
    this.clearSelectionOnDrawModeEnter = false,
    this.moveCommitDeltaResolver,
    this.textFontFamilyByDefault,
  }) : _pointerSettings = pointerSettings ?? const PointerInputSettings(),
       _dragStartSlop = _validateDragStartSlop(dragStartSlop),
       _core = SceneControllerCore(
         initialSnapshot: initialSnapshot,
         textFontFamilyByDefault: textFontFamilyByDefault,
       ) {
    validatePointerInputSettings(_pointerSettings);
    _notifyScheduler = InteractiveNotifyScheduler(
      notifyListeners: notifyListeners,
    );
    _events = InteractiveEventDispatcher();
    _selectionActions = _createSelectionActions();
    _runtime = _createRuntime();
    _core.addListener(_handleCoreChanged);
  }

  final SceneControllerCore _core;
  late final InteractiveNotifyScheduler _notifyScheduler;
  late final InteractiveEventDispatcher _events;
  late final InteractiveSelectionActions _selectionActions;
  late final InteractiveRuntime _runtime;

  PointerInputSettings _pointerSettings;
  double? _dragStartSlop;

  CanvasMode _mode = CanvasMode.move;
  DrawTool _drawTool = DrawTool.pen;
  Color _drawColor = SceneDefaults.penColors.first;
  double _penThickness = ToolDefaults.penThickness;
  double _highlighterThickness = ToolDefaults.highlighterThickness;
  double _lineThickness = ToolDefaults.penThickness;
  double _eraserThickness = ToolDefaults.eraserThickness;
  double _highlighterOpacity = ToolDefaults.highlighterOpacity;

  final bool clearSelectionOnDrawModeEnter;
  final MoveCommitDeltaResolver? moveCommitDeltaResolver;
  final String? textFontFamilyByDefault;

  bool _isDisposed = false;
  bool _moveCommitResolverActive = false;

  @override
  SceneSnapshot get snapshot => _core.snapshot;
  @override
  Set<NodeId> get selectedNodeIds => _core.selectedNodeIds;

  CanvasMode get mode => _mode;
  DrawTool get drawTool => _drawTool;
  Color get drawColor => _drawColor;

  double get penThickness => _penThickness;
  double get highlighterThickness => _highlighterThickness;
  double get lineThickness => _lineThickness;
  double get eraserThickness => _eraserThickness;
  double get highlighterOpacity => _highlighterOpacity;
  double get dragStartSlop => _dragStartSlop ?? _pointerSettings.tapSlop;

  Rect? get selectionRect => _runtime.selectionRect;

  Offset? get pendingLineStart => _runtime.pendingLineStart;
  int? get pendingLineTimestampMs => _runtime.pendingLineTimestampMs;
  bool get hasPendingLineStart => _runtime.hasPendingLineStart;
  bool get hasActiveStrokePreview =>
      _runtime.isActiveDrawGesture &&
      (_drawTool == DrawTool.pen || _drawTool == DrawTool.highlighter) &&
      _runtime.hasActiveStrokePoints;
  List<Offset> get activeStrokePreviewPoints =>
      _runtime.activeStrokePreviewPoints;
  double get activeStrokePreviewThickness =>
      _drawTool == DrawTool.highlighter ? _highlighterThickness : _penThickness;
  Color get activeStrokePreviewColor => _drawColor;
  double get activeStrokePreviewOpacity =>
      _drawTool == DrawTool.highlighter ? _highlighterOpacity : 1;
  bool get hasActiveLinePreview =>
      _runtime.isActiveDrawGesture &&
      _drawTool == DrawTool.line &&
      _runtime.activeLinePreviewStart != null &&
      _runtime.activeLinePreviewEnd != null;
  Offset? get activeLinePreviewStart => _runtime.activeLinePreviewStart;
  Offset? get activeLinePreviewEnd => _runtime.activeLinePreviewEnd;
  double get activeLinePreviewThickness => _lineThickness;
  Color get activeLinePreviewColor => _drawColor;

  PointerInputSettings get pointerSettings => _pointerSettings;

  Stream<ActionCommitted> get actions => _events.actions;
  Stream<EditTextRequested> get editTextRequests => _events.editTextRequests;

  T write<T>(T Function(SceneWriteTxn writer) fn) {
    _ensurePublicSideEffectAllowed('write');
    return _core.write(fn);
  }

  void setMode(CanvasMode value) {
    _ensurePublicSideEffectAllowed('setMode');
    if (_mode == value) return;

    _runtime.resetInteractiveState();
    _mode = value;

    if (value == CanvasMode.draw &&
        clearSelectionOnDrawModeEnter &&
        selectedNodeIds.isNotEmpty) {
      _core.commands.writeSelectionClear();
    }

    _scheduleNotify();
  }

  void setDrawTool(DrawTool value) {
    _ensurePublicSideEffectAllowed('setDrawTool');
    if (_drawTool == value) return;
    _runtime.resetInteractiveState();
    _drawTool = value;
    _scheduleNotify();
  }

  void setDrawColor(Color value) {
    _ensurePublicSideEffectAllowed('setDrawColor');
    if (_drawColor == value) return;
    _drawColor = value;
    _scheduleNotify();
  }

  set penThickness(double value) {
    _ensurePublicSideEffectAllowed('penThickness');
    _penThickness = _requireFinitePositive(value, name: 'penThickness');
    _scheduleNotify();
  }

  set highlighterThickness(double value) {
    _ensurePublicSideEffectAllowed('highlighterThickness');
    _highlighterThickness = _requireFinitePositive(
      value,
      name: 'highlighterThickness',
    );
    _scheduleNotify();
  }

  set lineThickness(double value) {
    _ensurePublicSideEffectAllowed('lineThickness');
    _lineThickness = _requireFinitePositive(value, name: 'lineThickness');
    _scheduleNotify();
  }

  set eraserThickness(double value) {
    _ensurePublicSideEffectAllowed('eraserThickness');
    _eraserThickness = _requireFinitePositive(value, name: 'eraserThickness');
    _scheduleNotify();
  }

  set highlighterOpacity(double value) {
    _ensurePublicSideEffectAllowed('highlighterOpacity');
    _highlighterOpacity = _requireFiniteInUnitInterval(
      value,
      name: 'highlighterOpacity',
    );
    _scheduleNotify();
  }

  void setPointerSettings(PointerInputSettings value) {
    _ensurePublicSideEffectAllowed('setPointerSettings');
    validatePointerInputSettings(value);
    _pointerSettings = value;
    _scheduleNotify();
  }

  void setDragStartSlop(double? value) {
    _ensurePublicSideEffectAllowed('setDragStartSlop');
    final resolved = _validateDragStartSlop(value);
    if (_dragStartSlop == resolved) return;
    _dragStartSlop = resolved;
    _scheduleNotify();
  }

  void setBackgroundColor(Color value) {
    _ensurePublicSideEffectAllowed('setBackgroundColor');
    _core.commands.writeBackgroundColorSet(value);
  }

  void setGridEnabled(bool value) {
    _ensurePublicSideEffectAllowed('setGridEnabled');
    _core.commands.writeGridEnabledSet(value);
  }

  void setGridCellSize(double value) {
    _ensurePublicSideEffectAllowed('setGridCellSize');
    _requireFinitePositive(value, name: 'cellSize');
    final gridEnabled = snapshot.background.grid.isEnabled;
    final resolved = gridEnabled
        ? value.clamp(kMinGridCellSize, double.infinity).toDouble()
        : value;
    _core.commands.writeGridCellSizeSet(resolved);
  }

  void setCameraOffset(Offset value) {
    _ensurePublicSideEffectAllowed('setCameraOffset');
    _requireFiniteOffset(value, name: 'value');
    if (snapshot.camera.offset == value) {
      return;
    }
    _runtime.resetInteractiveState();
    _core.commands.writeCameraOffsetSet(value);
  }

  NodeId addNode(NodeSpec node, {LayerId? layerId, int? insertIndex}) {
    _ensurePublicSideEffectAllowed('addNode');
    return _core.commands.writeAddNode(
      node,
      layerId: layerId,
      insertIndex: insertIndex,
    );
  }

  bool ensureLayer(LayerId layerId, {int? index}) {
    _ensurePublicSideEffectAllowed('ensureLayer');
    return _core.write((writer) {
      return writer.writeLayerEnsure(layerId, index: index);
    });
  }

  bool patchNode(NodePatch patch) {
    _ensurePublicSideEffectAllowed('patchNode');
    return _core.commands.writePatchNode(patch);
  }

  bool removeNode(NodeId id, {int? timestampMs}) {
    _ensurePublicSideEffectAllowed('removeNode');
    final deleted = _core.commands.writeDeleteNode(id);
    if (!deleted) return false;
    _events.emitAction(ActionType.delete, <NodeId>[
      id,
    ], _events.resolveTimestampMs(timestampMs));
    return true;
  }

  void setSelection(Iterable<NodeId> nodeIds) {
    _ensurePublicSideEffectAllowed('setSelection');
    _ensureExternalSelectionMutationAllowed('setSelection');
    _core.commands.writeSelectionReplace(nodeIds);
  }

  void toggleSelection(NodeId nodeId) {
    _ensurePublicSideEffectAllowed('toggleSelection');
    _ensureExternalSelectionMutationAllowed('toggleSelection');
    _core.commands.writeSelectionToggle(nodeId);
  }

  void clearSelection() {
    _ensurePublicSideEffectAllowed('clearSelection');
    _ensureExternalSelectionMutationAllowed('clearSelection');
    _core.commands.writeSelectionClear();
  }

  void selectAll({bool onlySelectable = true}) {
    _ensurePublicSideEffectAllowed('selectAll');
    _ensureExternalSelectionMutationAllowed('selectAll');
    _core.commands.writeSelectionSelectAll(onlySelectable: onlySelectable);
  }

  void rotateSelection({required bool clockwise, int? timestampMs}) {
    _ensurePublicSideEffectAllowed('rotateSelection');
    _selectionActions.rotateSelection(
      clockwise: clockwise,
      timestampMs: timestampMs,
    );
  }

  void flipSelectionVertical({int? timestampMs}) {
    _ensurePublicSideEffectAllowed('flipSelectionVertical');
    _selectionActions.flipSelectionVertical(timestampMs: timestampMs);
  }

  void flipSelectionHorizontal({int? timestampMs}) {
    _ensurePublicSideEffectAllowed('flipSelectionHorizontal');
    _selectionActions.flipSelectionHorizontal(timestampMs: timestampMs);
  }

  void deleteSelection({int? timestampMs}) {
    _ensurePublicSideEffectAllowed('deleteSelection');
    _selectionActions.deleteSelection(timestampMs: timestampMs);
  }

  void clearScene({int? timestampMs}) {
    _ensurePublicSideEffectAllowed('clearScene');
    _selectionActions.clearScene(timestampMs: timestampMs);
  }

  void replaceScene(SceneSnapshot snapshot) {
    _ensurePublicSideEffectAllowed('replaceScene');
    txnSceneFromSnapshot(snapshot);
    _runtime.resetInteractiveState();
    _core.writeReplaceScene(snapshot);
    _runtime.clearPointerNormalizationState();
  }

  void notifySceneChanged() {
    _ensurePublicSideEffectAllowed('notifySceneChanged');
    _core.requestRepaint();
  }

  void handlePointer(CanvasPointerInput input) {
    _ensurePublicSideEffectAllowed('handlePointer');
    _runtime.handlePointer(input);
  }

  void handleDoubleTap({required Offset position, int? timestampMs}) {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
    _runtime.handleDoubleTap(position: position, timestampMs: timestampMs);
  }

  InteractiveRuntime _createRuntime() {
    return InteractiveRuntime(
      events: _events,
      callbacks: InteractiveRuntimeCallbacks(
        scheduleNotify: _scheduleNotify,
        readSnapshot: () => snapshot,
        readSelectedNodeIds: () => selectedNodeIds,
        readMode: () => _mode,
        readDragStartSlop: () => dragStartSlop,
        readDrawStyle: () => _currentDrawStyle,
        querySpatialCandidates: _core.querySpatialCandidates,
        resolveSpatialCandidateNode: _core.resolveSpatialCandidateNode,
        writeSelectionReplace: _core.commands.writeSelectionReplace,
        writeSelectionClear: _core.commands.writeSelectionClear,
        commitMoveSelection: _selectionActions.commitMoveSelection,
        writeDrawStroke: _core.draw.writeDrawStroke,
        writeDrawLineFromWorldSegment: _writeDrawLineFromWorldSegment,
        writeEraseNodes: _core.draw.writeEraseNodes,
      ),
    );
  }

  InteractiveSelectionActions _createSelectionActions() {
    return InteractiveSelectionActions(
      core: _core,
      callbacks: InteractiveSelectionActionsCallbacks(
        resolveTimestampMs: _events.resolveTimestampMs,
        emitAction: _events.emitAction,
        resolveMoveCommitDelta: _runMoveCommitDeltaResolver,
        requireFiniteOffset: _requireFiniteOffset,
      ),
    );
  }

  InteractiveDrawStyle get _currentDrawStyle => (
    drawTool: _drawTool,
    drawColor: _drawColor,
    penThickness: _penThickness,
    highlighterThickness: _highlighterThickness,
    lineThickness: _lineThickness,
    eraserThickness: _eraserThickness,
    highlighterOpacity: _highlighterOpacity,
  );

  static double? _validateDragStartSlop(double? value) {
    if (value == null) return null;
    return _requireFiniteNonNegative(value, name: 'dragStartSlop');
  }

  NodeId _writeDrawLineFromWorldSegment({
    required Offset start,
    required Offset end,
  }) {
    return _core.write<NodeId>((writer) {
      final bounds = Rect.fromPoints(start, end);
      final center = bounds.center;
      final nodeId = writer.writeNodeInsert(
        LineNodeSpec(
          start: start - center,
          end: end - center,
          thickness: _lineThickness,
          color: _drawColor,
          transform: Transform2D.translation(center),
        ),
      );
      writer.writeSignalEnqueue(type: 'draw.line', nodeIds: <NodeId>[nodeId]);
      return nodeId;
    });
  }

  void _scheduleNotify() {
    _notifyScheduler.schedule();
  }

  void _handleCoreChanged() {
    _scheduleNotify();
  }

  Offset _runMoveCommitDeltaResolver({
    required SceneSnapshot snapshot,
    required List<NodeSnapshot> movedNodes,
    required Offset proposedDelta,
  }) {
    final resolver = moveCommitDeltaResolver;
    if (resolver == null) {
      return proposedDelta;
    }
    if (_moveCommitResolverActive) {
      throw StateError(
        'Reentrant moveCommitDeltaResolver(...) is not allowed.',
      );
    }

    _moveCommitResolverActive = true;
    try {
      return resolver(
        snapshot: snapshot,
        movedNodes: movedNodes,
        proposedDelta: proposedDelta,
      );
    } finally {
      _moveCommitResolverActive = false;
    }
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {
    if (_moveCommitResolverActive) {
      throw StateError(
        '$operation is not allowed during moveCommitDeltaResolver.',
      );
    }
    if (!allowAfterDispose && _isDisposed) {
      throw StateError(
        'SceneControllerInteractive is disposed and no longer usable.',
      );
    }
  }

  void _ensureExternalSelectionMutationAllowed(String operation) {
    if (_runtime.hasActiveGesture) {
      throw StateError('$operation is not allowed during an active gesture.');
    }
  }

  @override
  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
    if (_isDisposed) {
      return;
    }
    _runtime.resetInteractiveState();
    _core.dispose();
    _isDisposed = true;
    _notifyScheduler.dispose();
    _runtime.dispose();
    _events.dispose();
    super.dispose();
  }

  static double _requireFinitePositive(double value, {required String name}) {
    if (value.isFinite && value > 0) return value;
    throw ArgumentError.value(value, name, 'Must be a finite number > 0.');
  }

  static double _requireFiniteNonNegative(
    double value, {
    required String name,
  }) {
    if (value.isFinite && value >= 0) return value;
    throw ArgumentError.value(value, name, 'Must be a finite number >= 0.');
  }

  static double _requireFiniteInUnitInterval(
    double value, {
    required String name,
  }) {
    if (value.isFinite && value >= 0 && value <= 1) return value;
    throw ArgumentError.value(
      value,
      name,
      'Must be a finite number within [0,1].',
    );
  }

  static void _requireFiniteOffset(Offset value, {required String name}) {
    if (value.dx.isFinite && value.dy.isFinite) return;
    throw ArgumentError.value(value, name, 'Offset must be finite.');
  }
}

typedef SceneController = SceneControllerInteractive;
