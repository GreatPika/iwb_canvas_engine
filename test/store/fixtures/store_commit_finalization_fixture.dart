import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/edit/draft_document.dart';
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/revision_state.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
import 'package:iwb_canvas_engine/src/store/store_commit_finalization.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

import '../../support/document_store_with_document.dart';

void main() {
  _registerStoreCommitFinalizationTests();
}

void _registerStoreCommitFinalizationTests() {
  _registerMaterializedFinalizationTests();
  _registerSparseFinalizationTests();
}

void _registerMaterializedFinalizationTests() {
  test(
    'materialized final equality prepares as accepted no-op',
    () => expect(_materializedFinalEqualityPreparesAsNoOp, returnsNormally),
  );
  test(
    'materialized resource compensation prepares as accepted no-op',
    () => expect(
      _materializedResourceCompensationPreparesAsNoOp,
      returnsNormally,
    ),
  );
  test(
    'materialized changed facts prepare exact accepted delta',
    () =>
        expect(_materializedChangedFactsPrepareAcceptedDelta, returnsNormally),
  );
  test(
    'prepared materialized commit installs accepted facts',
    () => expect(
      _preparedMaterializedCommitInstallsAcceptedFacts,
      returnsNormally,
    ),
  );
  test(
    'materialized missing resource is rejected before install',
    () => expect(
      _materializedMissingResourceIsRejectedBeforeInstall,
      returnsNormally,
    ),
  );
  test(
    'materialized wrong resource kind is rejected before install',
    () => expect(
      _materializedWrongResourceKindIsRejectedBeforeInstall,
      returnsNormally,
    ),
  );
}

void _registerSparseFinalizationTests() {
  test(
    'sparse changed facts prepare exact accepted delta',
    () => expect(_sparseChangedFactsPrepareAcceptedDelta, returnsNormally),
  );
  test(
    'sparse append add prepares accepted element touch without layer rebuild',
    () => expect(_sparseAppendAddPreparesElementTouchOnly, returnsNormally),
  );
  test(
    'sparse indexed add prepares accepted layer touch',
    () => expect(_sparseIndexedAddPreparesLayerTouch, returnsNormally),
  );
  test(
    'sparse content removal prepares accepted base layer touch',
    () => expect(_sparseContentRemovalPreparesBaseLayerTouch, returnsNormally),
  );
  test(
    'sparse spatial-only update prepares accepted geometry touch',
    () =>
        expect(_sparseSpatialOnlyUpdatePreparesGeometryTouch, returnsNormally),
  );
  test(
    'sparse no-op ensure layer does not prepare accepted layer touch',
    () => expect(_sparseNoOpEnsureLayerDoesNotTouchLayer, returnsNormally),
  );
  test(
    'sparse deferred updates retain journal order after overwrite or removal',
    () => expect(
      _sparseDeferredUpdatesRetainJournalOrderAfterOverwriteOrRemoval,
      returnsNormally,
    ),
  );
}

// This exhaustive event filter is the direct candidate phase vocabulary; a
// split switch would separate the ordered assertion from its stable owner set.
// ignore: cyclomatic-complexity
void _expectCandidateFinalization(
  Iterable<StoreSparseCandidateEvent> events,
  List<StoreSparseCandidateEventKind> expected,
) {
  final actual = [
    for (final event in events)
      if (switch (event.kind) {
        StoreSparseCandidateEventKind.relationshipValidation ||
        StoreSparseCandidateEventKind.providedDeltaValidation ||
        StoreSparseCandidateEventKind.deferredValidation ||
        StoreSparseCandidateEventKind.acceptedFacts ||
        StoreSparseCandidateEventKind.coverageValidation ||
        StoreSparseCandidateEventKind.normalization ||
        StoreSparseCandidateEventKind.familyFreeze ||
        StoreSparseCandidateEventKind.resourceFreeze ||
        StoreSparseCandidateEventKind.structuralPublication ||
        StoreSparseCandidateEventKind.aggregatePublication ||
        StoreSparseCandidateEventKind.touchedFacts ||
        StoreSparseCandidateEventKind.consume ||
        StoreSparseCandidateEventKind.discard => true,
        StoreSparseCandidateEventKind.open ||
        StoreSparseCandidateEventKind.currentScalarRead ||
        StoreSparseCandidateEventKind.touchedElementRead ||
        StoreSparseCandidateEventKind.touchedResourceRead => false,
      })
        event.kind,
  ];
  expect(actual, expected);
}

