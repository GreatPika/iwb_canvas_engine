// This fixture observes the direct Store, resource editor, family telemetry,
// and immutable prepared facts. Hiding those seams behind a test barrel would
// weaken the resource lifecycle evidence.
// ignore_for_file: number-of-imports

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/family_tables.dart';
import 'package:iwb_canvas_engine/src/store/resource_table.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

import '../../../support/document_store_with_document.dart';
import '../family_tables_telemetry.dart';
import 'sparse_store_commit_support.dart';

void registerSparseResourceEditorTests() {
  test(
    'resource upsert descriptors use accepted resource revision',
    () => expect(_resourceDescriptorsUseAcceptedRevision, returnsNormally),
  );
  test(
    'clears only ordinary content and retains background-backed resources',
    () => expect(_clearsContentAndResources, returnsNormally),
  );
  test(
    'cleans clear-owned unused descriptors in one selective table lifecycle',
    () => expect(_clearsManyResourcesInOneSelectivePass, returnsNormally),
  );
  test(
    'treats a background-only retained document as a clear no-op',
    () => expect(_backgroundOnlyClearIsNoOp, returnsNormally),
  );
  test(
    'keeps sparse resource work bounded through normalized finalization',
    () => expect(_keepsSparseResourceWorkBounded, returnsNormally),
  );
  test(
    'bounds later resource clears to post-clear candidates',
    () => expect(_boundsLaterResourceClears, returnsNormally),
  );
  test(
    'preserves a reinserted resource position under scalar acceptance',
    () => expect(_preservesReinsertedResourcePosition, returnsNormally),
  );
  test(
    'clears mixed base and transaction-local tail descriptors in order',
    () => expect(_clearsMixedBaseAndResourceTailDescriptors, returnsNormally),
  );
  test(
    'seals sparse resource editor buffers after publication and discard',
    () => expect(_sealsSparseResourceEditorBuffers, returnsNormally),
  );
}

void _resourceDescriptorsUseAcceptedRevision() {
  final store = documentStoreWithDocument(baseDocument());

  store.installSparseCommit(
    store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.resource(),
        mutations: [
          StoreSparseUpsertResource(
            CanvasImageResource(
              id: CanvasResourceId('resource-a'),
              source: CanvasResourceSource.appKey('asset-b'),
              contentHash: 'hash-b',
            ),
          ),
        ],
      ),
    ),
  );

  expect(store.resourceRevision, 2);
  expect(
    store.resourceDescriptor(CanvasResourceId('resource-a'))?.resourceRevision,
    2,
  );
}

void _clearsContentAndResources() {
  _clearsContentWithRetainedBackgroundResources();
  _clearsResourceOnlyDocument();
}

