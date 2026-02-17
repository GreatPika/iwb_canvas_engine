import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../core/action_events.dart';
import '../core/defaults.dart';
import '../core/geometry.dart';
import '../core/grid_safety_limits.dart';
import '../core/interaction_types.dart';
import '../core/nodes.dart' show TextNode;
import '../core/pointer_input.dart';
import '../core/transform2d.dart';
import '../controller/scene_controller.dart';
import '../public/canvas_pointer_input.dart';
import '../public/node_patch.dart';
import '../public/node_spec.dart';
import '../public/scene_render_state.dart';
import '../public/scene_write_txn.dart';
import '../public/snapshot.dart';
import 'internal/interactive_draw_coordinator.dart';
import 'internal/interactive_event_dispatcher.dart';
import 'internal/interactive_geometry.dart';
import 'internal/interactive_move_session.dart';
import 'internal/interactive_selection_utils.dart';

int sceneControllerInteractiveInternalEpoch(
  SceneControllerInteractive controller,
) {
  return controller._core.controllerEpoch;
}

Offset sceneControllerInteractiveInternalPreviewDeltaForNode(
  SceneControllerInteractive controller,
  NodeId nodeId,
) {
  return controller._moveSession.movePreviewDeltaForNode(nodeId);
}

void sceneControllerInteractiveInternalSetBeforePointerDispatchHook(
  SceneControllerInteractive controller,
  VoidCallback? hook,
) {
  controller._debugBeforeHandlePointerDispatchHook = hook;
}

void sceneControllerInteractiveInternalEnforceGestureBufferSoftLimitForTest(
  SceneControllerInteractive controller, {
  required List<Offset> points,
  required int softLimit,
  required int trimTo,
}) {
  enforceGestureBufferSoftLimit(points, softLimit: softLimit, trimTo: trimTo);
}

int sceneControllerInteractiveInternalActiveEraserPointsLength(
  SceneControllerInteractive controller,
) {
  return controller._drawCoordinator.activeEraserPointsLength;
}

int sceneControllerInteractiveInternalEraserSpatialQueryCount(
  SceneControllerInteractive controller,
) {
  // Test-only metric: number of coarse spatial queries used by last eraser
  // commit. Helps keep complexity guards deterministic across environments.
  return controller._drawCoordinator.debugEraserSpatialQueryCount;
}

int sceneControllerInteractiveInternalEraserPreciseSegmentCheckCount(
  SceneControllerInteractive controller,
) {
  // Test-only metric: number of exact segment-to-segment checks during last
  // eraser commit. Used as primary perf acceptance signal.
  return controller._drawCoordinator.debugEraserPreciseSegmentChecks;
}