void _materializedFinalEqualityPreparesAsNoOp() {
  final store = documentStoreWithDocument(_baseDocument());
  final beforeDocumentRevision = store.documentRevision;
  final prepared = store.prepareMaterializedCommit(
    _baseDocument(),
    const StoreRevisionDelta.background().merge(
      const StoreRevisionDelta.resource(),
    ),
  );

  expect(prepared.hasChanges, isFalse);
  expect(prepared.revisionDelta.hasChanges, isFalse);
  expect(prepared.touchedFacts.hasTouches, isFalse);
  expect(prepared.document, same(prepared.baseDocument));
  expect(store.documentRevision, beforeDocumentRevision);
  expect(store.projectionBuildCount, 0);
}

void _materializedResourceCompensationPreparesAsNoOp() {
  final store = documentStoreWithDocument(_baseDocument());
  final beforeDocumentRevision = store.documentRevision;
  final beforeProjectionBuilds = store.projectionBuildCount;
  final draft = DraftDocument(_baseDocument());

  expect(
    draft.upsertResource(_resource('resource-1', appKey: 'resource-1-next')),
    isTrue,
  );
  expect(draft.upsertResource(_resource('resource-1')), isTrue);

  final prepared = store.prepareMaterializedCommit(
    draft.readDocument(),
    draft.revisionDelta,
  );

  expect(prepared.hasChanges, isFalse);
  expect(prepared.revisionDelta.hasChanges, isFalse);
  expect(prepared.touchedFacts.hasTouches, isFalse);
  expect(prepared.document, same(prepared.baseDocument));
  expect(store.documentRevision, beforeDocumentRevision);
  expect(store.projectionBuildCount, beforeProjectionBuilds);
}

void _materializedChangedFactsPrepareAcceptedDelta() {
  final store = documentStoreWithDocument(_baseDocument());
  final beforeRevisions = store
      .prepareMaterializedCommit(_baseDocument(), const StoreRevisionDelta())
      .baseDocument
      .revisions;
  final prepared = store.prepareMaterializedCommit(
    _baseDocument(backgroundColor: const Color(0xFF112233)),
    const StoreRevisionDelta.background().merge(
      const StoreRevisionDelta.resource(),
    ),
  );

  expect(prepared.hasChanges, isTrue);
  expect(prepared.document.background.color, const Color(0xFF112233));
  _expectBackgroundOnlyAcceptedDelta(prepared.revisionDelta);
  _expectBackgroundOnlyAcceptedTouches(prepared.touchedFacts);
  _expectBackgroundOnlyMaterializedRevisions(prepared, beforeRevisions);
  expect(store.documentRevision, beforeRevisions.documentRevision);
  expect(store.projectionBuildCount, 0);
}

void _preparedMaterializedCommitInstallsAcceptedFacts() {
  final store = documentStoreWithDocument(_baseDocument());
  final beforeDocumentRevision = store.documentRevision;
  final prepared = store.prepareMaterializedCommit(
    _baseDocument(backgroundColor: const Color(0xFF112233)),
    const StoreRevisionDelta.background(),
  );

  store.installPreparedMaterializedCommit(prepared);

  expect(store.background.color, const Color(0xFF112233));
  expect(store.documentRevision, beforeDocumentRevision + 1);
  expect(store.projectionBuildCount, 0);
}

