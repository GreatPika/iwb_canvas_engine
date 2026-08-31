// This fixture deliberately observes the real interaction, read, spatial,
// Store, and RuntimeRoot owners on one terminal trace; moving imports into a
// wrapper would hide the no-partial boundary it is responsible for proving.
// ignore_for_file: number-of-imports

import 'dart:ui' show Offset, PointerDeviceKind, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/deletion_entry_projection_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/diagnostics/diagnostics_hub.dart';
import 'package:iwb_canvas_engine/src/geometry/geometry_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/hit_test_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_kernel.dart';
import 'package:iwb_canvas_engine/src/interaction/eraser_machine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_pointer_context.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_read_port.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_session_identity.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_interaction_diagnostics_adapter.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_interaction_read_adapter.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_interaction_read_mapping.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import '../../support/runtime_root_with_committed_document_seed.dart';

// The named cases are the accepted no-partial taxonomy; keeping registration
// adjacent to their one fixture avoids a parallel evidence owner.
// ignore: halstead-volume, maintainability-index, source-lines-of-code
void main() {
  test('terminal budget overflow produces no partial commit intent', () {
    expect(_verifyTerminalOverflowNoPartialCommit, returnsNormally);
  });

  test('terminal budget overflow is cleanup-only through interaction', () {
    expect(_verifyTerminalOverflowInteractionCleanup, returnsNormally);
  });

  test('empty retained terminal has no partial runtime commit', () {
    expect(
      () => _verifyRuntimeTerminalNoPartialCommit(
        document: CanvasDocument(),
        terminalPosition: const Offset(20, 0),
        expectedRoute: _emptyRoute,
      ),
      returnsNormally,
    );
  });

  test('invalid retained terminal has no partial runtime commit', () {
    expect(
      () => _verifyRuntimeTerminalNoPartialCommit(
        document: CanvasDocument(),
        terminalPosition: const Offset(20, 0),
        forceInvalidSpatial: true,
        expectedRoute: _queryOnlyRoute,
      ),
      returnsNormally,
    );
  });

  test('spatial-overflow retained terminal has no partial runtime commit', () {
    expect(
      () => _verifyRuntimeTerminalNoPartialCommit(
        document: CanvasDocument(),
        downPosition: const Offset(-10000000, 0),
        terminalPosition: const Offset(10000000, 0),
        expectedRoute: _queryOnlyRoute,
        expectedBudgetReason:
            InteractionReadBudgetExceededReason.queryTileBudgetExceeded,
      ),
      returnsNormally,
    );
  });

  test(
    'candidate-overflow retained terminal has no partial runtime commit',
    () {
      expect(
        () => _verifyRuntimeTerminalNoPartialCommit(
          document: _candidateOverflowDocument(),
          terminalPosition: const Offset(20, 0),
          expectedRoute: _queryOnlyRoute,
          expectedBudgetReason: InteractionReadBudgetExceededReason
              .fallbackCandidateBudgetExceeded,
        ),
        returnsNormally,
      );
    },
  );

  test('stale retained terminal has no partial runtime commit', () {
    expect(_verifyStaleRuntimeTerminalNoPartialCommit, returnsNormally);
  });
  test('adapter candidate-limit terminal has no partial runtime commit', () {
    expect(
      () => RuntimeInteractionReadAdapter.injectEraserTerminalBudget(
        candidateLimit: 1,
        exactCheckLimit: 32768,
        operation: () => _verifyRuntimeTerminalNoPartialCommit(
          document: _twoCandidateDocument(),
          terminalPosition: const Offset(20, 0),
          expectedRoute: _adapterBudgetRoute,
        ),
      ),
      returnsNormally,
    );
  });
  test('adapter exact-limit terminal has no partial runtime commit', () {
    expect(
      () => RuntimeInteractionReadAdapter.injectEraserTerminalBudget(
        candidateLimit: 4096,
        exactCheckLimit: 0,
        operation: () => _verifyRuntimeTerminalNoPartialCommit(
          document: _twoCandidateDocument(),
          terminalPosition: const Offset(20, 0),
          expectedRoute: _adapterBudgetRoute,
        ),
      ),
      returnsNormally,
    );
  });
}

const _queryOnlyRoute = [
  RuntimeEraserEntryRouteWorkKind.terminalReadStarted,
  RuntimeEraserEntryRouteWorkKind.corridorEnvelopeReady,
  RuntimeEraserEntryRouteWorkKind.spatialQueryReady,
];

