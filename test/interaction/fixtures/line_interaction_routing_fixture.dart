import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_pointer_context.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_runtime_intents.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_sample_normalizer.dart';

void main() {
  test('first tap stores timestamped pending line preview', () {
    expect(_verifyFirstTapStoresPendingPreview, returnsNormally);
  });

  test('rejected first tap paths do not reserve timestamps', () {
    expect(_verifyRejectedFirstTapTimestampSilence, returnsNormally);
  });

  test('endpoint preview and terminal return line commit intent', () {
    expect(_verifyEndpointLifecycle, returnsNormally);
  });

  test('first pointer drag previews and commits a line', () {
    expect(_verifyFirstPointerDragLifecycle, returnsNormally);
  });

  test('first pointer line drag starts after dragStartSlop', () {
    expect(_verifyFirstPointerDragUsesDragStartSlop, returnsNormally);
  });

  test('same-point endpoint returns line commit intent', () {
    expect(_verifySamePointEndpointCommit, returnsNormally);
  });

  test(
    'endpoint invalid stale and cancel cleanup respect pending ownership',
    () {
      expect(_verifyEndpointCleanup, returnsNormally);
    },
  );
}

void _verifyFirstTapStoresPendingPreview() {
  final timestamps = <int?>[];
  final engine = _engine();

  final down = engine.handlePointerSample(
    _sample(1, const Offset(2, 3), CanvasPointerLifecyclePhase.down),
    _context(1, timestamps),
  );
  final terminal = engine.handlePointerSample(
    _sample(1, const Offset(3, 3), CanvasPointerLifecyclePhase.up, 17),
    _context(1, timestamps),
  );

  _expectAdmittedWithSample(down);
  _expectAdmittedWithSample(terminal);
  expect(timestamps, [17]);
  expect(engine.activeSession, isNull);
  final pending = engine.preview as CanvasPendingLineStartPreview;
  expect(pending.start, const Offset(2, 3));
  expect(pending.timestampMs, 17);
  expect(pending.color, const Color(0xFF112233));
  expect(pending.thickness, 6);
  expect(engine.hasPendingLine, isTrue);
}

void _verifyRejectedFirstTapTimestampSilence() {
  final timestamps = <int?>[];
  final engine = _engine();

  final rejected = _outsideSlopFirstTap(engine, timestamps);
  _cancelFirstTap(engine, timestamps);
  final stale = _staleFirstTap(engine, timestamps);
  final invalid = _invalidFirstTap(engine, timestamps);
  final accepted = _acceptedFirstTap(engine, timestamps);

  expect(rejected.kind, InteractionPointerAdmissionKind.cleanupOnly);
  expect(stale.kind, InteractionPointerAdmissionKind.cleanupOnly);
  expect(invalid.kind, InteractionPointerAdmissionKind.cleanupOnly);
  expect(accepted.kind, InteractionPointerAdmissionKind.admitted);
  expect(timestamps, [14]);
  final pending = engine.pendingLinePreview as CanvasPendingLineStartPreview;
  expect(pending.timestampMs, 14);
}

InteractionPointerAdmission _outsideSlopFirstTap(
  InteractionEngine engine,
  List<int?> timestamps,
) {
  engine.handlePointerSample(
    _sample(1, Offset.zero, CanvasPointerLifecyclePhase.down),
    _context(1, timestamps),
  );

  return engine.handlePointerSample(
    _sample(1, const Offset(6, 0), CanvasPointerLifecyclePhase.up, 11),
    _context(1, timestamps),
  );
}

void _cancelFirstTap(InteractionEngine engine, List<int?> timestamps) {
  engine.handlePointerSample(
    _sample(2, const Offset(1, 1), CanvasPointerLifecyclePhase.down),
    _context(1, timestamps),
  );
  engine.handlePointerSample(
    _sample(2, const Offset(1, 1), CanvasPointerLifecyclePhase.cancel, 12),
    _context(1, timestamps),
  );
}

