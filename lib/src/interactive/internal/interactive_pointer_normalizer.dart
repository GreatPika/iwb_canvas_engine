import 'dart:ui';

import '../../contract/canvas_pointer_input.dart';
import '../../contract/pointer_phase_codec.dart';
import '../../core/pointer_input.dart';

class InteractivePointerNormalizer {
  final Map<int, Offset> _lastFinitePointerPositionById = <int, Offset>{};

  PointerSample? normalize(
    CanvasPointerInput input, {
    required int Function(int? hintTimestampMs) resolveTimestampMs,
  }) {
    final phase = pointerPhaseFromCanvasPointerPhase(input.phase);
    final hasFinitePosition = _isFiniteOffset(input.position);
    if (!hasFinitePosition &&
        (phase == PointerPhase.down || phase == PointerPhase.move)) {
      return null;
    }
    final resolvedPosition = hasFinitePosition
        ? input.position
        : _lastFinitePointerPositionById[input.pointerId];
    if (resolvedPosition == null) {
      return null;
    }
    if (hasFinitePosition) {
      _lastFinitePointerPositionById[input.pointerId] = input.position;
    }

    return PointerSample(
      pointerId: input.pointerId,
      position: resolvedPosition,
      timestampMs: resolveTimestampMs(input.timestampMs),
      phase: phase,
      kind: input.kind,
    );
  }

  void release(PointerSample sample) {
    if (!_isTerminalPointerPhase(sample.phase)) {
      return;
    }
    _lastFinitePointerPositionById.remove(sample.pointerId);
  }

  void clear() {
    _lastFinitePointerPositionById.clear();
  }

  static bool _isFiniteOffset(Offset value) {
    return value.dx.isFinite && value.dy.isFinite;
  }

  static bool _isTerminalPointerPhase(PointerPhase phase) {
    return phase == PointerPhase.up || phase == PointerPhase.cancel;
  }
}
