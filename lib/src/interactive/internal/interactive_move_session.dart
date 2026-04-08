import 'dart:ui';

import '../../contract/pointer_input.dart';
import '../../core/nodes.dart' show SceneNode;
import '../../contract/ids.dart';
import 'interactive_move_commit_coordinator.dart';
import 'interactive_move_callbacks.dart';
import 'interactive_move_gesture_state.dart';
import 'interactive_move_hit_test_engine.dart';
import 'interactive_move_preview_state.dart';
import 'interactive_move_selection_coordinator.dart';

class InteractiveMoveSession {
  InteractiveMoveSession({required this.callbacks}) {
    final previewState = InteractiveMovePreviewState();
    _previewState = previewState;
    final hitTestEngine = InteractiveMoveHitTestEngine(
      callbacks: callbacks,
      previewState: previewState,
    );
    _hitTestEngine = hitTestEngine;
    _selectionCoordinator = InteractiveMoveSelectionCoordinator(
      callbacks: callbacks,
      hitTestEngine: hitTestEngine,
    );
    _commitCoordinator = InteractiveMoveCommitCoordinator(
      callbacks: callbacks,
      previewState: previewState,
      selectionCoordinator: _selectionCoordinator,
    );
  }

  final InteractiveMoveSessionCallbacks callbacks;
  late final InteractiveMovePreviewState _previewState;
  late final InteractiveMoveHitTestEngine _hitTestEngine;
  late final InteractiveMoveSelectionCoordinator _selectionCoordinator;
  late final InteractiveMoveCommitCoordinator _commitCoordinator;
  final InteractiveMoveGestureState _gestureState =
      InteractiveMoveGestureState();

  Rect? get selectionRect => _gestureState.selectionRect;

  SceneNode? hitTestTopNode(Offset scenePoint) {
    return _hitTestEngine.hitTestTopNode(scenePoint);
  }

  Offset movePreviewDeltaForNode(NodeId nodeId) {
    return _previewState.deltaForNode(nodeId);
  }

  void setSelectionRect(Rect? value) {
    if (!_gestureState.setSelectionRect(value)) {
      return;
    }
    callbacks.onStateChanged();
  }

  void resetGestureState() {
    _gestureState.reset();
    _selectionCoordinator.reset();
    _previewState.clear();
  }

  bool interruptGesture() {
    return _restoreAndClearGestureState();
  }

  bool detachOwningSession() {
    return _restoreAndClearGestureState();
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

    final hit = _hitTestEngine.hitTestTopNode(scenePoint);
    if (hit == null) {
      _gestureState
        ..setTarget(InteractiveMoveDragTarget.marquee)
        ..setPendingClearSelection(true);
      return true;
    }

    _selectionCoordinator.selectHitNodeIfNeeded(hit.id);
    final previewNodeIds = _selectionCoordinator.resolvePreviewNodeIds();
    if (previewNodeIds.contains(hit.id)) {
      _gestureState.setTarget(InteractiveMoveDragTarget.move);
      return _previewState.start(previewNodeIds);
    }

    _gestureState.setTarget(InteractiveMoveDragTarget.none);
    return false;
  }

  bool _moveHandleMove(Offset scenePoint, {required double dragStartSlop}) {
    final moveLastScene = _gestureState.lastScene;
    if (moveLastScene == null) {
      return false;
    }

    final didStartDrag = _gestureState.tryStartDrag(
      scenePoint,
      dragStartSlop: dragStartSlop,
    );
    if (!didStartDrag) {
      return false;
    }

    if (_gestureState.target == InteractiveMoveDragTarget.marquee &&
        _gestureState.pendingClearSelection) {
      _selectionCoordinator.writeSelectionClearIfChanged();
      _gestureState.setPendingClearSelection(false);
    }

    return switch (_gestureState.target) {
      InteractiveMoveDragTarget.move => _advanceMovePreview(
        scenePoint,
        moveLastScene,
      ),
      InteractiveMoveDragTarget.marquee => _updateSelectionRect(scenePoint),
      InteractiveMoveDragTarget.none => false,
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
    return _restoreAndClearGestureState();
  }

  void _beginGesture(Offset scenePoint) {
    _gestureState.begin(scenePoint);
    _selectionCoordinator.beginGesture();
    _previewState.clear();
  }

  bool _advanceMovePreview(Offset scenePoint, Offset moveLastScene) {
    final moved = _previewState.advance(scenePoint, moveLastScene);
    if (!moved) {
      return false;
    }
    _gestureState.setLastScene(scenePoint);
    return true;
  }

  bool _updateSelectionRect(Offset scenePoint) {
    final movePointerDownScene = _gestureState.pointerDownScene;
    if (movePointerDownScene == null) {
      return false;
    }
    return _setSelectionRect(Rect.fromPoints(movePointerDownScene, scenePoint));
  }

  void _commitMoveGesture(PointerSample sample) {
    _commitCoordinator.commit(sample, gestureState: _gestureState);
  }

  bool _setSelectionRect(Rect? value) {
    return _gestureState.setSelectionRect(value);
  }

  bool _resetGestureStateForTerminal() {
    final didChange =
        _gestureState.selectionRect != null || _previewState.isActive;
    resetGestureState();
    return didChange;
  }

  bool _restoreAndClearGestureState() {
    _commitCoordinator.commitCancelRestore();
    return _resetGestureStateForTerminal();
  }
}
