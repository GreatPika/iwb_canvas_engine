import 'dart:ui';

import '../../core/action_events.dart';
import '../../core/hit_test.dart';
import '../../core/input_sampling.dart';
import '../../core/nodes.dart' show SceneNode;
import '../../core/pointer_input.dart';
import '../../core/scene_spatial_index.dart';
import '../../core/transform2d.dart';
import '../../public/snapshot.dart';
import 'interactive_selection_utils.dart';

class InteractiveMoveSessionCallbacks {
  const InteractiveMoveSessionCallbacks({
    required this.onStateChanged,
    required this.readSnapshot,
    required this.readSelectedNodeIds,
    required this.querySpatialCandidates,
    required this.resolveSpatialCandidateNode,
    required this.writeSelectionReplace,
    required this.writeSelectionClear,
    required this.writeSelectionTranslate,
    required this.emitAction,
  });

  final VoidCallback onStateChanged;
  final SceneSnapshot Function() readSnapshot;
  final Set<NodeId> Function() readSelectedNodeIds;
  final List<SceneSpatialCandidate> Function(Rect bounds)
  querySpatialCandidates;
  final SceneNode? Function(SceneSpatialCandidate candidate)
  resolveSpatialCandidateNode;
  final void Function(Iterable<NodeId> nodeIds) writeSelectionReplace;
  final void Function() writeSelectionClear;
  final int Function(Offset delta) writeSelectionTranslate;
  final void Function(
    ActionType type,
    List<NodeId> nodeIds,
    int timestampMs, {
    Map<String, Object?>? payload,
  })
  emitAction;
}

class InteractiveMoveSession {
  InteractiveMoveSession({required this.callbacks});

  final InteractiveMoveSessionCallbacks callbacks;

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

  Rect? get selectionRect => _selectionRect;

  SceneNode? hitTestTopNode(Offset scenePoint) {
    return _hitTestTopNode(scenePoint);
  }

  Offset movePreviewDeltaForNode(NodeId nodeId) {
    if (!_hasMovePreviewTranslation) return Offset.zero;
    if (!_movePreviewNodeIds.contains(nodeId)) return Offset.zero;
    return _movePreviewDelta;
  }

  void setSelectionRect(Rect? value) {
    if (_selectionRect == value) return;
    _selectionRect = value;
    callbacks.onStateChanged();
  }

  void resetGestureState() {
    _moveActivePointerId = null;
    _movePointerDownScene = null;
    _moveLastScene = null;
    _moveTarget = _MoveDragTarget.none;
    _moveDragStarted = false;
    _movePendingClearSelection = false;
    _moveMarqueeBaseline = <NodeId>{};
    _clearMovePreview();
  }

  void dispose() {}

  void handlePointer(
    PointerSample sample,
    Offset scenePoint, {
    required double dragStartSlop,
  }) {
    if (_moveActivePointerId != null &&
        _moveActivePointerId != sample.pointerId) {
      return;
    }

    switch (sample.phase) {
      case PointerPhase.down:
        _moveHandleDown(sample, scenePoint);
        break;
      case PointerPhase.move:
        _moveHandleMove(sample, scenePoint, dragStartSlop: dragStartSlop);
        break;
      case PointerPhase.up:
        _moveHandleUp(sample, scenePoint);
        break;
      case PointerPhase.cancel:
        resetGestureState();
        setSelectionRect(null);
        callbacks.onStateChanged();
        break;
    }
  }

  void _moveHandleDown(PointerSample sample, Offset scenePoint) {
    _moveActivePointerId = sample.pointerId;
    _movePointerDownScene = scenePoint;
    _moveLastScene = scenePoint;
    _moveDragStarted = false;
    _movePendingClearSelection = false;
    _moveMarqueeBaseline = Set<NodeId>.from(callbacks.readSelectedNodeIds());

    final hit = _hitTestTopNode(scenePoint);
    if (hit != null) {
      _moveTarget = _MoveDragTarget.move;
      Set<NodeId> previewNodeIds = callbacks.readSelectedNodeIds();
      if (!previewNodeIds.contains(hit.id)) {
        callbacks.writeSelectionReplace(<NodeId>{hit.id});
        previewNodeIds = <NodeId>{hit.id};
      }
      _startMovePreview(previewNodeIds);
      callbacks.onStateChanged();
      return;
    }

    _moveTarget = _MoveDragTarget.marquee;
    _movePendingClearSelection = true;
    _clearMovePreview();
    callbacks.onStateChanged();
  }