void _materializedMissingResourceIsRejectedBeforeInstall() {
  final store = documentStoreWithDocument(_baseDocument());
  final beforeSummary = store.documentSummary;
  final beforeProjectionBuilds = store.projectionBuildCount;

  expect(
    () => store.prepareMaterializedCommit(
      _documentWithMissingImageResource(),
      const StoreRevisionDelta.structural(),
    ),
    throwsA(
      isA<CanvasDataException>()
          .having(
            (error) => error.code,
            'code',
            CanvasDataErrorCode.missingResourceReference,
          )
          .having((error) => error.path, 'path', 'image.resourceId'),
    ),
  );
  expect(store.documentSummary, beforeSummary);
  expect(store.projectionBuildCount, beforeProjectionBuilds);
}

void _materializedWrongResourceKindIsRejectedBeforeInstall() {
  _expectMaterializedResourceKindRejectedBeforeInstall(
    _documentWithImageUsingVectorResource(),
    'image.resourceId',
  );
  _expectMaterializedResourceKindRejectedBeforeInstall(
    _documentWithVectorUsingImageResource(),
    'vector.resourceId',
  );
}

void _expectMaterializedResourceKindRejectedBeforeInstall(
  CanvasDocument candidate,
  String path,
) {
  final store = documentStoreWithDocument(_baseDocument());
  final beforeSummary = store.documentSummary;
  final beforeDocumentRevision = store.documentRevision;
  final beforeProjectionBuilds = store.projectionBuildCount;

  expect(
    () => store.prepareMaterializedCommit(
      candidate,
      const StoreRevisionDelta.structural(),
    ),
    throwsA(
      isA<CanvasDataException>()
          .having(
            (error) => error.code,
            'code',
            CanvasDataErrorCode.resourceKindMismatch,
          )
          .having((error) => error.path, 'path', path),
    ),
  );
  expect(store.documentSummary, beforeSummary);
  expect(store.documentRevision, beforeDocumentRevision);
  expect(store.projectionBuildCount, beforeProjectionBuilds);
}

void _sparseChangedFactsPrepareAcceptedDelta() {
  final store = documentStoreWithDocument(_baseDocument());
  final beforeRevisions = store
      .prepareMaterializedCommit(_baseDocument(), const StoreRevisionDelta())
      .baseDocument
      .revisions;
  final sparsePrepared = store.prepareSparseCommit(
    StoreSparseCommit(
      mutations: const [
        StoreSparseSetBackground(CanvasBackground(color: Color(0xFF112233))),
      ],
      revisionDelta: const StoreRevisionDelta.background().merge(
        const StoreRevisionDelta.resource(),
      ),
    ),
  );

  expect(sparsePrepared.hasChanges, isTrue);
  _expectBackgroundOnlyAcceptedDelta(sparsePrepared.revisionDelta);
  _expectBackgroundOnlyAcceptedTouches(sparsePrepared.touchedFacts);
  store.installSparseCommit(sparsePrepared);
  expect(store.background.color, const Color(0xFF112233));
  expect(store.backgroundRevision, beforeRevisions.backgroundRevision + 1);
  expect(store.resourceRevision, beforeRevisions.resourceRevision);
  expect(store.projectionBuildCount, 0);
}

void _sparseAppendAddPreparesElementTouchOnly() {
  final store = documentStoreWithDocument(_baseDocument());
  final sparsePrepared = store.prepareSparseCommit(
    StoreSparseCommit(
      mutations: [
        StoreSparseAddElement(
          element: CanvasRectElement(
            id: CanvasElementId('implicit-layer-add'),
            size: const Size(2, 3),
          ),
        ),
      ],
      revisionDelta: const StoreRevisionDelta.structural(),
    ),
  );

  expect(sparsePrepared.hasChanges, isTrue);
  expect(sparsePrepared.touchedFacts.addedElementIds, {
    CanvasElementId('implicit-layer-add'),
  });
  expect(sparsePrepared.touchedFacts.layerIds, isEmpty);
  expect(store.projectionBuildCount, 0);
}