InteractionPointerAdmission _staleFirstTap(
  InteractionEngine engine,
  List<int?> timestamps,
) {
  engine.handlePointerSample(
    _sample(3, const Offset(2, 2), CanvasPointerLifecyclePhase.down),
    _context(1, timestamps),
  );

  return engine.handlePointerSample(
    _sample(3, const Offset(2, 2), CanvasPointerLifecyclePhase.up, 13),
    _context(2, timestamps),
  );
}

InteractionPointerAdmission _invalidFirstTap(
  InteractionEngine engine,
  List<int?> timestamps,
) {
  engine.handlePointerSample(
    _sample(5, const Offset(5, 5), CanvasPointerLifecyclePhase.down),
    _context(1, timestamps),
  );

  return engine.handlePointerSample(
    _sample(6, const Offset(5, 5), CanvasPointerLifecyclePhase.up, 15),
    _context(1, timestamps),
  );
}

InteractionPointerAdmission _acceptedFirstTap(
  InteractionEngine engine,
  List<int?> timestamps,
) {
  engine.handlePointerSample(
    _sample(4, const Offset(3, 3), CanvasPointerLifecyclePhase.down),
    _context(1, timestamps),
  );

  return engine.handlePointerSample(
    _sample(4, const Offset(3, 3), CanvasPointerLifecyclePhase.up, 14),
    _context(1, timestamps),
  );
}

void _verifyEndpointLifecycle() {
  final timestamps = <int?>[];
  final engine = _engineWithPendingLine();

  final down = _handleEndpointDown(engine, timestamps);
  final move = _handleEndpointMove(engine, timestamps);
  final terminal = _handleEndpointUp(engine, timestamps);

  _expectAdmittedWithSample(down);
  _expectAdmittedWithSample(move);
  _expectAdmittedWithSample(terminal);
  _expectLinePreview(engine.preview, end: const Offset(6, 7));
  _expectLineCommit(terminal.lineCommit);
  expect(timestamps, isEmpty);
  expect(engine.hasPendingLine, isTrue);
}

void _verifyFirstPointerDragLifecycle() {
  final timestamps = <int?>[];
  final engine = _engine();

  final down = engine.handlePointerSample(
    _sample(1, const Offset(2, 3), CanvasPointerLifecyclePhase.down),
    _context(1, timestamps),
  );
  final move = engine.handlePointerSample(
    _sample(1, const Offset(9, 11), CanvasPointerLifecyclePhase.move),
    _context(1, timestamps),
  );
  final preview = engine.preview as CanvasLinePreview;
  final terminal = engine.handlePointerSample(
    _sample(1, const Offset(12, 13), CanvasPointerLifecyclePhase.up),
    _context(1, timestamps),
  );

  expect(down.kind, InteractionPointerAdmissionKind.admitted);
  expect(move.kind, InteractionPointerAdmissionKind.admitted);
  _expectDragStartLinePreview(preview);
  _expectDragStartLineCommit(terminal.lineCommit);
  expect(timestamps, isEmpty);
  expect(engine.hasPendingLine, isFalse);
}

void _verifyFirstPointerDragUsesDragStartSlop() {
  final timestamps = <int?>[];
  final engine = _engine(
    pointerPolicy: CanvasPointerPolicy(tapSlop: 8, dragStartSlop: 2),
  );

  engine.handlePointerSample(
    _sample(1, Offset.zero, CanvasPointerLifecyclePhase.down),
    _context(1, timestamps),
  );
  final belowDragSlop = engine.handlePointerSample(
    _sample(1, const Offset(2, 0), CanvasPointerLifecyclePhase.move),
    _context(1, timestamps),
  );
  final aboveDragSlop = engine.handlePointerSample(
    _sample(1, const Offset(3, 0), CanvasPointerLifecyclePhase.move),
    _context(1, timestamps),
  );

  expect(belowDragSlop.kind, InteractionPointerAdmissionKind.ignored);
  expect(aboveDragSlop.kind, InteractionPointerAdmissionKind.admitted);
  final preview = engine.preview as CanvasLinePreview;
  expect(preview.start, Offset.zero);
  expect(preview.end, const Offset(3, 0));
}

