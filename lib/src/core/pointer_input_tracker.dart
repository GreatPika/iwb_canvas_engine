import 'dart:ui';

import '../contract/pointer_input.dart';

/// High-level signals derived from [PointerSample] input.
enum PointerSignalType { down, move, up, cancel, tap, doubleTap }

/// A derived pointer signal (including tap and double tap).
class PointerSignal {
  const PointerSignal({
    required this.type,
    required this.pointerId,
    required this.position,
    required this.timestampMs,
    required this.kind,
  });

  factory PointerSignal.fromSample(
    PointerSample sample,
    PointerSignalType type,
  ) {
    return PointerSignal(
      type: type,
      pointerId: sample.pointerId,
      position: sample.position,
      timestampMs: sample.timestampMs,
      kind: sample.kind,
    );
  }

  final PointerSignalType type;
  final int pointerId;
  final Offset position;
  final int timestampMs;
  final PointerDeviceKind kind;
}

/// Converts [PointerSample] input into a stream of [PointerSignal]s.
///
/// The tracker is stateless with respect to the scene model and can be reused
/// by hosts that want tap/double-tap detection.
class PointerInputTracker {
  PointerInputTracker({PointerInputSettings? settings})
    : settings = settings ?? const PointerInputSettings(),
      _activePointers = _ActivePointerStateOwner(
        tapSlop: (settings ?? const PointerInputSettings()).tapSlop,
      ),
      _pendingTaps = _PendingTapWindowOwner(
        settings: settings ?? const PointerInputSettings(),
      ) {
    validatePointerInputSettings(this.settings);
  }

  final PointerInputSettings settings;
  final _ActivePointerStateOwner _activePointers;
  final _PendingTapWindowOwner _pendingTaps;

  /// Whether at least one pointer currently has a pending tap window.
  bool get hasPendingTap => _pendingTaps.hasPendingTap;

  /// Earliest timestamp when [flushPending] may emit one or more taps.
  ///
  /// Returns `null` when there are no pending taps.
  int? get nextPendingFlushTimestampMs => _pendingTaps.nextFlushTimestampMs;

  List<PointerSignal> handle(PointerSample sample) {
    final signals = <PointerSignal>[
      ..._pendingTaps.flushExpired(sample.timestampMs),
      PointerSignal.fromSample(sample, _signalTypeFor(sample.phase)),
    ];

    switch (sample.phase) {
      case PointerPhase.down:
        _activePointers.handleDown(sample);
        break;
      case PointerPhase.move:
        _activePointers.handleMove(sample);
        break;
      case PointerPhase.up:
        if (_activePointers.takeTapCandidate(sample.pointerId)) {
          _pendingTaps.handleTap(sample, signals.add);
        }
        break;
      case PointerPhase.cancel:
        _activePointers.handleCancel(sample.pointerId);
        break;
    }

    return signals;
  }

  /// Emits deferred single-tap signals whose double-tap window has expired.
  ///
  /// Call this from a timer/tick in the host app if there are no pointer
  /// events.
  List<PointerSignal> flushPending(int timestampMs) {
    final signals = <PointerSignal>[];
    flushPendingTo(timestampMs, signals.add);
    return signals;
  }

  /// Emits deferred single-tap signals into [emit] without allocating a list.
  ///
  /// Hosts that only need the side effect can use this as the canonical flush
  /// primitive and avoid materializing a temporary collection.
  void flushPendingTo(
    int timestampMs,
    void Function(PointerSignal signal) emit,
  ) {
    _pendingTaps.flushExpiredTo(timestampMs, emit);
  }

  /// Drops transient tracker state for [pointerId] without emitting signals.
  ///
  /// Host runtimes use this when the host lifecycle ends a routed pointer
  /// without forwarding a terminal sample into the controller/tracker pipeline.
  void discardPointer(int pointerId) {
    _activePointers.discardPointer(pointerId);
    _pendingTaps.discardPointer(pointerId);
  }

  PointerSignalType _signalTypeFor(PointerPhase phase) {
    switch (phase) {
      case PointerPhase.down:
        return PointerSignalType.down;
      case PointerPhase.move:
        return PointerSignalType.move;
      case PointerPhase.up:
        return PointerSignalType.up;
      case PointerPhase.cancel:
        return PointerSignalType.cancel;
    }
  }
}

class _PointerDownState {
  _PointerDownState({required this.position});

  final Offset position;
  bool movedBeyondSlop = false;
}

class _ActivePointerStateOwner {
  _ActivePointerStateOwner({required double tapSlop})
    : _tapSlopSquared = tapSlop * tapSlop;

  final double _tapSlopSquared;
  final Map<int, _PointerDownState> _downStates = <int, _PointerDownState>{};