// The clear's content removal, retained-background resources, and no-op retry
// are one causal Store scenario; splitting would obscure its barrier policy.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _clearsContentWithRetainedBackgroundResources() {
  final store = documentStoreWithDocument(clearRetentionDocument());
  final beforeBackgroundImage = store.resourceDescriptor(
    CanvasResourceId('background-image-resource'),
  );
  final beforeBackgroundVector = store.resourceDescriptor(
    CanvasResourceId('background-vector-resource'),
  );

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
      mutations: const [StoreSparseClearContent(removeUnusedResources: true)],
    ),
  );

  expect(prepared.touchedFacts.removedElementIds, {
    CanvasElementId('content-image'),
    CanvasElementId('content-vector'),
  });
  expect(prepared.touchedFacts.resourceDescriptorChangedIds, {
    CanvasResourceId('content-image-resource'),
    CanvasResourceId('content-vector-resource'),
    CanvasResourceId('orphan-resource'),
  });
  expect(prepared.touchedFacts.resourceVisualChangedIds, {
    CanvasResourceId('content-image-resource'),
    CanvasResourceId('content-vector-resource'),
  });
  expect(prepared.touchedFacts.layerIds, {CanvasLayerId('content-layer')});
  expect(prepared.touchedFacts.backgroundLayerChanged, isFalse);
  expect(prepared.touchedFacts.background, isFalse);
  expect(prepared.touchedFacts.grid, isFalse);
  expect(prepared.revisionDelta.document, isTrue);
  expect(prepared.revisionDelta.projection, isTrue);
  expect(prepared.revisionDelta.structural, isTrue);
  expect(prepared.revisionDelta.resource, isTrue);
  expect(prepared.revisionDelta.bounds, isTrue);
  expect(prepared.revisionDelta.elementVisual, isTrue);
  expect(store.projectionBuildCount, 0);

  store.installSparseCommit(prepared);

  expect(store.documentSummary.elementCount, 2);
  expect(store.documentSummary.layerCount, 1);
  expect(store.documentSummary.resourceCount, 2);
  expect(store.backgroundElementIds, [
    CanvasElementId('background-image'),
    CanvasElementId('background-vector'),
  ]);
  expect(store.elementIdsInLayer(CanvasLayerId('content-layer')), isEmpty);
  _expectBackgroundImageFacts(store);
  _expectBackgroundVectorFacts(store);
  _expectImageDescriptor(
    store,
    id: 'background-image-resource',
    appKey: 'background-image-source',
    mimeType: 'image/png',
    contentHash: 'background-image-hash',
    byteLength: 101,
    metadata: CanvasMetadata.fromMap({'role': 'background-image'}),
    resourceRevision: 1,
  );
  _expectVectorDescriptor(
    store,
    id: 'background-vector-resource',
    appKey: 'background-vector-source',
    contentHash: 'background-vector-hash',
    byteLength: 202,
    metadata: CanvasMetadata.fromMap({'role': 'background-vector'}),
    resourceRevision: 1,
  );
  expect(
    store
        .resourceDescriptor(CanvasResourceId('background-image-resource'))
        ?.resourceRevision,
    beforeBackgroundImage?.resourceRevision,
  );
  expect(
    store
        .resourceDescriptor(CanvasResourceId('background-vector-resource'))
        ?.resourceRevision,
    beforeBackgroundVector?.resourceRevision,
  );
  expect(store.resourceRevision, 2);
  expect(store.elementFactsById(CanvasElementId('content-image')), isNull);
  expect(store.elementFactsById(CanvasElementId('content-vector')), isNull);
  expect(
    store.resourceDescriptor(CanvasResourceId('content-image-resource')),
    isNull,
  );
  expect(
    store.resourceDescriptor(CanvasResourceId('content-vector-resource')),
    isNull,
  );
  expect(store.resourceDescriptor(CanvasResourceId('orphan-resource')), isNull);
  expect(store.projectionBuildCount, 0);

  final noOpClear = store.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.structural(),
      mutations: const [StoreSparseClearContent(removeUnusedResources: true)],
    ),
  );
  expect(noOpClear.hasChanges, isFalse);
}

void _expectBackgroundImageFacts(DocumentStoreKernel store) {
  final element = store.elementById(CanvasElementId('background-image'));
  expect(element, isA<CanvasImageElement>());
  final image = element as CanvasImageElement;
  expect(image.id, CanvasElementId('background-image'));
  expect(image.resourceId, CanvasResourceId('background-image-resource'));
  expect(image.size, const Size(31, 37));
  expect(image.naturalSize, const Size(62, 74));
  expect(image.revision, 5);
  expect(image.isLocked, isTrue);
  expect(image.isDeletable, isFalse);
  expect(image.metadata, CanvasMetadata.fromMap({'slot': 'image'}));
}

void _expectBackgroundVectorFacts(DocumentStoreKernel store) {
  final element = store.elementById(CanvasElementId('background-vector'));
  expect(element, isA<CanvasVectorElement>());
  final vector = element as CanvasVectorElement;
  expect(vector.id, CanvasElementId('background-vector'));
  expect(vector.resourceId, CanvasResourceId('background-vector-resource'));
  expect(vector.size, const Size(41, 43));
  expect(vector.naturalSize, const Size(82, 86));
  expect(vector.revision, 6);
  expect(vector.isVisible, isFalse);
  expect(vector.isSelectable, isFalse);
  expect(vector.metadata, CanvasMetadata.fromMap({'slot': 'vector'}));
}

