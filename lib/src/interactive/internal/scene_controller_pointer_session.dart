import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../contract/canvas_pointer_input.dart';
import '../../contract/pointer_input.dart';
import '../../contract/pointer_phase_codec.dart';
import '../../contract/scene_view_runtime.dart';
import '../../core/pointer_input_tracker.dart';
import 'pointer_session_token.dart';

void _discardPointerSignal(PointerSignal _) {}

final class SceneControllerPointerSession implements SceneViewPointerSession {
  SceneControllerPointerSession({
    required Listenable ownerListenable,
    required PointerSessionToken token,
    required PointerInputSettings Function() readPointerSettings,
    required bool Function() isMounted,
    required bool Function() hasLiveRawPointers,
    required void Function(PointerSessionToken token) detachPointerSession,
    required void Function(PointerSessionToken token)
    releasePointerSessionToken,
    required void Function(
      CanvasPointerInput input, {
      required PointerSessionToken token,
    })
    handlePointerFromSession,
    required void Function({
      required Offset position,
      int? timestampMs,
      required PointerSessionToken token,
    })
    handleDoubleTapFromSession,
  }) : _ownerListenable = ownerListenable,
       _token = token,
       _readPointerSettings = readPointerSettings,
       _isMounted = isMounted,
       _hasLiveRawPointers = hasLiveRawPointers,
       _detachPointerSession = detachPointerSession,
       _releasePointerSessionToken = releasePointerSessionToken,
       _handlePointerFromSession = handlePointerFromSession,
       _handleDoubleTapFromSession = handleDoubleTapFromSession,
       _appliedPointerSettings = readPointerSettings(),
       _pointerTracker = PointerInputTracker(settings: readPointerSettings()) {
    _pointerTrackerGeneration = 1;
    _ownerListener = _handleOwnerChanged;
    _ownerListenable.addListener(_ownerListener);
  }

  final Listenable _ownerListenable;
  final PointerSessionToken _token;
  final PointerInputSettings Function() _readPointerSettings;
  final bool Function() _isMounted;
  final bool Function() _hasLiveRawPointers;
  final void Function(PointerSessionToken token) _detachPointerSession;
  final void Function(PointerSessionToken token) _releasePointerSessionToken;
  final void Function(
    CanvasPointerInput input, {
    required PointerSessionToken token,
  })
  _handlePointerFromSession;
  final void Function({
    required Offset position,
    int? timestampMs,
    required PointerSessionToken token,
  })
  _handleDoubleTapFromSession;
  final _PendingTapFlushScheduler _pendingTapFlushScheduler =
      _PendingTapFlushScheduler();
  late final VoidCallback _ownerListener;

  late PointerInputTracker _pointerTracker;
  late PointerInputSettings _appliedPointerSettings;
  PointerInputSettings? _pendingPointerSettings;
  int _pointerTrackerGeneration = 0;
  bool _detached = false;
  bool _disposed = false;
  bool _ownedResourcesReleased = false;

  @override
  int? get pendingTapFlushTimestampMs =>
      _detached ? null : _pendingTapFlushScheduler.pendingTapFlushTimestampMs;

  @override
  void detach() {
    if (_detached || _disposed) {
      return;
    }
    _detached = true;
    _pendingPointerSettings = null;
    _pointerTrackerGeneration++;
    _pendingTapFlushScheduler.clear();
    _detachPointerSession(_token);
    _releaseOwnedResources();
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    detach();
    _disposed = true;
    _pendingTapFlushScheduler.dispose();
  }

  @override
  void handleRoutedSample(
    PointerSample sample, {
    required bool shouldTrackSignals,
  }) {
    if (_detached) {
      return;
    }
    try {
      _handlePointerFromSession(
        CanvasPointerInput(
          pointerId: sample.pointerId,
          position: sample.position,
          timestampMs: sample.timestampMs,
          phase: canvasPointerPhaseFromPointerPhase(sample.phase),
          kind: sample.kind,
        ),
        token: _token,
      );
    } catch (_) {
      if (shouldTrackSignals && _isTerminalSample(sample)) {
        _pointerTracker.discardPointer(sample.pointerId);
        _syncPendingFlushTimer(referenceTimestampMs: sample.timestampMs);
      }
      rethrow;
    }
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
    if (_detached) {
      return;
    }
    try {
      _handlePointerFromSession(input, token: _token);
    } finally {
      _pointerTracker.discardPointer(pointerId);
      _syncPendingFlushTimer(referenceTimestampMs: referenceTimestampMs);
    }
  }

  @override
  void handleRawPointerRelease({required bool isIdleAfterRelease}) {
    if (_detached) {
      return;
    }
    if (!isIdleAfterRelease) {
      return;
    }
    _applyPendingPointerSettingsIfPossible();
  }

  void resetForInteractiveEpoch() {
    if (_detached || _disposed) {
      return;
    }
    _resetPointerTrackerState(settings: _appliedPointerSettings);
  }

  void deactivateForOwnerDispose() {
    if (_detached || _disposed) {
      return;
    }
    _detached = true;
    _pendingPointerSettings = null;
    _pointerTrackerGeneration++;
    _pendingTapFlushScheduler.clear();
    _releaseOwnedResources();
  }

  void _handleOwnerChanged() {
    if (_detached) {
      return;
    }
    if (!_isMounted()) {
      return;
    }
    _adoptPointerSettings(
      _readPointerSettings(),
      routerHasLiveRawPointers: _hasLiveRawPointers(),
    );
  }

  void _emitTrackedSignals(PointerSample sample) {
    for (final signal in _pointerTracker.handle(sample)) {
      if (signal.type != PointerSignalType.doubleTap) {
        continue;
      }
      _handleDoubleTapFromSession(
        position: signal.position,
        timestampMs: signal.timestampMs,
        token: _token,
      );
    }
  }

  bool _isTerminalSample(PointerSample sample) {
    return sample.phase == PointerPhase.up ||
        sample.phase == PointerPhase.cancel;
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
    if (_detached) {
      return;
    }
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
    _resetPointerTrackerState(settings: settings);
  }

  void _resetPointerTrackerState({required PointerInputSettings settings}) {
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

  void _releaseOwnedResources() {
    if (_ownedResourcesReleased) {
      return;
    }
    _ownedResourcesReleased = true;
    _ownerListenable.removeListener(_ownerListener);
    _releasePointerSessionToken(_token);
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