  void handleDown(PointerSample sample) {
    _downStates[sample.pointerId] = _PointerDownState(
      position: sample.position,
    );
  }

  void handleMove(PointerSample sample) {
    final down = _downStates[sample.pointerId];
    if (down == null || down.movedBeyondSlop) return;

    final delta = sample.position - down.position;
    final deltaSquared = delta.dx * delta.dx + delta.dy * delta.dy;
    down.movedBeyondSlop = deltaSquared > _tapSlopSquared;
  }

  bool takeTapCandidate(int pointerId) {
    final down = _downStates.remove(pointerId);
    return down != null && !down.movedBeyondSlop;
  }

  void handleCancel(int pointerId) {
    _downStates.remove(pointerId);
  }

  void discardPointer(int pointerId) {
    _downStates.remove(pointerId);
  }
}

class _PendingTapWindowOwner {
  _PendingTapWindowOwner({required PointerInputSettings settings})
    : _settings = settings;

  final PointerInputSettings _settings;
  final Map<int, _PendingTap> _pendingTapByPointerId = <int, _PendingTap>{};

  bool get hasPendingTap => _pendingTapByPointerId.isNotEmpty;

  int? get nextFlushTimestampMs {
    if (_pendingTapByPointerId.isEmpty) return null;
    var earliestTimestampMs = _pendingTapByPointerId.values.first.timestampMs;
    for (final pendingTap in _pendingTapByPointerId.values) {
      if (pendingTap.timestampMs < earliestTimestampMs) {
        earliestTimestampMs = pendingTap.timestampMs;
      }
    }
    return earliestTimestampMs + _settings.doubleTapMaxDelayMs + 1;
  }

  void handleTap(
    PointerSample sample,
    void Function(PointerSignal signal) emit,
  ) {
    final pendingTap = _pendingTapByPointerId[sample.pointerId];
    if (pendingTap != null && _isDoubleTap(sample, pendingTap)) {
      emit(PointerSignal.fromSample(sample, PointerSignalType.doubleTap));
      _pendingTapByPointerId.remove(sample.pointerId);
      return;
    }

    if (pendingTap != null && _settings.deferSingleTap) {
      emit(_tapSignalFor(pendingTap));
      _pendingTapByPointerId.remove(sample.pointerId);
    }

    if (!_settings.deferSingleTap) {
      emit(PointerSignal.fromSample(sample, PointerSignalType.tap));
    }

    _pendingTapByPointerId[sample.pointerId] = _PendingTap(
      pointerId: sample.pointerId,
      position: sample.position,
      timestampMs: sample.timestampMs,
      kind: sample.kind,
    );
  }

  List<PointerSignal> flushExpired(int timestampMs) {
    final signals = <PointerSignal>[];
    flushExpiredTo(timestampMs, signals.add);
    return signals;
  }

  void flushExpiredTo(
    int timestampMs,
    void Function(PointerSignal signal) emit,
  ) {
    if (_pendingTapByPointerId.isEmpty) return;

    final expiredPointerIds = <int>[];

    _pendingTapByPointerId.forEach((pointerId, pendingTap) {
      final timeDelta = timestampMs - pendingTap.timestampMs;
      if (timeDelta < 0) return;
      if (timeDelta <= _settings.doubleTapMaxDelayMs) return;

      expiredPointerIds.add(pointerId);
      if (_settings.deferSingleTap) {
        emit(_tapSignalFor(pendingTap));
      }
    });

    for (final pointerId in expiredPointerIds) {
      _pendingTapByPointerId.remove(pointerId);
    }
  }

  void discardPointer(int pointerId) {
    _pendingTapByPointerId.remove(pointerId);
  }

  bool _isDoubleTap(PointerSample sample, _PendingTap pendingTap) {
    final timeDelta = sample.timestampMs - pendingTap.timestampMs;
    if (timeDelta < 0 || timeDelta > _settings.doubleTapMaxDelayMs) {
      return false;
    }

    final delta = sample.position - pendingTap.position;
    final distanceSquared = delta.dx * delta.dx + delta.dy * delta.dy;
    final doubleTapSlop = _settings.doubleTapSlop;
    return distanceSquared <= doubleTapSlop * doubleTapSlop;
  }

  PointerSignal _tapSignalFor(_PendingTap pendingTap) {
    return PointerSignal(
      type: PointerSignalType.tap,
      pointerId: pendingTap.pointerId,
      position: pendingTap.position,
      timestampMs: pendingTap.timestampMs,
      kind: pendingTap.kind,
    );
  }
}

class _PendingTap {
  _PendingTap({
    required this.pointerId,
    required this.position,
    required this.timestampMs,
    required this.kind,
  });

  final int pointerId;
  final Offset position;
  final int timestampMs;
  final PointerDeviceKind kind;
}