void _expectDragStartLinePreview(CanvasLinePreview preview) {
  expect(preview.start, const Offset(2, 3));
  expect(preview.end, const Offset(9, 11));
  expect(preview.color, const Color(0xFF112233));
  expect(preview.thickness, 6);
}

void _expectDragStartLineCommit(DrawLineCommitIntent? intent) {
  final commit = intent as DrawLineCommitIntent;
  expect(commit.startWorld, const Offset(2, 3));
  expect(commit.endWorld, const Offset(12, 13));
  expect(commit.color, const Color(0xFF112233));
  expect(commit.thickness, 6);
}

void _verifySamePointEndpointCommit() {
  final timestamps = <int?>[];
  final engine = _engineWithPendingLine();

  final down = _handleEndpointDown(engine, timestamps);
  final terminal = engine.handlePointerSample(
    _sample(1, const Offset(4, 5), CanvasPointerLifecyclePhase.up),
    _context(1, timestamps),
  );

  expect(down.kind, InteractionPointerAdmissionKind.admitted);
  final commit = terminal.lineCommit as DrawLineCommitIntent;
  expect(commit.startWorld, const Offset(1, 1));
  expect(commit.endWorld, const Offset(4, 5));
  expect(timestamps, isEmpty);
}

InteractionPointerAdmission _handleEndpointDown(
  InteractionEngine engine,
  List<int?> timestamps,
) {
  return engine.handlePointerSample(
    _sample(1, const Offset(4, 5), CanvasPointerLifecyclePhase.down),
    _context(1, timestamps),
  );
}

InteractionPointerAdmission _handleEndpointMove(
  InteractionEngine engine,
  List<int?> timestamps,
) {
  return engine.handlePointerSample(
    _sample(1, const Offset(6, 7), CanvasPointerLifecyclePhase.move),
    _context(1, timestamps),
  );
}

InteractionPointerAdmission _handleEndpointUp(
  InteractionEngine engine,
  List<int?> timestamps,
) {
  return engine.handlePointerSample(
    _sample(1, const Offset(8, 9), CanvasPointerLifecyclePhase.up),
    _context(1, timestamps),
  );
}

void _verifyEndpointCleanup() {
  _expectEndpointCancelClearsPendingLine();
  _expectEndpointStaleTerminalClearsPendingLine();
  _expectEndpointStaleCleanupInputClearsPendingLine();
  _expectEndpointInvalidTerminalClearsPendingLine();
  _expectNoActiveTerminalPreservesPendingLine();
}

void _expectEndpointCancelClearsPendingLine() {
  final engine = _engineWithPendingLine();
  engine.handlePointerSample(
    _sample(1, const Offset(4, 5), CanvasPointerLifecyclePhase.down),
    _context(1, []),
  );
  final cancel = engine.handlePointerSample(
    _sample(1, const Offset(4, 5), CanvasPointerLifecyclePhase.cancel),
    _context(1, []),
  );

  expect(cancel.kind, InteractionPointerAdmissionKind.cleanupOnly);
  expect(cancel.lineCommit, isNull);
  expect(engine.hasPendingLine, isFalse);
  expect(engine.preview, isA<CanvasNoPreview>());
}

void _expectEndpointInvalidTerminalClearsPendingLine() {
  final timestamps = <int?>[];
  final engine = _engineWithPendingLine();
  _handleEndpointDown(engine, timestamps);
  final invalid = engine.handlePointerSample(
    _sample(2, const Offset(4, 5), CanvasPointerLifecyclePhase.up),
    _context(1, timestamps),
  );

  expect(invalid.kind, InteractionPointerAdmissionKind.cleanupOnly);
  expect(invalid.lineCommit, isNull);
  expect(timestamps, isEmpty);
  expect(engine.hasPendingLine, isFalse);
  expect(engine.preview, isA<CanvasNoPreview>());
}

void _expectNoActiveTerminalPreservesPendingLine() {
  final timestamps = <int?>[];
  final engine = _engineWithPendingLine();
  final terminal = engine.handlePointerSample(
    _sample(1, const Offset(4, 5), CanvasPointerLifecyclePhase.up),
    _context(1, timestamps),
  );

  expect(terminal.kind, InteractionPointerAdmissionKind.ignored);
  expect(terminal.lineCommit, isNull);
  expect(timestamps, isEmpty);
  expect(engine.hasPendingLine, isTrue);
  expect(engine.preview, isA<CanvasPendingLineStartPreview>());
}

