import 'dart:ui';
import "../../support/runtime_root_with_committed_document_seed.dart";

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_runtime_intents.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_session_identity.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';

void main() {
  test('pencil marker and line commits add elements and emit draw actions', () {
    return expectLater(_verifyDrawCommitDelivery(), completes);
  });

  test('draw delivery failure cleans interaction and emits no action', () {
    return expectLater(_verifyDrawDeliveryFailureRollback(), completes);
  });

  test(
    'line delivery failure cleans pending interaction and preserves its id',
    () {
      return expectLater(_verifyLineDeliveryFailureRollback(), completes);
    },
  );

  test(
    'runtime draw and line routes observe one unreserved candidate each',
    () {
      return expectLater(_verifyRuntimeRouteIdAdmissionWork(), completes);
    },
  );

  test('programmatic addElement remains action silent', () {
    return expectLater(_verifyProgrammaticAddElementActionSilence(), completes);
  });

  test('draw routes clean previews before every delivery callback', () {
    return expectLater(_verifyDrawRouteDeliveryCleanup(), completes);
  });
}

// Each draw variant must share the same real callback observations; splitting
// the matrix would obscure a route-specific cleanup/delivery regression.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
Future<void> _verifyDrawRouteDeliveryCleanup() async {
  for (final route
      in <
        ({
          RuntimeNonTextRoute route,
          void Function(RuntimeRoot) start,
          void Function(RuntimeRoot) finish,
        })
      >[
        (
          route: RuntimeNonTextRoute.drawStroke,
          start: _startPencilDeliveryProbe,
          finish: _finishPencilDeliveryProbe,
        ),
        (
          route: RuntimeNonTextRoute.drawStroke,
          start: _startMarkerDeliveryProbe,
          finish: _finishMarkerDeliveryProbe,
        ),
        (
          route: RuntimeNonTextRoute.drawLine,
          start: _startLineDeliveryProbe,
          finish: _finishLineDeliveryProbe,
        ),
      ]) {
    final trace = <String>[];
    var terminalDelivery = false;
    late RuntimeRoot root;
    root = runtimeRootWithCommittedDocumentSeed(
      CanvasDocument(),
      config: const CanvasRuntimeConfig(),
      commitEffectObserver: (effects) {
        if (!terminalDelivery) return;
        _expectCleanDrawDelivery(root);
        _expectMergedDrawRepaint(effects);
        trace.add('observer');
      },
    );
    final surface = Object();
    root.attachSurface(surface);
    route.start(root);
    root.surfaceFrameSignal.addListener(() {
      if (!terminalDelivery) return;
      _expectCleanDrawDelivery(root);
      final frame = root.surfaceFrameSignal.value;
      expect(frame?.mainCanvas, isTrue);
      expect(frame?.overlayCanvas, isTrue);
      trace.add('frame');
    });
    root.state.addListener(() {
      if (!terminalDelivery) return;
      _expectCleanDrawDelivery(root);
      trace.add('state');
    });
    final subscription = root.actions.listen((_) {
      _expectCleanDrawDelivery(root);
      trace.add('action');
    });
    terminalDelivery = true;
    final events = <RuntimeRouteTemporalEvent>[];
    RuntimeRoot.observeRouteTemporalEvents((event) {
      events.add(event);
      _recordDrawRouteLifecycleTrace(event, route.route, trace);
    }, () => route.finish(root));
    expect(trace, [
      'prepared',
      'cleanup',
      'effects',
      'delivery',
      'frame',
      'state',
      'action',
      'observer',
    ]);
    _expectDrawRouteLifecycle(events, route.route);
    await subscription.cancel();
    root.detachSurface(surface);
    root.dispose();
  }
}

