import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/touched_set.dart';
import 'package:iwb_canvas_engine/src/edit/draft_document.dart';
import 'package:iwb_canvas_engine/src/edit/draft_structure.dart';
import 'package:iwb_canvas_engine/src/edit/edit_session.dart';
import 'package:iwb_canvas_engine/src/edit/sparse_edit_structure.dart';
import 'package:iwb_canvas_engine/src/store/indexed_order_sequence.dart';

import 'sparse_edit_session_support.dart';

// This fixture's test registration intentionally lists each structural owner
// witness together so its coverage family stays discoverable at one seam.
// ignore: source-lines-of-code
void registerSparseEditSessionStructureTests() {
  test(
    'materialized Draft indexed structure matches the sequential placement oracle',
    () => expect(
      materializedDraftIndexedStructureMatchesSequentialPlacementOracle,
      returnsNormally,
    ),
  );
  test(
    'promoted Draft structural prefixes match the sequential oracle',
    () => expect(
      promotedDraftStructuralPrefixesMatchSequentialOracle,
      returnsNormally,
    ),
  );
  test(
    'materialized Draft structural work remains owner-bounded',
    () =>
        expect(_materializedDraftStructuralWorkRemainsBounded, returnsNormally),
  );
  test(
    'sparse indexed orders match a sequential placement oracle',
    () => expect(
      _sparseIndexedOrdersMatchSequentialPlacementOracle,
      returnsNormally,
    ),
  );
  test(
    'sparse indexed orders have bounded owner-attributed work',
    () => expect(
      _sparseIndexedOrdersHaveBoundedOwnerAttributedWork,
      returnsNormally,
    ),
  );
  test(
    'sparse promotion discards opened structural orders once',
    () => expect(
      _sparsePromotionDiscardsOpenedStructuralOrdersOnce,
      returnsNormally,
    ),
  );
  test(
    'empty-layer removal preserves callback-local structural ownership across sparse and materialized edits',
    () =>
        expect(_emptyLayerRemovalPreservesStructuralOwnership, returnsNormally),
  );
  test(
    'empty-layer removal composes and publishes final state atomically in sparse and materialized edits',
    () => expect(_materializedEmptyLayerRemovalComposition, returnsNormally),
  );
}

void _emptyLayerRemovalPreservesStructuralOwnership() {
  final document = _emptyLayerRemovalDocument();
  _expectSparseAndPromotedEmptyLayerRemoval(document);
  _expectMaterializedEmptyLayerRemoval(document);
  _expectRecreatedEmptyLayerRebindsSpatialCandidates(document);
  _expectMaterializedMovedLayerAndContentAddUsesExactSpatialTouches(document);
  _expectReaddedElementTouchesBothContentLayerPlacements(document);
  _expectSameLayerElementRecreationIsSilent(document);
  _expectRemovedLastElementLayerRestorationStaysEmpty(document);
}

// Both storage routes belong in one witness because their final public state
// must agree after the same remove/recreate sequence.
// ignore: halstead-volume
void _expectRemovedLastElementLayerRestorationStaysEmpty(
  CanvasDocument document,
) {
  final populatedLayerId = CanvasLayerId('populated');
  final removedElementId = CanvasElementId('populated-element');

  for (final materialize in [false, true]) {
    final root = sparseRuntimeRootWithCommittedDocumentSeed(document);
    addTearDown(root.dispose);

    root.edits.edit((edit) {
      if (materialize) {
        edit.readDraftDocument();
      }
      expect(edit.removeElement(removedElementId), isTrue);
      expect(edit.removeEmptyLayer(populatedLayerId), isTrue);
      expect(edit.ensureLayer(populatedLayerId, index: 2), isTrue);
    });

    final restored = root.readDocument();
    expect(
      restored.layers.map((layer) => layer.id),
      document.layers.map((layer) => layer.id),
      reason: 'materialize=$materialize',
    );
    expect(
      restored.layers
          .singleWhere((layer) => layer.id == populatedLayerId)
          .elements,
      isEmpty,
      reason: 'materialize=$materialize',
    );
    expect(root.state.value.summary.elementCount, 1);
  }
}

/// Keeps the public lifetime and atomic-publication oracle in one fixture;
/// splitting it would hide the shared final-candidate boundary for metrics.
// ignore: halstead-volume, source-lines-of-code, maintainability-index, reason: Shared public trace preserves the atomic final-candidate oracle.
void _materializedEmptyLayerRemovalComposition() {
  final document = _emptyLayerRemovalDocument();
  final emptyId = CanvasLayerId('empty');
  final afterId = CanvasLayerId('after');
  final restoredId = CanvasElementId('restored-after-read');

  final addBeforeRemove = sparseRuntimeRootWithCommittedDocumentSeed(document);
  final beforeRevision = addBeforeRemove.state.value.revisions.document;
  addBeforeRemove.edits.edit((edit) {
    edit.readDraftDocument();
    edit.addElement(
      sparseRect(restoredId.value),
      layerId: CanvasLayerId('before'),
    );
    expect(edit.removeEmptyLayer(emptyId), isTrue);
  });
  expect(addBeforeRemove.state.value.revisions.document, beforeRevision + 1);
  expect(addBeforeRemove.readDocument().layers.map((layer) => layer.id), [
    CanvasLayerId('before'),
    CanvasLayerId('populated'),
    afterId,
  ]);

  final removeBeforeAdd = sparseRuntimeRootWithCommittedDocumentSeed(document);
  removeBeforeAdd.edits.edit((edit) {
    edit.readDraftDocument();
    expect(edit.removeEmptyLayer(emptyId), isTrue);
    edit.addElement(
      sparseRect(restoredId.value),
      layerId: CanvasLayerId('before'),
    );
  });
  expect(
    removeBeforeAdd.readDocument().layers.first.elements.single.id,
    restoredId,
  );

  final multiRemove = sparseRuntimeRootWithCommittedDocumentSeed(document);
  multiRemove.edits.edit((edit) {
    expect(edit.removeEmptyLayer(emptyId), isTrue);
    edit.readDraftDocument();
    expect(edit.removeEmptyLayer(afterId), isTrue);
  });
  expect(multiRemove.readDocument().layers.map((layer) => layer.id), [
    CanvasLayerId('before'),
    CanvasLayerId('populated'),
  ]);

  final compensated = sparseRuntimeRootWithCommittedDocumentSeed(document);
  final compensatedRevision = compensated.state.value.revisions.document;
  compensated.edits.edit((edit) {
    edit.readDraftDocument();
    expect(edit.removeEmptyLayer(emptyId), isTrue);
    expect(edit.ensureLayer(emptyId, index: 1), isTrue);
  });
  expect(compensated.state.value.revisions.document, compensatedRevision);
  final compensatedDocument = compensated.readDocument();
  expect(
    compensatedDocument.layers.map((layer) => layer.id),
    document.layers.map((layer) => layer.id),
  );
  expect(
    compensatedDocument.backgroundElements.map((element) => element.id),
    document.backgroundElements.map((element) => element.id),
  );
  expect(
    compensatedDocument.resources.map((resource) => resource.id),
    document.resources.map((resource) => resource.id),
  );

  _expectAtomicEmptyLayerRemovalPublication(document, materialize: false);
  _expectAtomicEmptyLayerRemovalPublication(document, materialize: true);
}

