import 'dart:ui';

import '../contracts/public/canvas_pointer.dart';

final class NormalizedPointerSample {
  const NormalizedPointerSample({
    required this.pointerId,
    required this.viewPosition,
    required this.worldPosition,
    required this.phase,
    required this.kind,
    required this.timestampMs,
    required this.controllerEpoch,
  });

  final int pointerId;
  final Offset viewPosition;
  final Offset worldPosition;
  final CanvasPointerLifecyclePhase phase;
  final PointerDeviceKind kind;
  final int? timestampMs;
  final int controllerEpoch;
}

enum InvalidTerminalCleanupKind {
  none,
  invalidTerminalPosition,
  noActiveSession,
  stalePointer,
  staleControllerEpoch,
}

final class InvalidTerminalCleanupDecision {
  const InvalidTerminalCleanupDecision({
    required this.kind,
    required this.shouldCleanupActiveSession,
  });

  final InvalidTerminalCleanupKind kind;
  final bool shouldCleanupActiveSession;
}

final class PointerSampleNormalizer {
  const PointerSampleNormalizer();

  NormalizedPointerSample normalizePublicSample(
    CanvasPointerSample sample, {
    required Offset viewCameraOffset,
    required int controllerEpoch,
  }) {
    return NormalizedPointerSample(
      pointerId: sample.pointerId,
      viewPosition: sample.position,
      worldPosition: sample.position + viewCameraOffset,
      phase: sample.phase,
      kind: sample.kind,
      timestampMs: sample.timestampMs,
      controllerEpoch: controllerEpoch,
    );
  }

  InvalidTerminalCleanupDecision invalidTerminalCleanupDecision({
    required int? activePointerId,
    required int? activeControllerEpoch,
    required int terminalPointerId,
    required int terminalControllerEpoch,
  }) {
    if (activePointerId == null || activeControllerEpoch == null) {
      return const InvalidTerminalCleanupDecision(
        kind: InvalidTerminalCleanupKind.noActiveSession,
        shouldCleanupActiveSession: false,
      );
    }
    if (activePointerId != terminalPointerId) {
      return const InvalidTerminalCleanupDecision(
        kind: InvalidTerminalCleanupKind.stalePointer,
        shouldCleanupActiveSession: false,
      );
    }
    if (activeControllerEpoch != terminalControllerEpoch) {
      return const InvalidTerminalCleanupDecision(
        kind: InvalidTerminalCleanupKind.staleControllerEpoch,
        shouldCleanupActiveSession: true,
      );
    }

    return const InvalidTerminalCleanupDecision(
      kind: InvalidTerminalCleanupKind.none,
      shouldCleanupActiveSession: false,
    );
  }

  InvalidTerminalCleanupDecision terminalCleanupInputDecision({
    required int? activePointerId,
    required int? activeControllerEpoch,
    required int terminalPointerId,
    required int terminalControllerEpoch,
  }) {
    final decision = invalidTerminalCleanupDecision(
      activePointerId: activePointerId,
      activeControllerEpoch: activeControllerEpoch,
      terminalPointerId: terminalPointerId,
      terminalControllerEpoch: terminalControllerEpoch,
    );
    if (decision.kind != InvalidTerminalCleanupKind.none) {
      return decision;
    }

    return const InvalidTerminalCleanupDecision(
      kind: InvalidTerminalCleanupKind.invalidTerminalPosition,
      shouldCleanupActiveSession: true,
    );
  }
}
