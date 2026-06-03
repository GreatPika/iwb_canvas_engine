import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_pointer_context.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_runtime_intents.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_sample_normalizer.dart';

typedef _StrokeCommitExpectation = ({
  CanvasDrawTool tool,
  List<Offset> points,
  double thickness,
  double opacity,
});

void main() {
  test('pencil stroke publishes preview only and returns commit intent', () {
    expect(_verifyPencilStrokeLifecycle, returnsNormally);
  });

  test('marker stroke shares lifecycle with marker style facts', () {
    expect(_verifyMarkerStrokeLifecycle, returnsNormally);
  });

  test('second pointer down is ignored during active stroke', () {
    expect(_verifySecondPointerIgnored, returnsNormally);
  });

  test('cancel and stale terminal cleanup produce no stroke commit', () {
    expect(_verifyRejectedTerminals, returnsNormally);
  });

  test('rejected stroke terminals do not resolve output timestamps', () {
    expect(_verifyRejectedTerminalsDoNotResolveTimestamps, returnsNormally);
  });
}

void _verifyPencilStrokeLifecycle() {
  final engine = _engine(
    CanvasDrawStyle(color: const Color(0xFFAA0000), pencilThickness: 5),
  );

  final down = _handle(engine, CanvasPointerLifecyclePhase.down, Offset.zero);
  final move = _handle(
    engine,
    CanvasPointerLifecyclePhase.move,
    const Offset(2, 3),
  );
  final terminal = _handle(
    engine,
    CanvasPointerLifecyclePhase.up,
    const Offset(4, 5),
  );

  expect(down.kind, InteractionPointerAdmissionKind.admitted);
  expect(move.kind, InteractionPointerAdmissionKind.admitted);
  expect(engine.previewRevision, 2);
  expect(engine.interactionRevision, 0);
  _expectPencilPreview(engine.preview);
  _expectStrokeCommit(terminal.strokeCommit, (
    tool: CanvasDrawTool.pencil,
    points: const [Offset.zero, Offset(2, 3), Offset(4, 5)],
    thickness: 5,
    opacity: 1,
  ));
}

void _verifyMarkerStrokeLifecycle() {
  final engine = _engine(
    CanvasDrawStyle(
      tool: CanvasDrawTool.marker,
      color: const Color(0xFF00AA00),
      markerThickness: 11,
      markerOpacity: 0.25,
    ),
  );

  engine.handlePointerSample(
    _sample(1, const Offset(1, 1), CanvasPointerLifecyclePhase.down),
    _context(1),
  );
  final terminal = engine.handlePointerSample(
    _sample(1, const Offset(1, 1), CanvasPointerLifecyclePhase.up),
    _context(1),
  );

  expect(engine.preview, isA<CanvasMarkerStrokePreview>());
  _expectStrokeCommit(terminal.strokeCommit, (
    tool: CanvasDrawTool.marker,
    points: const [Offset(1, 1)],
    thickness: 11,
    opacity: 0.25,
  ));
}

void _verifySecondPointerIgnored() {
  final engine = _engine(
    CanvasDrawStyle(color: const Color(0xFFAA0000), pencilThickness: 5),
  );

  engine.handlePointerSample(
    _sample(1, Offset.zero, CanvasPointerLifecyclePhase.down),
    _context(1),
  );
  final second = engine.handlePointerSample(
    _sample(2, const Offset(9, 9), CanvasPointerLifecyclePhase.down),
    _context(1),
  );

  expect(second.kind, InteractionPointerAdmissionKind.ignored);
  expect(engine.activeSession?.pointerId, 1);
  _expectPencilPreview(engine.preview, points: const [Offset.zero]);
}

void _verifyRejectedTerminals() {
  _expectCancelCleanup();
  _expectStaleTerminalCleanup();
}

