import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

void main() {
  _registerSparseStoreCommitTests();
}

void _registerSparseStoreCommitTests() {
  group('sparse store commit prepare/install', () {
    _registerSparseInstallTests();
    _registerSparseValidationTests();
  });
}

void _registerSparseInstallTests() {
  test(
    'adds elements and layers without building public projection',
    () => expect(_addsElementsAndLayersWithoutProjection, returnsNormally),
  );
  test(
    'updates visual and transform facts in place',
    () => expect(_updatesFactsInPlace, returnsNormally),
  );
  test(
    'no-op and missing-id updates leave committed facts unchanged',
    () => expect(_noOpAndMissingIdUpdatesLeaveFactsUnchanged, returnsNormally),
  );
  test(
    'resource upsert descriptors use accepted resource revision',
    () => expect(_resourceDescriptorsUseAcceptedRevision, returnsNormally),
  );
  test(
    'clears content and can remove unused resources',
    () => expect(_clearsContentAndResources, returnsNormally),
  );
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
}

void _registerSparseValidationTests() {
  test(
    'validates duplicate ids and image resource references before swap',
    () => expect(_validatesAddFailuresBeforeSwap, returnsNormally),
  );
  test(
    'rejects committed sparse deltas without projection invalidation',
    () => expect(_rejectsSparseRevisionDeltaWithoutProjection, returnsNormally),
  );
  test(
    'rejects sparse deltas that do not match changed fact families',
    () => expect(_rejectsSparseRevisionDeltaFamilyMismatch, returnsNormally),
  );
  test(
    'validates image update resources before swap',
    () => expect(_validatesUpdateFailuresBeforeSwap, returnsNormally),
  );
}

void _addsElementsAndLayersWithoutProjection() {
  final store = DocumentStoreKernel(_baseDocument());

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

  final facts = _requireFacts(store, CanvasElementId('e-new'));
  expect(facts.layerId, CanvasLayerId('layer-b'));
  expect(facts.size, const Size(8, 9));
  expect(store.documentSummary.elementCount, 4);
  expect(store.documentSummary.layerCount, 2);
  expect(store.projectionBuildCount, 0);
}

void _updatesFactsInPlace() {
  final store = DocumentStoreKernel(_baseDocument());

  store.installSparseCommit(
    store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.elementBounds(),
        mutations: [
          StoreSparseUpdateElement(
            CanvasRectElement(
              id: CanvasElementId('e-content'),
              size: const Size(4, 5),
              revision: 1,
              transform: CanvasTransform.translation(const Offset(1, 1)),
              fillColor: const Color(0xFF00FF00),
            ),
          ),
        ],
      ),
    ),
  );

  final facts = _requireFacts(store, CanvasElementId('e-content'));
  expect(facts.transform, CanvasTransform.translation(const Offset(1, 1)));
  expect(facts.fillColor, const Color(0xFF00FF00));
  expect(facts.revision, 1);
  expect(store.projectionBuildCount, 0);
}

void _noOpAndMissingIdUpdatesLeaveFactsUnchanged() {
  final store = DocumentStoreKernel(_baseDocument());
  final beforeRevision = store.documentRevision;
  final beforeProjectionBuilds = store.projectionBuildCount;

  final noOp = store.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.elementVisual(),
      mutations: [
        StoreSparseUpdateElement(
          CanvasRectElement(
            id: CanvasElementId('e-content'),
            size: const Size(4, 5),
            fillColor: const Color(0xFFFF0000),
          ),
        ),
        StoreSparseUpdateElement(
          CanvasRectElement(
            id: CanvasElementId('missing'),
            size: const Size(1, 1),
            fillColor: const Color(0xFF123456),
          ),
        ),
      ],
    ),
  );

  store.installSparseCommit(noOp);

  expect(noOp.hasChanges, isFalse);
  expect(store.documentRevision, beforeRevision);
  expect(store.projectionBuildCount, beforeProjectionBuilds);
  expect(_requireFacts(store, CanvasElementId('e-content')).revision, 0);
}

void _validatesAddFailuresBeforeSwap() {
  final store = DocumentStoreKernel(_baseDocument());
  final beforeSummary = store.documentSummary;

  expect(_prepareDuplicateAdd(store), throwsA(isA<CanvasDataException>()));
  expect(store.documentSummary, beforeSummary);

  expect(
    _prepareMissingResourceAdd(store),
    throwsA(isA<CanvasDataException>()),
  );
  expect(store.documentSummary, beforeSummary);
  expect(store.projectionBuildCount, 0);
}

void _rejectsSparseRevisionDeltaWithoutProjection() {
  final store = DocumentStoreKernel(_baseDocument());
  store.readDocument();
  expect(store.projectionBuildCount, 1);

  expect(
    () => store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta(
          document: true,
          structural: true,
        ),
        mutations: [
          StoreSparseAddElement(
            element: CanvasRectElement(
              id: CanvasElementId('e-invalid-delta'),
              size: const Size(1, 1),
            ),
          ),
        ],
      ),
    ),
    throwsA(isA<ArgumentError>()),
  );
  expect(store.documentSummary.elementCount, 3);
  expect(store.readDocument().layers.single.elements, hasLength(2));
  expect(store.projectionBuildCount, 1);
}

