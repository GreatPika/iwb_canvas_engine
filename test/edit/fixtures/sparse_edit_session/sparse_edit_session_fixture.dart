import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/edit/draft_document.dart';
import 'package:iwb_canvas_engine/src/edit/edit_session.dart';

import 'sparse_edit_session_support.dart';
import 'sparse_edit_session_aggregate_fixture.dart';
import 'sparse_edit_session_parity_fixture.dart';
import 'sparse_edit_session_resource_fixture.dart';
import 'sparse_edit_session_structure_fixture.dart';

void main() {
  group('sparse edit session seam', () {
    _registerSparseSummaryTests();
    _registerSparsePromotionTests();
    registerSparseEditSessionStructureTests();
    registerSparseEditSessionResourceTests();
    registerSparseEditSessionParityTests();
    _registerSparseMutationTests();
    registerSparseEditSessionAggregateTest();
  });
}

void _registerSparseMutationTests() {
  test(
    'stale sparse handles reject every public entry point',
    () => expect(_staleSparseHandleRejected, returnsNormally),
  );
  test(
    'sparse mutations preserve no-op and validation semantics',
    () => expect(_sparseMutationsPreserveNoOpAndValidation, returnsNormally),
  );
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
    'sparse clear reports indexed insertions in draft order',
    () => expect(
      _sparseClearReportsIndexedInsertionsInDraftOrder,
      returnsNormally,
    ),
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
  final session = sparseSession(baseSparseDraft);

  expect(session.ensureLayer(CanvasLayerId('layer-added'), index: 0), isTrue);
  expect(session.ensureLayer(CanvasLayerId('layer-empty'), index: 1), isTrue);
  expect(session.ensureLayer(CanvasLayerId('layer-added'), index: 0), isFalse);
  expect(session.upsertResource(sparseImageResource('resource-a')), isFalse);
  session.setBackgroundColor(const Color(0xFFFFFFFF));
  session.addBackgroundElement(sparseRect('background-first'), index: 0);
  session.addBackgroundElement(sparseRect('background-second'), index: 0);
  session.addElement(
    sparseRect('content-first'),
    layerId: CanvasLayerId('layer-added'),
    index: 0,
  );
  session.addElement(
    sparseRect('content-second'),
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
  expect(
    session.upsertResource(sparseImageResource('resource-retained')),
    isTrue,
  );
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
  var appliedMutationCount = 0;
  var appliedMutationsMatch = true;
  final document = DraftDocument.observeSparseMutationApplications((mutation) {
    if (appliedMutationCount >= mutations.length ||
        !identical(mutation, mutations[appliedMutationCount])) {
      appliedMutationsMatch = false;
    }
    appliedMutationCount += 1;
  }, () => observeSparsePromotionWork(events.add, session.readDraftDocument));

  expect(mutations, hasLength(14));
  expect(appliedMutationCount, mutations.length);
  expect(appliedMutationsMatch, isTrue);
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
  final directWork = <DraftResourceWorkEvent>[];
  late CanvasClearResult directClear;
  observeDraftResourceWork(directWork.add, () {
    final draft = baseSparseDraft();
    directClear = draft.clearContent(removeUnusedResources: true);
    draft.readDocument();
  });
  final session = sparseSession(baseSparseDraft);

  final clear = session.clearContent(removeUnusedResources: true);
  expect(clear.didClearContent, isTrue);
  expect(clear.removedElementIds, [CanvasElementId('content-a')]);
  expect(clear.removedResourceIds, [CanvasResourceId('resource-a')]);

  final promotionWork = <DraftResourceWorkEvent>[];
  final document = observeDraftResourceWork(
    promotionWork.add,
    session.readDraftDocument,
  );

  expect(clear.removedElementIds, directClear.removedElementIds);
  expect(clear.removedResourceIds, directClear.removedResourceIds);
  expect(
    promotionWork.map((event) => event.kind),
    directWork.map((event) => event.kind),
  );
  expect(document.backgroundElements.map((element) => element.id), [
    CanvasElementId('background-a'),
  ]);
  expect(document.layers.single.elements, isEmpty);
  expect(document.resources, isEmpty);
}

void _draftSummaryOpensWithoutCommittedIdEnumeration() {
  final facts = SparseFixtureFacts(baseSparseDocument());
  final session = EditSession.sparse(
    facts: facts,
    promoteDraft: baseSparseDraft,
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

// One ordered public summary transition trace keeps each observation in state order.
// ignore: halstead-volume
void _draftSummaryTracksSparseMutations() {
  var materializations = 0;
  final session = sparseSession(() {
    materializations += 1;

    return baseSparseDraft();
  });

  expect(session.draftSummary.elementCount, 2);
  expect(session.draftSummary.layerCount, 1);
  expect(
    session.addBackgroundElement(sparseRect('background-added')),
    CanvasElementId('background-added'),
  );
  expect(
    session.addElement(sparseRect('content-added')),
    CanvasElementId('content-added'),
  );
  expect(session.upsertResource(sparseImageResource('resource-added')), isTrue);
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
  final session = sparseSession(() {
    materializations += 1;

    return baseSparseDraft();
  });

  session.addBackgroundElement(sparseRect('background-first'), index: 0);
  session.addElement(
    sparseRect('content-first'),
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

void _mutationsAfterPromotionUseMaterializedFallback() {
  var materializations = 0;
  final session = sparseSession(() {
    materializations += 1;

    return baseSparseDraft();
  });

  session.addElement(
    sparseRect('content-added'),
    layerId: CanvasLayerId('layer-a'),
  );
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
  final session = sparseSession(() {
    materializations += 1;

    return baseSparseDraft();
  });

  session.replaceDraftDocument(
    CanvasDocument(backgroundElements: [sparseRect('replacement')]),
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
  final session = sparseSession(baseSparseDraft);

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
  expect(session.upsertResource(sparseImageResource('resource-a')), isFalse);
  expect(session.removeUnusedResource(CanvasResourceId('missing')), isFalse);
}

void _expectSparseDocumentNoOps(EditSession session) {
  _expectClearNoOpKeepsSparseSessionClean(CanvasDocument());
  _expectClearNoOpKeepsSparseSessionClean(
    CanvasDocument(resources: [sparseImageResource('resource-a')]),
  );
  session.setCameraOffset(Offset.zero);
  session.setPalette(const CanvasPalette.defaults());
  session.setBackgroundColor(const Color(0xFFFFFFFF));
  session.setGrid(CanvasGrid());
  expect(session.didChange, isFalse);
}

void _expectClearNoOpKeepsSparseSessionClean(CanvasDocument document) {
  final session = sparseSessionForDocument(document);

  expect(session.clearContent().didClearContent, isFalse);
  expect(session.didChange, isFalse);
}

void _expectSparseValidationFailures() {
  final session = sparseSession(baseSparseDraft);

  expect(
    () => session.addElement(sparseRect('content-a')),
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
  final session = sparseSession(baseSparseDraft)..close();

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
  expect(() => session.addElement(sparseRect('next')), throwsStateError);
  expect(
    () => session.addBackgroundElement(sparseRect('next-bg')),
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
    () => session.upsertResource(sparseImageResource('resource-b')),
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
