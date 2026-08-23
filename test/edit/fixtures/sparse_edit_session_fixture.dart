import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/edit/draft_document.dart';
import 'package:iwb_canvas_engine/src/edit/edit_session.dart';
import 'package:iwb_canvas_engine/src/store/resource_table.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';

import '../../support/document_store_with_document.dart';

void main() {
  group('sparse edit session seam', () {
    _registerSparseSummaryTests();
    _registerSparsePromotionTests();
    test(
      'stale sparse handles reject every public entry point',
      () => expect(_staleSparseHandleRejected, returnsNormally),
    );
    test(
      'sparse mutations preserve no-op and validation semantics',
      () => expect(_sparseMutationsPreserveNoOpAndValidation, returnsNormally),
    );
    test(
      'sparse resource references follow accepted element overlay',
      () =>
          expect(_sparseResourceReferencesUseAcceptedOverlay, returnsNormally),
    );
    test(
      'sparse clear touches background layer only for background removals',
      () => expect(
        _sparseClearTouchesBackgroundLayerOnlyForBackgroundRemovals,
        returnsNormally,
      ),
    );
    test(
      'sparse clear retains background image and vector resources',
      () => expect(
        _sparseClearRetainsBackgroundImageAndVectorResources,
        returnsNormally,
      ),
    );
    test(
      'sparse clear retains committed and local background resources',
      () => expect(
        _sparseClearRetainsCommittedAndLocalBackgroundResources,
        returnsNormally,
      ),
    );
    test(
      'promoted sparse clear keeps DraftDocument resource work bounded',
      () => expect(
        _promotedSparseClearKeepsDraftResourceWorkBounded,
        returnsNormally,
      ),
    );
    test(
      'sparse clear remains an ordered journal barrier',
      () => expect(_sparseClearRemainsAnOrderedJournalBarrier, returnsNormally),
    );
    test(
      'sparse clear reports indexed insertions in draft order',
      () => expect(
        _sparseClearReportsIndexedInsertionsInDraftOrder,
        returnsNormally,
      ),
    );
    test(
      'sparse remove touches background layer only for background removals',
      () => expect(
        _sparseRemoveTouchesBackgroundLayerOnlyForBackgroundRemovals,
        returnsNormally,
      ),
    );
  });
}

void _registerSparseSummaryTests() {
  test(
    'draftSummary tracks sparse mutations without materialization',
    () => expect(_draftSummaryTracksSparseMutations, returnsNormally),
  );
  test(
    'draftSummary opens from committed summary without id enumeration',
    () => expect(
      _draftSummaryOpensWithoutCommittedIdEnumeration,
      returnsNormally,
    ),
  );
}

void _registerSparsePromotionTests() {
  test(
    'promotion applies the sole sparse DTO journal in order without extra work phases',
    () => expect(_promotionAppliesTheSoleDtoJournal, returnsNormally),
  );
  test(
    'promotion applies sparse clear content and unused resource removal',
    () => expect(_promotionAppliesSparseClearContent, returnsNormally),
  );
  test(
    'readDraftDocument promotes and replays prior sparse mutations',
    () => expect(_readDraftDocumentPromotesAndReplays, returnsNormally),
  );
  test(
    'mutations after promotion use materialized fallback',
    () => expect(
      _mutationsAfterPromotionUseMaterializedFallback,
      returnsNormally,
    ),
  );
  test(
    'replaceDraftDocument promotes to materialized replacement fallback',
    () => expect(_replaceDraftDocumentPromotes, returnsNormally),
  );
}

// The mixed trace stays with its independent Store snapshot so the witness
// directly connects each input mutation to the single promotion traversal.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _promotionAppliesTheSoleDtoJournal() {
  final session = _sparseSession(_baseDraft);

  expect(session.ensureLayer(CanvasLayerId('layer-added'), index: 0), isTrue);
  expect(session.ensureLayer(CanvasLayerId('layer-empty'), index: 1), isTrue);
  expect(session.ensureLayer(CanvasLayerId('layer-added'), index: 0), isFalse);
  expect(session.upsertResource(_resource('resource-a')), isFalse);
  session.setBackgroundColor(const Color(0xFFFFFFFF));
  session.addBackgroundElement(_rect('background-first'), index: 0);
  session.addBackgroundElement(_rect('background-second'), index: 0);
  session.addElement(
    _rect('content-first'),
    layerId: CanvasLayerId('layer-added'),
    index: 0,
  );
  session.addElement(
    _rect('content-second'),
    layerId: CanvasLayerId('layer-added'),
    index: 0,
  );
  expect(
    session.updateElement(
      CanvasRectElementUpdate(
        id: CanvasElementId('background-first'),
        fillColor: const CanvasFieldSet(Color(0xFF00FF00)),
      ),
    ),
    isTrue,
  );
  expect(session.removeElement(CanvasElementId('background-a')), isTrue);
  expect(session.upsertResource(_resource('resource-retained')), isTrue);
  expect(session.removeUnusedResource(CanvasResourceId('resource-a')), isTrue);
  session.setBackgroundColor(const Color(0xFF111111));
  session.setGrid(CanvasGrid(enabled: true, cellSize: 8));
  session.setCameraOffset(const Offset(2, 3));
  session.setPalette(
    CanvasPalette(
      penColors: const [Color(0xFF111111)],
      backgroundColors: const [Color(0xFF222222)],
      gridSizes: const [8],
    ),
  );

  final storeCommit = session.sparseCommit;
  final mutations = storeCommit.mutations;
  final events = <SparsePromotionWorkEvent>[];
  final appliedMutations = <StoreSparseMutation>[];
  final document = DraftDocument.observeSparseMutationApplications(
    appliedMutations.add,
    () => observeSparsePromotionWork(events.add, session.readDraftDocument),
  );

  expect(mutations, hasLength(14));
  expect(appliedMutations, hasLength(mutations.length));
  expect(events.map((event) => event.phase), [
    SparsePromotionWorkPhase.open,
    for (final _ in mutations) ...[
      SparsePromotionWorkPhase.journalElementRead,
      SparsePromotionWorkPhase.draftApplication,
    ],
    SparsePromotionWorkPhase.complete,
  ]);
  for (var index = 0; index < mutations.length; index += 1) {
    expect(
      identical(events[(index * 2) + 1].mutation, mutations[index]),
      isTrue,
    );
    expect(
      identical(events[(index * 2) + 2].mutation, mutations[index]),
      isTrue,
    );
    expect(identical(appliedMutations[index], mutations[index]), isTrue);
  }
  expect(document.backgroundElements.map((element) => element.id), [
    CanvasElementId('background-second'),
    CanvasElementId('background-first'),
  ]);
  expect(
    (document.backgroundElements.last as CanvasRectElement).fillColor,
    const Color(0xFF00FF00),
  );
  expect(
    document.backgroundElements.map((element) => element.id),
    isNot(contains(CanvasElementId('background-a'))),
  );
  expect(document.resources.map((resource) => resource.id), [
    CanvasResourceId('resource-retained'),
  ]);
  expect(document.layers.map((layer) => layer.id), [
    CanvasLayerId('layer-added'),
    CanvasLayerId('layer-empty'),
    CanvasLayerId('layer-a'),
  ]);
  expect(document.layers.first.elements.map((element) => element.id), [
    CanvasElementId('content-second'),
    CanvasElementId('content-first'),
  ]);
  expect(document.layers[1].elements, isEmpty);
  expect(document.layers.last.elements.map((element) => element.id), [
    CanvasElementId('content-a'),
  ]);
  expect(document.background.color, const Color(0xFF111111));
  expect(document.background.grid, CanvasGrid(enabled: true, cellSize: 8));
  expect(document.camera.offset, const Offset(2, 3));
  expect(document.palette.penColors, const [Color(0xFF111111)]);
}

// The direct Draft baseline and promotion work comparison remain together so
// a second clear traversal cannot be hidden behind separately derived facts.
// ignore: halstead-volume
void _promotionAppliesSparseClearContent() {
  final directDraft = _baseDraft();
  final directWork = <DraftClearContentWorkEvent>[];
  final directClear = DraftDocument.observeClearContentWork(
    directWork.add,
    () => directDraft.clearContent(removeUnusedResources: true),
  );
  final session = _sparseSession(_baseDraft);

  final clear = session.clearContent(removeUnusedResources: true);
  expect(clear.didClearContent, isTrue);
  expect(clear.removedElementIds, [CanvasElementId('content-a')]);
  expect(clear.removedResourceIds, [CanvasResourceId('resource-a')]);

  final promotionWork = <DraftClearContentWorkEvent>[];
  final document = DraftDocument.observeClearContentWork(
    promotionWork.add,
    session.readDraftDocument,
  );

  expect(clear.removedElementIds, directClear.removedElementIds);
  expect(clear.removedResourceIds, directClear.removedResourceIds);
  expect(promotionWork, directWork);
  expect(document.backgroundElements.map((element) => element.id), [
    CanvasElementId('background-a'),
  ]);
  expect(document.layers.single.elements, isEmpty);
  expect(document.resources, isEmpty);
}