void _recordDrawRouteLifecycleTrace(
  RuntimeRouteTemporalEvent event,
  RuntimeNonTextRoute route,
  List<String> trace,
) {
  if (event.route != route) return;
  switch (event.kind) {
    case RuntimeRouteTemporalEventKind.preparedApplyReturned:
      trace.add('prepared');
    case RuntimeRouteTemporalEventKind.routeCleanupCompleted:
      trace.add('cleanup');
    case RuntimeRouteTemporalEventKind.cleanupEffectsAugmented:
      trace.add('effects');
    case RuntimeRouteTemporalEventKind.commonDeliveryEntered:
      trace.add('delivery');
    default:
      break;
  }
}

void _expectDrawRouteLifecycle(
  List<RuntimeRouteTemporalEvent> events,
  RuntimeNonTextRoute route,
) {
  expect(
    events.where((event) => event.route == route).map((event) => event.kind),
    [
      RuntimeRouteTemporalEventKind.preparedApplyReturned,
      RuntimeRouteTemporalEventKind.routeCleanupCompleted,
      RuntimeRouteTemporalEventKind.cleanupEffectsAugmented,
      RuntimeRouteTemporalEventKind.commonDeliveryEntered,
    ],
  );
}

void _startPencilDeliveryProbe(RuntimeRoot root) {
  root.setInteractionMode(CanvasInteractionMode.draw);
  root.setDrawStyle(CanvasDrawStyle.defaultStyle);
  root.handlePointer(_pointer(CanvasPointerLifecyclePhase.down, Offset.zero));
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.move, const Offset(2, 3)),
  );
}

void _finishPencilDeliveryProbe(RuntimeRoot root) {
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, const Offset(4, 5)),
  );
}

void _startMarkerDeliveryProbe(RuntimeRoot root) {
  root.setInteractionMode(CanvasInteractionMode.draw);
  root.setDrawStyle(CanvasDrawStyle(tool: CanvasDrawTool.marker));
  root.handlePointer(_pointer(CanvasPointerLifecyclePhase.down, Offset.zero));
}

void _finishMarkerDeliveryProbe(RuntimeRoot root) {
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, const Offset(2, 3)),
  );
}

void _startLineDeliveryProbe(RuntimeRoot root) {
  root.setInteractionMode(CanvasInteractionMode.draw);
  root.setDrawStyle(CanvasDrawStyle(tool: CanvasDrawTool.line));
  root.handlePointer(_pointer(CanvasPointerLifecyclePhase.down, Offset.zero));
  root.handlePointer(_pointer(CanvasPointerLifecyclePhase.up, Offset.zero));
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, const Offset(2, 3)),
  );
}

void _finishLineDeliveryProbe(RuntimeRoot root) {
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, const Offset(2, 3)),
  );
}

void _expectCleanDrawDelivery(RuntimeRoot root) {
  expect(root.preview, isA<CanvasNoPreview>());
  expect(root.interactionEngine.activeSession, isNull);
}

void _expectMergedDrawRepaint(List<CommitDeliveryEffect> effects) {
  final repaint = effects.whereType<RepaintDeliveryEffect>().single;
  expect(repaint.mainCanvas, isTrue);
  expect(repaint.overlayCanvas, isTrue);
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
  _expectAcceptedDrawRouteIdOrder(scenario);
}

void _expectAcceptedDrawRouteIdOrder(_DrawScenario scenario) {
  expect(scenario.actions.map((action) => action.elementIds.single), [
    CanvasElementId('e0'),
    CanvasElementId('e1'),
    CanvasElementId('e2'),
  ]);
  expect(scenario.root.generateElementId(), CanvasElementId('e3'));
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
  expect(scenario.root.generateElementId(), CanvasElementId('e0'));
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
  expect(scenario.actions.single.elementIds, [CanvasElementId('e1')]);
}

Future<void> _verifyLineDeliveryFailureRollback() async {
  final scenario = _scenario();
  final before = _startPendingLinePreview(scenario.root);

  expect(
    () => scenario.root.deliverDrawLineCommitForTesting(
      _invalidLineCommitIntent(),
      timestampHintMs: 20,
    ),
    throwsA(isA<CanvasDataException>()),
  );
  await Future<void>.delayed(Duration.zero);

  _expectFailedLineDeliveryRollback(scenario, before);
  await _expectFailedLineLeavesTimestampUnadvanced(scenario);
}

