import 'dart:ui';

/// Low-level pointer lifecycle phases.
enum PointerPhase { down, move, up, cancel }

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
  /// Runtime controllers normalize this hint into an internal monotonic
  /// timeline before using it for emitted actions/signals.
  final int timestampMs;
  final PointerPhase phase;
  final PointerDeviceKind kind;
}

/// Thresholds and timings used by routed pointer processing.
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

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PointerInputSettings &&
            tapSlop == other.tapSlop &&
            doubleTapSlop == other.doubleTapSlop &&
            doubleTapMaxDelayMs == other.doubleTapMaxDelayMs &&
            deferSingleTap == other.deferSingleTap;
  }

  @override
  int get hashCode =>
      Object.hash(tapSlop, doubleTapSlop, doubleTapMaxDelayMs, deferSingleTap);
}

/// Validates [PointerInputSettings] values at runtime boundaries.
///
/// Throws [ArgumentError] when any numeric field is non-finite or negative.
void validatePointerInputSettings(PointerInputSettings settings) {
  _requireFiniteNonNegative(settings.tapSlop, name: 'tapSlop');
  _requireFiniteNonNegative(settings.doubleTapSlop, name: 'doubleTapSlop');
  if (settings.doubleTapMaxDelayMs < 0) {
    throw ArgumentError.value(
      settings.doubleTapMaxDelayMs,
      'doubleTapMaxDelayMs',
      'Must be >= 0.',
    );
  }
}

double _requireFiniteNonNegative(double value, {required String name}) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(value, name, 'Must be finite and >= 0.');
  }
  return value;
}