void _draftSummaryOpensWithoutCommittedIdEnumeration() {
  final facts = _SparseFixtureFacts(_baseDocument());
  final session = EditSession.sparse(
    facts: facts,
    promoteDraft: _baseDraft,
    selectedElementIds: const [],
  );

  _expectSparseSummary(
    session,
    elementCount: 2,
    layerCount: 1,
    resourceCount: 1,
  );
  expect(facts.elementIdsReadCount, 0);
  expect(facts.resourceIdsReadCount, 0);
}

void _draftSummaryTracksSparseMutations() {
  var materializations = 0;
  final session = _sparseSession(() {
    materializations += 1;

    return _baseDraft();
  });

  expect(session.draftSummary.elementCount, 2);
  expect(session.draftSummary.layerCount, 1);
  expect(
    session.addBackgroundElement(_rect('background-added')),
    CanvasElementId('background-added'),
  );
  expect(
    session.addElement(_rect('content-added')),
    CanvasElementId('content-added'),
  );
  expect(session.upsertResource(_resource('resource-added')), isTrue);
  session.setCameraOffset(const Offset(4, 5));
  session.setPalette(const CanvasPalette.defaults());

  _expectSparseSummary(
    session,
    elementCount: 4,
    layerCount: 1,
    resourceCount: 2,
  );
  expect(materializations, 0);

  _expectSparseClearWithoutMaterialization(session);
  expect(materializations, 0);
  final document = session.readDraftDocument();
  expect(materializations, 1);
  expect(document.backgroundElements.map((element) => element.id), [
    CanvasElementId('background-a'),
    CanvasElementId('background-added'),
  ]);
}

void _expectSparseSummary(
  EditSession session, {
  required int elementCount,
  required int layerCount,
  required int resourceCount,
}) {
  expect(
    session.draftSummary,
    CanvasDocumentSummary(
      elementCount: elementCount,
      layerCount: layerCount,
      resourceCount: resourceCount,
    ),
  );
}

void _expectSparseClearWithoutMaterialization(EditSession session) {
  final clear = session.clearContent(removeUnusedResources: true);

  expect(clear.didClearContent, isTrue);
  expect(clear.removedElementIds, [
    CanvasElementId('content-a'),
    CanvasElementId('content-added'),
  ]);
  expect(clear.removedResourceIds, [
    CanvasResourceId('resource-a'),
    CanvasResourceId('resource-added'),
  ]);
  _expectSparseSummary(
    session,
    elementCount: 2,
    layerCount: 1,
    resourceCount: 0,
  );
}

void _sparseClearReportsIndexedInsertionsInDraftOrder() {
  var materializations = 0;
  final session = _sparseSession(() {
    materializations += 1;

    return _baseDraft();
  });

  session.addBackgroundElement(_rect('background-first'), index: 0);
  session.addElement(
    _rect('content-first'),
    layerId: CanvasLayerId('layer-a'),
    index: 0,
  );

  final clear = session.clearContent();

  expect(clear.removedElementIds, [
    CanvasElementId('content-first'),
    CanvasElementId('content-a'),
  ]);
  expect(materializations, 0);
}

void _readDraftDocumentPromotesAndReplays() {
  var materializations = 0;
  final session = _sparseSession(() {
    materializations += 1;

    return _baseDraft();
  });

  session.addBackgroundElement(_rect('background-added'));
  session.addElement(_rect('content-added'), layerId: CanvasLayerId('layer-a'));

  final document = session.readDraftDocument();

  expect(materializations, 1);
  expect(document.backgroundElements.map((element) => element.id.value), [
    'background-a',
    'background-added',
  ]);
  expect(document.layers.single.elements.map((element) => element.id.value), [
    'content-a',
    'content-added',
  ]);
}

void _mutationsAfterPromotionUseMaterializedFallback() {
  var materializations = 0;
  final session = _sparseSession(() {
    materializations += 1;

    return _baseDraft();
  });

  session.addElement(_rect('content-added'), layerId: CanvasLayerId('layer-a'));
  session.readDraftDocument();
  session.updateElement(
    CanvasRectElementUpdate(
      id: CanvasElementId('content-added'),
      fillColor: const CanvasFieldSet(Color(0xFF00FF00)),
    ),
  );
  session.removeElement(CanvasElementId('background-a'));

  final document = session.readDraftDocument();

  expect(materializations, 1);
  expect(document.backgroundElements, isEmpty);
  expect(
    document.layers.single.elements.singleWhere(
      (element) => element.id.value == 'content-added',
    ),
    isA<CanvasRectElement>(),
  );
  expect(session.commitPlan.hasChanges, isTrue);
}

void _replaceDraftDocumentPromotes() {
  var materializations = 0;
  final session = _sparseSession(() {
    materializations += 1;

    return _baseDraft();
  });

  session.replaceDraftDocument(
    CanvasDocument(backgroundElements: [_rect('replacement')]),
  );

  expect(materializations, 1);
  expect(
    session.readDraftDocument().backgroundElements.single.id,
    CanvasElementId('replacement'),
  );
}

void _sparseMutationsPreserveNoOpAndValidation() {
  _expectSparseNoOps();
  _expectSparseValidationFailures();
}

void _expectSparseNoOps() {
  final session = _sparseSession(_baseDraft);

  _expectSparseElementNoOps(session);
  _expectSparseResourceNoOps(session);
  _expectSparseDocumentNoOps(session);
  expect(
    session.draftSummary,
    const CanvasDocumentSummary(
      elementCount: 2,
      layerCount: 1,
      resourceCount: 1,
    ),
  );
  _expectReferencedResourceRemovalNoOp();
}

void _expectSparseElementNoOps(EditSession session) {
  expect(session.ensureLayer(CanvasLayerId('layer-a')), isFalse);
  expect(
    session.updateElement(
      CanvasRectElementUpdate(
        id: CanvasElementId('content-a'),
        size: const CanvasFieldSet(Size(1, 1)),
      ),
    ),
    isFalse,
  );
  expect(session.removeElement(CanvasElementId('missing')), isFalse);
}

void _expectSparseResourceNoOps(EditSession session) {
  expect(session.upsertResource(_resource('resource-a')), isFalse);
  expect(session.removeUnusedResource(CanvasResourceId('missing')), isFalse);
}

void _expectSparseDocumentNoOps(EditSession session) {
  _expectClearNoOpKeepsSparseSessionClean(CanvasDocument());
  _expectClearNoOpKeepsSparseSessionClean(
    CanvasDocument(resources: [_resource('resource-a')]),
  );
  session.setCameraOffset(Offset.zero);
  session.setPalette(const CanvasPalette.defaults());
  session.setBackgroundColor(const Color(0xFFFFFFFF));
  session.setGrid(CanvasGrid());
  expect(session.didChange, isFalse);
}

void _expectClearNoOpKeepsSparseSessionClean(CanvasDocument document) {
  final session = _sparseSessionForDocument(document);

  expect(session.clearContent().didClearContent, isFalse);
  expect(session.didChange, isFalse);
}

void _sparseResourceReferencesUseAcceptedOverlay() {
  _expectRemoveThenResourceRemoval();
  _expectImageUpdateThenResourceRemoval();
}

void _expectRemoveThenResourceRemoval() {
  final session = _sparseSessionForDocument(_documentWithReferencedResource());

  expect(session.removeElement(CanvasElementId('image-a')), isTrue);
  expect(session.removeUnusedResource(CanvasResourceId('resource-a')), isTrue);
  expect(
    session.draftSummary,
    const CanvasDocumentSummary(
      elementCount: 0,
      layerCount: 1,
      resourceCount: 0,
    ),
  );
}

void _expectImageUpdateThenResourceRemoval() {
  final session = _sparseSessionForDocument(_documentWithTwoResources());

  expect(
    session.updateElement(
      CanvasImageElementUpdate(
        id: CanvasElementId('image-a'),
        resourceId: CanvasFieldSet(CanvasResourceId('resource-b')),
      ),
    ),
    isTrue,
  );
  expect(session.removeUnusedResource(CanvasResourceId('resource-a')), isTrue);
  expect(
    session.draftSummary,
    const CanvasDocumentSummary(
      elementCount: 1,
      layerCount: 1,
      resourceCount: 1,
    ),
  );
}

void _expectReferencedResourceRemovalNoOp() {
  final session = _sparseSessionForDocument(_documentWithReferencedResource());

  expect(session.removeUnusedResource(CanvasResourceId('resource-a')), isFalse);
  expect(
    session.draftSummary,
    const CanvasDocumentSummary(
      elementCount: 1,
      layerCount: 1,
      resourceCount: 1,
    ),
  );
}

void _sparseClearTouchesBackgroundLayerOnlyForBackgroundRemovals() {
  final contentOnly = _sparseSessionForDocument(
    CanvasDocument(
      layers: [
        CanvasLayer(
          id: CanvasLayerId('layer-a'),
          elements: [_rect('content-a')],
        ),
      ],
    ),
  );
  contentOnly.clearContent();
  expect(contentOnly.commitPlan.touchedSet.backgroundLayerChanged, isFalse);

  final withBackground = _sparseSessionForDocument(
    CanvasDocument(backgroundElements: [_rect('background-a')]),
  );
  withBackground.clearContent();
  expect(withBackground.commitPlan.touchedSet.backgroundLayerChanged, isFalse);
}

