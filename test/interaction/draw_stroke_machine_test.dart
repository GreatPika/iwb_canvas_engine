import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_contract_limits.dart';
import 'package:iwb_canvas_engine/src/interaction/draw_stroke_machine.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_session.dart';

typedef _StrokeExpectation = ({
  CanvasDrawTool tool,
  List<Offset> points,
  double thickness,
  double opacity,
});

void main() {
  test('pencil and marker start with public stroke preview facts', () {
    expect(_verifyStartStyleSnapshots, returnsNormally);
  });

  test('duplicate samples are silent and terminals can commit same point', () {
    expect(_verifyDuplicateAndSamePointTerminal, returnsNormally);
  });

  test(
    'stroke point cap preserves first point and replaces terminal point',
    () {
      expect(_verifyPointCap, returnsNormally);
    },
  );

  test('non-stroke draw tools are rejected by the stroke machine', () {
    expect(_verifyRejectedTools, returnsNormally);
  });
}

void _verifyStartStyleSnapshots() {
  const machine = DrawStrokeMachine();
  final style = CanvasDrawStyle(
    color: const Color(0xFF123456),
    pencilThickness: 2,
    markerThickness: 9,
    markerOpacity: 0.35,
  );

  final pencil = machine.start(
    tool: CanvasDrawTool.pencil,
    startWorld: const Offset(1, 2),
    style: style,
  );
  final marker = machine.start(
    tool: CanvasDrawTool.marker,
    startWorld: const Offset(3, 4),
    style: style,
  );

  _expectStroke(pencil.stroke, (
    tool: CanvasDrawTool.pencil,
    points: const [Offset(1, 2)],
    thickness: 2,
    opacity: 1,
  ));
  expect(pencil.stroke?.preview, isA<CanvasPencilStrokePreview>());
  _expectStroke(marker.stroke, (
    tool: CanvasDrawTool.marker,
    points: const [Offset(3, 4)],
    thickness: 9,
    opacity: 0.35,
  ));
  expect(marker.stroke?.preview, isA<CanvasMarkerStrokePreview>());
}

void _verifyDuplicateAndSamePointTerminal() {
  const machine = DrawStrokeMachine();
  final stroke =
      machine
              .start(
                tool: CanvasDrawTool.pencil,
                startWorld: Offset.zero,
                style: CanvasDrawStyle.defaultStyle,
              )
              .stroke
          as PointerStrokeCapture;

  final duplicate = machine.preview(stroke: stroke, currentWorld: Offset.zero);
  final terminal = machine.terminal(
    sessionId: const PointerSessionId(1),
    pointerToken: const PointerSessionToken(2),
    stroke: stroke,
    terminalWorld: Offset.zero,
  );

  expect(duplicate.changed, isFalse);
  expect(duplicate.stroke, isNull);
  _expectCommit(
    terminal.intent,
    points: const [Offset.zero],
    tool: CanvasDrawTool.pencil,
  );
}

void _verifyPointCap() {
  const machine = DrawStrokeMachine();
  final stroke = PointerStrokeCapture(
    tool: CanvasDrawTool.marker,
    points: List.generate(
      canvasMaxStrokePointsPerElement,
      (index) => Offset(index.toDouble(), 0),
    ),
    color: const Color(0xFF000000),
    thickness: 3,
    opacity: 0.4,
  );

  final previewStroke = _expectCappedPreview(machine, stroke);
  _expectCappedTerminal(machine, previewStroke);
}

PointerStrokeCapture _expectCappedPreview(
  DrawStrokeMachine machine,
  PointerStrokeCapture stroke,
) {
  final preview = machine.preview(
    stroke: stroke,
    currentWorld: const Offset(999999, 1),
  );
  final previewStroke = preview.stroke as PointerStrokeCapture;

  expect(previewStroke.points, hasLength(canvasMaxStrokePointsPerElement));
  expect(previewStroke.points.first, Offset.zero);
  expect(previewStroke.points.last, const Offset(999999, 1));

  return previewStroke;
}

void _expectCappedTerminal(
  DrawStrokeMachine machine,
  PointerStrokeCapture stroke,
) {
  final terminal = machine.terminal(
    sessionId: const PointerSessionId(1),
    pointerToken: const PointerSessionToken(2),
    stroke: stroke,
    terminalWorld: const Offset(999999, 2),
  );

  expect(terminal.intent.points, hasLength(canvasMaxStrokePointsPerElement));
  expect(terminal.intent.points.first, Offset.zero);
  expect(terminal.intent.points.last, const Offset(999999, 2));
}

void _verifyRejectedTools() {
  const machine = DrawStrokeMachine();

  expect(
    machine
        .start(
          tool: CanvasDrawTool.line,
          startWorld: Offset.zero,
          style: CanvasDrawStyle.defaultStyle,
        )
        .admitted,
    isFalse,
  );
  expect(
    machine
        .start(
          tool: CanvasDrawTool.eraser,
          startWorld: Offset.zero,
          style: CanvasDrawStyle.defaultStyle,
        )
        .stroke,
    isNull,
  );
}

void _expectStroke(PointerStrokeCapture? stroke, _StrokeExpectation expected) {
  final value = stroke as PointerStrokeCapture;
  expect(value.tool, expected.tool);
  expect(value.points, expected.points);
  expect(value.color, const Color(0xFF123456));
  expect(value.thickness, expected.thickness);
  expect(value.opacity, expected.opacity);
}

void _expectCommit(
  DrawStrokeCommitIntent intent, {
  required List<Offset> points,
  required CanvasDrawTool tool,
}) {
  expect(intent.sessionId, const PointerSessionId(1));
  expect(intent.pointerToken, const PointerSessionToken(2));
  expect(intent.tool, tool);
  expect(intent.points, points);
  expect(intent.thickness, CanvasDrawStyle.defaultStyle.pencilThickness);
  expect(intent.opacity, 1);
}