// Descriptor fields are the public facts being compared; a parameter object
// would mirror the owner merely to reduce this test helper's signature.
// ignore: number-of-parameters
void _expectImageDescriptor(
  DocumentStoreKernel store, {
  required String id,
  required String appKey,
  required String mimeType,
  required String contentHash,
  required int byteLength,
  required CanvasMetadata metadata,
  required int resourceRevision,
}) {
  final descriptor = store.resourceDescriptor(CanvasResourceId(id));
  expect(descriptor, isA<StoreImageResourceDescriptorFacts>());
  final image = descriptor as StoreImageResourceDescriptorFacts;
  expect(image.id, CanvasResourceId(id));
  expect(image.appKey, appKey);
  expect(image.mimeType, mimeType);
  expect(image.contentHash, contentHash);
  expect(image.byteLength, byteLength);
  expect(image.metadata, metadata);
  expect(image.resourceRevision, resourceRevision);
}

// Descriptor fields are the public facts being compared; a parameter object
// would mirror the owner merely to reduce this test helper's signature.
// ignore: number-of-parameters
void _expectVectorDescriptor(
  DocumentStoreKernel store, {
  required String id,
  required String appKey,
  required String contentHash,
  required int byteLength,
  required CanvasMetadata metadata,
  required int resourceRevision,
}) {
  final descriptor = store.resourceDescriptor(CanvasResourceId(id));
  expect(descriptor, isA<StoreVectorResourceDescriptorFacts>());
  final vector = descriptor as StoreVectorResourceDescriptorFacts;
  expect(vector.id, CanvasResourceId(id));
  expect(vector.appKey, appKey);
  expect(vector.contentHash, contentHash);
  expect(vector.byteLength, byteLength);
  expect(vector.metadata, metadata);
  expect(vector.resourceRevision, resourceRevision);
}

// This is one resource-lifecycle trace: changing its literal setup would no
// longer prove the authorized clear pass independently from normalization.
// ignore: halstead-volume
void _clearsManyResourcesInOneSelectivePass() {
  const resourceCount = 14;
  final store = documentStoreWithDocument(manyResourceClearDocument());
  final resourceWork = _SelectiveResourceTableWork();
  final familyWork = FamilyTablesTelemetry();

  final prepared = ResourceTableEditor.observeWork(
    resourceWork.record,
    () => FamilyTables.observeTelemetry(
      familyWork.record,
      () => store.prepareSparseCommit(
        StoreSparseCommit(
          revisionDelta: const StoreRevisionDelta(
            document: true,
            projection: true,
            structural: true,
            bounds: true,
            elementVisual: true,
            resource: true,
          ),
          mutations: const [
            StoreSparseClearContent(removeUnusedResources: true),
          ],
        ),
      ),
    ),
  );

  expect(prepared.hasChanges, isTrue);
  expect(resourceWork.openCount, 1);
  expect(resourceWork.entryVisitCount, resourceCount);
  _expectClearResourceRemovals(resourceWork, resourceCount - 2);
  expect(resourceWork.baseEntryCopyCount, 2);
  expect(resourceWork.freezeCount, 1);
  expect(resourceWork.immutablePublicationCount, 1);
  expect(resourceWork.discardCount, 0);
  expect(familyWork.referenceQueryFamilyRowVisitCount, 0);
  expect(familyWork.referenceEditorBaseSummaryReadCount, 28);
  expect(familyWork.referenceEditorDeltaReadCount, 28);
  expect(store.projectionBuildCount, 0);

  store.installSparseCommit(prepared);
  expect(store.resourceCount, 2);
  expect(store.projectionBuildCount, 0);
}

void _keepsSparseResourceWorkBounded() {
  const baseCount = 64;
  final store = documentStoreWithDocument(
    CanvasDocument(
      resources: List.generate(
        baseCount,
        (index) => CanvasImageResource(
          id: CanvasResourceId('resource-$index'),
          source: CanvasResourceSource.appKey('base-$index'),
        ),
      ),
    ),
  );
  final resourceWork = _SelectiveResourceTableWork();

  final prepared = ResourceTableEditor.observeWork(
    resourceWork.record,
    () => store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.resource(),
        mutations: [
          StoreSparseUpsertResource(
            CanvasImageResource(
              id: CanvasResourceId('resource-0'),
              source: CanvasResourceSource.appKey('changed'),
            ),
          ),
        ],
      ),
    ),
  );

  _expectSingleResourceNormalization(
    prepared,
    resourceWork,
    baseCount: baseCount,
    store: store,
  );
}

