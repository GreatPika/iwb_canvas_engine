// This fixture owns the real resolver/consume work boundary for both routes.
// It composes existing Store, prepared-package, Selection, cleanup, and sealed
// delivery observers rather than reproducing their work in test helpers.
// ignore_for_file: number-of-imports

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/edit/commit_applier.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_runtime_intents.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_cleanup_protocol.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_action_finalizer.dart';
import 'package:iwb_canvas_engine/src/selection/selection_kernel.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import '../../support/runtime_root_with_committed_document_seed.dart';
import '../../support/accept_deletion_commit.dart';

// The four route matrices share the same public work oracle. Keeping their
// registrations adjacent makes the fixed-k/N and terminal-outcome coverage
// auditable without hiding a route in a helper solely to lower metrics.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void main() {
  test('both deletion routes construct and consume one bounded package', () {
    var witnessedOperations = 0;
    for (final route in _DeletionRoute.values) {
      for (final outcome in _ResolverOutcome.nonemptyValues) {
        final result = _runRoute(
          route: route,
          outcome: outcome,
          targetCount: 2,
        );
        addTearDown(result.dispose);

        _expectNonemptyConstruction(result, route, outcome, targetCount: 2);
        witnessedOperations += 1;
      }
    }
    expect(
      witnessedOperations,
      _DeletionRoute.values.length * _ResolverOutcome.nonemptyValues.length,
    );
  });

  test(
    'empty, invalid, and policy-rejected terminals construct no package',
    () {
      _expectSelectionWithoutDeletion(
        document: _document(targetCount: 2),
        config: const CanvasRuntimeConfig(
          deletionCommitResolver: acceptDeletionCommit,
        ),
        select: const [],
      );
      _expectSelectionWithoutDeletion(
        document: _document(targetCount: 1, includeNotDeletable: true),
        config: const CanvasRuntimeConfig(
          deletionCommitResolver: acceptDeletionCommit,
          selectionDeletePolicy: CanvasSelectionDeletePolicy.allOrNone,
        ),
        select: [CanvasElementId('target-0'), CanvasElementId('blocked')],
      );
      _expectEraserWithoutDeletion(
        document: _document(targetCount: 1),
        config: const CanvasRuntimeConfig(
          deletionCommitResolver: acceptDeletionCommit,
        ),
        terminalPosition: const Offset(1000, 0),
      );
      _expectEraserWithoutDeletion(
        document: _document(targetCount: 1),
        config: const CanvasRuntimeConfig(
          deletionCommitResolver: acceptDeletionCommit,
          eraserElementKinds: <CanvasElementKind>{},
        ),
        terminalPosition: Offset.zero,
      );
      expect(_DeletionRoute.values, hasLength(2));
    },
  );

  test(
    'sparse preparation and accepted install stay fixed-k across unrelated N',
    () {
      for (final route in _DeletionRoute.values) {
        final small = _runRoute(
          route: route,
          outcome: _ResolverOutcome.accept,
          targetCount: 2,
        );
        final large = _runRoute(
          route: route,
          outcome: _ResolverOutcome.accept,
          targetCount: 2,
          unrelatedElementCount: 128,
        );
        final largerK = _runRoute(
          route: route,
          outcome: _ResolverOutcome.accept,
          targetCount: 4,
        );
        addTearDown(small.dispose);
        addTearDown(large.dispose);
        addTearDown(largerK.dispose);

        expect(large.sparseWork, small.sparseWork);
        expect(large.installWork, small.installWork);
        expect(large.sealedDeliveryWork, small.sealedDeliveryWork);
        expect(large.ownerLoopWork, small.ownerLoopWork);
        expect(
          large.projectionEventsAtResolver,
          small.projectionEventsAtResolver,
        );
        expect(small.requestEntryCopies, 2);
        expect(large.requestEntryCopies, 2);
        expect(largerK.requestEntryCopies, 4);
        expect(largerK.preparedWork, small.preparedWork);
        expect(largerK.installWork, small.installWork);
        expect(largerK.ownerLoopWork.actionCommittedReads, 4);
        expect(largerK.ownerLoopWork.actionPayloadReads, 4);
        expect(largerK.ownerLoopWork.idAdmissions, isEmpty);
        _expectTouchedSparseWork(small.sparseWork, targetCount: 2);
        _expectTouchedSparseWork(largerK.sparseWork, targetCount: 4);
        _expectExactOwnerLoopWork(small, route, targetCount: 2);
        _expectExactOwnerLoopWork(largerK, route, targetCount: 4);
      }
    },
  );

  test('discard and terminal cleanup stay fixed-k without rollback replay', () {
    for (final route in _DeletionRoute.values) {
      for (final outcome in _ResolverOutcome.discardValues) {
        final small = _runRoute(route: route, outcome: outcome, targetCount: 2);
        final large = _runRoute(
          route: route,
          outcome: outcome,
          targetCount: 2,
          unrelatedElementCount: 128,
        );
        addTearDown(small.dispose);
        addTearDown(large.dispose);

        expect(small.preparedWork, [
          PreparedInteractionApplyWorkEvent.selectionBackingTransferred,
          PreparedInteractionApplyWorkEvent.prepared,
          PreparedInteractionApplyWorkEvent.ownershipReleased,
          PreparedInteractionApplyWorkEvent.discarded,
        ]);
        expect(small.installWork, [DeletionPreparedInstallEvent.bound]);
        expect(small.selectionInstallCount, 1);
        expect(small.sparseWork, large.sparseWork);
        expect(small.preparedWork, large.preparedWork);
        expect(small.installWork, large.installWork);
        expect(small.ownerLoopWork, large.ownerLoopWork);
        expect(
          small.projectionEventsAtResolver,
          large.projectionEventsAtResolver,
        );
        expect(small.ownerLoopWork.actionCommittedReads, 0);
        expect(small.ownerLoopWork.actionPayloadReads, 0);
        expect(small.ownerLoopWork.selectionInstallWork, [
          PreparedSelectionInstallWorkEvent.ownedBackingPrepared,
        ]);
        expect(small.projectionEventsAtResolver, greaterThan(0));
        expect(small.projectionEventsAfterResolver, 0);
        expect(small.entryRouteEventsAfterResolver, 0);
        expect(
          small.ownerLoopWork.cleanupWork,
          route == _DeletionRoute.eraser
              ? [
                  InteractionCleanupWorkEvent.started,
                  InteractionCleanupWorkEvent.previewCleared,
                  InteractionCleanupWorkEvent.sessionReleased,
                ]
              : isEmpty,
        );
        if (route == _DeletionRoute.eraser) {
          expect(small.cleanupReasons, hasLength(1));
          expect(large.cleanupReasons, hasLength(1));
        } else {
          expect(small.cleanupReasons, isEmpty);
        }
      }
    }
  });

  test(
    'accepted eraser cleanup remains singular through delivery failures',
    () async {
      for (final failure in _EraserDeliveryFailure.values) {
        final result = await _runAcceptedEraserDeliveryFailure(failure);
        addTearDown(result.dispose);

        expect(result.callbacks, 1);
        expect(result.cleanupReasons, [PointerCleanupReason.postSuccessCommit]);
        expect(result.cleanupWork, [
          InteractionCleanupWorkEvent.started,
          InteractionCleanupWorkEvent.previewCleared,
          InteractionCleanupWorkEvent.sessionReleased,
        ]);
        expect(result.remainingIds, isEmpty);
        expect(result.selectionIds, isEmpty);
        expect(result.deliveryErrors, isNotEmpty);
      }
    },
  );
}