void _sparseIndexedAddPreparesLayerTouch() {
  final store = documentStoreWithDocument(_baseDocument());
  final sparsePrepared = store.prepareSparseCommit(
    StoreSparseCommit(
      mutations: [
        StoreSparseAddElement(
          element: CanvasRectElement(
            id: CanvasElementId('indexed-layer-add'),
            size: const Size(2, 3),
          ),
          layerId: CanvasLayerId('layer-1'),
          index: 0,
        ),
      ],
      revisionDelta: const StoreRevisionDelta.structural(),
    ),
  );

  expect(sparsePrepared.hasChanges, isTrue);
  expect(sparsePrepared.touchedFacts.addedElementIds, {
    CanvasElementId('indexed-layer-add'),
  });
  expect(sparsePrepared.touchedFacts.layerIds, {CanvasLayerId('layer-1')});
  expect(store.projectionBuildCount, 0);
}

void _sparseContentRemovalPreparesBaseLayerTouch() {
  final store = documentStoreWithDocument(_baseDocument());
  final sparsePrepared = store.prepareSparseCommit(
    StoreSparseCommit(
      mutations: [StoreSparseRemoveElement(CanvasElementId('rect-1'))],
      revisionDelta: const StoreRevisionDelta.structural(),
    ),
  );

  expect(sparsePrepared.hasChanges, isTrue);
  expect(sparsePrepared.touchedFacts.removedElementIds, {
    CanvasElementId('rect-1'),
  });
  expect(sparsePrepared.touchedFacts.layerIds, {CanvasLayerId('layer-1')});
  expect(store.projectionBuildCount, 0);
}

void _sparseSpatialOnlyUpdatePreparesGeometryTouch() {
  final store = documentStoreWithDocument(_baseDocument());
  final before = store.elementById(CanvasElementId('rect-1'));
  if (before is! CanvasRectElement) {
    throw StateError('Expected rect-1 to be a committed rect.');
  }
  final after = CanvasRectElement(
    id: before.id,
    revision: before.revision + 1,
    size: const Size(1, 1),
    isSelectable: false,
  );
  final sparsePrepared = store.prepareSparseCommit(
    StoreSparseCommit(
      mutations: [
        StoreSparseUpdateElement(
          before: before,
          element: after,
          elementRevisionDelta: const StoreRevisionDelta.projectionOnly(),
        ),
      ],
      revisionDelta: const StoreRevisionDelta.projectionOnly(),
    ),
  );

  expect(sparsePrepared.hasChanges, isTrue);
  _expectSparseSpatialOnlyTouches(sparsePrepared.touchedFacts);
  expect(store.projectionBuildCount, 0);
}

void _sparseNoOpEnsureLayerDoesNotTouchLayer() {
  final store = documentStoreWithDocument(_baseDocument());
  final before = store.elementById(CanvasElementId('rect-1'));
  if (before is! CanvasRectElement) {
    throw StateError('Expected rect-1 to be a committed rect.');
  }
  final after = CanvasRectElement(
    id: before.id,
    revision: before.revision + 1,
    size: const Size(1, 1),
    opacity: 0.5,
  );
  final sparsePrepared = store.prepareSparseCommit(
    StoreSparseCommit(
      mutations: [
        StoreSparseEnsureLayer(CanvasLayerId('layer-1')),
        StoreSparseUpdateElement(
          before: before,
          element: after,
          elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
        ),
      ],
      revisionDelta: const StoreRevisionDelta.elementVisual(),
    ),
  );

  expect(sparsePrepared.hasChanges, isTrue);
  expect(sparsePrepared.touchedFacts.layerIds, isEmpty);
  expect(sparsePrepared.touchedFacts.visualElementIds, {
    CanvasElementId('rect-1'),
  });
  expect(store.projectionBuildCount, 0);
}

