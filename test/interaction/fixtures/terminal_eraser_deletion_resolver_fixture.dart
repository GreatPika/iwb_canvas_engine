// Terminal eraser deletion has a distinct pointer/cleanup lifecycle, so its
// resolver evidence stays separate from selection-command scenarios.
// The real pointer, Store, guard, diagnostics, and delivery seams must remain
// explicit in this one terminal-route fixture.
// ignore_for_file: missing-test-assertion, number-of-imports

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/deletion_entry_projection_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/prepared_selection_effect.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/resolver_mutation_guard.dart';
import 'package:iwb_canvas_engine/src/diagnostics/diagnostic_code.dart';
import 'package:iwb_canvas_engine/src/edit/commit_applier.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_engine.dart';
import 'package:iwb_canvas_engine/src/interaction/pointer_cleanup_protocol.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import 'package:iwb_canvas_engine/src/selection/selection_kernel.dart';
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';

import '../../support/accept_deletion_commit.dart';

// Route registrations stay visible together so every terminal callback family
// remains auditable without a second fixture registry that can drift.
// ignore: source-lines-of-code
void main() {
  test(
    'terminal eraser sends the exact Store entries before accepting',
    () async {
      await _acceptsExactEntriesAndCleansBeforeDelivery();
    },
  );
  test('terminal eraser keeps Store order and filters mixed kinds', () {
    _mixedKindTerminalRequestKeepsStoreFacts();
  });
  test('terminal eraser retains empty layers and resource descriptors', () {
    _terminalEraserRetainsLayersAndResources();
  });
  test(
    'terminal eraser cancel and ordinary resolver throws leave no commit',
    () {
      _terminalCancelAndThrowAreContained();
    },
  );
  for (final family in _guardedEraserMutationFamilies) {
    test('terminal eraser rejects ${family.name} in its resolver', () {
      _terminalEraserCallbackUsesExistingGuard(family);
    });
  }
  test('terminal eraser resolver permits reads and client-owned undo work', () {
    _terminalResolverAllowsReadsAndClientUndoWork();
  });
  test('unhandled eraser guard rejection keeps only its guard diagnostic', () {
    _unhandledEraserGuardRejectionIsNotDeletionFailure();
  });
  test(
    'terminal eraser remains accepted after state or action delivery failure',
    () async {
      await _terminalEraserDeliveryFailuresRemainFinal();
    },
  );
  test('terminal eraser non-delete terminals stay resolver-free', () {
    _terminalEraserNonDeleteTerminalsStaySilent();
  });
  test('terminal eraser preparation failures clean and rethrow unchanged', () {
    _terminalEraserPreparationFailuresFailFast();
  });
}

// Exact request identity and cleanup-before-public-delivery share this one
// terminal witness: either can regress while the final document still looks OK.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
Future<void> _acceptsExactEntriesAndCleansBeforeDelivery() async {
  CanvasDeletionCommitRequest? request;
  final events = <String>[];
  final store = DocumentStoreKernel.withCommittedDocumentForTesting(
    CommittedDocument(_document()),
  );
  final root = RuntimeRoot.test(
    store: store,
    config: CanvasRuntimeConfig(
      deletionCommitResolver: (candidate) {
        request = candidate;
        events.add('resolver-return');
        return CanvasDeletionDecision.accept;
      },
    ),
  );
  final surface = Object();
  root.attachSurface(surface);
  addTearDown(() {
    root.detachSurface(surface);
    root.dispose();
  });
  var terminalDelivery = false;
  root.state.addListener(() {
    if (!terminalDelivery) return;
    expect(root.preview, isA<CanvasNoPreview>());
    expect(root.interactionEngine.activeSession, isNull);
    events.add('state');
  });
  final subscription = root.actions.listen((_) => events.add('action'));
  addTearDown(subscription.cancel);
  List<DeletionEntryFacts>? projected;
  final construction = <RuntimeDeletionRouteConstructionKind>[];

  root.selection.setSelection([CanvasElementId('erasable')]);
  _startEraser(root);
  terminalDelivery = true;
  RuntimeRoot.observeDeletionRouteConstruction(
    construction.add,
    () => RuntimeRoot.observeRouteTemporalEvents(
      (event) {
        if (event.route == RuntimeNonTextRoute.eraser &&
            event.kind == RuntimeRouteTemporalEventKind.routeCleanupCompleted) {
          events.add('cleanup');
        }
      },
      () => SelectionKernel.observePreparedInstall(
        () => events.add('selection'),
        () => DocumentStoreKernel.observeDeletionPreparedInstall(
          (event) {
            if (event == DeletionPreparedInstallEvent.installed) {
              events.add('store');
            }
          },
          () => DocumentStoreKernel.observeDeletionEntryProjection(
            (entries) => projected = entries,
            () => root.handlePointer(_sample(CanvasPointerLifecyclePhase.up)),
          ),
        ),
      ),
    ),
  );
  events.add('route-return');
  await Future<void>.delayed(Duration.zero);

  final received = request;
  if (received == null) {
    fail('The configured deletion resolver did not receive an eraser request.');
  }
  final observedEntries = projected;
  if (observedEntries == null) {
    fail('Terminal eraser did not read Store deletion entries.');
  }
  expect(received.operation, CanvasDeletionOperation.erase);
  expect(received.entries, hasLength(1));
  expect(received.entries.single.element, same(observedEntries.single.element));
  expect(received.entries.single.layerId, observedEntries.single.layerId);
  expect(
    received.entries.single.elementIndex,
    observedEntries.single.elementIndex,
  );
  expect(root.preview, isA<CanvasNoPreview>());
  expect(root.interactionEngine.activeSession, isNull);
  expect(events, [
    'resolver-return',
    'store',
    'selection',
    'cleanup',
    'state',
    'action',
    'route-return',
  ]);
  expect(construction, [
    RuntimeDeletionRouteConstructionKind.eraserPreparedCommit,
    RuntimeDeletionRouteConstructionKind.request,
  ]);
}

