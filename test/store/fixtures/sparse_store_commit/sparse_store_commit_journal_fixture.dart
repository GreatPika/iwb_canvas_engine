import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/id_admission.dart'
    show IdAdmissionWorkKind, IdAdmissionWorkPhase;
import 'package:iwb_canvas_engine/src/store/resource_table.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

import '../../../support/document_store_with_document.dart';
import 'sparse_store_commit_support.dart';

void registerSparseAccountingTests() {
  test(
    'keeps layer-only clear as an ordered sparse-store barrier',
    () => expect(_clearBarrierKeepsJournalOrder, returnsNormally),
  );
  test(
    'uses one sparse replay and admits compensated transient ids',
    () => expect(
      _usesOneSparseReplayAndAdmitsCompensatedTransientIds,
      returnsNormally,
    ),
  );
}

// Both mutation orders and their exact accepted facts are one barrier-policy
// witness; splitting them would duplicate the Store state and blur causality.
// ignore: halstead-volume, source-lines-of-code
void _expectRemoveUnusedResourceBarrierThroughDirectStore() {
  final resourceId = CanvasResourceId('content-image-resource');
  final retainedStore = documentStoreWithDocument(clearRetentionDocument());
  final retained = retainedStore.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta(
        document: true,
        projection: true,
        structural: true,
        bounds: true,
        elementVisual: true,
        resource: true,
      ),
      mutations: [
        StoreSparseRemoveUnusedResource(resourceId),
        const StoreSparseClearContent(removeUnusedResources: false),
      ],
    ),
  );

  expect(retained.touchedFacts.removedElementIds, {
    CanvasElementId('content-image'),
    CanvasElementId('content-vector'),
  });
  expect(retained.touchedFacts.resourceDescriptorChangedIds, isEmpty);
  expect(retained.touchedFacts.resourceVisualChangedIds, isEmpty);
  expect(retained.touchedFacts.layerIds, {CanvasLayerId('content-layer')});
  expect(retained.touchedFacts.backgroundLayerChanged, isFalse);
  expect(retained.revisionDelta.structural, isTrue);
  expect(retained.revisionDelta.resource, isFalse);
  retainedStore.installSparseCommit(retained);
  expect(retainedStore.resourceDescriptor(resourceId), isNotNull);
  expect(retainedStore.resourceRevision, 1);

  final removedStore = documentStoreWithDocument(clearRetentionDocument());
  final removed = removedStore.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta(
        document: true,
        projection: true,
        structural: true,
        bounds: true,
        elementVisual: true,
        resource: true,
      ),
      mutations: [
        const StoreSparseClearContent(removeUnusedResources: false),
        StoreSparseRemoveUnusedResource(resourceId),
      ],
    ),
  );

  expect(removed.touchedFacts.removedElementIds, {
    CanvasElementId('content-image'),
    CanvasElementId('content-vector'),
  });
  expect(removed.touchedFacts.resourceDescriptorChangedIds, {resourceId});
  expect(removed.touchedFacts.resourceVisualChangedIds, {resourceId});
  expect(removed.touchedFacts.layerIds, {CanvasLayerId('content-layer')});
  expect(removed.touchedFacts.backgroundLayerChanged, isFalse);
  expect(removed.revisionDelta.structural, isTrue);
  expect(removed.revisionDelta.resource, isTrue);
  removedStore.installSparseCommit(removed);
  expect(removedStore.resourceDescriptor(resourceId), isNull);
  expect(removedStore.resourceRevision, 2);
}