void _sparseClearRetainsBackgroundImageAndVectorResources() {
  var materializations = 0;
  final facts = _SparseFixtureFacts(_documentWithClearBackgroundResources());
  final session = EditSession.sparse(
    facts: facts,
    promoteDraft: () {
      materializations += 1;

      return DraftDocument(_documentWithClearBackgroundResources());
    },
    selectedElementIds: [CanvasElementId('content-image')],
  );
  facts.resetReadCounters();

  final clear = session.clearContent(removeUnusedResources: true);

  expect(clear.didClearContent, isTrue);
  expect(clear.removedElementIds, [CanvasElementId('content-image')]);
  expect(clear.removedResourceIds, [
    CanvasResourceId('content-image-resource'),
    CanvasResourceId('unused-resource'),
    CanvasResourceId('unused-resource-a'),
    CanvasResourceId('unused-resource-b'),
    CanvasResourceId('unused-resource-c'),
    CanvasResourceId('unused-resource-d'),
  ]);
  expect(materializations, 0);
  expect(session.hasMaterializedDraft, isFalse);
  _expectSparseSummary(
    session,
    elementCount: 2,
    layerCount: 1,
    resourceCount: 2,
  );
  expect(session.touchedSet.removedElementIds, {
    CanvasElementId('content-image'),
  });
  expect(session.touchedSet.resourceDescriptorChangedIds, {
    CanvasResourceId('content-image-resource'),
    CanvasResourceId('unused-resource'),
    CanvasResourceId('unused-resource-a'),
    CanvasResourceId('unused-resource-b'),
    CanvasResourceId('unused-resource-c'),
    CanvasResourceId('unused-resource-d'),
  });
  expect(session.touchedSet.selection, isTrue);
  expect(session.touchedSet.backgroundLayerChanged, isFalse);
  expect(session.touchedSet.background, isFalse);
  expect(session.touchedSet.grid, isFalse);
  expect(session.revisionDelta.structural, isTrue);
  expect(session.revisionDelta.resource, isTrue);
  expect(session.revisionDelta.background, isFalse);
  expect(session.revisionDelta.grid, isFalse);
  expect(facts.backgroundElementIdsReadCount, 1);
  expect(facts.resourceIdsReadCount, 1);
  expect(facts.elementByIdReadCount(CanvasElementId('background-image')), 1);
  expect(facts.elementByIdReadCount(CanvasElementId('background-vector')), 1);
  expect(facts.elementIdsReadCount, 0);
  expect(facts.isResourceReferencedReadCount, 0);

  final document = session.readDraftDocument();

  expect(materializations, 1);
  expect(document.backgroundElements.map((element) => element.id), [
    CanvasElementId('background-image'),
    CanvasElementId('background-vector'),
  ]);
  final backgroundImage =
      document.backgroundElements.first as CanvasImageElement;
  final backgroundVector =
      document.backgroundElements.last as CanvasVectorElement;
  expect(
    backgroundImage.resourceId,
    CanvasResourceId('background-image-resource'),
  );
  expect(backgroundImage.revision, 7);
  expect(backgroundImage.size, const Size(2, 3));
  expect(backgroundImage.naturalSize, const Size(20, 30));
  expect(
    backgroundImage.transform,
    CanvasTransform.translation(const Offset(8, 9)),
  );
  expect(backgroundImage.opacity, 0.75);
  expect(backgroundImage.hitPadding, 3);
  expect(backgroundImage.isVisible, isFalse);
  expect(backgroundImage.isSelectable, isFalse);
  expect(backgroundImage.isLocked, isTrue);
  expect(backgroundImage.isDeletable, isFalse);
  expect(backgroundImage.isTransformable, isFalse);
  expect(
    backgroundImage.metadata,
    CanvasMetadata.fromMap({'role': 'background-image', 'rank': 1}),
  );
  expect(
    backgroundVector.resourceId,
    CanvasResourceId('background-vector-resource'),
  );
  expect(backgroundVector.revision, 8);
  expect(backgroundVector.size, const Size(4, 5));
  expect(backgroundVector.naturalSize, const Size(40, 50));
  expect(
    backgroundVector.transform,
    CanvasTransform.translation(const Offset(10, 11)),
  );
  expect(backgroundVector.opacity, 0.5);
  expect(backgroundVector.hitPadding, 4);
  expect(backgroundVector.isVisible, isFalse);
  expect(backgroundVector.isSelectable, isFalse);
  expect(backgroundVector.isLocked, isTrue);
  expect(backgroundVector.isDeletable, isFalse);
  expect(backgroundVector.isTransformable, isFalse);
  expect(
    backgroundVector.metadata,
    CanvasMetadata.fromMap({'role': 'background-vector', 'rank': 2}),
  );
  expect(document.resources.map((resource) => resource.id), [
    CanvasResourceId('background-image-resource'),
    CanvasResourceId('background-vector-resource'),
  ]);
  final imageResource = document.resources.first as CanvasImageResource;
  final vectorResource = document.resources.last as CanvasVectorResource;
  expect(
    imageResource.source,
    CanvasResourceSource.appKey('background-image-source'),
  );
  expect(imageResource.mimeType, 'image/png');
  expect(imageResource.contentHash, 'sha256:background-image');
  expect(imageResource.byteLength, 101);
  expect(
    imageResource.metadata,
    CanvasMetadata.fromMap({'asset': 'image', 'scale': 2}),
  );
  expect(
    vectorResource.source,
    CanvasResourceSource.appKey('background-vector-source'),
  );
  expect(vectorResource.contentHash, 'sha256:background-vector');
  expect(vectorResource.byteLength, 202);
  expect(
    vectorResource.metadata,
    CanvasMetadata.fromMap({'asset': 'vector', 'scale': 3}),
  );
}

