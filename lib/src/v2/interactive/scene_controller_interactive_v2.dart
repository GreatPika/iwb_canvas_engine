import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../core/action_events.dart';
import '../../core/defaults.dart';
import '../../core/geometry.dart';
import '../../core/hit_test.dart';
import '../../core/input_sampling.dart';
import '../../core/interaction_types.dart';
import '../../core/nodes.dart';
import '../../core/pointer_input.dart';
import '../../core/scene.dart';
import '../../core/scene_spatial_index.dart';
import '../../core/selection_policy.dart';
import '../../core/transform2d.dart';
import '../controller/scene_controller_v2.dart';
import '../controller/scene_writer.dart';
import '../model/document.dart';
import '../public/node_patch.dart';
import '../public/node_spec.dart';
import '../public/snapshot.dart' hide NodeId;

class SceneControllerInteractiveV2 extends ChangeNotifier {
  SceneControllerInteractiveV2({
    Scene? scene,
    SceneSnapshot? initialSnapshot,
    PointerInputSettings? pointerSettings,
    double? dragStartSlop,
    this.clearSelectionOnDrawModeEnter = false,
  }) : _pointerSettings = pointerSettings ?? const PointerInputSettings(),
       _dragStartSlop = dragStartSlop,
       _core = SceneControllerV2(
         initialSnapshot:
             initialSnapshot ??
             (scene == null ? null : txnSceneToSnapshot(scene)),
       ) {
    _core.addListener(_handleCoreChanged);
  }

  final SceneControllerV2 _core;
  final _InteractiveEventDispatcher _events = _InteractiveEventDispatcher();

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
  Map<NodeId, Transform2D> _moveInitialTransforms = <NodeId, Transform2D>{};

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

  static const Duration _pendingLineTimeout = Duration(seconds: 10);

  SceneControllerV2 get core => _core;

  SceneSnapshot get snapshot => _core.snapshot;
  Scene get scene => txnSceneFromSnapshot(snapshot);
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

  int get controllerEpoch => _core.controllerEpoch;
  int get structuralRevision => _core.structuralRevision;
  int get boundsRevision => _core.boundsRevision;
  int get visualRevision => _core.visualRevision;

  T write<T>(T Function(SceneWriter writer) fn) => _core.write(fn);

  void setMode(CanvasMode value) {
    if (_mode == value) return;

    if (_mode == CanvasMode.move) {
      _rollbackMoveGestureIfNeeded();
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
      _core.commands.writeSelectionReplace(const <NodeId>{});
    }

    notifyListeners();
  }

  void setDrawTool(DrawTool value) {
    if (_drawTool == value) return;
    _drawTool = value;
    _resetDrawGestureState();
    _clearPendingLine();
    notifyListeners();
  }

  void setDrawColor(Color value) {
    if (_drawColor == value) return;
    _drawColor = value;
    notifyListeners();
  }

  set penThickness(double value) {
    _penThickness = _requireFinitePositive(value, name: 'penThickness');
    notifyListeners();
  }

  set highlighterThickness(double value) {
    _highlighterThickness = _requireFinitePositive(
      value,
      name: 'highlighterThickness',
    );
    notifyListeners();
  }

  set lineThickness(double value) {
    _lineThickness = _requireFinitePositive(value, name: 'lineThickness');
    notifyListeners();
  }

  set eraserThickness(double value) {
    _eraserThickness = _requireFinitePositive(value, name: 'eraserThickness');
    notifyListeners();
  }

  set highlighterOpacity(double value) {
    _highlighterOpacity = _requireFiniteInUnitInterval(
      value,
      name: 'highlighterOpacity',
    );
    notifyListeners();
  }

  void setPointerSettings(PointerInputSettings value) {
    _pointerSettings = value;
    notifyListeners();
  }

  void setDragStartSlop(double? value) {
    final resolved = value == null
        ? null
        : _requireFinitePositive(value, name: 'dragStartSlop');
    if (_dragStartSlop == resolved) return;
    _dragStartSlop = resolved;
    notifyListeners();
  }

