// This fixture exercises the full diagnostics route across public runtime,
// interaction, codec, and internal diagnostic records, so the boundary imports
// stay together instead of being split into metric-shaped fixtures.
// ignore_for_file: number-of-imports

import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/deletion_entry_projection_port.dart';
import 'package:iwb_canvas_engine/src/codec/schema_v1_diagnostics.dart';
import 'package:iwb_canvas_engine/src/diagnostics/diagnostic_code.dart';
import 'package:iwb_canvas_engine/src/diagnostics/diagnostics_hub.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_pointer_context.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_read_port.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_cleanup_protocol.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_interaction_diagnostics_adapter.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import '../../support/runtime_root_with_committed_document_seed.dart';
import '../../support/accept_commit.dart';

void main() {
  _testRecordsEveryInteractionDiagnosticCode();
  _testInteractionGuardPathsRouteDiagnostics();
  _testVectorInteractionReliabilityUsesExistingRoute();
  _testResolverReentrantMutationDiagnostic();
  _testCodecDiagnosticsRemainDataCodes();
  _testDeletionResolverDiagnostics();
  _testMoveResolverDiagnosticObservationFailuresAreContained();
}

void _testRecordsEveryInteractionDiagnosticCode() {
  test('records every P10 interaction diagnostic code internally', () {
    final hub = DiagnosticsHub(
      policy: CanvasDiagnosticPolicy.verbose(
        maxPreviewLength: 4,
        maxListEntries: 3,
      ),
    );

    for (final code in InteractionDiagnosticCode.values) {
      recordInteractionReliabilityDiagnostic(
        hub,
        code: code,
        details: () => {
          'text': 'abcdef',
          'items': [1, 2, 3, 4],
          'payload': _SensitivePayload(),
        },
      );
    }

    expect(
      hub.records.map((record) => record.code),
      InteractionDiagnosticCode.values.map(DiagnosticCode.interaction),
    );
    expect(hub.records, everyElement(_isSanitizedInteractionRecord));
  });
}

// The route proof reads as one scenario: start denial, stale candidate, stale
// terminal cleanup, and bounded diagnostics must be checked against one hub.
// ignore: halstead-volume, source-lines-of-code
void _testInteractionGuardPathsRouteDiagnostics() {
  test('interaction guard paths route bounded diagnostics without actions', () {
    final hub = DiagnosticsHub(policy: const CanvasDiagnosticPolicy.summary());
    final diagnostics = RuntimeInteractionDiagnosticsAdapter(hub);

    _rejectSelectedMoveWithFallbackBudget(diagnostics);
    _rejectSelectedMoveWithStaleCandidate(diagnostics);
    _rejectContextTargetWithStaleIndex(diagnostics);
    _rejectContextTargetWithBudgetExceeded(diagnostics);
    final beforeInvalidContextReject = hub.records.length;
    _rejectContextTargetWithInvalidIndex(diagnostics);
    expect(hub.records, hasLength(beforeInvalidContextReject));
    _rejectStaleTerminal(diagnostics);

    expect(
      hub.records.map((record) => record.code).toSet(),
      containsAll({
        const DiagnosticCode.interaction(
          InteractionDiagnosticCode.hitTestFallbackObserved,
        ),
        const DiagnosticCode.interaction(
          InteractionDiagnosticCode.interactionQueryBudgetExceeded,
        ),
        const DiagnosticCode.interaction(
          InteractionDiagnosticCode.staleCandidateRejected,
        ),
        const DiagnosticCode.interaction(
          InteractionDiagnosticCode.staleTerminalRejected,
        ),
        const DiagnosticCode.interaction(
          InteractionDiagnosticCode.invalidTerminalCleanup,
        ),
        const DiagnosticCode.interaction(
          InteractionDiagnosticCode.selectedMoveStartDeniedNotMovable,
        ),
      }),
    );
    expect(
      _diagnosticCount(
        hub,
        InteractionDiagnosticCode.interactionQueryBudgetExceeded,
      ),
      2,
    );
    expect(
      _diagnosticCount(hub, InteractionDiagnosticCode.hitTestFallbackObserved),
      2,
    );
    expect(
      _diagnosticCount(hub, InteractionDiagnosticCode.staleCandidateRejected),
      2,
    );
    expect(
      hub.records,
      everyElement(
        isA<DiagnosticRecord>()
            .having(
              (record) => record.source,
              'source',
              DiagnosticSource.interaction,
            )
            .having(
              (record) => record.severity,
              'severity',
              DiagnosticSeverity.warning,
            ),
      ),
    );
  });
}