// This keeps committed and local sparse facts in one lifecycle: local elements
// are admitted before their resources so the real reference policy need not
// fall back to committed full-frame facts while preparing the clear candidate.
// Keeping the exact lifecycle assertions together is clearer than splitting
// their shared fact-port budget and retained-state proof across helpers.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
void _sparseClearRetainsCommittedAndLocalBackgroundResources() {
  var materializations = 0;
  final seed = _documentWithCommittedAndLocalClearResources();
  final facts = _SparseFixtureFacts(seed);
  final session = EditSession.sparse(
    facts: facts,
    promoteDraft: () {
      materializations += 1;

      return DraftDocument(seed);
    },
    selectedElementIds: const [],
  );

  session.addBackgroundElement(
    CanvasImageElement(
      id: CanvasElementId('local-background-image'),
      resourceId: CanvasResourceId('local-background-image-resource'),
      size: const Size(31, 37),
      naturalSize: const Size(62, 74),
      revision: 7,
      isDeletable: false,
    ),
  );
  expect(
    session.upsertResource(
      CanvasImageResource(
        id: CanvasResourceId('local-background-image-resource'),
        source: CanvasResourceSource.appKey('local-background-image-source'),
        mimeType: 'image/jpeg',
        contentHash: 'local-background-image-hash',
        byteLength: 303,
      ),
    ),
    isTrue,
  );
  session.addBackgroundElement(
    CanvasVectorElement(
      id: CanvasElementId('local-background-vector'),
      resourceId: CanvasResourceId('local-background-vector-resource'),
      size: const Size(41, 43),
      naturalSize: const Size(82, 86),
      revision: 8,
      isDeletable: false,
    ),
  );
  expect(
    session.upsertResource(
      CanvasVectorResource(
        id: CanvasResourceId('local-background-vector-resource'),
        source: CanvasResourceSource.appKey('local-background-vector-source'),
        contentHash: 'local-background-vector-hash',
        byteLength: 404,
      ),
    ),
    isTrue,
  );
  session.addElement(
    CanvasImageElement(
      id: CanvasElementId('local-content-image'),
      resourceId: CanvasResourceId('local-content-image-resource'),
      size: const Size(47, 53),
      isDeletable: false,
    ),
  );
  expect(
    session.upsertResource(
      CanvasImageResource(
        id: CanvasResourceId('local-content-image-resource'),
        source: CanvasResourceSource.appKey('local-content-image-source'),
      ),
    ),
    isTrue,
  );
  session.addElement(
    CanvasVectorElement(
      id: CanvasElementId('local-unused-reference'),
      resourceId: CanvasResourceId('local-unused-vector-resource'),
      size: const Size(59, 61),
    ),
  );
  expect(
    session.upsertResource(
      CanvasVectorResource(
        id: CanvasResourceId('local-unused-vector-resource'),
        source: CanvasResourceSource.appKey('local-unused-vector-source'),
      ),
    ),
    isTrue,
  );
  expect(
    session.removeElement(CanvasElementId('local-unused-reference')),
    isTrue,
  );

  final backgroundReadsBeforeClear = facts.backgroundElementIdsReadCount;
  final resourceReadsBeforeClear = facts.resourceIdsReadCount;
  final committedImageReadsBeforeClear = facts.elementByIdReadCount(
    CanvasElementId('committed-background-image'),
  );
  final committedVectorReadsBeforeClear = facts.elementByIdReadCount(
    CanvasElementId('committed-background-vector'),
  );
  final localImageReadsBeforeClear = facts.elementByIdReadCount(
    CanvasElementId('local-background-image'),
  );
  final localVectorReadsBeforeClear = facts.elementByIdReadCount(
    CanvasElementId('local-background-vector'),
  );
  final elementIdsReadsBeforeClear = facts.elementIdsReadCount;
  final referenceReadsBeforeClear = facts.isResourceReferencedReadCount;

  final clear = session.clearContent(removeUnusedResources: true);

  expect(clear.didClearContent, isTrue);
  expect(clear.removedElementIds, [
    CanvasElementId('committed-content-image'),
    CanvasElementId('local-content-image'),
  ]);
  expect(clear.removedResourceIds, [
    CanvasResourceId('committed-content-image-resource'),
    CanvasResourceId('committed-unused-vector-resource'),
    CanvasResourceId('local-content-image-resource'),
    CanvasResourceId('local-unused-vector-resource'),
  ]);
  expect(materializations, 0);
  expect(session.hasMaterializedDraft, isFalse);
  expect(facts.backgroundElementIdsReadCount, backgroundReadsBeforeClear);
  expect(facts.resourceIdsReadCount - resourceReadsBeforeClear, 1);
  expect(
    facts.elementByIdReadCount(CanvasElementId('committed-background-image')) -
        committedImageReadsBeforeClear,
    1,
  );
  expect(
    facts.elementByIdReadCount(CanvasElementId('committed-background-vector')) -
        committedVectorReadsBeforeClear,
    1,
  );
  expect(
    facts.elementByIdReadCount(CanvasElementId('local-background-image')) -
        localImageReadsBeforeClear,
    0,
  );
  expect(
    facts.elementByIdReadCount(CanvasElementId('local-background-vector')) -
        localVectorReadsBeforeClear,
    0,
  );
  expect(facts.elementIdsReadCount - elementIdsReadsBeforeClear, 0);
  expect(facts.isResourceReferencedReadCount - referenceReadsBeforeClear, 0);
  expect(facts.backgroundElementIdsReadCount, 1);
  expect(facts.resourceIdsReadCount, 1);
  expect(facts.elementIdsReadCount, 0);
  expect(facts.isResourceReferencedReadCount, 0);

  final document = session.readDraftDocument();

  expect(materializations, 1);
  expect(document.backgroundElements.map((element) => element.id), [
    CanvasElementId('committed-background-image'),
    CanvasElementId('committed-background-vector'),
    CanvasElementId('local-background-image'),
    CanvasElementId('local-background-vector'),
  ]);
  expect(document.backgroundElements.map((element) => element.kind), [
    CanvasElementKind.image,
    CanvasElementKind.vector,
    CanvasElementKind.image,
    CanvasElementKind.vector,
  ]);
  final committedImage =
      document.backgroundElements.first as CanvasImageElement;
  final committedVector = document.backgroundElements[1] as CanvasVectorElement;
  final localImage = document.backgroundElements[2] as CanvasImageElement;
  final localVector = document.backgroundElements[3] as CanvasVectorElement;
  expect(
    committedImage.resourceId,
    CanvasResourceId('committed-background-image-resource'),
  );
  expect(
    committedVector.resourceId,
    CanvasResourceId('committed-background-vector-resource'),
  );
  expect(
    localImage.resourceId,
    CanvasResourceId('local-background-image-resource'),
  );
  expect(localImage.size, const Size(31, 37));
  expect(localImage.naturalSize, const Size(62, 74));
  expect(localImage.revision, 7);
  expect(
    localVector.resourceId,
    CanvasResourceId('local-background-vector-resource'),
  );
  expect(localVector.size, const Size(41, 43));
  expect(localVector.naturalSize, const Size(82, 86));
  expect(localVector.revision, 8);
  expect(document.layers.single.elements, isEmpty);
  expect(document.resources.map((resource) => resource.id), [
    CanvasResourceId('committed-background-image-resource'),
    CanvasResourceId('committed-background-vector-resource'),
    CanvasResourceId('local-background-image-resource'),
    CanvasResourceId('local-background-vector-resource'),
  ]);
  expect(document.resources.map((resource) => resource.runtimeType), [
    CanvasImageResource,
    CanvasVectorResource,
    CanvasImageResource,
    CanvasVectorResource,
  ]);
  final committedImageResource =
      document.resources.first as CanvasImageResource;
  final committedVectorResource = document.resources[1] as CanvasVectorResource;
  expect(
    committedImageResource.source,
    CanvasResourceSource.appKey('committed-background-image-source'),
  );
  expect(
    committedVectorResource.source,
    CanvasResourceSource.appKey('committed-background-vector-source'),
  );
  final localImageResource = document.resources[2] as CanvasImageResource;
  final localVectorResource = document.resources[3] as CanvasVectorResource;
  expect(
    localImageResource.source,
    CanvasResourceSource.appKey('local-background-image-source'),
  );
  expect(localImageResource.mimeType, 'image/jpeg');
  expect(localImageResource.contentHash, 'local-background-image-hash');
  expect(localImageResource.byteLength, 303);
  expect(
    localVectorResource.source,
    CanvasResourceSource.appKey('local-background-vector-source'),
  );
  expect(localVectorResource.contentHash, 'local-background-vector-hash');
  expect(localVectorResource.byteLength, 404);
}

void _promotedSparseClearKeepsDraftResourceWorkBounded() {
  var materializations = 0;
  final session = _sparseSessionForDocument(
    _documentWithClearBackgroundResources(),
    promoteDraft: () {
      materializations += 1;

      return DraftDocument(_documentWithClearBackgroundResources());
    },
  );

  session.readDraftDocument();
  final work = <DraftClearContentWorkEvent>[];
  final clear = DraftDocument.observeClearContentWork(
    work.add,
    () => session.clearContent(removeUnusedResources: true),
  );

  expect(materializations, 1);
  expect(clear.removedElementIds, [CanvasElementId('content-image')]);
  expect(clear.removedResourceIds, [
    CanvasResourceId('content-image-resource'),
    CanvasResourceId('unused-resource'),
    CanvasResourceId('unused-resource-a'),
    CanvasResourceId('unused-resource-b'),
    CanvasResourceId('unused-resource-c'),
    CanvasResourceId('unused-resource-d'),
  ]);
  expect(
    _draftClearWorkEventCount(
      work,
      DraftClearContentWorkEvent.backgroundReferencePass,
    ),
    1,
  );
  expect(
    _draftClearWorkEventCount(
      work,
      DraftClearContentWorkEvent.backgroundElementVisit,
    ),
    2,
  );
  expect(
    _draftClearWorkEventCount(work, DraftClearContentWorkEvent.resourcePass),
    1,
  );
  expect(
    _draftClearWorkEventCount(work, DraftClearContentWorkEvent.resourceVisit),
    8,
  );
  expect(
    _draftClearWorkEventCount(
      work,
      DraftClearContentWorkEvent.acceptedElementScan,
    ),
    0,
  );
}

// The fixture seed declares one literal committed frame so expected local versus
// committed retention facts stay visible without a test-owned inventory.
// ignore: halstead-volume, source-lines-of-code
CanvasDocument _documentWithCommittedAndLocalClearResources() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('committed-background-image-resource'),
        source: CanvasResourceSource.appKey(
          'committed-background-image-source',
        ),
        mimeType: 'image/png',
        contentHash: 'committed-background-image-hash',
        byteLength: 101,
      ),
      CanvasVectorResource(
        id: CanvasResourceId('committed-background-vector-resource'),
        source: CanvasResourceSource.appKey(
          'committed-background-vector-source',
        ),
        contentHash: 'committed-background-vector-hash',
        byteLength: 202,
      ),
      CanvasImageResource(
        id: CanvasResourceId('committed-content-image-resource'),
        source: CanvasResourceSource.appKey('committed-content-image-source'),
      ),
      CanvasVectorResource(
        id: CanvasResourceId('committed-unused-vector-resource'),
        source: CanvasResourceSource.appKey('committed-unused-vector-source'),
      ),
    ],
    backgroundElements: [
      CanvasImageElement(
        id: CanvasElementId('committed-background-image'),
        resourceId: CanvasResourceId('committed-background-image-resource'),
        size: const Size(11, 13),
        naturalSize: const Size(22, 26),
        revision: 3,
      ),
      CanvasVectorElement(
        id: CanvasElementId('committed-background-vector'),
        resourceId: CanvasResourceId('committed-background-vector-resource'),
        size: const Size(17, 19),
        naturalSize: const Size(34, 38),
        revision: 4,
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('committed-content-layer'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('committed-content-image'),
            resourceId: CanvasResourceId('committed-content-image-resource'),
            size: const Size(23, 29),
            isDeletable: false,
          ),
        ],
      ),
    ],
  );
}

int _draftClearWorkEventCount(
  Iterable<DraftClearContentWorkEvent> work,
  DraftClearContentWorkEvent event,
) {
  return work.where((item) => item == event).length;
}

