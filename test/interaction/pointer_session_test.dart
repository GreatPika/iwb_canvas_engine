import 'dart:ui';

import 'package:iwb_canvas_engine/src/contracts/public/canvas_ids.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_pointer.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_tools.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_sample_normalizer.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admits one routed pointer and captures session facts', () {
    expect(_verifyPointerAdmission, returnsNormally);
  });

  test('ignores a second down and stale non-terminal samples', () {
    expect(_verifyStaleNonTerminalHandling, returnsNormally);
  });

  test('turns stale terminal epoch into cleanup-only decision', () {
    expect(_verifyStaleTerminalCleanup, returnsNormally);
  });

  test('closes an admitted terminal sample', () {
    expect(_verifyAdmittedTerminalClose, returnsNormally);
  });
}

void _verifyPointerAdmission() {
  final engine = _engine();
  final selected = [CanvasElementId('a'), CanvasElementId('b')];

  final result = engine.handlePointerSample(
    _sample(1, const Offset(4, 5), CanvasPointerLifecyclePhase.down),
    InteractionPointerContext(
      viewCameraOffset: const Offset(10, -2),
      controllerEpoch: 3,
      selectedIds: selected,
      movableIds: [CanvasElementId('a')],
      previousSelectionIds: selected,
      selectionRevision: 9,
    ),
  );

  final session = engine.activeSession;
  expect(result.kind, InteractionPointerAdmissionKind.admitted);
  expect(session, isNotNull);
  final active = session as PointerSession;
  _expectPointerIdentity(active);
  _expectPointerCapture(active, selected);
  expect(engine.interactionRevision, 1);
}

void _expectPointerIdentity(PointerSession active) {
  expect(active.kind, PointerSessionKind.moveModePointer);
  expect(active.pointerId, 1);
  expect(active.controllerEpoch.value, 3);
  expect(active.sessionId.value, 1);
  expect(active.token.value, 1);
  expect(active.startWorld, const Offset(14, 3));
  expect(active.currentWorld, const Offset(14, 3));
}

void _expectPointerCapture(
  PointerSession active,
  List<CanvasElementId> selected,
) {
  expect(active.capturedSelectedIds, selected);
  expect(active.capturedMovableIds, [CanvasElementId('a')]);
  expect(active.previousSelectionIds, selected);
  expect(active.capturedSelectionRevision, 9);
}

void _verifyStaleNonTerminalHandling() {
  final engine = _engine()
    ..handlePointerSample(
      _sample(1, Offset.zero, CanvasPointerLifecyclePhase.down),
      _context(controllerEpoch: 1),
    );

  final secondDown = engine.handlePointerSample(
    _sample(2, const Offset(1, 1), CanvasPointerLifecyclePhase.down),
    _context(controllerEpoch: 1),
  );
  final staleMove = engine.handlePointerSample(
    _sample(1, const Offset(2, 2), CanvasPointerLifecyclePhase.move),
    _context(controllerEpoch: 2),
  );

  final active = engine.activeSession;
  expect(secondDown.kind, InteractionPointerAdmissionKind.ignored);
  expect(staleMove.kind, InteractionPointerAdmissionKind.ignored);
  expect(active?.pointerId, 1);
  expect(active?.currentWorld, Offset.zero);
  expect(engine.interactionRevision, 1);
}

void _verifyStaleTerminalCleanup() {
  final engine = _engine()
    ..handlePointerSample(
      _sample(1, Offset.zero, CanvasPointerLifecyclePhase.down),
      _context(controllerEpoch: 1),
    );

  final terminal = engine.handlePointerSample(
    _sample(1, const Offset(5, 5), CanvasPointerLifecyclePhase.up),
    _context(controllerEpoch: 2),
  );

  expect(terminal.kind, InteractionPointerAdmissionKind.cleanupOnly);
  expect(
    terminal.cleanupDecision?.kind,
    InvalidTerminalCleanupKind.staleControllerEpoch,
  );
  expect(engine.activeSession, isNull);
  expect(engine.interactionRevision, 2);
}

void _verifyAdmittedTerminalClose() {
  final engine = _engine()
    ..handlePointerSample(
      _sample(1, Offset.zero, CanvasPointerLifecyclePhase.down),
      _context(controllerEpoch: 1),
    );

  final terminal = engine.handlePointerSample(
    _sample(1, const Offset(5, 5), CanvasPointerLifecyclePhase.cancel),
    _context(controllerEpoch: 1),
  );

  expect(terminal.kind, InteractionPointerAdmissionKind.admitted);
  expect(engine.activeSession, isNull);
  expect(engine.interactionRevision, 2);
}

InteractionEngine _engine() {
  return InteractionEngine(
    initialMode: CanvasInteractionMode.move,
    initialDrawStyle: CanvasDrawStyle.defaultStyle,
    pointerPolicy: CanvasPointerPolicy.defaultPolicy,
  );
}

InteractionPointerContext _context({required int controllerEpoch}) {
  return InteractionPointerContext(
    viewCameraOffset: Offset.zero,
    controllerEpoch: controllerEpoch,
  );
}

CanvasPointerSample _sample(
  int pointerId,
  Offset position,
  CanvasPointerLifecyclePhase phase,
) {
  return CanvasPointerSample(
    pointerId: pointerId,
    position: position,
    phase: phase,
    kind: PointerDeviceKind.touch,
  );
}