class SceneControllerInteractive extends ChangeNotifier
    implements SceneRenderState {
  SceneControllerInteractive({
    SceneSnapshot? initialSnapshot,
    PointerInputSettings? pointerSettings,
    double? dragStartSlop,
    this.clearSelectionOnDrawModeEnter = false,
  }) : _pointerSettings = pointerSettings ?? const PointerInputSettings(),
       _dragStartSlop = dragStartSlop,
       _core = SceneControllerCore(initialSnapshot: initialSnapshot) {
    validatePointerInputSettings(_pointerSettings);
    _moveSession = InteractiveMoveSession(
      callbacks: InteractiveMoveSessionCallbacks(
        onStateChanged: _scheduleNotify,
        readSnapshot: () => snapshot,
        readSelectedNodeIds: () => selectedNodeIds,
        querySpatialCandidates: _core.querySpatialCandidates,
        resolveSpatialCandidateNode: _core.resolveSpatialCandidateNode,
        writeSelectionReplace: _core.commands.writeSelectionReplace,
        writeSelectionClear: _core.commands.writeSelectionClear,
        writeSelectionTranslate: (delta) {
          return _core.write<int>((writer) {
            return writer.writeSelectionTranslate(delta);
          });
        },
        emitAction: _events.emitAction,
      ),
    );
    _drawCoordinator = InteractiveDrawCoordinator(
      callbacks: InteractiveDrawCoordinatorCallbacks(
        onStateChanged: _scheduleNotify,
        emitAction: _events.emitAction,
        writeDrawStroke: _core.draw.writeDrawStroke,
        writeDrawLineFromWorldSegment: _writeDrawLineFromWorldSegment,
        querySpatialCandidates: _core.querySpatialCandidates,
        resolveSpatialCandidateNode: _core.resolveSpatialCandidateNode,
        writeEraseNodes: _core.draw.writeEraseNodes,
      ),
    );
    _core.addListener(_handleCoreChanged);
  }

  final SceneControllerCore _core;
  final InteractiveEventDispatcher _events = InteractiveEventDispatcher();
  late final InteractiveDrawCoordinator _drawCoordinator;
  late final InteractiveMoveSession _moveSession;

  PointerInputSettings _pointerSettings;
  double? _dragStartSlop;
  int _timestampCursorMs = -1;

  CanvasMode _mode = CanvasMode.move;
  DrawTool _drawTool = DrawTool.pen;
  Color _drawColor = SceneDefaults.penColors.first;
  double _penThickness = SceneDefaults.penThickness;
  double _highlighterThickness = SceneDefaults.highlighterThickness;
  double _lineThickness = SceneDefaults.penThickness;
  double _eraserThickness = SceneDefaults.eraserThickness;
  double _highlighterOpacity = SceneDefaults.highlighterOpacity;

  final bool clearSelectionOnDrawModeEnter;

  bool _notifyScheduled = false;
  bool _notifyPending = false;
  bool _isDisposed = false;
  bool _handlingPointer = false;
  VoidCallback? _debugBeforeHandlePointerDispatchHook;

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

  Rect? get selectionRect => _moveSession.selectionRect;

  Offset? get pendingLineStart => _drawCoordinator.pendingLineStart;
  int? get pendingLineTimestampMs => _drawCoordinator.pendingLineTimestampMs;
  bool get hasPendingLineStart => _drawCoordinator.hasPendingLineStart;
  bool get hasActiveStrokePreview =>
      _drawCoordinator.hasActivePointer &&
      (_drawTool == DrawTool.pen || _drawTool == DrawTool.highlighter) &&
      _drawCoordinator.hasActiveStrokePoints;
  List<Offset> get activeStrokePreviewPoints =>
      _drawCoordinator.activeStrokePreviewPoints;
  double get activeStrokePreviewThickness =>
      _drawTool == DrawTool.highlighter ? _highlighterThickness : _penThickness;
  Color get activeStrokePreviewColor => _drawColor;
  double get activeStrokePreviewOpacity =>
      _drawTool == DrawTool.highlighter ? _highlighterOpacity : 1;
  bool get hasActiveLinePreview =>
      _drawCoordinator.hasActivePointer &&
      _drawTool == DrawTool.line &&
      _drawCoordinator.activeLinePreviewStart != null &&
      _drawCoordinator.activeLinePreviewEnd != null;
  Offset? get activeLinePreviewStart => _drawCoordinator.activeLinePreviewStart;
  Offset? get activeLinePreviewEnd => _drawCoordinator.activeLinePreviewEnd;
  double get activeLinePreviewThickness => _lineThickness;
  Color get activeLinePreviewColor => _drawColor;

  PointerInputSettings get pointerSettings => _pointerSettings;

  Stream<ActionCommitted> get actions => _events.actions;
  Stream<EditTextRequested> get editTextRequests => _events.editTextRequests;

  T write<T>(T Function(SceneWriteTxn writer) fn) {
    _ensureNotDisposed();
    return _core.write(fn);
  }

  void setMode(CanvasMode value) {
    _ensureNotDisposed();
    if (_mode == value) return;

    if (_mode == CanvasMode.move) {
      _moveSession.resetGestureState();
    } else {
      _drawCoordinator.resetGestureState();
      _drawCoordinator.clearPendingLine();
    }

    _mode = value;
    _moveSession.setSelectionRect(null);

    if (value == CanvasMode.draw &&
        clearSelectionOnDrawModeEnter &&
        selectedNodeIds.isNotEmpty) {
      _core.commands.writeSelectionClear();
    }

    _scheduleNotify();
  }

  void setDrawTool(DrawTool value) {
    _ensureNotDisposed();
    if (_drawTool == value) return;
    _drawTool = value;
    _drawCoordinator.resetGestureState();
    _drawCoordinator.clearPendingLine();
    _scheduleNotify();
  }

  void setDrawColor(Color value) {
    _ensureNotDisposed();
    if (_drawColor == value) return;
    _drawColor = value;
    _scheduleNotify();
  }

  set penThickness(double value) {
    _ensureNotDisposed();
    _penThickness = _requireFinitePositive(value, name: 'penThickness');
    _scheduleNotify();
  }

  set highlighterThickness(double value) {
    _ensureNotDisposed();
    _highlighterThickness = _requireFinitePositive(
      value,
      name: 'highlighterThickness',
    );
    _scheduleNotify();
  }

  set lineThickness(double value) {
    _ensureNotDisposed();
    _lineThickness = _requireFinitePositive(value, name: 'lineThickness');
    _scheduleNotify();
  }

  set eraserThickness(double value) {
    _ensureNotDisposed();
    _eraserThickness = _requireFinitePositive(value, name: 'eraserThickness');
    _scheduleNotify();
  }

  set highlighterOpacity(double value) {
    _ensureNotDisposed();
    _highlighterOpacity = _requireFiniteInUnitInterval(
      value,
      name: 'highlighterOpacity',
    );
    _scheduleNotify();
  }

  void setPointerSettings(PointerInputSettings value) {
    _ensureNotDisposed();
    validatePointerInputSettings(value);
    _pointerSettings = value;
    _scheduleNotify();
  }

  void setDragStartSlop(double? value) {
    _ensureNotDisposed();
    final resolved = value == null
        ? null
        : _requireFinitePositive(value, name: 'dragStartSlop');
    if (_dragStartSlop == resolved) return;
    _dragStartSlop = resolved;
    _scheduleNotify();
  }

  void setBackgroundColor(Color value) {
    _ensureNotDisposed();
    _core.commands.writeBackgroundColorSet(value);
  }

  void setGridEnabled(bool value) {
    _ensureNotDisposed();
    _core.commands.writeGridEnabledSet(value);
  }

  void setGridCellSize(double value) {
    _ensureNotDisposed();
    _requireFinitePositive(value, name: 'cellSize');
    final gridEnabled = snapshot.background.grid.isEnabled;
    final resolved = gridEnabled
        ? value.clamp(kMinGridCellSize, double.infinity).toDouble()
        : value;
    _core.commands.writeGridCellSizeSet(resolved);
  }

  void setCameraOffset(Offset value) {
    _ensureNotDisposed();
    _requireFiniteOffset(value, name: 'value');
    _core.commands.writeCameraOffsetSet(value);
  }

  NodeId addNode(NodeSpec node, {LayerId? layerId}) {
    _ensureNotDisposed();
    return _core.commands.writeAddNode(node, layerId: layerId);
  }

  bool patchNode(NodePatch patch) {
    _ensureNotDisposed();
    return _core.commands.writePatchNode(patch);
  }

  bool removeNode(NodeId id, {int? timestampMs}) {
    _ensureNotDisposed();
    final deleted = _core.commands.writeDeleteNode(id);
    if (!deleted) return false;
    _events.emitAction(ActionType.delete, <NodeId>[
      id,
    ], _resolveTimestampMs(timestampMs));
    return true;
  }

  void setSelection(Iterable<NodeId> nodeIds) {
    _ensureNotDisposed();
    _core.commands.writeSelectionReplace(nodeIds);
  }

  void toggleSelection(NodeId nodeId) {
    _ensureNotDisposed();
    _core.commands.writeSelectionToggle(nodeId);
  }

  void clearSelection() {
    _ensureNotDisposed();
    _core.commands.writeSelectionClear();
  }

  void selectAll({bool onlySelectable = true}) {
    _ensureNotDisposed();
    _core.commands.writeSelectionSelectAll(onlySelectable: onlySelectable);
  }

  void rotateSelection({required bool clockwise, int? timestampMs}) {
    _ensureNotDisposed();
    final nodes = selectedTransformableNodesInSnapshotOrder(
      snapshot: snapshot,
      selected: selectedNodeIds,
    );
    if (nodes.isEmpty) return;

    final center = centerWorldForNodeSnapshots(nodes);
    final pivot = Transform2D.translation(center);
    final unpivot = Transform2D.translation(Offset(-center.dx, -center.dy));
    final rotation = Transform2D.rotationDeg(clockwise ? 90 : -90);
    final delta = pivot.multiply(rotation).multiply(unpivot);
    final movedIds = nodes.map((node) => node.id).toList(growable: false);
    final affected = _core.write<int>((writer) {
      return writer.writeSelectionTransform(delta);
    });

    if (affected > 0) {
      _events.emitAction(
        ActionType.transform,
        movedIds,
        _resolveTimestampMs(timestampMs),
        payload: <String, Object?>{'delta': delta.toJsonMap()},
      );
    }
  }

  void flipSelectionVertical({int? timestampMs}) {
    _ensureNotDisposed();
    final nodes = selectedTransformableNodesInSnapshotOrder(
      snapshot: snapshot,
      selected: selectedNodeIds,
    );
    if (nodes.isEmpty) return;

    final center = centerWorldForNodeSnapshots(nodes);
    final delta = Transform2D(
      a: 1,
      b: 0,
      c: 0,
      d: -1,
      tx: 0,
      ty: 2 * center.dy,
    );
    final movedIds = nodes.map((node) => node.id).toList(growable: false);
    final affected = _core.write<int>((writer) {
      return writer.writeSelectionTransform(delta);
    });

    if (affected > 0) {
      _events.emitAction(
        ActionType.transform,
        movedIds,
        _resolveTimestampMs(timestampMs),
        payload: <String, Object?>{'delta': delta.toJsonMap()},
      );
    }
  }

  void flipSelectionHorizontal({int? timestampMs}) {
    _ensureNotDisposed();
    final nodes = selectedTransformableNodesInSnapshotOrder(
      snapshot: snapshot,
      selected: selectedNodeIds,
    );
    if (nodes.isEmpty) return;

    final center = centerWorldForNodeSnapshots(nodes);
    final delta = Transform2D(
      a: -1,
      b: 0,
      c: 0,
      d: 1,
      tx: 2 * center.dx,
      ty: 0,
    );
    final movedIds = nodes.map((node) => node.id).toList(growable: false);
    final affected = _core.write<int>((writer) {
      return writer.writeSelectionTransform(delta);
    });

    if (affected > 0) {
      _events.emitAction(
        ActionType.transform,
        movedIds,
        _resolveTimestampMs(timestampMs),
        payload: <String, Object?>{'delta': delta.toJsonMap()},
      );
    }
  }

  void deleteSelection({int? timestampMs}) {
    _ensureNotDisposed();
    final deletedIds = deletableSelectedNodeIdsInSnapshot(
      snapshot: snapshot,
      selected: selectedNodeIds,
    );
    if (deletedIds.isEmpty) return;

    final removedCount = _core.commands.writeDeleteSelection();
    if (removedCount <= 0) return;

    _events.emitAction(
      ActionType.delete,
      deletedIds,
      _resolveTimestampMs(timestampMs),
    );
  }

  void clearScene({int? timestampMs}) {
    _ensureNotDisposed();
    final clearedIds = _core.write<List<NodeId>>((writer) {
      return writer.writeClearSceneKeepBackground();
    });
    if (clearedIds.isEmpty) return;

    _events.emitAction(
      ActionType.clear,
      clearedIds,
      _resolveTimestampMs(timestampMs),
    );
  }

  void replaceScene(SceneSnapshot snapshot) {
    _ensureNotDisposed();
    _core.writeReplaceScene(snapshot);
    _drawCoordinator.clearPendingLine();
    _moveSession.setSelectionRect(null);
  }

  void notifySceneChanged() {
    _ensureNotDisposed();
    _core.requestRepaint();
  }

  void handlePointer(CanvasPointerInput input) {
    _ensureNotDisposed();
    if (_handlingPointer) {
      throw StateError('Reentrant handlePointer(...) is not allowed.');
    }
    if (!_isFiniteOffset(input.position)) {
      return;
    }

    final resolvedSample = PointerSample(
      pointerId: input.pointerId,
      position: input.position,
      timestampMs: _resolveTimestampMs(input.timestampMs),
      phase: _toInternalPointerPhase(input.phase),
      kind: input.kind,
    );

    _handlingPointer = true;
    try {
      assert(() {
        _debugBeforeHandlePointerDispatchHook?.call();
        return true;
      }());
      if (_mode == CanvasMode.move) {
        _handleMovePointer(resolvedSample);
      } else {
        _handleDrawPointer(resolvedSample);
      }
    } finally {
      _handlingPointer = false;
    }
  }

  void handleDoubleTap({required Offset position, int? timestampMs}) {
    _ensureNotDisposed();
    if (!_isFiniteOffset(position)) {
      return;
    }
    if (_mode != CanvasMode.move) return;

    final scenePoint = _toScenePoint(position);
    final hit = _moveSession.hitTestTopNode(scenePoint);
    if (hit == null || hit is! TextNode) return;

    _events.emitEditTextRequested(
      EditTextRequested(
        nodeId: hit.id,
        timestampMs: _resolveTimestampMs(timestampMs),
        position: position,
      ),
    );
  }

  PointerPhase _toInternalPointerPhase(CanvasPointerPhase phase) {
    switch (phase) {
      case CanvasPointerPhase.down:
        return PointerPhase.down;
      case CanvasPointerPhase.move:
        return PointerPhase.move;
      case CanvasPointerPhase.up:
        return PointerPhase.up;
      case CanvasPointerPhase.cancel:
        return PointerPhase.cancel;
    }
  }

  void _handleMovePointer(PointerSample sample) {
    final scenePoint = _toScenePoint(sample.position);
    _moveSession.handlePointer(
      sample,
      scenePoint,
      dragStartSlop: dragStartSlop,
    );
  }

  void _handleDrawPointer(PointerSample sample) {
    final scenePoint = _toScenePoint(sample.position);
    _drawCoordinator.handlePointer(
      sample,
      scenePoint,
      drawTool: _drawTool,
      drawColor: _drawColor,
      penThickness: _penThickness,
      highlighterThickness: _highlighterThickness,
      lineThickness: _lineThickness,
      eraserThickness: _eraserThickness,
      highlighterOpacity: _highlighterOpacity,
      dragStartSlop: dragStartSlop,
    );
  }

  Offset _toScenePoint(Offset viewPoint) {
    return toScene(viewPoint, snapshot.camera.offset);
  }

  static bool _isFiniteOffset(Offset value) {
    return value.dx.isFinite && value.dy.isFinite;
  }

  int _resolveTimestampMs(int? hintTimestampMs) {
    final next = _timestampCursorMs + 1;
    final resolved = hintTimestampMs == null || hintTimestampMs < next
        ? next
        : hintTimestampMs;
    _timestampCursorMs = resolved;
    return resolved;
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
    if (_isDisposed) {
      return;
    }
    _notifyPending = true;
    if (_notifyScheduled) {
      return;
    }
    _notifyScheduled = true;

    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (_isDisposed || !_notifyPending) {
        return;
      }
      _notifyPending = false;
      notifyListeners();
    });
  }

  void _handleCoreChanged() {
    _scheduleNotify();
  }

  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw StateError(
        'SceneControllerInteractive is disposed and no longer usable.',
      );
    }
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _notifyPending = false;
    _notifyScheduled = false;
    _moveSession.dispose();
    _drawCoordinator.dispose();
    _core.removeListener(_handleCoreChanged);
    _core.dispose();
    _events.dispose();
    super.dispose();
  }

  static double _requireFinitePositive(double value, {required String name}) {
    if (value.isFinite && value > 0) return value;
    throw ArgumentError.value(value, name, 'Must be a finite number > 0.');
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