// Regression: evaluating removeUnusedResource against a final clear state
// rather than its journal position would make one of these paired traces
// retain or release the ordinary-content descriptor incorrectly.
void _expectRemoveUnusedResourceBarrierThroughSparseSession() {
  final resourceId = CanvasResourceId('content-image-resource');
  final removeBeforeClear = _runSparseClearTrace([
    _ClearTraceAction.removeUnusedResource(resourceId),
    const _ClearTraceAction.clearContent(removeUnusedResources: false),
  ]);
  final clearBeforeRemove = _runSparseClearTrace([
    const _ClearTraceAction.clearContent(removeUnusedResources: false),
    _ClearTraceAction.removeUnusedResource(resourceId),
  ]);

  _expectSparseClearTraceMatchesOracle(removeBeforeClear);
  _expectSparseClearTraceMatchesOracle(clearBeforeRemove);
  _expectSparseCommitInstallsTrace(removeBeforeClear);
  _expectSparseCommitInstallsTrace(clearBeforeRemove);

  expect(removeBeforeClear.actualResults[0].changed, isFalse);
  expect(removeBeforeClear.sparseCommit.mutations, hasLength(1));
  expect(
    removeBeforeClear.sparseCommit.mutations.single,
    isA<StoreSparseClearContent>(),
  );
  final retainedClear = removeBeforeClear.actualResults[1].clearResult;
  expect(retainedClear?.didClearContent, isTrue);
  expect(retainedClear?.removedElementIds, [CanvasElementId('content-image')]);
  expect(retainedClear?.removedResourceIds, isEmpty);
  expect(removeBeforeClear.document.resources.map((resource) => resource.id), [
    CanvasResourceId('background-image-resource'),
    CanvasResourceId('background-vector-resource'),
    resourceId,
  ]);
  expect(removeBeforeClear.session.touchedSet.removedElementIds, {
    CanvasElementId('content-image'),
  });
  expect(
    removeBeforeClear.session.touchedSet.resourceDescriptorChangedIds,
    isEmpty,
  );
  expect(removeBeforeClear.session.revisionDelta.structural, isTrue);
  expect(removeBeforeClear.session.revisionDelta.resource, isFalse);

  final removedClear = clearBeforeRemove.actualResults[0].clearResult;
  expect(removedClear?.didClearContent, isTrue);
  expect(removedClear?.removedElementIds, [CanvasElementId('content-image')]);
  expect(removedClear?.removedResourceIds, isEmpty);
  expect(clearBeforeRemove.actualResults[1].changed, isTrue);
  expect(clearBeforeRemove.sparseCommit.mutations, hasLength(2));
  expect(
    clearBeforeRemove.sparseCommit.mutations.first,
    isA<StoreSparseClearContent>(),
  );
  expect(
    clearBeforeRemove.sparseCommit.mutations.last,
    isA<StoreSparseRemoveUnusedResource>().having(
      (mutation) => mutation.id,
      'resource id',
      resourceId,
    ),
  );
  expect(clearBeforeRemove.document.resources.map((resource) => resource.id), [
    CanvasResourceId('background-image-resource'),
    CanvasResourceId('background-vector-resource'),
  ]);
  expect(clearBeforeRemove.session.touchedSet.removedElementIds, {
    CanvasElementId('content-image'),
  });
  expect(clearBeforeRemove.session.touchedSet.resourceDescriptorChangedIds, {
    resourceId,
  });
  expect(clearBeforeRemove.session.revisionDelta.structural, isTrue);
  expect(clearBeforeRemove.session.revisionDelta.resource, isTrue);
}

void _expectSparseCommitInstallsTrace(_SparseClearTraceOutcome outcome) {
  final store = documentStoreWithDocument(
    _documentWithClearBackgroundResources(includeUnusedResource: false),
  );
  final prepared = store.prepareSparseCommit(outcome.sparseCommit);

  expect(
    prepared.hasChanges,
    outcome.expectedEffects.structural || outcome.expectedEffects.resource,
  );
  expect(
    prepared.touchedFacts.addedElementIds,
    outcome.expectedEffects.addedElementIds,
  );
  expect(
    prepared.touchedFacts.removedElementIds,
    outcome.expectedEffects.removedElementIds,
  );
  expect(
    prepared.touchedFacts.resourceDescriptorChangedIds,
    outcome.expectedEffects.resourceDescriptorChangedIds,
  );
  expect(
    prepared.touchedFacts.resourceVisualChangedIds,
    outcome.expectedEffects.resourceDescriptorChangedIds,
  );
  expect(
    prepared.touchedFacts.layerIds,
    outcome.expectedEffects.structural
        ? {CanvasLayerId('layer-a')}
        : <CanvasLayerId>{},
  );
  expect(prepared.touchedFacts.backgroundLayerChanged, isFalse);
  expect(prepared.touchedFacts.background, isFalse);
  expect(prepared.touchedFacts.grid, isFalse);
  expect(prepared.revisionDelta.structural, outcome.expectedEffects.structural);
  expect(prepared.revisionDelta.resource, outcome.expectedEffects.resource);

  store.installSparseCommit(prepared);

  expect(
    store.backgroundElementIds,
    outcome.expectedDocument.backgroundElements.map((element) => element.id),
  );
  _expectTraceElements([
    for (final id in store.backgroundElementIds)
      _requireInstalledTraceElement(store.elementById(id), id),
  ], outcome.expectedDocument.backgroundElements);
  expect(
    store.elementIdsInLayer(CanvasLayerId('layer-a')),
    outcome.expectedDocument.layers.single.elements.map(
      (element) => element.id,
    ),
  );
  _expectTraceElements([
    for (final id in store.elementIdsInLayer(CanvasLayerId('layer-a')))
      _requireInstalledTraceElement(store.elementById(id), id),
  ], outcome.expectedDocument.layers.single.elements);
  expect(
    store.resourceIds,
    outcome.expectedDocument.resources.map((resource) => resource.id),
  );
  for (final resource in outcome.expectedDocument.resources) {
    _expectInstalledTraceDescriptor(
      store.resourceDescriptor(resource.id),
      resource,
    );
  }
}

void _expectInstalledTraceDescriptor(
  StoreResourceDescriptorFacts? actual,
  CanvasResource expected,
) {
  if (actual == null) {
    fail('installed trace descriptor is absent for ${expected.id}.');
  }
  final descriptor = actual;
  expect(descriptor.id, expected.id);
  expect(descriptor.resourceRevision, 1);
  switch (expected) {
    case CanvasImageResource(
      :final source,
      :final mimeType,
      :final contentHash,
      :final byteLength,
      :final metadata,
    ):
      expect(descriptor, isA<StoreImageResourceDescriptorFacts>());
      final image = descriptor as StoreImageResourceDescriptorFacts;
      expect(image.appKey, (source as CanvasAppKeyResourceSource).key);
      expect(image.mimeType, mimeType);
      expect(image.contentHash, contentHash);
      expect(image.byteLength, byteLength);
      expect(image.metadata, metadata);
    case CanvasVectorResource(
      :final source,
      :final contentHash,
      :final byteLength,
      :final metadata,
    ):
      expect(descriptor, isA<StoreVectorResourceDescriptorFacts>());
      final vector = descriptor as StoreVectorResourceDescriptorFacts;
      expect(vector.appKey, (source as CanvasAppKeyResourceSource).key);
      expect(vector.contentHash, contentHash);
      expect(vector.byteLength, byteLength);
      expect(vector.metadata, metadata);
  }
}

CanvasElement _requireInstalledTraceElement(
  CanvasElement? element,
  CanvasElementId id,
) {
  if (element == null) {
    fail('installed trace element is absent for $id.');
  }
  return element;
}

void _sparseClearRemainsAnOrderedJournalBarrier() {
  _expectRemoveUnusedResourceBarrierThroughSparseSession();

  final beforeClearTrace = [
    _ClearTraceAction.upsertResource(_resource('resource-before-clear')),
    _ClearTraceAction.addElement(
      CanvasImageElement(
        id: CanvasElementId('content-before-clear'),
        resourceId: CanvasResourceId('resource-before-clear'),
        size: const Size(8, 9),
        isDeletable: false,
      ),
    ),
    const _ClearTraceAction.clearContent(removeUnusedResources: false),
    _ClearTraceAction.removeUnusedResource(
      CanvasResourceId('content-image-resource'),
    ),
    const _ClearTraceAction.clearContent(removeUnusedResources: true),
    _ClearTraceAction.removeUnusedResource(
      CanvasResourceId('resource-before-clear'),
    ),
  ];
  final afterClearTrace = [
    const _ClearTraceAction.clearContent(removeUnusedResources: false),
    _ClearTraceAction.removeUnusedResource(
      CanvasResourceId('content-image-resource'),
    ),
    const _ClearTraceAction.clearContent(removeUnusedResources: true),
    _ClearTraceAction.upsertResource(_resource('resource-after-clear')),
    _ClearTraceAction.addElement(
      CanvasImageElement(
        id: CanvasElementId('content-after-clear'),
        resourceId: CanvasResourceId('resource-after-clear'),
        size: const Size(10, 11),
        isDeletable: false,
      ),
    ),
  ];

  final beforeClear = _runSparseClearTrace(beforeClearTrace);
  final afterClear = _runSparseClearTrace(afterClearTrace);

  _expectSparseClearTraceMatchesOracle(beforeClear);
  _expectSparseClearTraceMatchesOracle(afterClear);
  expect(beforeClear.document.layers.single.elements, isEmpty);
  expect(
    afterClear.document.layers.single.elements.map((element) => element.id),
    [CanvasElementId('content-after-clear')],
  );
  expect(beforeClear.document.resources.map((resource) => resource.id), [
    CanvasResourceId('background-image-resource'),
    CanvasResourceId('background-vector-resource'),
  ]);
  expect(afterClear.document.resources.map((resource) => resource.id), [
    CanvasResourceId('background-image-resource'),
    CanvasResourceId('background-vector-resource'),
    CanvasResourceId('resource-after-clear'),
  ]);
  for (final outcome in [beforeClear, afterClear]) {
    expect(outcome.document.backgroundElements.map((element) => element.id), [
      CanvasElementId('background-image'),
      CanvasElementId('background-vector'),
    ]);
  }
}

