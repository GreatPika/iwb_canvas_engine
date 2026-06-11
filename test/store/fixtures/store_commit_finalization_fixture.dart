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
    'sparse changed facts prepare exact accepted delta',
    () => expect(_sparseChangedFactsPrepareAcceptedDelta, returnsNormally),
  );
  test(
    'sparse implicit layer add prepares accepted layer touch',
    () => expect(_sparseImplicitLayerAddPreparesLayerTouch, returnsNormally),
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

void _sparseImplicitLayerAddPreparesLayerTouch() {
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
  expect(sparsePrepared.touchedFacts.layerIds, {CanvasLayerId('layer-1')});
  expect(store.projectionBuildCount, 0);
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
