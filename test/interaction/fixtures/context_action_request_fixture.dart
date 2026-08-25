// This context action fixture exercises the runtime facade, direct interaction
// engine admission, frame facts, spatial facts, diagnostics, and pointer stream
// delivery together. Keeping those seams in one file makes regressions easier
// to localize than splitting the same context flow into metric-shaped fixtures.
// ignore_for_file: number-of-imports

import 'dart:async';
import 'dart:ui';
import "../../support/runtime_root_with_committed_document_seed.dart";

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/deletion_entry_projection_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/selection_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/touched_set.dart';
import 'package:iwb_canvas_engine/src/diagnostics/diagnostic_code.dart';
import 'package:iwb_canvas_engine/src/diagnostics/diagnostics_hub.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_kernel.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_policy.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_pointer_context.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_interaction_diagnostics_adapter.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_interaction_read_adapter.dart';

void main() {
  test('direct content double tap emits one content request', () {
    return expectLater(_verifyDirectContentRequest(), completes);
  });
  test('direct content double tap uses context hit bounds', () {
    return expectLater(_verifyPaddedContextHitRequest(), completes);
  });
  test('direct empty double tap emits one empty request', () {
    return expectLater(_verifyDirectEmptyRequest(), completes);
  });
  _registerAsyncContextRequestStreamTests();
  test('non-finite direct double tap is rejected before timestamp', () {
    return expectLater(
      _verifyNonFiniteDirectRejectsBeforeTimestamp(),
      completes,
    );
  });
  _registerRejectedContextTargetTests();
  _registerPointerSampleContextTapTests();
}

void _registerPointerSampleContextTapTests() {
  test('pointer sample down-up double tap emits one request', () {
    return expectLater(_verifyPointerSampleDoubleTapRequest(), completes);
  });
  test('pointer sample selection tap still starts double tap history', () {
    return expectLater(_verifySelectionTapStartsDoubleTapHistory(), completes);
  });
  test('pointer sample double tap works on selected content', () {
    return expectLater(_verifySelectedContentPointerRequest(), completes);
  });
  test('pointer sample mismatch clears without public effects', () {
    return expectLater(_verifyPointerSampleMismatchIsPrivate(), completes);
  });
  test('pointer tap movement inside tap slop stays tap-only', () {
    return expectLater(_verifyPointerTapInsideTapSlopIsTapOnly(), completes);
  });
  test('private pointer tap does not leak through later state', () {
    return expectLater(_verifyPrivateTapRevisionStaysPrivate(), completes);
  });
}

void _registerAsyncContextRequestStreamTests() {
  test('accepted direct request delivery is asynchronous', () {
    return expectLater(_verifyAcceptedDirectRequestIsAsync(), completes);
  });
  test('direct requests resolve delivery timestamps monotonically', () {
    return expectLater(_verifyDirectRequestTimestampOrder(), completes);
  });
  test('pointer requests resolve delivery timestamps monotonically', () {
    return expectLater(_verifyPointerRequestTimestampOrder(), completes);
  });
  test('dispose suppresses accepted queued request before stream done', () {
    return expectLater(
      _verifyDisposeSuppressesQueuedRequestBeforeDone(),
      completes,
    );
  });
}

void _registerRejectedContextTargetTests() {
  test(
    'invalid-index direct target read emits no public request or effects',
    () {
      return expectLater(_verifyInvalidIndexTargetRejectsPublicly(), completes);
    },
  );
  test('stale-index direct target read emits no public request or effects', () {
    return expectLater(_verifyStaleIndexTargetRejectsPublicly(), completes);
  });
  test('budget direct target read emits no public request or effects', () {
    return expectLater(_verifyBudgetTargetRejectsPublicly(), completes);
  });
  test('unresolved direct target candidate rejects before timestamp', () {
    return expectLater(
      _verifyUnresolvedTargetRejectsBeforeTimestamp(),
      completes,
    );
  });
}

Future<void> _verifyDirectContentRequest() async {
  final scenario = _RuntimeContextRequestScenario();
  try {
    scenario.root.handleDoubleTap(
      position: const Offset(20, 0),
      timestampMs: 7,
    );
    await _flushEvents();

    _expectNoIncidentalEffects(scenario);
    _expectContentRequest(scenario.requests.single);
  } finally {
    await scenario.dispose();
  }
}

