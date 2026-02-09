import 'dart:ui';

import '../../../core/hit_test.dart';
import '../../../core/input_sampling.dart';
import '../../../core/nodes.dart';
import '../../../core/transform2d.dart';
import '../../action_events.dart';
import '../../internal/contracts.dart';
import '../../internal/node_interaction_policy.dart';
import '../../pointer_input.dart';

class MoveModeEngine {
  MoveModeEngine(this._contracts);

  final InputSliceContracts _contracts;

  List<SceneNode>? _moveGestureNodes;
  int _dragSceneRevision = 0;
  int _dragSelectionRevision = 0;
  int _debugMoveGestureBuildCount = 0;
  int _debugDragSceneStructureFingerprint = 0;

  int? _activePointerId;
  Offset? _pointerDownScene;
  Offset? _lastDragScene;
  _DragTarget _dragTarget = _DragTarget.none;
  bool _dragMoved = false;
  bool _pendingClearSelection = false;
  Set<NodeId> _marqueeSelectionBaseline = <NodeId>{};
  final List<_NodeTransformSnapshot> _dragTransformSnapshots =
      <_NodeTransformSnapshot>[];

  int get debugMoveGestureBuildCount => _debugMoveGestureBuildCount;

  List<SceneNode>? get debugMoveGestureNodes => _moveGestureNodes;

  bool get hasActivePointer => _activePointerId != null;