// Keeping the two policy paths together makes their contrast readable.
// ignore: halstead-volume, source-lines-of-code
void _testVectorInteractionReliabilityUsesExistingRoute() {
  test(
    'non-movable selected vector records the existing interaction route once',
    () {
      final enabledRoot = runtimeRootWithCommittedDocumentSeed(
        _nonMovableVectorDocument(),
        config: const CanvasRuntimeConfig(
          commitResolver: acceptCommit,
          diagnosticPolicy: CanvasDiagnosticPolicy.summary(),
        ),
      );
      addTearDown(enabledRoot.dispose);
      enabledRoot.selection.setSelection([CanvasElementId('vector-a')]);

      enabledRoot.handlePointer(
        _sample(CanvasPointerLifecyclePhase.down, Offset.zero),
      );

      expect(enabledRoot.diagnosticRecords, hasLength(1));
      expect(
        enabledRoot.diagnosticRecords.single.code,
        const DiagnosticCode.interaction(
          InteractionDiagnosticCode.selectedMoveStartDeniedNotMovable,
        ),
      );
      expect(
        enabledRoot.diagnosticRecords.single.source,
        DiagnosticSource.interaction,
      );

      final disabledRoot = runtimeRootWithCommittedDocumentSeed(
        _nonMovableVectorDocument(),
      );
      addTearDown(disabledRoot.dispose);
      final before = DiagnosticRecord.allocations.count;
      disabledRoot.selection.setSelection([CanvasElementId('vector-a')]);
      disabledRoot.handlePointer(
        _sample(CanvasPointerLifecyclePhase.down, Offset.zero),
      );

      expect(disabledRoot.diagnosticRecords, isEmpty);
      expect(DiagnosticRecord.allocations.count, before);
    },
  );
}

int _diagnosticCount(DiagnosticsHub hub, InteractionDiagnosticCode code) {
  return hub.records
      .where((record) => record.code == DiagnosticCode.interaction(code))
      .length;
}

// The reentrancy proof keeps resolver mutation, rollback, action silence, and
// diagnostic emission in one scenario so no assertion can drift from the cause.
// ignore: halstead-volume, source-lines-of-code
void _testResolverReentrantMutationDiagnostic() {
  test('runtime load and interaction diagnostics share ordered records', () {
    late RuntimeRoot root;
    final actions = <CanvasActionCommitted>[];
    root = runtimeRootWithCommittedDocumentSeed(
      _document(),
      config: CanvasRuntimeConfig(
        commitResolver: (request) {
          if (request is CanvasMoveCommitRequest) {
            root.selection.clearSelection();
            return const CanvasMoveCommitAccept(
              delta: Offset(1, 1),
              lease: testAcceptingCommitLease,
            );
          }
          return acceptCommit(request);
        },
        diagnosticPolicy: const CanvasDiagnosticPolicy.summary(),
      ),
    );
    addTearDown(root.dispose);
    root.actions.listen(actions.add);

    expect(
      () => root.edits.loadDocumentFromJson(
        jsonEncode({
          'schemaVersion': 1,
          'resources': [
            {
              'id': 'resource-a',
              'kind': 'image',
              'source': {'kind': 'appKey', 'key': 'resource-a'},
            },
            {
              'id': 'resource-a',
              'kind': 'image',
              'source': {'kind': 'appKey', 'key': 'resource-a'},
            },
          ],
        }),
      ),
      throwsA(isA<CanvasDataException>()),
    );
    expect(
      root.diagnosticRecords.single.code,
      const DiagnosticCode.data(CanvasDataErrorCode.duplicateResourceId),
    );

    root.selection.setSelection([CanvasElementId('a')]);

    root.handlePointer(_sample(CanvasPointerLifecyclePhase.down, Offset.zero));
    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.move, const Offset(10, 0)),
    );

    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.up, const Offset(10, 0)),
    );

    expect(actions, isEmpty);
    expect(_rect(root, 'a').transform, CanvasTransform.identity);
    expect(root.diagnosticRecords, hasLength(2));
    expect(root.diagnosticRecords.map((record) => record.code), [
      const DiagnosticCode.data(CanvasDataErrorCode.duplicateResourceId),
      const DiagnosticCode.interaction(
        InteractionDiagnosticCode.resolverReentrantMutationRejected,
      ),
    ]);
  });
}