// This direct clear trace needs each mutation and its expected state together
// to preserve the journal-order regression it falsifies.
// ignore: halstead-volume, source-lines-of-code
void _clearBarrierKeepsJournalOrder() {
  _expectRemoveUnusedResourceBarrierThroughDirectStore();

  final addedResource = CanvasImageResource(
    id: CanvasResourceId('trace-resource'),
    source: CanvasResourceSource.appKey('trace-source'),
    mimeType: 'image/webp',
    contentHash: 'trace-hash',
    byteLength: 303,
    metadata: CanvasMetadata.fromMap({'trace': 'resource'}),
  );
  final addedElement = CanvasImageElement(
    id: CanvasElementId('trace-element'),
    resourceId: CanvasResourceId('trace-resource'),
    size: const Size(47, 53),
    naturalSize: const Size(94, 106),
    revision: 7,
    isLocked: true,
    isDeletable: false,
    metadata: CanvasMetadata.fromMap({'trace': 'element'}),
  );
  final addBeforeClear = [
    _StoreClearTraceAction.upsert(addedResource),
    _StoreClearTraceAction.add(addedElement),
    const _StoreClearTraceAction.clear(removeUnusedResources: false),
    const _StoreClearTraceAction.removeUnused('trace-resource'),
    const _StoreClearTraceAction.clear(removeUnusedResources: true),
  ];
  final clearBeforeAdd = [
    const _StoreClearTraceAction.clear(removeUnusedResources: true),
    const _StoreClearTraceAction.removeUnused('trace-resource'),
    const _StoreClearTraceAction.clear(removeUnusedResources: false),
    _StoreClearTraceAction.add(addedElement),
    _StoreClearTraceAction.upsert(addedResource),
  ];

  final before = _runStoreClearTrace(addBeforeClear);
  final after = _runStoreClearTrace(clearBeforeAdd);

  expect(before.oracle.hasChanges, isFalse);
  expect(after.oracle.hasChanges, isTrue);
  expect(before.oracle.contentElementIds, isEmpty);
  expect(after.oracle.contentElementIds, [CanvasElementId('trace-element')]);
  expect(before.oracle.resourceIds, {
    CanvasResourceId('trace-background-image-resource'),
    CanvasResourceId('trace-background-vector-resource'),
  });
  expect(after.oracle.resourceIds, {
    CanvasResourceId('trace-background-image-resource'),
    CanvasResourceId('trace-background-vector-resource'),
    CanvasResourceId('trace-resource'),
  });
}

_StoreClearTraceResult _runStoreClearTrace(
  List<_StoreClearTraceAction> actions,
) {
  final seed = clearBarrierDocument();
  final oracle = _StoreClearTraceOracle(seed);
  for (final action in actions) {
    action.applyTo(oracle);
  }
  final store = documentStoreWithDocument(seed);
  final prepared = store.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta(
        document: true,
        projection: true,
        structural: true,
        bounds: true,
        elementVisual: true,
        resource: true,
      ),
      mutations: [for (final action in actions) action.mutation],
    ),
  );

  _expectStoreClearTracePrepared(prepared, oracle);
  expect(store.projectionBuildCount, 0);
  store.installSparseCommit(prepared);
  _expectStoreClearTraceCommitted(store, oracle);
  expect(store.projectionBuildCount, 0);

  return _StoreClearTraceResult(oracle: oracle, prepared: prepared);
}

// The complete prepared payload is the asserted boundary; a context object
// would duplicate Store's result model without clarifying the trace.
// ignore: halstead-volume
void _expectStoreClearTracePrepared(
  PreparedSparseStoreCommit prepared,
  _StoreClearTraceOracle oracle,
) {
  expect(prepared.hasChanges, oracle.hasChanges);
  expect(prepared.revisionDelta.document, oracle.hasChanges);
  expect(prepared.revisionDelta.projection, oracle.hasChanges);
  expect(prepared.revisionDelta.structural, oracle.hasStructuralChange);
  expect(prepared.revisionDelta.bounds, oracle.hasStructuralChange);
  expect(prepared.revisionDelta.elementVisual, oracle.hasStructuralChange);
  expect(prepared.revisionDelta.resource, oracle.hasResourceChange);
  expect(prepared.touchedFacts.addedElementIds, oracle.addedElementIds);
  expect(prepared.touchedFacts.removedElementIds, oracle.removedElementIds);
  expect(
    prepared.touchedFacts.resourceDescriptorChangedIds,
    oracle.changedResourceIds,
  );
  expect(
    prepared.touchedFacts.resourceVisualChangedIds,
    oracle.changedResourceIds,
  );
  expect(
    prepared.touchedFacts.layerIds,
    oracle.hasStructuralChange
        ? {CanvasLayerId('trace-content-layer')}
        : <CanvasLayerId>{},
  );
  expect(prepared.touchedFacts.backgroundLayerChanged, isFalse);
  expect(prepared.touchedFacts.background, isFalse);
  expect(prepared.touchedFacts.grid, isFalse);
}