// This route-local witness consumes the Unit-2 filter at the real pointer
// terminal: a request rebuilt from candidates would include the text element.
// ignore: halstead-volume, source-lines-of-code
void _mixedKindTerminalRequestKeepsStoreFacts() {
  CanvasDeletionCommitRequest? request;
  final root = RuntimeRoot.test(
    store: DocumentStoreKernel.withCommittedDocumentForTesting(
      CommittedDocument(_mixedKindDocument()),
    ),
    config: CanvasRuntimeConfig(
      deletionCommitResolver: (candidate) {
        request = candidate;
        return CanvasDeletionDecision.accept;
      },
      eraserElementKinds: const {CanvasElementKind.rect},
    ),
  );
  addTearDown(root.dispose);
  final actions = <CanvasActionCommitted>[];
  final subscription = root.actions.listen(actions.add);
  addTearDown(subscription.cancel);
  List<DeletionEntryFacts>? projected;

  _startEraser(root);
  DocumentStoreKernel.observeDeletionEntryProjection(
    (entries) => projected = entries,
    () => root.handlePointer(_sample(CanvasPointerLifecyclePhase.up)),
  );

  final received = request;
  final storeEntries = projected;
  if (received == null || storeEntries == null) {
    fail('The terminal eraser route did not expose its Store projection.');
  }
  expect(received.entries, hasLength(3));
  expect(received.entries.map((entry) => entry.element.id), [
    CanvasElementId('lower-a'),
    CanvasElementId('lower-c'),
    CanvasElementId('upper-b'),
  ]);
  for (var index = 0; index < received.entries.length; index += 1) {
    expect(received.entries[index].element, same(storeEntries[index].element));
    expect(received.entries[index].layerId, storeEntries[index].layerId);
    expect(
      received.entries[index].elementIndex,
      storeEntries[index].elementIndex,
    );
  }
  expect(
    received.entries.map((entry) => entry.element.kind),
    isNot(contains(CanvasElementKind.text)),
  );
  expect(actions, hasLength(1));
  expect(actions.single.type, CanvasActionType.erase);
  expect(actions.single.elementIds, [
    CanvasElementId('lower-a'),
    CanvasElementId('lower-c'),
    CanvasElementId('upper-b'),
  ]);
  expect(actions.single.timestampMs, 23);
}