// Both routes must share this complete public publication oracle; splitting
// assertions would obscure the required sparse/materialized parity.
// ignore: halstead-volume, source-lines-of-code, reason: One public atomicity trace must remain identical across both routes.
void _expectAtomicEmptyLayerRemovalPublication(
  CanvasDocument document, {
  required bool materialize,
}) {
  final emptyId = CanvasLayerId('empty');
  final afterId = CanvasLayerId('after');
  final atomic = sparseRuntimeRootWithCommittedDocumentSeed(document);
  final previouslySelectedId = CanvasElementId('populated-element');
  atomic.selection.setSelection([previouslySelectedId]);
  final beforeAtomic = atomic.state.value;
  final publications =
      <
        ({
          CanvasRuntimeState state,
          CanvasDocument document,
          Set<CanvasElementId> selectedIds,
        })
      >[];
  atomic.state.addListener(
    () => publications.add((
      state: atomic.state.value,
      document: atomic.readDocument(),
      selectedIds: atomic.selectedElementIds,
    )),
  );
  final atomicRestoredId = CanvasElementId('atomically-restored');
  atomic.edits.edit((edit) {
    if (materialize) {
      edit.readDraftDocument();
    }
    expect(edit.removeEmptyLayer(emptyId), isTrue);
    edit.addElement(
      sparseRect(atomicRestoredId.value),
      layerId: CanvasLayerId('before'),
    );
    edit.setSelection([atomicRestoredId]);
    expect(atomic.selectedElementIds, {previouslySelectedId});
  });

  expect(publications, hasLength(1));
  final publication = publications.single;
  expect(
    publication.state.revisions.document,
    beforeAtomic.revisions.document + 1,
  );
  expect(
    publication.state.revisions.selection,
    beforeAtomic.revisions.selection + 1,
  );
  expect(publication.state.summary.elementCount, 3);
  expect(publication.state.summary.layerCount, 3);
  expect(publication.state.summary.resourceCount, 1);
  expect(publication.state.summary.selectedCount, 1);
  expect(publication.selectedIds, {atomicRestoredId});
  expect(publication.document.layers.map((layer) => layer.id), [
    CanvasLayerId('before'),
    CanvasLayerId('populated'),
    afterId,
  ]);
  expect(
    publication.document.layers.first.elements.map((element) => element.id),
    [atomicRestoredId],
  );
  expect(
    publication.document.backgroundElements.map((element) => element.id),
    document.backgroundElements.map((element) => element.id),
  );
  expect(
    publication.document.resources.map((resource) => resource.id),
    document.resources.map((resource) => resource.id),
  );
}

// Commit delivery and the following spatial revision check are one Runtime
// boundary witness; splitting them would hide the rebind cause and effect.
// ignore: halstead-volume, reason: The public Runtime rebind witness is clearer as one trace.
void _expectRecreatedEmptyLayerRebindsSpatialCandidates(
  CanvasDocument document,
) {
  for (final materialize in [false, true]) {
    _expectMovedEmptyLayerRebindsSpatialCandidates(
      document,
      materialize: materialize,
    );
    _expectSameIndexEmptyLayerRecreationIsSilent(
      document,
      materialize: materialize,
    );
  }
}

/// One Runtime witness retains effect delivery, rebind, and bounded frame work.
// ignore: halstead-volume, source-lines-of-code, reason: One Runtime route must retain its delivered-effect, frame-work, and query oracle.
void _expectMovedEmptyLayerRebindsSpatialCandidates(
  CanvasDocument document, {
  required bool materialize,
}) {
  final spatialDeliveries = SparseRuntimeSpatialDeliveryRecorder();
  final root = sparseRuntimeRootWithCommittedDocumentSeed(
    document,
    spatialDeliveryRecorder: spatialDeliveries,
  );
  final emptyId = CanvasLayerId('empty');
  final beforeRevision = root.frameRevisions.structuralRevision;
  final beforeEntryCount = root.spatialKernel.snapshot.entryCount;
  var frameHandleEnumerations = 0;

  observeSparseRuntimeFrameHandleEnumerations(
    () => frameHandleEnumerations += 1,
    () => root.edits.edit((edit) {
      if (materialize) {
        edit.readDraftDocument();
      }
      expect(edit.removeEmptyLayer(emptyId), isTrue);
      expect(edit.ensureLayer(emptyId, index: 0), isTrue);
    }),
  );

  expect(root.frameRevisions.structuralRevision, beforeRevision + 1);
  expect(root.spatialKernel.snapshot.structuralRevision, beforeRevision + 1);
  expect(root.spatialKernel.snapshot.isInvalid, isFalse);
  expect(root.spatialKernel.snapshot.entryCount, beforeEntryCount);
  expect(frameHandleEnumerations, 0);
  expect(spatialDeliveries.spatialDeliveries, hasLength(1));
  _expectBoundedSpatialDelivery(
    spatialDeliveries.spatialDeliveries.single,
    layerIds: {emptyId},
  );
  final query = sparseRuntimeCurrentHitQuery(root);
  expect(query.candidateIds, [CanvasElementId('populated-element')]);
  expect(query.candidateStructuralRevisions, {beforeRevision + 1});
}

void _expectSameIndexEmptyLayerRecreationIsSilent(
  CanvasDocument document, {
  required bool materialize,
}) {
  final spatialDeliveries = SparseRuntimeSpatialDeliveryRecorder();
  final root = sparseRuntimeRootWithCommittedDocumentSeed(
    document,
    spatialDeliveryRecorder: spatialDeliveries,
  );
  final emptyId = CanvasLayerId('empty');
  final beforeDocumentRevision = root.state.value.revisions.document;
  var statePublications = 0;
  var frameHandleEnumerations = 0;
  root.state.addListener(() => statePublications += 1);

  observeSparseRuntimeFrameHandleEnumerations(
    () => frameHandleEnumerations += 1,
    () => root.edits.edit((edit) {
      if (materialize) {
        edit.readDraftDocument();
      }
      expect(edit.removeEmptyLayer(emptyId), isTrue);
      expect(edit.ensureLayer(emptyId, index: 1), isTrue);
    }),
  );

  expect(root.state.value.revisions.document, beforeDocumentRevision);
  expect(statePublications, 0);
  expect(spatialDeliveries.spatialDeliveries, isEmpty);
  expect(frameHandleEnumerations, 0);
}

/// This materialized trace guards bounded Store classification when structural
/// layer work and content insertion share one accepted final candidate.
void _expectMaterializedMovedLayerAndContentAddUsesExactSpatialTouches(
  CanvasDocument document,
) {
  final spatialDeliveries = SparseRuntimeSpatialDeliveryRecorder();
  final root = sparseRuntimeRootWithCommittedDocumentSeed(
    document,
    spatialDeliveryRecorder: spatialDeliveries,
  );
  final emptyId = CanvasLayerId('empty');
  final beforeId = CanvasLayerId('before');
  final addedId = CanvasElementId('added-with-moved-layer');
  final beforeRevision = root.frameRevisions.structuralRevision;
  var frameHandleEnumerations = 0;

  observeSparseRuntimeFrameHandleEnumerations(
    () => frameHandleEnumerations += 1,
    () => _materializeMoveEmptyLayerAndAddContent(
      (callback) => root.edits.edit(callback),
      emptyId: emptyId,
      contentLayerId: beforeId,
      elementId: addedId,
    ),
  );

  expect(root.frameRevisions.structuralRevision, beforeRevision + 1);
  expect(frameHandleEnumerations, 0);
  expect(spatialDeliveries.spatialDeliveries, hasLength(1));
  _expectBoundedSpatialDelivery(
    spatialDeliveries.spatialDeliveries.single,
    layerIds: {emptyId, beforeId},
    elementIds: {addedId},
  );
  _expectCurrentAddedAndPopulatedQuery(
    sparseRuntimeCurrentHitQuery(root),
    addedId: addedId,
    structuralRevision: beforeRevision + 1,
  );
}