void _boundsLaterResourceClears() {
  const baseCount = 64;
  final store = _resourceOnlyStore(baseCount);
  final resourceWork = _SelectiveResourceTableWork();

  final prepared = ResourceTableEditor.observeWork(
    resourceWork.record,
    () => store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.resource(),
        mutations: [
          const StoreSparseClearContent(removeUnusedResources: true),
          StoreSparseUpsertResource(
            CanvasImageResource(
              id: CanvasResourceId('new'),
              source: CanvasResourceSource.appKey('new'),
            ),
          ),
          const StoreSparseClearContent(removeUnusedResources: true),
        ],
      ),
    ),
  );

  _expectBoundedRepeatedResourceClearWork(
    prepared,
    resourceWork,
    baseCount: baseCount,
    store: store,
  );
}

void _expectBoundedRepeatedResourceClearWork(
  PreparedSparseStoreCommit prepared,
  _SelectiveResourceTableWork resourceWork, {
  required int baseCount,
  required DocumentStoreKernel store,
}) {
  expect(prepared.hasChanges, isTrue);
  expect(prepared.document.resourceTable.descriptors, isEmpty);
  expect(resourceWork.count(ResourceTableEditorWorkKind.clearEntryVisit), 65);
  expect(resourceWork.count(ResourceTableEditorWorkKind.normalizationRead), 65);
  expect(
    resourceWork.count(
      ResourceTableEditorWorkKind.materializationBaseEntryVisit,
    ),
    baseCount,
  );
  expect(resourceWork.count(ResourceTableEditorWorkKind.freeze), 1);
  expect(
    resourceWork.count(ResourceTableEditorWorkKind.immutablePublication),
    1,
  );
  expect(store.projectionBuildCount, 0);
}

void _preservesReinsertedResourcePosition() {
  final first = CanvasResourceId('first');
  final second = CanvasResourceId('second');
  final store = documentStoreWithDocument(
    _reinsertedResourceBase(first, second),
  );

  final prepared = store.prepareSparseCommit(_reinsertedResourceCommit(first));
  _expectPreparedReinsertedResourcePosition(prepared, first, second);

  store.installSparseCommit(prepared);
  _expectInstalledReinsertedResourcePosition(store, first, second);
}

CanvasDocument _reinsertedResourceBase(
  CanvasResourceId first,
  CanvasResourceId second,
) => CanvasDocument(
  resources: [_reinsertedResource(first), _reinsertedResource(second)],
);

StoreSparseCommit _reinsertedResourceCommit(CanvasResourceId first) =>
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.background(),
      mutations: [
        StoreSparseRemoveUnusedResource(first),
        StoreSparseUpsertResource(_reinsertedResource(first)),
        const StoreSparseSetBackground(
          CanvasBackground(color: Color(0xFF112233)),
        ),
      ],
    );

CanvasImageResource _reinsertedResource(CanvasResourceId id) =>
    CanvasImageResource(id: id, source: CanvasResourceSource.appKey(id.value));

void _expectPreparedReinsertedResourcePosition(
  PreparedSparseStoreCommit prepared,
  CanvasResourceId first,
  CanvasResourceId second,
) {
  expect(prepared.hasChanges, isTrue);
  expect(prepared.revisionDelta.background, isTrue);
  expect(prepared.revisionDelta.resource, isFalse);
  expect(prepared.touchedFacts.resourceDescriptorChangedIds, isEmpty);
  expect(prepared.document.resourceTable.descriptors.keys, [second, first]);
  _expectReinsertedResourceFacts(prepared, first, second);
}

void _expectInstalledReinsertedResourcePosition(
  DocumentStoreKernel store,
  CanvasResourceId first,
  CanvasResourceId second,
) {
  expect(store.resourceIds, [second, first]);
  expect(store.resourceRevision, 1);
}