// Retention is a real terminal-route fact: neither empty layers nor unused
// descriptors may disappear until their explicit public owners are invoked.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _terminalEraserRetainsLayersAndResources() {
  final imageId = CanvasResourceId('eraser-image-resource');
  final vectorId = CanvasResourceId('eraser-vector-resource');
  final image = CanvasImageResource(
    id: imageId,
    source: CanvasResourceSource.appKey('eraser-image-source'),
    contentHash: 'eraser-image-hash',
    byteLength: 21,
    metadata: CanvasMetadata.fromMap({'kind': 'image'}),
  );
  final vector = CanvasVectorResource(
    id: vectorId,
    source: CanvasResourceSource.appKey('eraser-vector-source'),
    contentHash: 'eraser-vector-hash',
    byteLength: 22,
    metadata: CanvasMetadata.fromMap({'kind': 'vector'}),
  );
  final root = RuntimeRoot.test(
    store: DocumentStoreKernel.withCommittedDocumentForTesting(
      CommittedDocument(
        CanvasDocument(
          resources: [image, vector],
          layers: [
            CanvasLayer(
              id: CanvasLayerId('background-adjacent'),
              metadata: CanvasMetadata.fromMap({'position': 'first'}),
              elements: [
                CanvasRectElement(
                  id: CanvasElementId('first-only'),
                  size: const Size(2, 2),
                ),
              ],
            ),
            CanvasLayer(
              id: CanvasLayerId('ordinary'),
              metadata: CanvasMetadata.fromMap({'position': 'ordinary'}),
              elements: [
                CanvasImageElement(
                  id: CanvasElementId('image-only'),
                  resourceId: imageId,
                  size: const Size(2, 2),
                ),
                CanvasVectorElement(
                  id: CanvasElementId('vector-only'),
                  resourceId: vectorId,
                  size: const Size(2, 2),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    config: const CanvasRuntimeConfig(
      deletionCommitResolver: acceptDeletionCommit,
    ),
  );
  addTearDown(root.dispose);
  _startEraser(root);

  root.handlePointer(_sample(CanvasPointerLifecyclePhase.up));

  final layers = root.readDocument().layers;
  expect(layers.map((layer) => (layer.id, layer.metadata)), [
    (
      CanvasLayerId('background-adjacent'),
      CanvasMetadata.fromMap({'position': 'first'}),
    ),
    (
      CanvasLayerId('ordinary'),
      CanvasMetadata.fromMap({'position': 'ordinary'}),
    ),
  ]);
  expect(layers.every((layer) => layer.elements.isEmpty), isTrue);
  _expectRetainedDescriptor(root.resources.resourceById(imageId), image);
  _expectRetainedDescriptor(root.resources.resourceById(vectorId), vector);
  var imageRemoved = false;
  var vectorRemoved = false;
  root.edits.edit((edit) {
    imageRemoved = edit.removeUnusedResource(imageId);
    vectorRemoved = edit.removeUnusedResource(vectorId);
  });
  expect(imageRemoved, isTrue);
  expect(vectorRemoved, isTrue);
  expect(root.resources.resourceById(imageId), isNull);
  expect(root.resources.resourceById(vectorId), isNull);
}

// Shared pointer setup keeps both no-effect outcomes against one cleanup oracle.
// ignore: halstead-volume, source-lines-of-code
void _terminalCancelAndThrowAreContained() {
  for (final thrown in <Object?>[
    null,
    StateError('eraser Error'),
    Exception('eraser Exception'),
    _ThrownEraserObject(),
  ]) {
    var calls = 0;
    final root = RuntimeRoot.test(
      store: DocumentStoreKernel.withCommittedDocumentForTesting(
        CommittedDocument(_document()),
      ),
      config: CanvasRuntimeConfig(
        deletionCommitResolver: (_) {
          calls += 1;
          if (thrown != null) {
            // This terminal route deliberately covers ordinary object throws.
            // ignore: only_throw_errors
            throw thrown;
          }
          return CanvasDeletionDecision.cancel;
        },
        diagnosticPolicy: thrown != null
            ? const CanvasDiagnosticPolicy.summary()
            : const CanvasDiagnosticPolicy.disabled(),
      ),
    );
    final surface = Object();
    root.attachSurface(surface);
    addTearDown(() {
      root.detachSurface(surface);
      root.dispose();
    });
    final before = root.readDocument();
    final construction = <RuntimeDeletionRouteConstructionKind>[];
    _startEraser(root);

    expect(
      () => RuntimeRoot.observeDeletionRouteConstruction(
        construction.add,
        () => root.handlePointer(_sample(CanvasPointerLifecyclePhase.up)),
      ),
      returnsNormally,
    );
    expect(calls, 1);
    expect(construction, [
      RuntimeDeletionRouteConstructionKind.eraserPreparedCommit,
      RuntimeDeletionRouteConstructionKind.request,
    ]);
    expect(root.readDocument(), before);
    expect(root.preview, isA<CanvasNoPreview>());
    expect(root.interactionEngine.activeSession, isNull);
    if (thrown != null) {
      expect(root.diagnosticRecords, hasLength(1));
      expect(
        root.diagnosticRecords.single.code,
        const DiagnosticCode.interaction(
          InteractionDiagnosticCode.deletionResolverFailed,
        ),
      );
      expect(root.diagnosticRecords.single.details, {
        'operation': 'erase',
        'errorKind': thrown is Error
            ? 'error'
            : thrown is Exception
            ? 'exception'
            : 'object',
      });
    } else {
      expect(root.diagnosticRecords, isEmpty);
    }
  }
}

// The callback actions and terminal cleanup must share one real-route witness.
// ignore: halstead-volume
void _terminalEraserCallbackUsesExistingGuard(
  _GuardedEraserMutationFamily family,
) {
  late RuntimeRoot root;
  root = RuntimeRoot.test(
    store: DocumentStoreKernel.withCommittedDocumentForTesting(
      CommittedDocument(_document()),
    ),
    config: CanvasRuntimeConfig(
      deletionCommitResolver: (_) {
        expect(root.readDocument().layers, isNotEmpty);
        expect(
          () => family.invoke(root),
          throwsA(isA<ResolverCallbackRejection>()),
        );
        return CanvasDeletionDecision.cancel;
      },
    ),
  );
  final surface = Object();
  root.attachSurface(surface);
  addTearDown(() {
    root.detachSurface(surface);
    root.dispose();
  });
  final before = _TerminalGuardSnapshot.capture(root);
  _startEraser(root);
  root.handlePointer(_sample(CanvasPointerLifecyclePhase.up));
  before.expectCommittedFactsUnchanged(root);
  expect(root.preview, isA<CanvasNoPreview>());
  expect(root.interactionEngine.activeSession, isNull);
}

void _terminalResolverAllowsReadsAndClientUndoWork() {
  final clientUndo = <CanvasDocument>[];
  late RuntimeRoot root;
  root = RuntimeRoot.test(
    store: DocumentStoreKernel.withCommittedDocumentForTesting(
      CommittedDocument(_document()),
    ),
    config: CanvasRuntimeConfig(
      deletionCommitResolver: (_) {
        final document = root.readDocument();
        clientUndo.add(document);
        expect(clientUndo.removeLast(), same(document));
        return CanvasDeletionDecision.cancel;
      },
    ),
  );
  addTearDown(root.dispose);
  final before = root.readDocument();
  _startEraser(root);

  root.handlePointer(_sample(CanvasPointerLifecyclePhase.up));

  expect(clientUndo, isEmpty);
  expect(root.readDocument(), before);
  expect(root.preview, isA<CanvasNoPreview>());
  expect(root.interactionEngine.activeSession, isNull);
}

// This keeps the real pointer route, cleanup, no-effect outcome, and bounded
// diagnostic oracle adjacent; splitting it would introduce a fake lifecycle.
// ignore: halstead-volume
void _unhandledEraserGuardRejectionIsNotDeletionFailure() {
  late RuntimeRoot root;
  root = RuntimeRoot.test(
    store: DocumentStoreKernel.withCommittedDocumentForTesting(
      CommittedDocument(_document()),
    ),
    config: CanvasRuntimeConfig(
      deletionCommitResolver: (_) {
        root.setCameraOffset(const Offset(1, 1));
        return CanvasDeletionDecision.cancel;
      },
      diagnosticPolicy: const CanvasDiagnosticPolicy.summary(),
    ),
  );
  addTearDown(root.dispose);
  final before = root.readDocument();
  final actions = <CanvasActionCommitted>[];
  final subscription = root.actions.listen(actions.add);
  addTearDown(subscription.cancel);
  _startEraser(root);

  expect(
    () => root.handlePointer(_sample(CanvasPointerLifecyclePhase.up)),
    returnsNormally,
  );

  expect(root.readDocument(), before);
  expect(actions, isEmpty);
  expect(root.preview, isA<CanvasNoPreview>());
  expect(root.interactionEngine.activeSession, isNull);
  expect(root.diagnosticRecords, hasLength(1));
  final record = root.diagnosticRecords.single;
  expect(
    record.code,
    const DiagnosticCode.interaction(
      InteractionDiagnosticCode.resolverReentrantMutationRejected,
    ),
  );
  expect(record.details, {'operation': 'runtimeMutation'});
}

// The two real public listener owners share the terminal acceptance oracle:
// cleanup must already be complete when either one becomes fallible.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
Future<void> _terminalEraserDeliveryFailuresRemainFinal() async {
  for (final failure in [_DeliveryFailure.state, _DeliveryFailure.action]) {
    var resolverCalls = 0;
    final events = <String>[];
    final store = DocumentStoreKernel.withCommittedDocumentForTesting(
      CommittedDocument(_document()),
    );
    final root = RuntimeRoot.test(
      store: store,
      config: CanvasRuntimeConfig(
        deletionCommitResolver: (_) {
          resolverCalls += 1;
          events.add('resolver-return');
          return CanvasDeletionDecision.accept;
        },
      ),
    );
    final surface = Object();
    root.attachSurface(surface);
    addTearDown(() {
      root.detachSurface(surface);
      root.dispose();
    });
    var armed = false;
    final errors = <Object>[];
    final previousFlutterError = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exception);
    addTearDown(() => FlutterError.onError = previousFlutterError);
    root.state.addListener(() {
      if (!armed) return;
      expect(root.preview, isA<CanvasNoPreview>());
      expect(root.interactionEngine.activeSession, isNull);
      events.add('state');
      if (failure == _DeliveryFailure.state) {
        throw StateError('state listener failed');
      }
    });
    late StreamSubscription<CanvasActionCommitted> throwing;
    runZonedGuarded(() {
      throwing = root.actions.listen((_) {
        if (!armed) return;
        events.add('action');
        if (failure == _DeliveryFailure.action) {
          throw StateError('action listener failed');
        }
      });
    }, (error, _) => errors.add(error));
    root.selection.setSelection([CanvasElementId('erasable')]);
    _startEraser(root);
    armed = true;
    RuntimeRoot.observeRouteTemporalEvents(
      (event) {
        if (event.route == RuntimeNonTextRoute.eraser &&
            event.kind == RuntimeRouteTemporalEventKind.routeCleanupCompleted) {
          events.add('cleanup');
        }
      },
      () => SelectionKernel.observePreparedInstall(
        () => events.add('selection'),
        () => DocumentStoreKernel.observeDeletionPreparedInstall((event) {
          if (event == DeletionPreparedInstallEvent.installed) {
            events.add('store');
          }
        }, () => root.handlePointer(_sample(CanvasPointerLifecyclePhase.up))),
      ),
    );
    // Record immediately after the public terminal returns. A deferred Store
    // or Selection install would move this ahead of the owned commit boundary.
    events.add('route-return');
    await Future<void>.delayed(Duration.zero);

    expect(resolverCalls, 1);
    expect(errors, isNotEmpty);
    expect(_idsAfterEraser(root), isEmpty);
    expect(root.preview, isA<CanvasNoPreview>());
    expect(root.interactionEngine.activeSession, isNull);
    expect(events, [
      'resolver-return',
      'store',
      'selection',
      'cleanup',
      'state',
      'action',
      'route-return',
    ]);
    await throwing.cancel();
  }
}

List<CanvasElementId> _idsAfterEraser(RuntimeRoot root) => [
  for (final layer in root.readDocument().layers)
    for (final element in layer.elements) element.id,
];

enum _DeliveryFailure { state, action }

// Empty, policy-filtered, and malformed terminal inputs all enter the real
// pointer facade. Their construction and cleanup owners are observed directly
// so a future eager deletion route cannot hide behind the same final document.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _terminalEraserNonDeleteTerminalsStaySilent() {
  _expectSilentEraserTerminal(
    document: CanvasDocument(),
    eraserElementKinds: null,
    terminal: (root) =>
        root.handlePointer(_sample(CanvasPointerLifecyclePhase.up)),
    expectedCleanup: PointerCleanupReason.noOpTerminal,
  );
  _expectSilentEraserTerminal(
    document: _document(),
    eraserElementKinds: const {CanvasElementKind.text},
    terminal: (root) =>
        root.handlePointer(_sample(CanvasPointerLifecyclePhase.up)),
    expectedCleanup: PointerCleanupReason.noOpTerminal,
  );
  _expectSilentEraserTerminal(
    document: _document(),
    eraserElementKinds: null,
    terminal: (root) => root.handlePointer(
      CanvasPointerTerminalCleanup(
        pointerId: 3,
        phase: CanvasPointerLifecyclePhase.up,
        kind: PointerDeviceKind.touch,
        timestampMs: 23,
      ),
    ),
    expectedCleanup: PointerCleanupReason.invalidTerminal,
  );
}

// One helper keeps the public route setup and its complete no-effect oracle
// together; splitting them would duplicate the same lifecycle witness.
// ignore: halstead-volume
void _expectSilentEraserTerminal({
  required CanvasDocument document,
  required Set<CanvasElementKind>? eraserElementKinds,
  required void Function(RuntimeRoot root) terminal,
  required PointerCleanupReason expectedCleanup,
}) {
  var resolverCalls = 0;
  final root = RuntimeRoot.test(
    store: DocumentStoreKernel.withCommittedDocumentForTesting(
      CommittedDocument(document),
    ),
    config: CanvasRuntimeConfig(
      deletionCommitResolver: (_) {
        resolverCalls += 1;
        return CanvasDeletionDecision.cancel;
      },
      eraserElementKinds: eraserElementKinds,
    ),
  );
  addTearDown(root.dispose);
  final actions = <CanvasActionCommitted>[];
  final subscription = root.actions.listen(actions.add);
  addTearDown(subscription.cancel);
  final beforeDocument = root.readDocument();
  final beforeSelection = root.selection.selectedElementIds;
  final construction = <RuntimeDeletionRouteConstructionKind>[];
  final cleanupReasons = <PointerCleanupReason>[];

  _startEraser(root);
  RuntimeRoot.observeDeletionRouteConstruction(
    construction.add,
    () => InteractionEngine.observeCleanup(
      cleanupReasons.add,
      () => terminal(root),
    ),
  );

  expect(resolverCalls, 0);
  expect(construction, isEmpty);
  expect(cleanupReasons, [expectedCleanup]);
  expect(root.readDocument(), beforeDocument);
  expect(root.selection.selectedElementIds, beforeSelection);
  expect(actions, isEmpty);
  expect(root.diagnosticRecords, isEmpty);
  expect(root.preview, isA<CanvasNoPreview>());
  expect(root.interactionEngine.activeSession, isNull);
}

// Preparation is intentionally faulted at the two real owner boundaries. The
// public pointer call proves the error cannot become a resolver cancel later.
void _terminalEraserPreparationFailuresFailFast() {
  for (final failure in _eraserPreparationFailures) {
    _expectEraserPreparationFailure(failure);
  }
}

final _eraserPreparationFailures = <_EraserPreparationFailureCase>[
  _EraserPreparationFailureCase(
    'CommitApplier document preparation',
    (error, operation) => CommitApplier.injectDeletionPreparationFailure(
      DeletionCommitPreparationPhase.documentPreparation,
      error,
      operation,
    ),
  ),
  const _EraserPreparationFailureCase(
    'PreparedSelectionEffect backing preparation',
    PreparedSelectionEffect.injectPreparationFailure,
  ),
  _EraserPreparationFailureCase(
    'DocumentStoreKernel sparse validation and mutation',
    (error, operation) => DocumentStoreKernel.injectDeletionPreparationFailure(
      DeletionStorePreparationPhase.sparseValidationAndMutation,
      error,
      operation,
    ),
  ),
  _EraserPreparationFailureCase(
    'DocumentStoreKernel stale Store bind',
    (error, operation) => DocumentStoreKernel.injectDeletionPreparationFailure(
      DeletionStorePreparationPhase.staleStoreBind,
      error,
      operation,
    ),
  ),
  _EraserPreparationFailureCase(
    'DocumentStoreKernel selection normalization',
    (error, operation) => DocumentStoreKernel.injectDeletionPreparationFailure(
      DeletionStorePreparationPhase.selectionNormalization,
      error,
      operation,
    ),
  ),
  _EraserPreparationFailureCase(
    'RuntimeRoot request construction',
    (error, operation) => RuntimeRoot.injectDeletionRequestPreparationFailure(
      RuntimeDeletionRequestPreparationPhase.requestConstruction,
      error,
      operation,
    ),
    hasPreparedCommit: true,
  ),
  _EraserPreparationFailureCase(
    'RuntimeRoot request entry copy',
    (error, operation) => RuntimeRoot.injectDeletionRequestPreparationFailure(
      RuntimeDeletionRequestPreparationPhase.entryCopy,
      error,
      operation,
    ),
    hasPreparedCommit: true,
  ),
  _EraserPreparationFailureCase(
    'CommitApplier revision preparation',
    (error, operation) => CommitApplier.injectDeletionPreparationFailure(
      DeletionCommitPreparationPhase.revisionPreparation,
      error,
      operation,
    ),
  ),
  _EraserPreparationFailureCase(
    'CommitApplier action-input sealing',
    (error, operation) => CommitApplier.injectDeletionPreparationFailure(
      DeletionCommitPreparationPhase.actionInputSealing,
      error,
      operation,
    ),
  ),
];

// Error identity, public pointer delivery, cleanup, and no-effect facts form
// one failure witness; separating them would obscure which owner failed first.
// ignore: halstead-volume, source-lines-of-code
void _expectEraserPreparationFailure(_EraserPreparationFailureCase failure) {
  var resolverCalls = 0;
  final root = RuntimeRoot.test(
    store: DocumentStoreKernel.withCommittedDocumentForTesting(
      CommittedDocument(_document()),
    ),
    config: CanvasRuntimeConfig(
      deletionCommitResolver: (_) {
        resolverCalls += 1;
        return CanvasDeletionDecision.accept;
      },
      diagnosticPolicy: const CanvasDiagnosticPolicy.summary(),
    ),
  );
  addTearDown(root.dispose);
  final actions = <CanvasActionCommitted>[];
  final subscription = root.actions.listen(actions.add);
  addTearDown(subscription.cancel);
  root.selection.setSelection([CanvasElementId('erasable')]);
  final error = StateError('eraser ${failure.name} failure');
  final beforeDocument = root.readDocument();
  final beforeSelection = root.selection.selectedElementIds;
  final construction = <RuntimeDeletionRouteConstructionKind>[];
  final cleanupReasons = <PointerCleanupReason>[];
  _startEraser(root);

  RuntimeRoot.observeDeletionRouteConstruction(
    construction.add,
    () => InteractionEngine.observeCleanup(
      cleanupReasons.add,
      () => failure.inject(
        error,
        () => expect(
          () => root.handlePointer(_sample(CanvasPointerLifecyclePhase.up)),
          throwsA(same(error)),
        ),
      ),
    ),
  );

  expect(resolverCalls, 0);
  expect(
    construction,
    failure.hasPreparedCommit
        ? [RuntimeDeletionRouteConstructionKind.eraserPreparedCommit]
        : isEmpty,
    reason: failure.name,
  );
  expect(cleanupReasons, [PointerCleanupReason.editFailure]);
  expect(root.readDocument(), beforeDocument);
  expect(root.selection.selectedElementIds, beforeSelection);
  expect(actions, isEmpty);
  expect(root.diagnosticRecords, isEmpty);
  expect(root.preview, isA<CanvasNoPreview>());
  expect(root.interactionEngine.activeSession, isNull);
}

final class _EraserPreparationFailureCase {
  const _EraserPreparationFailureCase(
    this.name,
    this.inject, {
    this.hasPreparedCommit = false,
  });

  final String name;
  final void Function(Error error, void Function() operation) inject;
  final bool hasPreparedCommit;
}

final _guardedEraserMutationFamilies = <_GuardedEraserMutationFamily>[
  _GuardedEraserMutationFamily(
    'resource dirty one',
    (root) => root.resources.markResourceDirty(CanvasResourceId('resource-a')),
  ),
  _GuardedEraserMutationFamily(
    'resource dirty all',
    (root) => root.resources.markAllResourcesDirty(),
  ),
  _GuardedEraserMutationFamily(
    'selection set',
    (root) => root.selection.setSelection([CanvasElementId('erasable')]),
  ),
  _GuardedEraserMutationFamily(
    'selection clear',
    (root) => root.selection.clearSelection(),
  ),
  _GuardedEraserMutationFamily(
    'selection move',
    (root) => root.selection.moveSelection(const Offset(1, 1)),
  ),
  _GuardedEraserMutationFamily(
    'selection delete',
    (root) => root.selection.deleteSelection(),
  ),
  _GuardedEraserMutationFamily(
    'camera',
    (root) => root.setCameraOffset(const Offset(1, 1)),
  ),
  _GuardedEraserMutationFamily(
    'element id generation',
    (root) => root.generateElementId(),
  ),
  _GuardedEraserMutationFamily(
    'layer id generation',
    (root) => root.generateLayerId(),
  ),
  _GuardedEraserMutationFamily(
    'resource id generation',
    (root) => root.generateResourceId(),
  ),
  _GuardedEraserMutationFamily(
    'edit remove',
    (root) => root.edits.edit(
      (edit) => edit.removeElement(CanvasElementId('erasable')),
    ),
  ),
  _GuardedEraserMutationFamily(
    'edit load',
    (root) => root.edits.loadDocumentFromJson(
      encodeCanvasDocumentToJson(_document()),
    ),
  ),
  _GuardedEraserMutationFamily(
    'command remove',
    (root) => root.commands.removeElement(CanvasElementId('erasable')),
  ),
  _GuardedEraserMutationFamily(
    'command clear',
    (root) => root.commands.clearContent(),
  ),
  _GuardedEraserMutationFamily(
    'tool mode',
    (root) => root.tools.setMode(root.tools.mode),
  ),
  _GuardedEraserMutationFamily(
    'tool style',
    (root) => root.tools.setDrawStyle(root.tools.drawStyle),
  ),
  _GuardedEraserMutationFamily(
    'tool draw tool',
    (root) => root.tools.setDrawTool(root.tools.drawStyle.tool),
  ),
  _GuardedEraserMutationFamily(
    'tool color',
    (root) => root.tools.setDrawColor(root.tools.drawStyle.color),
  ),
  _GuardedEraserMutationFamily(
    'tool pointer policy',
    (root) => root.tools.setPointerPolicy(root.tools.pointerPolicy),
  ),
  _GuardedEraserMutationFamily(
    'text read-only',
    (root) => root.textEditing.setReadOnly(true),
  ),
  _GuardedEraserMutationFamily('dispose', (root) => root.dispose()),
  _GuardedEraserMutationFamily(
    'nested resolver',
    (root) => root.runResolverCallback(() => CanvasDeletionDecision.cancel),
  ),
];

final class _GuardedEraserMutationFamily {
  const _GuardedEraserMutationFamily(this.name, this.invoke);

  final String name;
  final void Function(RuntimeRoot root) invoke;
}

void _startEraser(RuntimeRoot root) {
  root.setInteractionMode(CanvasInteractionMode.draw);
  root.setDrawStyle(CanvasDrawStyle(tool: CanvasDrawTool.eraser));
  root.handlePointer(_sample(CanvasPointerLifecyclePhase.down));
  root.handlePointer(_sample(CanvasPointerLifecyclePhase.move));
}

CanvasPointerSample _sample(CanvasPointerLifecyclePhase phase) =>
    CanvasPointerSample(
      pointerId: 3,
      phase: phase,
      position: const Offset(1, 1),
      kind: PointerDeviceKind.touch,
      timestampMs: 23,
    );

CanvasDocument _document() => CanvasDocument(
  layers: [
    CanvasLayer(
      id: CanvasLayerId('eraser-layer'),
      elements: [
        CanvasRectElement(
          id: CanvasElementId('erasable'),
          size: const Size(10, 10),
        ),
      ],
    ),
  ],
);

CanvasDocument _mixedKindDocument() => CanvasDocument(
  layers: [
    CanvasLayer(
      id: CanvasLayerId('lower'),
      elements: [
        CanvasRectElement(
          id: CanvasElementId('lower-a'),
          size: const Size(2, 2),
        ),
        CanvasTextElement(
          id: CanvasElementId('filtered-text'),
          text: 'skip',
          color: const Color(0xFF000000),
          textDirection: TextDirection.ltr,
        ),
        CanvasRectElement(
          id: CanvasElementId('lower-c'),
          size: const Size(2, 2),
        ),
      ],
    ),
    CanvasLayer(
      id: CanvasLayerId('upper'),
      elements: [
        CanvasRectElement(
          id: CanvasElementId('upper-b'),
          size: const Size(2, 2),
        ),
      ],
    ),
  ],
);

final class _ThrownEraserObject {
  @override
  String toString() => 'ordinary-eraser-object';
}

final class _TerminalGuardSnapshot {
  const _TerminalGuardSnapshot({
    required this.document,
    required this.selection,
    required this.state,
    required this.camera,
  });

  factory _TerminalGuardSnapshot.capture(RuntimeRoot root) =>
      _TerminalGuardSnapshot(
        document: root.readDocument(),
        selection: root.selectedElementIds,
        state: root.state.value,
        camera: root.viewCameraOffset,
      );

  final CanvasDocument document;
  final Set<CanvasElementId> selection;
  final CanvasRuntimeState state;
  final Offset camera;

  void expectCommittedFactsUnchanged(RuntimeRoot root) {
    expect(root.readDocument(), document);
    expect(root.selectedElementIds, selection);
    expect(root.state.value.revisions.document, state.revisions.document);
    expect(root.state.value.revisions.selection, state.revisions.selection);
    expect(root.state.value.revisions.viewCamera, state.revisions.viewCamera);
    expect(
      root.state.value.revisions.resourceVisual,
      state.revisions.resourceVisual,
    );
    expect(root.viewCameraOffset, camera);
  }
}

void _expectRetainedDescriptor(
  CanvasResource? actual,
  CanvasResource expected,
) {
  if (actual == null) {
    fail('The accepted deletion unexpectedly removed ${expected.id}.');
  }
  expect(actual.runtimeType, expected.runtimeType);
  expect(actual.id, expected.id);
  expect(actual.source, expected.source);
  expect(actual.contentHash, expected.contentHash);
  expect(actual.byteLength, expected.byteLength);
  expect(actual.metadata, expected.metadata);
  if (expected case CanvasImageResource(:final mimeType)) {
    expect((actual as CanvasImageResource).mimeType, mimeType);
  }
}