  void setBackgroundColor(Color value) {
    _core.commands.writeBackgroundColorSet(value);
  }

  void setGridEnabled(bool value) {
    _core.commands.writeGridEnabledSet(value);
  }

  void setGridCellSize(double value) {
    final gridEnabled = snapshot.background.grid.isEnabled;
    final resolved = gridEnabled
        ? value.clamp(1.0, double.infinity).toDouble()
        : value;
    _core.commands.writeGridCellSizeSet(resolved);
  }

  void setCameraOffset(Offset value) {
    _requireFiniteOffset(value, name: 'value');
    _core.commands.writeCameraOffsetSet(value);
  }

  String addNode(Object node, {int? layerIndex}) {
    if (node is NodeSpec) {
      return _core.commands.writeAddNode(node, layerIndex: layerIndex);
    }
    if (node is SceneNode) {
      return _core.commands.writeAddNode(
        _nodeSpecFromLegacyNode(node),
        layerIndex: layerIndex,
      );
    }
    throw ArgumentError.value(node, 'node', 'Expected NodeSpec or SceneNode.');
  }

  bool patchNode(NodePatch patch) {
    return _core.commands.writePatchNode(patch);
  }

  bool removeNode(NodeId id, {int? timestampMs}) {
    final deleted = _core.commands.writeDeleteNode(id);
    if (!deleted) return false;
    _events.emitAction(ActionType.delete, <NodeId>[
      id,
    ], _resolveTimestampMs(timestampMs));
    return true;
  }

  void setSelection(Iterable<NodeId> nodeIds) {
    _core.commands.writeSelectionReplace(nodeIds);
  }

  void toggleSelection(NodeId nodeId) {
    _core.commands.writeSelectionToggle(nodeId);
  }

  void clearSelection() {
    _core.commands.writeSelectionClear();
  }

  void selectAll({bool onlySelectable = true}) {
    _core.commands.writeSelectionSelectAll(onlySelectable: onlySelectable);
  }

  void rotateSelection({required bool clockwise, int? timestampMs}) {
    var affected = 0;
    Transform2D? delta;
    final movedIds = <NodeId>[];
    _core.write<void>((writer) {
      final nodes = selectedTransformableNodesInSceneOrder(
        writer.scene,
        writer.selectedNodeIds,
      ).where((node) => !node.isLocked).toList(growable: false);
      if (nodes.isEmpty) return;

      final center = centerWorldForNodes(nodes);
      final pivot = Transform2D.translation(center);
      final unpivot = Transform2D.translation(Offset(-center.dx, -center.dy));
      final rotation = Transform2D.rotationDeg(clockwise ? 90 : -90);
      delta = pivot.multiply(rotation).multiply(unpivot);
      affected = writer.writeSelectionTransform(delta!);
      if (affected > 0) {
        movedIds.addAll(nodes.map((n) => n.id));
      }
    });

    if (affected > 0 && delta != null) {
      _events.emitAction(
        ActionType.transform,
        movedIds,
        _resolveTimestampMs(timestampMs),
        payload: <String, Object?>{'delta': delta!.toJsonMap()},
      );
    }
  }

  void flipSelectionVertical({int? timestampMs}) {
    var affected = 0;
    Transform2D? delta;
    final movedIds = <NodeId>[];
    _core.write<void>((writer) {
      final nodes = selectedTransformableNodesInSceneOrder(
        writer.scene,
        writer.selectedNodeIds,
      ).where((node) => !node.isLocked).toList(growable: false);
      if (nodes.isEmpty) return;

      final center = centerWorldForNodes(nodes);
      delta = Transform2D(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 2 * center.dy);
      affected = writer.writeSelectionTransform(delta!);
      if (affected > 0) {
        movedIds.addAll(nodes.map((n) => n.id));
      }
    });

    if (affected > 0 && delta != null) {
      _events.emitAction(
        ActionType.transform,
        movedIds,
        _resolveTimestampMs(timestampMs),
        payload: <String, Object?>{'delta': delta!.toJsonMap()},
      );
    }
  }

