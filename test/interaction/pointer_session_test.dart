import 'dart:ui';

import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_diagnostics_sink.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_pointer_context.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_read_port.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_cleanup_protocol.dart';
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

  test('routes terminal cleanup input before sample normalization', () {
    expect(_verifyTerminalCleanupInputRouting, returnsNormally);
  });

  test(
    'records cleanup diagnostics without false stale terminal rejection',
    () {
      expect(_verifyTerminalCleanupDiagnostics, returnsNormally);
    },
  );

  test('closes an admitted terminal sample', () {
    expect(_verifyAdmittedTerminalClose, returnsNormally);
  });

  test('preserves and clears pending line by cleanup ownership', () {
    expect(_verifyPendingLineCleanupOwnership, returnsNormally);
  });

  test('dispose clears pending line state', () {
    expect(_verifyDisposeClearsPendingLine, returnsNormally);
  });

  test('eraser session shells forward one mutable capture identity', () {
    expect(_verifyEraserSessionCaptureIdentity, returnsNormally);
  });

  test('exposes output timestamp resolver only through pointer context', () {
    expect(_verifyPointerContextTimestampResolver, returnsNormally);
  });
}

// The engine move route is the owner seam for both published session shells.
// ignore: halstead-volume
void _verifyEraserSessionCaptureIdentity() {
  final engine = InteractionEngine(
    initialMode: CanvasInteractionMode.draw,
    initialDrawStyle: CanvasDrawStyle(
      tool: CanvasDrawTool.eraser,
      eraserThickness: 6,
    ),
    pointerPolicy: CanvasPointerPolicy.defaultPolicy,
  )..attachReadPort(const _PointerSessionReadPort());
  engine.handlePointerSample(
    _sample(1, Offset.zero, CanvasPointerLifecyclePhase.down),
    _context(controllerEpoch: 1),
  );
  final original = engine.activeSession;
  final capture = original?.eraserCapture;
  if (original == null || capture == null) {
    fail('eraser start did not create a session capture');
  }
  final move = engine.handlePointerSample(
    _sample(1, const Offset(2, 3), CanvasPointerLifecyclePhase.move),
    _context(controllerEpoch: 1),
  );
  final updated = engine.activeSession;
  if (updated == null) {
    fail('eraser move did not publish its updated session shell');
  }
  capture.admitPoint(const Offset(4, 5));

  expect(move.kind, InteractionPointerAdmissionKind.admitted);
  expect(updated, isNot(same(original)));
  expect(engine.activeSession, same(updated));
  expect(original.eraserCapture, same(capture));
  expect(updated.eraserCapture, same(capture));
  expect(original.eraserCapture?.points, [
    Offset.zero,
    const Offset(2, 3),
    const Offset(4, 5),
  ]);
  expect(updated.eraserCapture?.points, original.eraserCapture?.points);
  expect(updated.currentWorld, const Offset(2, 3));
  expect(updated.kind, PointerSessionKind.drawEraserPointer);
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
  expect(result.sample, isNotNull);
  expect(session, isNotNull);
  final active = session as PointerSession;
  _expectPointerIdentity(active);
  _expectPointerCapture(active, selected);
  expect(engine.interactionRevision, 0);
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
  final capture = active.selectionCapture;
  expect(capture.selectedIds, selected);
  expect(capture.movableIds, [CanvasElementId('a')]);
  expect(capture.previousIds, selected);
  expect(capture.revision, 9);
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
  expect(engine.interactionRevision, 0);
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
  expect(terminal.sample, isNotNull);
  expect(engine.activeSession, isNull);
  expect(engine.interactionRevision, 0);
}

void _verifyTerminalCleanupInputRouting() {
  _expectSameActiveCleanupInput();
  _expectNoActiveCleanupInput();
  _expectStalePointerCleanupInput();
  _expectStaleEpochCleanupInput();
}

void _expectSameActiveCleanupInput() {
  final engine = _engine()
    ..handlePointerInput(
      _sample(1, Offset.zero, CanvasPointerLifecyclePhase.down),
      _context(controllerEpoch: 1),
    );

  final terminal = engine.handlePointerInput(
    _cleanup(1, CanvasPointerLifecyclePhase.up),
    _context(controllerEpoch: 1),
  );

  expect(terminal.kind, InteractionPointerAdmissionKind.cleanupOnly);
  expect(
    terminal.cleanupDecision?.kind,
    InvalidTerminalCleanupKind.invalidTerminalPosition,
  );
  expect(terminal.sample, isNull);
  expect(engine.activeSession, isNull);
}