  void _moveHandleMove(
    PointerSample sample,
    Offset scenePoint, {
    required double dragStartSlop,
  }) {
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
        callbacks.writeSelectionClear();
        _movePendingClearSelection = false;
      }
    }

    if (!_moveDragStarted) return;

    if (_moveTarget == _MoveDragTarget.move) {
      final deltaStep = scenePoint - _moveLastScene!;
      if (deltaStep == Offset.zero) return;
      _movePreviewDelta = _movePreviewDelta + deltaStep;
      _moveLastScene = scenePoint;
      callbacks.onStateChanged();
      return;
    }

    if (_moveTarget == _MoveDragTarget.marquee) {
      setSelectionRect(Rect.fromPoints(_movePointerDownScene!, scenePoint));
    }
  }

  void _moveHandleUp(PointerSample sample, Offset scenePoint) {
    if (_moveActivePointerId != sample.pointerId) return;

    if (_moveTarget == _MoveDragTarget.move) {
      final finalDelta = _movePreviewDelta;
      final movedIds = selectedTransformableNodesInSnapshotOrder(
        snapshot: callbacks.readSnapshot(),
        selected: _movePreviewNodeIds,
      ).map((node) => node.id).toList(growable: false);
      _clearMovePreview();
      if (_moveDragStarted) {
        var affected = 0;
        if (finalDelta != Offset.zero) {
          affected = callbacks.writeSelectionTranslate(finalDelta);
        }
        if (affected > 0 && movedIds.isNotEmpty) {
          final delta = Transform2D.translation(finalDelta);
          callbacks.emitAction(
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
        callbacks.writeSelectionClear();
      }
    }

    resetGestureState();
    setSelectionRect(null);
    callbacks.onStateChanged();
  }

  void _commitMarquee(int timestampMs) {
    final rect = _selectionRect;
    if (rect == null) return;

    final selected = _nodesIntersecting(rect);
    callbacks.writeSelectionReplace(selected);

    final currentSelection = callbacks.readSelectedNodeIds();
    final didChange =
        _moveMarqueeBaseline.length != currentSelection.length ||
        !_moveMarqueeBaseline.containsAll(currentSelection);
    if (didChange) {
      callbacks.emitAction(
        ActionType.selectMarquee,
        currentSelection.toList(growable: false),
        timestampMs,
      );
    }
  }

  Set<NodeId> _nodesIntersecting(Rect rect) {
    final ids = <NodeId>{};
    final candidates =
        callbacks.querySpatialCandidates(rect).toList(growable: true)
          ..sort((left, right) {
            final byLayer = left.layerIndex.compareTo(right.layerIndex);
            if (byLayer != 0) return byLayer;
            return left.nodeIndex.compareTo(right.nodeIndex);
          });

    for (final candidate in candidates) {
      final node = callbacks.resolveSpatialCandidateNode(candidate);
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
      final node = callbacks.resolveSpatialCandidateNode(candidate);
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
    for (final candidate in callbacks.querySpatialCandidates(probe)) {
      byNodeId[candidate.node.id] = candidate;
    }
    if (_hasMovePreviewTranslation) {
      final shiftedProbe = Rect.fromLTWH(
        scenePoint.dx - _movePreviewDelta.dx,
        scenePoint.dy - _movePreviewDelta.dy,
        0,
        0,
      );
      for (final candidate in callbacks.querySpatialCandidates(shiftedProbe)) {
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

  Rect _effectiveNodeBoundsWorld(SceneNode node) {
    final delta = movePreviewDeltaForNode(node.id);
    return node.boundsWorld.shift(delta);
  }

  bool _hitTestNodeWithMovePreview(Offset scenePoint, SceneNode node) {
    final delta = movePreviewDeltaForNode(node.id);
    if (delta == Offset.zero) {
      return hitTestNode(scenePoint, node);
    }
    return hitTestNode(scenePoint - delta, node);
  }
}

enum _MoveDragTarget { none, move, marquee }