  void flipSelectionHorizontal({int? timestampMs}) {
    var affected = 0;
    Transform2D? delta;
    final movedIds = <NodeId>[];
    _core.write<void>((writer) {
      final nodes = selectedTransformableNodesInSceneOrder(
        writer.scene,
        writer.selectedNodeIds,
      ).where((node) => !node.isLocked).toList(growable: false);
      if (nodes.isEmpty) return;

      final center = centerWorldForNodes(nodes);
      delta = Transform2D(a: -1, b: 0, c: 0, d: 1, tx: 2 * center.dx, ty: 0);
      affected = writer.writeSelectionTransform(delta!);
      if (affected > 0) {
        movedIds.addAll(nodes.map((n) => n.id));
      }
    });

    if (affected > 0 && delta != null) {
      _events.emitAction(
        ActionType.transform,
        movedIds,
        _resolveTimestampMs(timestampMs),
        payload: <String, Object?>{'delta': delta!.toJsonMap()},
      );
    }
  }

  void deleteSelection({int? timestampMs}) {
    final deletedIds = <NodeId>[];
    _core.write<void>((writer) {
      final selected = writer.selectedNodeIds.toSet();
      if (selected.isEmpty) return;
      for (final layer in writer.scene.layers) {
        for (final node in layer.nodes) {
          if (!selected.contains(node.id)) continue;
          if (!isNodeDeletableInLayer(node, layer)) continue;
          deletedIds.add(node.id);
        }
      }
      if (deletedIds.isEmpty) return;
      writer.writeDeleteSelection();
    });

    if (deletedIds.isNotEmpty) {
      _events.emitAction(
        ActionType.delete,
        deletedIds,
        _resolveTimestampMs(timestampMs),
      );
    }
  }

  void clearScene({int? timestampMs}) {
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
    _core.writeReplaceScene(snapshot);
    _clearPendingLine();
    _setSelectionRect(null);
  }

  void notifySceneChanged() {
    _core.write<void>((writer) {
      writer.writeMarkVisualChanged();
    });
  }

  void handlePointer(PointerSample sample) {
    final resolvedSample = PointerSample(
      pointerId: sample.pointerId,
      position: sample.position,
      timestampMs: _resolveTimestampMs(sample.timestampMs),
      phase: sample.phase,
      kind: sample.kind,
    );

    if (_mode == CanvasMode.move) {
      _handleMovePointer(resolvedSample);
    } else {
      _handleDrawPointer(resolvedSample);
    }
  }

  void handlePointerSignal(PointerSignal signal) {
    if (signal.type != PointerSignalType.doubleTap) return;
    if (_mode != CanvasMode.move) return;

    final scenePoint = _toScenePoint(signal.position);
    final hit = _hitTestTopNode(scenePoint);
    if (hit == null || hit is! TextNode) return;

    _events.emitEditTextRequested(
      EditTextRequested(
        nodeId: hit.id,
        timestampMs: _resolveTimestampMs(signal.timestampMs),
        position: signal.position,
      ),
    );
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
        _rollbackMoveGestureIfNeeded();
        _resetMoveGestureState();
        _setSelectionRect(null);
        notifyListeners();
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
    _moveInitialTransforms = <NodeId, Transform2D>{};

    final hit = _hitTestTopNode(scenePoint);
    if (hit != null) {
      _moveTarget = _MoveDragTarget.move;
      if (!selectedNodeIds.contains(hit.id)) {
        _core.commands.writeSelectionReplace(<NodeId>{hit.id});
      }
      return;
    }

    _moveTarget = _MoveDragTarget.marquee;
    _movePendingClearSelection = true;
  }

