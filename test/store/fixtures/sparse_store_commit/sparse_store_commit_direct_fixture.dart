// Direct Store acceptance keeps public values, committed backing, sparse
// preparation, finalization, and structural work owners explicit in one
// fixture; hiding them behind an import barrel would obscure this boundary.
// ignore_for_file: number-of-imports

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/element_registry.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
import 'package:iwb_canvas_engine/src/store/store_commit_finalization.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

import '../../../support/document_store_with_document.dart';
import 'sparse_store_commit_support.dart';

// Direct Store acceptance scenarios; resource, journal, and rejection
// witnesses live beside their respective owner seams.
void registerSparseInstallTests() {
  test(
    'adds elements and layers without building public projection',
    () => expect(_addsElementsAndLayersWithoutProjection, returnsNormally),
  );
  _registerSparseUpdateInstallTests();
  test(
    'normalizes selection against prepared sparse commit before install',
    () => expect(
      _normalizesSelectionAgainstPreparedSparseCommit,
      returnsNormally,
    ),
  );
  test(
    'replacement fallback still installs full committed facts',
    () => expect(_replacementFallbackInstallsFullFacts, returnsNormally),
  );
  test(
    'removes only existing empty layers through sparse Store preparation',
    () => expect(_removesOnlyExistingEmptyLayers, returnsNormally),
  );
  test(
    'empty-layer removal finalizes only layer ownership',
    () =>
        expect(_emptyLayerRemovalFinalizesOnlyLayerOwnership, returnsNormally),
  );
}

void _registerSparseUpdateInstallTests() {
  test(
    'updates visual and transform facts in place',
    () => expect(_updatesFactsInPlace, returnsNormally),
  );
  test(
    'installs batched sparse element updates',
    () => expect(_installsBatchedSparseElementUpdates, returnsNormally),
  );
  test(
    'no-op and missing-id updates leave committed facts unchanged',
    () => expect(_noOpAndMissingIdUpdatesLeaveFactsUnchanged, returnsNormally),
  );
  test(
    'compensating sparse candidates prepare as final no-ops',
    () => expect(_compensatingSparseCandidatesPrepareAsNoOps, returnsNormally),
  );
}

void _addsElementsAndLayersWithoutProjection() {
  final store = documentStoreWithDocument(baseDocument());

  final prepared = store.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.structural(),
      mutations: [
        StoreSparseEnsureLayer(CanvasLayerId('layer-b')),
        StoreSparseAddElement(
          element: CanvasRectElement(
            id: CanvasElementId('e-new'),
            size: const Size(8, 9),
          ),
          layerId: CanvasLayerId('layer-b'),
        ),
      ],
    ),
  );
  expect(store.projectionBuildCount, 0);

  store.installSparseCommit(prepared);

  final facts = requireFacts(store, CanvasElementId('e-new'));
  expect(facts.layerId, CanvasLayerId('layer-b'));
  expect(facts.size, const Size(8, 9));
  expect(store.documentSummary.elementCount, 4);
  expect(store.documentSummary.layerCount, 2);
  expect(store.projectionBuildCount, 0);
}

// This store admission scenario keeps the input row, explicit revision family,
// and installed facts together; splitting it would hide the checked handoff.
// ignore: halstead-volume
void _updatesFactsInPlace() {
  final store = documentStoreWithDocument(baseDocument());

  store.installSparseCommit(
    store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.elementBounds(),
        mutations: [
          sparseUpdate(
            before: CanvasRectElement(
              id: CanvasElementId('e-content'),
              size: const Size(4, 5),
              fillColor: const Color(0xFFFF0000),
            ),
            after: CanvasRectElement(
              id: CanvasElementId('e-content'),
              size: const Size(4, 5),
              revision: 1,
              transform: CanvasTransform.translation(const Offset(1, 1)),
              fillColor: const Color(0xFF00FF00),
            ),
            elementRevisionDelta: const StoreRevisionDelta.elementBounds(),
          ),
        ],
      ),
    ),
  );

  final facts = requireFacts(store, CanvasElementId('e-content'));
  expect(facts.transform, CanvasTransform.translation(const Offset(1, 1)));
  expect(facts.fillColor, const Color(0xFF00FF00));
  expect(facts.revision, 1);
  expect(store.projectionBuildCount, 0);
}