void _materializeMoveEmptyLayerAndAddContent(
  void Function(void Function(CanvasEdit edit)) runEdit, {
  required CanvasLayerId emptyId,
  required CanvasLayerId contentLayerId,
  required CanvasElementId elementId,
}) {
  runEdit((edit) {
    edit.readDraftDocument();
    expect(edit.removeEmptyLayer(emptyId), isTrue);
    expect(edit.ensureLayer(emptyId, index: 0), isTrue);
    edit.addElement(sparseRect(elementId.value), layerId: contentLayerId);
  });
}

void _expectBoundedSpatialDelivery(
  SparseRuntimeSpatialDelivery delivery, {
  required Set<CanvasLayerId> layerIds,
  Set<CanvasElementId> elementIds = const {},
}) {
  expect(delivery.layerIds, layerIds);
  expect(delivery.elementIds, elementIds);
  expect(delivery.backgroundLayerChanged, isFalse);
  expect(delivery.background, isFalse);
  expect(delivery.documentReplaced, isFalse);
}

void _expectCurrentAddedAndPopulatedQuery(
  SparseRuntimeSpatialQuery query, {
  required CanvasElementId addedId,
  required int structuralRevision,
}) {
  expect(
    query.candidateIds,
    unorderedEquals([addedId, CanvasElementId('populated-element')]),
  );
  expect(query.candidateStructuralRevisions, {structuralRevision});
}

void _expectReaddedElementTouchesBothContentLayerPlacements(
  CanvasDocument document,
) {
  for (final materialize in [false, true]) {
    final spatialDeliveries = SparseRuntimeSpatialDeliveryRecorder();
    final root = sparseRuntimeRootWithCommittedDocumentSeed(
      document,
      spatialDeliveryRecorder: spatialDeliveries,
    );
    final beforeRevision = root.frameRevisions.structuralRevision;
    var frameHandleEnumerations = 0;

    observeSparseRuntimeFrameHandleEnumerations(
      () => frameHandleEnumerations += 1,
      () => root.edits.edit(
        (edit) => _moveEmptyLayerAndReaddPopulatedElement(edit, materialize),
      ),
    );

    expect(frameHandleEnumerations, 0);
    expect(spatialDeliveries.spatialDeliveries, hasLength(1));
    expect(spatialDeliveries.spatialDeliveries.single.layerIds, {
      CanvasLayerId('empty'),
      CanvasLayerId('before'),
      CanvasLayerId('populated'),
    });
    final query = sparseRuntimeCurrentHitQuery(root);
    expect(query.candidateIds, [CanvasElementId('populated-element')]);
    expect(query.candidateStructuralRevisions, {beforeRevision + 1});
  }
}

void _moveEmptyLayerAndReaddPopulatedElement(
  CanvasEdit edit,
  bool materialize,
) {
  if (materialize) {
    edit.readDraftDocument();
  }
  expect(edit.removeEmptyLayer(CanvasLayerId('empty')), isTrue);
  expect(edit.ensureLayer(CanvasLayerId('empty'), index: 0), isTrue);
  expect(edit.removeElement(CanvasElementId('populated-element')), isTrue);
  edit.addElement(
    sparseRect('populated-element'),
    layerId: CanvasLayerId('before'),
    index: 0,
  );
}

void _expectSameLayerElementRecreationIsSilent(CanvasDocument document) {
  for (final materialize in [false, true]) {
    final spatialDeliveries = SparseRuntimeSpatialDeliveryRecorder();
    final root = sparseRuntimeRootWithCommittedDocumentSeed(
      document,
      spatialDeliveryRecorder: spatialDeliveries,
    );
    final beforeDocumentRevision = root.state.value.revisions.document;
    var statePublications = 0;
    var frameHandleEnumerations = 0;
    root.state.addListener(() => statePublications += 1);

    observeSparseRuntimeFrameHandleEnumerations(
      () => frameHandleEnumerations += 1,
      () => root.edits.edit((edit) {
        if (materialize) {
          edit.readDraftDocument();
        }
        expect(
          edit.removeElement(CanvasElementId('populated-element')),
          isTrue,
        );
        edit.addElement(
          sparseRect('populated-element'),
          layerId: CanvasLayerId('populated'),
        );
      }),
    );

    expect(root.state.value.revisions.document, beforeDocumentRevision);
    expect(statePublications, 0);
    expect(spatialDeliveries.spatialDeliveries, isEmpty);
    expect(frameHandleEnumerations, 0);
  }
}

CanvasDocument _emptyLayerRemovalDocument() {
  final emptyId = CanvasLayerId('empty');
  final populatedId = CanvasLayerId('populated');
  return CanvasDocument(
    resources: [sparseImageResource('retained-resource')],
    backgroundElements: [sparseRect('retained-background')],
    layers: [
      CanvasLayer(id: CanvasLayerId('before')),
      CanvasLayer(id: emptyId),
      CanvasLayer(id: populatedId, elements: [sparseRect('populated-element')]),
      CanvasLayer(id: CanvasLayerId('after')),
    ],
  );
}

// The parity trace keeps sparse, promotion, restoration, and selection intent
// in one observable callback so their shared final candidate remains legible.
// ignore: halstead-volume
void _expectSparseAndPromotedEmptyLayerRemoval(CanvasDocument document) {
  final emptyId = CanvasLayerId('empty');
  final populatedId = CanvasLayerId('populated');
  final sparse = sparseSessionForDocument(document);
  expect(sparse.removeEmptyLayer(CanvasLayerId('missing')), isFalse);
  expect(sparse.removeEmptyLayer(populatedId), isFalse);
  expect(sparse.removeEmptyLayer(emptyId), isTrue);
  expect(sparse.removeEmptyLayer(emptyId), isFalse);
  expect(sparse.revisionDelta.structural, isTrue);
  expect(sparse.revisionDelta.document, isTrue);
  final promoted = sparse.readDraftDocument();
  expect(promoted.layers.map((layer) => layer.id), [
    CanvasLayerId('before'),
    populatedId,
    CanvasLayerId('after'),
  ]);
  expect(promoted.backgroundElements.map((element) => element.id), [
    CanvasElementId('retained-background'),
  ]);
  expect(promoted.resources.map((resource) => resource.id), [
    CanvasResourceId('retained-resource'),
  ]);

  final restoring = sparseSessionForDocument(document);
  final restoredId = CanvasElementId('restored-content');
  expect(restoring.removeEmptyLayer(emptyId), isTrue);
  restoring.addElement(
    sparseRect(restoredId.value),
    layerId: CanvasLayerId('before'),
  );
  restoring.setSelection([restoredId]);
  expect(restoring.commitPlan.revisionDelta.document, isTrue);
  expect(restoring.pendingSelectionEffect?.elementIds, [restoredId]);
  final restored = restoring.readDraftDocument();
  expect(restored.layers.map((layer) => layer.id), [
    CanvasLayerId('before'),
    populatedId,
    CanvasLayerId('after'),
  ]);
  expect(restored.layers.first.elements.map((element) => element.id), [
    restoredId,
  ]);
}

void _expectMaterializedEmptyLayerRemoval(CanvasDocument document) {
  final emptyId = CanvasLayerId('empty');
  final populatedId = CanvasLayerId('populated');
  final materialized = DraftDocument(document);
  expect(materialized.removeEmptyLayer(populatedId), isFalse);
  expect(
    materialized.removeElement(CanvasElementId('populated-element')),
    isTrue,
  );
  expect(materialized.removeEmptyLayer(populatedId), isTrue);
  expect(materialized.removeEmptyLayer(populatedId), isFalse);
  expect(materialized.readDocument().layers.map((layer) => layer.id), [
    CanvasLayerId('before'),
    emptyId,
    CanvasLayerId('after'),
  ]);

  final removeEnsureRemove = DraftDocument(document);
  expect(removeEnsureRemove.removeEmptyLayer(emptyId), isTrue);
  expect(removeEnsureRemove.ensureLayer(emptyId, index: 1), isTrue);
  expect(removeEnsureRemove.removeEmptyLayer(emptyId), isTrue);
  expect(removeEnsureRemove.removeEmptyLayer(emptyId), isFalse);
}

