import 'dart:ui' show Offset, PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/eraser_machine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_pointer_context.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_read_port.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_session.dart';

void main() {
  test('preview budget overflow keeps corridor-only preview', () {
    expect(_verifyPreviewOverflowCorridorOnly, returnsNormally);
  });

  test('terminal budget overflow produces no partial commit intent', () {
    expect(_verifyTerminalOverflowNoPartialCommit, returnsNormally);
  });

  test('terminal budget overflow is cleanup-only through interaction', () {
    expect(_verifyTerminalOverflowInteractionCleanup, returnsNormally);
  });
}

void _verifyPreviewOverflowCorridorOnly() {
  const machine = EraserMachine();
  final eraser = PointerEraserCapture(points: [Offset.zero], thickness: 6);

  final preview = machine.preview(
    eraser: eraser,
    currentWorld: const Offset(10, 0),
    facts: _facts(
      corridor: const [Offset.zero, Offset(10, 0)],
      erasedIds: [CanvasElementId('would-be-partial')],
      exactBudgetExceeded: true,
    ),
  );

  final eraserPreview = preview.preview as CanvasEraserPreview;
  expect(preview.exactBudgetExceeded, isTrue);
  expect(eraserPreview.corridor, const [Offset.zero, Offset(10, 0)]);
  expect(eraserPreview.thickness, 6);
}

void _verifyTerminalOverflowNoPartialCommit() {
  const machine = EraserMachine();
  final eraser = PointerEraserCapture(points: [Offset.zero], thickness: 6);

  final terminal = machine.terminal(
    sessionId: const PointerSessionId(1),
    pointerToken: const PointerSessionToken(2),
    eraser: eraser,
    facts: _facts(
      corridor: const [Offset.zero, Offset(10, 0)],
      erasedIds: [CanvasElementId('would-be-partial')],
      exactBudgetExceeded: true,
    ),
  );

  expect(terminal.intent, isNull);
}

void _verifyTerminalOverflowInteractionCleanup() {
  final engine = InteractionEngine(
    initialMode: CanvasInteractionMode.draw,
    initialDrawStyle: CanvasDrawStyle(
      tool: CanvasDrawTool.eraser,
      eraserThickness: 6,
    ),
    pointerPolicy: CanvasPointerPolicy.defaultPolicy,
  )..attachReadPort(_BudgetOverflowReadPort());

  engine.handlePointerSample(
    _sample(CanvasPointerLifecyclePhase.down, Offset.zero),
    _context(),
  );
  engine.handlePointerSample(
    _sample(CanvasPointerLifecyclePhase.move, const Offset(10, 0)),
    _context(),
  );
  final terminal = engine.handlePointerSample(
    _sample(CanvasPointerLifecyclePhase.up, const Offset(20, 0)),
    _context(),
  );

  expect(terminal.kind, InteractionPointerAdmissionKind.cleanupOnly);
  expect(terminal.eraserCommit, isNull);
  expect(terminal.strokeCommit, isNull);
  expect(engine.activeSession, isNull);
  expect(engine.preview, isA<CanvasNoPreview>());
}

EraserReadFacts _facts({
  required Iterable<Offset> corridor,
  required Iterable<CanvasElementId> erasedIds,
  required bool exactBudgetExceeded,
}) {
  return EraserReadFacts(
    corridorPoints: corridor,
    erasedElementIds: erasedIds,
    eraserThickness: 6,
    controllerEpoch: 1,
    documentRevision: 0,
    exactCheckCount: 1,
    exactBudgetExceeded: exactBudgetExceeded,
  );
}

CanvasPointerSample _sample(
  CanvasPointerLifecyclePhase phase,
  Offset position,
) {
  return CanvasPointerSample(
    pointerId: 1,
    position: position,
    phase: phase,
    kind: PointerDeviceKind.touch,
  );
}

InteractionPointerContext _context() {
  return InteractionPointerContext(
    viewCameraOffset: Offset.zero,
    controllerEpoch: 1,
  );
}

// The fake implements the full port so the overflow routing test proves only
// eraser read paths are used by the interaction engine.
// ignore: coupling-between-object-classes
final class _BudgetOverflowReadPort implements InteractionReadPort {
  @override
  EraserReadFacts eraserPreviewFacts(EraserReadRequest request) {
    return _facts(
      corridor: request.corridorPoints,
      erasedIds: const [],
      exactBudgetExceeded: false,
    );
  }

  @override
  EraserReadFacts eraserTerminalFacts(EraserReadRequest request) {
    return _facts(
      corridor: request.corridorPoints,
      erasedIds: [CanvasElementId('would-be-partial')],
      exactBudgetExceeded: true,
    );
  }

  @override
  SelectedMoveStartFacts selectedMoveStartFacts(
    SelectedMoveStartReadRequest request,
  ) {
    return SelectedMoveStartFacts(
      selectedIds: const [],
      movableSelectedIds: const [],
      controllerEpoch: 1,
      selectionRevision: 0,
      hitSelectedMovable: false,
    );
  }

  @override
  SelectedMoveCommitFacts selectedMoveCommitFacts(
    SelectedMoveCommitReadRequest request,
  ) {
    throw UnimplementedError('selected move is outside this fixture.');
  }

  @override
  MarqueeStartFacts marqueeStartFacts(MarqueeStartReadRequest request) {
    return MarqueeStartFacts(
      previousSelectedIds: const [],
      controllerEpoch: 1,
      selectionRevision: 0,
    );
  }

  @override
  MarqueeCommitFacts marqueeCommitFacts(MarqueeCommitReadRequest request) {
    throw UnimplementedError('marquee is outside this fixture.');
  }

  @override
  ContextTargetReadFacts directContextTargetFacts(
    ContextTargetReadRequest request,
  ) {
    throw UnimplementedError('context target is outside this fixture.');
  }

  @override
  ContextTargetReadFacts pendingContextTapFacts(
    ContextTargetReadRequest request,
  ) {
    throw UnimplementedError('context target is outside this fixture.');
  }

  @override
  ContextTargetReadFacts secondContextTapFacts(
    ContextTargetReadRequest request,
  ) {
    throw UnimplementedError('context target is outside this fixture.');
  }

  @override
  TextCommitGuardReadFacts textCommitGuardFacts(
    TextCommitGuardReadRequest request,
  ) {
    throw UnimplementedError('text guard is outside this fixture.');
  }
}
