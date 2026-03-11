import 'dart:ui';

import '../../core/action_events.dart';
import '../../core/hit_test.dart';
import '../../core/input_sampling.dart';
import '../../core/nodes.dart' show SceneNode;
import '../../core/pointer_input.dart';
import '../../core/scene_spatial_index.dart';
import '../../contract/transform2d.dart';
import '../../contract/snapshot.dart';
import '../interaction_eligibility_policy.dart'
    as interaction_eligibility_policy;

typedef MoveCommitSelectionResult = ({
  Offset appliedDelta,
  List<NodeId> movedIds,
});

class InteractiveMoveSessionCallbacks {
  const InteractiveMoveSessionCallbacks({
    required this.onStateChanged,
    required this.readSnapshot,
    required this.readSelectedNodeIds,
    required this.querySpatialCandidates,
    required this.resolveSpatialCandidateNode,
    required this.writeSelectionReplace,
    required this.writeSelectionClear,
    required this.commitMoveSelection,
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
  final MoveCommitSelectionResult Function(Offset proposedDelta)
  commitMoveSelection;
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

  Offset? _movePointerDownScene;
  Offset? _moveLastScene;
  _MoveDragTarget _moveTarget = _MoveDragTarget.none;
  bool _moveDragStarted = false;
  bool _movePendingClearSelection = false;
  Set<NodeId> _moveMarqueeBaseline = <NodeId>{};
  bool _moveSelectionChangedLocally = false;
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
    _movePointerDownScene = null;
    _moveLastScene = null;
    _moveTarget = _MoveDragTarget.none;
    _moveDragStarted = false;
    _movePendingClearSelection = false;
    _moveMarqueeBaseline = <NodeId>{};
    _moveSelectionChangedLocally = false;
    _clearMovePreview();
  }

  void dispose() {}

  void handlePointer(
    PointerSample sample,
    Offset scenePoint, {
    required double dragStartSlop,
  }) {
    final shouldNotify = switch (sample.phase) {
      PointerPhase.down => _moveHandleDown(scenePoint),
      PointerPhase.move => _moveHandleMove(
        scenePoint,
        dragStartSlop: dragStartSlop,
      ),
      PointerPhase.up => _moveHandleUp(sample),
      PointerPhase.cancel => _moveHandleCancel(),
    };
    if (shouldNotify) {
      callbacks.onStateChanged();
    }
  }

  bool _moveHandleDown(Offset scenePoint) {
    _beginGesture(scenePoint);

    final hit = _hitTestTopNode(scenePoint);
    if (hit == null) {
      _moveTarget = _MoveDragTarget.marquee;
      _movePendingClearSelection = true;
      return true;
    }

    _selectHitNodeIfNeeded(hit.id);
    final previewNodeIds = _resolvePreviewNodeIds();
    if (previewNodeIds.contains(hit.id)) {
      _moveTarget = _MoveDragTarget.move;
      return _startMovePreview(previewNodeIds);
    }

    _moveTarget = _MoveDragTarget.none;
    return false;
  }

  bool _moveHandleMove(Offset scenePoint, {required double dragStartSlop}) {
    final movePointerDownScene = _movePointerDownScene;
    final moveLastScene = _moveLastScene;
    if (movePointerDownScene == null || moveLastScene == null) return false;

    if (!_moveDragStarted &&
        !isDistanceGreaterThan(
          movePointerDownScene,
          scenePoint,
          dragStartSlop,
        )) {
      return false;
    }

    if (!_moveDragStarted) {
      _moveDragStarted = true;
      if (_moveTarget == _MoveDragTarget.marquee &&
          _movePendingClearSelection) {
        _writeSelectionClearIfChanged();
        _movePendingClearSelection = false;
      }
    }

    return switch (_moveTarget) {
      _MoveDragTarget.move => _advanceMovePreview(scenePoint, moveLastScene),
      _MoveDragTarget.marquee => _updateSelectionRect(scenePoint),
      _MoveDragTarget.none => false,
    };
  }

  bool _moveHandleUp(PointerSample sample) {
    var shouldNotify = false;
    try {
      _commitMoveGesture(sample);
    } finally {
      shouldNotify = _resetGestureStateForTerminal();
    }
    return shouldNotify;
  }

  bool _moveHandleCancel() {
    _restoreBaselineSelectionIfNeeded();
    return _resetGestureStateForTerminal();
  }

  void _beginGesture(Offset scenePoint) {
    _movePointerDownScene = scenePoint;
    _moveLastScene = scenePoint;
    _moveDragStarted = false;
    _movePendingClearSelection = false;
    _moveTarget = _MoveDragTarget.none;
    _moveMarqueeBaseline = Set<NodeId>.from(callbacks.readSelectedNodeIds());
    _moveSelectionChangedLocally = false;
    _clearMovePreview();
  }

  void _selectHitNodeIfNeeded(NodeId nodeId) {
    final selection = callbacks.readSelectedNodeIds();
    if (selection.contains(nodeId)) {
      return;
    }
    _writeSelectionReplaceIfChanged(<NodeId>{nodeId});
  }

  Set<NodeId> _resolvePreviewNodeIds() {
    final previewableNodes = interaction_eligibility_policy
        .selectedPreviewMovableNodesInSnapshotOrder(
          snapshot: callbacks.readSnapshot(),
          selected: callbacks.readSelectedNodeIds(),
        );
    return previewableNodes.map((node) => node.id).toSet();
  }

  bool _advanceMovePreview(Offset scenePoint, Offset moveLastScene) {
    final deltaStep = scenePoint - moveLastScene;
    if (deltaStep == Offset.zero) return false;
    _movePreviewDelta = _movePreviewDelta + deltaStep;
    _moveLastScene = scenePoint;
    return true;
  }

  bool _updateSelectionRect(Offset scenePoint) {
    final movePointerDownScene = _movePointerDownScene;
    if (movePointerDownScene == null) {
      return false;
    }
    return _setSelectionRect(Rect.fromPoints(movePointerDownScene, scenePoint));
  }

  void _commitMoveGesture(PointerSample sample) {
    switch (sample.phase) {
      case PointerPhase.down:
      case PointerPhase.move:
      case PointerPhase.cancel:
        return;
      case PointerPhase.up:
        break;
    }

    if (_moveTarget == _MoveDragTarget.move) {
      _commitMovePreview(sample);
      return;
    }

    if (_moveTarget != _MoveDragTarget.marquee) {
      return;
    }

    if (_moveDragStarted && _selectionRect != null) {
      _commitMarquee(sample.timestampMs);
      return;
    }

    if (_movePendingClearSelection) {
      _writeSelectionClearIfChanged();
    }
  }

  void _commitMovePreview(PointerSample sample) {
    final proposedDelta = _movePreviewDelta;
    if (!_moveDragStarted || proposedDelta == Offset.zero) {
      return;
    }

    final moveCommit = callbacks.commitMoveSelection(proposedDelta);
    if (moveCommit.appliedDelta == Offset.zero || moveCommit.movedIds.isEmpty) {
      return;
    }

    final delta = Transform2D.translation(moveCommit.appliedDelta);
    callbacks.emitAction(
      ActionType.transform,
      moveCommit.movedIds,
      sample.timestampMs,
      payload: <String, Object?>{'delta': delta.toJsonMap()},
    );
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
      if (!interaction_eligibility_policy.canSelectSceneNode(node)) continue;
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
      if (!interaction_eligibility_policy.canSelectSceneNode(node)) continue;
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

  bool _startMovePreview(Set<NodeId> nodeIds) {
    _movePreviewActive = true;
    _movePreviewDelta = Offset.zero;
    _movePreviewNodeIds = Set<NodeId>.from(nodeIds);
    return true;
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

  bool _setSelectionRect(Rect? value) {
    if (_selectionRect == value) return false;
    _selectionRect = value;
    return true;
  }

  bool _resetGestureStateForTerminal() {
    final didChange = _selectionRect != null || _movePreviewActive;
    resetGestureState();
    _setSelectionRect(null);
    return didChange;
  }

  void _restoreBaselineSelectionIfNeeded() {
    if (!_moveSelectionChangedLocally) {
      return;
    }
    final baseline = _moveMarqueeBaseline;
    final current = callbacks.readSelectedNodeIds();
    if (_sameNodeSet(current, baseline)) {
      return;
    }
    if (baseline.isEmpty) {
      callbacks.writeSelectionClear();
      return;
    }
    callbacks.writeSelectionReplace(baseline);
  }

  bool _sameNodeSet(Set<NodeId> left, Set<NodeId> right) {
    return left.length == right.length && left.containsAll(right);
  }

  void _writeSelectionReplaceIfChanged(Set<NodeId> nextSelection) {
    final current = callbacks.readSelectedNodeIds();
    if (_sameNodeSet(current, nextSelection)) {
      return;
    }
    callbacks.writeSelectionReplace(nextSelection);
    _moveSelectionChangedLocally = true;
  }

  void _writeSelectionClearIfChanged() {
    if (callbacks.readSelectedNodeIds().isEmpty) {
      return;
    }
    callbacks.writeSelectionClear();
    _moveSelectionChangedLocally = true;
  }

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
