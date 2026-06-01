import 'dart:ui';

import 'package:iwb_canvas_engine/src/contracts/public/canvas_pointer.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_sample_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes public pointer samples into world space', () {
    expect(_verifyPublicSampleNormalization, returnsNormally);
  });

  test('classifies internal invalid terminal cleanup decisions', () {
    expect(_verifyInvalidTerminalDecisions, returnsNormally);
  });
}

void _verifyPublicSampleNormalization() {
  const normalizer = PointerSampleNormalizer();
  final sample = CanvasPointerSample(
    pointerId: 7,
    position: const Offset(10, 20),
    phase: CanvasPointerLifecyclePhase.move,
    kind: PointerDeviceKind.mouse,
    timestampMs: 42,
  );

  final normalized = normalizer.normalizePublicSample(
    sample,
    viewCameraOffset: const Offset(3, -5),
    controllerEpoch: 11,
  );

  expect(normalized.pointerId, 7);
  expect(normalized.viewPosition, const Offset(10, 20));
  expect(normalized.worldPosition, const Offset(13, 15));
  expect(normalized.phase, CanvasPointerLifecyclePhase.move);
  expect(normalized.kind, PointerDeviceKind.mouse);
  expect(normalized.timestampMs, 42);
  expect(normalized.controllerEpoch, 11);
}

void _verifyInvalidTerminalDecisions() {
  const normalizer = PointerSampleNormalizer();

  expect(
    normalizer
        .invalidTerminalCleanupDecision(
          activePointerId: null,
          activeControllerEpoch: null,
          terminalPointerId: 1,
          terminalControllerEpoch: 1,
        )
        .kind,
    InvalidTerminalCleanupKind.noActiveSession,
  );
  expect(
    normalizer
        .invalidTerminalCleanupDecision(
          activePointerId: 1,
          activeControllerEpoch: 1,
          terminalPointerId: 2,
          terminalControllerEpoch: 1,
        )
        .shouldCleanupActiveSession,
    isFalse,
  );
  final staleEpoch = normalizer.invalidTerminalCleanupDecision(
    activePointerId: 1,
    activeControllerEpoch: 1,
    terminalPointerId: 1,
    terminalControllerEpoch: 2,
  );

  expect(staleEpoch.kind, InvalidTerminalCleanupKind.staleControllerEpoch);
  expect(staleEpoch.shouldCleanupActiveSession, isTrue);
}