void _expectStoreClearTraceCommitted(
  DocumentStoreKernel store,
  _StoreClearTraceOracle oracle,
) {
  expect(store.backgroundElementIds, oracle.backgroundElementIds);
  expect(
    store.elementIdsInLayer(CanvasLayerId('trace-content-layer')),
    oracle.contentElementIds,
  );
  expect(store.resourceIds.toSet(), oracle.resourceIds);
  for (final id in oracle.backgroundElementIds) {
    _expectSameTraceElement(store.elementById(id), oracle.elementById(id));
  }
  for (final id in oracle.contentElementIds) {
    _expectSameTraceElement(store.elementById(id), oracle.elementById(id));
  }
  for (final id in oracle.resourceIds) {
    _expectSameTraceDescriptor(
      store.resourceDescriptor(id),
      oracle.resourceById(id),
      resourceRevision: oracle.resourceRevisionFor(id),
    );
  }
}

// Element comparison remains explicit because this oracle must not reuse the
// production equality path it is independently checking.
// ignore: halstead-volume
void _expectSameTraceElement(CanvasElement? actual, CanvasElement expected) {
  expect(actual, isNotNull);
  if (actual == null) {
    fail('trace element is absent.');
  }
  final actualElement = actual;
  expect(actualElement.id, expected.id);
  expect(actualElement.kind, expected.kind);
  expect(actualElement.revision, expected.revision);
  expect(actualElement.transform, expected.transform);
  expect(actualElement.opacity, expected.opacity);
  expect(actualElement.hitPadding, expected.hitPadding);
  expect(actualElement.isVisible, expected.isVisible);
  expect(actualElement.isSelectable, expected.isSelectable);
  expect(actualElement.isLocked, expected.isLocked);
  expect(actualElement.isDeletable, expected.isDeletable);
  expect(actualElement.isTransformable, expected.isTransformable);
  expect(actualElement.metadata, expected.metadata);
  switch (actualElement) {
    case CanvasImageElement():
      final expectedImage = expected as CanvasImageElement;
      expect(actualElement.resourceId, expectedImage.resourceId);
      expect(actualElement.size, expectedImage.size);
      expect(actualElement.naturalSize, expectedImage.naturalSize);
    case CanvasVectorElement():
      final expectedVector = expected as CanvasVectorElement;
      expect(actualElement.resourceId, expectedVector.resourceId);
      expect(actualElement.size, expectedVector.size);
      expect(actualElement.naturalSize, expectedVector.naturalSize);
    case _:
      fail('trace uses only image and vector elements.');
  }
}

// Resource facts remain explicit because this oracle must not reuse the
// production descriptor comparison it is independently checking.
// ignore: halstead-volume
void _expectSameTraceDescriptor(
  StoreResourceDescriptorFacts? actual,
  CanvasResource expected, {
  required int resourceRevision,
}) {
  expect(actual, isNotNull);
  if (actual == null) {
    fail('trace descriptor is absent.');
  }
  final actualDescriptor = actual;
  final source = expected.source as CanvasAppKeyResourceSource;
  switch (actualDescriptor) {
    case StoreImageResourceDescriptorFacts():
      final expectedImage = expected as CanvasImageResource;
      expect(actualDescriptor.id, expectedImage.id);
      expect(actualDescriptor.appKey, source.key);
      expect(actualDescriptor.mimeType, expectedImage.mimeType);
      expect(actualDescriptor.contentHash, expectedImage.contentHash);
      expect(actualDescriptor.byteLength, expectedImage.byteLength);
      expect(actualDescriptor.metadata, expectedImage.metadata);
      expect(actualDescriptor.resourceRevision, resourceRevision);
    case StoreVectorResourceDescriptorFacts():
      final expectedVector = expected as CanvasVectorResource;
      expect(actualDescriptor.id, expectedVector.id);
      expect(actualDescriptor.appKey, source.key);
      expect(actualDescriptor.contentHash, expectedVector.contentHash);
      expect(actualDescriptor.byteLength, expectedVector.byteLength);
      expect(actualDescriptor.metadata, expectedVector.metadata);
      expect(actualDescriptor.resourceRevision, resourceRevision);
  }
}