void _expectNoIncidentalEffects(_RuntimeContextRequestScenario scenario) {
  expect(scenario.stateEvents, isEmpty);
  expect(scenario.actions, isEmpty);
  expect(scenario.effectBatches, isEmpty);
}

void _expectContentRequest(
  CanvasContextActionRequested request, {
  Offset position = const Offset(20, 0),
}) {
  expect(request.trigger, CanvasContextActionTrigger.doubleTap);
  expect(request.timestampMs, 7);
  expect(request.viewPosition, position);
  expect(request.worldPosition, position);
  expect(request.controllerEpoch, 0);
  expect(request.documentRevision, 0);
  final target = request.target as CanvasContentElementContextActionTarget;
  expect(target.elementSnapshot.id, CanvasElementId('rect-a'));
  expect(target.boundsWorld.left, 15);
}

Future<void> _verifyDirectEmptyRequest() async {
  final scenario = _RuntimeContextRequestScenario();
  try {
    scenario.root.handleDoubleTap(position: const Offset(200, 200));
    await _flushEvents();

    expect(scenario.requests, hasLength(1));
    expect(
      scenario.requests.single.target,
      isA<CanvasEmptyCanvasContextActionTarget>(),
    );
    _expectNoIncidentalEffects(scenario);
  } finally {
    await scenario.dispose();
  }
}

Future<void> _verifyAcceptedDirectRequestIsAsync() async {
  final scenario = _RuntimeContextRequestScenario();
  try {
    scenario.root.handleDoubleTap(
      position: const Offset(20, 0),
      timestampMs: 7,
    );
    expect(scenario.requests, isEmpty);

    await _flushEvents();

    expect(scenario.requests, hasLength(1));
    _expectContentRequest(scenario.requests.single);
    _expectNoIncidentalEffects(scenario);
  } finally {
    await scenario.dispose();
  }
}

Future<void> _verifyDirectRequestTimestampOrder() async {
  final scenario = _RuntimeContextRequestScenario();
  try {
    scenario.root.handleDoubleTap(
      position: const Offset(20, 0),
      timestampMs: 5,
    );
    await _flushEvents();
    scenario.root.handleDoubleTap(
      position: const Offset(200, 200),
      timestampMs: 2,
    );
    await _flushEvents();
    scenario.root.handleDoubleTap(position: const Offset(20, 0));
    await _flushEvents();

    expect(scenario.requests.map((request) => request.timestampMs), [5, 6, 7]);
  } finally {
    await scenario.dispose();
  }
}

Future<void> _verifyPointerRequestTimestampOrder() async {
  final scenario = _RuntimeContextRequestScenario();
  try {
    _tapPointer(scenario.root, const Offset(20, 0), timestampMs: 1);
    _tapPointer(scenario.root, const Offset(21, 0), timestampMs: 5);
    await _flushEvents();
    _tapPointer(scenario.root, const Offset(20, 0), timestampMs: 1);
    _tapPointer(scenario.root, const Offset(21, 0), timestampMs: 2);
    await _flushEvents();
    _tapPointer(scenario.root, const Offset(20, 0));
    _tapPointer(scenario.root, const Offset(21, 0));
    await _flushEvents();

    expect(scenario.requests.map((request) => request.timestampMs), [5, 6, 7]);
  } finally {
    await scenario.dispose();
  }
}

Future<void> _verifyDisposeSuppressesQueuedRequestBeforeDone() async {
  final root = runtimeRootWithCommittedDocumentSeed(
    _document(selectableContent: false, hitPadding: 0),
    config: const CanvasRuntimeConfig(
      deletionCommitResolver: _acceptDeletionCommit,
    ),
  );
  final events = <String>[];
  final done = Completer<void>();
  root.contextActionRequests.listen(
    (request) {
      events.add('request:${request.requestId.value}');
    },
    onDone: () {
      events.add('done');
      done.complete();
    },
  );

  root.handleDoubleTap(position: const Offset(20, 0), timestampMs: 7);
  root.dispose();

  await done.future;

  expect(events, ['done']);
}

