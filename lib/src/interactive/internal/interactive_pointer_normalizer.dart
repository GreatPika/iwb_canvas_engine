import 'dart:ui';

import '../../contract/canvas_pointer_input.dart';
import '../../contract/pointer_input.dart';
import '../../contract/pointer_phase_codec.dart';
import 'pointer_session_token.dart';

class InteractivePointerNormalizer {
  final Map<_PointerNormalizationKey, Offset> _lastFinitePointerPositionByKey =
      <_PointerNormalizationKey, Offset>{};

  PointerSample? normalize(
    CanvasPointerInput input, {
    required int Function(int? hintTimestampMs) resolveTimestampMs,
    PointerSessionToken? sessionToken,
  }) {
    final key = _PointerNormalizationKey(
      pointerId: input.pointerId,
      sessionToken: sessionToken,
    );
    final phase = pointerPhaseFromCanvasPointerPhase(input.phase);
    final hasFinitePosition = _isFiniteOffset(input.position);
    if (!hasFinitePosition &&
        (phase == PointerPhase.down || phase == PointerPhase.move)) {
      return null;
    }
    final resolvedPosition = hasFinitePosition
        ? input.position
        : _lastFinitePointerPositionByKey[key];
    if (resolvedPosition == null) {
      return null;
    }
    if (hasFinitePosition) {
      _lastFinitePointerPositionByKey[key] = input.position;
    }

    return PointerSample(
      pointerId: input.pointerId,
      position: resolvedPosition,
      timestampMs: resolveTimestampMs(input.timestampMs),
      phase: phase,
      kind: input.kind,
    );
  }

  void release(PointerSample sample, {PointerSessionToken? sessionToken}) {
    if (!_isTerminalPointerPhase(sample.phase)) {
      return;
    }
    _lastFinitePointerPositionByKey.remove(
      _PointerNormalizationKey(
        pointerId: sample.pointerId,
        sessionToken: sessionToken,
      ),
    );
  }

  void detachSession(PointerSessionToken token) {
    _lastFinitePointerPositionByKey.removeWhere(
      (key, _) => key.sessionToken == token,
    );
  }

  void clear() {
    _lastFinitePointerPositionByKey.clear();
  }

  static bool _isFiniteOffset(Offset value) {
    return value.dx.isFinite && value.dy.isFinite;
  }

  static bool _isTerminalPointerPhase(PointerPhase phase) {
    return phase == PointerPhase.up || phase == PointerPhase.cancel;
  }
}

final class _PointerNormalizationKey {
  const _PointerNormalizationKey({
    required this.pointerId,
    required this.sessionToken,
  });

  final int pointerId;
  final PointerSessionToken? sessionToken;

  @override
  bool operator ==(Object other) {
    return other is _PointerNormalizationKey &&
        other.pointerId == pointerId &&
        other.sessionToken == sessionToken;
  }

  @override
  int get hashCode => Object.hash(pointerId, sessionToken);
}