void _testCodecDiagnosticsRemainDataCodes() {
  test('codec diagnostics remain wrapped as data codes', () {
    final hub = DiagnosticsHub(policy: const CanvasDiagnosticPolicy.summary());
    final exception = CanvasDataException(
      code: CanvasDataErrorCode.invalidJson,
      message: 'Invalid JSON.',
      path: r'$.document',
    );

    recordSchemaV1FailureDiagnostic(hub, exception);

    expect(
      hub.records.single.code,
      const DiagnosticCode.data(CanvasDataErrorCode.invalidJson),
    );
    expect(hub.records.single.source, DiagnosticSource.codec);
  });
}

// The configured public callbacks supply the diagnostic evidence; outcome
// fixtures separately own no-mutation and cleanup behavior for these routes.
// ignore: halstead-volume, source-lines-of-code
void _testDeletionResolverDiagnostics() {
  test('both deletion routes emit one bounded resolver failure record', () {
    for (final route in _DeletionRoute.values) {
      for (final thrown in [
        StateError('internal message'),
        Exception('internal exception'),
        _OrdinaryThrownObject(),
      ]) {
        final root = _deletionRoot((_) {
          // Ordinary objects are part of the bounded error-kind contract.
          // ignore: only_throw_errors
          throw thrown;
        }, diagnosticPolicy: const CanvasDiagnosticPolicy.summary());
        addTearDown(root.dispose);

        _triggerDeletion(root, route);

        expect(root.diagnosticRecords, hasLength(1));
        _expectBoundedDeletionFailure(
          root.diagnosticRecords.single,
          operation: route == _DeletionRoute.selection ? 'delete' : 'erase',
          errorKind: thrown is Error
              ? 'error'
              : thrown is Exception
              ? 'exception'
              : 'object',
        );
      }
    }
  });

  test('deletion diagnostic controls and disabled callbacks stay silent', () {
    for (final route in _DeletionRoute.values) {
      for (final decision in [
        const CanvasCommitAccept(lease: testAcceptingCommitLease),
        const CanvasCommitCancel(),
      ]) {
        final root = _deletionRoot(
          (_) => decision,
          diagnosticPolicy: const CanvasDiagnosticPolicy.summary(),
        );
        addTearDown(root.dispose);
        _triggerDeletion(root, route);
        expect(root.diagnosticRecords, isEmpty);
      }
      final disabled = _deletionRoot((_) {
        throw StateError('unreported message');
      });
      addTearDown(disabled.dispose);
      final before = DiagnosticRecord.allocations.count;
      final diagnosticWork = <ResolverCallbackDiagnosticWorkEvent>[];
      RuntimeInteractionDiagnosticsAdapter.observeResolverCallbackDiagnosticWork(
        diagnosticWork.add,
        () => _triggerDeletion(disabled, route),
      );
      expect(disabled.diagnosticRecords, isEmpty);
      expect(DiagnosticRecord.allocations.count, before);
      expect(diagnosticWork, isEmpty);
    }
  });
}

// The adapter's two construction phases can fail independently, but both must
// stay inside the existing Move callback containment boundary.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _testMoveResolverDiagnosticObservationFailuresAreContained() {
  for (final phase in ResolverCallbackDiagnosticWorkEvent.values) {
    test(
      'Move resolver contains diagnostic observation failure at ${phase.name}',
      () {
        var resolverThrows = true;
        final actions = <CanvasActionCommitted>[];
        final root = runtimeRootWithCommittedDocumentSeed(
          _document(),
          config: CanvasRuntimeConfig(
            commitResolver: (request) {
              if (request is CanvasMoveCommitRequest) {
                if (resolverThrows) {
                  throw StateError('sensitive resolver failure must not leak');
                }
                return const CanvasMoveCommitAccept(
                  delta: Offset(10, 0),
                  lease: testAcceptingCommitLease,
                );
              }
              return acceptCommit(request);
            },
            diagnosticPolicy: const CanvasDiagnosticPolicy.summary(),
          ),
        );
        addTearDown(root.dispose);
        final subscription = root.actions.listen(actions.add);
        addTearDown(subscription.cancel);
        root.selection.setSelection([CanvasElementId('a')]);

        final cleanupReasons = <PointerCleanupReason>[];
        final routeEvents = <RuntimeRouteTemporalEvent>[];
        RuntimeRoot.observeRouteTemporalEvents(
          routeEvents.add,
          () => InteractionEngine.observeCleanup(
            cleanupReasons.add,
            () =>
                RuntimeInteractionDiagnosticsAdapter.observeResolverCallbackDiagnosticWork((
                  event,
                ) {
                  if (event == phase) {
                    throw StateError(
                      'sensitive ${phase.name} observer failure must not leak',
                    );
                  }
                }, () => _deliverSelectedMove(root)),
          ),
        );

        expect(cleanupReasons, [PointerCleanupReason.resolverError]);
        expect(root.preview, isA<CanvasNoPreview>());
        expect(root.interactionEngine.activeSession, isNull);
        expect(_rect(root, 'a').transform, CanvasTransform.identity);
        expect(root.selection.selectedElementIds, {CanvasElementId('a')});
        expect(actions, isEmpty);
        expect(root.diagnosticRecords, isEmpty);
        expect(
          routeEvents
              .map((event) => event.kind)
              .where(
                (kind) =>
                    kind ==
                        RuntimeRouteTemporalEventKind.resolverGuardEntered ||
                    kind == RuntimeRouteTemporalEventKind.resolverGuardReleased,
              ),
          [
            RuntimeRouteTemporalEventKind.resolverGuardEntered,
            RuntimeRouteTemporalEventKind.resolverGuardReleased,
          ],
        );

        expect(root.generateElementId(), isNotNull);
        resolverThrows = false;
        _deliverSelectedMove(root);
        expect(actions, hasLength(1));
        expect(_rect(root, 'a').transform.translation, const Offset(10, 0));
        expect(root.diagnosticRecords, isEmpty);
      },
    );
  }
}

