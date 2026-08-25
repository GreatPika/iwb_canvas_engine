// Selection deletion resolver scenarios stay in their own public-route fixture:
// they exercise the configured client boundary rather than CommitApplier shape.
// Runtime, Store projection, diagnostics, and delivery listeners are all real
// owner seams for this one route fixture, so their imports remain explicit.
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
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';

import '../../support/runtime_root_with_committed_document_seed.dart';

void main() {
  test(
    'selection delete exposes exact immutable Store entries before accept',
    () async {
      await _acceptExposesExactRequestAndExistingAction();
    },
  );
  test(
    'selection delete cancellation leaves the complete public snapshot intact',
    () {
      _cancelLeavesNoEffect();
    },
  );
  test(
    'selection delete absorbs each ordinary resolver throw without effects',
    () {
      _ordinaryResolverThrowsAreContained();
    },
  );
  test('empty and all-or-none rejected selection stay resolver silent', () {
    _excludedSelectionSetsStaySilent();
  });
  test('selection deletion callback keeps the existing resolver guard', () {
    _selectionDeletionCallbackUsesExistingGuard();
  });
  test('selection preparation failures remain diagnostic-silent', () {
    _selectionPreparationFailuresStayDiagnosticSilent();
  });
  test(
    'selection deletion remains accepted after state or action delivery failure',
    () async {
      await _selectionDeliveryFailuresRemainFinal();
    },
  );
  test('selection deletion retains empty layers and resource descriptors', () {
    _selectionDeletionRetainsLayersAndResources();
  });
}

// Request facts, state-before-action, and identity form one public accept
// witness: splitting them would permit a callback to observe a rebuilt set.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
Future<void> _acceptExposesExactRequestAndExistingAction() async {
  CanvasDeletionCommitRequest? request;
  final installTrace = <String>[];
  final store = DocumentStoreKernel.withCommittedDocumentForTesting(
    CommittedDocument(_document()),
  );
  final root = RuntimeRoot.test(
    store: store,
    config: CanvasRuntimeConfig(
      deletionCommitResolver: (candidate) {
        request = candidate;
        installTrace.add('resolver-return');
        return CanvasDeletionDecision.accept;
      },
    ),
  );
  addTearDown(root.dispose);
  final stateEvents = <CanvasRuntimeState>[];
  final actions = <CanvasActionCommitted>[];
  final deliveryEvents = <String>[];
  root.state.addListener(() => stateEvents.add(root.state.value));
  root.state.addListener(() {
    deliveryEvents.add('state');
    installTrace.add('state');
  });
  final subscription = root.actions.listen((action) {
    actions.add(action);
    deliveryEvents.add('action');
    installTrace.add('action');
  });
  addTearDown(subscription.cancel);
  root.selection.setSelection([
    CanvasElementId('b'),
    CanvasElementId('c'),
    CanvasElementId('a'),
  ]);
  deliveryEvents.clear();
  installTrace.clear();
  final construction = <RuntimeDeletionRouteConstructionKind>[];
  List<DeletionEntryFacts>? projected;

  RuntimeRoot.observeDeletionRouteConstruction(
    construction.add,
    () => DocumentStoreKernel.observeDeletionPreparedInstall(
      (event) {
        if (event == DeletionPreparedInstallEvent.installed) {
          installTrace.add('store');
        }
      },
      () => DocumentStoreKernel.observeDeletionEntryProjection(
        (entries) => projected = entries,
        () => root.selection.deleteSelection(timestampMs: 41),
      ),
    ),
  );
  await Future<void>.delayed(Duration.zero);

  final received = request;
  if (received == null) {
    fail('The configured deletion resolver did not receive a request.');
  }
  final observedEntries = projected;
  if (observedEntries == null) {
    fail('Selection deletion did not read Store deletion entries.');
  }
  expect(received.operation, CanvasDeletionOperation.deleteSelection);
  expect(received.entries, hasLength(3));
  expect(received.entries[0].element, same(observedEntries[0].element));
  expect(received.entries[0].layerId, CanvasLayerId('lower'));
  expect(received.entries[0].elementIndex, 0);
  expect(received.entries[1].element, same(observedEntries[1].element));
  expect(received.entries[1].layerId, CanvasLayerId('lower'));
  expect(received.entries[1].elementIndex, 2);
  expect(received.entries[2].element, same(observedEntries[2].element));
  expect(received.entries[2].layerId, CanvasLayerId('upper'));
  expect(received.entries[2].elementIndex, 0);
  expect(
    () => received.entries.add(received.entries.first),
    throwsUnsupportedError,
  );
  expect(actions, hasLength(1));
  expect(actions.single.type, CanvasActionType.deleteElements);
  expect(actions.single.elementIds, [
    CanvasElementId('a'),
    CanvasElementId('c'),
    CanvasElementId('b'),
  ]);
  expect(actions.single.timestampMs, 41);
  expect(stateEvents, isNotEmpty);
  expect(deliveryEvents.take(2), ['state', 'action']);
  expect(installTrace, ['resolver-return', 'store', 'state', 'action']);
  expect(construction, [
    RuntimeDeletionRouteConstructionKind.selectionPreparedCommit,
    RuntimeDeletionRouteConstructionKind.request,
  ]);
  expect(
    root.readDocument().layers.expand((layer) => layer.elements),
    isNot(contains(CanvasElementId('a'))),
  );
}

