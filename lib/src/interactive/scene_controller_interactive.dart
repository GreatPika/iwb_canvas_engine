import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../core/action_events.dart';
import '../core/defaults.dart';
import '../core/geometry.dart';
import '../core/grid_safety_limits.dart';
import '../core/hit_test.dart';
import '../core/input_sampling.dart';
import '../core/interaction_types.dart';
import '../core/nodes.dart' show LineNode, SceneNode, StrokeNode, TextNode;
import '../core/pointer_input.dart';
import '../core/scene_limits.dart';
import '../core/scene_spatial_index.dart';
import '../core/transform2d.dart';
import '../controller/scene_controller.dart';
import '../public/canvas_pointer_input.dart';
import '../public/node_patch.dart';
import '../public/node_spec.dart';
import '../public/scene_render_state.dart';
import '../public/scene_write_txn.dart';
import '../public/snapshot.dart';
import 'internal/interactive_event_dispatcher.dart';
import 'internal/interactive_geometry.dart';
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
  return controller._movePreviewDeltaForNode(nodeId);
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
  controller._enforceGestureBufferSoftLimit(
    points,
    softLimit: softLimit,
    trimTo: trimTo,
  );
}

int sceneControllerInteractiveInternalActiveEraserPointsLength(
  SceneControllerInteractive controller,
) {
  return controller._activeEraserPoints.length;
}

int sceneControllerInteractiveInternalEraserSpatialQueryCount(
  SceneControllerInteractive controller,
) {
  // Test-only metric: number of coarse spatial queries used by last eraser
  // commit. Helps keep complexity guards deterministic across environments.
  return controller._debugEraserSpatialQueryCount;
}