void _deliverSelectedMove(RuntimeRoot root) {
  root.handlePointer(_sample(CanvasPointerLifecyclePhase.down, Offset.zero));
  root.handlePointer(
    _sample(CanvasPointerLifecyclePhase.move, const Offset(10, 0)),
  );
  root.handlePointer(
    _sample(CanvasPointerLifecyclePhase.up, const Offset(10, 0)),
  );
}

RuntimeRoot _deletionRoot(
  CanvasCommitResolver resolver, {
  CanvasDiagnosticPolicy diagnosticPolicy =
      const CanvasDiagnosticPolicy.disabled(),
}) => runtimeRootWithCommittedDocumentSeed(
  _document(),
  config: CanvasRuntimeConfig(
    commitResolver: resolver,
    diagnosticPolicy: diagnosticPolicy,
  ),
);

void _triggerDeletion(RuntimeRoot root, _DeletionRoute route) {
  switch (route) {
    case _DeletionRoute.selection:
      root.selection.setSelection([CanvasElementId('a')]);
      root.selection.deleteSelection();
    case _DeletionRoute.eraser:
      root.setInteractionMode(CanvasInteractionMode.draw);
      root.setDrawStyle(CanvasDrawStyle(tool: CanvasDrawTool.eraser));
      root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.down, Offset.zero),
      );
      root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.move, const Offset(1, 1)),
      );
      root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.up, const Offset(1, 1)),
      );
  }
}

void _expectBoundedDeletionFailure(
  DiagnosticRecord record, {
  required String operation,
  required String errorKind,
}) {
  expect(
    record.code,
    const DiagnosticCode.interaction(
      InteractionDiagnosticCode.resolverCallbackFailed,
    ),
  );
  expect(record.severity, DiagnosticSeverity.warning);
  expect(record.source, DiagnosticSource.interaction);
  expect(record.details, {'operation': operation, 'errorKind': errorKind});
  expect(record.path, isNull);
  expect(record.revision, isNull);
  expect(record.sessionId, isNull);
  expect(record.correlationId, isNull);
}

enum _DeletionRoute { selection, eraser }

final class _OrdinaryThrownObject {
  @override
  String toString() => 'must not appear in diagnostics';
}

void _rejectSelectedMoveWithFallbackBudget(
  RuntimeInteractionDiagnosticsAdapter diagnostics,
) {
  final engine = _engine(
    diagnostics,
    selectedMoveStartFacts: SelectedMoveStartFacts(
      selectedIds: [CanvasElementId('a')],
      movableSelectedIds: const [],
      controllerEpoch: 0,
      selectionRevision: 0,
      hitSelectedMovable: false,
      query: const InteractionReadQueryFacts.budgetExceeded(
        budgetExceededReason:
            InteractionReadBudgetExceededReason.fallbackCandidateBudgetExceeded,
        budget: 1,
        observed: 2,
      ),
    ),
  );

  engine.handlePointerSample(
    _sample(CanvasPointerLifecyclePhase.down, Offset.zero),
    _context(),
  );
}

