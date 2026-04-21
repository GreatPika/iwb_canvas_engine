import 'dart:ui';

import '../../contract/pointer_input.dart';
import '../../contract/scene_view_render_state.dart';
import '../../contract/snapshot.dart';
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

  NodeSnapshot? hitTestTopNode(Offset scenePoint) {
    return _hitTestEngine.hitTestTopNode(scenePoint);
  }

  Offset movePreviewDeltaForNode(NodeId nodeId) {
    return _previewState.deltaForNode(nodeId);
  }

  SceneViewFramePreview captureFramePreview() {
    return _previewState.captureFramePreview();
  }

  void setSelectionRect(Rect? value) {
    if (!_gestureState.setSelectionRect(value)) {
      return;
    }
    callbacks.onOverlayStateChanged();
  }

  void resetGestureState() {
    _gestureState.reset();
    _selectionCoordinator.reset();
    _previewState.clear();
  }

  ({bool scene, bool overlay}) interruptGesture() {
    return _restoreAndClearGestureState();
  }

  ({bool scene, bool overlay}) detachOwningSession() {
    return _restoreAndClearGestureState();
  }

  void dispose() {}

  void handlePointer(
    PointerSample sample,
    Offset scenePoint, {
    required double dragStartSlop,
  }) {
    switch (sample.phase) {
      case PointerPhase.down:
        _moveHandleDown(scenePoint);
      case PointerPhase.move:
        final change = _moveHandleMove(
          scenePoint,
          dragStartSlop: dragStartSlop,
        );
        if (change.scene) {
          callbacks.onSceneStateChanged();
        }
        if (change.overlay) {
          callbacks.onOverlayStateChanged();
        }
      case PointerPhase.up:
        final change = _moveHandleUp(sample);
        if (change.scene) {
          callbacks.onSceneStateChanged();
        }
        if (change.overlay) {
          callbacks.onOverlayStateChanged();
        }
      case PointerPhase.cancel:
        final change = _moveHandleCancel();
        if (change.scene) {
          callbacks.onSceneStateChanged();
        }
        if (change.overlay) {
          callbacks.onOverlayStateChanged();
        }
    }
  }

  void _moveHandleDown(Offset scenePoint) {
    _beginGesture(scenePoint);

    final hit = _hitTestEngine.hitTestTopNode(scenePoint);
    if (hit == null) {
      _gestureState
        ..setTarget(InteractiveMoveDragTarget.marquee)
        ..setPendingClearSelection(true);
      callbacks.onPublicStateChanged();
      return;
    }

    _selectionCoordinator.selectHitNodeIfNeeded(hit.id);
    final previewNodeIds = _selectionCoordinator.resolvePreviewNodeIds();
    if (previewNodeIds.contains(hit.id)) {
      _gestureState.setTarget(InteractiveMoveDragTarget.move);
      _previewState.start(previewNodeIds);
      return;
    }

    _gestureState.setTarget(InteractiveMoveDragTarget.none);
  }

  ({bool scene, bool overlay}) _moveHandleMove(
    Offset scenePoint, {
    required double dragStartSlop,
  }) {
    final moveLastScene = _gestureState.lastScene;
    if (moveLastScene == null) {
      return (scene: false, overlay: false);
    }

    final didStartDrag = _gestureState.tryStartDrag(
      scenePoint,
      dragStartSlop: dragStartSlop,
    );
    if (!didStartDrag) {
      return (scene: false, overlay: false);
    }

    if (_gestureState.target == InteractiveMoveDragTarget.marquee &&
        _gestureState.pendingClearSelection) {
      _selectionCoordinator.writeSelectionClearIfChanged();
      _gestureState.setPendingClearSelection(false);
    }

    return switch (_gestureState.target) {
      InteractiveMoveDragTarget.move => (
        scene: _advanceMovePreview(scenePoint, moveLastScene),
        overlay: false,
      ),
      InteractiveMoveDragTarget.marquee => (
        scene: false,
        overlay: _updateSelectionRect(scenePoint),
      ),
      InteractiveMoveDragTarget.none => (scene: false, overlay: false),
    };
  }

  ({bool scene, bool overlay}) _moveHandleUp(PointerSample sample) {
    var change = (scene: false, overlay: false);
    try {
      _commitMoveGesture(sample);
    } finally {
      change = _resetGestureStateForTerminal();
    }
    return change;
  }

  ({bool scene, bool overlay}) _moveHandleCancel() {
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

  ({bool scene, bool overlay}) _resetGestureStateForTerminal() {
    final didChange = (
      scene: _previewState.hasSceneEffect,
      overlay: _gestureState.selectionRect != null,
    );
    resetGestureState();
    return didChange;
  }

  ({bool scene, bool overlay}) _restoreAndClearGestureState() {
    _commitCoordinator.commitCancelRestore();
    return _resetGestureStateForTerminal();
  }
}