void _cancelLeavesNoEffect() {
  var calls = 0;
  final root = _root((_) {
    calls += 1;
    return CanvasDeletionDecision.cancel;
  });
  addTearDown(root.dispose);
  root.selection.setSelection([CanvasElementId('a')]);
  final before = _SelectionDeleteSnapshot.capture(root);
  final construction = <RuntimeDeletionRouteConstructionKind>[];

  RuntimeRoot.observeDeletionRouteConstruction(
    construction.add,
    root.selection.deleteSelection,
  );

  expect(calls, 1);
  expect(construction, [
    RuntimeDeletionRouteConstructionKind.selectionPreparedCommit,
    RuntimeDeletionRouteConstructionKind.request,
  ]);
  before.expectUnchanged(root);
  expect(root.diagnosticRecords, isEmpty);
}

// Error, Exception, and non-Exception objects are deliberately kept together:
// they are one public containment policy with the same no-effect invariant.
// Keeping all ordinary throw classes beside their common snapshot and bounded
// diagnostic oracle makes their one containment policy easier to audit.
// ignore: halstead-volume, source-lines-of-code
void _ordinaryResolverThrowsAreContained() {
  for (final thrown in [
    StateError('error'),
    Exception('exception'),
    _ThrownObject(),
  ]) {
    var calls = 0;
    final root = _root((_) {
      calls += 1;
      // This route deliberately covers ordinary non-Exception throws.
      // ignore: only_throw_errors
      throw thrown;
    }, diagnosticPolicy: const CanvasDiagnosticPolicy.summary());
    addTearDown(root.dispose);
    root.selection.setSelection([CanvasElementId('a')]);
    final before = _SelectionDeleteSnapshot.capture(root);
    final construction = <RuntimeDeletionRouteConstructionKind>[];

    expect(
      () => RuntimeRoot.observeDeletionRouteConstruction(
        construction.add,
        root.selection.deleteSelection,
      ),
      returnsNormally,
    );
    expect(calls, 1);
    expect(construction, [
      RuntimeDeletionRouteConstructionKind.selectionPreparedCommit,
      RuntimeDeletionRouteConstructionKind.request,
    ]);
    before.expectUnchanged(root);
    expect(root.diagnosticRecords, hasLength(1));
    final record = root.diagnosticRecords.single;
    expect(
      record.code,
      const DiagnosticCode.interaction(
        InteractionDiagnosticCode.deletionResolverFailed,
      ),
    );
    expect(record.details, {
      'operation': 'deleteSelection',
      'errorKind': thrown is Error
          ? 'error'
          : thrown is Exception
          ? 'exception'
          : 'object',
    });
  }
}