void _rejectSelectedMoveWithStaleCandidate(
  RuntimeInteractionDiagnosticsAdapter diagnostics,
) {
  final engine = _engine(
    diagnostics,
    selectedMoveStartFacts: SelectedMoveStartFacts(
      selectedIds: [CanvasElementId('a')],
      movableSelectedIds: const [],
      controllerEpoch: 0,
      selectionRevision: 0,
      hitSelectedMovable: false,
      query: const InteractionReadQueryFacts.candidates(
        candidateCount: 1,
        skippedCandidateCount: 1,
      ),
    ),
  );

  engine.handlePointerSample(
    _sample(CanvasPointerLifecyclePhase.down, Offset.zero),
    _context(),
  );
}

void _rejectContextTargetWithStaleIndex(
  RuntimeInteractionDiagnosticsAdapter diagnostics,
) {
  final engine = _contextEngine(
    diagnostics,
    contextTarget: const RejectedContextTargetRead(
      query: InteractionReadQueryFacts.staleIndex(
        expectedStructuralRevision: 2,
        observedStructuralRevision: 1,
      ),
    ),
  );

  final intent = engine.handleDoubleTap(
    Offset.zero,
    _context(),
    timestampHintMs: 1,
  );

  expect(intent, isNull);
  expect(
    engine.requestFactsFor(CanvasInteractionRequestId('request-0')),
    isNull,
  );
}

void _rejectContextTargetWithBudgetExceeded(
  RuntimeInteractionDiagnosticsAdapter diagnostics,
) {
  final engine = _contextEngine(
    diagnostics,
    contextTarget: const RejectedContextTargetRead(
      query: InteractionReadQueryFacts.budgetExceeded(
        budgetExceededReason:
            InteractionReadBudgetExceededReason.fallbackCandidateBudgetExceeded,
        budget: 1,
        observed: 2,
      ),
    ),
  );

  final intent = engine.handleDoubleTap(
    Offset.zero,
    _context(),
    timestampHintMs: 1,
  );

  expect(intent, isNull);
  expect(
    engine.requestFactsFor(CanvasInteractionRequestId('request-0')),
    isNull,
  );
}

void _rejectContextTargetWithInvalidIndex(
  RuntimeInteractionDiagnosticsAdapter diagnostics,
) {
  final engine = _contextEngine(
    diagnostics,
    contextTarget: const RejectedContextTargetRead(
      query: InteractionReadQueryFacts.invalidIndex(
        invalidIndexReason: InteractionReadInvalidIndexReason.rebuildNeeded,
      ),
    ),
  );

  final intent = engine.handleDoubleTap(
    Offset.zero,
    _context(),
    timestampHintMs: 1,
  );

  expect(intent, isNull);
  expect(
    engine.requestFactsFor(CanvasInteractionRequestId('request-0')),
    isNull,
  );
}

void _rejectStaleTerminal(RuntimeInteractionDiagnosticsAdapter diagnostics) {
  final engine = _engine(
    diagnostics,
    selectedMoveStartFacts: SelectedMoveStartFacts(
      selectedIds: [CanvasElementId('a')],
      movableSelectedIds: [CanvasElementId('a')],
      controllerEpoch: 0,
      selectionRevision: 0,
      hitSelectedMovable: true,
    ),
  );

  engine.handlePointerSample(
    _sample(CanvasPointerLifecyclePhase.down, Offset.zero),
    _context(),
  );
  engine.handlePointerSample(
    _sample(CanvasPointerLifecyclePhase.up, Offset.zero),
    _context(controllerEpoch: 1),
  );
}

InteractionEngine _engine(
  RuntimeInteractionDiagnosticsAdapter diagnostics, {
  required SelectedMoveStartFacts selectedMoveStartFacts,
}) {
  final engine = InteractionEngine(
    initialMode: CanvasInteractionMode.move,
    initialDrawStyle: CanvasDrawStyle(),
    pointerPolicy: CanvasPointerPolicy(),
    diagnosticsSink: diagnostics,
  );
  engine.attachReadPort(
    _FakeInteractionReadPort(startFacts: selectedMoveStartFacts),
  );

  return engine;
}