void _installsBatchedSparseElementUpdates() {
  final store = documentStoreWithDocument(multiRectDocument());

  store.installSparseCommit(
    store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.elementVisual(),
        mutations: [
          sparseRectFillColorUpdate(
            id: 'rect-a',
            size: const Size(2, 2),
            fillColor: const Color(0xFF00FF00),
          ),
          sparseRectFillColorUpdate(
            id: 'rect-b',
            size: const Size(3, 3),
            fillColor: const Color(0xFF0000FF),
          ),
        ],
      ),
    ),
  );

  expect(
    requireFacts(store, CanvasElementId('rect-a')).fillColor,
    const Color(0xFF00FF00),
  );
  expect(
    requireFacts(store, CanvasElementId('rect-b')).fillColor,
    const Color(0xFF0000FF),
  );
  expect(requireFacts(store, CanvasElementId('rect-a')).revision, 1);
  expect(requireFacts(store, CanvasElementId('rect-b')).revision, 1);
}

void _noOpAndMissingIdUpdatesLeaveFactsUnchanged() {
  final store = documentStoreWithDocument(baseDocument());
  final beforeRevision = store.documentRevision;
  final beforeProjectionBuilds = store.projectionBuildCount;

  final noOp = store.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.elementVisual(),
      mutations: [
        sparseUpdate(
          before: contentRect(),
          after: contentRect(),
          elementRevisionDelta: const StoreRevisionDelta(),
        ),
        sparseUpdate(
          before: CanvasRectElement(
            id: CanvasElementId('missing'),
            size: const Size(1, 1),
          ),
          after: CanvasRectElement(
            id: CanvasElementId('missing'),
            size: const Size(1, 1),
            revision: 1,
            fillColor: const Color(0xFF123456),
          ),
          elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
        ),
      ],
    ),
  );

  store.installSparseCommit(noOp);

  expect(noOp.hasChanges, isFalse);
  expect(store.documentRevision, beforeRevision);
  expect(store.projectionBuildCount, beforeProjectionBuilds);
  expect(requireFacts(store, CanvasElementId('e-content')).revision, 0);
}

void _compensatingSparseCandidatesPrepareAsNoOps() {
  _expectCompensatingSparseNoOp(_backgroundCompensation());
  _expectCompensatingSparseNoOp(_cameraCompensation());
  _expectCompensatingSparseNoOp(_paletteCompensation());
  _expectCompensatingSparseNoOp(_addRemoveElementCompensation());
  _expectCompensatingSparseNoOp(_resourceCompensation());
}

void _expectCompensatingSparseNoOp(StoreSparseCommit commit) {
  final store = documentStoreWithDocument(baseDocument());
  final beforeDocumentRevision = store.documentRevision;
  final beforeProjectionBuilds = store.projectionBuildCount;
  final prepared = store.prepareSparseCommit(commit);

  expect(prepared.hasChanges, isFalse);
  expect(prepared.revisionDelta, const StoreRevisionDelta());
  expect(prepared.touchedFacts.hasTouches, isFalse);
  expect(store.documentRevision, beforeDocumentRevision);
  expect(store.projectionBuildCount, beforeProjectionBuilds);
}

StoreSparseCommit _backgroundCompensation() {
  return StoreSparseCommit(
    revisionDelta: const StoreRevisionDelta.background(),
    mutations: const [
      StoreSparseSetBackground(CanvasBackground(color: Color(0xFF112233))),
      StoreSparseSetBackground(CanvasBackground(color: Color(0xFFFFFFFF))),
    ],
  );
}

StoreSparseCommit _cameraCompensation() {
  return StoreSparseCommit(
    revisionDelta: const StoreRevisionDelta.projectionOnly(),
    mutations: [
      StoreSparseSetCamera(CanvasCamera(offset: const Offset(4, 5))),
      StoreSparseSetCamera(CanvasCamera()),
    ],
  );
}

StoreSparseCommit _paletteCompensation() {
  return StoreSparseCommit(
    revisionDelta: const StoreRevisionDelta.projectionOnly(),
    mutations: [
      StoreSparseSetPalette(alternatePalette()),
      const StoreSparseSetPalette(CanvasPalette.defaults()),
    ],
  );
}

StoreSparseCommit _addRemoveElementCompensation() {
  return StoreSparseCommit(
    revisionDelta: const StoreRevisionDelta.structural(),
    mutations: [
      StoreSparseAddElement(
        element: CanvasRectElement(
          id: CanvasElementId('temporary'),
          size: const Size(1, 1),
        ),
        layerId: CanvasLayerId('layer-a'),
      ),
      StoreSparseRemoveElement(CanvasElementId('temporary')),
    ],
  );
}

StoreSparseCommit _resourceCompensation() {
  return StoreSparseCommit(
    revisionDelta: const StoreRevisionDelta.resource(),
    mutations: [
      StoreSparseUpsertResource(
        CanvasImageResource(
          id: CanvasResourceId('resource-a'),
          source: CanvasResourceSource.appKey('asset-b'),
        ),
      ),
      StoreSparseUpsertResource(
        CanvasImageResource(
          id: CanvasResourceId('resource-a'),
          source: CanvasResourceSource.appKey('asset-a'),
        ),
      ),
    ],
  );
}