  void _moveHandleMove(PointerSample sample, Offset scenePoint) {
    if (_moveActivePointerId != sample.pointerId) return;
    if (_movePointerDownScene == null || _moveLastScene == null) return;

    final didStartDrag =
        !_moveDragStarted &&
        isDistanceGreaterThan(
          _movePointerDownScene!,
          scenePoint,
          _pointerSettings.tapSlop,
        );

    if (didStartDrag) {
      _moveDragStarted = true;
      if (_moveTarget == _MoveDragTarget.marquee &&
          _movePendingClearSelection) {
        _core.commands.writeSelectionReplace(const <NodeId>{});
        _movePendingClearSelection = false;
      }
      if (_moveTarget == _MoveDragTarget.move) {
        _moveInitialTransforms = _captureSelectedTransforms();
      }
    }

    if (!_moveDragStarted) return;

    if (_moveTarget == _MoveDragTarget.move) {
      final delta = scenePoint - _moveLastScene!;
      if (delta == Offset.zero) return;
      _core.write<void>((writer) {
        writer.writeSelectionTranslate(delta);
      });
      _moveLastScene = scenePoint;
      return;
    }

    if (_moveTarget == _MoveDragTarget.marquee) {
      _setSelectionRect(Rect.fromPoints(_movePointerDownScene!, scenePoint));
    }
  }