_SparseClearTraceOutcome _runSparseClearTrace(List<_ClearTraceAction> trace) {
  final seed = _documentWithClearBackgroundResources(
    includeUnusedResource: false,
  );
  final oracle = _ClearSequentialOracle(
    seed,
    selectedElementIds: {CanvasElementId('content-image')},
  );
  final session = EditSession.sparse(
    facts: _SparseFixtureFacts(seed),
    promoteDraft: () => DraftDocument(
      seed,
      selectedElementIds: [CanvasElementId('content-image')],
    ),
    selectedElementIds: [CanvasElementId('content-image')],
  );
  final actualResults = <_ClearTraceResult>[];
  final expectedResults = <_ClearTraceResult>[];

  for (final action in trace) {
    actualResults.add(action.applyToSession(session));
    expectedResults.add(action.applyToOracle(oracle));
  }
  final sparseCommit = session.sparseCommit;

  return _SparseClearTraceOutcome(
    actualResults: actualResults,
    expectedResults: expectedResults,
    sparseCommit: sparseCommit,
    document: session.readDraftDocument(),
    expectedDocument: oracle.toDocument(),
    session: session,
    expectedEffects: oracle.effects,
  );
}

void _expectSparseClearTraceMatchesOracle(_SparseClearTraceOutcome outcome) {
  expect(outcome.actualResults.length, outcome.expectedResults.length);
  for (var index = 0; index < outcome.actualResults.length; index += 1) {
    _expectClearTraceResult(
      outcome.actualResults[index],
      outcome.expectedResults[index],
    );
  }
  expect(outcome.document.background, outcome.expectedDocument.background);
  _expectTraceElements(
    outcome.document.backgroundElements,
    outcome.expectedDocument.backgroundElements,
  );
  expect(
    outcome.document.layers.map((layer) => layer.id),
    outcome.expectedDocument.layers.map((layer) => layer.id),
  );
  for (var index = 0; index < outcome.document.layers.length; index += 1) {
    _expectTraceElements(
      outcome.document.layers[index].elements,
      outcome.expectedDocument.layers[index].elements,
    );
  }
  _expectTraceResources(
    outcome.document.resources,
    outcome.expectedDocument.resources,
  );
  expect(
    outcome.session.touchedSet.addedElementIds,
    outcome.expectedEffects.addedElementIds,
  );
  expect(
    outcome.session.touchedSet.removedElementIds,
    outcome.expectedEffects.removedElementIds,
  );
  expect(
    outcome.session.touchedSet.resourceDescriptorChangedIds,
    outcome.expectedEffects.resourceDescriptorChangedIds,
  );
  expect(
    outcome.session.touchedSet.selection,
    outcome.expectedEffects.selection,
  );
  expect(outcome.session.touchedSet.backgroundLayerChanged, isFalse);
  expect(outcome.session.touchedSet.background, isFalse);
  expect(outcome.session.touchedSet.grid, isFalse);
  expect(
    outcome.session.revisionDelta.structural,
    outcome.expectedEffects.structural,
  );
  expect(
    outcome.session.revisionDelta.resource,
    outcome.expectedEffects.resource,
  );
  expect(outcome.session.revisionDelta.background, isFalse);
  expect(outcome.session.revisionDelta.grid, isFalse);
}

void _expectClearTraceResult(
  _ClearTraceResult actual,
  _ClearTraceResult expected,
) {
  expect(actual.kind, expected.kind);
  expect(actual.elementId, expected.elementId);
  expect(actual.changed, expected.changed);
  final actualClear = actual.clearResult;
  final expectedClear = expected.clearResult;
  expect(actualClear?.didClearContent, expectedClear?.didClearContent);
  expect(actualClear?.removedElementIds, expectedClear?.removedElementIds);
  expect(actualClear?.removedResourceIds, expectedClear?.removedResourceIds);
}

void _expectTraceElements(
  List<CanvasElement> actual,
  List<CanvasElement> expected,
) {
  expect(actual.length, expected.length);
  for (var index = 0; index < actual.length; index += 1) {
    final actualElement = actual[index];
    final expectedElement = expected[index];
    expect(actualElement.runtimeType, expectedElement.runtimeType);
    expect(actualElement.id, expectedElement.id);
    expect(actualElement.revision, expectedElement.revision);
    expect(actualElement.transform, expectedElement.transform);
    expect(actualElement.opacity, expectedElement.opacity);
    expect(actualElement.hitPadding, expectedElement.hitPadding);
    expect(actualElement.isVisible, expectedElement.isVisible);
    expect(actualElement.isSelectable, expectedElement.isSelectable);
    expect(actualElement.isLocked, expectedElement.isLocked);
    expect(actualElement.isDeletable, expectedElement.isDeletable);
    expect(actualElement.isTransformable, expectedElement.isTransformable);
    expect(actualElement.metadata, expectedElement.metadata);
    switch ((actualElement, expectedElement)) {
      case (
        final CanvasImageElement actualImage,
        final CanvasImageElement expectedImage,
      ):
        expect(actualImage.resourceId, expectedImage.resourceId);
        expect(actualImage.size, expectedImage.size);
        expect(actualImage.naturalSize, expectedImage.naturalSize);
      case (
        final CanvasVectorElement actualVector,
        final CanvasVectorElement expectedVector,
      ):
        expect(actualVector.resourceId, expectedVector.resourceId);
        expect(actualVector.size, expectedVector.size);
        expect(actualVector.naturalSize, expectedVector.naturalSize);
      default:
        fail('trace fixture supports image and vector elements only.');
    }
  }
}

void _expectTraceResources(
  List<CanvasResource> actual,
  List<CanvasResource> expected,
) {
  expect(actual.length, expected.length);
  for (var index = 0; index < actual.length; index += 1) {
    final actualResource = actual[index];
    final expectedResource = expected[index];
    expect(actualResource.runtimeType, expectedResource.runtimeType);
    expect(actualResource.id, expectedResource.id);
    expect(actualResource.source, expectedResource.source);
    expect(actualResource.contentHash, expectedResource.contentHash);
    expect(actualResource.byteLength, expectedResource.byteLength);
    expect(actualResource.metadata, expectedResource.metadata);
    switch ((actualResource, expectedResource)) {
      case (
        final CanvasImageResource actualImage,
        final CanvasImageResource expectedImage,
      ):
        expect(actualImage.mimeType, expectedImage.mimeType);
      case (CanvasVectorResource(), CanvasVectorResource()):
        break;
      default:
        fail('trace fixture supports image and vector resources only.');
    }
  }
}

void _sparseRemoveTouchesBackgroundLayerOnlyForBackgroundRemovals() {
  final contentRemove = _sparseSessionForDocument(_baseDocument());
  expect(contentRemove.removeElement(CanvasElementId('content-a')), isTrue);
  expect(contentRemove.commitPlan.touchedSet.backgroundLayerChanged, isFalse);

  final backgroundRemove = _sparseSessionForDocument(_baseDocument());
  expect(
    backgroundRemove.removeElement(CanvasElementId('background-a')),
    isTrue,
  );
  expect(backgroundRemove.commitPlan.touchedSet.backgroundLayerChanged, isTrue);
}

void _expectSparseValidationFailures() {
  final session = _sparseSession(_baseDraft);

  expect(
    () => session.addElement(_rect('content-a')),
    throwsA(isA<CanvasDataException>()),
  );
  expect(
    session.addElement(
      CanvasImageElement(
        id: CanvasElementId('image-missing'),
        resourceId: CanvasResourceId('missing'),
        size: const Size(1, 1),
      ),
    ),
    CanvasElementId('image-missing'),
  );
  expect(
    () => session.updateElement(
      CanvasImageElementUpdate(id: CanvasElementId('content-a')),
    ),
    throwsArgumentError,
  );
}

void _staleSparseHandleRejected() {
  final session = _sparseSession(_baseDraft)..close();

  _expectStaleReadEntriesRejected(session);
  _expectStaleElementEntriesRejected(session);
  _expectStaleResourceEntriesRejected(session);
  _expectStaleDocumentEntriesRejected(session);
}

void _expectStaleReadEntriesRejected(EditSession session) {
  expect(() => session.readDraftDocument(), throwsStateError);
  expect(() => session.draftSummary, throwsStateError);
}