InteractionEngine _contextEngine(
  RuntimeInteractionDiagnosticsAdapter diagnostics, {
  required ContextTargetReadOutcome contextTarget,
}) {
  final engine = InteractionEngine(
    initialMode: CanvasInteractionMode.move,
    initialDrawStyle: CanvasDrawStyle(),
    pointerPolicy: CanvasPointerPolicy(),
    diagnosticsSink: diagnostics,
  );
  engine.attachReadPort(
    _FakeInteractionReadPort(
      startFacts: SelectedMoveStartFacts(
        selectedIds: const [],
        movableSelectedIds: const [],
        controllerEpoch: 0,
        selectionRevision: 0,
        hitSelectedMovable: false,
      ),
      contextTarget: contextTarget,
    ),
  );

  return engine;
}

InteractionPointerContext _context({int controllerEpoch = 0}) {
  return InteractionPointerContext(
    viewCameraOffset: Offset.zero,
    controllerEpoch: controllerEpoch,
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

CanvasDocument _document() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasRectElement(id: CanvasElementId('a'), size: const Size(10, 10)),
        ],
      ),
    ],
  );
}

CanvasDocument _nonMovableVectorDocument() {
  return CanvasDocument(
    resources: [
      CanvasVectorResource(
        id: CanvasResourceId('vector-resource'),
        source: CanvasResourceSource.appKey('vector-resource'),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('vector-layer'),
        elements: [
          CanvasVectorElement(
            id: CanvasElementId('vector-a'),
            resourceId: CanvasResourceId('vector-resource'),
            size: const Size(10, 10),
            isTransformable: false,
          ),
        ],
      ),
    ],
  );
}

CanvasRectElement _rect(RuntimeRoot root, String id) {
  return root
      .readDocument()
      .layers
      .single
      .elements
      .whereType<CanvasRectElement>()
      .firstWhere((element) => element.id == CanvasElementId(id));
}

final Matcher _isSanitizedInteractionRecord = isA<DiagnosticRecord>()
    .having((record) => record.source, 'source', DiagnosticSource.interaction)
    .having((record) => record.severity, 'severity', DiagnosticSeverity.warning)
    .having((record) => record.details['text'], 'text', 'abcd<truncated>')
    .having((record) => record.details['item<truncated>'], 'items', [1, 2, 3])
    .having((record) => record.details['payl<truncated>'], 'payload', {
      'unsupportedType': '_Sen<truncated>',
    });

// This fixture implements the full read port so diagnostic route tests fail if
// a scenario unexpectedly crosses into an unrelated interaction read path.
// Splitting it into metric-sized fakes would hide that boundary proof.
// ignore: coupling-between-object-classes, number-of-methods
final class _FakeInteractionReadPort implements InteractionReadPort {
  const _FakeInteractionReadPort({
    required this.startFacts,
    this.contextTarget = const AdmittedContextTargetRead(
      ContextTargetReadFacts.emptyCanvas(
        controllerEpoch: 0,
        documentRevision: 0,
      ),
    ),
  });

  final SelectedMoveStartFacts startFacts;
  final ContextTargetReadOutcome contextTarget;

  @override
  SelectedMoveStartFacts selectedMoveStartFacts(
    SelectedMoveStartReadRequest request,
  ) {
    return startFacts;
  }

  @override
  SelectedMoveCommitFacts selectedMoveCommitFacts(
    SelectedMoveCommitReadRequest request,
  ) {
    throw UnimplementedError('selected move commit is outside this fixture.');
  }

  @override
  MarqueeStartFacts marqueeStartFacts(MarqueeStartReadRequest request) {
    return MarqueeStartFacts(
      previousSelectedIds: const [],
      controllerEpoch: 0,
      selectionRevision: 0,
    );
  }

  @override
  MarqueeCommitFacts marqueeCommitFacts(MarqueeCommitReadRequest request) {
    return MarqueeCommitFacts(
      previousSelectedIds: const [],
      nextSelectedIds: const [],
      controllerEpoch: 0,
      selectionRevision: 0,
      rectWorld: request.rectWorld,
    );
  }

  @override
  EraserReadFacts eraserTerminalFacts(EraserReadRequest request) {
    return EraserReadFacts.terminal(
      corridorPoints: request.corridorPoints,
      erasedEntryProjection: const DeletionEntryProjection.empty(),
      eraserThickness: request.eraserThickness,
      controllerEpoch: 0,
      documentRevision: 0,
      exactCheckCount: 0,
      exactBudgetExceeded: false,
    );
  }

  @override
  ContextTargetReadOutcome directContextTargetFacts(
    ContextTargetReadRequest request,
  ) {
    return contextTarget;
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
      controllerEpoch: 0,
      documentRevision: 0,
    );
  }
}

final class _SensitivePayload {}
