import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/eraser_machine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_pointer_context.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_read_port.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_sample_normalizer.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_session.dart';

typedef _ContextTapInput = ({
  Offset position,
  Offset? movePosition,
  Offset? terminalPosition,
  int? timestampMs,
});

void main() {
  _registerEraserTests();
  _registerContextTapTests();
}

void _registerEraserTests() {
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

void _registerContextTapTests() {
  test(
    'context tap stores pending history and emits on matching second tap',
    () {
      expect(_verifyContextTapPendingAndSecondTap, returnsNormally);
    },
  );

  test('context tap accepts move jitter inside tap slop', () {
    expect(_verifyContextTapMoveJitter, returnsNormally);
  });

  test('context tap accepts terminal jitter inside tap slop', () {
    expect(_verifyContextTapTerminalJitter, returnsNormally);
  });

  test('context tap mismatch clears pending without request', () {
    expect(_verifyContextTapMismatchCleanup, returnsNormally);
  });

  test('context tap missing timestamps cannot match', () {
    expect(_verifyContextTapMissingTimestampsCleanup, returnsNormally);
  });

  test('orphan terminal taps cannot request context actions', () {
    expect(_verifyOrphanTerminalsDoNotRequestContextAction, returnsNormally);
  });

  test('direct double tap clears pending before target read', () {
    expect(_verifyDirectDoubleTapCleanupBeforeTargetRead, returnsNormally);
  });

  test('direct double tap preserves active preview while clearing pending', () {
    expect(_verifyDirectDoubleTapPreservesActivePreview, returnsNormally);
  });

  test('non-finite direct double tap performs no read or timestamp', () {
    expect(_verifyNonFiniteDirectDoubleTapIsSilent, returnsNormally);
  });
  _registerRejectedContextTapTests();
}

void _registerRejectedContextTapTests() {
  test('rejected direct context read issues no request or timestamp', () {
    expect(_verifyRejectedDirectContextReadIsSilent, returnsNormally);
  });

  test('rejected first context tap stores no pending state', () {
    expect(_verifyRejectedFirstContextTapStoresNoPending, returnsNormally);
  });

  test('rejected second context tap clears pending without request', () {
    expect(_verifyRejectedSecondContextTapClearsPending, returnsNormally);
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

void _verifyContextTapPendingAndSecondTap() {
  final readPort = _FakeReadPort(contextElementId: CanvasElementId('ctx-a'));
  final engine = _contextEngine(readPort);

  final first = _tapContext(engine, _contextTap(const Offset(10, 10)));
  expect(first.kind, InteractionPointerAdmissionKind.ignored);
  expect(engine.pendingContextTap, isNotNull);

  final second = _tapContext(engine, _contextTap(const Offset(12, 10)));

  final request = second.contextRequest?.request;
  expect(request, isNotNull);
  expect(request?.requestId, CanvasInteractionRequestId('request-0'));
  expect(request?.target, isA<CanvasContentElementContextActionTarget>());
  expect(
    engine.requestFactsFor(CanvasInteractionRequestId('request-0')),
    isNotNull,
  );
  expect(readPort.pendingContextReads, 1);
  expect(readPort.secondContextReads, 1);
}

void _verifyContextTapMoveJitter() {
  final readPort = _FakeReadPort(contextElementId: CanvasElementId('ctx-a'));
  final engine = _contextEngine(readPort);

  final first = _tapContext(
    engine,
    _contextTap(const Offset(10, 10), movePosition: const Offset(11, 10)),
  );
  final second = _tapContext(
    engine,
    _contextTap(const Offset(12, 10), movePosition: const Offset(13, 10)),
  );

  expect(first.kind, InteractionPointerAdmissionKind.ignored);
  expect(
    second.contextRequest?.request.requestId,
    (CanvasInteractionRequestId('request-0')),
  );
  expect(readPort.pendingContextReads, 1);
  expect(readPort.secondContextReads, 1);
}

void _verifyContextTapTerminalJitter() {
  final readPort = _FakeReadPort(contextElementId: CanvasElementId('ctx-a'));
  final engine = _contextEngine(readPort);

  final first = _tapContext(
    engine,
    _contextTap(const Offset(10, 10), terminalPosition: const Offset(11, 10)),
  );
  final second = _tapContext(
    engine,
    _contextTap(const Offset(12, 10), terminalPosition: const Offset(13, 10)),
  );

  expect(first.kind, InteractionPointerAdmissionKind.ignored);
  expect(
    second.contextRequest?.request.requestId,
    CanvasInteractionRequestId('request-0'),
  );
  expect(readPort.pendingContextReads, 1);
  expect(readPort.secondContextReads, 1);
}

void _verifyContextTapMismatchCleanup() {
  final readPort = _FakeReadPort(
    contextElementId: CanvasElementId('ctx-a'),
    secondContextElementId: CanvasElementId('ctx-b'),
  );
  final engine = _contextEngine(readPort);

  _tapContext(engine, _contextTap(const Offset(10, 10)));
  final second = _tapContext(engine, _contextTap(const Offset(40, 10)));

  expect(second.kind, InteractionPointerAdmissionKind.cleanupOnly);
  expect(second.contextRequest, isNull);
  expect(engine.pendingContextTap, isNull);
}

void _verifyContextTapMissingTimestampsCleanup() {
  final readPort = _FakeReadPort(contextElementId: CanvasElementId('ctx-a'));
  final engine = _contextEngine(readPort);

  final first = _tapContext(
    engine,
    _contextTap(const Offset(10, 10), timestampMs: null),
  );
  final second = _tapContext(
    engine,
    _contextTap(const Offset(12, 10), timestampMs: null),
  );

  expect(first.kind, InteractionPointerAdmissionKind.ignored);
  expect(second.kind, InteractionPointerAdmissionKind.cleanupOnly);
  expect(second.contextRequest, isNull);
  expect(engine.pendingContextTap, isNull);
  expect(readPort.pendingContextReads, 1);
  expect(readPort.secondContextReads, 1);
}

void _verifyOrphanTerminalsDoNotRequestContextAction() {
  final readPort = _FakeReadPort(contextElementId: CanvasElementId('ctx-a'));
  final engine = _contextEngine(readPort);

  final first = engine.handlePointerSample(
    _sample(1, const Offset(10, 10), CanvasPointerLifecyclePhase.up),
    _context(1),
  );
  final second = engine.handlePointerSample(
    _sample(1, const Offset(12, 10), CanvasPointerLifecyclePhase.up),
    _context(1),
  );

  expect(first.kind, InteractionPointerAdmissionKind.ignored);
  expect(second.kind, InteractionPointerAdmissionKind.ignored);
  expect(second.contextRequest, isNull);
  expect(engine.pendingContextTap, isNull);
  expect(readPort.pendingContextReads, 0);
  expect(readPort.secondContextReads, 0);
}

void _verifyDirectDoubleTapCleanupBeforeTargetRead() {
  final readPort = _FakeReadPort(contextElementId: CanvasElementId('ctx-a'));
  final engine = _contextEngine(readPort);
  var timestampReads = 0;
  _tapContext(engine, _contextTap(const Offset(10, 10)));
  readPort.onDirectContextRead = () {
    expect(engine.pendingContextTap, isNull);
    expect(timestampReads, 0);
  };

  final request = engine.handleDoubleTap(
    const Offset(10, 10),
    InteractionPointerContext(
      viewCameraOffset: Offset.zero,
      controllerEpoch: 1,
      resolveOutputTimestamp: (hint) {
        timestampReads += 1;

        return hint ?? 0;
      },
    ),
    timestampHintMs: 5,
  );

  expect(request?.request.timestampMs, 5);
  expect(timestampReads, 1);
  expect(readPort.directContextReads, 1);
}

void _verifyDirectDoubleTapPreservesActivePreview() {
  final readPort = _FakeReadPort(contextElementId: CanvasElementId('ctx-a'));
  final engine = _contextEngine(readPort);
  _tapContext(engine, _contextTap(const Offset(10, 10)));
  engine
    ..setMode(CanvasInteractionMode.draw, cleanupSelectionMode: false)
    ..handlePointerSample(
      _sample(1, const Offset(1, 1), CanvasPointerLifecyclePhase.down),
      _context(1),
    );
  readPort.onDirectContextRead = () {
    expect(engine.pendingContextTap, isNull);
    expect(engine.activeSession, isNotNull);
    expect(engine.preview, isA<CanvasPencilStrokePreview>());
  };

  final request = engine.handleDoubleTap(
    const Offset(10, 10),
    _context(1),
    timestampHintMs: 5,
  );

  expect(request, isNotNull);
  expect(engine.activeSession, isNotNull);
  expect(engine.preview, isA<CanvasPencilStrokePreview>());
}

void _verifyNonFiniteDirectDoubleTapIsSilent() {
  var timestampReads = 0;
  final readPort = _FakeReadPort(contextElementId: CanvasElementId('ctx-a'));
  final engine = _contextEngine(readPort);

  final request = engine.handleDoubleTap(
    const Offset(double.nan, 10),
    InteractionPointerContext(
      viewCameraOffset: Offset.zero,
      controllerEpoch: 1,
      resolveOutputTimestamp: (hint) {
        timestampReads += 1;

        return hint ?? 0;
      },
    ),
    timestampHintMs: 5,
  );

  expect(request, isNull);
  expect(timestampReads, 0);
  expect(readPort.directContextReads, 0);
}

void _verifyRejectedDirectContextReadIsSilent() {
  var timestampReads = 0;
  final readPort = _FakeReadPort(
    contextOutcome: const RejectedContextTargetRead(
      query: InteractionReadQueryFacts.invalidIndex(
        invalidIndexReason: InteractionReadInvalidIndexReason.rebuildNeeded,
      ),
    ),
  );
  final engine = _contextEngine(readPort);

  final request = engine.handleDoubleTap(
    const Offset(10, 10),
    InteractionPointerContext(
      viewCameraOffset: Offset.zero,
      controllerEpoch: 1,
      resolveOutputTimestamp: (hint) {
        timestampReads += 1;

        return hint ?? 0;
      },
    ),
    timestampHintMs: 5,
  );

  expect(request, isNull);
  expect(timestampReads, 0);
  expect(readPort.directContextReads, 1);
  expect(
    engine.requestFactsFor(CanvasInteractionRequestId('request-0')),
    isNull,
  );
}

void _verifyRejectedFirstContextTapStoresNoPending() {
  var timestampReads = 0;
  final readPort = _FakeReadPort(
    contextOutcome: const RejectedContextTargetRead(
      query: InteractionReadQueryFacts.staleIndex(
        expectedStructuralRevision: 2,
        observedStructuralRevision: 1,
      ),
    ),
  );
  final engine = _contextEngine(readPort);

  final first = _tapContext(
    engine,
    _contextTap(const Offset(10, 10)),
    context: _contextWithTimestampCounter(
      epoch: 1,
      onRead: () {
        timestampReads += 1;
      },
    ),
  );

  expect(first.kind, InteractionPointerAdmissionKind.ignored);
  expect(first.contextRequest, isNull);
  expect(engine.pendingContextTap, isNull);
  expect(timestampReads, 0);
  expect(readPort.pendingContextReads, 1);
}

void _verifyRejectedSecondContextTapClearsPending() {
  var timestampReads = 0;
  final readPort = _FakeReadPort(contextElementId: CanvasElementId('ctx-a'));
  final engine = _contextEngine(readPort);

  _tapContext(engine, _contextTap(const Offset(10, 10)));
  expect(engine.pendingContextTap, isNotNull);
  readPort.secondContextOutcome = _budgetRejectedContextTarget();

  final second = _tapContext(
    engine,
    _contextTap(const Offset(12, 10)),
    context: _contextWithTimestampCounter(
      epoch: 1,
      onRead: () {
        timestampReads += 1;
      },
    ),
  );

  expect(second.kind, InteractionPointerAdmissionKind.cleanupOnly);
  expect(second.contextRequest, isNull);
  expect(engine.pendingContextTap, isNull);
  expect(timestampReads, 0);
  expect(readPort.pendingContextReads, 1);
  expect(readPort.secondContextReads, 1);
  expect(
    engine.requestFactsFor(CanvasInteractionRequestId('request-0')),
    isNull,
  );
}

ContextTargetReadOutcome _budgetRejectedContextTarget() {
  return const RejectedContextTargetRead(
    query: InteractionReadQueryFacts.budgetExceeded(
      budgetExceededReason:
          InteractionReadBudgetExceededReason.queryTileBudgetExceeded,
      budget: 1,
      observed: 2,
    ),
  );
}

InteractionPointerAdmission _tapContext(
  InteractionEngine engine,
  _ContextTapInput input, {
  InteractionPointerContext? context,
}) {
  final pointerContext = context ?? _context(1);
  engine.handlePointerSample(
    _sample(
      1,
      input.position,
      CanvasPointerLifecyclePhase.down,
      timestampMs: input.timestampMs,
    ),
    pointerContext,
  );
  final moved = input.movePosition;
  if (moved != null) {
    engine.handlePointerSample(
      _sample(
        1,
        moved,
        CanvasPointerLifecyclePhase.move,
        timestampMs: input.timestampMs,
      ),
      pointerContext,
    );
  }

  return engine.handlePointerSample(
    _sample(
      1,
      input.terminalPosition ?? input.movePosition ?? input.position,
      CanvasPointerLifecyclePhase.up,
      timestampMs: input.timestampMs,
    ),
    pointerContext,
  );
}

_ContextTapInput _contextTap(
  Offset position, {
  Offset? movePosition,
  Offset? terminalPosition,
  int? timestampMs = 1,
}) {
  return (
    position: position,
    movePosition: movePosition,
    terminalPosition: terminalPosition,
    timestampMs: timestampMs,
  );
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

InteractionEngine _contextEngine(_FakeReadPort readPort) {
  return InteractionEngine(
    initialMode: CanvasInteractionMode.move,
    initialDrawStyle: CanvasDrawStyle.defaultStyle,
    pointerPolicy: CanvasPointerPolicy.defaultPolicy,
  )..attachReadPort(readPort);
}

InteractionPointerContext _context(int epoch) {
  return InteractionPointerContext(
    viewCameraOffset: Offset.zero,
    controllerEpoch: epoch,
    resolveOutputTimestamp: (hint) => hint ?? 0,
  );
}

InteractionPointerContext _contextWithTimestampCounter({
  required int epoch,
  required void Function() onRead,
}) {
  return InteractionPointerContext(
    viewCameraOffset: Offset.zero,
    controllerEpoch: epoch,
    resolveOutputTimestamp: (hint) {
      onRead();

      return hint ?? 0;
    },
  );
}

CanvasPointerSample _sample(
  int pointerId,
  Offset position,
  CanvasPointerLifecyclePhase phase, {
  int? timestampMs,
}) {
  return CanvasPointerSample(
    pointerId: pointerId,
    position: position,
    phase: phase,
    kind: PointerDeviceKind.touch,
    timestampMs: timestampMs,
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
  _FakeReadPort({
    this.erasedIds = const [],
    this.contextElementId,
    this.secondContextElementId,
    ContextTargetReadOutcome? contextOutcome,
  }) : contextOutcome = contextOutcome ?? _contextOutcome(contextElementId);

  final Iterable<CanvasElementId> erasedIds;
  final CanvasElementId? contextElementId;
  final CanvasElementId? secondContextElementId;
  final ContextTargetReadOutcome contextOutcome;
  ContextTargetReadOutcome? secondContextOutcome;
  var _previewReads = 0;
  var _terminalReads = 0;
  var _directContextReads = 0;
  var _pendingContextReads = 0;
  var _secondContextReads = 0;
  void Function()? onDirectContextRead;

  int get previewReadCount => _previewReads;
  int get terminalReadCount => _terminalReads;
  int get directContextReads => _directContextReads;
  int get pendingContextReads => _pendingContextReads;
  int get secondContextReads => _secondContextReads;

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
  ContextTargetReadOutcome directContextTargetFacts(
    ContextTargetReadRequest request,
  ) {
    _directContextReads += 1;
    onDirectContextRead?.call();

    return contextOutcome;
  }

  @override
  ContextTargetReadOutcome pendingContextTapFacts(
    ContextTargetReadRequest request,
  ) {
    _pendingContextReads += 1;

    return contextOutcome;
  }

  @override
  ContextTargetReadOutcome secondContextTapFacts(
    ContextTargetReadRequest request,
  ) {
    _secondContextReads += 1;

    return secondContextOutcome ??
        _contextOutcome(secondContextElementId ?? contextElementId);
  }

  @override
  TextCommitGuardReadFacts textCommitGuardFacts(
    TextCommitGuardReadRequest request,
  ) {
    throw UnimplementedError('text guard is outside this fixture.');
  }
}

ContextTargetReadOutcome _contextOutcome(CanvasElementId? id) {
  if (id == null) {
    return const AdmittedContextTargetRead(
      ContextTargetReadFacts.emptyCanvas(
        controllerEpoch: 1,
        documentRevision: 0,
      ),
    );
  }

  return AdmittedContextTargetRead(
    ContextTargetReadFacts.contentElement(
      elementId: id,
      elementKind: CanvasElementKind.rect,
      elementSnapshot: CanvasRectElement(id: id, size: const Size(10, 10)),
      boundsWorld: const Rect.fromLTWH(10, 10, 10, 10),
      generation: 1,
      elementRevision: 0,
      family: InteractionElementFamily.rect,
      controllerEpoch: 1,
      documentRevision: 0,
    ),
  );
}