void _expectFailedLineDeliveryRollback(
  _DrawScenario scenario,
  CanvasRuntimeState before,
) {
  expect(scenario.actions, isEmpty);
  expect(
    scenario.root.state.value.revisions.document,
    before.revisions.document,
  );
  expect(scenario.root.preview, isA<CanvasNoPreview>());
  expect(scenario.root.generateElementId(), CanvasElementId('e0'));
}

Future<void> _expectFailedLineLeavesTimestampUnadvanced(
  _DrawScenario scenario,
) async {
  scenario.root.deliverDrawLineCommitForTesting(
    _validLineCommitIntent(),
    timestampHintMs: null,
  );
  await Future<void>.delayed(Duration.zero);
  // The pending-line preview has already accepted baseline timestamp zero.
  expect(scenario.actions.single.timestampMs, 1);
  expect(scenario.actions.single.elementIds, [CanvasElementId('e1')]);
}

CanvasRuntimeState _startPendingLinePreview(RuntimeRoot root) {
  root.setInteractionMode(CanvasInteractionMode.draw);
  root.setDrawStyle(
    CanvasDrawStyle(tool: CanvasDrawTool.line, lineThickness: 4),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, const Offset(1, 2)),
  );
  root.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.up, const Offset(1, 2)),
  );
  expect(root.preview, isA<CanvasPendingLineStartPreview>());

  return root.state.value;
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

DrawLineCommitIntent _invalidLineCommitIntent() {
  return const DrawLineCommitIntent(
    sessionId: PointerSessionId(100),
    pointerToken: PointerSessionToken(100),
    startWorld: Offset.zero,
    endWorld: Offset(1, 1),
    color: Color(0xFF112233),
    thickness: 0,
    opacity: 1,
  );
}

DrawLineCommitIntent _validLineCommitIntent() {
  return const DrawLineCommitIntent(
    sessionId: PointerSessionId(101),
    pointerToken: PointerSessionToken(101),
    startWorld: Offset.zero,
    endWorld: Offset(1, 1),
    color: Color(0xFF112233),
    thickness: 4,
    opacity: 1,
  );
}

Future<void> _verifyRuntimeRouteIdAdmissionWork() async {
  final setup = _createSupportedPrefixRuntime();
  addTearDown(setup.root.dispose);
  _expectSupportedPrefixReset(setup.resetWork);
  _verifyRepeatedFailedRouteReads(setup.root);
  _verifyAcceptedRouteReads(setup.root);
  await Future<void>.delayed(Duration.zero);
}

_RouteWorkSetup _createSupportedPrefixRuntime() {
  final resetWork = _IdAdmissionWork();
  late RuntimeRoot root;
  DocumentStoreKernel.observeIdAdmissionWork(resetWork.record, () {
    root = runtimeRootWithCommittedDocumentSeed(_supportedPrefixDocument());
  });

  return (root: root, resetWork: resetWork);
}

void _expectSupportedPrefixReset(_IdAdmissionWork work) {
  _expectIdAdmissionPhase(
    work,
    phase: IdAdmissionWorkPhase.reset,
    expected: const {
      IdAdmissionWorkKind.inputVisit: 200000,
      IdAdmissionWorkKind.cursorProbe: 200001,
      IdAdmissionWorkKind.collision: 200000,
      IdAdmissionWorkKind.advance: 200000,
    },
  );
}

