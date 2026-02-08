import 'dart:ui';

/// Low-level pointer lifecycle phases.
enum PointerPhase { down, move, up, cancel }

/// High-level signals derived from [PointerSample] input.
enum PointerSignalType { down, move, up, cancel, tap, doubleTap }

/// A single pointer sample in view/screen coordinates.
class PointerSample {
  const PointerSample({
    required this.pointerId,
    required this.position,
    required this.timestampMs,
    required this.phase,
    this.kind = PointerDeviceKind.touch,
  });

  final int pointerId;
  final Offset position;

  /// Host-provided timestamp hint for event ordering.
  ///
  /// `SceneController` normalizes this hint into an internal monotonic
  /// timeline before using it for emitted actions/signals.
  final int timestampMs;
  final PointerPhase phase;
  final PointerDeviceKind kind;
}

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

/// Thresholds and timings used by [PointerInputTracker].
class PointerInputSettings {
  const PointerInputSettings({
    this.tapSlop = 8,
    this.doubleTapSlop = 24,
    this.doubleTapMaxDelayMs = 300,
    this.deferSingleTap = true,
  });

  final double tapSlop;
  final double doubleTapSlop;
  final int doubleTapMaxDelayMs;

  /// When true, single tap is emitted only after the double-tap window passes.
  final bool deferSingleTap;
}

/// Converts [PointerSample] input into a stream of [PointerSignal]s.
///
/// The tracker is stateless with respect to the scene model and can be reused
/// by hosts that want tap/double-tap detection.
class PointerInputTracker {
  PointerInputTracker({PointerInputSettings? settings})
    : settings = settings ?? const PointerInputSettings();

  final PointerInputSettings settings;
  final Map<int, _PointerDownState> _downStates = <int, _PointerDownState>{};
  final Map<int, _PendingTap> _pendingTapByPointerId = <int, _PendingTap>{};

  /// Whether at least one pointer currently has a pending tap window.
  bool get hasPendingTap => _pendingTapByPointerId.isNotEmpty;

  /// Earliest timestamp when [flushPending] may emit one or more taps.
  ///
  /// Returns `null` when there are no pending taps.
  int? get nextPendingFlushTimestampMs {
    if (_pendingTapByPointerId.isEmpty) return null;
    var earliestTimestampMs = _pendingTapByPointerId.values.first.timestampMs;
    for (final pendingTap in _pendingTapByPointerId.values) {
      if (pendingTap.timestampMs < earliestTimestampMs) {
        earliestTimestampMs = pendingTap.timestampMs;
      }
    }
    return earliestTimestampMs + settings.doubleTapMaxDelayMs + 1;
  }

  List<PointerSignal> handle(PointerSample sample) {
    final signals = <PointerSignal>[
      ..._flushExpired(sample.timestampMs),
      PointerSignal.fromSample(sample, _signalTypeFor(sample.phase)),
    ];

    switch (sample.phase) {
      case PointerPhase.down:
        _downStates[sample.pointerId] = _PointerDownState(
          position: sample.position,
        );
        break;
      case PointerPhase.move:
        final down = _downStates[sample.pointerId];
        if (down != null && !down.movedBeyondSlop) {
          down.movedBeyondSlop =
              (sample.position - down.position).distance > settings.tapSlop;
        }
        break;
      case PointerPhase.up:
        final down = _downStates.remove(sample.pointerId);
        if (down != null && !down.movedBeyondSlop) {
          _handleTap(sample, signals);
        }
        break;
      case PointerPhase.cancel:
        _downStates.remove(sample.pointerId);
        break;
    }

    return signals;
  }

  /// Emits deferred single-tap signals whose double-tap window has expired.
  ///
  /// Call this from a timer/tick in the host app if there are no pointer events.
  List<PointerSignal> flushPending(int timestampMs) {
    return _flushExpired(timestampMs);
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

  void _handleTap(PointerSample sample, List<PointerSignal> signals) {
    final pendingTap = _pendingTapByPointerId[sample.pointerId];
    if (pendingTap != null && _isDoubleTap(sample, pendingTap)) {
      signals.add(
        PointerSignal.fromSample(sample, PointerSignalType.doubleTap),
      );
      _pendingTapByPointerId.remove(sample.pointerId);
      return;
    }

    if (pendingTap != null && settings.deferSingleTap) {
      signals.add(
        PointerSignal(
          type: PointerSignalType.tap,
          pointerId: pendingTap.pointerId,
          position: pendingTap.position,
          timestampMs: pendingTap.timestampMs,
          kind: pendingTap.kind,
        ),
      );
      _pendingTapByPointerId.remove(sample.pointerId);
    }

    if (!settings.deferSingleTap) {
      signals.add(PointerSignal.fromSample(sample, PointerSignalType.tap));
    }

    _pendingTapByPointerId[sample.pointerId] = _PendingTap(
      pointerId: sample.pointerId,
      position: sample.position,
      timestampMs: sample.timestampMs,
      kind: sample.kind,
    );
  }

  List<PointerSignal> _flushExpired(int timestampMs) {
    if (_pendingTapByPointerId.isEmpty) return const <PointerSignal>[];

    final expiredPointerIds = <int>[];
    final signals = <PointerSignal>[];

    _pendingTapByPointerId.forEach((pointerId, pendingTap) {
      final timeDelta = timestampMs - pendingTap.timestampMs;
      if (timeDelta < 0) return;
      if (timeDelta <= settings.doubleTapMaxDelayMs) return;

      expiredPointerIds.add(pointerId);
      if (settings.deferSingleTap) {
        signals.add(
          PointerSignal(
            type: PointerSignalType.tap,
            pointerId: pendingTap.pointerId,
            position: pendingTap.position,
            timestampMs: pendingTap.timestampMs,
            kind: pendingTap.kind,
          ),
        );
      }
    });

    for (final pointerId in expiredPointerIds) {
      _pendingTapByPointerId.remove(pointerId);
    }

    return signals;
  }

  bool _isDoubleTap(PointerSample sample, _PendingTap pendingTap) {
    final timeDelta = sample.timestampMs - pendingTap.timestampMs;
    if (timeDelta < 0 || timeDelta > settings.doubleTapMaxDelayMs) {
      return false;
    }

    final distance = (sample.position - pendingTap.position).distance;
    return distance <= settings.doubleTapSlop;
  }
}

class _PointerDownState {
  _PointerDownState({required this.position});

  final Offset position;
  bool movedBeyondSlop = false;
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