void _expectEndpointStaleTerminalClearsPendingLine() {
  final engine = _engineWithPendingLine();
  engine.handlePointerSample(
    _sample(1, const Offset(4, 5), CanvasPointerLifecyclePhase.down),
    _context(1, []),
  );
  final stale = engine.handlePointerSample(
    _sample(1, const Offset(4, 5), CanvasPointerLifecyclePhase.up),
    _context(2, []),
  );

  expect(stale.kind, InteractionPointerAdmissionKind.cleanupOnly);
  expect(stale.lineCommit, isNull);
  expect(engine.hasPendingLine, isFalse);
  expect(engine.preview, isA<CanvasNoPreview>());
}

void _expectEndpointStaleCleanupInputClearsPendingLine() {
  final engine = _engineWithPendingLine();
  engine.handlePointerSample(
    _sample(1, const Offset(4, 5), CanvasPointerLifecyclePhase.down),
    _context(1, []),
  );
  final stale = engine.handlePointerInput(
    _cleanup(2, CanvasPointerLifecyclePhase.up),
    _context(1, []),
  );

  expect(stale.kind, InteractionPointerAdmissionKind.cleanupOnly);
  expect(stale.cleanupDecision?.kind, InvalidTerminalCleanupKind.stalePointer);
  expect(stale.sample, isNull);
  expect(stale.lineCommit, isNull);
  expect(engine.hasPendingLine, isFalse);
  expect(engine.preview, isA<CanvasNoPreview>());
}

InteractionEngine _engineWithPendingLine() {
  return _engine()..storePendingLineStart(
    preview: const CanvasPendingLineStartPreview(
      start: Offset(1, 1),
      timestampMs: 9,
      color: Color(0xFF445566),
      thickness: 7,
    ),
    controllerEpoch: 1,
  );
}

InteractionEngine _engine({CanvasPointerPolicy? pointerPolicy}) {
  return InteractionEngine(
    initialMode: CanvasInteractionMode.draw,
    initialDrawStyle: CanvasDrawStyle(
      tool: CanvasDrawTool.line,
      color: const Color(0xFF112233),
      lineThickness: 6,
    ),
    pointerPolicy: pointerPolicy ?? CanvasPointerPolicy(tapSlop: 5),
  );
}

InteractionPointerContext _context(int epoch, List<int?> timestamps) {
  return InteractionPointerContext(
    viewCameraOffset: Offset.zero,
    controllerEpoch: epoch,
    resolveOutputTimestamp: (timestampHintMs) {
      timestamps.add(timestampHintMs);

      return timestampHintMs ?? 0;
    },
  );
}

CanvasPointerSample _sample(
  int pointerId,
  Offset position,
  CanvasPointerLifecyclePhase phase, [
  int? timestampMs,
]) {
  return CanvasPointerSample(
    pointerId: pointerId,
    position: position,
    phase: phase,
    kind: PointerDeviceKind.touch,
    timestampMs: timestampMs,
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

void _expectLinePreview(CanvasPreviewState preview, {required Offset end}) {
  final line = preview as CanvasLinePreview;
  expect(line.start, const Offset(1, 1));
  expect(line.end, end);
  expect(line.color, const Color(0xFF445566));
  expect(line.thickness, 7);
}

void _expectLineCommit(DrawLineCommitIntent? intent) {
  final commit = intent as DrawLineCommitIntent;
  expect(commit.startWorld, const Offset(1, 1));
  expect(commit.endWorld, const Offset(8, 9));
  expect(commit.color, const Color(0xFF445566));
  expect(commit.thickness, 7);
  expect(commit.opacity, 1);
}

void _expectAdmittedWithSample(InteractionPointerAdmission admission) {
  expect(admission.kind, InteractionPointerAdmissionKind.admitted);
  expect(admission.sample, isNotNull);
}