void _expectNoActiveCleanupInput() {
  final engine = _engine();

  final terminal = engine.handlePointerInput(
    _cleanup(1, CanvasPointerLifecyclePhase.cancel),
    _context(controllerEpoch: 1),
  );

  expect(terminal.kind, InteractionPointerAdmissionKind.ignored);
  expect(
    terminal.cleanupDecision?.kind,
    InvalidTerminalCleanupKind.noActiveSession,
  );
  expect(terminal.sample, isNull);
  expect(engine.activeSession, isNull);
}

void _expectStalePointerCleanupInput() {
  final engine = _engine()
    ..handlePointerInput(
      _sample(1, Offset.zero, CanvasPointerLifecyclePhase.down),
      _context(controllerEpoch: 1),
    );

  final terminal = engine.handlePointerInput(
    _cleanup(2, CanvasPointerLifecyclePhase.up),
    _context(controllerEpoch: 1),
  );

  expect(terminal.kind, InteractionPointerAdmissionKind.ignored);
  expect(
    terminal.cleanupDecision?.kind,
    InvalidTerminalCleanupKind.stalePointer,
  );
  expect(terminal.sample, isNull);
  expect(engine.activeSession?.pointerId, 1);
}

void _expectStaleEpochCleanupInput() {
  final engine = _engine()
    ..handlePointerInput(
      _sample(1, Offset.zero, CanvasPointerLifecyclePhase.down),
      _context(controllerEpoch: 1),
    );

  final terminal = engine.handlePointerInput(
    _cleanup(1, CanvasPointerLifecyclePhase.cancel),
    _context(controllerEpoch: 2),
  );

  expect(terminal.kind, InteractionPointerAdmissionKind.cleanupOnly);
  expect(
    terminal.cleanupDecision?.kind,
    InvalidTerminalCleanupKind.staleControllerEpoch,
  );
  expect(terminal.sample, isNull);
  expect(engine.activeSession, isNull);
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

  expect(terminal.kind, InteractionPointerAdmissionKind.cleanupOnly);
  expect(terminal.sample, isNotNull);
  expect(engine.activeSession, isNull);
  expect(engine.interactionRevision, 0);
}

void _verifyPendingLineCleanupOwnership() {
  final engine = _engine();
  final stored = _storePendingLine(engine);
  final preview = engine.pendingLinePreview as CanvasPendingLineStartPreview;

  _expectStoredPendingLine(engine, stored, preview);
  _expectInteractiveFalsePreservesPendingLine(engine, preview);
  _expectPreparedLoadClearsPendingLine(engine);
}

void _verifyDisposeClearsPendingLine() {
  final engine = _engine();
  _storePendingLine(engine);

  final cleared = engine.disposeCleanup();

  expect(cleared.disposeBeforeStreamClose, isTrue);
  expect(cleared.pendingLineDisposition, PointerPendingLineDisposition.cleared);
  expect(engine.hasPendingLine, isFalse);
  expect(engine.preview, isA<CanvasNoPreview>());
}

bool _storePendingLine(InteractionEngine engine) {
  return engine.storePendingLineStart(
    preview: const CanvasPendingLineStartPreview(
      start: Offset(2, 3),
      timestampMs: 7,
      color: Color(0xFF112233),
      thickness: 4,
    ),
    controllerEpoch: 1,
  );
}

void _expectStoredPendingLine(
  InteractionEngine engine,
  bool stored,
  CanvasPendingLineStartPreview preview,
) {
  expect(stored, isTrue);
  expect(engine.hasPendingLine, isTrue);
  expect(preview.start, const Offset(2, 3));
  expect(preview.timestampMs, 7);
  expect(engine.preview, isA<CanvasPendingLineStartPreview>());
}