// Both variants also omit the later element-visual revision coverage. The
// deferred gate must therefore surface the first effective update diagnostic.
// Keeping overwrite, removal, and ignored-update variants together makes the
// journal-order guarantee visible without coupling the assertions to helpers.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _sparseDeferredUpdatesRetainJournalOrderAfterOverwriteOrRemoval() {
  final traces = <List<StoreSparseMutation>>[];
  for (final overwrite in [true, false]) {
    final store = documentStoreWithDocument(_baseDocument());
    final before = store.elementById(CanvasElementId('rect-1'));
    if (before is! CanvasRectElement) {
      throw StateError('Expected rect-1 to be a committed rect.');
    }
    final invalidAfter = CanvasRectElement(
      id: before.id,
      revision: 3,
      size: before.size,
      fillColor: const Color(0xFF112233),
    );
    final first = StoreSparseUpdateElement(
      before: before,
      element: invalidAfter,
      elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
    );
    final later = overwrite
        ? StoreSparseUpdateElement(
            before: invalidAfter,
            element: CanvasRectElement(
              id: before.id,
              revision: 4,
              size: before.size,
              fillColor: const Color(0xFF445566),
            ),
            elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
          )
        : StoreSparseRemoveElement(before.id);
    traces.add([
      first,
      later,
      const StoreSparseSetBackground(
        CanvasBackground(color: Color(0xFF778899)),
      ),
    ]);
  }

  for (final trace in traces.indexed) {
    final store = documentStoreWithDocument(_baseDocument());
    final work = <SparseTransactionWorkEvent>[];
    final phaseEvents = <StoreSparseCandidateEvent>[];
    expect(
      () => CommittedDocument.observeSparseCandidateEvents(
        phaseEvents.add,
        () => DocumentStoreKernel.observeSparseTransactionWork(
          work.add,
          () => store.prepareSparseCommit(
            StoreSparseCommit(
              mutations: trace.$2,
              revisionDelta: const StoreRevisionDelta.background(),
            ),
          ),
        ),
      ),
      throwsA(
        isA<ArgumentError>()
            .having((error) => error.name, 'name', 'element.revision')
            .having(
              (error) => error.message,
              'message',
              'sparse element updates must carry the next committed element revision.',
            )
            .having((error) => error.invalidValue, 'invalidValue', 3),
      ),
    );
    _expectCandidateFinalization(phaseEvents, const [
      StoreSparseCandidateEventKind.relationshipValidation,
      StoreSparseCandidateEventKind.providedDeltaValidation,
      StoreSparseCandidateEventKind.deferredValidation,
      StoreSparseCandidateEventKind.discard,
    ]);
    expect(
      work
          .where(
            (event) =>
                event.kind == SparseTransactionWorkKind.ledgerAppend &&
                event.ledger == SparseTransactionWorkLedger.deferredValidation,
          )
          .map((event) => event.journalIndex),
      trace.$1 == 0 ? [0, 1] : [0],
    );
    expect(
      work
          .where(
            (event) =>
                event.phase == SparseTransactionWorkPhase.replay &&
                event.kind == SparseTransactionWorkKind.journalVisit,
          )
          .map((event) => event.journalIndex),
      List.generate(trace.$2.length, (index) => index),
    );
    expect(
      work
          .where(
            (event) =>
                event.kind == SparseTransactionWorkKind.ledgerRead &&
                event.ledger == SparseTransactionWorkLedger.deferredValidation,
          )
          .map((event) => event.journalIndex),
      [0],
    );
  }

  for (final update in [_noOpDeferredUpdate(), _missingDeferredUpdate()]) {
    final store = documentStoreWithDocument(_baseDocument());
    final work = <SparseTransactionWorkEvent>[];
    final prepared = DocumentStoreKernel.observeSparseTransactionWork(
      work.add,
      () => store.prepareSparseCommit(
        StoreSparseCommit(
          mutations: [
            update,
            const StoreSparseSetBackground(
              CanvasBackground(color: Color(0xFF778899)),
            ),
          ],
          revisionDelta: const StoreRevisionDelta.background(),
        ),
      ),
    );
    expect(prepared.hasChanges, isTrue);
    expect(
      work.where(
        (event) =>
            event.ledger == SparseTransactionWorkLedger.deferredValidation,
      ),
      isEmpty,
    );
  }
}