const _emptyRoute = [
  ..._queryOnlyRoute,
  RuntimeEraserEntryRouteWorkKind.candidatesReady,
  RuntimeEraserEntryRouteWorkKind.exactEvaluationReady,
  RuntimeEraserEntryRouteWorkKind.exactHitIdsReady,
  RuntimeEraserEntryRouteWorkKind.entriesReady,
];

const _adapterBudgetRoute = [
  ..._queryOnlyRoute,
  RuntimeEraserEntryRouteWorkKind.candidatesReady,
  RuntimeEraserEntryRouteWorkKind.exactEvaluationReady,
];

void _verifyTerminalOverflowNoPartialCommit() {
  DiagnosticRecord.allocations.reset();
  final before = DiagnosticRecord.allocations.count;
  const machine = EraserMachine();
  final eraser = PointerEraserCapture(points: [Offset.zero], thickness: 6);

  final terminal = machine.terminal(
    input: EraserTerminalInput(
      sessionId: const PointerSessionId(1),
      pointerToken: const PointerSessionToken(2),
      eraser: eraser,
      facts: _facts(
        corridor: const [Offset.zero, Offset(10, 0)],
        erasedIds: [CanvasElementId('would-be-partial')],
        exactBudgetExceeded: true,
      ),
    ),
  );

  expect(terminal.intent, isNull);
  expect(DiagnosticRecord.allocations.count, before);
}

// The exact-budget boundary trace intentionally includes admission, read, and
// centralized cleanup so it can rule out work displaced into cleanup.
// ignore: halstead-volume
void _verifyTerminalOverflowInteractionCleanup() {
  DiagnosticRecord.allocations.reset();
  final hub = DiagnosticsHub(policy: const CanvasDiagnosticPolicy.summary());
  final readPort = _BudgetOverflowReadPort();
  final engine = _budgetOverflowEngine(hub, readPort);
  final before = DiagnosticRecord.allocations.count;

  final trace = <String>[];
  final terminal = _observeTerminalGeometryAndSpatialWork(
    trace,
    () => PointerEraserCapture.observeWork(
      (event) => trace.add('capture:${event.kind.name}'),
      () => InteractionEngine.observeEraserRouteWork(
        (event) => trace.add('interaction:${event.name}'),
        () => InteractionEngine.observeCleanupWork(
          (event) => trace.add('cleanup:${event.name}'),
          () => _runOverflowEraserGesture(engine),
        ),
      ),
    ),
  );

  _expectCleanupOnlyOverflow(terminal, engine);
  expect(
    trace.where(
      (event) =>
          event ==
          'interaction:${InteractionEraserRouteWorkEvent.terminalSnapshot.name}',
    ),
    hasLength(1),
  );
  expect(readPort.terminalReadCount, 1);
  expect(trace.where((event) => event.startsWith('geometry:')), isEmpty);
  expect(trace.where((event) => event.startsWith('spatial:')), isEmpty);
  _expectNoCaptureOrReadWorkAfterCleanup(trace);
  expect(hub.records, isEmpty);
  expect(DiagnosticRecord.allocations.count, before);
}

