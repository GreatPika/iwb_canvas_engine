import 'dart:async';

import '../../contract/canvas_pointer_input.dart';
import '../../core/pointer_input.dart';
import '../scene_controller.dart';
import '../scene_view_pointer_semantics.dart';

void _discardPointerSignal(PointerSignal _) {}

final class SceneControllerPointerSemantics
    implements SceneViewPointerSemanticsBridge {
  SceneControllerPointerSemantics({
    required SceneController controller,
    required bool Function() isMounted,
  }) : _controller = controller,
       _isMounted = isMounted,
       _appliedPointerSettings = controller.interaction.pointerSettings,
       _pointerTracker = PointerInputTracker(
         settings: controller.interaction.pointerSettings,
       ) {
    _pointerTrackerGeneration = 1;
  }

  final SceneController _controller;
  final bool Function() _isMounted;
  final _PendingTapFlushScheduler _pendingTapFlushScheduler =
      _PendingTapFlushScheduler();

  late PointerInputTracker _pointerTracker;
  late PointerInputSettings _appliedPointerSettings;
  PointerInputSettings? _pendingPointerSettings;
  int _pointerTrackerGeneration = 0;

  @override
  int? get pendingTapFlushTimestampMs =>
      _pendingTapFlushScheduler.pendingTapFlushTimestampMs;

  @override
  void dispose() {
    _pendingTapFlushScheduler.dispose();
  }

  @override
  void handleControllerChanged({required bool routerHasLiveRawPointers}) {
    _adoptPointerSettings(
      _controller.interaction.pointerSettings,
      routerHasLiveRawPointers: routerHasLiveRawPointers,
    );
  }

  @override
  void handleRoutedSample(
    PointerSample sample, {
    required bool shouldTrackSignals,
  }) {
    _controller.interaction.handlePointer(
      CanvasPointerInput(
        pointerId: sample.pointerId,
        position: sample.position,
        timestampMs: sample.timestampMs,
        phase: _toCanvasPointerPhase(sample.phase),
        kind: sample.kind,
      ),
    );
    if (shouldTrackSignals) {
      _emitTrackedSignals(sample);
    }
    _syncPendingFlushTimer(referenceTimestampMs: sample.timestampMs);
  }

  @override
  void handleInvalidTerminalSample({
    required CanvasPointerInput input,
    required int pointerId,
    required int referenceTimestampMs,
  }) {
    _controller.interaction.handlePointer(input);
    _pointerTracker.discardPointer(pointerId);
    _syncPendingFlushTimer(referenceTimestampMs: referenceTimestampMs);
  }

  @override
  void handleRawPointerRelease({required bool isIdleAfterRelease}) {
    if (!isIdleAfterRelease) {
      return;
    }
    _applyPendingPointerSettingsIfPossible();
  }

  void _emitTrackedSignals(PointerSample sample) {
    for (final signal in _pointerTracker.handle(sample)) {
      if (signal.type != PointerSignalType.doubleTap) {
        continue;
      }
      _controller.interaction.handleDoubleTap(
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
  }

  void _adoptPointerSettings(
    PointerInputSettings nextSettings, {
    required bool routerHasLiveRawPointers,
  }) {
    if (routerHasLiveRawPointers) {
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
    if (pending == null) {
      return;
    }
    _resetPointerTracking(settings: pending);
  }
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

final class _PendingTapFlushScheduler {
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