// This one ordered trace intentionally keeps each placement transition beside
// its independent oracle observation; splitting it would obscure the invariant.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void materializedDraftIndexedStructureMatchesSequentialPlacementOracle() {
  final seed = baseSparseDocument();
  final draft = DraftDocument(
    seed,
    selectedElementIds: [
      CanvasElementId('content-a'),
      CanvasElementId('background-a'),
    ],
  );
  final oracle = SparseOrderOracle(seed);
  final touches = _DraftStructuralTouchOracle(
    selectedElementIds: {
      CanvasElementId('content-a'),
      CanvasElementId('background-a'),
    },
  );
  final layerFirst = CanvasLayerId('draft-layer-first');
  final layerLast = CanvasLayerId('draft-layer-last');
  final contentLayer = CanvasLayerId('layer-a');
  final trace = _DraftStructureTrace(draft, oracle, touches);

  final addedFirstLayer = draft.ensureLayer(layerFirst, index: -9);
  expect(addedFirstLayer, oracle.ensureLayer(layerFirst, -9));
  touches.ensureLayer(layerFirst, didChange: addedFirstLayer);
  _expectDraftStructureMatchesOracle(draft, oracle, touches);
  final addedLastLayer = draft.ensureLayer(layerLast, index: 999);
  expect(addedLastLayer, oracle.ensureLayer(layerLast, 999));
  touches.ensureLayer(layerLast, didChange: addedLastLayer);
  _expectDraftStructureMatchesOracle(draft, oracle, touches);
  final addedExistingLayer = draft.ensureLayer(layerFirst, index: 0);
  expect(addedExistingLayer, oracle.ensureLayer(layerFirst, 0));
  touches.ensureLayer(layerFirst, didChange: addedExistingLayer);
  _expectDraftStructureMatchesOracle(draft, oracle, touches);

  _addDraftContentAt(trace, 'draft-content-end', contentLayer, null);
  _addDraftContentAt(trace, 'draft-content-front', contentLayer, -4);
  _addDraftContentAt(trace, 'draft-content-middle-a', contentLayer, 1);
  _addDraftContentAt(trace, 'draft-content-middle-b', contentLayer, 1);
  _addDraftContentAt(trace, 'draft-content-last', contentLayer, 999);
  _addDraftBackgroundAt(trace, 'draft-background-end', null);
  _addDraftBackgroundAt(trace, 'draft-background-front', -1);
  _addDraftBackgroundAt(trace, 'draft-background-middle-a', 1);
  _addDraftBackgroundAt(trace, 'draft-background-middle-b', 1);
  _addDraftBackgroundAt(trace, 'draft-background-last', 999);

  final updated = draft.updateElement(
    CanvasRectElementUpdate(
      id: CanvasElementId('content-a'),
      fillColor: const CanvasFieldSet(Color(0xFF335577)),
    ),
  );
  expect(updated, isTrue);
  touches.update(CanvasElementId('content-a'), didChange: updated);
  _expectDraftStructureMatchesOracle(draft, oracle, touches);

  final movedContentId = CanvasElementId('content-a');
  final removedContent = draft.removeElement(movedContentId);
  expect(removedContent, oracle.remove(movedContentId));
  touches.remove(movedContentId, didChange: removedContent);
  _expectDraftStructureMatchesOracle(draft, oracle, touches);
  draft.addBackgroundElement(sparseRect('content-a'), index: 0);
  oracle.addBackground(movedContentId, 0);
  touches.addBackground(movedContentId);
  _expectDraftStructureMatchesOracle(draft, oracle, touches);

  final movedBackgroundId = CanvasElementId('background-a');
  final removedBackground = draft.removeElement(movedBackgroundId);
  expect(removedBackground, oracle.remove(movedBackgroundId));
  touches.remove(movedBackgroundId, didChange: removedBackground);
  _expectDraftStructureMatchesOracle(draft, oracle, touches);
  draft.addElement(sparseRect('background-a'), layerId: contentLayer, index: 0);
  oracle.addContent(movedBackgroundId, contentLayer, 0);
  touches.addContent(movedBackgroundId);
  _expectDraftStructureMatchesOracle(draft, oracle, touches);

  final clear = draft.clearContent(removeUnusedResources: false);
  final expectedRemoved = oracle.clearContent();
  expect(clear.removedElementIds, expectedRemoved);
  expect(clear.didClearContent, isTrue);
  touches.clear(expectedRemoved);
  _expectDraftStructureMatchesOracle(draft, oracle, touches);

  _addDraftContentAt(trace, 'draft-content-after-clear', contentLayer, 0);
}

final class _DraftStructureTrace {
  const _DraftStructureTrace(this.draft, this.oracle, this.touches);

  final DraftDocument draft;
  final SparseOrderOracle oracle;
  final _DraftStructuralTouchOracle touches;
}

void _addDraftContentAt(
  _DraftStructureTrace trace,
  String id,
  CanvasLayerId layerId,
  int? index,
) {
  final element = sparseRect(id);
  expect(
    trace.draft.addElement(element, layerId: layerId, index: index),
    element.id,
  );
  trace.oracle.addContent(element.id, layerId, index);
  trace.touches.addContent(element.id);
  _expectDraftStructureMatchesOracle(trace.draft, trace.oracle, trace.touches);
}

void _addDraftBackgroundAt(_DraftStructureTrace trace, String id, int? index) {
  final element = sparseRect(id);
  expect(trace.draft.addBackgroundElement(element, index: index), element.id);
  trace.oracle.addBackground(element.id, index);
  trace.touches.addBackground(element.id);
  _expectDraftStructureMatchesOracle(trace.draft, trace.oracle, trace.touches);
}

void _expectDraftStructureMatchesOracle(
  DraftDocument draft,
  SparseOrderOracle oracle,
  _DraftStructuralTouchOracle touches,
) {
  final document = draft.readDocument();
  _expectDocumentStructureMatchesOracle(document, oracle);
  expect(draft.summary.elementCount, _oracleElementCount(oracle));
  expect(draft.summary.layerCount, oracle.layerIds.length);
  touches.expectMatches(draft.touchedSet);
}

/// This tracks only public touched facts alongside the independent placement
/// oracle; it does not model any Draft backing or order implementation.
final class _DraftStructuralTouchOracle {
  _DraftStructuralTouchOracle({
    required Set<CanvasElementId> selectedElementIds,
  }) : _selectedElementIds = selectedElementIds;

  final Set<CanvasElementId> _selectedElementIds;
  final Set<CanvasLayerId> _layerIds = {};
  final Set<CanvasElementId> _addedElementIds = {};
  final Set<CanvasElementId> _updatedElementIds = {};
  final Set<CanvasElementId> _removedElementIds = {};
  var _backgroundLayerChanged = false;
  var _selectionChanged = false;

  void ensureLayer(CanvasLayerId id, {required bool didChange}) {
    if (didChange) {
      _layerIds.add(id);
    }
  }

  void addContent(CanvasElementId id) {
    _addedElementIds.add(id);
  }

  void addBackground(CanvasElementId id) {
    _addedElementIds.add(id);
    _backgroundLayerChanged = true;
  }

  void update(CanvasElementId id, {required bool didChange}) {
    if (didChange) {
      _updatedElementIds.add(id);
    }
  }

