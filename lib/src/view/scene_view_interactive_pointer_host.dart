import 'package:flutter/widgets.dart';

import '../contract/canvas_pointer_input.dart';
import '../core/pointer_input.dart';
import '../interactive/scene_controller.dart';
import '../interactive/internal/scene_controller_internal_access.dart';
import 'scene_view_pointer_router.dart';

bool _hasFiniteLocalPosition(PointerEvent event) {
  return event.localPosition.dx.isFinite && event.localPosition.dy.isFinite;
}

bool _isTerminalPhase(PointerPhase phase) {
  return phase == PointerPhase.up || phase == PointerPhase.cancel;
}

bool _shouldDropInvalidFiniteAdmission(PointerEvent event, PointerPhase phase) {
  return !_hasFiniteLocalPosition(event) &&
      (phase == PointerPhase.down || phase == PointerPhase.move);
}

bool _isInvalidTerminalHostEvent(PointerEvent event, PointerPhase phase) {
  return !_hasFiniteLocalPosition(event) && _isTerminalPhase(phase);
}

int? _routePointerId(
  SceneViewPointerRouter pointerRouter, {
  required int rawPointer,
  required PointerPhase phase,
}) {
  final routedPointer = pointerRouter.route(
    rawPointer: rawPointer,
    phase: phase,
  );
  if (routedPointer.isStray || routedPointer.pointerId == null) {
    return null;
  }
  return routedPointer.pointerId;
}

PointerSample _pointerSampleFromEvent({
  required int pointerId,
  required PointerEvent event,
  required PointerPhase phase,
}) {
  return PointerSample(
    pointerId: pointerId,
    position: event.localPosition,
    timestampMs: event.timeStamp.inMilliseconds,
    phase: phase,
    kind: event.kind,
  );
}

CanvasPointerInput _canvasPointerInputFromSample(PointerSample sample) {
  return CanvasPointerInput(
    pointerId: sample.pointerId,
    position: sample.position,
    timestampMs: sample.timestampMs,
    phase: _toCanvasPointerPhase(sample.phase),
    kind: sample.kind,
  );
}

CanvasPointerPhase _toCanvasPointerPhase(PointerPhase phase) {
  switch (phase) {
    case PointerPhase.down:
      return CanvasPointerPhase.down;
    case PointerPhase.move:
      return CanvasPointerPhase.move;
    case PointerPhase.up:
      return CanvasPointerPhase.up;
    case PointerPhase.cancel:
      return CanvasPointerPhase.cancel;
  }
}

class SceneViewInteractivePointerHost {
  SceneViewInteractivePointerHost({
    required SceneController controller,
    required bool Function() isMounted,
    required void Function() onControllerChanged,
    required SceneControllerPointerSemanticsBridge pointerSemantics,
  }) : _controller = controller,
       _isMounted = isMounted,
       _onControllerChanged = onControllerChanged,
       _runtime = _SceneViewInteractivePointerRuntime(
         pointerSemantics: pointerSemantics,
       ) {
    _subscribeToController(controller);
  }

  SceneController _controller;
  final bool Function() _isMounted;
  final void Function() _onControllerChanged;

  final _SceneViewInteractivePointerRuntime _runtime;
  late VoidCallback _controllerListener;
  int _controllerListenerGeneration = 0;

  int get debugLiveRawPointerCount => _runtime.debugLiveRawPointerCount;
  int? get debugPendingTapFlushTimestampMs =>
      _runtime.debugPendingTapFlushTimestampMs;

  void updateController(SceneController controller) {
    if (identical(_controller, controller)) {
      return;
    }
    _unsubscribeFromController(_controller);
    _controller = controller;
    _runtime.replacePointerSemantics(
      sceneControllerInternalCreatePointerSemanticsBridge(
        controller,
        isMounted: _isMounted,
      ),
    );
    _subscribeToController(controller);
  }