void _expectStaleElementEntriesRejected(EditSession session) {
  expect(() => session.ensureLayer(CanvasLayerId('next')), throwsStateError);
  expect(() => session.addElement(_rect('next')), throwsStateError);
  expect(
    () => session.addBackgroundElement(_rect('next-bg')),
    throwsStateError,
  );
  expect(
    () => session.updateElement(
      CanvasRectElementUpdate(
        id: CanvasElementId('content-a'),
        fillColor: const CanvasFieldSet(Color(0xFF00FF00)),
      ),
    ),
    throwsStateError,
  );
  expect(
    () => session.removeElement(CanvasElementId('content-a')),
    throwsStateError,
  );
}

void _expectStaleResourceEntriesRejected(EditSession session) {
  expect(
    () => session.upsertResource(_resource('resource-b')),
    throwsStateError,
  );
  expect(
    () => session.removeUnusedResource(CanvasResourceId('resource-a')),
    throwsStateError,
  );
}

void _expectStaleDocumentEntriesRejected(EditSession session) {
  expect(
    () => session.setBackgroundColor(const Color(0xFF000000)),
    throwsStateError,
  );
  expect(
    () => session.setGrid(CanvasGrid(enabled: true, cellSize: 8)),
    throwsStateError,
  );
  expect(
    () => session.setPalette(const CanvasPalette.defaults()),
    throwsStateError,
  );
  expect(() => session.setCameraOffset(const Offset(1, 2)), throwsStateError);
  expect(() => session.clearContent(), throwsStateError);
  expect(
    () => session.replaceDraftDocument(CanvasDocument()),
    throwsStateError,
  );
}

EditSession _sparseSession(DraftDocument Function() promoteDraft) {
  return _sparseSessionForDocument(_baseDocument(), promoteDraft: promoteDraft);
}

EditSession _sparseSessionForDocument(
  CanvasDocument document, {
  DraftDocument Function()? promoteDraft,
}) {
  return EditSession.sparse(
    facts: _SparseFixtureFacts(document),
    promoteDraft: promoteDraft ?? () => DraftDocument(document),
    selectedElementIds: const [],
  );
}

DraftDocument _baseDraft() {
  return DraftDocument(_baseDocument());
}

CanvasDocument _baseDocument() {
  return CanvasDocument(
    resources: [_resource('resource-a')],
    backgroundElements: [_rect('background-a')],
    layers: [
      CanvasLayer(id: CanvasLayerId('layer-a'), elements: [_rect('content-a')]),
    ],
  );
}