void _excludedSelectionSetsStaySilent() {
  var calls = 0;
  final emptyRoot = _root((_) {
    calls += 1;
    return CanvasDeletionDecision.accept;
  });
  addTearDown(emptyRoot.dispose);
  final emptyConstruction = <RuntimeDeletionRouteConstructionKind>[];
  RuntimeRoot.observeDeletionRouteConstruction(
    emptyConstruction.add,
    emptyRoot.selection.deleteSelection,
  );
  expect(calls, 0);
  expect(emptyConstruction, isEmpty);

  final rejectedRoot = _root((_) {
    calls += 1;
    return CanvasDeletionDecision.accept;
  }, selectionDeletePolicy: CanvasSelectionDeletePolicy.allOrNone);
  addTearDown(rejectedRoot.dispose);
  rejectedRoot.selection.setSelection([
    CanvasElementId('a'),
    CanvasElementId('not-deletable'),
  ]);
  final before = _SelectionDeleteSnapshot.capture(rejectedRoot);
  final rejectedConstruction = <RuntimeDeletionRouteConstructionKind>[];
  RuntimeRoot.observeDeletionRouteConstruction(
    rejectedConstruction.add,
    rejectedRoot.selection.deleteSelection,
  );
  expect(calls, 0);
  expect(rejectedConstruction, isEmpty);
  before.expectUnchanged(rejectedRoot);
}

void _selectionDeletionCallbackUsesExistingGuard() {
  late RuntimeRoot root;
  root = _root((_) {
    expect(root.readDocument().layers, isNotEmpty);
    expect(root.selectedElementIds, {CanvasElementId('a')});
    for (final mutation in _guardedPublicMutations(root)) {
      expect(mutation, throwsA(isA<ResolverCallbackRejection>()));
    }
    return CanvasDeletionDecision.cancel;
  });
  addTearDown(root.dispose);
  root.selection.setSelection([CanvasElementId('a')]);
  final before = _SelectionDeleteSnapshot.capture(root);
  root.selection.deleteSelection();
  before.expectUnchanged(root);
}

void _selectionPreparationFailuresStayDiagnosticSilent() {
  for (final failure in _selectionPreparationFailures) {
    _expectSelectionPreparationFailure(failure);
  }
}

final _selectionPreparationFailures = <_PreparationFailureCase>[
  _PreparationFailureCase(
    'CommitApplier document preparation',
    (error, operation) => CommitApplier.injectDeletionPreparationFailure(
      DeletionCommitPreparationPhase.documentPreparation,
      error,
      operation,
    ),
  ),
  const _PreparationFailureCase(
    'PreparedSelectionEffect backing preparation',
    PreparedSelectionEffect.injectPreparationFailure,
  ),
  _PreparationFailureCase(
    'DocumentStoreKernel sparse validation and mutation',
    (error, operation) => DocumentStoreKernel.injectDeletionPreparationFailure(
      DeletionStorePreparationPhase.sparseValidationAndMutation,
      error,
      operation,
    ),
  ),
  _PreparationFailureCase(
    'DocumentStoreKernel stale Store bind',
    (error, operation) => DocumentStoreKernel.injectDeletionPreparationFailure(
      DeletionStorePreparationPhase.staleStoreBind,
      error,
      operation,
    ),
  ),
  _PreparationFailureCase(
    'DocumentStoreKernel selection normalization',
    (error, operation) => DocumentStoreKernel.injectDeletionPreparationFailure(
      DeletionStorePreparationPhase.selectionNormalization,
      error,
      operation,
    ),
  ),
  _PreparationFailureCase(
    'RuntimeRoot request construction',
    (error, operation) => RuntimeRoot.injectDeletionRequestPreparationFailure(
      RuntimeDeletionRequestPreparationPhase.requestConstruction,
      error,
      operation,
    ),
    hasPreparedCommit: true,
  ),
  _PreparationFailureCase(
    'RuntimeRoot request entry copy',
    (error, operation) => RuntimeRoot.injectDeletionRequestPreparationFailure(
      RuntimeDeletionRequestPreparationPhase.entryCopy,
      error,
      operation,
    ),
    hasPreparedCommit: true,
  ),
  _PreparationFailureCase(
    'CommitApplier revision preparation',
    (error, operation) => CommitApplier.injectDeletionPreparationFailure(
      DeletionCommitPreparationPhase.revisionPreparation,
      error,
      operation,
    ),
  ),
  _PreparationFailureCase(
    'CommitApplier action-input sealing',
    (error, operation) => CommitApplier.injectDeletionPreparationFailure(
      DeletionCommitPreparationPhase.actionInputSealing,
      error,
      operation,
    ),
  ),
];

