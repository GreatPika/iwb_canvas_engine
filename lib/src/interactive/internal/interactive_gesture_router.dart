import 'dart:ui';

import '../../core/geometry.dart';
import '../../core/interaction_types.dart';
import '../../core/pointer_input.dart';
import 'interactive_draw_coordinator.dart';
import 'interactive_gesture_machine.dart';
import 'interactive_move_session.dart';
import 'interactive_runtime_callbacks.dart';

class InteractiveGestureRouter {
  InteractiveGestureRouter({
    required this.callbacks,
    required InteractiveMoveSession moveSession,
    required InteractiveDrawCoordinator drawCoordinator,
  }) : _moveSession = moveSession,
       _drawCoordinator = drawCoordinator;

  final InteractiveRuntimeCallbacks callbacks;
  final InteractiveGestureMachine _gestureMachine = InteractiveGestureMachine();
  final InteractiveMoveSession _moveSession;
  final InteractiveDrawCoordinator _drawCoordinator;

  bool get hasActiveGesture => _gestureMachine.hasActiveGesture;
  bool get isActiveDrawGesture => _gestureMachine.isActiveDrawGesture;

  bool resetGestureWasMove() {
    return _gestureMachine.reset() == InteractiveGestureFamily.move;
  }

  void dispatchPointerSample(PointerSample sample) {
    switch (sample.phase) {
      case PointerPhase.down:
        _handlePointerDown(sample);
        break;
      case PointerPhase.move:
      case PointerPhase.up:
      case PointerPhase.cancel:
        _handleOwnedPointerSample(sample);
        break;
    }
  }

  Offset toScenePoint(Offset viewPoint) {
    return toScene(viewPoint, callbacks.readSnapshot().camera.offset);
  }

  static bool isTerminalPointerPhase(PointerPhase phase) {
    return phase == PointerPhase.up || phase == PointerPhase.cancel;
  }

  void _handlePointerDown(PointerSample sample) {
    final family = _currentGestureFamily;
    final activeGesture = _gestureMachine.begin(
      pointerId: sample.pointerId,
      family: family,
      dragStartSlop: callbacks.readDragStartSlop(),
    );
    if (activeGesture == null) {
      return;
    }

    try {
      _dispatchPointerToFamily(
        sample,
        family: activeGesture.family,
        dragStartSlop: activeGesture.dragStartSlop,
      );
    } catch (_) {
      _gestureMachine.reset();
      rethrow;
    }
  }

  void _handleOwnedPointerSample(PointerSample sample) {
    final activeGesture = _gestureMachine.activeGestureForPointer(
      sample.pointerId,
    );
    if (activeGesture == null) {
      return;
    }
    try {
      _dispatchPointerToFamily(
        sample,
        family: activeGesture.family,
        dragStartSlop: activeGesture.dragStartSlop,
      );
    } finally {
      if (isTerminalPointerPhase(sample.phase)) {
        _gestureMachine.reset();
      }
    }
  }

  void _dispatchPointerToFamily(
    PointerSample sample, {
    required InteractiveGestureFamily family,
    required double dragStartSlop,
  }) {
    final scenePoint = toScenePoint(sample.position);
    switch (family) {
      case InteractiveGestureFamily.move:
        _moveSession.handlePointer(
          sample,
          scenePoint,
          dragStartSlop: dragStartSlop,
        );
        break;
      case InteractiveGestureFamily.draw:
        _drawCoordinator.handlePointer(
          sample,
          scenePoint,
          style: callbacks.readDrawStyle(),
          dragStartSlop: dragStartSlop,
        );
        break;
    }
  }

  InteractiveGestureFamily get _currentGestureFamily {
    return callbacks.readMode() == CanvasMode.move
        ? InteractiveGestureFamily.move
        : InteractiveGestureFamily.draw;
  }
}