// This trace couples replay order, admission, prepared facts, and installed
// cursors. Splitting it would duplicate the cross-owner state it falsifies.
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index
void _usesOneSparseReplayAndAdmitsCompensatedTransientIds() {
  final store = DocumentStoreKernel();
  final sparseWork = <SparseTransactionWorkEvent>[];
  final admissionWork = <IdAdmissionWorkEvent>[];
  final mutations = <StoreSparseMutation>[
    StoreSparseAddElement(
      element: CanvasRectElement(
        id: CanvasElementId('e2'),
        size: const Size(1, 1),
      ),
      background: true,
    ),
    StoreSparseUpsertResource(_transientResource('r2')),
    StoreSparseAddElement(
      element: CanvasRectElement(
        id: CanvasElementId('e0'),
        size: const Size(1, 1),
      ),
      background: true,
    ),
    StoreSparseUpsertResource(_transientResource('r0')),
    StoreSparseRemoveElement(CanvasElementId('e2')),
    StoreSparseAddElement(
      element: CanvasRectElement(
        id: CanvasElementId('e2'),
        size: const Size(1, 1),
      ),
      background: true,
    ),
    StoreSparseRemoveElement(CanvasElementId('e0')),
    StoreSparseRemoveElement(CanvasElementId('e2')),
    StoreSparseRemoveUnusedResource(CanvasResourceId('r2')),
    StoreSparseUpsertResource(_transientResource('r2')),
    StoreSparseRemoveUnusedResource(CanvasResourceId('r0')),
    StoreSparseRemoveUnusedResource(CanvasResourceId('r2')),
    const StoreSparseSetBackground(CanvasBackground(color: Color(0xFF112233))),
  ];
  late PreparedSparseStoreCommit prepared;

  DocumentStoreKernel.observeSparseTransactionWork(
    sparseWork.add,
    () => DocumentStoreKernel.observeIdAdmissionWork(admissionWork.add, () {
      prepared = store.prepareSparseCommit(
        StoreSparseCommit(
          revisionDelta: const StoreRevisionDelta.structural()
              .merge(const StoreRevisionDelta.resource())
              .merge(const StoreRevisionDelta.background()),
          mutations: mutations,
        ),
      );
      store.installSparseCommit(prepared);
    }),
  );

  expect(prepared.admittedElementIds, ['e2', 'e0']);
  expect(prepared.admittedResourceIds, ['r2', 'r0']);
  expect(prepared.admittedLayerIds, isEmpty);
  expect(prepared.touchedFacts.addedElementIds, isEmpty);
  expect(prepared.touchedFacts.removedElementIds, isEmpty);
  expect(prepared.touchedFacts.resourceDescriptorChangedIds, isEmpty);
  expect(store.elementById(CanvasElementId('e0')), isNull);
  expect(store.elementById(CanvasElementId('e2')), isNull);
  expect(store.resourceById(CanvasResourceId('r0')), isNull);
  expect(store.resourceById(CanvasResourceId('r2')), isNull);
  expect(store.generateElementId(), CanvasElementId('e1'));
  expect(store.generateElementId(), CanvasElementId('e3'));
  expect(store.generateResourceId(), CanvasResourceId('r1'));
  expect(store.generateResourceId(), CanvasResourceId('r3'));
  expect(
    admissionWork
        .where(
          (event) =>
              event.phase == IdAdmissionWorkPhase.acceptedAdmission &&
              event.kind == IdAdmissionWorkKind.sparseLedgerVisit,
        )
        .map((event) => (event.prefix, event.subject)),
    [('e', 'e2'), ('e', 'e0'), ('r', 'r2'), ('r', 'r0')],
  );
  expect(
    sparseWork
        .where(
          (event) =>
              event.phase == SparseTransactionWorkPhase.replay &&
              event.kind == SparseTransactionWorkKind.journalVisit,
        )
        .map((event) => event.journalIndex),
    List.generate(mutations.length, (index) => index),
  );
  expect(
    sparseWork.where(
      (event) =>
          event.phase == SparseTransactionWorkPhase.replay &&
          event.kind == SparseTransactionWorkKind.ledgerAppend &&
          event.ledger == SparseTransactionWorkLedger.touched,
    ),
    hasLength(mutations.length),
  );
  expect(
    sparseWork.where(
      (event) =>
          event.phase == SparseTransactionWorkPhase.replay &&
          event.kind == SparseTransactionWorkKind.ledgerAppend &&
          event.ledger == SparseTransactionWorkLedger.requiredDelta,
    ),
    hasLength(mutations.length),
  );
  expect(
    sparseWork.where(
      (event) =>
          event.kind == SparseTransactionWorkKind.journalVisit &&
          event.phase == SparseTransactionWorkPhase.finalization,
    ),
    isEmpty,
  );
  expect(
    sparseWork.where(
      (event) =>
          event.phase == SparseTransactionWorkPhase.finalization &&
          event.kind == SparseTransactionWorkKind.ledgerRead,
    ),
    isNotEmpty,
  );
  expect(
    sparseWork.where(
      (event) =>
          event.phase == SparseTransactionWorkPhase.finalization &&
          event.kind == SparseTransactionWorkKind.ledgerRead &&
          event.ledger == SparseTransactionWorkLedger.requiredDelta,
    ),
    hasLength(1),
  );

  final noOpStore = DocumentStoreKernel();
  final noOp = noOpStore.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.structural().merge(
        const StoreRevisionDelta.resource(),
      ),
      mutations: [
        StoreSparseAddElement(
          element: CanvasRectElement(
            id: CanvasElementId('e0'),
            size: const Size(1, 1),
          ),
          background: true,
        ),
        StoreSparseRemoveElement(CanvasElementId('e0')),
        StoreSparseUpsertResource(_transientResource('r0')),
        StoreSparseRemoveUnusedResource(CanvasResourceId('r0')),
      ],
    ),
  );
  expect(noOp.hasChanges, isFalse);
  expect(noOp.admittedElementIds, isEmpty);
  expect(noOp.admittedResourceIds, isEmpty);
  expect(noOpStore.generateElementId(), CanvasElementId('e0'));
  expect(noOpStore.generateResourceId(), CanvasResourceId('r0'));
}