  void remove(CanvasElementId id, {required bool didChange}) {
    if (!didChange) {
      return;
    }
    _removedElementIds.add(id);
    _selectionChanged |= _selectedElementIds.contains(id);
  }

  void clear(Iterable<CanvasElementId> ids) {
    for (final id in ids) {
      remove(id, didChange: true);
    }
  }

  void expectMatches(TouchedSet touched) {
    expect(touched.layerIds, _layerIds);
    expect(touched.addedElementIds, _addedElementIds);
    expect(touched.updatedElementIds, _updatedElementIds);
    expect(touched.removedElementIds, _removedElementIds);
    expect(
      touched.backgroundLayerChanged,
      _backgroundLayerChanged,
      reason: 'background-layer touched fact',
    );
    expect(
      touched.selection,
      _selectionChanged,
      reason: 'selection touched fact',
    );
  }
}

// Each prefix promotes an independently created sparse session. The trace is
// declarative and applies public operations to the independent list/map oracle.
void promotedDraftStructuralPrefixesMatchSequentialOracle() {
  const actions = _PromotedStructureAction.values;
  final selectedIds = {
    CanvasElementId('content-a'),
    CanvasElementId('background-a'),
  };

  for (var length = 1; length <= actions.length; length += 1) {
    final seed = baseSparseDocument();
    final session = sparseSessionForDocument(
      seed,
      selectedElementIds: selectedIds,
    );
    final oracle = SparseOrderOracle(seed);
    final touches = _DraftStructuralTouchOracle(
      selectedElementIds: selectedIds,
    );

    for (final action in actions.take(length)) {
      _applyPromotedStructureAction(action, session, oracle, touches);
    }

    final document = session.readDraftDocument();
    _expectDocumentStructureMatchesOracle(document, oracle);
    expect(session.draftSummary.elementCount, _oracleElementCount(oracle));
    expect(session.draftSummary.layerCount, oracle.layerIds.length);
    touches.expectMatches(session.touchedSet);
  }
}

enum _PromotedStructureAction {
  ensureLayer,
  addContentEnd,
  addContentFront,
  addBackground,
  updateContent,
  removeContent,
  readdContentAsBackground,
  removeBackground,
  readdBackgroundAsContent,
  clearContent,
}

// The one switch is the public-operation trace consumed by every prefix; split
// action forwarding would duplicate its oracle transition and obscure the trace.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _applyPromotedStructureAction(
  _PromotedStructureAction action,
  EditSession session,
  SparseOrderOracle oracle,
  _DraftStructuralTouchOracle touches,
) {
  final layerId = CanvasLayerId('layer-a');
  final contentId = CanvasElementId('content-a');
  final backgroundId = CanvasElementId('background-a');
  switch (action) {
    case _PromotedStructureAction.ensureLayer:
      final id = CanvasLayerId('prefix-layer');
      final didChange = session.ensureLayer(id, index: -3);
      expect(didChange, oracle.ensureLayer(id, -3));
      touches.ensureLayer(id, didChange: didChange);
    case _PromotedStructureAction.addContentEnd:
      final element = sparseRect('prefix-content-end');
      expect(session.addElement(element, layerId: layerId), element.id);
      oracle.addContent(element.id, layerId, null);
      touches.addContent(element.id);
    case _PromotedStructureAction.addContentFront:
      final element = sparseRect('prefix-content-front');
      expect(
        session.addElement(element, layerId: layerId, index: -8),
        element.id,
      );
      oracle.addContent(element.id, layerId, -8);
      touches.addContent(element.id);
    case _PromotedStructureAction.addBackground:
      final element = sparseRect('prefix-background');
      expect(session.addBackgroundElement(element, index: 0), element.id);
      oracle.addBackground(element.id, 0);
      touches.addBackground(element.id);
    case _PromotedStructureAction.updateContent:
      expect(
        session.updateElement(
          CanvasRectElementUpdate(
            id: contentId,
            fillColor: const CanvasFieldSet(Color(0xFF123456)),
          ),
        ),
        isTrue,
      );
      touches.update(contentId, didChange: true);
    case _PromotedStructureAction.removeContent:
      final didChange = session.removeElement(contentId);
      expect(didChange, oracle.remove(contentId));
      touches.remove(contentId, didChange: didChange);
    case _PromotedStructureAction.readdContentAsBackground:
      expect(
        session.addBackgroundElement(sparseRect('content-a'), index: 0),
        contentId,
      );
      oracle.addBackground(contentId, 0);
      touches.addBackground(contentId);
    case _PromotedStructureAction.removeBackground:
      final didChange = session.removeElement(backgroundId);
      expect(didChange, oracle.remove(backgroundId));
      touches.remove(backgroundId, didChange: didChange);
    case _PromotedStructureAction.readdBackgroundAsContent:
      expect(
        session.addElement(
          sparseRect('background-a'),
          layerId: layerId,
          index: 0,
        ),
        backgroundId,
      );
      oracle.addContent(backgroundId, layerId, 0);
      touches.addContent(backgroundId);
    case _PromotedStructureAction.clearContent:
      final result = session.clearContent(removeUnusedResources: false);
      final removedIds = oracle.clearContent();
      expect(result.removedElementIds, removedIds);
      expect(result.removedResourceIds, isEmpty);
      touches.clear(removedIds);
  }
}

void _expectDocumentStructureMatchesOracle(
  CanvasDocument document,
  SparseOrderOracle oracle,
) {
  expect(
    document.backgroundElements.map((element) => element.id),
    oracle.backgroundIds,
  );
  expect(document.layers.map((layer) => layer.id), oracle.layerIds);
  for (final layer in document.layers) {
    expect(
      layer.elements.map((element) => element.id),
      oracle.contentIds(layer.id),
    );
  }
}

int _oracleElementCount(SparseOrderOracle oracle) {
  return oracle.backgroundIds.length +
      oracle.layerIds.fold<int>(
        0,
        (count, layerId) => count + oracle.contentIds(layerId).length,
      );
}