// Error identity, route construction, snapshot, action, and diagnostics form
// one fail-fast witness; splitting them would hide a post-error side effect.
// ignore: halstead-volume
void _expectSelectionPreparationFailure(_PreparationFailureCase failure) {
  var calls = 0;
  final root = _root((_) {
    calls += 1;
    return CanvasDeletionDecision.accept;
  }, diagnosticPolicy: const CanvasDiagnosticPolicy.summary());
  addTearDown(root.dispose);
  root.selection.setSelection([CanvasElementId('a')]);
  final error = StateError('selection ${failure.name} failure');
  final before = _SelectionDeleteSnapshot.capture(root);
  final actions = <CanvasActionCommitted>[];
  final subscription = root.actions.listen(actions.add);
  addTearDown(subscription.cancel);
  final construction = <RuntimeDeletionRouteConstructionKind>[];

  failure.inject(
    error,
    () => RuntimeRoot.observeDeletionRouteConstruction(
      construction.add,
      () => expect(root.selection.deleteSelection, throwsA(same(error))),
    ),
  );

  expect(calls, 0);
  expect(
    construction,
    failure.hasPreparedCommit
        ? [RuntimeDeletionRouteConstructionKind.selectionPreparedCommit]
        : isEmpty,
    reason: failure.name,
  );
  before.expectUnchanged(root);
  expect(actions, isEmpty);
  expect(root.diagnosticRecords, isEmpty);
}

final class _PreparationFailureCase {
  const _PreparationFailureCase(
    this.name,
    this.inject, {
    this.hasPreparedCommit = false,
  });

  final String name;
  final void Function(Error error, void Function() operation) inject;
  final bool hasPreparedCommit;
}

// State and action listeners are the two fallible public delivery owners. Both
// cases share the accepted-route finality oracle without a fake delivery seam.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
Future<void> _selectionDeliveryFailuresRemainFinal() async {
  for (final failure in [_DeliveryFailure.state, _DeliveryFailure.action]) {
    var resolverCalls = 0;
    final root = _root((_) {
      resolverCalls += 1;
      return CanvasDeletionDecision.accept;
    });
    addTearDown(root.dispose);
    root.selection.setSelection([CanvasElementId('a')]);
    var armed = false;
    final errors = <Object>[];
    final previousFlutterError = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exception);
    addTearDown(() => FlutterError.onError = previousFlutterError);
    final actions = <CanvasActionCommitted>[];
    if (failure == _DeliveryFailure.state) {
      root.state.addListener(() {
        if (armed) throw StateError('state listener failed');
      });
    }
    late StreamSubscription<CanvasActionCommitted> throwing;
    runZonedGuarded(() {
      throwing = root.actions.listen((_) {
        if (failure == _DeliveryFailure.action) {
          throw StateError('action listener failed');
        }
      });
    }, (error, _) => errors.add(error));
    final receiving = root.actions.listen(actions.add);
    armed = true;
    runZonedGuarded(
      () => root.selection.deleteSelection(timestampMs: 67),
      (error, _) => errors.add(error),
    );
    await Future<void>.delayed(Duration.zero);

    expect(resolverCalls, 1);
    expect(errors, isNotEmpty);
    expect(_idsAfterDelete(root), isNot(contains(CanvasElementId('a'))));
    expect(root.selectedElementIds, isEmpty);
    expect(actions, hasLength(1));
    expect(actions.single.type, CanvasActionType.deleteElements);
    expect(actions.single.timestampMs, 67);
    await throwing.cancel();
    await receiving.cancel();
  }
}

// Retention belongs to the accepted selection route: layer metadata and
// descriptors must survive its sparse delete until their explicit owners act.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _selectionDeletionRetainsLayersAndResources() {
  final imageId = CanvasResourceId('selection-image-resource');
  final vectorId = CanvasResourceId('selection-vector-resource');
  final image = CanvasImageResource(
    id: imageId,
    source: CanvasResourceSource.appKey('selection-image-source'),
    contentHash: 'selection-image-hash',
    byteLength: 11,
    metadata: CanvasMetadata.fromMap({'kind': 'image'}),
  );
  final vector = CanvasVectorResource(
    id: vectorId,
    source: CanvasResourceSource.appKey('selection-vector-source'),
    contentHash: 'selection-vector-hash',
    byteLength: 12,
    metadata: CanvasMetadata.fromMap({'kind': 'vector'}),
  );
  final root = runtimeRootWithCommittedDocumentSeed(
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
    config: const CanvasRuntimeConfig(deletionCommitResolver: _acceptDeletion),
  );
  addTearDown(root.dispose);
  root.selection.setSelection([
    CanvasElementId('first-only'),
    CanvasElementId('image-only'),
    CanvasElementId('vector-only'),
  ]);

  root.selection.deleteSelection();

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