void _expectReinsertedResourceFacts(
  PreparedSparseStoreCommit prepared,
  CanvasResourceId first,
  CanvasResourceId second,
) {
  final firstDescriptor = prepared.document.resourceTable.descriptors[first];
  final secondDescriptor = prepared.document.resourceTable.descriptors[second];
  expect(firstDescriptor, isA<StoreImageResourceDescriptorFacts>());
  expect(secondDescriptor, isA<StoreImageResourceDescriptorFacts>());
  expect(firstDescriptor?.appKey, 'first');
  expect(secondDescriptor?.appKey, 'second');
  expect(firstDescriptor?.resourceRevision, 1);
  expect(secondDescriptor?.resourceRevision, 1);
}

void _clearsMixedBaseAndResourceTailDescriptors() {
  final scenario = _MixedResourceClearScenario();
  final work = _SelectiveResourceTableWork();

  final frozen = scenario.run(work);
  scenario.expectResult(frozen, work);
}

final class _MixedResourceClearScenario {
  final baseRetained = CanvasResourceId('base-retained');
  final baseRemoved = CanvasResourceId('base-removed');
  final tailRemoved = CanvasResourceId('tail-removed');
  final tailRetained = CanvasResourceId('tail-retained');

  ResourceTable run(_SelectiveResourceTableWork work) =>
      ResourceTableEditor.observeWork(
        work.record,
        () => ResourceTableEditor.editSparse(_base, (editor) {
          _upsertTail(editor);
          expect(editor.descriptors.removeUnreferenced(_isReferenced), isTrue);
          editor.normalizeFinalFacts(acceptedRevision: 2);
          return editor.freeze();
        }),
      );

  void expectResult(ResourceTable frozen, _SelectiveResourceTableWork work) {
    expect(frozen.descriptors.keys, [baseRetained, tailRetained]);
    expect(work.idsFor(ResourceTableEditorWorkKind.clearEntryVisit), [
      baseRetained,
      baseRemoved,
      tailRemoved,
      tailRetained,
    ]);
    expect(work.idsFor(ResourceTableEditorWorkKind.currentRemove), [
      baseRemoved,
      tailRemoved,
    ]);
    expect(work.count(ResourceTableEditorWorkKind.freeze), 1);
    expect(work.count(ResourceTableEditorWorkKind.immutablePublication), 1);
  }

  ResourceTable get _base => ResourceTable([
    CanvasImageResource(
      id: baseRetained,
      source: CanvasResourceSource.appKey('base-retained'),
    ),
    CanvasVectorResource(
      id: baseRemoved,
      source: CanvasResourceSource.appKey('base-removed'),
    ),
  ], resourceRevision: 1);

  void _upsertTail(ResourceTableEditor editor) {
    editor.descriptors.upsert(
      CanvasImageResource(
        id: tailRemoved,
        source: CanvasResourceSource.appKey('tail-removed'),
      ),
      resourceRevision: 1,
    );
    editor.descriptors.upsert(
      CanvasVectorResource(
        id: tailRetained,
        source: CanvasResourceSource.appKey('tail-retained'),
      ),
      resourceRevision: 1,
    );
  }

  bool _isReferenced(CanvasResourceId id) =>
      id == baseRetained || id == tailRetained;
}

DocumentStoreKernel _resourceOnlyStore(int count) {
  return documentStoreWithDocument(
    CanvasDocument(
      resources: List.generate(
        count,
        (index) => CanvasImageResource(
          id: CanvasResourceId('resource-$index'),
          source: CanvasResourceSource.appKey('base-$index'),
        ),
      ),
    ),
  );
}