Future<void> _verifyPaddedContextHitRequest() async {
  final scenario = _RuntimeContextRequestScenario(hitPadding: 4);
  try {
    scenario.root.handleDoubleTap(
      position: const Offset(12, 0),
      timestampMs: 7,
    );
    await _flushEvents();

    expect(scenario.requests, hasLength(1));
    _expectContentRequest(
      scenario.requests.single,
      position: const Offset(12, 0),
    );
    _expectNoIncidentalEffects(scenario);
  } finally {
    await scenario.dispose();
  }
}

Future<void> _verifyNonFiniteDirectRejectsBeforeTimestamp() async {
  final scenario = _RuntimeContextRequestScenario();
  try {
    scenario.root.handleDoubleTap(position: const Offset(double.nan, 1));
    scenario.root.handleDoubleTap(position: const Offset(200, 200));
    await _flushEvents();

    expect(scenario.requests, hasLength(1));
    expect(scenario.requests.single.timestampMs, 0);
    expect(scenario.stateEvents, isEmpty);
    expect(scenario.actions, isEmpty);
    expect(scenario.effectBatches, isEmpty);
  } finally {
    await scenario.dispose();
  }
}

Future<void> _verifyInvalidIndexTargetRejectsPublicly() async {
  final scenario = _RuntimeContextRequestScenario(
    initialDocument: CanvasDocument(),
  );
  try {
    scenario.root.spatialKernel.applyTouched(
      scenario.root,
      TouchedSet(updatedElementIds: [CanvasElementId('missing')]),
    );

    scenario.root.handleDoubleTap(position: Offset.zero);
    await _flushEvents();

    _expectRejectedContextTargetIsPrivate(scenario);
  } finally {
    await scenario.dispose();
  }
}

Future<void> _verifyStaleIndexTargetRejectsPublicly() async {
  final scenario = _RuntimeContextRequestScenario();
  try {
    scenario.root.spatialKernel.resetEmpty(1);

    scenario.root.handleDoubleTap(position: const Offset(20, 0));
    await _flushEvents();

    _expectRejectedContextTargetIsPrivate(scenario);
  } finally {
    await scenario.dispose();
  }
}

Future<void> _verifyBudgetTargetRejectsPublicly() async {
  final scenario = _RuntimeContextRequestScenario(
    initialDocument: _fallbackBudgetDocument(),
  );
  try {
    scenario.root.spatialKernel.applyTouched(
      scenario.root,
      TouchedSet(updatedElementIds: [CanvasElementId('missing')]),
    );

    scenario.root.handleDoubleTap(position: Offset.zero);
    await _flushEvents();

    _expectRejectedContextTargetIsPrivate(scenario);
  } finally {
    await scenario.dispose();
  }
}

Future<void> _verifyUnresolvedTargetRejectsBeforeTimestamp() {
  final fixture = _unresolvedTopCandidateFixture();
  var timestampReservations = 0;

  final intent = fixture.engine.handleDoubleTap(
    const Offset(5, 5),
    InteractionPointerContext(
      viewCameraOffset: Offset.zero,
      controllerEpoch: 0,
      resolveOutputTimestamp: (_) {
        timestampReservations += 1;

        return 1;
      },
    ),
    timestampHintMs: 1,
  );

  _expectUnresolvedTargetRejected(
    fixture.hub,
    intent: intent,
    timestampReservations: timestampReservations,
  );

  return Future<void>.value();
}

_DirectContextTargetFixture _unresolvedTopCandidateFixture() {
  final frame = _FakeContextFrameFactsPort([
    _contextFrameFacts(id: 'lower', orderToken: 1),
    _contextFrameFacts(id: 'top', orderToken: 2),
  ]);
  final spatial = SpatialKernel()..rebuild(frame);
  frame.unresolvedIds.add(CanvasElementId('top'));
  final hub = DiagnosticsHub(policy: const CanvasDiagnosticPolicy.summary());
  final engine = InteractionEngine(
    initialMode: CanvasInteractionMode.move,
    initialDrawStyle: CanvasDrawStyle(),
    pointerPolicy: CanvasPointerPolicy(),
    diagnosticsSink: RuntimeInteractionDiagnosticsAdapter(hub),
  );
  engine.attachReadPort(
    RuntimeInteractionReadAdapter(
      frame: frame,
      documentSummary: () => const CanvasDocumentSummary(
        elementCount: 2,
        layerCount: 1,
        resourceCount: 0,
      ),
      selection: const _EmptySelectionFactsPort(),
      spatial: spatial,
      controllerEpoch: () => 0,
      deletionEntryProjection: const _NoDeletionEntryProjection(),
    ),
  );

  return _DirectContextTargetFixture(engine: engine, hub: hub);
}

