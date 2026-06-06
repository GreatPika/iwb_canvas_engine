import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/edit/draft_document.dart';
import 'package:iwb_canvas_engine/src/edit/edit_session.dart';

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
    CanvasElementId('background-a'),
    CanvasElementId('background-added'),
    CanvasElementId('content-a'),
    CanvasElementId('content-added'),
  ]);
  expect(clear.removedResourceIds, [
    CanvasResourceId('resource-a'),
    CanvasResourceId('resource-added'),
  ]);
  _expectSparseSummary(
    session,
    elementCount: 0,
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
    CanvasElementId('background-first'),
    CanvasElementId('background-a'),
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
  expect(withBackground.commitPlan.touchedSet.backgroundLayerChanged, isTrue);
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
    () => session.addElement(
      CanvasImageElement(
        id: CanvasElementId('image-missing'),
        resourceId: CanvasResourceId('missing'),
        size: const Size(1, 1),
      ),
    ),
    throwsA(isA<CanvasDataException>()),
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

// The fixture implements the complete sparse facts port so sparse-session tests
// exercise the same boundary shape as production store facts.
// ignore: number-of-methods
final class _SparseFixtureFacts implements SparseEditSessionFacts {
  _SparseFixtureFacts(this.document);

  final CanvasDocument document;
  int elementIdsReadCount = 0;
  int resourceIdsReadCount = 0;

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