int sceneControllerInteractiveInternalEraserPreciseSegmentCheckCount(
  SceneControllerInteractive controller,
) {
  // Test-only metric: number of exact segment-to-segment checks during last
  // eraser commit. Used as primary perf acceptance signal.
  return controller._debugEraserPreciseSegmentChecks;
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
    _core.addListener(_handleCoreChanged);
  }

  final SceneControllerCore _core;
  final InteractiveEventDispatcher _events = InteractiveEventDispatcher();

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

  Rect? _selectionRect;

  int? _moveActivePointerId;
  Offset? _movePointerDownScene;
  Offset? _moveLastScene;
  _MoveDragTarget _moveTarget = _MoveDragTarget.none;
  bool _moveDragStarted = false;
  bool _movePendingClearSelection = false;
  Set<NodeId> _moveMarqueeBaseline = <NodeId>{};
  bool _movePreviewActive = false;
  Offset _movePreviewDelta = Offset.zero;
  Set<NodeId> _movePreviewNodeIds = <NodeId>{};

  int? _drawActivePointerId;
  Offset? _drawDownScene;
  bool _drawMoved = false;
  final List<Offset> _activeStrokePoints = <Offset>[];
  late final UnmodifiableListView<Offset> _activeStrokePointsView =
      UnmodifiableListView<Offset>(_activeStrokePoints);
  final List<Offset> _activeEraserPoints = <Offset>[];
  Offset? _activeLinePreviewStart;
  Offset? _activeLinePreviewEnd;

  Offset? _pendingLineStart;
  int? _pendingLineTimestampMs;
  Timer? _pendingLineTimer;
  bool _notifyScheduled = false;
  bool _notifyPending = false;
  bool _isDisposed = false;
  bool _handlingPointer = false;
  VoidCallback? _debugBeforeHandlePointerDispatchHook;
  int _debugEraserSpatialQueryCount = 0;
  int _debugEraserPreciseSegmentChecks = 0;

  static const Duration _pendingLineTimeout = Duration(seconds: 10);
  // Eraser batching constants tune the coarse-vs-precise tradeoff:
  // - larger values reduce spatial queries but widen candidate prefilter bounds;
  // - smaller values increase query overhead.
  // Invariant: complexity should stay sub-linear for spatial queries and bounded
  // for precise checks in long gestures. Validate with:
  // - "long eraser commit keeps bounded query/check complexity"
  // - "eraser zigzag path keeps coarse prefilter correctness and bounded checks"
  // Do not change these constants without updating perf acceptance tests.
  static const int _eraserQueryBatchSegments = 64;
  static const int _eraserHitBatchSegments = 64;
  static const int _strokeHitBatchSegments = 32;

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

  Rect? get selectionRect => _selectionRect;

  Offset? get pendingLineStart => _pendingLineStart;
  int? get pendingLineTimestampMs => _pendingLineTimestampMs;
  bool get hasPendingLineStart => _pendingLineStart != null;
  bool get hasActiveStrokePreview =>
      _drawActivePointerId != null &&
      (_drawTool == DrawTool.pen || _drawTool == DrawTool.highlighter) &&
      _activeStrokePoints.isNotEmpty;
  List<Offset> get activeStrokePreviewPoints => _activeStrokePointsView;
  double get activeStrokePreviewThickness =>
      _drawTool == DrawTool.highlighter ? _highlighterThickness : _penThickness;
  Color get activeStrokePreviewColor => _drawColor;
  double get activeStrokePreviewOpacity =>
      _drawTool == DrawTool.highlighter ? _highlighterOpacity : 1;
  bool get hasActiveLinePreview =>
      _drawActivePointerId != null &&
      _drawTool == DrawTool.line &&
      _activeLinePreviewStart != null &&
      _activeLinePreviewEnd != null;
  Offset? get activeLinePreviewStart => _activeLinePreviewStart;
  Offset? get activeLinePreviewEnd => _activeLinePreviewEnd;
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
      _resetMoveGestureState();
    } else {
      _resetDrawGestureState();
      _clearPendingLine();
    }

    _mode = value;
    _setSelectionRect(null);

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
    _resetDrawGestureState();
    _clearPendingLine();
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
    _requireFinitePositive(value, name: 'value');
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

  String addNode(NodeSpec node, {int? layerIndex}) {
    _ensureNotDisposed();
    return _core.commands.writeAddNode(node, layerIndex: layerIndex);
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
    _clearPendingLine();
    _setSelectionRect(null);
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
    final hit = _hitTestTopNode(scenePoint);
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
    if (_moveActivePointerId != null &&
        _moveActivePointerId != sample.pointerId) {
      return;
    }

    final scenePoint = _toScenePoint(sample.position);
    switch (sample.phase) {
      case PointerPhase.down:
        _moveHandleDown(sample, scenePoint);
        break;
      case PointerPhase.move:
        _moveHandleMove(sample, scenePoint);
        break;
      case PointerPhase.up:
        _moveHandleUp(sample, scenePoint);
        break;
      case PointerPhase.cancel:
        _resetMoveGestureState();
        _setSelectionRect(null);
        _scheduleNotify();
        break;
    }
  }

  void _moveHandleDown(PointerSample sample, Offset scenePoint) {
    _moveActivePointerId = sample.pointerId;
    _movePointerDownScene = scenePoint;
    _moveLastScene = scenePoint;
    _moveDragStarted = false;
    _movePendingClearSelection = false;
    _moveMarqueeBaseline = Set<NodeId>.from(selectedNodeIds);

    final hit = _hitTestTopNode(scenePoint);
    if (hit != null) {
      _moveTarget = _MoveDragTarget.move;
      Set<NodeId> previewNodeIds = selectedNodeIds;
      if (!selectedNodeIds.contains(hit.id)) {
        _core.commands.writeSelectionReplace(<NodeId>{hit.id});
        previewNodeIds = <NodeId>{hit.id};
      }
      _startMovePreview(previewNodeIds);
      _scheduleNotify();
      return;
    }

    _moveTarget = _MoveDragTarget.marquee;
    _movePendingClearSelection = true;
    _clearMovePreview();
    _scheduleNotify();
  }

  void _moveHandleMove(PointerSample sample, Offset scenePoint) {
    if (_moveActivePointerId != sample.pointerId) return;
    if (_movePointerDownScene == null || _moveLastScene == null) return;

    final didStartDrag =
        !_moveDragStarted &&
        isDistanceGreaterThan(
          _movePointerDownScene!,
          scenePoint,
          dragStartSlop,
        );

    if (didStartDrag) {
      _moveDragStarted = true;
      if (_moveTarget == _MoveDragTarget.marquee &&
          _movePendingClearSelection) {
        _core.commands.writeSelectionClear();
        _movePendingClearSelection = false;
      }
    }

    if (!_moveDragStarted) return;

    if (_moveTarget == _MoveDragTarget.move) {
      final deltaStep = scenePoint - _moveLastScene!;
      if (deltaStep == Offset.zero) return;
      _movePreviewDelta = _movePreviewDelta + deltaStep;
      _moveLastScene = scenePoint;
      _scheduleNotify();
      return;
    }

    if (_moveTarget == _MoveDragTarget.marquee) {
      _setSelectionRect(Rect.fromPoints(_movePointerDownScene!, scenePoint));
    }
  }

  void _moveHandleUp(PointerSample sample, Offset scenePoint) {
    if (_moveActivePointerId != sample.pointerId) return;

    if (_moveTarget == _MoveDragTarget.move) {
      final finalDelta = _movePreviewDelta;
      final movedIds = selectedTransformableNodesInSnapshotOrder(
        snapshot: snapshot,
        selected: _movePreviewNodeIds,
      ).map((node) => node.id).toList(growable: false);
      _clearMovePreview();
      if (_moveDragStarted) {
        var affected = 0;
        if (finalDelta != Offset.zero) {
          affected = _core.write<int>((writer) {
            return writer.writeSelectionTranslate(finalDelta);
          });
        }
        if (affected > 0 && movedIds.isNotEmpty) {
          final delta = Transform2D.translation(finalDelta);
          _events.emitAction(
            ActionType.transform,
            movedIds,
            sample.timestampMs,
            payload: <String, Object?>{'delta': delta.toJsonMap()},
          );
        }
      }
    } else if (_moveTarget == _MoveDragTarget.marquee) {
      if (_moveDragStarted && _selectionRect != null) {
        _commitMarquee(sample.timestampMs);
      } else if (_movePendingClearSelection) {
        _core.commands.writeSelectionClear();
      }
    }

    _resetMoveGestureState();
    _setSelectionRect(null);
    _scheduleNotify();
  }

  void _commitMarquee(int timestampMs) {
    final rect = _selectionRect;
    if (rect == null) return;

    final selected = _nodesIntersecting(rect);
    _core.commands.writeSelectionReplace(selected);

    final currentSelection = selectedNodeIds;
    final didChange =
        _moveMarqueeBaseline.length != currentSelection.length ||
        !_moveMarqueeBaseline.containsAll(currentSelection);
    if (didChange) {
      _events.emitAction(
        ActionType.selectMarquee,
        currentSelection.toList(growable: false),
        timestampMs,
      );
    }
  }

  void _handleDrawPointer(PointerSample sample) {
    if (_drawActivePointerId != null &&
        _drawActivePointerId != sample.pointerId) {
      return;
    }

    final scenePoint = _toScenePoint(sample.position);
    switch (sample.phase) {
      case PointerPhase.down:
        _drawHandleDown(sample, scenePoint);
        break;
      case PointerPhase.move:
        _drawHandleMove(sample, scenePoint);
        break;
      case PointerPhase.up:
        _drawHandleUp(sample, scenePoint);
        break;
      case PointerPhase.cancel:
        _clearPendingLine();
        _resetDrawGestureState();
        _scheduleNotify();
        break;
    }
  }

  void _drawHandleDown(PointerSample sample, Offset scenePoint) {
    _drawActivePointerId = sample.pointerId;
    _drawDownScene = scenePoint;
    _drawMoved = false;

    switch (_drawTool) {
      case DrawTool.pen:
      case DrawTool.highlighter:
        _activeStrokePoints
          ..clear()
          ..add(scenePoint);
        break;
      case DrawTool.line:
        _setActiveLinePreview(null, null);
        break;
      case DrawTool.eraser:
        _activeEraserPoints
          ..clear()
          ..add(scenePoint);
        break;
    }
  }

  void _drawHandleMove(PointerSample sample, Offset scenePoint) {
    if (_drawActivePointerId != sample.pointerId) return;

    switch (_drawTool) {
      case DrawTool.pen:
      case DrawTool.highlighter:
        if (_activeStrokePoints.isNotEmpty &&
            isDistanceAtLeast(
              _activeStrokePoints.last,
              scenePoint,
              kInputDecimationMinStepScene,
            )) {
          _activeStrokePoints.add(scenePoint);
          _enforceGestureBufferSoftLimit(
            _activeStrokePoints,
            softLimit: kInteractiveStrokePointsSoftLimit,
            trimTo: kInteractiveStrokePointsTrimTo,
          );
          _scheduleNotify();
        }
        break;
      case DrawTool.line:
        if (_drawDownScene == null) return;
        if (!_drawMoved &&
            isDistanceAtMost(_drawDownScene!, scenePoint, dragStartSlop)) {
          return;
        }
        _drawMoved = true;
        if (_pendingLineStart != null) {
          _clearPendingLine();
        }
        _setActiveLinePreview(_drawDownScene, scenePoint);
        _scheduleNotify();
        break;
      case DrawTool.eraser:
        if (_activeEraserPoints.isEmpty) return;
        if (isDistanceAtLeast(
          _activeEraserPoints.last,
          scenePoint,
          kInputDecimationMinStepScene,
        )) {
          _activeEraserPoints.add(scenePoint);
          _enforceGestureBufferSoftLimit(
            _activeEraserPoints,
            softLimit: kInteractiveEraserPointsSoftLimit,
            trimTo: kInteractiveEraserPointsTrimTo,
          );
          _scheduleNotify();
        }
        break;
    }
  }

  void _drawHandleUp(PointerSample sample, Offset scenePoint) {
    if (_drawActivePointerId != sample.pointerId) return;

    switch (_drawTool) {
      case DrawTool.pen:
      case DrawTool.highlighter:
        _commitStroke(sample.timestampMs, scenePoint);
        break;
      case DrawTool.line:
        _commitLine(sample.timestampMs, scenePoint);
        break;
      case DrawTool.eraser:
        _commitEraser(sample.timestampMs, scenePoint);
        break;
    }

    _drawActivePointerId = null;
    _drawDownScene = null;
    _drawMoved = false;
    _setActiveLinePreview(null, null);
  }

  void _commitStroke(int timestampMs, Offset scenePoint) {
    if (_activeStrokePoints.isEmpty) return;
    if (isDistanceGreaterThan(_activeStrokePoints.last, scenePoint, 0)) {
      _activeStrokePoints.add(scenePoint);
    }
    final committedPoints = resamplePointsToLimit(
      _activeStrokePoints,
      limit: kMaxStrokePointsPerNode,
    );

    final strokeId = _core.draw.writeDrawStroke(
      points: committedPoints,
      thickness: _drawTool == DrawTool.highlighter
          ? _highlighterThickness
          : _penThickness,
      color: _drawColor,
      opacity: _drawTool == DrawTool.highlighter ? _highlighterOpacity : 1,
    );

    _events.emitAction(
      _drawTool == DrawTool.highlighter
          ? ActionType.drawHighlighter
          : ActionType.drawStroke,
      <NodeId>[strokeId],
      timestampMs,
      payload: <String, Object?>{
        'tool': _drawTool.name,
        'color': _drawColor.toARGB32(),
        'thickness': _drawTool == DrawTool.highlighter
            ? _highlighterThickness
            : _penThickness,
      },
    );

    _activeStrokePoints.clear();
  }

  void _enforceGestureBufferSoftLimit(
    List<Offset> points, {
    required int softLimit,
    required int trimTo,
  }) {
    enforceGestureBufferSoftLimit(points, softLimit: softLimit, trimTo: trimTo);
  }

  void _commitLine(int timestampMs, Offset scenePoint) {
    final drawDown = _drawDownScene;
    if (drawDown == null) return;

    final isTap = isDistanceAtMost(drawDown, scenePoint, dragStartSlop);
    if (!isTap || _drawMoved) {
      final lineId = _writeDrawLineFromWorldSegment(
        start: drawDown,
        end: scenePoint,
      );
      _events.emitAction(
        ActionType.drawLine,
        <NodeId>[lineId],
        timestampMs,
        payload: <String, Object?>{
          'tool': _drawTool.name,
          'color': _drawColor.toARGB32(),
          'thickness': _lineThickness,
        },
      );
      _clearPendingLine();
      return;
    }

    if (_pendingLineStart == null) {
      _setPendingLineStart(scenePoint, timestampMs);
      return;
    }

    final start = _pendingLineStart!;
    _clearPendingLine();
    final lineId = _writeDrawLineFromWorldSegment(
      start: start,
      end: scenePoint,
    );
    _events.emitAction(
      ActionType.drawLine,
      <NodeId>[lineId],
      timestampMs,
      payload: <String, Object?>{
        'tool': _drawTool.name,
        'color': _drawColor.toARGB32(),
        'thickness': _lineThickness,
      },
    );
  }

  void _commitEraser(int timestampMs, Offset scenePoint) {
    if (_activeEraserPoints.isEmpty) return;
    _debugEraserSpatialQueryCount = 0;
    _debugEraserPreciseSegmentChecks = 0;
    if (isDistanceGreaterThan(_activeEraserPoints.last, scenePoint, 0)) {
      _activeEraserPoints.add(scenePoint);
      _enforceGestureBufferSoftLimit(
        _activeEraserPoints,
        softLimit: kInteractiveEraserPointsSoftLimit,
        trimTo: kInteractiveEraserPointsTrimTo,
      );
    }

    final deletedIds = _eraseAnnotations(_activeEraserPoints);
    _activeEraserPoints.clear();
    if (deletedIds.isEmpty) return;

    _events.emitAction(
      ActionType.erase,
      deletedIds,
      timestampMs,
      payload: <String, Object?>{'eraserThickness': _eraserThickness},
    );
  }

  List<NodeId> _eraseAnnotations(List<Offset> eraserPoints) {
    final candidates = _queryEraserCandidates(eraserPoints)
      ..sort((left, right) {
        final byLayer = left.layerIndex.compareTo(right.layerIndex);
        if (byLayer != 0) return byLayer;
        return left.nodeIndex.compareTo(right.nodeIndex);
      });

    final ids = <NodeId>[];
    for (final candidate in candidates) {
      final node = _core.resolveSpatialCandidateNode(candidate);
      if (node == null) continue;
      if (node is! StrokeNode && node is! LineNode) continue;
      if (!node.isDeletable) continue;
      if (!_eraserHitsNode(eraserPoints, node)) continue;
      ids.add(node.id);
    }

    if (ids.isEmpty) return const <NodeId>[];

    final removedCount = _core.draw.writeEraseNodes(ids);
    if (removedCount <= 0) return const <NodeId>[];

    return ids;
  }

  List<SceneSpatialCandidate> _queryEraserCandidates(
    List<Offset> eraserPoints,
  ) {
    final byId = <NodeId, SceneSpatialCandidate>{};
    final queryPadding = _eraserThickness / 2 + kHitSlop;

    if (eraserPoints.length == 1) {
      final point = eraserPoints.first;
      final probe = Rect.fromLTWH(
        point.dx,
        point.dy,
        0,
        0,
      ).inflate(queryPadding);
      for (final candidate in _querySpatialCandidatesForEraser(probe)) {
        byId[candidate.node.id] = candidate;
      }
      return byId.values.toList(growable: false);
    }

    final segmentCount = eraserPoints.length - 1;
    for (
      var segmentStart = 0;
      segmentStart < segmentCount;
      segmentStart += _eraserQueryBatchSegments
    ) {
      final segmentEndExclusive = math.min(
        segmentStart + _eraserQueryBatchSegments,
        segmentCount,
      );
      final batchBounds = segmentRangeBounds(
        eraserPoints,
        segmentStart: segmentStart,
        segmentEndExclusive: segmentEndExclusive,
      ).inflate(queryPadding);
      for (final candidate in _querySpatialCandidatesForEraser(batchBounds)) {
        byId[candidate.node.id] = candidate;
      }
    }

    return byId.values.toList(growable: false);
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
    final sigmaMax = maxSingularValue2x2(
      inverse.a,
      inverse.b,
      inverse.c,
      inverse.d,
    );
    final threshold = line.thickness / 2 + (_eraserThickness / 2) * sigmaMax;
    final thresholdSquared = threshold * threshold;

    if (localEraserPoints.length == 1) {
      return distanceSquaredPointToSegment(
            localEraserPoints.first,
            line.start,
            line.end,
          ) <=
          thresholdSquared;
    }

    final lineBounds = Rect.fromPoints(line.start, line.end);
    final eraserBatches = buildSegmentBatches(
      localEraserPoints,
      batchSize: _eraserHitBatchSegments,
    );
    for (final batch in eraserBatches) {
      if (!rectsCanBeWithinDistance(batch.bounds, lineBounds, threshold)) {
        continue;
      }
      for (var i = batch.startSegment; i < batch.endSegmentExclusive; i++) {
        _debugEraserPreciseSegmentChecks = _debugEraserPreciseSegmentChecks + 1;
        if (distanceSquaredSegmentToSegment(
              localEraserPoints[i],
              localEraserPoints[i + 1],
              line.start,
              line.end,
            ) <=
            thresholdSquared) {
          return true;
        }
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
    final sigmaMax = maxSingularValue2x2(
      inverse.a,
      inverse.b,
      inverse.c,
      inverse.d,
    );
    final threshold = stroke.thickness / 2 + (_eraserThickness / 2) * sigmaMax;
    final thresholdSquared = threshold * threshold;

    if (stroke.points.isEmpty) return false;

    if (stroke.points.length == 1) {
      final point = stroke.points.first;
      for (final eraserPoint in localEraserPoints) {
        final delta = eraserPoint - point;
        if (delta.dx * delta.dx + delta.dy * delta.dy <= thresholdSquared) {
          return true;
        }
      }
      return false;
    }

    if (localEraserPoints.length == 1) {
      final eraserPoint = localEraserPoints.first;
      for (var i = 0; i < stroke.points.length - 1; i++) {
        if (distanceSquaredPointToSegment(
              eraserPoint,
              stroke.points[i],
              stroke.points[i + 1],
            ) <=
            thresholdSquared) {
          return true;
        }
      }
      return false;
    }

    final eraserBatches = buildSegmentBatches(
      localEraserPoints,
      batchSize: _eraserHitBatchSegments,
    );
    final strokeBatches = buildSegmentBatches(
      stroke.points,
      batchSize: _strokeHitBatchSegments,
    );
    for (final eraserBatch in eraserBatches) {
      for (final strokeBatch in strokeBatches) {
        if (!rectsCanBeWithinDistance(
          eraserBatch.bounds,
          strokeBatch.bounds,
          threshold,
        )) {
          continue;
        }
        for (
          var i = eraserBatch.startSegment;
          i < eraserBatch.endSegmentExclusive;
          i++
        ) {
          for (
            var j = strokeBatch.startSegment;
            j < strokeBatch.endSegmentExclusive;
            j++
          ) {
            _debugEraserPreciseSegmentChecks =
                _debugEraserPreciseSegmentChecks + 1;
            if (distanceSquaredSegmentToSegment(
                  localEraserPoints[i],
                  localEraserPoints[i + 1],
                  stroke.points[j],
                  stroke.points[j + 1],
                ) <=
                thresholdSquared) {
              return true;
            }
          }
        }
      }
    }

    return false;
  }

  List<SceneSpatialCandidate> _querySpatialCandidatesForEraser(Rect bounds) {
    _debugEraserSpatialQueryCount = _debugEraserSpatialQueryCount + 1;
    return _core.querySpatialCandidates(bounds);
  }

  Set<NodeId> _nodesIntersecting(Rect rect) {
    final ids = <NodeId>{};
    final candidates = _core.querySpatialCandidates(rect).toList(growable: true)
      ..sort((left, right) {
        final byLayer = left.layerIndex.compareTo(right.layerIndex);
        if (byLayer != 0) return byLayer;
        return left.nodeIndex.compareTo(right.nodeIndex);
      });

    for (final candidate in candidates) {
      final node = _core.resolveSpatialCandidateNode(candidate);
      if (node == null) continue;
      if (!node.isVisible || !node.isSelectable) continue;
      if (!_effectiveNodeBoundsWorld(node).overlaps(rect)) continue;
      ids.add(node.id);
    }

    return ids;
  }

  SceneNode? _hitTestTopNode(Offset scenePoint) {
    final candidates = _queryHitTestCandidates(scenePoint);

    for (final candidate in candidates) {
      final node = _core.resolveSpatialCandidateNode(candidate);
      if (node == null) continue;
      if (!node.isVisible || !node.isSelectable) continue;
      if (_hitTestNodeWithMovePreview(scenePoint, node)) {
        return node;
      }
    }

    return null;
  }

  List<SceneSpatialCandidate> _queryHitTestCandidates(Offset scenePoint) {
    final probe = Rect.fromLTWH(scenePoint.dx, scenePoint.dy, 0, 0);
    final byNodeId = <NodeId, SceneSpatialCandidate>{};
    for (final candidate in _core.querySpatialCandidates(probe)) {
      byNodeId[candidate.node.id] = candidate;
    }
    if (_hasMovePreviewTranslation) {
      final shiftedProbe = Rect.fromLTWH(
        scenePoint.dx - _movePreviewDelta.dx,
        scenePoint.dy - _movePreviewDelta.dy,
        0,
        0,
      );
      for (final candidate in _core.querySpatialCandidates(shiftedProbe)) {
        byNodeId[candidate.node.id] = candidate;
      }
    }
    final candidates = byNodeId.values.toList(growable: true)
      ..sort((left, right) {
        final byLayer = right.layerIndex.compareTo(left.layerIndex);
        if (byLayer != 0) return byLayer;
        return right.nodeIndex.compareTo(left.nodeIndex);
      });
    return candidates;
  }

  void _resetMoveGestureState() {
    _moveActivePointerId = null;
    _movePointerDownScene = null;
    _moveLastScene = null;
    _moveTarget = _MoveDragTarget.none;
    _moveDragStarted = false;
    _movePendingClearSelection = false;
    _moveMarqueeBaseline = <NodeId>{};
    _clearMovePreview();
  }

  void _startMovePreview(Set<NodeId> nodeIds) {
    _movePreviewActive = true;
    _movePreviewDelta = Offset.zero;
    _movePreviewNodeIds = Set<NodeId>.from(nodeIds);
  }

  void _clearMovePreview() {
    _movePreviewActive = false;
    _movePreviewDelta = Offset.zero;
    _movePreviewNodeIds = <NodeId>{};
  }

  bool get _hasMovePreviewTranslation =>
      _movePreviewActive &&
      _movePreviewNodeIds.isNotEmpty &&
      _movePreviewDelta != Offset.zero;

  Offset _movePreviewDeltaForNode(NodeId nodeId) {
    if (!_hasMovePreviewTranslation) return Offset.zero;
    if (!_movePreviewNodeIds.contains(nodeId)) return Offset.zero;
    return _movePreviewDelta;
  }

  Rect _effectiveNodeBoundsWorld(SceneNode node) {
    final delta = _movePreviewDeltaForNode(node.id);
    return node.boundsWorld.shift(delta);
  }

  bool _hitTestNodeWithMovePreview(Offset scenePoint, SceneNode node) {
    final delta = _movePreviewDeltaForNode(node.id);
    if (delta == Offset.zero) {
      return hitTestNode(scenePoint, node);
    }
    return hitTestNode(scenePoint - delta, node);
  }

  void _resetDrawGestureState() {
    _drawActivePointerId = null;
    _drawDownScene = null;
    _drawMoved = false;
    _activeStrokePoints.clear();
    _activeEraserPoints.clear();
    _setActiveLinePreview(null, null);
  }

  void _setActiveLinePreview(Offset? start, Offset? end) {
    if (_activeLinePreviewStart == start && _activeLinePreviewEnd == end) {
      return;
    }
    _activeLinePreviewStart = start;
    _activeLinePreviewEnd = end;
    _scheduleNotify();
  }

  void _setSelectionRect(Rect? value) {
    if (_selectionRect == value) return;
    _selectionRect = value;
    _scheduleNotify();
  }

  void _setPendingLineStart(Offset? start, int? timestampMs) {
    if (_pendingLineStart == start && _pendingLineTimestampMs == timestampMs) {
      return;
    }
    _pendingLineTimer?.cancel();
    _pendingLineTimer = null;
    _pendingLineStart = start;
    _pendingLineTimestampMs = timestampMs;
    if (_pendingLineStart != null) {
      _pendingLineTimer = Timer(_pendingLineTimeout, _clearPendingLine);
    }
    _scheduleNotify();
  }

  void _clearPendingLine() {
    _setPendingLineStart(null, null);
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
    _pendingLineTimer?.cancel();
    _pendingLineTimer = null;
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

enum _MoveDragTarget { none, move, marquee }

typedef SceneController = SceneControllerInteractive;