// One supported-size trace exercises direct map reads, both order families,
// rank mutations, clear, compensation, and repeated public materialization.
// It counts owner phases and sequence work; it intentionally makes no timing
// or private-node-shape claim.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _materializedDraftStructuralWorkRemainsBounded() {
  const elementCount = 200000;
  const initialLayerCount = 4095;
  const orderCountAfterMutation = 4098;
  const indexedMutationCount = 9;
  final maxNodeVisitsPerMutation = 2 * _binaryLogCeiling(elementCount + 4);
  final constructionEvents = <DraftStructureWorkEvent>[];
  final directLookupEvents = <DraftStructureWorkEvent>[];
  final clearEvents = <DraftStructureWorkEvent>[];
  final materializationEvents = <DraftStructureWorkEvent>[];
  final sequenceEvents = <IndexedOrderSequenceWorkEvent>[];
  var phase = _DraftStructureWorkPhase.construction;

  observeDraftStructureWork(
    (event) {
      switch (phase) {
        case _DraftStructureWorkPhase.construction:
          constructionEvents.add(event);
        case _DraftStructureWorkPhase.directLookup:
          directLookupEvents.add(event);
        case _DraftStructureWorkPhase.clear:
          clearEvents.add(event);
        case _DraftStructureWorkPhase.materialization:
          materializationEvents.add(event);
      }
    },
    () => IndexedOrderSequence.observeWork(sequenceEvents.add, () {
      final draft = DraftDocument(
        supportedSizeDraftDocument(
          elementCount: elementCount,
          layerCount: initialLayerCount,
        ),
      );
      phase = _DraftStructureWorkPhase.directLookup;

      expect(
        draft.ensureLayer(CanvasLayerId('draft-new-layer'), index: 0),
        isTrue,
      );
      expect(draft.ensureLayer(CanvasLayerId('layer-4094')), isFalse);
      draft.addBackgroundElement(
        sparseRect('draft-background-front'),
        index: -1,
      );
      draft.addBackgroundElement(
        sparseRect('draft-background-middle'),
        index: 0,
      );
      draft.addBackgroundElement(
        sparseRect('draft-background-last'),
        index: 999999,
      );
      draft.addElement(
        sparseRect('draft-content-front'),
        layerId: CanvasLayerId('layer-0'),
        index: -1,
      );
      draft.addElement(
        sparseRect('draft-content-middle'),
        layerId: CanvasLayerId('layer-0'),
        index: elementCount ~/ 2,
      );
      draft.addElement(
        sparseRect('draft-content-last'),
        layerId: CanvasLayerId('layer-0'),
        index: 999999,
      );
      draft.addElement(sparseRect('draft-content-implicit'), index: 0);
      expect(
        draft.updateElement(
          CanvasRectElementUpdate(
            id: CanvasElementId('element-100000'),
            fillColor: const CanvasFieldSet(Color(0xFF113355)),
          ),
        ),
        isTrue,
      );
      expect(draft.removeElement(CanvasElementId('element-100000')), isTrue);
      expect(draft.removeElement(CanvasElementId('missing-element')), isFalse);
      draft.addElement(
        sparseRect('element-100000'),
        layerId: CanvasLayerId('layer-0'),
        index: elementCount ~/ 2,
      );
      phase = _DraftStructureWorkPhase.clear;
      expect(
        draft.clearContent(removeUnusedResources: false).removedElementIds,
        hasLength(elementCount + 4),
      );
      phase = _DraftStructureWorkPhase.materialization;
      expect(draft.readDocument().backgroundElements, hasLength(3));
      expect(draft.readDocument().layers, hasLength(4096));
    }),
  );

  expect(
    _draftStructureEventCounts(
      constructionEvents,
      DraftStructureWorkKind.orderOpen,
    ),
    {
      DraftStructureOrderKind.layer: 1,
      DraftStructureOrderKind.background: 1,
      DraftStructureOrderKind.content: initialLayerCount,
    },
  );
  expect(
    _draftStructureEventCounts(
      directLookupEvents,
      DraftStructureWorkKind.orderOpen,
    ),
    {
      DraftStructureOrderKind.layer: 0,
      DraftStructureOrderKind.background: 0,
      DraftStructureOrderKind.content: 1,
    },
  );
  expect(
    draftStructureEventCount(
      constructionEvents,
      DraftStructureWorkKind.constructionLayerVisit,
    ),
    initialLayerCount,
  );
  expect(
    draftStructureEventCount(
      constructionEvents,
      DraftStructureWorkKind.constructionElementVisit,
    ),
    elementCount,
  );
  expect(
    _draftMapEventCount(
      directLookupEvents,
      DraftStructureMapKind.elementRows,
      DraftStructureMapOperation.contains,
    ),
    inInclusiveRange(1, 10),
  );
  expect(
    _draftMapEventCount(
      directLookupEvents,
      DraftStructureMapKind.layerRows,
      DraftStructureMapOperation.contains,
    ),
    inInclusiveRange(1, 8),
  );
  expect(
    _draftMapEventCount(
      directLookupEvents,
      DraftStructureMapKind.elementRows,
      DraftStructureMapOperation.read,
    ),
    inInclusiveRange(1, 4),
  );
  expect(
    _draftMapEventCount(
      directLookupEvents,
      DraftStructureMapKind.placements,
      DraftStructureMapOperation.read,
    ),
    inInclusiveRange(1, 3),
  );
  expect(
    _draftMapEventCount(
      directLookupEvents,
      DraftStructureMapKind.contentOrders,
      DraftStructureMapOperation.read,
    ),
    inInclusiveRange(1, 8),
  );
  expect(
    _draftMapEventCount(
      clearEvents,
      DraftStructureMapKind.contentOrders,
      DraftStructureMapOperation.read,
    ),
    inInclusiveRange(1, 4096),
  );
  expect(
    _draftMapEventCount(
      clearEvents,
      DraftStructureMapKind.elementRows,
      DraftStructureMapOperation.remove,
    ),
    inInclusiveRange(1, elementCount + 4),
  );
  expect(
    _draftMapEventCount(
      clearEvents,
      DraftStructureMapKind.placements,
      DraftStructureMapOperation.remove,
    ),
    inInclusiveRange(1, elementCount + 4),
  );
  expect(
    _draftMapEventCount(
      materializationEvents,
      DraftStructureMapKind.layerRows,
      DraftStructureMapOperation.read,
    ),
    inInclusiveRange(1, 2 * 4096),
  );
  expect(
    _draftMapEventCount(
      materializationEvents,
      DraftStructureMapKind.contentOrders,
      DraftStructureMapOperation.read,
    ),
    inInclusiveRange(1, 2 * 4096),
  );
  expect(
    _draftMapEventCount(
      materializationEvents,
      DraftStructureMapKind.elementRows,
      DraftStructureMapOperation.read,
    ),
    inInclusiveRange(1, 6),
  );
  expect(
    draftStructureEventCount(
      materializationEvents,
      DraftStructureWorkKind.materialization,
    ),
    2 * orderCountAfterMutation,
  );
  expect(
    indexedEventCount(sequenceEvents, IndexedOrderSequenceWorkEvent.buildOpen),
    orderCountAfterMutation,
  );
  expect(
    indexedEventCount(
      sequenceEvents,
      IndexedOrderSequenceWorkEvent.buildInputVisit,
    ),
    elementCount + initialLayerCount,
  );
  expect(
    indexedEventCount(
      sequenceEvents,
      IndexedOrderSequenceWorkEvent.insertNodeVisit,
    ),
    lessThanOrEqualTo(indexedMutationCount * maxNodeVisitsPerMutation),
  );
  expect(
    indexedEventCount(
      sequenceEvents,
      IndexedOrderSequenceWorkEvent.removeNodeVisit,
    ),
    lessThanOrEqualTo(maxNodeVisitsPerMutation),
  );
  expect(
    indexedEventCount(
      sequenceEvents,
      IndexedOrderSequenceWorkEvent.finalFlattenVisit,
    ),
    0,
  );
  expect(
    indexedEventCount(
      sequenceEvents,
      IndexedOrderSequenceWorkEvent.finalFlattenPublication,
    ),
    0,
  );
  expect(
    indexedEventCount(
      sequenceEvents,
      IndexedOrderSequenceWorkEvent.orderedIterationVisit,
    ),
    elementCount + 4 + (3 * 4096) + 6,
  );
}

Map<DraftStructureOrderKind, int> _draftStructureEventCounts(
  Iterable<DraftStructureWorkEvent> events,
  DraftStructureWorkKind kind,
) {
  return {
    for (final order in DraftStructureOrderKind.values)
      order: events
          .where((event) => event.kind == kind && event.order == order)
          .length,
  };
}

int draftStructureEventCount(
  Iterable<DraftStructureWorkEvent> events,
  DraftStructureWorkKind kind,
) => events.where((event) => event.kind == kind).length;

int _draftMapEventCount(
  Iterable<DraftStructureWorkEvent> events,
  DraftStructureMapKind mapKind,
  DraftStructureMapOperation mapOperation,
) => events
    .where(
      (event) => event.mapKind == mapKind && event.mapOperation == mapOperation,
    )
    .length;

enum _DraftStructureWorkPhase {
  construction,
  directLookup,
  clear,
  materialization,
}

int indexedEventCount(
  Iterable<IndexedOrderSequenceWorkEvent> events,
  IndexedOrderSequenceWorkEvent kind,
) => events.where((event) => event == kind).length;