  void _moveHandleUp(PointerSample sample, Offset scenePoint) {
    if (_moveActivePointerId != sample.pointerId) return;

    if (_moveTarget == _MoveDragTarget.move) {
      if (_moveDragStarted) {
        final movedIds = _moveInitialTransforms.keys.toList(growable: false);
        final totalDelta = scenePoint - (_movePointerDownScene ?? scenePoint);
        if (movedIds.isNotEmpty && totalDelta != Offset.zero) {
          final delta = Transform2D.translation(totalDelta);
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
        _core.commands.writeSelectionReplace(const <NodeId>{});
      }
    }

    _resetMoveGestureState();
    _setSelectionRect(null);
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
        _resetDrawGestureState();
        notifyListeners();
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
          _core.write<void>((writer) {
            writer.writeMarkVisualChanged();
          });
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
        _core.write<void>((writer) {
          writer.writeMarkVisualChanged();
        });
        break;
      case DrawTool.eraser:
        if (_activeEraserPoints.isEmpty) return;
        if (isDistanceAtLeast(
          _activeEraserPoints.last,
          scenePoint,
          kInputDecimationMinStepScene,
        )) {
          _activeEraserPoints.add(scenePoint);
          _core.write<void>((writer) {
            writer.writeMarkVisualChanged();
          });
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

    final strokeId = _core.draw.writeDrawStroke(
      points: _activeStrokePoints,
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
    if (isDistanceGreaterThan(_activeEraserPoints.last, scenePoint, 0)) {
      _activeEraserPoints.add(scenePoint);
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
      if (!_isCandidateFromForeground(candidate.layerIndex)) continue;
      final node = candidate.node;
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
      for (final candidate in _core.querySpatialCandidates(probe)) {
        byId[candidate.node.id] = candidate;
      }
      return byId.values.toList(growable: false);
    }

    for (var i = 0; i < eraserPoints.length - 1; i++) {
      final a = eraserPoints[i];
      final b = eraserPoints[i + 1];
      final segmentBounds = Rect.fromPoints(a, b).inflate(queryPadding);
      for (final candidate in _core.querySpatialCandidates(segmentBounds)) {
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
    final sigmaMax = _maxSingularValue2x2(
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

    for (var i = 0; i < localEraserPoints.length - 1; i++) {
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

    for (var i = 0; i < localEraserPoints.length - 1; i++) {
      for (var j = 0; j < stroke.points.length - 1; j++) {
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

    return false;
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
      if (!_isCandidateFromForeground(candidate.layerIndex)) continue;
      final node = candidate.node;
      if (!node.isVisible || !node.isSelectable) continue;
      if (!node.boundsWorld.overlaps(rect)) continue;
      ids.add(node.id);
    }

    return ids;
  }

  SceneNode? _hitTestTopNode(Offset scenePoint) {
    final probe = Rect.fromLTWH(scenePoint.dx, scenePoint.dy, 0, 0);
    final candidates =
        _core.querySpatialCandidates(probe).toList(growable: true)
          ..sort((left, right) {
            final byLayer = right.layerIndex.compareTo(left.layerIndex);
            if (byLayer != 0) return byLayer;
            return right.nodeIndex.compareTo(left.nodeIndex);
          });

    for (final candidate in candidates) {
      if (!_isCandidateFromForeground(candidate.layerIndex)) continue;
      final node = candidate.node;
      if (!node.isVisible || !node.isSelectable) continue;
      if (hitTestNode(scenePoint, node)) {
        return node;
      }
    }

    return null;
  }

  bool _isCandidateFromForeground(int layerIndex) {
    final layers = snapshot.layers;
    if (layerIndex < 0 || layerIndex >= layers.length) return false;
    return !layers[layerIndex].isBackground;
  }

  Map<NodeId, Transform2D> _captureSelectedTransforms() {
    final captured = <NodeId, Transform2D>{};
    _core.write<void>((writer) {
      for (final layer in writer.scene.layers) {
        for (final node in layer.nodes) {
          if (!writer.selectedNodeIds.contains(node.id)) continue;
          if (!node.isTransformable || node.isLocked) continue;
          captured[node.id] = node.transform;
        }
      }
    });
    return captured;
  }

  void _rollbackMoveGestureIfNeeded() {
    if (!_moveDragStarted) return;
    if (_moveTarget != _MoveDragTarget.move) return;
    if (_moveInitialTransforms.isEmpty) return;

    _core.write<void>((writer) {
      for (final entry in _moveInitialTransforms.entries) {
        final found = writer.writeFindNode(entry.key);
        if (found == null) continue;
        found.node.transform = entry.value;
        writer.writeMarkSceneGeometryChanged();
      }
    });
  }

  void _resetMoveGestureState() {
    _moveActivePointerId = null;
    _movePointerDownScene = null;
    _moveLastScene = null;
    _moveTarget = _MoveDragTarget.none;
    _moveDragStarted = false;
    _movePendingClearSelection = false;
    _moveMarqueeBaseline = <NodeId>{};
    _moveInitialTransforms = <NodeId, Transform2D>{};
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
    notifyListeners();
  }

  void _setSelectionRect(Rect? value) {
    if (_selectionRect == value) return;
    _selectionRect = value;
    notifyListeners();
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
    notifyListeners();
  }

  void _clearPendingLine() {
    _setPendingLineStart(null, null);
  }

  Offset _toScenePoint(Offset viewPoint) {
    return toScene(viewPoint, snapshot.camera.offset);
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

  double _maxSingularValue2x2(double a, double b, double c, double d) {
    final t = a * a + b * b + c * c + d * d;
    final det = a * d - b * c;
    final discSquared = t * t - 4 * det * det;
    final disc = math.sqrt(math.max(0, discSquared));
    final lambdaMax = (t + disc) / 2;
    return math.sqrt(math.max(0, lambdaMax));
  }

  void _handleCoreChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
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

  static NodeSpec _nodeSpecFromLegacyNode(SceneNode node) {
    switch (node) {
      case RectNode rect:
        return RectNodeSpec(
          id: rect.id,
          size: rect.size,
          fillColor: rect.fillColor,
          strokeColor: rect.strokeColor,
          strokeWidth: rect.strokeWidth,
          transform: rect.transform,
          opacity: rect.opacity,
          hitPadding: rect.hitPadding,
          isVisible: rect.isVisible,
          isSelectable: rect.isSelectable,
          isLocked: rect.isLocked,
          isDeletable: rect.isDeletable,
          isTransformable: rect.isTransformable,
        );
      case TextNode text:
        return TextNodeSpec(
          id: text.id,
          text: text.text,
          size: text.size,
          fontSize: text.fontSize,
          color: text.color,
          align: text.align,
          isBold: text.isBold,
          isItalic: text.isItalic,
          isUnderline: text.isUnderline,
          fontFamily: text.fontFamily,
          maxWidth: text.maxWidth,
          lineHeight: text.lineHeight,
          transform: text.transform,
          opacity: text.opacity,
          hitPadding: text.hitPadding,
          isVisible: text.isVisible,
          isSelectable: text.isSelectable,
          isLocked: text.isLocked,
          isDeletable: text.isDeletable,
          isTransformable: text.isTransformable,
        );
      case StrokeNode stroke:
        return StrokeNodeSpec(
          id: stroke.id,
          points: stroke.points,
          thickness: stroke.thickness,
          color: stroke.color,
          transform: stroke.transform,
          opacity: stroke.opacity,
          hitPadding: stroke.hitPadding,
          isVisible: stroke.isVisible,
          isSelectable: stroke.isSelectable,
          isLocked: stroke.isLocked,
          isDeletable: stroke.isDeletable,
          isTransformable: stroke.isTransformable,
        );
      case LineNode line:
        return LineNodeSpec(
          id: line.id,
          start: line.start,
          end: line.end,
          thickness: line.thickness,
          color: line.color,
          transform: line.transform,
          opacity: line.opacity,
          hitPadding: line.hitPadding,
          isVisible: line.isVisible,
          isSelectable: line.isSelectable,
          isLocked: line.isLocked,
          isDeletable: line.isDeletable,
          isTransformable: line.isTransformable,
        );
      case ImageNode image:
        return ImageNodeSpec(
          id: image.id,
          imageId: image.imageId,
          size: image.size,
          naturalSize: image.naturalSize,
          transform: image.transform,
          opacity: image.opacity,
          hitPadding: image.hitPadding,
          isVisible: image.isVisible,
          isSelectable: image.isSelectable,
          isLocked: image.isLocked,
          isDeletable: image.isDeletable,
          isTransformable: image.isTransformable,
        );
      case PathNode path:
        return PathNodeSpec(
          id: path.id,
          svgPathData: path.svgPathData,
          fillColor: path.fillColor,
          strokeColor: path.strokeColor,
          strokeWidth: path.strokeWidth,
          fillRule: path.fillRule == PathFillRule.evenOdd
              ? V2PathFillRule.evenOdd
              : V2PathFillRule.nonZero,
          transform: path.transform,
          opacity: path.opacity,
          hitPadding: path.hitPadding,
          isVisible: path.isVisible,
          isSelectable: path.isSelectable,
          isLocked: path.isLocked,
          isDeletable: path.isDeletable,
          isTransformable: path.isTransformable,
        );
    }
    throw ArgumentError(
      'Unsupported SceneNode runtime type: ${node.runtimeType}',
    );
  }
}

enum _MoveDragTarget { none, move, marquee }

class _InteractiveEventDispatcher {
  final StreamController<ActionCommitted> _actions =
      StreamController<ActionCommitted>.broadcast(sync: true);
  final StreamController<EditTextRequested> _editTextRequests =
      StreamController<EditTextRequested>.broadcast(sync: true);

  int _actionCounter = 0;
  bool _isDisposed = false;

  Stream<ActionCommitted> get actions => _actions.stream;
  Stream<EditTextRequested> get editTextRequests => _editTextRequests.stream;

  void emitAction(
    ActionType type,
    List<NodeId> nodeIds,
    int timestampMs, {
    Map<String, Object?>? payload,
  }) {
    if (_isDisposed) return;
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

  void emitEditTextRequested(EditTextRequested req) {
    if (_isDisposed) return;
    _editTextRequests.add(req);
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _actions.close();
    _editTextRequests.close();
  }
}

typedef SceneController = SceneControllerInteractiveV2;