final class _NoDeletionEntryProjection implements DeletionEntryProjectionPort {
  const _NoDeletionEntryProjection();

  @override
  List<DeletionEntryFacts> projectDeletionEntries(
    Iterable<CanvasElementId> ids,
  ) => const [];
}

void _expectUnresolvedTargetRejected(
  DiagnosticsHub hub, {
  required Object? intent,
  required int timestampReservations,
}) {
  expect(intent, isNull);
  expect(timestampReservations, 0);
  expect(
    hub.records.map((record) => record.code),
    contains(
      const DiagnosticCode.interaction(
        InteractionDiagnosticCode.staleCandidateRejected,
      ),
    ),
  );
}

class _DirectContextTargetFixture {
  const _DirectContextTargetFixture({required this.engine, required this.hub});

  final InteractionEngine engine;
  final DiagnosticsHub hub;
}

void _expectRejectedContextTargetIsPrivate(
  _RuntimeContextRequestScenario scenario,
) {
  expect(scenario.requests, isEmpty);
  _expectNoIncidentalEffects(scenario);
}

Future<void> _verifyPointerSampleDoubleTapRequest() async {
  final scenario = _RuntimeContextRequestScenario();
  try {
    _tapPointer(scenario.root, const Offset(20, 0), timestampMs: 1);
    _tapPointer(scenario.root, const Offset(21, 0), timestampMs: 2);
    await _flushEvents();

    expect(scenario.requests, hasLength(1));
    final request = scenario.requests.single;
    expect(request.timestampMs, 2);
    expect(request.target, isA<CanvasContentElementContextActionTarget>());
    expect(scenario.stateEvents, isEmpty);
    expect(scenario.actions, isEmpty);
    expect(scenario.effectBatches, isEmpty);
  } finally {
    await scenario.dispose();
  }
}

Future<void> _verifySelectionTapStartsDoubleTapHistory() async {
  final scenario = _RuntimeContextRequestScenario(selectableContent: true);
  try {
    _tapPointer(scenario.root, const Offset(20, 0), timestampMs: 1);
    _expectSelectionTapSetupStarted(scenario);

    _tapPointer(scenario.root, const Offset(21, 0), timestampMs: 2);
    await _flushEvents();

    _expectSelectionTapDoubleTapRequest(scenario);
  } finally {
    await scenario.dispose();
  }
}

void _expectSelectionTapSetupStarted(_RuntimeContextRequestScenario scenario) {
  expect(scenario.root.selection.selectedElementIds, {
    CanvasElementId('rect-a'),
  });
  expect(scenario.actions, hasLength(1));
  expect(scenario.actions.single.type, CanvasActionType.selectMarquee);
  expect(scenario.effectBatches, hasLength(1));
}

void _expectSelectionTapDoubleTapRequest(
  _RuntimeContextRequestScenario scenario,
) {
  expect(scenario.requests, hasLength(1));
  final request = scenario.requests.single;
  expect(request.timestampMs, 2);
  expect(request.target, isA<CanvasContentElementContextActionTarget>());
  expect(scenario.actions, hasLength(1));
  expect(scenario.effectBatches, hasLength(1));
}

Future<void> _verifySelectedContentPointerRequest() async {
  final scenario = _RuntimeContextRequestScenario(selectableContent: true);
  try {
    scenario.root.selection.setSelection([CanvasElementId('rect-a')]);
    scenario.stateEvents.clear();

    _tapPointer(scenario.root, const Offset(20, 0), timestampMs: 1);
    _tapPointer(scenario.root, const Offset(21, 0), timestampMs: 2);
    await _flushEvents();

    expect(scenario.requests, hasLength(1));
    expect(
      scenario.requests.single.target,
      isA<CanvasContentElementContextActionTarget>(),
    );
    expect(scenario.stateEvents, isEmpty);
    expect(scenario.actions, isEmpty);
    expect(scenario.effectBatches, isEmpty);
  } finally {
    await scenario.dispose();
  }
}