void _expectSingleResourceNormalization(
  PreparedSparseStoreCommit prepared,
  _SelectiveResourceTableWork resourceWork, {
  required int baseCount,
  required DocumentStoreKernel store,
}) {
  expect(prepared.hasChanges, isTrue);
  expect(
    resourceWork.count(
      ResourceTableEditorWorkKind.editorOpen,
      phase: ResourceTableEditorWorkPhase.replay,
    ),
    1,
  );
  expect(resourceWork.count(ResourceTableEditorWorkKind.normalizationRead), 1);
  expect(resourceWork.count(ResourceTableEditorWorkKind.normalizationWrite), 1);
  _expectSingleResourceReplayWork(resourceWork);
  expect(resourceWork.count(ResourceTableEditorWorkKind.clearEntryVisit), 0);
  expect(
    resourceWork.count(
      ResourceTableEditorWorkKind.materializationBaseEntryVisit,
    ),
    baseCount,
  );
  expect(
    resourceWork.count(
      ResourceTableEditorWorkKind.materializationBaseEntryCopy,
    ),
    baseCount,
  );
  expect(resourceWork.count(ResourceTableEditorWorkKind.freeze), 1);
  expect(
    resourceWork.count(ResourceTableEditorWorkKind.immutablePublication),
    1,
  );
  expect(resourceWork.discardCount, 0);
  expect(resourceWork.finalRetainsBaseIdentity, isFalse);
  expect(
    prepared
        .document
        .resourceTable
        .descriptors[CanvasResourceId('resource-0')]
        ?.resourceRevision,
    2,
  );
  expect(store.projectionBuildCount, 0);
}

void _expectSingleResourceReplayWork(_SelectiveResourceTableWork resourceWork) {
  expect(
    resourceWork.count(
      ResourceTableEditorWorkKind.currentWrite,
      phase: ResourceTableEditorWorkPhase.replay,
    ),
    1,
  );
  expect(
    resourceWork.count(ResourceTableEditorWorkKind.currentRead),
    greaterThanOrEqualTo(2),
  );
}

void _expectClearResourceRemovals(
  _SelectiveResourceTableWork resourceWork,
  int expectedRemovals,
) {
  expect(
    resourceWork.count(ResourceTableEditorWorkKind.currentRemove),
    expectedRemovals,
  );
}

void _sealsSparseResourceEditorBuffers() {
  _expectFrozenResourceEditorIsSealed();
  _expectDiscardedResourceEditorIsSealed();
  _expectFinalEqualResourceEditorKeepsBaseIdentity();
  _expectResourceNoOpKeepsBaseIdentity();
}

void _expectFrozenResourceEditorIsSealed() {
  final fixture = _freezeResourceEditorForIsolation();
  _expectFrozenResourceTable(fixture.frozen);
  _expectPublishedEditorIsClosed(fixture.editor, fixture.frozen, fixture.work);
}

({
  ResourceTable frozen,
  ResourceTableEditor editor,
  _SelectiveResourceTableWork work,
})
_freezeResourceEditorForIsolation() {
  final base = _resourceEditorIsolationBase();
  final work = _SelectiveResourceTableWork();
  late ResourceTableEditor publishedEditor;
  final frozen = ResourceTableEditor.observeWork(
    work.record,
    () => ResourceTableEditor.editSparse(base, (editor) {
      publishedEditor = editor;
      editor.descriptors.upsert(
        CanvasImageResource(
          id: CanvasResourceId('added'),
          source: CanvasResourceSource.appKey('added'),
        ),
        resourceRevision: 1,
      );
      editor.normalizeFinalFacts(acceptedRevision: 2);
      return editor.freeze();
    }),
  );

  return (frozen: frozen, editor: publishedEditor, work: work);
}

void _expectFrozenResourceTable(ResourceTable frozen) {
  expect(frozen.descriptors.keys, [
    CanvasResourceId('base'),
    CanvasResourceId('added'),
  ]);
  expect(frozen.descriptors[CanvasResourceId('added')]?.resourceRevision, 2);
}

void _expectPublishedEditorIsClosed(
  ResourceTableEditor editor,
  ResourceTable frozen,
  _SelectiveResourceTableWork work,
) {
  ResourceTableEditor.observeWork(work.record, () {
    expect(
      () => editor.descriptors.remove(CanvasResourceId('added')),
      throwsStateError,
    );
    expect(
      () => editor.normalizeFinalFacts(acceptedRevision: 3),
      throwsStateError,
    );
    expect(editor.freeze, throwsStateError);
  });
  expect(
    () => frozen.descriptors[CanvasResourceId('added')] =
        frozen.descriptors[CanvasResourceId('base')]!,
    throwsUnsupportedError,
  );
  expect(work.count(ResourceTableEditorWorkKind.postClosureAccess), 3);
}

