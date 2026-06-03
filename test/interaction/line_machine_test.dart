import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_runtime_intents.dart';
import 'package:iwb_canvas_engine/src/interaction/line_machine.dart';

void main() {
  test('line first tap snapshots style and rejects non-line tools', () {
    expect(_verifyFirstTapStart, returnsNormally);
  });

  test('tap slop accepts only bounded first taps', () {
    expect(_verifyFirstTapTerminal, returnsNormally);
  });

  test('endpoint preview and terminal carry line facts', () {
    expect(_verifyEndpointLifecycle, returnsNormally);
  });

  test('same-point endpoint returns a line commit intent', () {
    expect(_verifySamePointEndpointCommit, returnsNormally);
  });
}

void _verifyFirstTapStart() {
  const machine = LineMachine();
  final style = CanvasDrawStyle(
    tool: CanvasDrawTool.line,
    color: const Color(0xFF123456),
    lineThickness: 6,
  );

  final start = machine.startFirstTap(
    tool: CanvasDrawTool.line,
    startWorld: const Offset(1, 2),
    style: style,
  );
  final rejected = machine.startFirstTap(
    tool: CanvasDrawTool.pencil,
    startWorld: Offset.zero,
    style: CanvasDrawStyle.defaultStyle,
  );

  final firstTap = start.firstTap as PointerLineFirstTapCapture;
  expect(start.admitted, isTrue);
  expect(firstTap.startWorld, const Offset(1, 2));
  expect(firstTap.color, const Color(0xFF123456));
  expect(firstTap.thickness, 6);
  expect(rejected.admitted, isFalse);
  expect(rejected.firstTap, isNull);
}

void _verifyFirstTapTerminal() {
  const machine = LineMachine();
  const firstTap = PointerLineFirstTapCapture(
    startWorld: Offset.zero,
    color: Color(0xFF000000),
    thickness: 3,
  );

  final accepted = machine.firstTapTerminal(
    firstTap: firstTap,
    terminalWorld: const Offset(3, 4),
    tapSlop: 5,
  );
  final rejected = machine.firstTapTerminal(
    firstTap: firstTap,
    terminalWorld: const Offset(5, 1),
    tapSlop: 5,
  );

  expect(accepted.accepted, isTrue);
  expect(accepted.startWorld, Offset.zero);
  expect(accepted.color, const Color(0xFF000000));
  expect(accepted.thickness, 3);
  expect(rejected.accepted, isFalse);
}

void _verifyEndpointLifecycle() {
  const machine = LineMachine();
  final start = _endpointStart(machine);
  final changed = _expectEndpointPreview(machine, start.line);
  _expectEndpointTerminal(machine, changed.line as PointerLineEndpointCapture);
}

LineEndpointStartDecision _endpointStart(LineMachine machine) {
  return machine.startEndpoint(
    pendingLine: const LinePendingStartCapture(
      startWorld: Offset(1, 2),
      timestampMs: 7,
      color: Color(0xFF778899),
      thickness: 5,
    ),
    endWorld: const Offset(3, 4),
  );
}

LineEndpointPreviewDecision _expectEndpointPreview(
  LineMachine machine,
  PointerLineEndpointCapture line,
) {
  final duplicate = machine.preview(line: line, endWorld: const Offset(3, 4));
  final changed = machine.preview(line: line, endWorld: const Offset(5, 6));

  expect(line.preview, isA<CanvasLinePreview>());
  expect(duplicate.changed, isFalse);
  expect(changed.line?.endWorld, const Offset(5, 6));

  return changed;
}

void _expectEndpointTerminal(
  LineMachine machine,
  PointerLineEndpointCapture line,
) {
  final terminal = machine.terminal(
    sessionId: const PointerSessionId(1),
    pointerToken: const PointerSessionToken(2),
    line: line,
    terminalWorld: const Offset(9, 9),
  );

  expect(terminal.intent.sessionId, const PointerSessionId(1));
  expect(terminal.intent.pointerToken, const PointerSessionToken(2));
  expect(terminal.intent.startWorld, const Offset(1, 2));
  expect(terminal.intent.endWorld, const Offset(9, 9));
  expect(terminal.intent.color, const Color(0xFF778899));
  expect(terminal.intent.thickness, 5);
  expect(terminal.intent.opacity, 1);
}

void _verifySamePointEndpointCommit() {
  const machine = LineMachine();
  final start = machine.startEndpoint(
    pendingLine: const LinePendingStartCapture(
      startWorld: Offset(4, 4),
      timestampMs: 21,
      color: Color(0xFF010203),
      thickness: 8,
    ),
    endWorld: const Offset(4, 4),
  );
  final terminal = machine.terminal(
    sessionId: const PointerSessionId(9),
    pointerToken: const PointerSessionToken(10),
    line: start.line,
    terminalWorld: const Offset(4, 4),
  );

  expect(terminal.intent.startWorld, const Offset(4, 4));
  expect(terminal.intent.endWorld, const Offset(4, 4));
  expect(terminal.intent.thickness, 8);
  expect(terminal.intent.opacity, 1);
}