// These runtime cases remain in this geometry-owned no-partial fixture because
// they exercise the actual spatial/read boundary and the same centralized
// terminal cleanup that receives typed exact-budget facts below.
// ignore: halstead-volume, source-lines-of-code, maintainability-index, number-of-parameters
void _verifyRuntimeTerminalNoPartialCommit({
  required CanvasDocument document,
  required Offset terminalPosition,
  required List<RuntimeEraserEntryRouteWorkKind> expectedRoute,
  Offset downPosition = Offset.zero,
  bool forceInvalidSpatial = false,
  InteractionReadBudgetExceededReason? expectedBudgetReason,
}) {
  final root = runtimeRootWithCommittedDocumentSeed(document);
  addTearDown(root.dispose);
  final surface = Object();
  root.attachSurface(surface);
  addTearDown(() => root.detachSurface(surface));
  root.setInteractionMode(CanvasInteractionMode.draw);
  root.setDrawStyle(CanvasDrawStyle(tool: CanvasDrawTool.eraser));
  if (forceInvalidSpatial) {
    root.spatialKernel.rebuild(
      _FailingSpatialFrame(root.documentFacts.structuralRevision),
    );
  }
  final actions = <CanvasActionCommitted>[];
  final actionSubscription = root.actions.listen(actions.add);
  addTearDown(actionSubscription.cancel);
  root.handlePointer(_sample(CanvasPointerLifecyclePhase.down, downPosition));
  root.handlePointer(
    _sample(CanvasPointerLifecyclePhase.move, terminalPosition),
  );
  final beforeOwners = _PreacceptanceOwnerSnapshot.capture(root);
  final beforeSpatial = root.spatialKernel.snapshot;
  final beforeProjectionBuilds = root.projectionBuildCount;
  final terminalFrames = <RuntimeSurfaceFrameSignal>[];
  root.surfaceFrameSignal.addListener(() {
    final frame = root.surfaceFrameSignal.value;
    if (frame != null) terminalFrames.add(frame);
  });
  final trace = <String>[];
  final routeEvents = <RuntimeEraserEntryRouteWorkEvent>[];
  final preparation = <RuntimeDeletionRouteConstructionKind>[];
  final projectedEntries = <List<Object>>[];
  _observeTerminalGeometryAndSpatialWork(
    trace,
    () => PointerEraserCapture.observeWork(
      (event) => trace.add('capture:${event.kind.name}'),
      () => InteractionEngine.observeEraserRouteWork(
        (event) => trace.add('interaction:${event.name}'),
        () => InteractionEngine.observeCleanupWork(
          (event) => trace.add('cleanup:${event.name}'),
          () => RuntimeInteractionReadAdapter.observeEraserEntryRouteWork(
            (event) {
              routeEvents.add(event);
              trace.add('read:${event.kind.name}');
            },
            () => RuntimeRoot.observeDeletionRouteConstruction(
              preparation.add,
              () => DocumentStoreKernel.observeDeletionEntryProjection(
                (entries) => projectedEntries.add(List<Object>.of(entries)),
                () => root.handlePointer(
                  _sample(CanvasPointerLifecyclePhase.up, terminalPosition),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  expect(trace.where((event) => event.startsWith('geometry:')), [
    'geometry:${GeometryPolicyEraserWorkEvent.corridorEnvelope.name}',
  ]);
  expect(trace.where((event) => event.startsWith('spatial:')), [
    'spatial:${SpatialKernelEraserWorkEvent.queryEraser.name}',
  ]);
  _expectNoPartialRuntimeTerminal(
    root: root,
    beforeOwners: beforeOwners,
    beforeSpatial: beforeSpatial,
    beforeProjectionBuilds: beforeProjectionBuilds,
    actions: actions,
    preparation: preparation,
    projectedEntries: projectedEntries,
    terminalFrames: terminalFrames,
    trace: trace,
    expectedRoute: expectedRoute,
    routeEvents: routeEvents,
    expectedBudgetReason: expectedBudgetReason,
  );
}

// The stale route keeps its lifecycle, state, and cleanup observations
// together because no RuntimeRoot delivery is permitted after the mismatch.
// ignore: halstead-volume, source-lines-of-code
void _verifyStaleRuntimeTerminalNoPartialCommit() {
  final root = runtimeRootWithCommittedDocumentSeed(CanvasDocument());
  addTearDown(root.dispose);
  root.setInteractionMode(CanvasInteractionMode.draw);
  root.setDrawStyle(CanvasDrawStyle(tool: CanvasDrawTool.eraser));
  final engine = root.interactionEngine;
  engine.handlePointerSample(
    _sample(CanvasPointerLifecyclePhase.down, Offset.zero),
    _epochContext(1),
  );
  final before = root.state.value;
  final beforeSpatial = root.spatialKernel.snapshot;
  final beforeStructuralRevision = root.documentFacts.structuralRevision;
  final beforeProjectionBuilds = root.projectionBuildCount;
  final actions = <CanvasActionCommitted>[];
  final actionSubscription = root.actions.listen(actions.add);
  addTearDown(actionSubscription.cancel);
  final trace = <String>[];
  final terminal = _observeTerminalGeometryAndSpatialWork(
    trace,
    () => PointerEraserCapture.observeWork(
      (event) => trace.add('capture:${event.kind.name}'),
      () => InteractionEngine.observeCleanupWork(
        (event) => trace.add('cleanup:${event.name}'),
        () => RuntimeInteractionReadAdapter.observeEraserEntryRouteWork(
          (event) => trace.add('read:${event.kind.name}'),
          () => engine.handlePointerSample(
            _sample(CanvasPointerLifecyclePhase.up, const Offset(20, 0)),
            _epochContext(2),
          ),
        ),
      ),
    ),
  );
  expect(terminal.kind, InteractionPointerAdmissionKind.cleanupOnly);
  expect(root.interactionEngine.activeSession, isNull);
  expect(root.state.value.revisions.document, before.revisions.document);
  expect(root.state.value.revisions.selection, before.revisions.selection);
  expect(root.documentFacts.structuralRevision, beforeStructuralRevision);
  expect(root.projectionBuildCount, beforeProjectionBuilds);
  _expectSpatialSnapshotUnchanged(beforeSpatial, root.spatialKernel.snapshot);
  expect(actions, isEmpty);
  expect(trace.where((event) => event.startsWith('geometry:')), isEmpty);
  expect(trace.where((event) => event.startsWith('spatial:')), isEmpty);
  _expectNoCaptureOrReadWorkAfterCleanup(trace);
}

// The assertion compares every committed/derived owner that a rejected route
// could otherwise touch, while allowing the expected preview-clear repaint.
// This assertion consumes the one captured owner trace as a unit; splitting
// its state and work assertions would obscure the cross-owner no-partial rule.
// All pre-acceptance owner effects must be compared against the same captured
// terminal outcome; splitting the assertions would obscure partial effects.
// ignore: halstead-volume, number-of-parameters, source-lines-of-code
void _expectNoPartialRuntimeTerminal({
  required RuntimeRoot root,
  required _PreacceptanceOwnerSnapshot beforeOwners,
  required SpatialKernelSnapshot beforeSpatial,
  required int beforeProjectionBuilds,
  required List<CanvasActionCommitted> actions,
  required List<RuntimeDeletionRouteConstructionKind> preparation,
  required List<List<Object>> projectedEntries,
  required List<RuntimeSurfaceFrameSignal> terminalFrames,
  required List<String> trace,
  required List<RuntimeEraserEntryRouteWorkKind> expectedRoute,
  required List<RuntimeEraserEntryRouteWorkEvent> routeEvents,
  required InteractionReadBudgetExceededReason? expectedBudgetReason,
}) {
  expect(root.interactionEngine.activeSession, isNull);
  expect(root.preview, isA<CanvasNoPreview>());
  beforeOwners.expectUnchanged(root);
  if (expectedBudgetReason != null) {
    final spatialQuery = routeEvents
        .firstWhere(
          (event) =>
              event.kind == RuntimeEraserEntryRouteWorkKind.spatialQueryReady,
        )
        .query;
    expect(spatialQuery.status, InteractionReadQueryStatus.budgetExceeded);
    expect(spatialQuery.budgetExceededReason, expectedBudgetReason);
  }
  expect(root.projectionBuildCount, beforeProjectionBuilds);
  _expectSpatialSnapshotUnchanged(beforeSpatial, root.spatialKernel.snapshot);
  expect(actions, isEmpty);
  expect(preparation, isEmpty);
  if (expectedRoute.contains(RuntimeEraserEntryRouteWorkKind.entriesReady)) {
    expect(projectedEntries, [isEmpty]);
  } else {
    expect(projectedEntries, isEmpty);
  }
  expect(terminalFrames.where((frame) => frame.mainCanvas), isEmpty);
  expect(
    trace
        .where((event) => event.startsWith('read:'))
        .map((event) => event.split(':').last),
    expectedRoute.map((kind) => kind.name),
  );
  expect(
    trace.where(
      (event) =>
          event ==
          'interaction:${InteractionEraserRouteWorkEvent.terminalSnapshot.name}',
    ),
    hasLength(1),
  );
  _expectNoCaptureOrReadWorkAfterCleanup(trace);
}

final class _PreacceptanceOwnerSnapshot {
  _PreacceptanceOwnerSnapshot._({
    required this.document,
    required this.selectedIds,
    required this.publicState,
    required this.structuralRevision,
  });

  factory _PreacceptanceOwnerSnapshot.capture(RuntimeRoot root) {
    return _PreacceptanceOwnerSnapshot._(
      document: root.readDocument(),
      selectedIds: Set<CanvasElementId>.of(root.selectedElementIds),
      publicState: root.state.value,
      structuralRevision: root.documentFacts.structuralRevision,
    );
  }

  final CanvasDocument document;
  final Set<CanvasElementId> selectedIds;
  final CanvasRuntimeState publicState;
  final int structuralRevision;

  void expectUnchanged(RuntimeRoot root) {
    final after = root.state.value;
    expect(root.readDocument(), document);
    expect(root.selectedElementIds, selectedIds);
    expect(after.summary, publicState.summary);
    expect(after.revisions.document, publicState.revisions.document);
    expect(after.revisions.selection, publicState.revisions.selection);
    expect(after.revisions.viewCamera, publicState.revisions.viewCamera);
    expect(
      after.revisions.resourceVisual,
      publicState.revisions.resourceVisual,
    );
    expect(root.documentFacts.structuralRevision, structuralRevision);
  }
}

void _expectSpatialSnapshotUnchanged(
  SpatialKernelSnapshot before,
  SpatialKernelSnapshot after,
) {
  expect(after.structuralRevision, before.structuralRevision);
  expect(after.isInvalid, before.isInvalid);
  expect(after.entryCount, before.entryCount);
  expect(after.hitTilePageCount, before.hitTilePageCount);
  expect(after.paintTilePageCount, before.paintTilePageCount);
  expect(after.contextTilePageCount, before.contextTilePageCount);
  expect(after.hitOutlierCount, before.hitOutlierCount);
  expect(after.paintOutlierCount, before.paintOutlierCount);
  expect(after.contextOutlierCount, before.contextOutlierCount);
}

void _expectNoCaptureOrReadWorkAfterCleanup(List<String> trace) {
  final cleanupStart = trace.indexOf(
    'cleanup:${InteractionCleanupWorkEvent.started.name}',
  );
  expect(cleanupStart, isNonNegative);
  expect(
    trace
        .skip(cleanupStart + 1)
        .where(
          (event) =>
              event.startsWith('capture:') ||
              event.startsWith('read:') ||
              event.startsWith('geometry:') ||
              event.startsWith('spatial:') ||
              event.startsWith('candidate:') ||
              event.startsWith('exact:') ||
              event == 'projection',
        ),
    isEmpty,
  );
  expect(
    trace,
    contains('cleanup:${InteractionCleanupWorkEvent.sessionReleased.name}'),
  );
}

T _observeTerminalGeometryAndSpatialWork<T>(
  List<String> trace,
  T Function() operation,
) => observeRuntimeCandidateResolutionWork(
  (event) => trace.add('candidate:${event.name}'),
  () => HitTestPolicy.observeExactEraserWork(
    (event) => trace.add('exact:${event.candidateId.value}'),
    () => DocumentStoreKernel.observeDeletionEntryProjection(
      (_) => trace.add('projection'),
      () => GeometryPolicy.observeEraserWork(
        (event) => trace.add('geometry:${event.name}'),
        () => SpatialKernel.observeEraserWork(
          (event) => trace.add('spatial:${event.name}'),
          operation,
        ),
      ),
    ),
  ),
);

InteractionPointerContext _epochContext(int epoch) => InteractionPointerContext(
  viewCameraOffset: Offset.zero,
  controllerEpoch: epoch,
);

CanvasDocument _candidateOverflowDocument() => CanvasDocument(
  layers: [
    CanvasLayer(
      id: CanvasLayerId('candidate-overflow'),
      elements: [
        for (var index = 0; index <= 4096; index += 1)
          CanvasRectElement(
            id: CanvasElementId('candidate-$index'),
            transform: CanvasTransform.translation(Offset.zero),
            size: const Size(10, 10),
          ),
      ],
    ),
  ],
);

CanvasDocument _twoCandidateDocument() => CanvasDocument(
  layers: [
    CanvasLayer(
      id: CanvasLayerId('adapter-budget'),
      elements: [
        for (var index = 0; index < 2; index += 1)
          CanvasRectElement(
            id: CanvasElementId('adapter-$index'),
            size: const Size(10, 10),
          ),
      ],
    ),
  ],
);

/// Forces the existing spatial owner into its documented failed-update state;
/// the subsequent pointer-up still reads through RuntimeRoot's real adapter.
final class _FailingSpatialFrame implements FrameFactsPort {
  const _FailingSpatialFrame(this.structuralRevision);

  final int structuralRevision;

  @override
  FrameRevisionFacts get frameRevisions => FrameRevisionFacts(
    documentRevision: 0,
    structuralRevision: structuralRevision,
    boundsRevision: 0,
    elementVisualRevision: 0,
    backgroundRevision: 0,
    gridRevision: 0,
    resourceRevision: 0,
  );

  @override
  Never get background => throw StateError('fixture forces spatial failure');

  @override
  Never elementCount(int structuralRevision) =>
      throw StateError('fixture forces spatial failure');

  @override
  Never elementHandles(int structuralRevision) =>
      throw StateError('fixture forces spatial failure');

  @override
  Never elementHandleForId(int structuralRevision, CanvasElementId id) =>
      throw StateError('fixture forces spatial failure');

  @override
  Never resolveElement(FrameElementHandle handle) =>
      throw StateError('fixture forces spatial failure');

  @override
  Never resourceDescriptor(CanvasResourceId id) =>
      throw StateError('fixture forces spatial failure');
}

InteractionPointerAdmission _runOverflowEraserGesture(
  InteractionEngine engine,
) {
  engine.handlePointerSample(
    _sample(CanvasPointerLifecyclePhase.down, Offset.zero),
    _context(),
  );
  engine.handlePointerSample(
    _sample(CanvasPointerLifecyclePhase.move, const Offset(10, 0)),
    _context(),
  );
  return engine.handlePointerSample(
    _sample(CanvasPointerLifecyclePhase.up, const Offset(20, 0)),
    _context(),
  );
}

InteractionEngine _budgetOverflowEngine(
  DiagnosticsHub hub,
  InteractionReadPort readPort,
) {
  return InteractionEngine(
    initialMode: CanvasInteractionMode.draw,
    initialDrawStyle: CanvasDrawStyle(
      tool: CanvasDrawTool.eraser,
      eraserThickness: 6,
    ),
    pointerPolicy: CanvasPointerPolicy.defaultPolicy,
    diagnosticsSink: RuntimeInteractionDiagnosticsAdapter(hub),
  )..attachReadPort(readPort);
}

void _expectCleanupOnlyOverflow(
  InteractionPointerAdmission terminal,
  InteractionEngine engine,
) {
  expect(terminal.kind, InteractionPointerAdmissionKind.cleanupOnly);
  expect(terminal.eraserCommit, isNull);
  expect(terminal.strokeCommit, isNull);
  expect(engine.activeSession, isNull);
  expect(engine.preview, isA<CanvasNoPreview>());
}

EraserReadFacts _facts({
  required Iterable<Offset> corridor,
  required Iterable<CanvasElementId> erasedIds,
  required bool exactBudgetExceeded,
}) {
  return EraserReadFacts.terminal(
    corridorPoints: corridor,
    erasedEntryProjection: DeletionEntryProjection([
      for (final id in erasedIds)
        DeletionEntryFacts(
          element: CanvasRectElement(id: id, size: const Size(10, 10)),
          layerId: CanvasLayerId('fixture-layer'),
          elementIndex: 0,
          orderToken: 0,
        ),
    ]),
    eraserThickness: 6,
    controllerEpoch: 1,
    documentRevision: 0,
    exactCheckCount: 1,
    exactBudgetExceeded: exactBudgetExceeded,
  );
}

CanvasPointerSample _sample(
  CanvasPointerLifecyclePhase phase,
  Offset position,
) {
  return CanvasPointerSample(
    pointerId: 1,
    position: position,
    phase: phase,
    kind: PointerDeviceKind.touch,
  );
}

InteractionPointerContext _context() {
  return InteractionPointerContext(
    viewCameraOffset: Offset.zero,
    controllerEpoch: 1,
  );
}

// The fake implements the full port so the overflow routing test proves only
// eraser read paths are used by the interaction engine.
// ignore: coupling-between-object-classes
final class _BudgetOverflowReadPort implements InteractionReadPort {
  int terminalReadCount = 0;

  @override
  EraserReadFacts eraserTerminalFacts(EraserReadRequest request) {
    terminalReadCount += 1;
    return _facts(
      corridor: request.corridorPoints,
      erasedIds: [CanvasElementId('would-be-partial')],
      exactBudgetExceeded: true,
    );
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
    throw UnimplementedError('context target is outside this fixture.');
  }

  @override
  ContextTargetReadOutcome pendingContextTapFacts(
    ContextTargetReadRequest request,
  ) {
    throw UnimplementedError('context target is outside this fixture.');
  }

  @override
  ContextTargetReadOutcome secondContextTapFacts(
    ContextTargetReadRequest request,
  ) {
    throw UnimplementedError('context target is outside this fixture.');
  }

  @override
  TextCommitGuardReadFacts textCommitGuardFacts(
    TextCommitGuardReadRequest request,
  ) {
    throw UnimplementedError('text guard is outside this fixture.');
  }
}