void _expectDiscardedResourceEditorIsSealed() {
  final base = _resourceEditorIsolationBase();
  final work = _SelectiveResourceTableWork();
  final discardedEditor = _discardResourceEditorWithFailure(base, work);
  expect(base.descriptors.keys, [CanvasResourceId('base')]);
  ResourceTableEditor.observeWork(
    work.record,
    () => expect(
      () =>
          discardedEditor.descriptors.descriptor(CanvasResourceId('discarded')),
      throwsStateError,
    ),
  );
  expect(work.discardCount, 1);
  expect(work.finalRetainsBaseIdentity, isTrue);
  expect(work.count(ResourceTableEditorWorkKind.immutablePublication), 0);
  expect(work.count(ResourceTableEditorWorkKind.freeze), 0);
}

ResourceTableEditor _discardResourceEditorWithFailure(
  ResourceTable base,
  _SelectiveResourceTableWork work,
) {
  late ResourceTableEditor editor;
  expect(
    () => ResourceTableEditor.observeWork(
      work.record,
      () => ResourceTableEditor.editSparse(base, (current) {
        editor = current;
        current.descriptors.upsert(
          CanvasImageResource(
            id: CanvasResourceId('discarded'),
            source: CanvasResourceSource.appKey('discarded'),
          ),
          resourceRevision: 1,
        );
        throw ArgumentError('failure');
      }),
    ),
    throwsArgumentError,
  );
  return editor;
}

ResourceTable _resourceEditorIsolationBase() {
  return ResourceTable([
    CanvasImageResource(
      id: CanvasResourceId('base'),
      source: CanvasResourceSource.appKey('base'),
    ),
  ], resourceRevision: 1);
}

void _expectFinalEqualResourceEditorKeepsBaseIdentity() {
  final base = _resourceEditorIsolationBase();
  final work = _SelectiveResourceTableWork();
  final frozen = ResourceTableEditor.observeWork(
    work.record,
    () => ResourceTableEditor.editSparse(base, (editor) {
      editor.descriptors.upsert(
        CanvasImageResource(
          id: CanvasResourceId('base'),
          source: CanvasResourceSource.appKey('base'),
        ),
        resourceRevision: 1,
      );
      editor.normalizeFinalFacts(acceptedRevision: 2);
      return editor.freeze();
    }),
  );

  expect(identical(frozen, base), isTrue);
  expect(work.count(ResourceTableEditorWorkKind.normalizationRead), 1);
  expect(work.count(ResourceTableEditorWorkKind.freeze), 0);
  expect(work.count(ResourceTableEditorWorkKind.immutablePublication), 0);
  expect(work.finalRetainsBaseIdentity, isTrue);
}

void _expectResourceNoOpKeepsBaseIdentity() {
  final base = _resourceEditorNoOpBase();
  final store = DocumentStoreKernel.withCommittedDocumentForTesting(base);
  final work = _SelectiveResourceTableWork();
  final prepared = _prepareResourceNoOp(store, work);

  expect(prepared.hasChanges, isFalse);
  expect(
    identical(prepared.document.resourceTable, base.resourceTable),
    isTrue,
  );
  expect(work.count(ResourceTableEditorWorkKind.immutablePublication), 0);
  expect(work.count(ResourceTableEditorWorkKind.freeze), 0);
  expect(work.discardCount, 1);
  expect(work.finalRetainsBaseIdentity, isTrue);
}

CommittedDocument _resourceEditorNoOpBase() => CommittedDocument(
  CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('base'),
        source: CanvasResourceSource.appKey('base'),
      ),
    ],
  ),
);

PreparedSparseStoreCommit _prepareResourceNoOp(
  DocumentStoreKernel store,
  _SelectiveResourceTableWork work,
) {
  return ResourceTableEditor.observeWork(
    work.record,
    () => store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.resource(),
        mutations: [
          StoreSparseUpsertResource(
            CanvasImageResource(
              id: CanvasResourceId('base'),
              source: CanvasResourceSource.appKey('base'),
            ),
          ),
        ],
      ),
    ),
  );
}