CanvasDeletionDecision _acceptDeletion(CanvasDeletionCommitRequest _) =>
    CanvasDeletionDecision.accept;

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

List<CanvasElementId> _idsAfterDelete(RuntimeRoot root) => [
  for (final layer in root.readDocument().layers)
    for (final element in layer.elements) element.id,
];

enum _DeliveryFailure { state, action }

// Each public facade family must remain independently represented in the same
// callback witness; splitting this list would obscure omissions behind setup.
// ignore: halstead-volume
List<void Function()> _guardedPublicMutations(RuntimeRoot root) => [
  () => root.resources.markResourceDirty(CanvasResourceId('resource-a')),
  root.resources.markAllResourcesDirty,
  () => root.selection.setSelection([CanvasElementId('a')]),
  root.selection.clearSelection,
  () => root.selection.moveSelection(const Offset(1, 1)),
  root.selection.deleteSelection,
  () => root.setCameraOffset(const Offset(1, 1)),
  root.generateElementId,
  root.generateLayerId,
  root.generateResourceId,
  () => root.edits.edit((edit) => edit.removeElement(CanvasElementId('a'))),
  () =>
      root.edits.loadDocumentFromJson(encodeCanvasDocumentToJson(_document())),
  () => root.commands.removeElement(CanvasElementId('a')),
  root.commands.clearContent,
  () => root.tools.setMode(root.tools.mode),
  () => root.tools.setDrawStyle(root.tools.drawStyle),
  () => root.tools.setDrawTool(root.tools.drawStyle.tool),
  () => root.tools.setDrawColor(root.tools.drawStyle.color),
  () => root.tools.setPointerPolicy(root.tools.pointerPolicy),
  () => root.textEditing.setReadOnly(true),
  root.dispose,
  () => root.runResolverCallback(() => CanvasDeletionDecision.cancel),
];

RuntimeRoot _root(
  CanvasDeletionCommitResolver resolver, {
  CanvasSelectionDeletePolicy selectionDeletePolicy =
      CanvasSelectionDeletePolicy.partial,
  CanvasDiagnosticPolicy diagnosticPolicy =
      const CanvasDiagnosticPolicy.disabled(),
}) => runtimeRootWithCommittedDocumentSeed(
  _document(),
  config: CanvasRuntimeConfig(
    deletionCommitResolver: resolver,
    selectionDeletePolicy: selectionDeletePolicy,
    diagnosticPolicy: diagnosticPolicy,
  ),
);

CanvasDocument _document() => CanvasDocument(
  layers: [
    CanvasLayer(
      id: CanvasLayerId('lower'),
      elements: [
        CanvasRectElement(id: CanvasElementId('a'), size: const Size(2, 2)),
        CanvasRectElement(
          id: CanvasElementId('not-deletable'),
          size: const Size(2, 2),
          isDeletable: false,
        ),
        CanvasRectElement(id: CanvasElementId('c'), size: const Size(2, 2)),
      ],
    ),
    CanvasLayer(
      id: CanvasLayerId('upper'),
      elements: [
        CanvasRectElement(id: CanvasElementId('b'), size: const Size(2, 2)),
      ],
    ),
  ],
);

final class _SelectionDeleteSnapshot {
  const _SelectionDeleteSnapshot({
    required this.document,
    required this.selectedIds,
    required this.state,
  });

  factory _SelectionDeleteSnapshot.capture(RuntimeRoot root) =>
      _SelectionDeleteSnapshot(
        document: root.readDocument(),
        selectedIds: root.selectedElementIds,
        state: root.state.value,
      );

  final CanvasDocument document;
  final Set<CanvasElementId> selectedIds;
  final CanvasRuntimeState state;

  void expectUnchanged(RuntimeRoot root) {
    expect(root.readDocument(), document);
    expect(root.selectedElementIds, selectedIds);
    expect(root.state.value, state);
  }
}

final class _ThrownObject {
  @override
  String toString() => 'ordinary-object';
}