  void dispose() {
    _unsubscribeFromController(_controller);
    _runtime.dispose();
  }

  void handlePointerEvent(PointerEvent event, PointerPhase phase) {
    _runtime.handlePointerEvent(event, phase);
  }

  void _handleControllerChanged({
    required SceneController controller,
    required int ownerGeneration,
  }) {
    if (!_isMounted() ||
        ownerGeneration != _controllerListenerGeneration ||
        !identical(controller, _controller)) {
      return;
    }
    _runtime.handleControllerChanged();
    _onControllerChanged();
  }

  void _subscribeToController(SceneController controller) {
    _controllerListenerGeneration++;
    final ownerGeneration = _controllerListenerGeneration;
    _controllerListener = () => _handleControllerChanged(
      controller: controller,
      ownerGeneration: ownerGeneration,
    );
    controller.addListener(_controllerListener);
  }

  void _unsubscribeFromController(SceneController controller) {
    controller.removeListener(_controllerListener);
  }
}

class _SceneViewInteractivePointerRuntime {
  _SceneViewInteractivePointerRuntime({
    required SceneControllerPointerSemanticsBridge pointerSemantics,
  }) : _pointerSemantics = pointerSemantics;

  final SceneViewPointerRouter _pointerRouter = SceneViewPointerRouter();
  SceneControllerPointerSemanticsBridge _pointerSemantics;

  int get debugLiveRawPointerCount => _pointerRouter.liveRawPointerCount;
  int? get debugPendingTapFlushTimestampMs =>
      _pointerSemantics.pendingTapFlushTimestampMs;

  void replacePointerSemantics(SceneControllerPointerSemanticsBridge next) {
    _pointerSemantics.dispose();
    _pointerSemantics = next;
    _pointerRouter.reset();
  }

  void dispose() {
    _pointerSemantics.dispose();
  }

  void handlePointerEvent(PointerEvent event, PointerPhase phase) {
    if (_shouldDropInvalidFiniteAdmission(event, phase)) {
      return;
    }
    if (_isInvalidTerminalHostEvent(event, phase)) {
      _forwardInvalidTerminalHostEvent(event, phase);
      return;
    }

    final pointerId = _routePointerId(
      _pointerRouter,
      rawPointer: event.pointer,
      phase: phase,
    );
    if (pointerId == null) {
      return;
    }

    final sample = _pointerSampleFromEvent(
      pointerId: pointerId,
      event: event,
      phase: phase,
    );
    _pointerSemantics.handleRoutedSample(
      sample,
      shouldTrackSignals: _pointerRouter.shouldTrackSignals(
        pointerId: sample.pointerId,
        phase: sample.phase,
      ),
    );
    if (_isTerminalPhase(phase)) {
      final release = _pointerRouter.release(event.pointer);
      _pointerSemantics.handleRawPointerRelease(
        isIdleAfterRelease: release.isIdleAfterRelease,
      );
    }
  }

  void handleControllerChanged() {
    _pointerSemantics.handleControllerChanged(
      routerHasLiveRawPointers: _pointerRouter.hasLiveRawPointers,
    );
  }

  void _forwardInvalidTerminalHostEvent(
    PointerEvent event,
    PointerPhase phase,
  ) {
    final pointerId = _routePointerId(
      _pointerRouter,
      rawPointer: event.pointer,
      phase: phase,
    );
    if (pointerId == null) {
      return;
    }

    final input = _canvasPointerInputFromSample(
      _pointerSampleFromEvent(pointerId: pointerId, event: event, phase: phase),
    );
    final release = _pointerRouter.release(event.pointer);
    _pointerSemantics.handleInvalidTerminalSample(
      input: input,
      pointerId: pointerId,
      referenceTimestampMs: event.timeStamp.inMilliseconds,
    );
    _pointerSemantics.handleRawPointerRelease(
      isIdleAfterRelease: release.isIdleAfterRelease,
    );
  }
}