void _verifyRejectedTerminalsDoNotResolveTimestamps() {
  final resolvedHints = <int?>[];

  _expectCancelCleanup(resolvedHints: resolvedHints);
  _expectStaleTerminalCleanup(resolvedHints: resolvedHints);
  _expectNoActiveTerminalIgnored(resolvedHints);

  expect(resolvedHints, isEmpty);
}

void _expectCancelCleanup({List<int?>? resolvedHints}) {
  final cancelEngine = _engine(CanvasDrawStyle.defaultStyle)
    ..handlePointerSample(
      _sample(1, Offset.zero, CanvasPointerLifecyclePhase.down),
      _context(1, resolvedHints: resolvedHints),
    );
  final cancel = cancelEngine.handlePointerSample(
    _sample(1, const Offset(2, 2), CanvasPointerLifecyclePhase.cancel),
    _context(1, resolvedHints: resolvedHints),
  );
  expect(cancel.strokeCommit, isNull);
  expect(cancel.kind, InteractionPointerAdmissionKind.cleanupOnly);
  expect(cancelEngine.activeSession, isNull);
  expect(cancelEngine.preview, isA<CanvasNoPreview>());
}

void _expectStaleTerminalCleanup({List<int?>? resolvedHints}) {
  final staleEngine = _engine(CanvasDrawStyle.defaultStyle)
    ..handlePointerSample(
      _sample(1, Offset.zero, CanvasPointerLifecyclePhase.down),
      _context(1, resolvedHints: resolvedHints),
    );
  final stale = staleEngine.handlePointerSample(
    _sample(1, const Offset(2, 2), CanvasPointerLifecyclePhase.up),
    _context(2, resolvedHints: resolvedHints),
  );
  expect(stale.strokeCommit, isNull);
  expect(
    stale.cleanupDecision?.kind,
    InvalidTerminalCleanupKind.staleControllerEpoch,
  );
  expect(staleEngine.activeSession, isNull);
}

void _expectNoActiveTerminalIgnored(List<int?> resolvedHints) {
  final engine = _engine(CanvasDrawStyle.defaultStyle);

  final terminal = engine.handlePointerSample(
    _sample(1, const Offset(2, 2), CanvasPointerLifecyclePhase.up),
    _context(1, resolvedHints: resolvedHints),
  );

  expect(terminal.kind, InteractionPointerAdmissionKind.ignored);
  expect(terminal.strokeCommit, isNull);
}

InteractionPointerAdmission _handle(
  InteractionEngine engine,
  CanvasPointerLifecyclePhase phase,
  Offset position,
) {
  return engine.handlePointerSample(_sample(1, position, phase), _context(1));
}

InteractionEngine _engine(CanvasDrawStyle style) {
  return InteractionEngine(
    initialMode: CanvasInteractionMode.draw,
    initialDrawStyle: style,
    pointerPolicy: CanvasPointerPolicy.defaultPolicy,
  );
}

InteractionPointerContext _context(int epoch, {List<int?>? resolvedHints}) {
  return InteractionPointerContext(
    viewCameraOffset: Offset.zero,
    controllerEpoch: epoch,
    resolveOutputTimestamp: resolvedHints == null
        ? null
        : (timestampHintMs) {
            resolvedHints.add(timestampHintMs);

            return timestampHintMs ?? 0;
          },
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

void _expectPencilPreview(
  CanvasPreviewState preview, {
  List<Offset> points = const [Offset.zero, Offset(2, 3)],
}) {
  final pencil = preview as CanvasPencilStrokePreview;
  expect(pencil.points, points);
  expect(pencil.color, const Color(0xFFAA0000));
  expect(pencil.thickness, 5);
  expect(pencil.opacity, 1);
}

void _expectStrokeCommit(
  DrawStrokeCommitIntent? intent,
  _StrokeCommitExpectation expected,
) {
  final commit = intent as DrawStrokeCommitIntent;
  expect(commit.tool, expected.tool);
  expect(commit.points, expected.points);
  expect(commit.thickness, expected.thickness);
  expect(commit.opacity, expected.opacity);
}