StoreSparseUpdateElement _noOpDeferredUpdate() {
  final before = CanvasRectElement(
    id: CanvasElementId('rect-1'),
    size: const Size(1, 1),
  );
  return StoreSparseUpdateElement(
    before: before,
    element: before,
    elementRevisionDelta: const StoreRevisionDelta(),
  );
}

StoreSparseUpdateElement _missingDeferredUpdate() {
  final before = CanvasRectElement(
    id: CanvasElementId('missing'),
    size: const Size(1, 1),
  );
  return StoreSparseUpdateElement(
    before: before,
    element: CanvasRectElement(
      id: before.id,
      revision: 1,
      size: before.size,
      fillColor: const Color(0xFF112233),
    ),
    elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
  );
}

void _expectSparseSpatialOnlyTouches(AcceptedStoreTouchedFacts facts) {
  expect(facts.updatedElementIds, {CanvasElementId('rect-1')});
  expect(facts.geometryElementIds, {CanvasElementId('rect-1')});
  expect(facts.selectionPruneElementIds, {CanvasElementId('rect-1')});
}

void _expectBackgroundOnlyAcceptedDelta(StoreRevisionDelta delta) {
  expect(delta.background, isTrue);
  expect(delta.resource, isFalse);
}

void _expectBackgroundOnlyAcceptedTouches(AcceptedStoreTouchedFacts facts) {
  expect(facts.background, isTrue);
  expect(facts.grid, isFalse);
  expect(facts.persistedCamera, isFalse);
  expect(facts.palette, isFalse);
  expect(facts.resourceDescriptorChangedIds, isEmpty);
  expect(facts.resourceVisualChangedIds, isEmpty);
}

void _expectBackgroundOnlyMaterializedRevisions(
  PreparedMaterializedStoreCommit prepared,
  RevisionState beforeRevisions,
) {
  expect(
    prepared.document.revisions.documentRevision,
    beforeRevisions.documentRevision + 1,
  );
  expect(
    prepared.document.revisions.projectionRevision,
    beforeRevisions.projectionRevision + 1,
  );
  expect(
    prepared.document.revisions.backgroundRevision,
    beforeRevisions.backgroundRevision + 1,
  );
  expect(
    prepared.document.revisions.resourceRevision,
    beforeRevisions.resourceRevision,
  );
}

CanvasImageResource _resource(String id, {String? appKey}) {
  return CanvasImageResource(
    id: CanvasResourceId(id),
    source: CanvasResourceSource.appKey(appKey ?? id),
  );
}

CanvasVectorResource _vectorResource(String id) {
  return CanvasVectorResource(
    id: CanvasResourceId(id),
    source: CanvasResourceSource.appKey(id),
  );
}

CanvasDocument _baseDocument({
  Color backgroundColor = const Color(0xFFFFFFFF),
}) {
  return CanvasDocument(
    background: CanvasBackground(color: backgroundColor),
    resources: [_resource('resource-1')],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('rect-1'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _documentWithMissingImageResource() {
  return CanvasDocument(
    resources: [_resource('resource-1')],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('missing-image-resource'),
            resourceId: CanvasResourceId('missing-resource'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _documentWithImageUsingVectorResource() {
  return CanvasDocument(
    resources: [_vectorResource('resource-1')],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('image-with-vector-resource'),
            resourceId: CanvasResourceId('resource-1'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _documentWithVectorUsingImageResource() {
  return CanvasDocument(
    resources: [_resource('resource-1')],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasVectorElement(
            id: CanvasElementId('vector-with-image-resource'),
            resourceId: CanvasResourceId('resource-1'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}
