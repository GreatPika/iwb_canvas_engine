import 'dart:ui';
import "../../support/runtime_root_with_committed_document_seed.dart";

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_runtime_intents.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_session_identity.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  test('pencil marker and line commits add elements and emit draw actions', () {
    return expectLater(_verifyDrawCommitDelivery(), completes);
  });

  test('draw delivery failure cleans interaction and emits no action', () {
    return expectLater(_verifyDrawDeliveryFailureRollback(), completes);
  });

  test('programmatic addElement remains action silent', () {
    return expectLater(_verifyProgrammaticAddElementActionSilence(), completes);
  });
}

Future<void> _verifyDrawCommitDelivery() async {
  final scenario = _scenario();

  _drawPencil(scenario.root);
  await _expectDeliveredActionCount(scenario, expectedDocumentRevisions: [1]);
  _expectLatestCommitRepaintsMainAndOverlay(scenario);

  _drawMarker(scenario.root);
  await _expectDeliveredActionCount(
    scenario,
    expectedDocumentRevisions: [1, 2],
  );
  _expectLatestCommitRepaintsMainAndOverlay(scenario);

  _drawLine(scenario.root);
  await _expectDeliveredActionCount(
    scenario,
    expectedDocumentRevisions: [1, 2, 3],
  );
  _expectLatestCommitRepaintsMainAndOverlay(scenario);
  _expectPencil(scenario.root.readDocument(), scenario.actions[0]);
  _expectMarker(scenario.root.readDocument(), scenario.actions[1]);
  _expectLine(scenario.root.readDocument(), scenario.actions[2]);
}

Future<void> _expectDeliveredActionCount(
  _DrawScenario scenario, {
  required List<int> expectedDocumentRevisions,
}) async {
  await Future<void>.delayed(Duration.zero);
  expect(scenario.actions, hasLength(expectedDocumentRevisions.length));
  expect(scenario.effectBatches, hasLength(expectedDocumentRevisions.length));
  expect(
    scenario.actionStates.map((state) => state.revisions.document),
    expectedDocumentRevisions,
  );
}

void _expectLatestCommitRepaintsMainAndOverlay(_DrawScenario scenario) {
  final repaint = scenario.effectBatches.last
      .whereType<RepaintDeliveryEffect>()
      .single;
  expect(repaint.mainCanvas, isTrue);
  expect(repaint.overlayCanvas, isTrue);
}

void _drawPencil(RuntimeRoot root, {int? timestampMs = 10}) {
  root.setInteractionMode(CanvasInteractionMode.draw);
  root.setDrawStyle(
    CanvasDrawStyle(
      tool: CanvasDrawTool.pencil,
      color: const Color(0xFF112233),
      pencilThickness: 3,
    ),
  );
  root.handlePointer(_pointer(CanvasPointerLifecyclePhase.down, Offset.zero));
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.move, const Offset(2, 3)),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, const Offset(4, 5), timestampMs),
  );
}

void _drawMarker(RuntimeRoot root) {
  root.setDrawStyle(
    CanvasDrawStyle(
      tool: CanvasDrawTool.marker,
      color: const Color(0xFF445566),
      markerThickness: 12,
      markerOpacity: 0.4,
    ),
  );
  root.handlePointer(_pointer(CanvasPointerLifecyclePhase.down, Offset.zero));
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, const Offset(1, 1), 11),
  );
}

void _drawLine(RuntimeRoot root) {
  root.setDrawStyle(
    CanvasDrawStyle(
      tool: CanvasDrawTool.line,
      color: const Color(0xFF778899),
      lineThickness: 4,
    ),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, const Offset(1, 2)),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, const Offset(1, 2), 12),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, const Offset(3, 4)),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, const Offset(3, 4), 13),
  );
}

void _expectPencil(CanvasDocument document, CanvasActionCommitted action) {
  expect(action.type, CanvasActionType.drawPencil);
  expect(action.timestampMs, 10);
  final payload = action.payload as CanvasDrawStrokeActionPayload;
  expect(payload.tool, CanvasDrawTool.pencil);
  expect(payload.color, const Color(0xFF112233));
  expect(payload.thickness, 3);
  expect(payload.opacity, 1);
  expect(payload.pointCount, 3);

  final stroke = _element(document, action) as CanvasStrokeElement;
  expect(stroke.points, const [Offset.zero, Offset(2, 3), Offset(4, 5)]);
  expect(stroke.color, const Color(0xFF112233));
  expect(stroke.thickness, 3);
  expect(stroke.opacity, 1);
}

void _expectMarker(CanvasDocument document, CanvasActionCommitted action) {
  expect(action.type, CanvasActionType.drawMarker);
  expect(action.timestampMs, 11);
  final payload = action.payload as CanvasDrawStrokeActionPayload;
  expect(payload.tool, CanvasDrawTool.marker);
  expect(payload.color, const Color(0xFF445566));
  expect(payload.thickness, 12);
  expect(payload.opacity, 0.4);
  expect(payload.pointCount, 2);

  final stroke = _element(document, action) as CanvasStrokeElement;
  expect(stroke.points, const [Offset.zero, Offset(1, 1)]);
  expect(stroke.color, const Color(0xFF445566));
  expect(stroke.thickness, 12);
  expect(stroke.opacity, 0.4);
}