Future<void> _verifyPointerSampleMismatchIsPrivate() async {
  final scenario = _RuntimeContextRequestScenario();
  try {
    _tapPointer(scenario.root, const Offset(20, 0), timestampMs: 1);
    _tapPointer(scenario.root, const Offset(200, 200), timestampMs: 2);
    await _flushEvents();

    expect(scenario.requests, isEmpty);
    expect(scenario.stateEvents, isEmpty);
    expect(scenario.actions, isEmpty);
    expect(scenario.effectBatches, isEmpty);
  } finally {
    await scenario.dispose();
  }
}

Future<void> _verifyPointerTapInsideTapSlopIsTapOnly() async {
  final scenario = _RuntimeContextRequestScenario(
    config: CanvasRuntimeConfig(
      deletionCommitResolver: _acceptDeletionCommit,
      pointerPolicy: CanvasPointerPolicy(tapSlop: 8, dragStartSlop: 4),
    ),
  );
  try {
    _tapPointer(
      scenario.root,
      const Offset(200, 200),
      movePosition: const Offset(205, 200),
      timestampMs: 1,
    );
    await _flushEvents();

    expect(scenario.requests, isEmpty);
    expect(scenario.root.preview, isA<CanvasNoPreview>());
    expect(scenario.actions, isEmpty);
    expect(scenario.effectBatches, isEmpty);
  } finally {
    await scenario.dispose();
  }
}

Future<void> _verifyPrivateTapRevisionStaysPrivate() async {
  final scenario = _RuntimeContextRequestScenario();
  try {
    _tapPointer(scenario.root, const Offset(200, 200), timestampMs: 1);
    final interactionRevision = scenario.root.state.value.revisions.interaction;
    scenario.root.panCameraBy(const Offset(1, 0));
    await _flushEvents();

    expect(scenario.requests, isEmpty);
    expect(scenario.actions, isEmpty);
    expect(scenario.effectBatches, isEmpty);
    expect(scenario.stateEvents, hasLength(1));
    expect(scenario.stateEvents.single.revisions.viewCamera, 1);
    expect(
      scenario.stateEvents.single.revisions.interaction,
      interactionRevision,
    );
  } finally {
    await scenario.dispose();
  }
}

final class _RuntimeContextRequestScenario {
  _RuntimeContextRequestScenario({
    bool selectableContent = false,
    double hitPadding = 0,
    CanvasRuntimeConfig config = const CanvasRuntimeConfig(
      deletionCommitResolver: _acceptDeletionCommit,
    ),
    CanvasDocument? initialDocument,
  }) {
    root = runtimeRootWithCommittedDocumentSeed(
      initialDocument ??
          _document(
            selectableContent: selectableContent,
            hitPadding: hitPadding,
          ),
      config: config,
      commitEffectObserver: effectBatches.add,
    );
    root.state.addListener(() {
      stateEvents.add(root.state.value);
    });
    requestSubscription = root.contextActionRequests.listen(requests.add);
    actionSubscription = root.actions.listen(actions.add);
  }

  late final RuntimeRoot root;
  late final StreamSubscription<CanvasContextActionRequested>
  requestSubscription;
  late final StreamSubscription<CanvasActionCommitted> actionSubscription;
  final List<CanvasContextActionRequested> requests = [];
  final List<CanvasActionCommitted> actions = [];
  final List<CanvasRuntimeState> stateEvents = [];
  final List<List<CommitDeliveryEffect>> effectBatches = [];

  Future<void> dispose() async {
    await requestSubscription.cancel();
    await actionSubscription.cancel();
    root.dispose();
  }
}

CanvasDocument _fallbackBudgetDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          for (var index = 0; index <= kCanvasMaxFallbackCandidates; index += 1)
            CanvasRectElement(
              id: CanvasElementId('fallback-$index'),
              size: const Size(10, 10),
              transform: CanvasTransform.translation(Offset(index * 20, 0)),
            ),
        ],
      ),
    ],
  );
}