CanvasImageResource _transientResource(String id) {
  return CanvasImageResource(
    id: CanvasResourceId(id),
    source: CanvasResourceSource.appKey(id),
  );
}

sealed class _StoreClearTraceAction {
  const _StoreClearTraceAction();

  const factory _StoreClearTraceAction.upsert(CanvasResource resource) =
      _StoreClearTraceUpsert;
  const factory _StoreClearTraceAction.add(CanvasElement element) =
      _StoreClearTraceAdd;
  const factory _StoreClearTraceAction.clear({
    required bool removeUnusedResources,
  }) = _StoreClearTraceClear;
  const factory _StoreClearTraceAction.removeUnused(String id) =
      _StoreClearTraceRemoveUnused;

  StoreSparseMutation get mutation;
  void applyTo(_StoreClearTraceOracle oracle);
}

final class _StoreClearTraceUpsert extends _StoreClearTraceAction {
  const _StoreClearTraceUpsert(this.resource);

  final CanvasResource resource;

  @override
  StoreSparseMutation get mutation => StoreSparseUpsertResource(resource);

  @override
  void applyTo(_StoreClearTraceOracle oracle) {
    oracle.upsertResource(resource);
  }
}

final class _StoreClearTraceAdd extends _StoreClearTraceAction {
  const _StoreClearTraceAdd(this.element);

  final CanvasElement element;

  @override
  StoreSparseMutation get mutation => StoreSparseAddElement(
    element: element,
    layerId: CanvasLayerId('trace-content-layer'),
  );

  @override
  void applyTo(_StoreClearTraceOracle oracle) {
    oracle.addContentElement(element);
  }
}

final class _StoreClearTraceClear extends _StoreClearTraceAction {
  const _StoreClearTraceClear({required this.removeUnusedResources});

  final bool removeUnusedResources;

  @override
  StoreSparseMutation get mutation =>
      StoreSparseClearContent(removeUnusedResources: removeUnusedResources);