// The facts stay together to distinguish this no-op policy from ordinary
// content clearing; extracting them would create a setup mirror.
// ignore: halstead-volume
void _backgroundOnlyClearIsNoOp() {
  final store = documentStoreWithDocument(
    CanvasDocument(
      resources: [
        CanvasImageResource(
          id: CanvasResourceId('background-only-resource'),
          source: CanvasResourceSource.appKey('background-only-source'),
        ),
      ],
      backgroundElements: [
        CanvasImageElement(
          id: CanvasElementId('background-only-element'),
          resourceId: CanvasResourceId('background-only-resource'),
          size: const Size(13, 17),
        ),
      ],
    ),
  );
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
      mutations: const [StoreSparseClearContent(removeUnusedResources: true)],
    ),
  );

  expect(prepared.hasChanges, isFalse);
  expect(prepared.touchedFacts.hasTouches, isFalse);
  expect(store.documentRevision, 1);
  expect(store.structuralRevision, 1);
  expect(store.resourceRevision, 1);
  expect(store.backgroundElementIds, [
    CanvasElementId('background-only-element'),
  ]);
  expect(store.resourceCount, 1);
  expect(store.projectionBuildCount, 0);
}

// Regression: evaluating remove-unused mutations against the final clear state
// would erase this ordinary-content descriptor before clear or retain it after.
// Both orders and their exact accepted facts are one barrier-policy witness.
// ignore: halstead-volume, source-lines-of-code
void _clearsResourceOnlyDocument() {
  final resourceOnlyStore = documentStoreWithDocument(resourceOnlyDocument());
  final prepared = resourceOnlyStore.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.resource(),
      mutations: const [StoreSparseClearContent(removeUnusedResources: true)],
    ),
  );
  expect(prepared.touchedFacts.removedElementIds, isEmpty);
  expect(prepared.touchedFacts.layerIds, isEmpty);
  expect(prepared.touchedFacts.backgroundLayerChanged, isFalse);
  expect(prepared.touchedFacts.background, isFalse);
  expect(prepared.touchedFacts.grid, isFalse);
  expect(prepared.touchedFacts.resourceDescriptorChangedIds, {
    CanvasResourceId('resource-only'),
  });
  expect(prepared.touchedFacts.resourceVisualChangedIds, isEmpty);
  expect(prepared.revisionDelta.structural, isFalse);
  expect(prepared.revisionDelta.bounds, isFalse);
  expect(prepared.revisionDelta.elementVisual, isFalse);
  expect(prepared.revisionDelta.resource, isTrue);
  resourceOnlyStore.installSparseCommit(prepared);
  expect(resourceOnlyStore.documentSummary.resourceCount, 0);
  expect(resourceOnlyStore.documentSummary.elementCount, 0);
  expect(resourceOnlyStore.resourceRevision, 2);
}

final class _SelectiveResourceTableWork {
  final List<ResourceTableSelectiveMutationEvent> _events = [];

  int get openCount => count(ResourceTableEditorWorkKind.editorOpen);
  int get entryVisitCount => count(ResourceTableEditorWorkKind.clearEntryVisit);
  int get baseEntryCopyCount =>
      count(ResourceTableEditorWorkKind.materializationBaseEntryCopy);
  int get freezeCount => count(ResourceTableEditorWorkKind.freeze);
  int get immutablePublicationCount =>
      count(ResourceTableEditorWorkKind.immutablePublication);
  int get discardCount => count(ResourceTableEditorWorkKind.discard);
  bool? get finalRetainsBaseIdentity => _events
      .where((event) => event.kind == ResourceTableEditorWorkKind.finalIdentity)
      .lastOrNull
      ?.retainsBaseIdentity;

  int count(
    ResourceTableEditorWorkKind kind, {
    ResourceTableEditorWorkPhase? phase,
  }) => _events
      .where(
        (event) =>
            event.kind == kind && (phase == null || event.phase == phase),
      )
      .length;

  List<CanvasResourceId> idsFor(ResourceTableEditorWorkKind kind) => _events
      .where((event) => event.kind == kind)
      .map((event) => event.id)
      .whereType<CanvasResourceId>()
      .toList(growable: false);

  void record(ResourceTableSelectiveMutationEvent event) => _events.add(event);
}