  void handlePointer(PointerSample sample) {
    if (_activePointerId != null && _activePointerId != sample.pointerId) {
      return;
    }

    final scenePoint = _contracts.toScenePoint(sample.position);

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

  void reset() {
    _activePointerId = null;
    _pointerDownScene = null;
    _lastDragScene = null;
    _dragTarget = _DragTarget.none;
    _dragMoved = false;
    _pendingClearSelection = false;
    _marqueeSelectionBaseline = <NodeId>{};
    _moveGestureNodes = null;
    _dragTransformSnapshots.clear();
    _contracts.setSelectionRect(null, notify: false);
  }

  void cancelGesture({bool notify = true}) {
    _rollbackMoveIfNeeded();
    reset();
    if (notify) {
      _contracts.notifyNowIfNeeded();
    }
  }

  void _handleDown(PointerSample sample, Offset scenePoint) {
    _activePointerId = sample.pointerId;
    _pointerDownScene = scenePoint;
    _lastDragScene = scenePoint;
    _dragMoved = false;
    _pendingClearSelection = false;
    _moveGestureNodes = null;

    final hit = _hitTestTopNode(scenePoint);
    if (hit != null) {
      _dragTarget = _DragTarget.move;
      if (!_contracts.selectedNodeIds.contains(hit.id)) {
        _contracts.setSelection({hit.id});
      }
      return;
    }

    _dragTarget = _DragTarget.marquee;
    _marqueeSelectionBaseline = Set<NodeId>.from(_contracts.selectedNodeIds);
    _pendingClearSelection = true;
  }

  void _handleMove(PointerSample sample, Offset scenePoint) {
    if (_activePointerId != sample.pointerId) return;
    if (_pointerDownScene == null || _lastDragScene == null) return;

    final didStartDrag =
        !_dragMoved &&
        isDistanceGreaterThan(
          _pointerDownScene!,
          scenePoint,
          _contracts.dragStartSlop,
        );
    if (didStartDrag) {
      _dragMoved = true;
      if (_dragTarget == _DragTarget.marquee) {
        if (_pendingClearSelection) {
          _contracts.setSelection(const <NodeId>[], notify: false);
          _pendingClearSelection = false;
        }
      }
      if (_dragTarget == _DragTarget.move) {
        _dragSceneRevision = _contracts.sceneRevision;
        _dragSelectionRevision = _contracts.selectionRevision;
        _moveGestureNodes = _selectedNodesInSceneOrder();
        _debugMoveGestureBuildCount += 1;
        assert(() {
          _debugDragSceneStructureFingerprint =
              _debugComputeSceneStructureFingerprint();
          return true;
        }());
      }
    }

    if (!_dragMoved) return;

    if (_dragTarget == _DragTarget.move) {
      if (_moveGestureNodes != null &&
          (_contracts.sceneRevision != _dragSceneRevision ||
              _contracts.selectionRevision != _dragSelectionRevision)) {
        _moveGestureNodes = null;
      }
      assert(() {
        if (_moveGestureNodes != null &&
            _debugDragSceneStructureFingerprint !=
                _debugComputeSceneStructureFingerprint()) {
          _moveGestureNodes = null;
        }
        return true;
      }());
      final delta = scenePoint - _lastDragScene!;
      if (delta == Offset.zero) return;
      _applyMoveDelta(delta, nodes: _moveGestureNodes);
      _lastDragScene = scenePoint;
      _contracts.requestRepaintOncePerFrame();
      return;
    }

    if (_dragTarget == _DragTarget.marquee) {
      _contracts.setSelectionRect(
        Rect.fromPoints(_pointerDownScene!, scenePoint),
      );
    }
  }

  void _handleUp(PointerSample sample, Offset scenePoint) {
    if (_activePointerId != sample.pointerId) return;

    if (_dragTarget == _DragTarget.move) {
      if (_dragMoved) {
        _commitMove(sample.timestampMs, scenePoint);
      }
    } else if (_dragTarget == _DragTarget.marquee) {
      if (_dragMoved && _contracts.selectionRect != null) {
        _commitMarquee(sample.timestampMs);
      } else if (_pendingClearSelection) {
        _contracts.setSelection(const <NodeId>[], notify: false);
      }
    }

    reset();
    _contracts.notifyNowIfNeeded();
  }

  void _handleCancel() {
    cancelGesture();
  }

  void _commitMove(int timestampMs, Offset scenePoint) {
    final movedNodeIds = _selectedTransformableNodeIds();
    final totalDelta = scenePoint - (_pointerDownScene ?? scenePoint);
    if (movedNodeIds.isNotEmpty && totalDelta != Offset.zero) {
      final delta = Transform2D.translation(totalDelta);
      _contracts.emitAction(
        ActionType.transform,
        movedNodeIds,
        timestampMs,
        payload: <String, Object?>{'delta': delta.toJsonMap()},
      );
    }
  }

  void _commitMarquee(int timestampMs) {
    final rect = _normalizeRect(_contracts.selectionRect!);
    final selected = _nodesIntersecting(rect);
    final baseline = _marqueeSelectionBaseline;
    _contracts.setSelectionRect(null, notify: false);
    _contracts.setSelection(selected, notify: false);
    final currentSelection = _contracts.selectedNodeIds;
    final didChange =
        baseline.length != currentSelection.length ||
        !baseline.containsAll(currentSelection);
    if (didChange) {
      _contracts.emitAction(ActionType.selectMarquee, selected, timestampMs);
    }
  }

  void _applyMoveDelta(Offset delta, {List<SceneNode>? nodes}) {
    if (delta == Offset.zero) return;

    final nodesToMove = nodes ?? _selectedNodesInSceneOrder();
    var movedAny = false;
    for (final node in nodesToMove) {
      if (node.isLocked) continue;
      if (!node.isTransformable) continue;
      _rememberNodeTransform(node);
      node.position = node.position + delta;
      movedAny = true;
    }
    if (movedAny) {
      _contracts.markSceneGeometryChanged();
    }
  }

  void _rememberNodeTransform(SceneNode node) {
    for (final snapshot in _dragTransformSnapshots) {
      if (identical(snapshot.node, node)) {
        return;
      }
    }
    _dragTransformSnapshots.add(
      _NodeTransformSnapshot(node: node, transform: node.transform),
    );
  }

  void _rollbackMoveIfNeeded() {
    if (!_dragMoved || _dragTarget != _DragTarget.move) {
      return;
    }
    if (_dragTransformSnapshots.isEmpty) {
      return;
    }
    for (final snapshot in _dragTransformSnapshots) {
      snapshot.node.transform = snapshot.transform;
    }
    _contracts.markSceneGeometryChanged();
    _contracts.requestRepaintOncePerFrame();
  }

  List<SceneNode> _selectedNodesInSceneOrder() {
    final nodes = <SceneNode>[];
    final selectedNodeIds = _contracts.selectedNodeIds;
    if (selectedNodeIds.isEmpty) return nodes;

    for (final layer in _contracts.scene.layers) {
      for (final node in layer.nodes) {
        if (selectedNodeIds.contains(node.id)) {
          nodes.add(node);
        }
      }
    }
    return nodes;
  }

  List<NodeId> _selectedTransformableNodeIds() {
    final ids = <NodeId>[];
    final selectedNodeIds = _contracts.selectedNodeIds;
    if (selectedNodeIds.isEmpty) return ids;

    for (final layer in _contracts.scene.layers) {
      for (final node in layer.nodes) {
        if (!selectedNodeIds.contains(node.id)) continue;
        if (!node.isTransformable) continue;
        if (node.isLocked) continue;
        ids.add(node.id);
      }
    }
    return ids;
  }

  List<NodeId> _nodesIntersecting(Rect rect) {
    final ids = <NodeId>[];
    final seen = <NodeId>{};
    final candidates =
        _contracts.querySpatialCandidates(rect).toList(growable: true)
          ..sort((left, right) {
            final byLayer = left.layerIndex.compareTo(right.layerIndex);
            if (byLayer != 0) return byLayer;
            return left.nodeIndex.compareTo(right.nodeIndex);
          });

    for (final candidate in candidates) {
      final layerIndex = candidate.layerIndex;
      if (layerIndex < 0 || layerIndex >= _contracts.scene.layers.length) {
        continue;
      }
      final layer = _contracts.scene.layers[layerIndex];
      final nodeIndex = candidate.nodeIndex;
      if (nodeIndex < 0 || nodeIndex >= layer.nodes.length) {
        continue;
      }
      final node = layer.nodes[nodeIndex];
      if (!identical(node, candidate.node)) continue;
      if (!isNodeInteractiveForSelection(node, layer, onlySelectable: true)) {
        continue;
      }
      if (!node.boundsWorld.overlaps(rect)) continue;
      if (seen.add(node.id)) {
        ids.add(node.id);
      }
    }
    return ids;
  }

  SceneNode? _hitTestTopNode(Offset point) {
    final probe = Rect.fromLTWH(point.dx, point.dy, 0, 0);
    final candidates =
        _contracts.querySpatialCandidates(probe).toList(growable: true)
          ..sort((left, right) {
            final byLayer = right.layerIndex.compareTo(left.layerIndex);
            if (byLayer != 0) return byLayer;
            return right.nodeIndex.compareTo(left.nodeIndex);
          });

    for (final candidate in candidates) {
      final layerIndex = candidate.layerIndex;
      if (layerIndex < 0 || layerIndex >= _contracts.scene.layers.length) {
        continue;
      }
      final layer = _contracts.scene.layers[layerIndex];
      final nodeIndex = candidate.nodeIndex;
      if (nodeIndex < 0 || nodeIndex >= layer.nodes.length) {
        continue;
      }
      final node = layer.nodes[nodeIndex];
      if (!identical(node, candidate.node)) continue;
      if (!isNodeInteractiveForSelection(node, layer, onlySelectable: true)) {
        continue;
      }
      if (hitTestNode(point, node)) {
        return node;
      }
    }
    return null;
  }

  int _debugComputeSceneStructureFingerprint() {
    final scene = _contracts.scene;
    var hash = 17;
    hash = 37 * hash + scene.layers.length;
    for (final layer in scene.layers) {
      hash = 37 * hash + identityHashCode(layer);
      hash = 37 * hash + layer.nodes.length;
      hash = 37 * hash + (layer.isBackground ? 1 : 0);
      final nodes = layer.nodes;
      if (nodes.isNotEmpty) {
        hash = 37 * hash + identityHashCode(nodes.first);
        hash = 37 * hash + identityHashCode(nodes.last);
      }
    }
    return hash;
  }
}

enum _DragTarget { none, move, marquee }

class _NodeTransformSnapshot {
  const _NodeTransformSnapshot({required this.node, required this.transform});

  final SceneNode node;
  final Transform2D transform;
}

Rect _normalizeRect(Rect rect) {
  final left = rect.left < rect.right ? rect.left : rect.right;
  final right = rect.left < rect.right ? rect.right : rect.left;
  final top = rect.top < rect.bottom ? rect.top : rect.bottom;
  final bottom = rect.top < rect.bottom ? rect.bottom : rect.top;
  return Rect.fromLTRB(left, top, right, bottom);
}