int _binaryLogCeiling(int value) {
  var power = 1;
  var exponent = 0;
  while (power < value) {
    power <<= 1;
    exponent += 1;
  }
  return exponent;
}

// This literal list/map oracle is deliberately independent from indexed orders:
// it applies the raw public indices sequentially and exposes clear order before
// the later promoted document observes the same current placement.
// One trace keeps every transition and its intermediate clear witness adjacent.
// ignore: halstead-volume, source-lines-of-code
void _sparseIndexedOrdersMatchSequentialPlacementOracle() {
  final seed = baseSparseDocument();
  final session = sparseSessionForDocument(seed);
  final oracle = SparseOrderOracle(seed);
  final layerFirst = CanvasLayerId('layer-first');
  final layerLast = CanvasLayerId('layer-last');
  final contentLayer = CanvasLayerId('layer-a');

  expect(
    session.ensureLayer(layerFirst, index: -9),
    oracle.ensureLayer(layerFirst, -9),
  );
  expect(
    session.ensureLayer(layerLast, index: 999),
    oracle.ensureLayer(layerLast, 999),
  );
  expect(
    session.ensureLayer(layerFirst, index: 0),
    oracle.ensureLayer(layerFirst, 0),
  );
  _addContentAt(session, oracle, 'content-end', contentLayer, null);
  _addContentAt(session, oracle, 'content-front', contentLayer, -4);
  _addContentAt(session, oracle, 'content-middle-a', contentLayer, 1);
  _addContentAt(session, oracle, 'content-middle-b', contentLayer, 1);
  _addContentAt(session, oracle, 'content-last', contentLayer, 999);
  _addBackgroundAt(session, oracle, 'background-end', null);
  _addBackgroundAt(session, oracle, 'background-front', -1);
  _addBackgroundAt(session, oracle, 'background-middle-a', 1);
  _addBackgroundAt(session, oracle, 'background-middle-b', 1);
  _addBackgroundAt(session, oracle, 'background-last', 999);

  final movedId = CanvasElementId('content-a');
  expect(session.removeElement(movedId), oracle.remove(movedId));
  session.addBackgroundElement(sparseRect('content-a'), index: 0);
  oracle.addBackground(movedId, 0);
  final movedBackgroundId = CanvasElementId('background-a');
  expect(
    session.removeElement(movedBackgroundId),
    oracle.remove(movedBackgroundId),
  );
  _addContentAt(session, oracle, 'background-a', contentLayer, 0);

  final clear = session.clearContent();
  expect(clear.removedElementIds, oracle.clearContent());
  _addContentAt(session, oracle, 'content-after-clear', contentLayer, 0);

  final document = session.readDraftDocument();
  expect(
    document.backgroundElements.map((element) => element.id),
    oracle.backgroundIds,
  );
  expect(document.layers.map((layer) => layer.id), oracle.layerIds);
  for (final layer in document.layers) {
    expect(
      layer.elements.map((element) => element.id),
      oracle.contentIds(layer.id),
    );
  }
}

// The helper keeps the public call and independent oracle transition paired.
// ignore: number-of-parameters
void _addContentAt(
  EditSession session,
  SparseOrderOracle oracle,
  String id,
  CanvasLayerId layerId,
  int? index,
) {
  final element = sparseRect(id);
  expect(
    session.addElement(element, layerId: layerId, index: index),
    element.id,
  );
  oracle.addContent(element.id, layerId, index);
}

void _addBackgroundAt(
  EditSession session,
  SparseOrderOracle oracle,
  String id,
  int? index,
) {
  final element = sparseRect(id);
  expect(session.addBackgroundElement(element, index: index), element.id);
  oracle.addBackground(element.id, index);
}

// The supported-size trace keeps setup, observed owner events, and bounds in
// one place so no aggregate-only proxy can hide a repeated order open or scan.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _sparseIndexedOrdersHaveBoundedOwnerAttributedWork() {
  const elementCount = 200000;
  const layerCount = 4096;
  const indexedMutationCount = 7;
  final maxNodeVisitsPerMutation = 2 * _binaryLogCeiling(elementCount + 4);
  final facts = SupportedSizeSparseFacts(
    elementCount: elementCount,
    layerCount: layerCount,
  );
  final session = EditSession.sparse(
    readFacts: () => facts,
    promoteDraft: (_) => baseSparseDraft(),
    readSelectedElementIds: () => const {},
  );
  final structureEvents = <SparseEditStructureWorkEvent>[];
  final sequenceEvents = <IndexedOrderSequenceWorkEvent>[];

  observeSparseEditStructureWork(
    structureEvents.add,
    () => IndexedOrderSequence.observeWork(sequenceEvents.add, () {
      expect(session.ensureLayer(CanvasLayerId('layer-new'), index: 0), isTrue);
      session.addBackgroundElement(sparseRect('background-front'), index: -1);
      session.addBackgroundElement(sparseRect('background-middle'), index: 0);
      session.addBackgroundElement(
        sparseRect('background-last'),
        index: 999999,
      );
      session.addElement(
        sparseRect('content-front'),
        layerId: CanvasLayerId('layer-0'),
        index: -1,
      );
      session.addElement(
        sparseRect('content-middle'),
        layerId: CanvasLayerId('layer-0'),
        index: elementCount ~/ 2,
      );
      session.addElement(
        sparseRect('content-last'),
        layerId: CanvasLayerId('layer-0'),
        index: 999999,
      );
      expect(session.removeElement(CanvasElementId('element-100000')), isTrue);
      expect(
        session.clearContent().removedElementIds,
        hasLength(elementCount + 2),
      );
      session.close();
    }),
  );

  final opens = _structureEventCounts(
    structureEvents,
    SparseEditStructureWorkKind.orderOpen,
  );
  final cleanup = _structureEventCounts(
    structureEvents,
    SparseEditStructureWorkKind.cleanup,
  );
  expect(opens[SparseEditStructureOrderKind.layer], 1);
  expect(opens[SparseEditStructureOrderKind.background], 1);
  expect(opens[SparseEditStructureOrderKind.content], layerCount + 1);
  expect(cleanup, opens);
  expect(
    _structureEventCount(
      structureEvents,
      SparseEditStructureWorkKind.committedLocationRead,
    ),
    1,
  );
  expect(
    _structureEventCount(
      structureEvents,
      SparseEditStructureWorkKind.currentLocationRead,
    ),
    1,
  );
  expect(facts.locationReadCount, 1);
  expect(
    indexedEventCount(sequenceEvents, IndexedOrderSequenceWorkEvent.buildOpen),
    layerCount + 3,
  );
  expect(
    indexedEventCount(
      sequenceEvents,
      IndexedOrderSequenceWorkEvent.buildInputVisit,
    ),
    elementCount + layerCount,
  );
  expect(
    indexedEventCount(
      sequenceEvents,
      IndexedOrderSequenceWorkEvent.insertNodeVisit,
    ),
    lessThanOrEqualTo(indexedMutationCount * maxNodeVisitsPerMutation),
  );
  expect(
    indexedEventCount(
      sequenceEvents,
      IndexedOrderSequenceWorkEvent.removeNodeVisit,
    ),
    lessThanOrEqualTo(maxNodeVisitsPerMutation),
  );
  expect(
    indexedEventCount(
      sequenceEvents,
      IndexedOrderSequenceWorkEvent.finalFlattenVisit,
    ),
    0,
  );
  expect(
    indexedEventCount(
      sequenceEvents,
      IndexedOrderSequenceWorkEvent.orderedIterationVisit,
    ),
    elementCount + layerCount + 3,
  );
  expect(
    indexedEventCount(sequenceEvents, IndexedOrderSequenceWorkEvent.discard),
    layerCount + 3,
  );

  final earlyFacts = SupportedSizeSparseFacts(
    elementCount: elementCount,
    layerCount: layerCount,
  );
  final earlySession = EditSession.sparse(
    readFacts: () => earlyFacts,
    promoteDraft: (_) => baseSparseDraft(),
    readSelectedElementIds: () => const {},
  );
  final earlyStructureEvents = <SparseEditStructureWorkEvent>[];
  final earlySequenceEvents = <IndexedOrderSequenceWorkEvent>[];
  observeSparseEditStructureWork(
    earlyStructureEvents.add,
    () => IndexedOrderSequence.observeWork(earlySequenceEvents.add, () {
      expect(
        earlySession.clearContent().removedElementIds,
        hasLength(elementCount),
      );
      earlySession.close();
    }),
  );
  final earlyOpens = _structureEventCounts(
    earlyStructureEvents,
    SparseEditStructureWorkKind.orderOpen,
  );
  expect(earlyOpens[SparseEditStructureOrderKind.layer], 1);
  expect(earlyOpens[SparseEditStructureOrderKind.background], 0);
  expect(earlyOpens[SparseEditStructureOrderKind.content], layerCount);
  expect(
    _structureEventCounts(
      earlyStructureEvents,
      SparseEditStructureWorkKind.cleanup,
    ),
    earlyOpens,
  );
  expect(
    indexedEventCount(
      earlySequenceEvents,
      IndexedOrderSequenceWorkEvent.buildOpen,
    ),
    layerCount + 1,
  );
  expect(
    indexedEventCount(
      earlySequenceEvents,
      IndexedOrderSequenceWorkEvent.buildInputVisit,
    ),
    elementCount + layerCount,
  );
  expect(
    indexedEventCount(
      earlySequenceEvents,
      IndexedOrderSequenceWorkEvent.orderedIterationVisit,
    ),
    elementCount + layerCount,
  );
  expect(
    indexedEventCount(
      earlySequenceEvents,
      IndexedOrderSequenceWorkEvent.discard,
    ),
    layerCount + 1,
  );
}

