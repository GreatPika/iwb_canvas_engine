import 'package:flutter/widgets.dart';

import '../contract/canvas_pointer_input.dart';
import '../contract/pointer_input.dart';
import '../contract/pointer_phase_codec.dart';
import '../contract/scene_view_runtime.dart';
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
    phase: canvasPointerPhaseFromPointerPhase(sample.phase),
    kind: sample.kind,
  );
}

class SceneViewInteractivePointerHost {
  SceneViewInteractivePointerHost({
    required SceneViewPointerSession pointerSession,
  }) : _runtime = _SceneViewInteractivePointerRuntime(
         pointerSession: pointerSession,
       );

  final _SceneViewInteractivePointerRuntime _runtime;

  int get debugLiveRawPointerCount => _runtime.debugLiveRawPointerCount;
  int? get debugPendingTapFlushTimestampMs =>
      _runtime.debugPendingTapFlushTimestampMs;

  void replacePointerSession(SceneViewPointerSession pointerSession) {
    _runtime.replacePointerSession(pointerSession);
  }

  void dispose() {
    _runtime.dispose();
  }

  void handlePointerEvent(PointerEvent event, PointerPhase phase) {
    _runtime.handlePointerEvent(event, phase);
  }
}

class _SceneViewInteractivePointerRuntime {
  _SceneViewInteractivePointerRuntime({
    required SceneViewPointerSession pointerSession,
  }) : _pointerSession = pointerSession;

  final SceneViewPointerRouter _pointerRouter = SceneViewPointerRouter();
  SceneViewPointerSession _pointerSession;

  int get debugLiveRawPointerCount => _pointerRouter.liveRawPointerCount;
  int? get debugPendingTapFlushTimestampMs =>
      _pointerSession.pendingTapFlushTimestampMs;

  void replacePointerSession(SceneViewPointerSession next) {
    final current = _pointerSession;
    current.detach();
    current.dispose();
    _pointerRouter.reset();
    _pointerSession = next;
  }

  void dispose() {
    _pointerSession.detach();
    _pointerSession.dispose();
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
    _pointerSession.handleRoutedSample(
      sample,
      shouldTrackSignals: _pointerRouter.shouldTrackSignals(
        pointerId: sample.pointerId,
        phase: sample.phase,
      ),
    );
    if (_isTerminalPhase(phase)) {
      final release = _pointerRouter.release(event.pointer);
      _pointerSession.handleRawPointerRelease(
        isIdleAfterRelease: release.isIdleAfterRelease,
      );
    }
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
    _pointerSession.handleInvalidTerminalSample(
      input: input,
      pointerId: pointerId,
      referenceTimestampMs: event.timeStamp.inMilliseconds,
    );
    _pointerSession.handleRawPointerRelease(
      isIdleAfterRelease: release.isIdleAfterRelease,
    );
  }
}
