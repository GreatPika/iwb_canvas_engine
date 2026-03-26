import 'dart:async';

import 'package:flutter/widgets.dart';

import '../contract/canvas_pointer_input.dart';
import '../core/pointer_input.dart';
import '../interactive/scene_controller_interactive.dart';
import 'scene_view_pointer_router.dart';

void _discardPointerSignal(PointerSignal _) {}

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

class _PendingTapFlushScheduler {
  Timer? _pendingTapTimer;
  int? _pendingTapFlushTimestampMs;

  int? get pendingTapFlushTimestampMs => _pendingTapFlushTimestampMs;

  void dispose() {
    clear();
  }

  void clear() {
    _pendingTapTimer?.cancel();
    _pendingTapTimer = null;
    _pendingTapFlushTimestampMs = null;
  }

  void sync({
    required int? nextFlushTimestampMs,
    required int referenceTimestampMs,
    required int ownerGeneration,
    required void Function(int expectedFlushTimestampMs, int ownerGeneration)
    onFlush,
  }) {
    if (nextFlushTimestampMs == null) {
      clear();
      return;
    }

    if (_pendingTapTimer != null &&
        _pendingTapFlushTimestampMs == nextFlushTimestampMs) {
      return;
    }

    clear();
    _pendingTapFlushTimestampMs = nextFlushTimestampMs;
    final delayMs = (nextFlushTimestampMs - referenceTimestampMs)
        .clamp(0, 1 << 30)
        .toInt();
    _pendingTapTimer = Timer(
      Duration(milliseconds: delayMs),
      () => onFlush(nextFlushTimestampMs, ownerGeneration),
    );
  }

  bool matches({
    required int expectedFlushTimestampMs,
    required int ownerGeneration,
    required int currentGeneration,
    required bool isMounted,
  }) {
    return isMounted &&
        ownerGeneration == currentGeneration &&
        _pendingTapFlushTimestampMs == expectedFlushTimestampMs;
  }

  void clearCompleted(int expectedFlushTimestampMs) {
    if (_pendingTapFlushTimestampMs != expectedFlushTimestampMs) {
      return;
    }
    _pendingTapTimer = null;
    _pendingTapFlushTimestampMs = null;
  }
}

class SceneViewInteractivePointerHost {
  SceneViewInteractivePointerHost({
    required SceneControllerInteractive controller,
    required bool Function() isMounted,
    required void Function() onControllerChanged,
  }) : _controller = controller,
       _isMounted = isMounted,
       _onControllerChanged = onControllerChanged,
       _runtime = _SceneViewInteractivePointerRuntime(
         controller: controller,
         isMounted: isMounted,
       ) {
    _subscribeToController(controller);
  }

  SceneControllerInteractive _controller;
  final bool Function() _isMounted;
  final void Function() _onControllerChanged;

  final _SceneViewInteractivePointerRuntime _runtime;
  late VoidCallback _controllerListener;
  int _controllerListenerGeneration = 0;

  int get debugLiveRawPointerCount => _runtime.debugLiveRawPointerCount;
  int? get debugPendingTapFlushTimestampMs =>
      _runtime.debugPendingTapFlushTimestampMs;

  void updateController(SceneControllerInteractive controller) {
    if (identical(_controller, controller)) {
      return;
    }
    _unsubscribeFromController(_controller);
    _controller = controller;
    _runtime.updateController(controller);
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
    required SceneControllerInteractive controller,
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

  void _subscribeToController(SceneControllerInteractive controller) {
    _controllerListenerGeneration++;
    final ownerGeneration = _controllerListenerGeneration;
    _controllerListener = () => _handleControllerChanged(
      controller: controller,
      ownerGeneration: ownerGeneration,
    );
    controller.addListener(_controllerListener);
  }

  void _unsubscribeFromController(SceneControllerInteractive controller) {
    controller.removeListener(_controllerListener);
  }
}

class _SceneViewInteractivePointerRuntime {
  _SceneViewInteractivePointerRuntime({
    required SceneControllerInteractive controller,
    required bool Function() isMounted,
  }) : _controller = controller,
       _isMounted = isMounted,
       _appliedPointerSettings = controller.pointerSettings,
       _pointerTracker = PointerInputTracker(
         settings: controller.pointerSettings,
       ) {
    _pointerTrackerGeneration = 1;
  }

  SceneControllerInteractive _controller;
  final bool Function() _isMounted;

  final SceneViewPointerRouter _pointerRouter = SceneViewPointerRouter();
  final _PendingTapFlushScheduler _pendingTapFlushScheduler =
      _PendingTapFlushScheduler();