// Keeping the real listener setup, pointer terminal, cleanup observer, and
// finality snapshot adjacent prevents a synthetic delivery path from passing.
// ignore: halstead-volume, source-lines-of-code
Future<_AcceptedEraserDeliveryFailureResult> _runAcceptedEraserDeliveryFailure(
  _EraserDeliveryFailure failure,
) async {
  var callbacks = 0;
  final cleanupReasons = <PointerCleanupReason>[];
  final cleanupWork = <InteractionCleanupWorkEvent>[];
  final errors = <Object>[];
  final root = runtimeRootWithCommittedDocumentSeed(
    _document(targetCount: 2),
    config: CanvasRuntimeConfig(
      deletionCommitResolver: (_) {
        callbacks += 1;
        return CanvasDeletionDecision.accept;
      },
    ),
  );
  var armed = false;
  final previousFlutterError = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exception);
  root.state.addListener(() {
    if (armed && failure == _EraserDeliveryFailure.state) {
      throw StateError('state delivery failure');
    }
  });
  late StreamSubscription<CanvasActionCommitted> subscription;
  runZonedGuarded(() {
    subscription = root.actions.listen((_) {
      if (armed && failure == _EraserDeliveryFailure.action) {
        throw StateError('action delivery failure');
      }
    });
  }, (error, _) => errors.add(error));
  _beginEraser(root, const Offset(60, 0));
  armed = true;
  InteractionEngine.observeCleanup(
    cleanupReasons.add,
    () => InteractionEngine.observeCleanupWork(
      cleanupWork.add,
      () => root.handlePointer(
        _pointer(CanvasPointerLifecyclePhase.up, const Offset(60, 0)),
      ),
    ),
  );
  await Future<void>.delayed(Duration.zero);
  await subscription.cancel();
  FlutterError.onError = previousFlutterError;

  return _AcceptedEraserDeliveryFailureResult(
    root: root,
    callbacks: callbacks,
    cleanupReasons: cleanupReasons,
    cleanupWork: cleanupWork,
    deliveryErrors: errors,
    remainingIds: [
      for (final layer in root.readDocument().layers)
        for (final element in layer.elements) element.id,
    ],
    selectionIds: root.selectedElementIds,
  );
}

