import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/eraser_machine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_pointer_context.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_read_port.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_sample_normalizer.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_session.dart';

void main() {
  test('eraser machine captures preview and commit decisions', () {
    expect(_verifyEraserMachineDecisions, returnsNormally);
  });

  test('interaction routes draw eraser through eraser machine', () {
    expect(_verifyEraserInteractionRouting, returnsNormally);
  });

  test('eraser stale terminal cleanup produces no commit intent', () {
    expect(_verifyEraserStaleTerminalCleanup, returnsNormally);
  });

  test('draw stroke machine still rejects eraser', () {
    expect(_verifyDrawStrokeRejectsEraserSession, returnsNormally);
  });
}

// The machine assertions stay together to prove capture, preview, immutability,
// and commit-intent fields on the same eraser transition sequence.
// ignore: halstead-volume
void _verifyEraserMachineDecisions() {
  const machine = EraserMachine();
  final start = machine.start(
    tool: CanvasDrawTool.eraser,
    startWorld: Offset.zero,
    style: CanvasDrawStyle.defaultStyle,
  );
  final eraser = start.eraser as PointerEraserCapture;

  final preview = machine.preview(
    eraser: eraser,
    currentWorld: const Offset(2, 3),
    facts: _eraserFacts(
      corridor: const [Offset.zero, Offset(2, 3)],
      erasedIds: const [],
    ),
  );
  final terminal = machine.terminal(
    sessionId: const PointerSessionId(1),
    pointerToken: const PointerSessionToken(2),
    eraser: preview.eraser as PointerEraserCapture,
    facts: _eraserFacts(
      corridor: const [Offset.zero, Offset(2, 3), Offset(4, 5)],
      erasedIds: [CanvasElementId('a')],
    ),
  );

  final eraserPreview = preview.preview as CanvasEraserPreview;
  final intent = terminal.intent as EraserCommitIntent;
  expect(eraser.points, [Offset.zero]);
  expect(eraser.thickness, CanvasDrawStyle.defaultStyle.eraserThickness);
  expect(eraserPreview.corridor, [Offset.zero, const Offset(2, 3)]);
  expect(() => eraserPreview.corridor.clear(), throwsUnsupportedError);
  expect(intent.erasedElementIds, [CanvasElementId('a')]);
  expect(intent.eraserThickness, eraser.thickness);
  expect(intent.corridorPointCount, 3);
}

// The routing assertions stay together to prove session capture, preview reads,
// terminal reads, and admission handoff for one public pointer sequence.
// ignore: halstead-volume
void _verifyEraserInteractionRouting() {
  final readPort = _FakeReadPort(erasedIds: [CanvasElementId('erasable-a')]);
  final engine = _eraserEngine(readPort);

  final down = engine.handlePointerSample(
    _sample(1, Offset.zero, CanvasPointerLifecyclePhase.down),
    _context(1),
  );
  final move = engine.handlePointerSample(
    _sample(1, const Offset(2, 3), CanvasPointerLifecyclePhase.move),
    _context(1),
  );
  final terminal = engine.handlePointerSample(
    _sample(1, const Offset(4, 5), CanvasPointerLifecyclePhase.up),
    _context(1),
  );

  expect(down.kind, InteractionPointerAdmissionKind.admitted);
  expect(move.kind, InteractionPointerAdmissionKind.admitted);
  expect(engine.activeSession?.kind, PointerSessionKind.drawEraserPointer);
  expect(engine.activeSession?.eraserCapture?.points, [
    Offset.zero,
    const Offset(2, 3),
  ]);
  expect(engine.preview, isA<CanvasEraserPreview>());
  final intent = terminal.eraserCommit as EraserCommitIntent;
  expect(intent.erasedElementIds, [CanvasElementId('erasable-a')]);
  expect(intent.corridorPointCount, 3);
  expect(terminal.strokeCommit, isNull);
  expect(readPort.previewReadCount, 2);
  expect(readPort.terminalReadCount, 1);
}

void _verifyEraserStaleTerminalCleanup() {
  final engine = _eraserEngine(_FakeReadPort())
    ..handlePointerSample(
      _sample(1, Offset.zero, CanvasPointerLifecyclePhase.down),
      _context(1),
    );

  final terminal = engine.handlePointerSample(
    _sample(1, const Offset(2, 3), CanvasPointerLifecyclePhase.up),
    _context(2),
  );

  expect(terminal.kind, InteractionPointerAdmissionKind.cleanupOnly);
  expect(
    terminal.cleanupDecision?.kind,
    InvalidTerminalCleanupKind.staleControllerEpoch,
  );
  expect(terminal.eraserCommit, isNull);
  expect(engine.activeSession, isNull);
  expect(engine.preview, isA<CanvasNoPreview>());
}

void _verifyDrawStrokeRejectsEraserSession() {
  final engine = _eraserEngine(_FakeReadPort());
  engine.handlePointerSample(
    _sample(1, Offset.zero, CanvasPointerLifecyclePhase.down),
    _context(1),
  );

  expect(engine.activeSession?.strokeCapture, isNull);
  expect(engine.activeSession?.eraserCapture, isA<PointerEraserCapture>());
}

InteractionEngine _eraserEngine(_FakeReadPort readPort) {
  return InteractionEngine(
    initialMode: CanvasInteractionMode.draw,
    initialDrawStyle: CanvasDrawStyle(
      tool: CanvasDrawTool.eraser,
      eraserThickness: 7,
    ),
    pointerPolicy: CanvasPointerPolicy.defaultPolicy,
  )..attachReadPort(readPort);
}

InteractionPointerContext _context(int epoch) {
  return InteractionPointerContext(
    viewCameraOffset: Offset.zero,
    controllerEpoch: epoch,
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

EraserReadFacts _eraserFacts({
  required Iterable<Offset> corridor,
  required Iterable<CanvasElementId> erasedIds,
  bool exactBudgetExceeded = false,
}) {
  return EraserReadFacts(
    corridorPoints: corridor,
    erasedElementIds: erasedIds,
    eraserThickness: 7,
    controllerEpoch: 1,
    documentRevision: 0,
    exactCheckCount: erasedIds.length,
    exactBudgetExceeded: exactBudgetExceeded,
    query: InteractionReadQueryFacts.candidates(
      candidateCount: erasedIds.length,
      skippedCandidateCount: 0,
    ),
  );
}

// The fake implements the full port so the eraser routing test can prove unused
// interaction read paths are not reached.
// ignore: coupling-between-object-classes, number-of-methods
final class _FakeReadPort implements InteractionReadPort {
  _FakeReadPort({this.erasedIds = const []});

  final Iterable<CanvasElementId> erasedIds;
  var _previewReads = 0;
  var _terminalReads = 0;

  int get previewReadCount => _previewReads;
  int get terminalReadCount => _terminalReads;

  @override
  EraserReadFacts eraserPreviewFacts(EraserReadRequest request) {
    _previewReads += 1;

    return _eraserFacts(corridor: request.corridorPoints, erasedIds: const []);
  }

  @override
  EraserReadFacts eraserTerminalFacts(EraserReadRequest request) {
    _terminalReads += 1;

    return _eraserFacts(corridor: request.corridorPoints, erasedIds: erasedIds);
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
