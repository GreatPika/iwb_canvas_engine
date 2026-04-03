import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../contract/canvas_pointer_input.dart';
import '../../contract/pointer_phase_codec.dart';
import '../../contract/scene_view_runtime.dart';
import '../../core/pointer_input.dart';
import '../scene_controller_interaction.dart';

void _discardPointerSignal(PointerSignal _) {}

final class SceneControllerPointerSession implements SceneViewPointerSession {
  SceneControllerPointerSession({
    required Listenable ownerListenable,
    required SceneControllerInteraction Function() readInteraction,
    required bool Function() isMounted,
    required bool Function() hasLiveRawPointers,
  }) : _ownerListenable = ownerListenable,
       _readInteraction = readInteraction,
       _isMounted = isMounted,
       _hasLiveRawPointers = hasLiveRawPointers,
       _appliedPointerSettings = readInteraction().pointerSettings,
       _pointerTracker = PointerInputTracker(
         settings: readInteraction().pointerSettings,
       ) {
    _pointerTrackerGeneration = 1;
    _ownerListener = _handleOwnerChanged;
    _ownerListenable.addListener(_ownerListener);
  }

  final Listenable _ownerListenable;
  final SceneControllerInteraction Function() _readInteraction;
  final bool Function() _isMounted;
  final bool Function() _hasLiveRawPointers;
  final _PendingTapFlushScheduler _pendingTapFlushScheduler =
      _PendingTapFlushScheduler();
  late final VoidCallback _ownerListener;

  late PointerInputTracker _pointerTracker;
  late PointerInputSettings _appliedPointerSettings;
  PointerInputSettings? _pendingPointerSettings;
  int _pointerTrackerGeneration = 0;

  @override
  int? get pendingTapFlushTimestampMs =>
      _pendingTapFlushScheduler.pendingTapFlushTimestampMs;

  @override
  void dispose() {
    _ownerListenable.removeListener(_ownerListener);
    _pendingTapFlushScheduler.dispose();
  }

  @override
  void handleRoutedSample(
    PointerSample sample, {
    required bool shouldTrackSignals,
  }) {
    final interaction = _readInteraction();
    interaction.handlePointer(
      CanvasPointerInput(
        pointerId: sample.pointerId,
        position: sample.position,
        timestampMs: sample.timestampMs,
        phase: canvasPointerPhaseFromPointerPhase(sample.phase),
        kind: sample.kind,
      ),
    );
    if (shouldTrackSignals) {
      _emitTrackedSignals(interaction, sample);
    }
    _syncPendingFlushTimer(referenceTimestampMs: sample.timestampMs);
  }

  @override
  void handleInvalidTerminalSample({
    required CanvasPointerInput input,
    required int pointerId,
    required int referenceTimestampMs,
  }) {
    _readInteraction().handlePointer(input);
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

  void _handleOwnerChanged() {
    if (!_isMounted()) {
      return;
    }
    _adoptPointerSettings(
      _readInteraction().pointerSettings,
      routerHasLiveRawPointers: _hasLiveRawPointers(),
    );
  }

  void _emitTrackedSignals(
    SceneControllerInteraction interaction,
    PointerSample sample,
  ) {
    for (final signal in _pointerTracker.handle(sample)) {
      if (signal.type != PointerSignalType.doubleTap) {
        continue;
      }
      interaction.handleDoubleTap(
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