Future<void> _flushEvents() => Future<void>.delayed(Duration.zero);

void _tapPointer(
  RuntimeRoot root,
  Offset position, {
  int? timestampMs,
  Offset? movePosition,
}) {
  root.handlePointer(
    CanvasPointerSample(
      pointerId: 1,
      position: position,
      phase: CanvasPointerLifecyclePhase.down,
      kind: PointerDeviceKind.touch,
      timestampMs: timestampMs,
    ),
  );
  final moved = movePosition;
  if (moved != null) {
    root.handlePointer(
      CanvasPointerSample(
        pointerId: 1,
        position: moved,
        phase: CanvasPointerLifecyclePhase.move,
        kind: PointerDeviceKind.touch,
        timestampMs: timestampMs,
      ),
    );
  }
  root.handlePointer(
    CanvasPointerSample(
      pointerId: 1,
      position: movePosition ?? position,
      phase: CanvasPointerLifecyclePhase.up,
      kind: PointerDeviceKind.touch,
      timestampMs: timestampMs,
    ),
  );
}

CanvasDocument _document({
  required bool selectableContent,
  required double hitPadding,
}) {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('rect-a'),
            size: const Size(10, 10),
            transform: CanvasTransform.translation(const Offset(20, 0)),
            isSelectable: selectableContent,
            hitPadding: hitPadding,
          ),
        ],
      ),
    ],
  );
}

FrameElementFacts _contextFrameFacts({
  required String id,
  required int orderToken,
}) {
  return FrameElementFacts(
    id: CanvasElementId(id),
    kind: CanvasElementKind.rect,
    revision: 0,
    generation: 0,
    orderToken: orderToken,
    locationKind: FrameElementLocationKind.content,
    transform: CanvasTransform.identity,
    opacity: 1,
    hitPadding: 0,
    isVisible: true,
    isSelectable: true,
    isLocked: false,
    isDeletable: true,
    isTransformable: true,
    metadata: const CanvasMetadata.empty(),
    size: const Size(10, 10),
  );
}

final class _EmptySelectionFactsPort implements SelectionFactsPort {
  const _EmptySelectionFactsPort();

  @override
  SelectionFacts get selectionFacts {
    return SelectionFacts(selectedElementIds: const [], selectionRevision: 0);
  }
}

final class _FakeContextFrameFactsPort implements FrameFactsPort {
  _FakeContextFrameFactsPort(Iterable<FrameElementFacts> facts)
    : _facts = {for (final fact in facts) fact.id: fact};

  final Map<CanvasElementId, FrameElementFacts> _facts;
  final Set<CanvasElementId> unresolvedIds = {};

  @override
  FrameRevisionFacts get frameRevisions {
    return const FrameRevisionFacts(
      documentRevision: 0,
      structuralRevision: 0,
      boundsRevision: 0,
      elementVisualRevision: 0,
      backgroundRevision: 0,
      gridRevision: 0,
      resourceRevision: 0,
    );
  }

  @override
  CanvasBackground get background => const CanvasBackground();

  @override
  int elementCount(int structuralRevision) => _facts.length;

  @override
  List<FrameElementHandle> elementHandles(int structuralRevision) {
    return [
      for (final facts in _facts.values)
        FrameElementHandle(
          id: facts.id,
          structuralRevision: structuralRevision,
          generation: facts.generation,
          orderToken: facts.orderToken,
        ),
    ];
  }

  @override
  FrameElementHandle? elementHandleForId(
    int structuralRevision,
    CanvasElementId id,
  ) {
    final facts = _facts[id];
    if (facts == null) {
      return null;
    }

    return FrameElementHandle(
      id: facts.id,
      structuralRevision: structuralRevision,
      generation: facts.generation,
      orderToken: facts.orderToken,
    );
  }

  @override
  FrameElementFacts? resolveElement(FrameElementHandle handle) {
    if (unresolvedIds.contains(handle.id)) {
      return null;
    }

    return _facts[handle.id];
  }

  @override
  FrameResourceDescriptorFacts? resourceDescriptor(CanvasResourceId id) => null;
}

CanvasDeletionDecision _acceptDeletionCommit(CanvasDeletionCommitRequest _) =>
    CanvasDeletionDecision.accept;