  late PointerInputTracker _pointerTracker;
  late PointerInputSettings _appliedPointerSettings;
  PointerInputSettings? _pendingPointerSettings;
  int _pointerTrackerGeneration = 0;

  int get debugLiveRawPointerCount => _pointerRouter.liveRawPointerCount;
  int? get debugPendingTapFlushTimestampMs =>
      _pendingTapFlushScheduler.pendingTapFlushTimestampMs;

  void updateController(SceneControllerInteractive controller) {
    if (identical(_controller, controller)) {
      return;
    }
    _controller = controller;
    _resetPointerTracking(settings: controller.pointerSettings);
  }

  void dispose() {
    _pendingTapFlushScheduler.dispose();
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
    _controller.handlePointer(_canvasPointerInputFromSample(sample));
    _emitTrackedSignals(sample);
    _syncPendingFlushTimer(referenceTimestampMs: sample.timestampMs);
    if (!_isTerminalPhase(phase)) {
      return;
    }
    if (_pointerRouter.release(event.pointer).isIdleAfterRelease) {
      _applyPendingPointerSettingsIfPossible();
    }
  }

  void handleControllerChanged() {
    _adoptPointerSettings(_controller.pointerSettings);
  }

  void _emitTrackedSignals(PointerSample sample) {
    if (!_pointerRouter.shouldTrackSignals(
      pointerId: sample.pointerId,
      phase: sample.phase,
    )) {
      return;
    }
    for (final signal in _pointerTracker.handle(sample)) {
      if (signal.type != PointerSignalType.doubleTap) {
        continue;
      }
      _controller.handleDoubleTap(
        position: signal.position,
        timestampMs: signal.timestampMs,
      );
    }
  }

  void _syncPendingFlushTimer({required int referenceTimestampMs}) {
    _pendingTapFlushScheduler.sync(
      nextFlushTimestampMs: _pointerTracker.nextPendingFlushTimestampMs,
      referenceTimestampMs: referenceTimestampMs,
      ownerGeneration: _pointerTrackerGeneration,
      onFlush: _handlePendingTapTimer,
    );
  }

  void _handlePendingTapTimer(
    int expectedFlushTimestampMs,
    int ownerGeneration,
  ) {
    if (!_pendingTapFlushScheduler.matches(
      expectedFlushTimestampMs: expectedFlushTimestampMs,
      ownerGeneration: ownerGeneration,
      currentGeneration: _pointerTrackerGeneration,
      isMounted: _isMounted(),
    )) {
      return;
    }

    _pendingTapFlushScheduler.clearCompleted(expectedFlushTimestampMs);
    _pointerTracker.flushPendingTo(
      expectedFlushTimestampMs,
      _discardPointerSignal,
    );
    if (!_isMounted() || ownerGeneration != _pointerTrackerGeneration) {
      return;
    }
    _syncPendingFlushTimer(referenceTimestampMs: expectedFlushTimestampMs);
  }

  void _resetPointerTracking({required PointerInputSettings settings}) {
    _pendingPointerSettings = null;
    _appliedPointerSettings = settings;
    _pointerTracker = PointerInputTracker(settings: settings);
    _pointerTrackerGeneration++;
    _pendingTapFlushScheduler.clear();
    _pointerRouter.reset();
  }

  void _adoptPointerSettings(PointerInputSettings nextSettings) {
    if (_pointerRouter.hasLiveRawPointers) {
      _pendingPointerSettings = nextSettings == _appliedPointerSettings
          ? null
          : nextSettings;
      return;
    }
    if (nextSettings == _appliedPointerSettings) {
      _pendingPointerSettings = null;
      return;
    }
    _resetPointerTracking(settings: nextSettings);
  }

  void _applyPendingPointerSettingsIfPossible() {
    final pending = _pendingPointerSettings;
    if (pending == null || !_pointerRouter.isIdle) {
      return;
    }
    _resetPointerTracking(settings: pending);
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

    _controller.handlePointer(
      _canvasPointerInputFromSample(
        _pointerSampleFromEvent(
          pointerId: pointerId,
          event: event,
          phase: phase,
        ),
      ),
    );

    _pointerTracker.discardPointer(pointerId);
    final release = _pointerRouter.release(event.pointer);
    if (release.isIdleAfterRelease) {
      _applyPendingPointerSettingsIfPossible();
      return;
    }
    _syncPendingFlushTimer(
      referenceTimestampMs: event.timeStamp.inMilliseconds,
    );
  }
}