  @override
  void applyTo(_StoreClearTraceOracle oracle) {
    oracle.clearContent(removeUnusedResources: removeUnusedResources);
  }
}

final class _StoreClearTraceRemoveUnused extends _StoreClearTraceAction {
  const _StoreClearTraceRemoveUnused(this.id);

  final String id;

  @override
  StoreSparseMutation get mutation =>
      StoreSparseRemoveUnusedResource(CanvasResourceId(id));

  @override
  void applyTo(_StoreClearTraceOracle oracle) {
    oracle.removeUnusedResource(CanvasResourceId(id));
  }
}

final class _StoreClearTraceResult {
  const _StoreClearTraceResult({required this.oracle, required this.prepared});

  final _StoreClearTraceOracle oracle;
  final PreparedSparseStoreCommit prepared;
}

// This type deliberately groups one trace's independent state.
// Splitting it would duplicate the scenario model.
// ignore: number-of-methods, weighted-methods-per-class
final class _StoreClearTraceOracle {
  _StoreClearTraceOracle(CanvasDocument document)
    : _initialContentElementIds = {
        for (final layer in document.layers) ...layer.elements.map((e) => e.id),
      },
      _initialResourceIds = {
        for (final resource in document.resources) resource.id,
      },
      backgroundElementIds = List.of(
        document.backgroundElements.map((element) => element.id),
      ),
      contentElementIds = [
        for (final layer in document.layers) ...layer.elements.map((e) => e.id),
      ],
      _elements = {
        for (final element in [
          ...document.backgroundElements,
          for (final layer in document.layers) ...layer.elements,
        ])
          element.id: element,
      },
      _resources = {
        for (final resource in document.resources) resource.id: resource,
      };

  final Set<CanvasElementId> _initialContentElementIds;
  final Set<CanvasResourceId> _initialResourceIds;
  final List<CanvasElementId> backgroundElementIds;
  final List<CanvasElementId> contentElementIds;
  final Map<CanvasElementId, CanvasElement> _elements;
  final Map<CanvasResourceId, CanvasResource> _resources;

  Set<CanvasResourceId> get resourceIds => Set.unmodifiable(_resources.keys);
  Set<CanvasElementId> get addedElementIds => {
    for (final id in contentElementIds)
      if (!_initialContentElementIds.contains(id)) id,
  };
  Set<CanvasElementId> get removedElementIds => {
    for (final id in _initialContentElementIds)
      if (!contentElementIds.contains(id)) id,
  };
  Set<CanvasResourceId> get changedResourceIds => {
    for (final id in _initialResourceIds)
      if (!_resources.containsKey(id)) id,
    for (final id in _resources.keys)
      if (!_initialResourceIds.contains(id)) id,
  };
  bool get hasStructuralChange =>
      addedElementIds.isNotEmpty || removedElementIds.isNotEmpty;
  bool get hasResourceChange => changedResourceIds.isNotEmpty;
  bool get hasChanges => hasStructuralChange || hasResourceChange;

  CanvasElement elementById(CanvasElementId id) => _elements[id]!;
  CanvasResource resourceById(CanvasResourceId id) => _resources[id]!;

  int resourceRevisionFor(CanvasResourceId id) {
    return _initialResourceIds.contains(id) ? 1 : 2;
  }

  void upsertResource(CanvasResource resource) {
    _resources[resource.id] = resource;
  }

  void addContentElement(CanvasElement element) {
    _elements[element.id] = element;
    contentElementIds.add(element.id);
  }

  void clearContent({required bool removeUnusedResources}) {
    for (final id in contentElementIds) {
      _elements.remove(id);
    }
    contentElementIds.clear();
    if (removeUnusedResources) {
      _resources.removeWhere((id, _) => !_isResourceReferenced(id));
    }
  }

  void removeUnusedResource(CanvasResourceId id) {
    if (!_isResourceReferenced(id)) {
      _resources.remove(id);
    }
  }

  bool _isResourceReferenced(CanvasResourceId id) {
    return _elements.values.any(
      (element) => switch (element) {
        CanvasImageElement() => element.resourceId == id,
        CanvasVectorElement() => element.resourceId == id,
        _ => false,
      },
    );
  }
}