// The promotion seam, opened owners, and cleanup observations stay adjacent so
// a close-path cleanup cannot accidentally satisfy this independent witness.
// ignore: halstead-volume, source-lines-of-code
void _sparsePromotionDiscardsOpenedStructuralOrdersOnce() {
  final session = sparseSessionForDocument(baseSparseDocument());
  final structureEvents = <SparseEditStructureWorkEvent>[];
  final sequenceEvents = <IndexedOrderSequenceWorkEvent>[];

  observeSparseEditStructureWork(
    structureEvents.add,
    () => IndexedOrderSequence.observeWork(sequenceEvents.add, () {
      expect(session.ensureLayer(CanvasLayerId('opened-layer')), isTrue);
      session.addBackgroundElement(sparseRect('opened-background'));
      session.addElement(
        sparseRect('opened-content'),
        layerId: CanvasLayerId('layer-a'),
      );

      final document = session.readDraftDocument();

      expect(document.backgroundElements.map((element) => element.id), [
        CanvasElementId('background-a'),
        CanvasElementId('opened-background'),
      ]);
      expect(document.layers.first.elements.map((element) => element.id), [
        CanvasElementId('content-a'),
        CanvasElementId('opened-content'),
      ]);
    }),
  );

  final opens = _structureEventCounts(
    structureEvents,
    SparseEditStructureWorkKind.orderOpen,
  );
  expect(opens, {
    SparseEditStructureOrderKind.layer: 1,
    SparseEditStructureOrderKind.background: 1,
    SparseEditStructureOrderKind.content: 1,
  });
  expect(
    _structureEventCounts(structureEvents, SparseEditStructureWorkKind.cleanup),
    opens,
  );
  expect(
    indexedEventCount(sequenceEvents, IndexedOrderSequenceWorkEvent.discard),
    3,
  );
  expect(
    indexedEventCount(
      sequenceEvents,
      IndexedOrderSequenceWorkEvent.finalFlattenVisit,
    ),
    0,
  );
}

Map<SparseEditStructureOrderKind, int> _structureEventCounts(
  Iterable<SparseEditStructureWorkEvent> events,
  SparseEditStructureWorkKind kind,
) {
  return {
    for (final order in SparseEditStructureOrderKind.values)
      order: events
          .where((event) => event.kind == kind && event.order == order)
          .length,
  };
}

int _structureEventCount(
  Iterable<SparseEditStructureWorkEvent> events,
  SparseEditStructureWorkKind kind,
) => events.where((event) => event.kind == kind).length;

final class SparseOrderOracle {
  SparseOrderOracle(CanvasDocument seed)
    : _backgroundIds = [
        for (final element in seed.backgroundElements) element.id,
      ],
      _contentIdsByLayer = {} {
    for (final layer in seed.layers) {
      _contentIdsByLayer[layer.id] = [
        for (final element in layer.elements) element.id,
      ];
    }
    for (final id in _backgroundIds) {
      _locations[id] = null;
    }
    for (final entry in _contentIdsByLayer.entries) {
      for (final id in entry.value) {
        _locations[id] = entry.key;
      }
    }
  }

  final List<CanvasElementId> _backgroundIds;
  final Map<CanvasLayerId, List<CanvasElementId>> _contentIdsByLayer;
  final Map<CanvasElementId, CanvasLayerId?> _locations = {};

  Iterable<CanvasElementId> get backgroundIds => _backgroundIds;
  Iterable<CanvasLayerId> get layerIds => _contentIdsByLayer.keys;

  Iterable<CanvasElementId> contentIds(CanvasLayerId id) {
    return _contentIdsByLayer[id] ?? const <CanvasElementId>[];
  }

  bool ensureLayer(CanvasLayerId id, int? index) {
    if (_contentIdsByLayer.containsKey(id)) {
      return false;
    }
    final entries = _contentIdsByLayer.entries.toList(growable: false);
    _contentIdsByLayer.clear();
    final clamped = _clampOracleIndex(index, entries.length);
    for (var position = 0; position <= entries.length; position += 1) {
      if (position == clamped) {
        _contentIdsByLayer[id] = [];
      }
      if (position < entries.length) {
        final entry = entries[position];
        _contentIdsByLayer[entry.key] = entry.value;
      }
    }
    return true;
  }

  void addBackground(CanvasElementId id, int? index) {
    _backgroundIds.insert(_clampOracleIndex(index, _backgroundIds.length), id);
    _locations[id] = null;
  }

  void addContent(CanvasElementId id, CanvasLayerId layerId, int? index) {
    if (!_contentIdsByLayer.containsKey(layerId)) {
      ensureLayer(layerId, null);
    }
    final ids = _contentIdsByLayer[layerId]!;
    ids.insert(_clampOracleIndex(index, ids.length), id);
    _locations[id] = layerId;
  }

  bool remove(CanvasElementId id) {
    if (!_locations.containsKey(id)) {
      return false;
    }
    final layerId = _locations.remove(id);
    if (layerId == null) {
      _backgroundIds.remove(id);
    } else {
      _contentIdsByLayer[layerId]!.remove(id);
    }
    return true;
  }

  List<CanvasElementId> clearContent() {
    final removed = <CanvasElementId>[];
    for (final ids in _contentIdsByLayer.values) {
      removed.addAll(ids);
      for (final id in ids) {
        _locations.remove(id);
      }
      ids.clear();
    }
    return removed;
  }
}

int _clampOracleIndex(int? requested, int length) {
  if (requested == null || requested > length) {
    return length;
  }
  if (requested < 0) {
    return 0;
  }
  return requested;
}