void _expectLine(CanvasDocument document, CanvasActionCommitted action) {
  expect(action.type, CanvasActionType.drawLine);
  expect(action.timestampMs, 13);
  final payload = action.payload as CanvasDrawLineActionPayload;
  expect(payload.color, const Color(0xFF778899));
  expect(payload.thickness, 4);
  expect(payload.opacity, 1);
  expect(payload.startWorld, const Offset(1, 2));
  expect(payload.endWorld, const Offset(3, 4));

  final line = _element(document, action) as CanvasLineElement;
  expect(line.start, const Offset(1, 2));
  expect(line.end, const Offset(3, 4));
  expect(line.color, const Color(0xFF778899));
  expect(line.thickness, 4);
  expect(line.opacity, 1);
}

CanvasElement _element(CanvasDocument document, CanvasActionCommitted action) {
  return document.layers.single.elements.singleWhere(
    (element) => element.id == action.elementIds.single,
  );
}

Future<void> _verifyDrawDeliveryFailureRollback() async {
  final scenario = _scenario();
  final before = _startPencilPreview(scenario.root);

  _expectInvalidStrokeCommitRejected(scenario.root);
  await Future<void>.delayed(Duration.zero);

  _expectFailedDrawDeliveryRollback(scenario, before);
  await _expectFailureDoesNotAdvanceActionTimestamp(scenario);
}

CanvasRuntimeState _startPencilPreview(RuntimeRoot root) {
  root.setInteractionMode(CanvasInteractionMode.draw);
  root.setDrawStyle(CanvasDrawStyle.defaultStyle);

  root.handlePointer(_pointer(CanvasPointerLifecyclePhase.down, Offset.zero));
  final state = root.state.value;
  expect(root.preview, isA<CanvasPencilStrokePreview>());

  return state;
}

void _expectInvalidStrokeCommitRejected(RuntimeRoot root) {
  expect(
    () => root.deliverDrawStrokeCommitForTesting(
      _emptyStrokeCommitIntent(),
      timestampHintMs: 20,
    ),
    throwsA(isA<CanvasDataException>()),
  );
}

void _expectFailedDrawDeliveryRollback(
  _DrawScenario scenario,
  CanvasRuntimeState before,
) {
  expect(scenario.actions, isEmpty);
  expect(
    scenario.root.state.value.revisions.document,
    before.revisions.document,
  );
  expect(scenario.root.preview, isA<CanvasNoPreview>());
}

Future<void> _expectFailureDoesNotAdvanceActionTimestamp(
  _DrawScenario scenario,
) async {
  _drawPencil(scenario.root, timestampMs: null);
  await Future<void>.delayed(Duration.zero);
  expect(scenario.actions.single.timestampMs, 0);
}

DrawStrokeCommitIntent _emptyStrokeCommitIntent() {
  return DrawStrokeCommitIntent(
    sessionId: const PointerSessionId(100),
    pointerToken: const PointerSessionToken(100),
    tool: CanvasDrawTool.pencil,
    points: const [],
    color: const Color(0xFF112233),
    thickness: 3,
    opacity: 1,
  );
}

Future<void> _verifyProgrammaticAddElementActionSilence() async {
  final scenario = _scenario();

  scenario.root.edits.edit((edit) {
    edit.addElement(
      CanvasRectElement(id: CanvasElementId('rect-a'), size: const Size(1, 1)),
    );
  });
  await Future<void>.delayed(Duration.zero);

  expect(scenario.actions, isEmpty);
  expect(scenario.root.readDocument().layers.single.elements, hasLength(1));
}

_DrawScenario _scenario({CanvasDocument? initialDocument}) {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final root = runtimeRootWithCommittedDocumentSeed(
    initialDocument ?? CanvasDocument(),
    config: const CanvasRuntimeConfig(),
    commitEffectObserver: effectBatches.add,
  );
  final actions = <CanvasActionCommitted>[];
  final actionStates = <CanvasRuntimeState>[];
  final subscription = root.actions.listen((action) {
    actions.add(action);
    actionStates.add(root.state.value);
  });
  addTearDown(() async {
    await subscription.cancel();
    root.dispose();
  });

  return (
    root: root,
    actions: actions,
    actionStates: actionStates,
    effectBatches: effectBatches,
  );
}

typedef _DrawScenario = ({
  RuntimeRoot root,
  List<CanvasActionCommitted> actions,
  List<CanvasRuntimeState> actionStates,
  List<List<CommitDeliveryEffect>> effectBatches,
});

CanvasPointerSample _pointer(
  CanvasPointerLifecyclePhase phase,
  Offset position, [
  int? timestampMs,
]) {
  return CanvasPointerSample(
    pointerId: 1,
    position: position,
    phase: phase,
    kind: PointerDeviceKind.touch,
    timestampMs: timestampMs,
  );
}