void _expectInteractiveFalsePreservesPendingLine(
  InteractionEngine engine,
  CanvasPendingLineStartPreview preview,
) {
  final preserved = engine.cleanupPointerTool(
    const PointerCleanupRequest(
      reason: PointerCleanupReason.interactiveDisabled,
      activePreviewKind: PointerCleanupPreviewKind.pendingLineStart,
      hasPendingLine: true,
    ),
  );
  expect(preserved.previewChanged, isFalse);
  expect(
    preserved.pendingLineDisposition,
    PointerPendingLineDisposition.preserved,
  );
  expect(engine.hasPendingLine, isTrue);
  _expectPendingLinePreview(engine.preview, preview);
}

void _expectPreparedLoadClearsPendingLine(InteractionEngine engine) {
  final cleared = engine.prepareLoadCleanup();
  expect(cleared.pendingLineDisposition, PointerPendingLineDisposition.cleared);
  expect(engine.hasPendingLine, isFalse);
  expect(engine.preview, isA<CanvasNoPreview>());
}

void _expectPendingLinePreview(
  CanvasPreviewState actual,
  CanvasPendingLineStartPreview expected,
) {
  final pendingLine = actual as CanvasPendingLineStartPreview;
  expect(pendingLine.start, expected.start);
  expect(pendingLine.timestampMs, expected.timestampMs);
  expect(pendingLine.color, expected.color);
  expect(pendingLine.thickness, expected.thickness);
}

void _verifyPointerContextTimestampResolver() {
  final resolvedHints = <int?>[];
  final context = InteractionPointerContext(
    viewCameraOffset: Offset.zero,
    controllerEpoch: 1,
    resolveOutputTimestamp: (timestampHintMs) {
      resolvedHints.add(timestampHintMs);

      return timestampHintMs ?? 0;
    },
  );

  expect(context.resolveOutputTimestamp(null), 0);
  expect(context.resolveOutputTimestamp(12), 12);
  expect(resolvedHints, [null, 12]);
  expect(
    () => _context(controllerEpoch: 1).resolveOutputTimestamp(null),
    throwsStateError,
  );
}

void _verifyTerminalCleanupDiagnostics() {
  final cleanupDiagnostics = _RecordingInteractionDiagnosticsSink();
  final cleanupEngine = _engine(diagnosticsSink: cleanupDiagnostics)
    ..handlePointerInput(
      _sample(1, Offset.zero, CanvasPointerLifecyclePhase.down),
      _context(controllerEpoch: 1),
    );

  cleanupEngine.handlePointerInput(
    _cleanup(1, CanvasPointerLifecyclePhase.cancel),
    _context(controllerEpoch: 1),
  );

  expect(cleanupDiagnostics.invalidTerminalCleanupReasons, [
    'invalidTerminalPosition',
  ]);
  expect(cleanupDiagnostics.staleTerminalRejectedReasons, isEmpty);

  final staleDiagnostics = _RecordingInteractionDiagnosticsSink();
  final staleEngine = _engine(diagnosticsSink: staleDiagnostics)
    ..handlePointerSample(
      _sample(1, Offset.zero, CanvasPointerLifecyclePhase.down),
      _context(controllerEpoch: 1),
    );

  staleEngine.handlePointerSample(
    _sample(1, const Offset(5, 5), CanvasPointerLifecyclePhase.up),
    _context(controllerEpoch: 2),
  );

  expect(staleDiagnostics.invalidTerminalCleanupReasons, [
    'staleControllerEpoch',
  ]);
  expect(staleDiagnostics.staleTerminalRejectedReasons, [
    'staleControllerEpoch',
  ]);
}

InteractionEngine _engine({
  InteractionDiagnosticsSink diagnosticsSink =
      const NoopInteractionDiagnosticsSink(),
}) {
  return InteractionEngine(
    initialMode: CanvasInteractionMode.move,
    initialDrawStyle: CanvasDrawStyle.defaultStyle,
    pointerPolicy: CanvasPointerPolicy.defaultPolicy,
    diagnosticsSink: diagnosticsSink,
  )..attachReadPort(const _PointerSessionReadPort());
}

InteractionPointerContext _context({required int controllerEpoch}) {
  return InteractionPointerContext(
    viewCameraOffset: Offset.zero,
    controllerEpoch: controllerEpoch,
  );
}

// The fake implements the full port so pointer-session tests fail if unrelated
// read paths are accidentally invoked.
// ignore: coupling-between-object-classes, number-of-methods
final class _PointerSessionReadPort implements InteractionReadPort {
  const _PointerSessionReadPort();

