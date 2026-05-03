import 'dart:ui';

import '../../contract/pointer_input.dart';
import '../../core/geometry.dart';
import '../../core/interaction_types.dart';
import 'interactive_draw_coordinator.dart';
import 'interactive_gesture_machine.dart';
import 'interactive_move_session.dart';
import 'pointer_session_token.dart';
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

  InteractiveGestureFamily? interruptActiveGesture() {
    return _gestureMachine.interruptActiveGesture();
  }

  InteractiveGestureFamily? detachPointerSession(PointerSessionToken token) {
    return _gestureMachine.detachSession(token);
  }

  void dispatchPointerSample(
    PointerSample sample, {
    PointerSessionToken? sessionToken,
  }) {
    switch (sample.phase) {
      case PointerPhase.down:
        _handlePointerDown(sample, sessionToken: sessionToken);
        break;
      case PointerPhase.move:
      case PointerPhase.up:
      case PointerPhase.cancel:
        _handleOwnedPointerSample(sample, sessionToken: sessionToken);
        break;
    }
  }

  Offset toScenePoint(Offset viewPoint) {
    return toScene(viewPoint, callbacks.readSnapshot().camera.offset);
  }

  static bool isTerminalPointerPhase(PointerPhase phase) {
    return phase == PointerPhase.up || phase == PointerPhase.cancel;
  }

  void _handlePointerDown(
    PointerSample sample, {
    PointerSessionToken? sessionToken,
  }) {
    final family = _currentGestureFamily;
    final activeGesture = _gestureMachine.begin(
      pointerId: sample.pointerId,
      sessionToken: sessionToken,
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
        sessionToken: activeGesture.sessionToken,
        dragStartSlop: activeGesture.dragStartSlop,
      );
    } catch (_) {
      _gestureMachine.interruptActiveGesture();
      rethrow;
    }
  }

  void _handleOwnedPointerSample(
    PointerSample sample, {
    PointerSessionToken? sessionToken,
  }) {
    final activeGesture = _gestureMachine.activeGestureForPointer(
      sample.pointerId,
      sessionToken: sessionToken,
    );
    if (activeGesture == null) {
      return;
    }
    try {
      _dispatchPointerToFamily(
        sample,
        family: activeGesture.family,
        sessionToken: activeGesture.sessionToken,
        dragStartSlop: activeGesture.dragStartSlop,
      );
    } finally {
      if (isTerminalPointerPhase(sample.phase)) {
        _gestureMachine.interruptActiveGesture();
      }
    }
  }

  void _dispatchPointerToFamily(
    PointerSample sample, {
    required InteractiveGestureFamily family,
    required PointerSessionToken? sessionToken,
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
          sessionToken: sessionToken,
          capturedStyle: sample.phase == PointerPhase.down
              ? callbacks.readDrawStyle()
              : null,
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