void _removesOnlyExistingEmptyLayers() {
  final emptyId = CanvasLayerId('empty-layer');
  final document = _emptyLayerDocument(emptyId);
  final store = documentStoreWithDocument(document);
  _expectRejectedEmptyLayerRemovals(store);
  _expectAcceptedEmptyLayerRemoval(store, emptyId);
  _expectLayerRecreationIsSilent(document, emptyId);
}

void _emptyLayerRemovalFinalizesOnlyLayerOwnership() {
  final events = <ElementRegistryStructuralEditorWorkEvent>[];
  final store = documentStoreWithDocument(
    _emptyLayerDocument(CanvasLayerId('empty-layer')),
  );
  final prepared = ElementRegistry.observeSparseStructuralEditorWork(
    events.add,
    () => store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.layerStructural(),
        mutations: [StoreSparseRemoveEmptyLayer(CanvasLayerId('empty-layer'))],
      ),
    ),
  );
  expect(prepared.hasChanges, isTrue);
  expect(
    events
        .where(
          (event) =>
              event.kind ==
              ElementRegistryStructuralEditorWorkKind.finalTraversalVisit,
        )
        .map((event) => event.order),
    everyElement(ElementRegistryStructuralOrderKind.layer),
  );
}

CanvasDocument _emptyLayerDocument(CanvasLayerId emptyId) {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('retained-resource'),
        source: CanvasResourceSource.appKey('retained-resource'),
      ),
    ],
    backgroundElements: [
      CanvasImageElement(
        id: CanvasElementId('retained-background'),
        resourceId: CanvasResourceId('retained-resource'),
        size: const Size(1, 1),
      ),
    ],
    layers: [
      CanvasLayer(id: CanvasLayerId('before')),
      CanvasLayer(id: emptyId),
      CanvasLayer(
        id: CanvasLayerId('nonempty-layer'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('retained-content'),
            size: const Size(1, 1),
          ),
        ],
      ),
      CanvasLayer(id: CanvasLayerId('after')),
    ],
  );
}

void _expectRejectedEmptyLayerRemovals(DocumentStoreKernel store) {
  for (final id in [
    CanvasLayerId('missing'),
    CanvasLayerId('nonempty-layer'),
  ]) {
    final prepared = store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.layerStructural(),
        mutations: [StoreSparseRemoveEmptyLayer(id)],
      ),
    );
    expect(prepared.hasChanges, isFalse);
    expect(prepared.touchedFacts.hasTouches, isFalse);
  }
}

// This one Store acceptance trace keeps the prepared facts, install, and ID
// reuse assertions together so the structural owner seam remains explicit.
// ignore: halstead-volume, source-lines-of-code, reason: The direct Store handoff is safer to verify as one lifecycle trace.
void _expectAcceptedEmptyLayerRemoval(
  DocumentStoreKernel store,
  CanvasLayerId emptyId,
) {
  final beforeRevision = store.documentRevision;
  final prepared = store.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.layerStructural(),
      mutations: [StoreSparseRemoveEmptyLayer(emptyId)],
    ),
  );
  expect(prepared.revisionDelta.structural, isTrue);
  expect(prepared.touchedFacts.layerIds, {emptyId});
  store.installSparseCommit(prepared);
  expect(store.documentRevision, beforeRevision + 1);
  expect(store.layerIds, [
    CanvasLayerId('before'),
    CanvasLayerId('nonempty-layer'),
    CanvasLayerId('after'),
  ]);
  expect(store.backgroundElementIds, [CanvasElementId('retained-background')]);
  expect(store.resourceIds, contains(CanvasResourceId('retained-resource')));
  final repeated = store.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.layerStructural(),
      mutations: [StoreSparseRemoveEmptyLayer(emptyId)],
    ),
  );
  expect(repeated.hasChanges, isFalse);
  final recreated = store.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.layerStructural(),
      mutations: [StoreSparseEnsureLayer(emptyId, index: 1)],
    ),
  );
  store.installSparseCommit(recreated);
  expect(store.layerIds, [
    CanvasLayerId('before'),
    emptyId,
    CanvasLayerId('nonempty-layer'),
    CanvasLayerId('after'),
  ]);
}