  @override
  SelectedMoveStartFacts selectedMoveStartFacts(
    SelectedMoveStartReadRequest request,
  ) {
    return SelectedMoveStartFacts(
      selectedIds: [CanvasElementId('a'), CanvasElementId('b')],
      movableSelectedIds: [CanvasElementId('a')],
      controllerEpoch: 1,
      selectionRevision: 9,
      hitSelectedMovable: true,
    );
  }

  @override
  SelectedMoveCommitFacts selectedMoveCommitFacts(
    SelectedMoveCommitReadRequest request,
  ) {
    return SelectedMoveCommitFacts(
      movableIds: request.sessionMovableIds,
      movedElements: const [],
      documentSummary: const CanvasDocumentSummary(
        elementCount: 0,
        layerCount: 0,
        resourceCount: 0,
      ),
      selectionBoundsWorld: Rect.zero,
      controllerEpoch: request.selectionRevision == 9 ? 1 : 2,
      selectionRevision: request.selectionRevision,
      hasDocumentChangesAvailable: request.sessionMovableIds.isNotEmpty,
    );
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
    return MarqueeCommitFacts(
      previousSelectedIds: const [],
      nextSelectedIds: const [],
      controllerEpoch: 1,
      selectionRevision: 0,
      rectWorld: request.rectWorld,
    );
  }

  @override
  EraserReadFacts eraserTerminalFacts(EraserReadRequest request) {
    throw UnimplementedError('eraser terminal is outside this fixture.');
  }

  @override
  ContextTargetReadOutcome directContextTargetFacts(
    ContextTargetReadRequest request,
  ) {
    return const AdmittedContextTargetRead(
      ContextTargetReadFacts.emptyCanvas(
        controllerEpoch: 1,
        documentRevision: 0,
      ),
    );
  }

  @override
  ContextTargetReadOutcome pendingContextTapFacts(
    ContextTargetReadRequest request,
  ) {
    return directContextTargetFacts(request);
  }

  @override
  ContextTargetReadOutcome secondContextTapFacts(
    ContextTargetReadRequest request,
  ) {
    return directContextTargetFacts(request);
  }

  @override
  TextCommitGuardReadFacts textCommitGuardFacts(
    TextCommitGuardReadRequest request,
  ) {
    return TextCommitGuardReadFacts.missing(
      targetElementId: request.targetElementId,
      controllerEpoch: 1,
      documentRevision: 0,
    );
  }
}

final class _RecordingInteractionDiagnosticsSink
    implements InteractionDiagnosticsSink {
  final invalidTerminalCleanupReasons = <String>[];
  final staleTerminalRejectedReasons = <String>[];

  @override
  void recordHitTestFallbackObserved({
    required String reason,
    required int? budget,
    required int? observed,
  }) => _discardDiagnosticEvent();

  @override
  void recordInteractionQueryBudgetExceeded({
    required String reason,
    required int? budget,
    required int? observed,
  }) => _discardDiagnosticEvent();

  @override
  void recordInvalidTerminalCleanup({required String reason}) {
    invalidTerminalCleanupReasons.add(reason);
  }

  @override
  void recordResolverReentrantMutationRejected({required String operation}) =>
      _discardDiagnosticEvent();

  @override
  void recordResolverCallbackFailed({
    required String operation,
    required String errorKind,
  }) => _discardDiagnosticEvent();

  @override
  void recordSelectedMoveStartDeniedNotMovable({
    required int selectedCount,
    required int movableCount,
  }) => _discardDiagnosticEvent();

  @override
  void recordStaleCandidateRejected({
    required String reason,
    required int? expectedRevision,
    required int? observedRevision,
    required int skippedCandidateCount,
  }) => _discardDiagnosticEvent();

  @override
  void recordStaleTerminalRejected({required String reason}) {
    staleTerminalRejectedReasons.add(reason);
  }
}

int _discardDiagnosticEvent() => 0;

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

CanvasPointerTerminalCleanup _cleanup(
  int pointerId,
  CanvasPointerLifecyclePhase phase,
) {
  return CanvasPointerTerminalCleanup(
    pointerId: pointerId,
    phase: phase,
    kind: PointerDeviceKind.touch,
  );
}