void _verifyRepeatedFailedRouteReads(RuntimeRoot root) {
  for (var attempt = 0; attempt < 2; attempt += 1) {
    final strokeWork = _observeIdAdmissionWork(() {
      _expectInvalidStrokeCommitRejected(root);
    });
    _expectReadOnlyRouteCandidate(strokeWork);

    _startPendingLinePreview(root);
    final lineWork = _observeIdAdmissionWork(() {
      expect(
        () => root.deliverDrawLineCommitForTesting(
          _invalidLineCommitIntent(),
          timestampHintMs: 20,
        ),
        throwsA(isA<CanvasDataException>()),
      );
    });
    _expectReadOnlyRouteCandidate(lineWork);
    expect(root.preview, isA<CanvasNoPreview>());
  }
}

void _verifyAcceptedRouteReads(RuntimeRoot root) {
  final pencilWork = _observeIdAdmissionWork(() {
    _drawPencil(root);
  });
  _expectReadOnlyRouteCandidate(pencilWork);
  _expectAcceptedRouteAdmission(pencilWork);

  final explicitWork = _observeIdAdmissionWork(() {
    expect(root.generateElementId(), CanvasElementId('e200001'));
  });
  _expectIdAdmissionPhase(
    explicitWork,
    phase: IdAdmissionWorkPhase.generation,
    expected: const {
      IdAdmissionWorkKind.cursorProbe: 1,
      IdAdmissionWorkKind.advance: 1,
      IdAdmissionWorkKind.candidateObservation: 1,
      IdAdmissionWorkKind.reservation: 1,
    },
  );

  final lineWork = _observeIdAdmissionWork(() {
    _drawLine(root);
  });
  _expectReadOnlyRouteCandidate(lineWork);
  _expectAcceptedRouteAdmission(lineWork);
  expect(root.generateElementId(), CanvasElementId('e200003'));
}

void _expectReadOnlyRouteCandidate(_IdAdmissionWork work) {
  _expectIdAdmissionPhase(
    work,
    phase: IdAdmissionWorkPhase.generation,
    expected: const {IdAdmissionWorkKind.candidateObservation: 1},
  );
}

void _expectAcceptedRouteAdmission(_IdAdmissionWork work) {
  _expectIdAdmissionPhase(
    work,
    phase: IdAdmissionWorkPhase.acceptedAdmission,
    expected: const {
      IdAdmissionWorkKind.sparseLedgerVisit: 1,
      IdAdmissionWorkKind.inputVisit: 1,
      IdAdmissionWorkKind.cursorProbe: 2,
      IdAdmissionWorkKind.collision: 1,
      IdAdmissionWorkKind.advance: 1,
    },
  );
}

CanvasDocument _supportedPrefixDocument() {
  return CanvasDocument(
    backgroundElements: List<CanvasElement>.generate(
      200000,
      (index) => CanvasRectElement(
        id: CanvasElementId('e$index'),
        size: const Size(1, 1),
      ),
      growable: false,
    ),
  );
}

_IdAdmissionWork _observeIdAdmissionWork(void Function() operation) {
  final work = _IdAdmissionWork();
  DocumentStoreKernel.observeIdAdmissionWork(work.record, operation);
  return work;
}

void _expectIdAdmissionPhase(
  _IdAdmissionWork work, {
  required IdAdmissionWorkPhase phase,
  required Map<IdAdmissionWorkKind, int> expected,
}) {
  for (final kind in IdAdmissionWorkKind.values) {
    expect(
      work.count(prefix: 'e', phase: phase, kind: kind),
      expected[kind] ?? 0,
    );
  }
}

final class _IdAdmissionWork {
  final Map<(String, IdAdmissionWorkPhase, IdAdmissionWorkKind), int> _counts =
      {};

  void record(IdAdmissionWorkEvent event) {
    final key = (event.prefix, event.phase, event.kind);
    _counts[key] = (_counts[key] ?? 0) + 1;
  }

  int count({
    required String prefix,
    required IdAdmissionWorkPhase phase,
    required IdAdmissionWorkKind kind,
  }) {
    return _counts[(prefix, phase, kind)] ?? 0;
  }
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

typedef _RouteWorkSetup = ({RuntimeRoot root, _IdAdmissionWork resetWork});

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
