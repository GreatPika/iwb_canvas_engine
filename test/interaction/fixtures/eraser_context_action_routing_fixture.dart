// This fixture verifies the full eraser/context routing boundary, so the
// machine, read-port, intent, session identity, and runtime surfaces stay
// together instead of being split into metric-shaped fixtures.
// ignore_for_file: number-of-imports

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/deletion_entry_projection_port.dart';
import 'package:iwb_canvas_engine/src/interaction/eraser_machine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_pointer_context.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_read_port.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_runtime_intents.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_sample_normalizer.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_cleanup_protocol.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_session.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_session_identity.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import '../../support/runtime_root_with_committed_document_seed.dart';

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
  test('eraser capture retains the exact bounded approximation', () {
    expect(_verifyEraserCaptureRetainedApproximation, returnsNormally);
  });

  test('real eraser route retains repeated bounded approximations', () {
    expect(_verifyRepeatedRetainedEraserRouting, returnsNormally);
  });

  test('eraser machine captures preview and commit decisions', () {
    expect(_verifyEraserMachineDecisions, returnsNormally);
  });

  test('interaction routes draw eraser through eraser machine', () {
    expect(_verifyEraserInteractionRouting, returnsNormally);
  });

  test('eraser stale terminal cleanup produces no commit intent', () {
    expect(_verifyEraserStaleTerminalCleanup, returnsNormally);
  });

  test('eraser cleanup releases capture without displaced work', () {
    expect(_verifyEraserCleanupDoesNoCaptureWork, returnsNormally);
  });

  test('draw stroke machine still rejects eraser', () {
    expect(_verifyDrawStrokeRejectsEraserSession, returnsNormally);
  });

  test('eraser callbacks observe cleanup and merged repaint intent', () {
    expect(_verifyEraserCleanupPrecedesDelivery, returnsNormally);
  });
}

// One accepted eraser terminal must relate its cleanup to every callback.
// Keeping the lifecycle and callbacks together makes the route's temporal
// relation explicit instead of hiding it behind test-only helper layers.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _verifyEraserCleanupPrecedesDelivery() {
  final trace = <String>[];
  var terminalDelivery = false;
  late RuntimeRoot root;
  root = runtimeRootWithCommittedDocumentSeed(
    CanvasDocument(
      layers: [
        CanvasLayer(
          id: CanvasLayerId('eraser-layer'),
          elements: [
            CanvasRectElement(
              id: CanvasElementId('erasable-a'),
              size: const Size(10, 10),
            ),
          ],
        ),
      ],
    ),
    commitEffectObserver: (effects) {
      if (!terminalDelivery) return;
      _expectCleanEraserDelivery(root);
      final repaint = effects.whereType<RepaintDeliveryEffect>().single;
      expect(repaint.mainCanvas, isTrue);
      expect(repaint.overlayCanvas, isTrue);
      trace.add('observer');
    },
  );
  final surface = Object();
  root.attachSurface(surface);
  root.setInteractionMode(CanvasInteractionMode.draw);
  root.setDrawStyle(CanvasDrawStyle(tool: CanvasDrawTool.eraser));
  root.handlePointer(_sample(1, Offset.zero, CanvasPointerLifecyclePhase.down));
  root.handlePointer(
    _sample(1, const Offset(2, 3), CanvasPointerLifecyclePhase.move),
  );
  root.surfaceFrameSignal.addListener(() {
    if (!terminalDelivery) return;
    _expectCleanEraserDelivery(root);
    final frame = root.surfaceFrameSignal.value;
    expect(frame?.mainCanvas, isTrue);
    expect(frame?.overlayCanvas, isTrue);
    trace.add('frame');
  });
  root.state.addListener(() {
    if (!terminalDelivery) return;
    _expectCleanEraserDelivery(root);
    trace.add('state');
  });
  final subscription = root.actions.listen((_) {
    _expectCleanEraserDelivery(root);
    trace.add('action');
  });
  addTearDown(() async {
    await subscription.cancel();
    terminalDelivery = false;
    root.detachSurface(surface);
    root.dispose();
  });
  terminalDelivery = true;
  final events = <RuntimeRouteTemporalEvent>[];
  RuntimeRoot.observeRouteTemporalEvents(
    (event) {
      events.add(event);
      _recordEraserRouteLifecycleTrace(event, trace);
    },
    () => root.handlePointer(
      _sample(1, const Offset(4, 5), CanvasPointerLifecyclePhase.up),
    ),
  );
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
  _expectEraserRouteLifecycle(events);
}