CanvasDocument _documentWithReferencedResource() {
  return CanvasDocument(
    resources: [_resource('resource-a')],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('image-a'),
            resourceId: CanvasResourceId('resource-a'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _documentWithTwoResources() {
  return CanvasDocument(
    resources: [_resource('resource-a'), _resource('resource-b')],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('image-a'),
            resourceId: CanvasResourceId('resource-a'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _documentWithClearBackgroundResources({
  bool includeUnusedResource = true,
}) {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('background-image-resource'),
        source: CanvasResourceSource.appKey('background-image-source'),
        mimeType: 'image/png',
        contentHash: 'sha256:background-image',
        byteLength: 101,
        metadata: CanvasMetadata.fromMap({'asset': 'image', 'scale': 2}),
      ),
      CanvasVectorResource(
        id: CanvasResourceId('background-vector-resource'),
        source: CanvasResourceSource.appKey('background-vector-source'),
        contentHash: 'sha256:background-vector',
        byteLength: 202,
        metadata: CanvasMetadata.fromMap({'asset': 'vector', 'scale': 3}),
      ),
      CanvasImageResource(
        id: CanvasResourceId('content-image-resource'),
        source: CanvasResourceSource.appKey('content-image-source'),
      ),
      if (includeUnusedResource)
        CanvasVectorResource(
          id: CanvasResourceId('unused-resource'),
          source: CanvasResourceSource.appKey('unused-source'),
        ),
      if (includeUnusedResource)
        CanvasImageResource(
          id: CanvasResourceId('unused-resource-a'),
          source: CanvasResourceSource.appKey('unused-source-a'),
        ),
      if (includeUnusedResource)
        CanvasVectorResource(
          id: CanvasResourceId('unused-resource-b'),
          source: CanvasResourceSource.appKey('unused-source-b'),
        ),
      if (includeUnusedResource)
        CanvasImageResource(
          id: CanvasResourceId('unused-resource-c'),
          source: CanvasResourceSource.appKey('unused-source-c'),
        ),
      if (includeUnusedResource)
        CanvasVectorResource(
          id: CanvasResourceId('unused-resource-d'),
          source: CanvasResourceSource.appKey('unused-source-d'),
        ),
    ],
    backgroundElements: [
      CanvasImageElement(
        id: CanvasElementId('background-image'),
        resourceId: CanvasResourceId('background-image-resource'),
        size: const Size(2, 3),
        naturalSize: const Size(20, 30),
        revision: 7,
        transform: CanvasTransform.translation(const Offset(8, 9)),
        opacity: 0.75,
        hitPadding: 3,
        isVisible: false,
        isSelectable: false,
        isLocked: true,
        isDeletable: false,
        isTransformable: false,
        metadata: CanvasMetadata.fromMap({
          'role': 'background-image',
          'rank': 1,
        }),
      ),
      CanvasVectorElement(
        id: CanvasElementId('background-vector'),
        resourceId: CanvasResourceId('background-vector-resource'),
        size: const Size(4, 5),
        naturalSize: const Size(40, 50),
        revision: 8,
        transform: CanvasTransform.translation(const Offset(10, 11)),
        opacity: 0.5,
        hitPadding: 4,
        isVisible: false,
        isSelectable: false,
        isLocked: true,
        isDeletable: false,
        isTransformable: false,
        metadata: CanvasMetadata.fromMap({
          'role': 'background-vector',
          'rank': 2,
        }),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('content-image'),
            resourceId: CanvasResourceId('content-image-resource'),
            size: const Size(6, 7),
            isVisible: false,
            isLocked: true,
            isDeletable: false,
          ),
        ],
      ),
    ],
  );
}

enum _ClearTraceActionKind {
  addElement,
  upsertResource,
  removeUnusedResource,
  clearContent,
}

final class _ClearTraceAction {
  const _ClearTraceAction._(this.kind, this.value);

  factory _ClearTraceAction.addElement(CanvasElement element) {
    return _ClearTraceAction._(_ClearTraceActionKind.addElement, element);
  }

  factory _ClearTraceAction.upsertResource(CanvasResource resource) {
    return _ClearTraceAction._(_ClearTraceActionKind.upsertResource, resource);
  }

  factory _ClearTraceAction.removeUnusedResource(CanvasResourceId id) {
    return _ClearTraceAction._(_ClearTraceActionKind.removeUnusedResource, id);
  }

  const _ClearTraceAction.clearContent({required bool removeUnusedResources})
    : this._(_ClearTraceActionKind.clearContent, removeUnusedResources);

  final _ClearTraceActionKind kind;
  final Object value;

  _ClearTraceResult applyToSession(EditSession session) {
    return switch (kind) {
      _ClearTraceActionKind.addElement => _ClearTraceResult.added(
        session.addElement(value as CanvasElement),
      ),
      _ClearTraceActionKind.upsertResource => _ClearTraceResult.changed(
        kind,
        changed: session.upsertResource(value as CanvasResource),
      ),
      _ClearTraceActionKind.removeUnusedResource => _ClearTraceResult.changed(
        kind,
        changed: session.removeUnusedResource(value as CanvasResourceId),
      ),
      _ClearTraceActionKind.clearContent => _ClearTraceResult.cleared(
        session.clearContent(removeUnusedResources: value as bool),
      ),
    };
  }

  _ClearTraceResult applyToOracle(_ClearSequentialOracle oracle) {
    return oracle.apply(this);
  }
}

final class _ClearTraceResult {
  const _ClearTraceResult._({
    required this.kind,
    this.elementId,
    this.changed,
    this.clearResult,
  });

  factory _ClearTraceResult.added(CanvasElementId id) {
    return _ClearTraceResult._(
      kind: _ClearTraceActionKind.addElement,
      elementId: id,
    );
  }

  factory _ClearTraceResult.changed(
    _ClearTraceActionKind kind, {
    required bool changed,
  }) {
    return _ClearTraceResult._(kind: kind, changed: changed);
  }

  factory _ClearTraceResult.cleared(CanvasClearResult result) {
    return _ClearTraceResult._(
      kind: _ClearTraceActionKind.clearContent,
      clearResult: result,
    );
  }

  final _ClearTraceActionKind kind;
  final CanvasElementId? elementId;
  final bool? changed;
  final CanvasClearResult? clearResult;
}

final class _ClearSequentialOracle {
  _ClearSequentialOracle(
    CanvasDocument seed, {
    required Set<CanvasElementId> selectedElementIds,
  }) : _background = seed.background,
       _backgroundElements = List.of(seed.backgroundElements),
       _resources = List.of(seed.resources),
       _layers = [
         for (final layer in seed.layers)
           _ClearOracleLayer(layer.id, List.of(layer.elements)),
       ],
       _selectedElementIds = selectedElementIds;

  final CanvasBackground _background;
  final List<CanvasElement> _backgroundElements;
  final List<CanvasResource> _resources;
  final List<_ClearOracleLayer> _layers;
  final Set<CanvasElementId> _selectedElementIds;
  final effects = _ClearTraceEffects();

  _ClearTraceResult apply(_ClearTraceAction action) {
    return switch (action.kind) {
      _ClearTraceActionKind.addElement => _addElement(
        action.value as CanvasElement,
      ),
      _ClearTraceActionKind.upsertResource => _upsertResource(
        action.value as CanvasResource,
      ),
      _ClearTraceActionKind.removeUnusedResource => _removeUnusedResource(
        action.value as CanvasResourceId,
      ),
      _ClearTraceActionKind.clearContent => _clearContent(
        removeUnusedResources: action.value as bool,
      ),
    };
  }

  _ClearTraceResult _addElement(CanvasElement element) {
    _layers.last.elements.add(element);
    effects.addedElementIds.add(element.id);
    effects.structural = true;

    return _ClearTraceResult.added(element.id);
  }

  _ClearTraceResult _upsertResource(CanvasResource resource) {
    final index = _resources.indexWhere((item) => item.id == resource.id);
    if (index >= 0) {
      _resources[index] = resource;
    } else {
      _resources.add(resource);
    }
    effects.resourceDescriptorChangedIds.add(resource.id);
    effects.resource = true;

    return _ClearTraceResult.changed(
      _ClearTraceActionKind.upsertResource,
      changed: true,
    );
  }

  _ClearTraceResult _removeUnusedResource(CanvasResourceId id) {
    if (_resourceIsReferenced(id)) {
      return _ClearTraceResult.changed(
        _ClearTraceActionKind.removeUnusedResource,
        changed: false,
      );
    }
    final resourceCountBefore = _resources.length;
    _resources.removeWhere((resource) => resource.id == id);
    final removed = _resources.length < resourceCountBefore;
    if (removed) {
      effects.resourceDescriptorChangedIds.add(id);
      effects.resource = true;
    }

    return _ClearTraceResult.changed(
      _ClearTraceActionKind.removeUnusedResource,
      changed: removed,
    );
  }

  _ClearTraceResult _clearContent({required bool removeUnusedResources}) {
    final removedElementIds = [
      for (final layer in _layers)
        ...layer.elements.map((element) => element.id),
    ];
    for (final layer in _layers) {
      layer.elements.clear();
    }
    if (removedElementIds.isNotEmpty) {
      effects.removedElementIds.addAll(removedElementIds);
      effects.selection =
          effects.selection ||
          removedElementIds.any(_selectedElementIds.contains);
      effects.structural = true;
    }
    final removedResourceIds = removeUnusedResources
        ? _removeResourcesNotReferencedByBackground()
        : const <CanvasResourceId>[];
    if (removedResourceIds.isNotEmpty) {
      effects.resourceDescriptorChangedIds.addAll(removedResourceIds);
      effects.resource = true;
    }

    return _ClearTraceResult.cleared(
      CanvasClearResult(
        removedElementIds: removedElementIds,
        removedResourceIds: removedResourceIds,
        didClearContent:
            removedElementIds.isNotEmpty || removedResourceIds.isNotEmpty,
      ),
    );
  }

  List<CanvasResourceId> _removeResourcesNotReferencedByBackground() {
    final retainedIds = <CanvasResourceId>{
      for (final element in _backgroundElements)
        if (element
            case CanvasImageElement(:final resourceId) ||
                CanvasVectorElement(:final resourceId))
          resourceId,
    };
    final removedIds = <CanvasResourceId>[];
    _resources.removeWhere((resource) {
      if (retainedIds.contains(resource.id)) {
        return false;
      }
      removedIds.add(resource.id);

      return true;
    });

    return removedIds;
  }

  bool _resourceIsReferenced(CanvasResourceId id) {
    return [
      ..._backgroundElements,
      for (final layer in _layers) ...layer.elements,
    ].any(
      (element) => switch (element) {
        CanvasImageElement(:final resourceId) ||
        CanvasVectorElement(:final resourceId) => resourceId == id,
        _ => false,
      },
    );
  }

  CanvasDocument toDocument() {
    return CanvasDocument(
      background: _background,
      resources: _resources,
      backgroundElements: _backgroundElements,
      layers: [
        for (final layer in _layers)
          CanvasLayer(id: layer.id, elements: layer.elements),
      ],
    );
  }
}

final class _ClearOracleLayer {
  _ClearOracleLayer(this.id, this.elements);

  final CanvasLayerId id;
  final List<CanvasElement> elements;
}

final class _ClearTraceEffects {
  final Set<CanvasElementId> addedElementIds = {};
  final Set<CanvasElementId> removedElementIds = {};
  final Set<CanvasResourceId> resourceDescriptorChangedIds = {};
  bool selection = false;
  bool structural = false;
  bool resource = false;
}

final class _SparseClearTraceOutcome {
  const _SparseClearTraceOutcome({
    required this.actualResults,
    required this.expectedResults,
    required this.sparseCommit,
    required this.document,
    required this.expectedDocument,
    required this.session,
    required this.expectedEffects,
  });

  final List<_ClearTraceResult> actualResults;
  final List<_ClearTraceResult> expectedResults;
  final StoreSparseCommit sparseCommit;
  final CanvasDocument document;
  final CanvasDocument expectedDocument;
  final EditSession session;
  final _ClearTraceEffects expectedEffects;
}

// The fixture implements the complete sparse facts port so sparse-session tests
// exercise the same boundary shape as production store facts.
// ignore: number-of-methods
final class _SparseFixtureFacts implements SparseEditSessionFacts {
  _SparseFixtureFacts(this.document);

  final CanvasDocument document;
  int elementIdsReadCount = 0;
  int resourceIdsReadCount = 0;
  int backgroundElementIdsReadCount = 0;
  int isResourceReferencedReadCount = 0;
  final Map<CanvasElementId, int> _elementByIdReadCounts = {};

  void resetReadCounters() {
    elementIdsReadCount = 0;
    resourceIdsReadCount = 0;
    backgroundElementIdsReadCount = 0;
    isResourceReferencedReadCount = 0;
    _elementByIdReadCounts.clear();
  }

  int elementByIdReadCount(CanvasElementId id) {
    return _elementByIdReadCounts[id] ?? 0;
  }

  @override
  CanvasBackground get background => document.background;

  @override
  CanvasCamera get camera => document.camera;

  @override
  CanvasPalette get palette => document.palette;

  @override
  CanvasDocumentSummary get summary {
    return CanvasDocumentSummary(
      elementCount: document.backgroundElements.length + _contentElementCount,
      layerCount: document.layers.length,
      resourceCount: document.resources.length,
    );
  }

  int get _contentElementCount {
    return document.layers.fold(
      0,
      (count, layer) => count + layer.elements.length,
    );
  }

  @override
  Iterable<CanvasElementId> get backgroundElementIds {
    backgroundElementIdsReadCount += 1;

    return [for (final element in document.backgroundElements) element.id];
  }

  @override
  Iterable<CanvasElementId> get elementIds {
    elementIdsReadCount += 1;

    return [
      for (final element in document.backgroundElements) element.id,
      for (final layer in document.layers)
        for (final element in layer.elements) element.id,
    ];
  }

  @override
  Iterable<CanvasLayerId> get layerIds {
    return [for (final layer in document.layers) layer.id];
  }

  @override
  Iterable<CanvasElementId> elementIdsInLayer(CanvasLayerId id) {
    for (final layer in document.layers) {
      if (layer.id == id) {
        return [for (final element in layer.elements) element.id];
      }
    }

    return const <CanvasElementId>[];
  }

  @override
  bool hasLayer(CanvasLayerId id) {
    return document.layers.any((layer) => layer.id == id);
  }

  @override
  Iterable<CanvasResourceId> get resourceIds {
    resourceIdsReadCount += 1;

    return [for (final resource in document.resources) resource.id];
  }

  @override
  CanvasElement? elementById(CanvasElementId id) {
    _elementByIdReadCounts.update(id, (count) => count + 1, ifAbsent: () => 1);
    for (final element in document.backgroundElements) {
      if (element.id == id) {
        return element;
      }
    }
    for (final layer in document.layers) {
      for (final element in layer.elements) {
        if (element.id == id) {
          return element;
        }
      }
    }

    return null;
  }

  @override
  CanvasResource? resourceById(CanvasResourceId id) {
    for (final resource in document.resources) {
      if (resource.id == id) {
        return resource;
      }
    }

    return null;
  }

  @override
  bool isResourceReferenced(CanvasResourceId id) {
    isResourceReferencedReadCount += 1;

    return elementIds.any((elementId) {
      final element = elementById(elementId);

      return element is CanvasImageElement && element.resourceId == id;
    });
  }
}

CanvasRectElement _rect(String id) {
  return CanvasRectElement(id: CanvasElementId(id), size: const Size(1, 1));
}

CanvasImageResource _resource(String id) {
  return CanvasImageResource(
    id: CanvasResourceId(id),
    source: CanvasResourceSource.appKey(id),
  );
}
