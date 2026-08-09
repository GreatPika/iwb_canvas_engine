import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/edit/draft_document.dart';
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