void _recordEraserRouteLifecycleTrace(
  RuntimeRouteTemporalEvent event,
  List<String> trace,
) {
  if (event.route != RuntimeNonTextRoute.eraser) return;
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

void _expectEraserRouteLifecycle(List<RuntimeRouteTemporalEvent> events) {
  expect(
    events
        .where((event) => event.route == RuntimeNonTextRoute.eraser)
        .map((event) => event.kind),
    [
      RuntimeRouteTemporalEventKind.preparedApplyReturned,
      RuntimeRouteTemporalEventKind.routeCleanupCompleted,
      RuntimeRouteTemporalEventKind.cleanupEffectsAugmented,
      RuntimeRouteTemporalEventKind.commonDeliveryEntered,
    ],
  );
}

void _expectCleanEraserDelivery(RuntimeRoot root) {
  expect(root.preview, isA<CanvasNoPreview>());
  expect(root.interactionEngine.activeSession, isNull);
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

  test('context tap missing timestamps can match by target and slop', () {
    expect(_verifyContextTapMissingTimestampsMatch, returnsNormally);
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
// ignore: halstead-volume, source-lines-of-code
void _verifyEraserMachineDecisions() {
  const machine = EraserMachine();
  final start = machine.start(
    tool: CanvasDrawTool.eraser,
    startWorld: Offset.zero,
    style: CanvasDrawStyle.defaultStyle,
  );
  final eraser = start.eraser as PointerEraserCapture;
  final admission = eraser.admitPoint(const Offset(2, 3));
  expect(admission.admitted, isTrue);

  final preview = machine.preview(
    eraser: eraser,
    corridorPoints: eraser.points,
    facts: _eraserFacts(
      corridor: const [Offset.zero, Offset(2, 3)],
      erasedIds: const [],
    ),
  );
  final projectedEntry = _projectedEntry();
  final terminalFacts = _eraserFacts(
    corridor: const [Offset.zero, Offset(2, 3), Offset(4, 5)],
    erasedIds: [CanvasElementId('a')],
    erasedEntries: [projectedEntry],
  );
  final terminal = machine.terminal(
    input: EraserTerminalInput(
      sessionId: const PointerSessionId(1),
      pointerToken: const PointerSessionToken(2),
      eraser: preview.eraser as PointerEraserCapture,
      facts: terminalFacts,
    ),
  );

  final eraserPreview = preview.preview as CanvasEraserPreview;
  final intent = terminal.intent as EraserCommitIntent;
  expect(eraser.points, [Offset.zero, const Offset(2, 3)]);
  expect(eraser.thickness, CanvasDrawStyle.defaultStyle.eraserThickness);
  expect(preview.eraser, same(eraser));
  expect(eraserPreview.corridor, [Offset.zero, const Offset(2, 3)]);
  expect(() => eraserPreview.corridor.clear(), throwsUnsupportedError);
  expect(intent.erasedElementIds, [CanvasElementId('a')]);
  expect(intent.erasedEntries, hasLength(1));
  expect(intent.erasedEntries.single.element, same(projectedEntry.element));
  expect(intent.eraserThickness, eraser.thickness);
  expect(intent.corridorPointCount, terminalFacts.corridorPoints.length);
}

// This scenario keeps its retained-corridor observations together so that the
// resample and duplicate assertions continue to describe one user interaction.
// ignore: halstead-volume, source-lines-of-code
void _verifyEraserCaptureRetainedApproximation() {
  final source = <Offset>[
    for (var index = 0; index <= 8000; index += 1)
      Offset(index.toDouble(), (index % 7).toDouble()),
  ];
  final events = <PointerEraserCaptureWorkEvent>[];
  final eraser = PointerEraserCapture(points: [source.first], thickness: 6);

  PointerEraserCapture.observeWork(events.add, () {
    for (final point in source.skip(1)) {
      expect(eraser.admitPoint(point).admitted, isTrue);
    }
    expect(eraser.admitPoint(source.last).admitted, isFalse);
  });

  final retained = eraser.points;
  expect(retained, hasLength(4000));
  expect(retained.first, source.first);
  expect(retained.last, source.last);
  expect(retained, [
    for (var index = 0; index < 4000; index += 1)
      source[(index * (source.length - 1)) ~/ 3999],
  ]);
  expect(
    events.where(
      (event) => event.kind == PointerEraserCaptureWorkKind.resampled,
    ),
    hasLength(1),
  );
  expect(events.skip(events.length - 3).map((event) => event.kind), [
    PointerEraserCaptureWorkKind.sampleAdmitted,
    PointerEraserCaptureWorkKind.resampled,
    PointerEraserCaptureWorkKind.duplicateSuppressed,
  ]);
  expect(
    events.where(
      (event) => event.kind == PointerEraserCaptureWorkKind.ordinaryAppend,
    ),
    everyElement(
      isA<PointerEraserCaptureWorkEvent>()
          .having(
            (event) => event.retainedPrefixPointsTraversed,
            'traversed',
            0,
          )
          .having((event) => event.retainedPrefixPointsCopied, 'copied', 0),
    ),
  );
}

// This route deliberately keeps its two overflow cycles and terminal boundary
// together: the retained public preview and terminal read must have one truth.
// The direct overflow/publication comparisons are intentionally co-located so
// equal-count snapshots cannot be separated from their two real resamples.
// ignore: halstead-volume, source-lines-of-code, maintainability-index, cyclomatic-complexity
void _verifyRepeatedRetainedEraserRouting() {
  final source = <Offset>[
    for (var index = 0; index <= 12001; index += 1)
      Offset(index.toDouble(), ((index * 17) % 29).toDouble()),
  ];
  final readPort = _FakeReadPort();
  final engine = _eraserEngine(readPort);
  final captureEvents = <PointerEraserCaptureWorkEvent>[];
  PointerEraserCapture.observeWork(captureEvents.add, () {
    engine.handlePointerSample(
      _sample(1, source.first, CanvasPointerLifecyclePhase.down),
      _context(1),
    );
    for (var index = 1; index < source.length; index += 1) {
      engine.handlePointerSample(
        _sample(1, source[index], CanvasPointerLifecyclePhase.move),
        _context(1),
      );
    }
  });

  final preview = engine.preview as CanvasEraserPreview;
  expect(preview.corridor, hasLength(4000));
  expect(readPort.lastPreviewCorridor, preview.corridor);
  expect(
    captureEvents.where(
      (event) => event.kind == PointerEraserCaptureWorkKind.resampled,
    ),
    everyElement(
      isA<PointerEraserCaptureWorkEvent>().having(
        (event) => event.retainedPointCount,
        'retained count',
        4000,
      ),
    ),
  );
  expect(
    captureEvents
        .where((event) => event.kind == PointerEraserCaptureWorkKind.resampled)
        .length,
    2,
  );
  final resamples = [
    for (final event in captureEvents)
      if (event.kind == PointerEraserCaptureWorkKind.resampled) event,
  ];
  expect(resamples.map((event) => event.retainedPrefixPointsTraversed), [
    8001,
    8001,
  ]);
  expect(resamples.map((event) => event.retainedPrefixPointsCopied), [
    4000,
    4000,
  ]);
  final firstFullPublication = captureEvents.firstWhere(
    (event) =>
        event.kind == PointerEraserCaptureWorkKind.snapshotCreated &&
        event.retainedPointCount == 4000,
  );
  final postResamplePublications = [
    for (var index = 0; index < captureEvents.length - 1; index += 1)
      if (captureEvents[index].kind == PointerEraserCaptureWorkKind.resampled)
        captureEvents[index + 1],
  ];
  expect(postResamplePublications.map((event) => event.kind), [
    PointerEraserCaptureWorkKind.snapshotCreated,
    PointerEraserCaptureWorkKind.snapshotCreated,
  ]);
  expect(
    [
      firstFullPublication,
      ...postResamplePublications,
    ].map((event) => event.retainedPointCount),
    [4000, 4000, 4000],
  );
  expect(
    [
      firstFullPublication,
      ...postResamplePublications,
    ].map((event) => event.retainedPrefixPointsTraversed),
    [4000, 4000, 4000],
  );
  expect(
    [
      firstFullPublication,
      ...postResamplePublications,
    ].map((event) => event.retainedPrefixPointsCopied),
    [4000, 4000, 4000],
  );
  expect(
    captureEvents.where(
      (event) => event.kind == PointerEraserCaptureWorkKind.ordinaryAppend,
    ),
    everyElement(
      isA<PointerEraserCaptureWorkEvent>()
          .having(
            (event) => event.retainedPrefixPointsTraversed,
            'traversed',
            0,
          )
          .having((event) => event.retainedPrefixPointsCopied, 'copied', 0),
    ),
  );

  final terminalSource = <Offset>[
    for (var index = 0; index <= 8000; index += 1)
      Offset(index.toDouble(), ((index * 13) % 31).toDouble()),
  ];
  final terminalRead = _FakeReadPort(erasedIds: [CanvasElementId('a')]);
  final terminalEngine = _eraserEngine(terminalRead);
  terminalEngine.handlePointerSample(
    _sample(2, terminalSource.first, CanvasPointerLifecyclePhase.down),
    _context(1),
  );
  for (var index = 1; index < terminalSource.length - 1; index += 1) {
    terminalEngine.handlePointerSample(
      _sample(2, terminalSource[index], CanvasPointerLifecyclePhase.move),
      _context(1),
    );
  }
  final terminal = terminalEngine.handlePointerSample(
    _sample(2, terminalSource.last, CanvasPointerLifecyclePhase.up),
    _context(1),
  );
  final expected = [
    for (var index = 0; index < 4000; index += 1)
      terminalSource[(index * (terminalSource.length - 1)) ~/ 3999],
  ];
  final intent = terminal.eraserCommit as EraserCommitIntent;
  expect(terminalRead.lastTerminalCorridor, expected);
  expect(intent.corridorPointCount, expected.length);
  expect(expected.first, terminalSource.first);
  expect(expected.last, terminalSource.last);
}

DeletionEntryFacts _projectedEntry() => DeletionEntryFacts(
  element: CanvasRectElement(id: CanvasElementId('a'), size: const Size(1, 1)),
  layerId: CanvasLayerId('layer-a'),
  elementIndex: 0,
  orderToken: 0,
);

// The routing assertions stay together to prove session capture, preview reads,
// terminal reads, and admission handoff for one public pointer sequence.
// ignore: halstead-volume, source-lines-of-code
void _verifyEraserInteractionRouting() {
  final readPort = _FakeReadPort(erasedIds: [CanvasElementId('erasable-a')]);
  final engine = _eraserEngine(readPort);
  final routeEvents = <InteractionEraserRouteWorkEvent>[];
  late PointerEraserCapture downCapture;

  final result = InteractionEngine.observeEraserRouteWork(routeEvents.add, () {
    final down = engine.handlePointerSample(
      _sample(1, Offset.zero, CanvasPointerLifecyclePhase.down),
      _context(1),
    );
    final capture = engine.activeSession?.eraserCapture;
    if (capture == null) {
      fail('eraser down did not retain its capture');
    }
    downCapture = capture;
    final move = engine.handlePointerSample(
      _sample(1, const Offset(2, 3), CanvasPointerLifecyclePhase.move),
      _context(1),
    );
    final terminal = engine.handlePointerSample(
      _sample(1, const Offset(4, 5), CanvasPointerLifecyclePhase.up),
      _context(1),
    );
    return (down: down, move: move, terminal: terminal);
  });
  final down = result.down;
  final move = result.move;
  final terminal = result.terminal;

  expect(down.kind, InteractionPointerAdmissionKind.admitted);
  expect(move.kind, InteractionPointerAdmissionKind.admitted);
  expect(engine.activeSession?.kind, PointerSessionKind.drawEraserPointer);
  expect(engine.activeSession?.eraserCapture?.points, [
    Offset.zero,
    const Offset(2, 3),
    const Offset(4, 5),
  ]);
  expect(engine.activeSession?.eraserCapture, same(downCapture));
  expect(downCapture.points.last, const Offset(4, 5));
  expect(engine.preview, isA<CanvasEraserPreview>());
  final intent = terminal.eraserCommit as EraserCommitIntent;
  expect(intent.erasedElementIds, [CanvasElementId('erasable-a')]);
  expect(intent.corridorPointCount, 3);
  expect(terminal.strokeCommit, isNull);
  expect(readPort.previewReadCount, 2);
  expect(readPort.terminalReadCount, 1);
  expect(routeEvents, [
    InteractionEraserRouteWorkEvent.downSnapshot,
    InteractionEraserRouteWorkEvent.previewPublished,
    InteractionEraserRouteWorkEvent.moveSnapshot,
    InteractionEraserRouteWorkEvent.previewPublished,
    InteractionEraserRouteWorkEvent.terminalSnapshot,
  ]);
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

void _verifyEraserCleanupDoesNoCaptureWork() {
  _expectEraserCleanupWithoutWork(CanvasPointerLifecyclePhase.cancel, 1);
  _expectEraserCleanupWithoutWork(CanvasPointerLifecyclePhase.up, 2);
  _expectNamedEraserCleanupWithoutWork(
    PointerCleanupReason.modeToolChange,
    (engine) =>
        engine.setDrawStyle(CanvasDrawStyle(tool: CanvasDrawTool.marker)),
  );
  _expectNamedEraserCleanupWithoutWork(
    PointerCleanupReason.interactiveDisabled,
    (engine) => engine.interactiveDisabledCleanup(),
  );
  _expectNamedEraserCleanupWithoutWork(
    PointerCleanupReason.preparedLoadSuccess,
    (engine) => engine.prepareLoadCleanup(),
  );
  _expectNamedEraserCleanupWithoutWork(
    PointerCleanupReason.dispose,
    (engine) => engine.disposeCleanup(),
  );
}

// The four lifecycle owners intentionally share one capture-release oracle.
// ignore: halstead-volume
void _expectNamedEraserCleanupWithoutWork(
  PointerCleanupReason expectedReason,
  Object? Function(InteractionEngine engine) operation,
) {
  final engine = _eraserEngine(_FakeReadPort())
    ..handlePointerSample(
      _sample(1, Offset.zero, CanvasPointerLifecyclePhase.down),
      _context(1),
    );
  final capture = engine.activeSession?.eraserCapture;
  if (capture == null) {
    fail('eraser down did not retain a capture');
  }
  final captureEvents = <PointerEraserCaptureWorkEvent>[];
  final routeEvents = <InteractionEraserRouteWorkEvent>[];
  final cleanupEvents = <InteractionCleanupWorkEvent>[];
  final cleanupReasons = <PointerCleanupReason>[];

  InteractionEngine.observeCleanup(
    cleanupReasons.add,
    () => InteractionEngine.observeCleanupWork(
      cleanupEvents.add,
      () => PointerEraserCapture.observeWork(
        captureEvents.add,
        () => InteractionEngine.observeEraserRouteWork(
          routeEvents.add,
          () => operation(engine),
        ),
      ),
    ),
  );

  expect(cleanupReasons, [expectedReason]);
  expect(engine.activeSession, isNull);
  expect(captureEvents, isEmpty);
  expect(routeEvents, isEmpty);
  expect(cleanupEvents, contains(InteractionCleanupWorkEvent.sessionReleased));
}

void _expectEraserCleanupWithoutWork(
  CanvasPointerLifecyclePhase phase,
  int terminalEpoch,
) {
  final engine = _eraserEngine(_FakeReadPort())
    ..handlePointerSample(
      _sample(1, Offset.zero, CanvasPointerLifecyclePhase.down),
      _context(1),
    );
  final capture = engine.activeSession?.eraserCapture;
  if (capture == null) {
    fail('eraser down did not retain a capture');
  }
  final captureEvents = <PointerEraserCaptureWorkEvent>[];
  final routeEvents = <InteractionEraserRouteWorkEvent>[];
  final cleanupEvents = <InteractionCleanupWorkEvent>[];

  InteractionEngine.observeCleanupWork(
    cleanupEvents.add,
    () => PointerEraserCapture.observeWork(
      captureEvents.add,
      () => InteractionEngine.observeEraserRouteWork(
        routeEvents.add,
        () => engine.handlePointerSample(
          _sample(1, const Offset(4, 5), phase),
          _context(terminalEpoch),
        ),
      ),
    ),
  );

  expect(engine.activeSession, isNull);
  expect(captureEvents, isEmpty);
  expect(routeEvents, isEmpty);
  expect(cleanupEvents, contains(InteractionCleanupWorkEvent.sessionReleased));
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

  final request = second.contextRequest?.pendingRequest;
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
    second.contextRequest?.pendingRequest.requestId,
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
    second.contextRequest?.pendingRequest.requestId,
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

void _verifyContextTapMissingTimestampsMatch() {
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
  expect(second.kind, InteractionPointerAdmissionKind.admitted);
  final request = second.contextRequest?.pendingRequest;
  expect(request, isNotNull);
  expect(request?.requestId, CanvasInteractionRequestId('request-0'));
  expect(request?.timestampHintMs, isNull);
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

  expect(request?.pendingRequest.timestampHintMs, 5);
  expect(timestampReads, 0);
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
  Iterable<DeletionEntryFacts> erasedEntries = const [],
  bool exactBudgetExceeded = false,
}) {
  final ids = List<CanvasElementId>.unmodifiable(erasedIds);
  final entries = erasedEntries.isEmpty
      ? List<DeletionEntryFacts>.unmodifiable(
          ids.map(
            (id) => DeletionEntryFacts(
              element: CanvasRectElement(id: id, size: const Size(1, 1)),
              layerId: CanvasLayerId('fixture-layer'),
              elementIndex: 0,
              orderToken: 0,
            ),
          ),
        )
      : List<DeletionEntryFacts>.unmodifiable(erasedEntries);
  return EraserReadFacts.terminal(
    corridorPoints: corridor,
    erasedEntryProjection: DeletionEntryProjection(entries),
    eraserThickness: 7,
    controllerEpoch: 1,
    documentRevision: 0,
    exactCheckCount: ids.length,
    exactBudgetExceeded: exactBudgetExceeded,
    query: InteractionReadQueryFacts.candidates(
      candidateCount: ids.length,
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
  List<Offset>? lastPreviewCorridor;
  List<Offset>? lastTerminalCorridor;
  void Function()? onDirectContextRead;

  int get previewReadCount => _previewReads;
  int get terminalReadCount => _terminalReads;
  int get directContextReads => _directContextReads;
  int get pendingContextReads => _pendingContextReads;
  int get secondContextReads => _secondContextReads;

  @override
  EraserReadFacts eraserPreviewFacts(EraserReadRequest request) {
    _previewReads += 1;
    lastPreviewCorridor = request.corridorPoints;

    return _eraserFacts(corridor: request.corridorPoints, erasedIds: const []);
  }

  @override
  EraserReadFacts eraserTerminalFacts(EraserReadRequest request) {
    _terminalReads += 1;
    lastTerminalCorridor = request.corridorPoints;

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
    return MarqueeCommitFacts(
      previousSelectedIds: const [],
      nextSelectedIds: const [],
      controllerEpoch: 1,
      selectionRevision: 0,
      rectWorld: request.rectWorld,
    );
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
      controllerEpoch: 1,
      documentRevision: 0,
    ),
  );
}