// Equality, moved-location acceptance, and the next removal share one Store
// candidate lifecycle; splitting them would hide final-candidate semantics.
// ignore: halstead-volume, source-lines-of-code, maintainability-index, reason: One structural Store trace keeps compensation and moved-ID facts together.
void _expectLayerRecreationIsSilent(
  CanvasDocument document,
  CanvasLayerId emptyId,
) {
  final compensatedStore = documentStoreWithDocument(document);
  final compensated = compensatedStore.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.layerStructural(),
      mutations: [
        StoreSparseRemoveEmptyLayer(emptyId),
        StoreSparseEnsureLayer(emptyId, index: 1),
      ],
    ),
  );
  expect(compensated.hasChanges, isFalse);
  expect(compensated.touchedFacts.hasTouches, isFalse);

  final materializedMovedDocument = CanvasDocument(
    camera: document.camera,
    background: document.background,
    palette: document.palette,
    resources: document.resources,
    backgroundElements: document.backgroundElements,
    layers: [
      document.layers[1],
      document.layers[0],
      ...document.layers.skip(2),
    ],
    metadata: document.metadata,
  );
  final unboundedMaterializedStore = documentStoreWithDocument(document);
  final unboundedMaterialized = unboundedMaterializedStore
      .prepareMaterializedCommit(
        materializedMovedDocument,
        const StoreRevisionDelta.layerStructural(),
      );
  expect(unboundedMaterialized.touchedFacts.layerIds, {
    emptyId,
    CanvasLayerId('before'),
  });
  final boundedMaterializedStore = documentStoreWithDocument(document);
  final boundedMaterialized = boundedMaterializedStore
      .prepareMaterializedCommit(
        materializedMovedDocument,
        const StoreRevisionDelta.layerStructural(),
        candidates: MaterializedStoreCommitCandidates(layerIds: [emptyId]),
      );
  expect(boundedMaterialized.touchedFacts.layerIds, {emptyId});

  final movedStore = documentStoreWithDocument(document);
  final beforeMovedRevision = movedStore.documentRevision;
  final moved = movedStore.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.layerStructural(),
      mutations: [
        StoreSparseRemoveEmptyLayer(emptyId),
        StoreSparseEnsureLayer(emptyId, index: 0),
      ],
    ),
  );
  expect(moved.hasChanges, isTrue);
  expect(moved.touchedFacts.layerIds, {emptyId});
  movedStore.installSparseCommit(moved);
  expect(movedStore.documentRevision, beforeMovedRevision + 1);
  expect(movedStore.layerIds, [
    emptyId,
    CanvasLayerId('before'),
    CanvasLayerId('nonempty-layer'),
    CanvasLayerId('after'),
  ]);

  final removedAgainStore = documentStoreWithDocument(document);
  final removedAgain = removedAgainStore.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.layerStructural(),
      mutations: [
        StoreSparseRemoveEmptyLayer(emptyId),
        StoreSparseEnsureLayer(emptyId, index: 1),
        StoreSparseRemoveEmptyLayer(emptyId),
      ],
    ),
  );
  expect(removedAgain.hasChanges, isTrue);
  removedAgainStore.installSparseCommit(removedAgain);
  expect(removedAgainStore.layerIds, [
    CanvasLayerId('before'),
    CanvasLayerId('nonempty-layer'),
    CanvasLayerId('after'),
  ]);
}

void _normalizesSelectionAgainstPreparedSparseCommit() {
  final store = documentStoreWithDocument(baseDocument());
  final prepared = store.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.structural(),
      mutations: [StoreSparseRemoveElement(CanvasElementId('e-content'))],
    ),
  );

  expect(
    store.normalizeSelectionForSparseCommit(prepared, [
      CanvasElementId('e-content'),
      CanvasElementId('e-image'),
    ]),
    {CanvasElementId('e-image')},
  );
  expect(store.projectionBuildCount, 0);

  store.installSparseCommit(prepared);
  expect(
    () => store.normalizeSelectionForSparseCommit(prepared, [
      CanvasElementId('e-image'),
    ]),
    throwsStateError,
  );
}

// Replacement compatibility owns summary, direct fact, and projection-lazy
// observations in one lifecycle; separating them would obscure which installed
// document supplies each public fact.
// ignore: halstead-volume, maintainability-index
void _replacementFallbackInstallsFullFacts() {
  final store = documentStoreWithDocument(baseDocument());

  store.replaceDocument(
    CommittedDocument(
      CanvasDocument(
        layers: [
          CanvasLayer(
            id: CanvasLayerId('replacement-layer'),
            elements: [
              CanvasRectElement(
                id: CanvasElementId('replacement-element'),
                size: const Size(10, 11),
              ),
            ],
          ),
        ],
      ),
    ),
    const StoreRevisionDelta.structural(),
  );

  expect(store.documentSummary.elementCount, 1);
  expect(store.documentSummary.layerCount, 1);
  expect(
    requireFacts(store, CanvasElementId('replacement-element')).size,
    const Size(10, 11),
  );
  expect(store.projectionBuildCount, 0);
  store.readDocument();
  expect(store.projectionBuildCount, 1);
}