// The route result keeps direct owner observations together. It deliberately
// stores scalar work vectors, not timing or a copied document projection.
// Nesting the real owner observers is safer than a test-only proxy seam.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
_DeletionWorkResult _runRoute({
  required _DeletionRoute route,
  required _ResolverOutcome outcome,
  required int targetCount,
  int unrelatedElementCount = 0,
}) {
  var callbacks = 0;
  final projectionWork = <DeletionProjectionWorkEvent>[];
  final entryRouteWork = <RuntimeDeletionEntryRouteWorkEvent>[];
  var projectionEventsAtResolver = -1;
  var entryRouteEventsAtResolver = -1;
  final root = runtimeRootWithCommittedDocumentSeed(
    _document(
      targetCount: targetCount,
      unrelatedElementCount: unrelatedElementCount,
    ),
    config: CanvasRuntimeConfig(
      deletionCommitResolver: (_) {
        callbacks += 1;
        projectionEventsAtResolver = projectionWork.length;
        entryRouteEventsAtResolver = entryRouteWork.length;
        return outcome.resolve();
      },
    ),
  );
  final construction = <RuntimeDeletionRouteConstructionKind>[];
  final requestWork = <RuntimeDeletionRequestWorkEvent>[];
  final preparedWork = <PreparedInteractionApplyWorkEvent>[];
  final installWork = <DeletionPreparedInstallEvent>[];
  final sparseEvents = <SparseTransactionWorkEvent>[];
  final cleanupReasons = <PointerCleanupReason>[];
  final idAdmissions = <IdAdmissionWorkEvent>[];
  final actionElementReads = <DeletionActionElementReadEvent>[];
  final eraserIdMaterializationWork =
      <EraserDeletionIdMaterializationWorkEvent>[];
  final cleanupWork = <InteractionCleanupWorkEvent>[];
  final augmentationWork = <RuntimePointerCleanupAugmentationWorkEvent>[];
  final selectionInstallWork = <PreparedSelectionInstallWorkEvent>[];
  var selectionInstallCount = 0;
  CommitSealedDeliveryWork? sealedDeliveryWork;

  root.selection.setSelection(_targetIds(targetCount));
  if (route == _DeletionRoute.eraser) {
    _beginEraser(root, const Offset(60, 0));
  }

  DocumentStoreKernel.observeDeletionProjectionWork(
    projectionWork.add,
    () => RuntimeRoot.observeDeletionEntryRouteWork(
      entryRouteWork.add,
      () => CommitApplier.observePreparedInteractionWork(
        preparedWork.add,
        () => DocumentStoreKernel.observeIdAdmissionWork(
          idAdmissions.add,
          () => DocumentStoreKernel.observeSparseTransactionWork(
            sparseEvents.add,
            () => RuntimeActionFinalizer.observeDeletionElementIdReads(
              actionElementReads.add,
              () => EraserCommitIntent.observeErasedElementIdMaterializationWork(
                eraserIdMaterializationWork.add,
                () => RuntimeRoot.observePointerCleanupAugmentationWork(
                  augmentationWork.add,
                  () => RuntimeRoot.observeDeletionRouteConstruction(
                    construction.add,
                    () => RuntimeRoot.observeDeletionRequestWork(
                      requestWork.add,
                      () => DocumentStoreKernel.observeDeletionPreparedInstall(
                        installWork.add,
                        () => SelectionKernel.observePreparedInstall(
                          () => selectionInstallCount += 1,
                          () => SelectionKernel.observePreparedInstallWork(
                            selectionInstallWork.add,
                            () => InteractionEngine.observeCleanupWork(
                              cleanupWork.add,
                              () => InteractionEngine.observeCleanup(
                                cleanupReasons.add,
                                () => CommitApplier.observeSealedDeliveryWork(
                                  (work) => sealedDeliveryWork = work,
                                  () => switch (route) {
                                    _DeletionRoute.selection =>
                                      root.selection.deleteSelection(),
                                    _DeletionRoute.eraser => root.handlePointer(
                                      _pointer(
                                        CanvasPointerLifecyclePhase.up,
                                        const Offset(60, 0),
                                      ),
                                    ),
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  return _DeletionWorkResult(
    root: root,
    callbacks: callbacks,
    construction: construction,
    requestEntryCopies: requestWork.length,
    preparedWork: preparedWork,
    installWork: installWork,
    selectionInstallCount: selectionInstallCount,
    sparseWork: _sparseWorkCounts(sparseEvents),
    sealedDeliveryWork: _sealedWorkVector(sealedDeliveryWork),
    cleanupReasons: cleanupReasons,
    ownerLoopWork: _OwnerLoopWork(
      idAdmissions: _idAdmissionCounts(idAdmissions),
      actionCommittedReads: actionElementReads
          .where(
            (event) =>
                event.phase == DeletionActionElementReadPhase.committedAction,
          )
          .length,
      actionPayloadReads: actionElementReads
          .where(
            (event) => event.phase == DeletionActionElementReadPhase.payload,
          )
          .length,
      eraserEntryIdVisits: eraserIdMaterializationWork.length,
      cleanupAugmentation: augmentationWork,
      cleanupWork: cleanupWork,
      selectionInstallWork: selectionInstallWork,
    ),
    projectionEventsAtResolver: projectionEventsAtResolver,
    projectionEventsAfterResolver:
        projectionWork.length - projectionEventsAtResolver,
    entryRouteEventsAfterResolver:
        entryRouteWork.length - entryRouteEventsAtResolver,
  );
}

// Keeping this branch matrix together makes the counter contrast readable.
// It is one accepted-outcome oracle, not independent test behavior.
// ignore: halstead-volume, source-lines-of-code
void _expectNonemptyConstruction(
  _DeletionWorkResult result,
  _DeletionRoute route,
  _ResolverOutcome outcome, {
  required int targetCount,
}) {
  expect(result.callbacks, 1);
  expect(result.construction, [
    route == _DeletionRoute.selection
        ? RuntimeDeletionRouteConstructionKind.selectionPreparedCommit
        : RuntimeDeletionRouteConstructionKind.eraserPreparedCommit,
    RuntimeDeletionRouteConstructionKind.request,
  ]);
  expect(result.requestEntryCopies, targetCount);
  if (outcome == _ResolverOutcome.accept) {
    expect(result.sealedDeliveryWork, (
      preparations: 1,
      effectLengthReads: 1,
      effectIterations: 2,
      effectElements: route == _DeletionRoute.selection ? 8 : 10,
      actionLengthReads: 3,
      actionIterations: 0,
      actionElements: 1,
    ));
    expect(result.preparedWork, [
      PreparedInteractionApplyWorkEvent.selectionBackingTransferred,
      PreparedInteractionApplyWorkEvent.prepared,
      PreparedInteractionApplyWorkEvent.ownershipReleased,
      PreparedInteractionApplyWorkEvent.consumed,
    ]);
    expect(result.installWork, [
      DeletionPreparedInstallEvent.bound,
      DeletionPreparedInstallEvent.installed,
    ]);
    expect(result.selectionInstallCount, 1);
    _expectExactOwnerLoopWork(result, route, targetCount: targetCount);
    final deliveryWork = result.sealedDeliveryWork;
    expect(deliveryWork, isNotNull);
    expect(deliveryWork?.preparations, 1);
    expect(deliveryWork?.actionElements, 1);
  } else {
    expect(result.preparedWork, [
      PreparedInteractionApplyWorkEvent.selectionBackingTransferred,
      PreparedInteractionApplyWorkEvent.prepared,
      PreparedInteractionApplyWorkEvent.ownershipReleased,
      PreparedInteractionApplyWorkEvent.discarded,
    ]);
    expect(result.installWork, [DeletionPreparedInstallEvent.bound]);
    expect(result.selectionInstallCount, 1);
  }
}

void _expectExactOwnerLoopWork(
  _DeletionWorkResult result,
  _DeletionRoute route, {
  required int targetCount,
}) {
  expect(result.ownerLoopWork.idAdmissions, isEmpty);
  expect(result.ownerLoopWork.actionCommittedReads, targetCount);
  expect(result.ownerLoopWork.actionPayloadReads, targetCount);
  expect(
    result.ownerLoopWork.eraserEntryIdVisits,
    route == _DeletionRoute.eraser ? targetCount : 0,
  );
  expect(result.ownerLoopWork.selectionInstallWork, [
    PreparedSelectionInstallWorkEvent.ownedBackingPrepared,
  ]);
  expect(
    result.ownerLoopWork.cleanupAugmentation,
    route == _DeletionRoute.eraser
        ? [
            for (var index = 0; index < 5; index += 1)
              RuntimePointerCleanupAugmentationWorkEvent.baseEffectVisit,
            RuntimePointerCleanupAugmentationWorkEvent.cleanupEffectVisit,
          ]
        : isEmpty,
  );
  expect(
    result.ownerLoopWork.cleanupWork,
    route == _DeletionRoute.eraser
        ? [
            InteractionCleanupWorkEvent.started,
            InteractionCleanupWorkEvent.previewCleared,
            InteractionCleanupWorkEvent.sessionReleased,
          ]
        : isEmpty,
  );
}

Map<String, int> _idAdmissionCounts(List<IdAdmissionWorkEvent> events) => {
  for (final prefix in ['e', 'l', 'r'])
    prefix: events
        .where(
          (event) =>
              event.prefix == prefix &&
              event.kind == IdAdmissionWorkKind.sparseLedgerVisit,
        )
        .length,
}..removeWhere((_, count) => count == 0);

void _expectSelectionWithoutDeletion({
  required CanvasDocument document,
  required CanvasRuntimeConfig config,
  required List<CanvasElementId> select,
}) {
  var callbacks = 0;
  final root = runtimeRootWithCommittedDocumentSeed(
    document,
    config: CanvasRuntimeConfig(
      deletionCommitResolver: (_) {
        callbacks += 1;
        return config.deletionCommitResolver(_emptyRequest);
      },
      selectionDeletePolicy: config.selectionDeletePolicy,
      eraserElementKinds: config.eraserElementKinds,
    ),
  );
  addTearDown(root.dispose);
  root.selection.setSelection(select);
  final construction = <RuntimeDeletionRouteConstructionKind>[];
  final requestWork = <RuntimeDeletionRequestWorkEvent>[];
  final preparedWork = <PreparedInteractionApplyWorkEvent>[];
  RuntimeRoot.observeDeletionRouteConstruction(
    construction.add,
    () => RuntimeRoot.observeDeletionRequestWork(
      requestWork.add,
      () => CommitApplier.observePreparedInteractionWork(
        preparedWork.add,
        root.selection.deleteSelection,
      ),
    ),
  );
  expect(callbacks, 0);
  expect(construction, isEmpty);
  expect(requestWork, isEmpty);
  expect(preparedWork, isEmpty);
}

void _expectEraserWithoutDeletion({
  required CanvasDocument document,
  required CanvasRuntimeConfig config,
  required Offset terminalPosition,
}) {
  var callbacks = 0;
  final root = runtimeRootWithCommittedDocumentSeed(
    document,
    config: CanvasRuntimeConfig(
      deletionCommitResolver: (_) {
        callbacks += 1;
        return config.deletionCommitResolver(_emptyRequest);
      },
      eraserElementKinds: config.eraserElementKinds,
    ),
  );
  addTearDown(root.dispose);
  _beginEraser(root, terminalPosition, start: terminalPosition);
  final construction = <RuntimeDeletionRouteConstructionKind>[];
  final requestWork = <RuntimeDeletionRequestWorkEvent>[];
  final preparedWork = <PreparedInteractionApplyWorkEvent>[];
  RuntimeRoot.observeDeletionRouteConstruction(
    construction.add,
    () => RuntimeRoot.observeDeletionRequestWork(
      requestWork.add,
      () => CommitApplier.observePreparedInteractionWork(
        preparedWork.add,
        () => root.handlePointer(
          _pointer(CanvasPointerLifecyclePhase.up, terminalPosition),
        ),
      ),
    ),
  );
  expect(callbacks, 0);
  expect(construction, isEmpty);
  expect(requestWork, isEmpty);
  expect(preparedWork, isEmpty);
}

void _expectTouchedSparseWork(
  Map<String, int> sparseWork, {
  required int targetCount,
}) {
  expect(sparseWork, isNotEmpty);
  final replayVisits = sparseWork['replay/journalVisit/touched'] ?? 0;
  final finalizationVisits =
      sparseWork['finalization/journalVisit/touched'] ?? 0;
  expect(replayVisits, lessThanOrEqualTo(targetCount));
  expect(finalizationVisits, lessThanOrEqualTo(targetCount));
}

Map<String, int> _sparseWorkCounts(List<SparseTransactionWorkEvent> events) {
  final counts = <String, int>{};
  for (final event in events) {
    final key = '${event.phase.name}/${event.kind.name}/${event.ledger?.name}';
    counts.update(key, (count) => count + 1, ifAbsent: () => 1);
  }
  return counts;
}

_SealedWorkVector? _sealedWorkVector(CommitSealedDeliveryWork? work) {
  if (work == null) {
    return null;
  }
  return (
    preparations: work.preparations,
    effectLengthReads: work.effectLengthReads,
    effectIterations: work.effectIterations,
    effectElements: work.effectElements,
    actionLengthReads: work.actionLengthReads,
    actionIterations: work.actionIterations,
    actionElements: work.actionElements,
  );
}

void _beginEraser(
  RuntimeRoot root,
  Offset endpoint, {
  Offset start = Offset.zero,
}) {
  root.setInteractionMode(CanvasInteractionMode.draw);
  root.setDrawStyle(CanvasDrawStyle(tool: CanvasDrawTool.eraser));
  root.handlePointer(_pointer(CanvasPointerLifecyclePhase.down, start));
  root.handlePointer(_pointer(CanvasPointerLifecyclePhase.move, endpoint));
}

CanvasPointerSample _pointer(
  CanvasPointerLifecyclePhase phase,
  Offset position,
) => CanvasPointerSample(
  pointerId: 31,
  phase: phase,
  position: position,
  kind: PointerDeviceKind.touch,
  timestampMs: 31,
);

CanvasDocument _document({
  required int targetCount,
  int unrelatedElementCount = 0,
  bool includeNotDeletable = false,
}) => CanvasDocument(
  layers: [
    CanvasLayer(
      id: CanvasLayerId('targets'),
      elements: [
        for (var index = 0; index < targetCount; index += 1)
          CanvasRectElement(
            id: CanvasElementId('target-$index'),
            transform: CanvasTransform.translation(Offset(index * 20, 0)),
            size: const Size(10, 10),
          ),
        if (includeNotDeletable)
          CanvasRectElement(
            id: CanvasElementId('blocked'),
            isDeletable: false,
            size: const Size(10, 10),
          ),
      ],
    ),
    CanvasLayer(
      id: CanvasLayerId('unrelated'),
      elements: [
        for (var index = 0; index < unrelatedElementCount; index += 1)
          CanvasRectElement(
            id: CanvasElementId('unrelated-$index'),
            transform: CanvasTransform.translation(
              Offset(1000 + index * 20, 0),
            ),
            size: const Size(10, 10),
          ),
      ],
    ),
  ],
);

List<CanvasElementId> _targetIds(int count) => [
  for (var index = 0; index < count; index += 1)
    CanvasElementId('target-$index'),
];

final _emptyRequest = CanvasDeletionCommitRequest(
  operation: CanvasDeletionOperation.deleteSelection,
  entries: const [],
);

enum _DeletionRoute { selection, eraser }

enum _EraserDeliveryFailure { state, action }

enum _ResolverOutcome {
  accept,
  cancel,
  error,
  exception,
  object;

  static const nonemptyValues = values;
  static const discardValues = [cancel, error, exception, object];

  CanvasDeletionDecision resolve() {
    switch (this) {
      case accept:
        return CanvasDeletionDecision.accept;
      case cancel:
        return CanvasDeletionDecision.cancel;
      case error:
        throw StateError('resolver Error');
      case exception:
        throw Exception('resolver Exception');
      case object:
        // The public resolver intentionally classifies ordinary thrown objects.
        // ignore: only_throw_errors
        throw _OrdinaryThrownObject();
    }
  }
}

final class _OrdinaryThrownObject {}

final class _DeletionWorkResult {
  const _DeletionWorkResult({
    required this.root,
    required this.callbacks,
    required this.construction,
    required this.requestEntryCopies,
    required this.preparedWork,
    required this.installWork,
    required this.selectionInstallCount,
    required this.sparseWork,
    required this.sealedDeliveryWork,
    required this.cleanupReasons,
    required this.ownerLoopWork,
    required this.projectionEventsAtResolver,
    required this.projectionEventsAfterResolver,
    required this.entryRouteEventsAfterResolver,
  });

  final RuntimeRoot root;
  final int callbacks;
  final List<RuntimeDeletionRouteConstructionKind> construction;
  final int requestEntryCopies;
  final List<PreparedInteractionApplyWorkEvent> preparedWork;
  final List<DeletionPreparedInstallEvent> installWork;
  final int selectionInstallCount;
  final Map<String, int> sparseWork;
  final _SealedWorkVector? sealedDeliveryWork;
  final List<PointerCleanupReason> cleanupReasons;
  final _OwnerLoopWork ownerLoopWork;
  final int projectionEventsAtResolver;
  final int projectionEventsAfterResolver;
  final int entryRouteEventsAfterResolver;

  void dispose() => root.dispose();
}

@immutable
final class _OwnerLoopWork {
  const _OwnerLoopWork({
    required this.idAdmissions,
    required this.actionCommittedReads,
    required this.actionPayloadReads,
    required this.eraserEntryIdVisits,
    required this.cleanupAugmentation,
    required this.cleanupWork,
    required this.selectionInstallWork,
  });

  final Map<String, int> idAdmissions;
  final int actionCommittedReads;
  final int actionPayloadReads;
  final int eraserEntryIdVisits;
  final List<RuntimePointerCleanupAugmentationWorkEvent> cleanupAugmentation;
  final List<InteractionCleanupWorkEvent> cleanupWork;
  final List<PreparedSelectionInstallWorkEvent> selectionInstallWork;

  @override
  bool operator ==(Object other) =>
      other is _OwnerLoopWork &&
      _sameMap(idAdmissions, other.idAdmissions) &&
      actionCommittedReads == other.actionCommittedReads &&
      actionPayloadReads == other.actionPayloadReads &&
      eraserEntryIdVisits == other.eraserEntryIdVisits &&
      listEquals(cleanupAugmentation, other.cleanupAugmentation) &&
      listEquals(cleanupWork, other.cleanupWork) &&
      listEquals(selectionInstallWork, other.selectionInstallWork);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(idAdmissions.entries),
    actionCommittedReads,
    actionPayloadReads,
    eraserEntryIdVisits,
    Object.hashAll(cleanupAugmentation),
    Object.hashAll(cleanupWork),
    Object.hashAll(selectionInstallWork),
  );
}

bool _sameMap(Map<String, int> left, Map<String, int> right) =>
    left.length == right.length &&
    left.entries.every((entry) => right[entry.key] == entry.value);

final class _AcceptedEraserDeliveryFailureResult {
  const _AcceptedEraserDeliveryFailureResult({
    required this.root,
    required this.callbacks,
    required this.cleanupReasons,
    required this.cleanupWork,
    required this.deliveryErrors,
    required this.remainingIds,
    required this.selectionIds,
  });

  final RuntimeRoot root;
  final int callbacks;
  final List<PointerCleanupReason> cleanupReasons;
  final List<InteractionCleanupWorkEvent> cleanupWork;
  final List<Object> deliveryErrors;
  final List<CanvasElementId> remainingIds;
  final Set<CanvasElementId> selectionIds;

  void dispose() => root.dispose();
}

typedef _SealedWorkVector = ({
  int preparations,
  int effectLengthReads,
  int effectIterations,
  int effectElements,
  int actionLengthReads,
  int actionIterations,
  int actionElements,
});