void _rejectsSparseRevisionDeltaFamilyMismatch() {
  _expectRevisionDeltaRejected(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.elementVisual(),
      mutations: [
        StoreSparseAddElement(
          element: CanvasRectElement(
            id: CanvasElementId('e-wrong-structural'),
            size: const Size(1, 1),
          ),
        ),
      ],
    ),
  );
  _expectRevisionDeltaRejected(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.elementVisual(),
      mutations: [
        StoreSparseUpsertResource(
          CanvasImageResource(
            id: CanvasResourceId('resource-b'),
            source: CanvasResourceSource.appKey('asset-b'),
          ),
        ),
      ],
    ),
  );
  _expectRevisionDeltaRejected(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.elementVisual(),
      mutations: [
        StoreSparseUpdateElement(
          CanvasRectElement(
            id: CanvasElementId('e-content'),
            size: const Size(44, 55),
            fillColor: const Color(0xFFFF0000),
          ),
        ),
      ],
    ),
  );
}

void _expectRevisionDeltaRejected(StoreSparseCommit commit) {
  final store = DocumentStoreKernel(_baseDocument());
  final beforeSummary = store.documentSummary;

  expect(
    () => store.prepareSparseCommit(commit),
    throwsA(isA<ArgumentError>()),
  );
  expect(store.documentSummary, beforeSummary);
  expect(store.projectionBuildCount, 0);
}

void _validatesUpdateFailuresBeforeSwap() {
  final store = DocumentStoreKernel(_baseDocument());
  final beforeFacts = _requireFacts(store, CanvasElementId('e-image'));

  expect(
    _prepareMissingResourceUpdate(store),
    throwsA(isA<CanvasDataException>()),
  );
  expect(
    _requireFacts(store, CanvasElementId('e-image')).resourceId,
    beforeFacts.resourceId,
  );
  expect(store.projectionBuildCount, 0);
}

void _resourceDescriptorsUseAcceptedRevision() {
  final store = DocumentStoreKernel(_baseDocument());

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

  expect(store.resourceRevision, 1);
  expect(
    store.resourceDescriptor(CanvasResourceId('resource-a'))?.resourceRevision,
    1,
  );
}

void _clearsContentAndResources() {
  final store = DocumentStoreKernel(_baseDocument());

  store.installSparseCommit(
    store.prepareSparseCommit(
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
    ),
  );

  expect(store.documentSummary.elementCount, 0);
  expect(store.documentSummary.layerCount, 1);
  expect(store.documentSummary.resourceCount, 0);
  expect(store.elementFactsById(CanvasElementId('e-content')), isNull);
  expect(store.projectionBuildCount, 0);

  final noOpClear = store.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.structural(),
      mutations: const [StoreSparseClearContent(removeUnusedResources: true)],
    ),
  );
  expect(noOpClear.hasChanges, isFalse);
}

void _normalizesSelectionAgainstPreparedSparseCommit() {
  final store = DocumentStoreKernel(_baseDocument());
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

void _replacementFallbackInstallsFullFacts() {
  final store = DocumentStoreKernel(_baseDocument());

  store.replaceDocument(
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
    const StoreRevisionDelta.structural(),
  );

  expect(store.documentSummary.elementCount, 1);
  expect(store.documentSummary.layerCount, 1);
  expect(
    _requireFacts(store, CanvasElementId('replacement-element')).size,
    const Size(10, 11),
  );
  expect(store.projectionBuildCount, 0);
  store.readDocument();
  expect(store.projectionBuildCount, 1);
}

void Function() _prepareDuplicateAdd(DocumentStoreKernel store) {
  return () => store.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.structural(),
      mutations: [
        StoreSparseAddElement(
          element: CanvasRectElement(
            id: CanvasElementId('e-content'),
            size: const Size(1, 1),
          ),
        ),
      ],
    ),
  );
}

void Function() _prepareMissingResourceAdd(DocumentStoreKernel store) {
  return () => store.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.structural(),
      mutations: [
        StoreSparseAddElement(
          element: CanvasImageElement(
            id: CanvasElementId('e-missing-resource'),
            resourceId: CanvasResourceId('missing'),
            size: const Size(1, 1),
          ),
        ),
      ],
    ),
  );
}

void Function() _prepareMissingResourceUpdate(DocumentStoreKernel store) {
  return () => store.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.elementVisual(),
      mutations: [
        StoreSparseUpdateElement(
          CanvasImageElement(
            id: CanvasElementId('e-image'),
            resourceId: CanvasResourceId('missing'),
            size: const Size(6, 7),
          ),
        ),
      ],
    ),
  );
}

StoreElementFacts _requireFacts(DocumentStoreKernel store, CanvasElementId id) {
  final facts = store.elementFactsById(id);
  expect(facts, isNotNull);

  return facts as StoreElementFacts;
}

CanvasDocument _baseDocument() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('resource-a'),
        source: CanvasResourceSource.appKey('asset-a'),
      ),
    ],
    backgroundElements: [
      CanvasRectElement(
        id: CanvasElementId('e-background'),
        size: const Size(2, 3),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('e-content'),
            size: const Size(4, 5),
            fillColor: const Color(0xFFFF0000),
          ),
          CanvasImageElement(
            id: CanvasElementId('e-image'),
            resourceId: CanvasResourceId('resource-a'),
            size: const Size(6, 7),
          ),
        ],
      ),
    ],
  );
}
