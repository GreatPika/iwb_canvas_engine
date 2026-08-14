// This direct Store fixture observes independent family, resource, admission,
// and preparation owners. Suppress the file-only import metric instead of
// hiding those dependencies behind a test barrel.
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

import '../../support/document_store_with_document.dart';
import 'family_tables_telemetry.dart';

void main() {
  _registerSparseStoreCommitTests();
}

void _registerSparseStoreCommitTests() {
  group('sparse store commit prepare/install', () {
    _registerSparseInstallTests();
    _registerSparseResourceEditorTests();
    _registerSparseAccountingTests();
    _registerSparseValidationTests();
  });
}

// Install coverage is deliberately registered in journal-facing order so the
// direct Store scenarios remain an auditable group rather than metric shards.
// ignore: source-lines-of-code
void _registerSparseInstallTests() {
  test(
    'adds elements and layers without building public projection',
    () => expect(_addsElementsAndLayersWithoutProjection, returnsNormally),
  );
  _registerSparseUpdateInstallTests();
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
    'keeps layer-only clear as an ordered sparse-store barrier',
    () => expect(_clearBarrierKeepsJournalOrder, returnsNormally),
  );
  test(
    'normalizes selection against prepared sparse commit before install',
    () => expect(
      _normalizesSelectionAgainstPreparedSparseCommit,
      returnsNormally,
    ),
  );
  test(
    'admits sparse ids without scanning the installed document',
    () => expect(_admitsSparseIdsWithoutDocumentScan, returnsNormally),
  );
  test(
    'validates sparse update revision coverage',
    () => expect(_validatesSparseUpdateRevisionCoverage, returnsNormally),
  );
  test(
    'replacement fallback still installs full committed facts',
    () => expect(_replacementFallbackInstallsFullFacts, returnsNormally),
  );
}

void _registerSparseResourceEditorTests() {
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

void _registerSparseAccountingTests() {
  test(
    'uses one sparse replay and admits compensated transient ids',
    () => expect(
      _usesOneSparseReplayAndAdmitsCompensatedTransientIds,
      returnsNormally,
    ),
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

void _registerSparseValidationTests() {
  test(
    'validates image resource relationships against the final candidate before swap',
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
    'rejects revision-only sparse update mutations',
    () => expect(_rejectsRevisionOnlySparseUpdateBeforeSwap, returnsNormally),
  );
  test(
    'rejects sparse update deltas from non-committed rows',
    () => expect(_rejectsSparseUpdateSourceMismatchBeforeSwap, returnsNormally),
  );
  test(
    'validates image update resources before swap',
    () => expect(_validatesUpdateFailuresBeforeSwap, returnsNormally),
  );
  test(
    'rejects stale element revision updates before swap',
    () => expect(_rejectsStaleElementRevisionBeforeSwap, returnsNormally),
  );
}

void _addsElementsAndLayersWithoutProjection() {
  final store = documentStoreWithDocument(_baseDocument());

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

// This store admission scenario keeps the input row, explicit revision family,
// and installed facts together; splitting it would hide the checked handoff.
// ignore: halstead-volume
void _updatesFactsInPlace() {
  final store = documentStoreWithDocument(_baseDocument());

  store.installSparseCommit(
    store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.elementBounds(),
        mutations: [
          _sparseUpdate(
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

  final facts = _requireFacts(store, CanvasElementId('e-content'));
  expect(facts.transform, CanvasTransform.translation(const Offset(1, 1)));
  expect(facts.fillColor, const Color(0xFF00FF00));
  expect(facts.revision, 1);
  expect(store.projectionBuildCount, 0);
}

void _installsBatchedSparseElementUpdates() {
  final store = documentStoreWithDocument(_multiRectDocument());

  store.installSparseCommit(
    store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.elementVisual(),
        mutations: [
          _sparseRectFillColorUpdate(
            id: 'rect-a',
            size: const Size(2, 2),
            fillColor: const Color(0xFF00FF00),
          ),
          _sparseRectFillColorUpdate(
            id: 'rect-b',
            size: const Size(3, 3),
            fillColor: const Color(0xFF0000FF),
          ),
        ],
      ),
    ),
  );

  expect(
    _requireFacts(store, CanvasElementId('rect-a')).fillColor,
    const Color(0xFF00FF00),
  );
  expect(
    _requireFacts(store, CanvasElementId('rect-b')).fillColor,
    const Color(0xFF0000FF),
  );
  expect(_requireFacts(store, CanvasElementId('rect-a')).revision, 1);
  expect(_requireFacts(store, CanvasElementId('rect-b')).revision, 1);
}

void _noOpAndMissingIdUpdatesLeaveFactsUnchanged() {
  final store = documentStoreWithDocument(_baseDocument());
  final beforeRevision = store.documentRevision;
  final beforeProjectionBuilds = store.projectionBuildCount;

  final noOp = store.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.elementVisual(),
      mutations: [
        _sparseUpdate(
          before: _contentRect(),
          after: _contentRect(),
          elementRevisionDelta: const StoreRevisionDelta(),
        ),
        _sparseUpdate(
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
  expect(_requireFacts(store, CanvasElementId('e-content')).revision, 0);
}

void _compensatingSparseCandidatesPrepareAsNoOps() {
  _expectCompensatingSparseNoOp(_backgroundCompensation());
  _expectCompensatingSparseNoOp(_cameraCompensation());
  _expectCompensatingSparseNoOp(_paletteCompensation());
  _expectCompensatingSparseNoOp(_addRemoveElementCompensation());
  _expectCompensatingSparseNoOp(_resourceCompensation());
}

void _expectCompensatingSparseNoOp(StoreSparseCommit commit) {
  final store = documentStoreWithDocument(_baseDocument());
  final beforeDocumentRevision = store.documentRevision;
  final beforeProjectionBuilds = store.projectionBuildCount;
  final prepared = store.prepareSparseCommit(commit);

  expect(prepared.hasChanges, isFalse);
  expect(prepared.revisionDelta, const StoreRevisionDelta());
  expect(prepared.touchedFacts.hasTouches, isFalse);
  expect(prepared.admittedElementIds, isEmpty);
  expect(prepared.admittedLayerIds, isEmpty);
  expect(prepared.admittedResourceIds, isEmpty);
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
      StoreSparseSetPalette(_alternatePalette()),
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

void _validatesAddFailuresBeforeSwap() {
  _acceptsImageAndResourceAddedInEitherOrder();
  _removedResourceBeforeElementAddFailsFinalRelationshipValidation();

  final store = documentStoreWithDocument(_baseDocument());
  final beforeSummary = store.documentSummary;

  expect(_prepareDuplicateAdd(store), throwsA(isA<CanvasDataException>()));
  expect(store.documentSummary, beforeSummary);

  expect(
    _prepareMissingResourceAdd(store),
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
  expect(store.projectionBuildCount, 0);
}

void _removedResourceBeforeElementAddFailsFinalRelationshipValidation() {
  final resourceId = CanvasResourceId('removed-before-add');
  final store = documentStoreWithDocument(
    CanvasDocument(
      resources: [
        CanvasImageResource(
          id: resourceId,
          source: CanvasResourceSource.appKey('removed-before-add'),
        ),
      ],
    ),
  );

  expect(
    () => store.prepareSparseCommit(
      _removedResourceBeforeElementAddCommit(resourceId),
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
  expect(store.resourceDescriptor(resourceId), isNotNull);
  expect(store.projectionBuildCount, 0);
}

StoreSparseCommit _removedResourceBeforeElementAddCommit(
  CanvasResourceId resourceId,
) {
  return StoreSparseCommit(
    revisionDelta: const StoreRevisionDelta.structural().merge(
      const StoreRevisionDelta.resource(),
    ),
    mutations: [
      StoreSparseRemoveUnusedResource(resourceId),
      StoreSparseAddElement(
        element: CanvasImageElement(
          id: CanvasElementId('added-after-removal'),
          resourceId: resourceId,
          size: const Size(1, 1),
        ),
      ),
    ],
  );
}

// Keeping both callback orders together makes their shared final-candidate
// invariant visible as one behavior.
// ignore: halstead-volume
void _acceptsImageAndResourceAddedInEitherOrder() {
  for (final elementFirst in [true, false]) {
    final store = documentStoreWithDocument(_baseDocument());
    final image = CanvasImageElement(
      id: CanvasElementId('e-final-candidate-$elementFirst'),
      resourceId: CanvasResourceId('resource-final-candidate-$elementFirst'),
      size: const Size(1, 1),
    );
    final resource = CanvasImageResource(
      id: image.resourceId,
      source: CanvasResourceSource.appKey(
        'asset-final-candidate-$elementFirst',
      ),
    );
    final mutations = elementFirst
        ? [
            StoreSparseAddElement(element: image),
            StoreSparseUpsertResource(resource),
          ]
        : [
            StoreSparseUpsertResource(resource),
            StoreSparseAddElement(element: image),
          ];

    final prepared = store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.structural().merge(
          const StoreRevisionDelta.resource(),
        ),
        mutations: mutations,
      ),
    );

    store.installSparseCommit(prepared);
    expect(store.elementById(image.id), isA<CanvasImageElement>());
    expect(store.resourceById(image.resourceId), isA<CanvasImageResource>());
  }
}

void _rejectsSparseRevisionDeltaWithoutProjection() {
  final store = documentStoreWithDocument(_baseDocument());
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
  _expectStructuralDeltaRejected();
  _expectResourceDeltaRejected();
  _expectElementBoundsDeltaRejected();
}

void _expectStructuralDeltaRejected() {
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
}

void _expectResourceDeltaRejected() {
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
}

void _expectElementBoundsDeltaRejected() {
  _expectRevisionDeltaRejected(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.elementVisual(),
      mutations: [
        _sparseUpdate(
          before: CanvasRectElement(
            id: CanvasElementId('e-content'),
            size: const Size(4, 5),
            fillColor: const Color(0xFFFF0000),
          ),
          after: CanvasRectElement(
            id: CanvasElementId('e-content'),
            size: const Size(44, 55),
            revision: 1,
            fillColor: const Color(0xFFFF0000),
          ),
          elementRevisionDelta: const StoreRevisionDelta.elementBounds(),
        ),
      ],
    ),
  );
}

void _rejectsRevisionOnlySparseUpdateBeforeSwap() {
  final store = documentStoreWithDocument(_baseDocument());
  final beforeFacts = _requireFacts(store, CanvasElementId('e-content'));

  expect(
    () => store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.elementVisual(),
        mutations: [
          _sparseUpdate(
            before: CanvasRectElement(
              id: CanvasElementId('e-content'),
              size: const Size(4, 5),
              fillColor: const Color(0xFFFF0000),
            ),
            after: CanvasRectElement(
              id: CanvasElementId('e-content'),
              size: const Size(4, 5),
              revision: 1,
              fillColor: const Color(0xFFFF0000),
            ),
            elementRevisionDelta: const StoreRevisionDelta(),
          ),
        ],
      ),
    ),
    throwsA(isA<ArgumentError>()),
  );
  final afterFacts = _requireFacts(store, CanvasElementId('e-content'));
  expect(afterFacts.size, beforeFacts.size);
  expect(afterFacts.fillColor, beforeFacts.fillColor);
  expect(afterFacts.revision, beforeFacts.revision);
  expect(store.projectionBuildCount, 0);
}

void _rejectsSparseUpdateSourceMismatchBeforeSwap() {
  final store = documentStoreWithDocument(_baseDocument());
  final beforeFacts = _requireFacts(store, CanvasElementId('e-content'));
  final beforeBoundsRevision = store.boundsRevision;
  final beforeVisualRevision = store.elementVisualRevision;

  expect(
    () => store.prepareSparseCommit(_sparseUpdateWithMismatchedBefore()),
    throwsA(isA<ArgumentError>()),
  );
  final afterFacts = _requireFacts(store, CanvasElementId('e-content'));
  expect(afterFacts.size, beforeFacts.size);
  expect(afterFacts.fillColor, beforeFacts.fillColor);
  expect(afterFacts.revision, beforeFacts.revision);
  expect(store.boundsRevision, beforeBoundsRevision);
  expect(store.elementVisualRevision, beforeVisualRevision);
  expect(store.projectionBuildCount, 0);
}

StoreSparseCommit _sparseUpdateWithMismatchedBefore() {
  return StoreSparseCommit(
    revisionDelta: const StoreRevisionDelta.elementVisual(),
    mutations: [
      _sparseUpdate(
        before: CanvasRectElement(
          id: CanvasElementId('e-content'),
          size: const Size(44, 55),
          fillColor: const Color(0xFFFF0000),
        ),
        after: CanvasRectElement(
          id: CanvasElementId('e-content'),
          size: const Size(44, 55),
          revision: 1,
          fillColor: const Color(0xFF00FF00),
        ),
        elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
      ),
    ],
  );
}

void _expectRevisionDeltaRejected(StoreSparseCommit commit) {
  final store = documentStoreWithDocument(_baseDocument());
  final beforeSummary = store.documentSummary;

  expect(
    () => store.prepareSparseCommit(commit),
    throwsA(isA<ArgumentError>()),
  );
  expect(store.documentSummary, beforeSummary);
  expect(store.projectionBuildCount, 0);
}

void _validatesUpdateFailuresBeforeSwap() {
  final store = documentStoreWithDocument(_baseDocument());
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

void _rejectsStaleElementRevisionBeforeSwap() {
  final store = documentStoreWithDocument(_baseDocument());
  final beforeFacts = _requireFacts(store, CanvasElementId('e-content'));

  expect(
    () => store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.elementVisual(),
        mutations: [
          _sparseUpdate(
            before: _contentRect(),
            after: _contentRect(fillColor: const Color(0xFF00FF00)),
            elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
          ),
        ],
      ),
    ),
    throwsA(isA<ArgumentError>()),
  );
  final afterFacts = _requireFacts(store, CanvasElementId('e-content'));
  expect(afterFacts.fillColor, beforeFacts.fillColor);
  expect(afterFacts.revision, beforeFacts.revision);
  expect(store.projectionBuildCount, 0);
}

void _resourceDescriptorsUseAcceptedRevision() {
  final store = documentStoreWithDocument(_baseDocument());

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
  final store = documentStoreWithDocument(_clearRetentionDocument());
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
  final store = documentStoreWithDocument(_manyResourceClearDocument());
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
void _expectRemoveUnusedResourceBarrierThroughDirectStore() {
  final resourceId = CanvasResourceId('content-image-resource');
  final retainedStore = documentStoreWithDocument(_clearRetentionDocument());
  final retained = retainedStore.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta(
        document: true,
        projection: true,
        structural: true,
        bounds: true,
        elementVisual: true,
        resource: true,
      ),
      mutations: [
        StoreSparseRemoveUnusedResource(resourceId),
        const StoreSparseClearContent(removeUnusedResources: false),
      ],
    ),
  );

  expect(retained.touchedFacts.removedElementIds, {
    CanvasElementId('content-image'),
    CanvasElementId('content-vector'),
  });
  expect(retained.touchedFacts.resourceDescriptorChangedIds, isEmpty);
  expect(retained.touchedFacts.resourceVisualChangedIds, isEmpty);
  expect(retained.touchedFacts.layerIds, {CanvasLayerId('content-layer')});
  expect(retained.touchedFacts.backgroundLayerChanged, isFalse);
  expect(retained.revisionDelta.structural, isTrue);
  expect(retained.revisionDelta.resource, isFalse);
  retainedStore.installSparseCommit(retained);
  expect(retainedStore.resourceDescriptor(resourceId), isNotNull);
  expect(retainedStore.resourceRevision, 1);

  final removedStore = documentStoreWithDocument(_clearRetentionDocument());
  final removed = removedStore.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta(
        document: true,
        projection: true,
        structural: true,
        bounds: true,
        elementVisual: true,
        resource: true,
      ),
      mutations: [
        const StoreSparseClearContent(removeUnusedResources: false),
        StoreSparseRemoveUnusedResource(resourceId),
      ],
    ),
  );

  expect(removed.touchedFacts.removedElementIds, {
    CanvasElementId('content-image'),
    CanvasElementId('content-vector'),
  });
  expect(removed.touchedFacts.resourceDescriptorChangedIds, {resourceId});
  expect(removed.touchedFacts.resourceVisualChangedIds, {resourceId});
  expect(removed.touchedFacts.layerIds, {CanvasLayerId('content-layer')});
  expect(removed.touchedFacts.backgroundLayerChanged, isFalse);
  expect(removed.revisionDelta.structural, isTrue);
  expect(removed.revisionDelta.resource, isTrue);
  removedStore.installSparseCommit(removed);
  expect(removedStore.resourceDescriptor(resourceId), isNull);
  expect(removedStore.resourceRevision, 2);
}

// This direct clear trace needs each mutation and its expected state together
// to preserve the journal-order regression it falsifies.
// ignore: halstead-volume, source-lines-of-code
void _clearBarrierKeepsJournalOrder() {
  _expectRemoveUnusedResourceBarrierThroughDirectStore();

  final addedResource = CanvasImageResource(
    id: CanvasResourceId('trace-resource'),
    source: CanvasResourceSource.appKey('trace-source'),
    mimeType: 'image/webp',
    contentHash: 'trace-hash',
    byteLength: 303,
    metadata: CanvasMetadata.fromMap({'trace': 'resource'}),
  );
  final addedElement = CanvasImageElement(
    id: CanvasElementId('trace-element'),
    resourceId: CanvasResourceId('trace-resource'),
    size: const Size(47, 53),
    naturalSize: const Size(94, 106),
    revision: 7,
    isLocked: true,
    isDeletable: false,
    metadata: CanvasMetadata.fromMap({'trace': 'element'}),
  );
  final addBeforeClear = [
    _StoreClearTraceAction.upsert(addedResource),
    _StoreClearTraceAction.add(addedElement),
    const _StoreClearTraceAction.clear(removeUnusedResources: false),
    const _StoreClearTraceAction.removeUnused('trace-resource'),
    const _StoreClearTraceAction.clear(removeUnusedResources: true),
  ];
  final clearBeforeAdd = [
    const _StoreClearTraceAction.clear(removeUnusedResources: true),
    const _StoreClearTraceAction.removeUnused('trace-resource'),
    const _StoreClearTraceAction.clear(removeUnusedResources: false),
    _StoreClearTraceAction.add(addedElement),
    _StoreClearTraceAction.upsert(addedResource),
  ];

  final before = _runStoreClearTrace(addBeforeClear);
  final after = _runStoreClearTrace(clearBeforeAdd);

  expect(before.oracle.hasChanges, isFalse);
  expect(before.prepared.hasChanges, isFalse);
  expect(after.oracle.hasChanges, isTrue);
  expect(after.prepared.hasChanges, isTrue);
  expect(before.oracle.contentElementIds, isEmpty);
  expect(after.oracle.contentElementIds, [CanvasElementId('trace-element')]);
  expect(before.oracle.resourceIds, {
    CanvasResourceId('trace-background-image-resource'),
    CanvasResourceId('trace-background-vector-resource'),
  });
  expect(after.oracle.resourceIds, {
    CanvasResourceId('trace-background-image-resource'),
    CanvasResourceId('trace-background-vector-resource'),
    CanvasResourceId('trace-resource'),
  });
}

_StoreClearTraceResult _runStoreClearTrace(
  List<_StoreClearTraceAction> actions,
) {
  final seed = _clearBarrierDocument();
  final oracle = _StoreClearTraceOracle(seed);
  for (final action in actions) {
    action.applyTo(oracle);
  }
  final store = documentStoreWithDocument(seed);
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
      mutations: [for (final action in actions) action.mutation],
    ),
  );

  _expectStoreClearTracePrepared(prepared, oracle);
  expect(store.projectionBuildCount, 0);
  store.installSparseCommit(prepared);
  _expectStoreClearTraceCommitted(store, oracle);
  expect(store.projectionBuildCount, 0);

  return _StoreClearTraceResult(oracle: oracle, prepared: prepared);
}

// The complete prepared payload is the asserted boundary; a context object
// would duplicate Store's result model without clarifying the trace.
// ignore: halstead-volume
void _expectStoreClearTracePrepared(
  PreparedSparseStoreCommit prepared,
  _StoreClearTraceOracle oracle,
) {
  expect(prepared.hasChanges, oracle.hasChanges);
  expect(prepared.revisionDelta.document, oracle.hasChanges);
  expect(prepared.revisionDelta.projection, oracle.hasChanges);
  expect(prepared.revisionDelta.structural, oracle.hasStructuralChange);
  expect(prepared.revisionDelta.bounds, oracle.hasStructuralChange);
  expect(prepared.revisionDelta.elementVisual, oracle.hasStructuralChange);
  expect(prepared.revisionDelta.resource, oracle.hasResourceChange);
  expect(prepared.touchedFacts.addedElementIds, oracle.addedElementIds);
  expect(prepared.touchedFacts.removedElementIds, oracle.removedElementIds);
  expect(
    prepared.touchedFacts.resourceDescriptorChangedIds,
    oracle.changedResourceIds,
  );
  expect(
    prepared.touchedFacts.resourceVisualChangedIds,
    oracle.changedResourceIds,
  );
  expect(
    prepared.touchedFacts.layerIds,
    oracle.hasStructuralChange
        ? {CanvasLayerId('trace-content-layer')}
        : <CanvasLayerId>{},
  );
  expect(prepared.touchedFacts.backgroundLayerChanged, isFalse);
  expect(prepared.touchedFacts.background, isFalse);
  expect(prepared.touchedFacts.grid, isFalse);
}

void _expectStoreClearTraceCommitted(
  DocumentStoreKernel store,
  _StoreClearTraceOracle oracle,
) {
  expect(store.backgroundElementIds, oracle.backgroundElementIds);
  expect(
    store.elementIdsInLayer(CanvasLayerId('trace-content-layer')),
    oracle.contentElementIds,
  );
  expect(store.resourceIds.toSet(), oracle.resourceIds);
  for (final id in oracle.backgroundElementIds) {
    _expectSameTraceElement(store.elementById(id), oracle.elementById(id));
  }
  for (final id in oracle.contentElementIds) {
    _expectSameTraceElement(store.elementById(id), oracle.elementById(id));
  }
  for (final id in oracle.resourceIds) {
    _expectSameTraceDescriptor(
      store.resourceDescriptor(id),
      oracle.resourceById(id),
      resourceRevision: oracle.resourceRevisionFor(id),
    );
  }
}

// Element comparison remains explicit because this oracle must not reuse the
// production equality path it is independently checking.
// ignore: halstead-volume
void _expectSameTraceElement(CanvasElement? actual, CanvasElement expected) {
  expect(actual, isNotNull);
  if (actual == null) {
    fail('trace element is absent.');
  }
  final actualElement = actual;
  expect(actualElement.id, expected.id);
  expect(actualElement.kind, expected.kind);
  expect(actualElement.revision, expected.revision);
  expect(actualElement.transform, expected.transform);
  expect(actualElement.opacity, expected.opacity);
  expect(actualElement.hitPadding, expected.hitPadding);
  expect(actualElement.isVisible, expected.isVisible);
  expect(actualElement.isSelectable, expected.isSelectable);
  expect(actualElement.isLocked, expected.isLocked);
  expect(actualElement.isDeletable, expected.isDeletable);
  expect(actualElement.isTransformable, expected.isTransformable);
  expect(actualElement.metadata, expected.metadata);
  switch (actualElement) {
    case CanvasImageElement():
      final expectedImage = expected as CanvasImageElement;
      expect(actualElement.resourceId, expectedImage.resourceId);
      expect(actualElement.size, expectedImage.size);
      expect(actualElement.naturalSize, expectedImage.naturalSize);
    case CanvasVectorElement():
      final expectedVector = expected as CanvasVectorElement;
      expect(actualElement.resourceId, expectedVector.resourceId);
      expect(actualElement.size, expectedVector.size);
      expect(actualElement.naturalSize, expectedVector.naturalSize);
    case _:
      fail('trace uses only image and vector elements.');
  }
}

// Resource facts remain explicit because this oracle must not reuse the
// production descriptor comparison it is independently checking.
// ignore: halstead-volume
void _expectSameTraceDescriptor(
  StoreResourceDescriptorFacts? actual,
  CanvasResource expected, {
  required int resourceRevision,
}) {
  expect(actual, isNotNull);
  if (actual == null) {
    fail('trace descriptor is absent.');
  }
  final actualDescriptor = actual;
  final source = expected.source as CanvasAppKeyResourceSource;
  switch (actualDescriptor) {
    case StoreImageResourceDescriptorFacts():
      final expectedImage = expected as CanvasImageResource;
      expect(actualDescriptor.id, expectedImage.id);
      expect(actualDescriptor.appKey, source.key);
      expect(actualDescriptor.mimeType, expectedImage.mimeType);
      expect(actualDescriptor.contentHash, expectedImage.contentHash);
      expect(actualDescriptor.byteLength, expectedImage.byteLength);
      expect(actualDescriptor.metadata, expectedImage.metadata);
      expect(actualDescriptor.resourceRevision, resourceRevision);
    case StoreVectorResourceDescriptorFacts():
      final expectedVector = expected as CanvasVectorResource;
      expect(actualDescriptor.id, expectedVector.id);
      expect(actualDescriptor.appKey, source.key);
      expect(actualDescriptor.contentHash, expectedVector.contentHash);
      expect(actualDescriptor.byteLength, expectedVector.byteLength);
      expect(actualDescriptor.metadata, expectedVector.metadata);
      expect(actualDescriptor.resourceRevision, resourceRevision);
  }
}

// The resource-only setup and post-clear facts make this distinct from the
// content-clear traces; extracting them would conceal that distinction.
// ignore: halstead-volume
void _clearsResourceOnlyDocument() {
  final resourceOnlyStore = documentStoreWithDocument(_resourceOnlyDocument());
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

void _normalizesSelectionAgainstPreparedSparseCommit() {
  final store = documentStoreWithDocument(_baseDocument());
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

void _admitsSparseIdsWithoutDocumentScan() {
  final store = documentStoreWithDocument(_baseDocument());

  store.installSparseCommit(
    store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.structural().merge(
          const StoreRevisionDelta.resource(),
        ),
        mutations: [
          StoreSparseEnsureLayer(CanvasLayerId('l0')),
          StoreSparseAddElement(
            element: CanvasRectElement(
              id: CanvasElementId('e0'),
              size: const Size(1, 1),
            ),
            layerId: CanvasLayerId('l0'),
          ),
          StoreSparseUpsertResource(
            CanvasImageResource(
              id: CanvasResourceId('r0'),
              source: CanvasResourceSource.appKey('new-resource'),
            ),
          ),
        ],
      ),
    ),
  );

  expect(store.generateElementId(), CanvasElementId('e1'));
  expect(store.generateLayerId(), CanvasLayerId('l1'));
  expect(store.generateResourceId(), CanvasResourceId('r1'));
  expect(store.projectionBuildCount, 0);
}

// This direct trace ties replay work to the prepared ledger and installed
// cursor, so a final-fact rebuild cannot hide compensated sparse IDs.
// Keeping the full prepared/install/cursor witness together makes its causal
// order explicit; splitting it would only distribute one invariant across
// helpers without simplifying the direct Store evidence.
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index
void _usesOneSparseReplayAndAdmitsCompensatedTransientIds() {
  final store = DocumentStoreKernel();
  final sparseWork = <SparseTransactionWorkEvent>[];
  final admissionWork = <IdAdmissionWorkEvent>[];
  final mutations = <StoreSparseMutation>[
    StoreSparseAddElement(
      element: CanvasRectElement(
        id: CanvasElementId('e2'),
        size: const Size(1, 1),
      ),
      background: true,
    ),
    StoreSparseUpsertResource(_transientResource('r2')),
    StoreSparseAddElement(
      element: CanvasRectElement(
        id: CanvasElementId('e0'),
        size: const Size(1, 1),
      ),
      background: true,
    ),
    StoreSparseUpsertResource(_transientResource('r0')),
    StoreSparseRemoveElement(CanvasElementId('e2')),
    StoreSparseAddElement(
      element: CanvasRectElement(
        id: CanvasElementId('e2'),
        size: const Size(1, 1),
      ),
      background: true,
    ),
    StoreSparseRemoveElement(CanvasElementId('e0')),
    StoreSparseRemoveElement(CanvasElementId('e2')),
    StoreSparseRemoveUnusedResource(CanvasResourceId('r2')),
    StoreSparseUpsertResource(_transientResource('r2')),
    StoreSparseRemoveUnusedResource(CanvasResourceId('r0')),
    StoreSparseRemoveUnusedResource(CanvasResourceId('r2')),
    const StoreSparseSetBackground(CanvasBackground(color: Color(0xFF112233))),
  ];
  late PreparedSparseStoreCommit prepared;

  DocumentStoreKernel.observeSparseTransactionWork(
    sparseWork.add,
    () => DocumentStoreKernel.observeIdAdmissionWork(admissionWork.add, () {
      prepared = store.prepareSparseCommit(
        StoreSparseCommit(
          revisionDelta: const StoreRevisionDelta.structural()
              .merge(const StoreRevisionDelta.resource())
              .merge(const StoreRevisionDelta.background()),
          mutations: mutations,
        ),
      );
      store.installSparseCommit(prepared);
    }),
  );

  expect(prepared.admittedElementIds, ['e2', 'e0']);
  expect(prepared.admittedResourceIds, ['r2', 'r0']);
  expect(prepared.admittedLayerIds, isEmpty);
  expect(prepared.touchedFacts.addedElementIds, isEmpty);
  expect(prepared.touchedFacts.removedElementIds, isEmpty);
  expect(prepared.touchedFacts.resourceDescriptorChangedIds, isEmpty);
  expect(store.elementById(CanvasElementId('e0')), isNull);
  expect(store.elementById(CanvasElementId('e2')), isNull);
  expect(store.resourceById(CanvasResourceId('r0')), isNull);
  expect(store.resourceById(CanvasResourceId('r2')), isNull);
  expect(store.generateElementId(), CanvasElementId('e1'));
  expect(store.generateElementId(), CanvasElementId('e3'));
  expect(store.generateResourceId(), CanvasResourceId('r1'));
  expect(store.generateResourceId(), CanvasResourceId('r3'));
  expect(
    admissionWork
        .where(
          (event) =>
              event.phase == IdAdmissionWorkPhase.acceptedAdmission &&
              event.kind == IdAdmissionWorkKind.sparseLedgerVisit,
        )
        .map((event) => (event.prefix, event.subject)),
    [('e', 'e2'), ('e', 'e0'), ('r', 'r2'), ('r', 'r0')],
  );
  expect(
    sparseWork
        .where(
          (event) =>
              event.phase == SparseTransactionWorkPhase.replay &&
              event.kind == SparseTransactionWorkKind.journalVisit,
        )
        .map((event) => event.journalIndex),
    List.generate(mutations.length, (index) => index),
  );
  expect(
    sparseWork.where(
      (event) =>
          event.phase == SparseTransactionWorkPhase.replay &&
          event.kind == SparseTransactionWorkKind.ledgerAppend &&
          event.ledger == SparseTransactionWorkLedger.touched,
    ),
    hasLength(mutations.length),
  );
  expect(
    sparseWork.where(
      (event) =>
          event.phase == SparseTransactionWorkPhase.replay &&
          event.kind == SparseTransactionWorkKind.ledgerAppend &&
          event.ledger == SparseTransactionWorkLedger.requiredDelta,
    ),
    hasLength(mutations.length),
  );
  expect(
    sparseWork.where(
      (event) =>
          event.kind == SparseTransactionWorkKind.journalVisit &&
          event.phase == SparseTransactionWorkPhase.finalization,
    ),
    isEmpty,
  );
  expect(
    sparseWork.where(
      (event) =>
          event.phase == SparseTransactionWorkPhase.finalization &&
          event.kind == SparseTransactionWorkKind.ledgerRead,
    ),
    isNotEmpty,
  );
  expect(
    sparseWork.where(
      (event) =>
          event.phase == SparseTransactionWorkPhase.finalization &&
          event.kind == SparseTransactionWorkKind.ledgerRead &&
          event.ledger == SparseTransactionWorkLedger.requiredDelta,
    ),
    hasLength(1),
  );

  final noOpStore = DocumentStoreKernel();
  final noOp = noOpStore.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.structural().merge(
        const StoreRevisionDelta.resource(),
      ),
      mutations: [
        StoreSparseAddElement(
          element: CanvasRectElement(
            id: CanvasElementId('e0'),
            size: const Size(1, 1),
          ),
          background: true,
        ),
        StoreSparseRemoveElement(CanvasElementId('e0')),
        StoreSparseUpsertResource(_transientResource('r0')),
        StoreSparseRemoveUnusedResource(CanvasResourceId('r0')),
      ],
    ),
  );
  expect(noOp.hasChanges, isFalse);
  expect(noOp.admittedElementIds, isEmpty);
  expect(noOp.admittedResourceIds, isEmpty);
  expect(noOpStore.generateElementId(), CanvasElementId('e0'));
  expect(noOpStore.generateResourceId(), CanvasResourceId('r0'));
}

CanvasImageResource _transientResource(String id) {
  return CanvasImageResource(
    id: CanvasResourceId(id),
    source: CanvasResourceSource.appKey(id),
  );
}

void _validatesSparseUpdateRevisionCoverage() {
  _validatesUnderlineVisualUpdate();
  _validatesPathPaintedStrokeBoundsUpdate();
  _validatesRectPaintedStrokeBoundsUpdate();
}

void _validatesUnderlineVisualUpdate() {
  final underlineStore = documentStoreWithDocument(_textDocument());
  underlineStore.installSparseCommit(
    underlineStore.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.elementVisual(),
        mutations: [
          _sparseUpdate(
            before: CanvasTextElement(
              id: CanvasElementId('text'),
              text: 'label',
              color: const Color(0xFF000000),
              textDirection: TextDirection.ltr,
            ),
            after: CanvasTextElement(
              id: CanvasElementId('text'),
              text: 'label',
              color: const Color(0xFF000000),
              textDirection: TextDirection.ltr,
              revision: 1,
              isUnderline: true,
            ),
            elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
          ),
        ],
      ),
    ),
  );
  expect(
    _requireFacts(underlineStore, CanvasElementId('text')).isUnderline,
    isTrue,
  );
}

void _validatesPathPaintedStrokeBoundsUpdate() {
  _expectPaintedStrokeBoundsUpdate(
    id: CanvasElementId('path'),
    before: CanvasPathElement(
      id: CanvasElementId('path'),
      svgPathData: 'M 0 0 L 1 1',
      strokeWidth: 2,
    ),
    update: CanvasPathElement(
      id: CanvasElementId('path'),
      svgPathData: 'M 0 0 L 1 1',
      strokeColor: const Color(0xFF00FF00),
      strokeWidth: 2,
      revision: 1,
    ),
    strokeColorOf: (facts) => facts.strokeColor,
  );
}

void _validatesRectPaintedStrokeBoundsUpdate() {
  _expectPaintedStrokeBoundsUpdate(
    id: CanvasElementId('rect'),
    before: CanvasRectElement(
      id: CanvasElementId('rect'),
      size: const Size(2, 3),
      strokeWidth: 2,
    ),
    update: CanvasRectElement(
      id: CanvasElementId('rect'),
      size: const Size(2, 3),
      strokeColor: const Color(0xFF00FF00),
      strokeWidth: 2,
      revision: 1,
    ),
    strokeColorOf: (facts) => facts.strokeColor,
  );
}

void _expectPaintedStrokeBoundsUpdate({
  required CanvasElementId id,
  required CanvasElement before,
  required CanvasElement update,
  required Color? Function(StoreElementFacts facts) strokeColorOf,
}) {
  final store = documentStoreWithDocument(_paintedStrokeDocument());
  expect(
    () => store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.elementVisual(),
        mutations: [
          _sparseUpdate(
            before: before,
            after: update,
            elementRevisionDelta: const StoreRevisionDelta.elementBounds(),
          ),
        ],
      ),
    ),
    throwsA(isA<ArgumentError>()),
  );
  store.installSparseCommit(
    store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.elementBounds(),
        mutations: [
          _sparseUpdate(
            before: before,
            after: update,
            elementRevisionDelta: const StoreRevisionDelta.elementBounds(),
          ),
        ],
      ),
    ),
  );
  expect(strokeColorOf(_requireFacts(store, id)), const Color(0xFF00FF00));
}

void _replacementFallbackInstallsFullFacts() {
  final store = documentStoreWithDocument(_baseDocument());

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
        _sparseUpdate(
          before: CanvasImageElement(
            id: CanvasElementId('e-image'),
            resourceId: CanvasResourceId('resource-a'),
            size: const Size(6, 7),
          ),
          after: CanvasImageElement(
            id: CanvasElementId('e-image'),
            resourceId: CanvasResourceId('missing'),
            size: const Size(6, 7),
          ),
          elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
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

StoreSparseUpdateElement _sparseUpdate({
  required CanvasElement before,
  required CanvasElement after,
  required StoreRevisionDelta elementRevisionDelta,
}) {
  return StoreSparseUpdateElement(
    before: before,
    element: after,
    elementRevisionDelta: elementRevisionDelta,
  );
}

StoreSparseUpdateElement _sparseRectFillColorUpdate({
  required String id,
  required Size size,
  required Color fillColor,
}) {
  return _sparseUpdate(
    before: CanvasRectElement(id: CanvasElementId(id), size: size),
    after: CanvasRectElement(
      id: CanvasElementId(id),
      size: size,
      fillColor: fillColor,
      revision: 1,
    ),
    elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
  );
}

CanvasRectElement _contentRect({
  Color fillColor = const Color(0xFFFF0000),
  int revision = 0,
}) {
  return CanvasRectElement(
    id: CanvasElementId('e-content'),
    size: const Size(4, 5),
    revision: revision,
    fillColor: fillColor,
  );
}

// Both retained and removable rows stay in one fixture so the policy remains
// legible as a single state rather than a setup abstraction.
// ignore: halstead-volume, source-lines-of-code
CanvasDocument _clearRetentionDocument() {
  return CanvasDocument(
    background: CanvasBackground(
      color: const Color(0xFF102030),
      grid: CanvasGrid(
        enabled: true,
        cellSize: 16,
        color: const Color(0xFF405060),
      ),
    ),
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('background-image-resource'),
        source: CanvasResourceSource.appKey('background-image-source'),
        mimeType: 'image/png',
        contentHash: 'background-image-hash',
        byteLength: 101,
        metadata: CanvasMetadata.fromMap({'role': 'background-image'}),
      ),
      CanvasVectorResource(
        id: CanvasResourceId('background-vector-resource'),
        source: CanvasResourceSource.appKey('background-vector-source'),
        contentHash: 'background-vector-hash',
        byteLength: 202,
        metadata: CanvasMetadata.fromMap({'role': 'background-vector'}),
      ),
      CanvasImageResource(
        id: CanvasResourceId('content-image-resource'),
        source: CanvasResourceSource.appKey('content-image-source'),
      ),
      CanvasVectorResource(
        id: CanvasResourceId('content-vector-resource'),
        source: CanvasResourceSource.appKey('content-vector-source'),
      ),
      CanvasImageResource(
        id: CanvasResourceId('orphan-resource'),
        source: CanvasResourceSource.appKey('orphan-source'),
      ),
    ],
    backgroundElements: [
      CanvasImageElement(
        id: CanvasElementId('background-image'),
        resourceId: CanvasResourceId('background-image-resource'),
        size: const Size(31, 37),
        naturalSize: const Size(62, 74),
        revision: 5,
        isLocked: true,
        isDeletable: false,
        metadata: CanvasMetadata.fromMap({'slot': 'image'}),
      ),
      CanvasVectorElement(
        id: CanvasElementId('background-vector'),
        resourceId: CanvasResourceId('background-vector-resource'),
        size: const Size(41, 43),
        naturalSize: const Size(82, 86),
        revision: 6,
        isVisible: false,
        isSelectable: false,
        metadata: CanvasMetadata.fromMap({'slot': 'vector'}),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('content-layer'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('content-image'),
            resourceId: CanvasResourceId('content-image-resource'),
            size: const Size(17, 19),
          ),
          CanvasVectorElement(
            id: CanvasElementId('content-vector'),
            resourceId: CanvasResourceId('content-vector-resource'),
            size: const Size(23, 29),
          ),
        ],
      ),
    ],
  );
}

// Explicit resource roles keep the work distribution visible; generation would
// hide which rows must survive the transition.
// ignore: halstead-volume, source-lines-of-code
CanvasDocument _manyResourceClearDocument() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('background-image-resource'),
        source: CanvasResourceSource.appKey('background-image-source'),
      ),
      CanvasVectorResource(
        id: CanvasResourceId('background-vector-resource'),
        source: CanvasResourceSource.appKey('background-vector-source'),
      ),
      for (var index = 0; index < 6; index += 1)
        CanvasImageResource(
          id: CanvasResourceId('content-resource-$index'),
          source: CanvasResourceSource.appKey('content-source-$index'),
        ),
      for (var index = 0; index < 6; index += 1)
        CanvasVectorResource(
          id: CanvasResourceId('orphan-resource-$index'),
          source: CanvasResourceSource.appKey('orphan-source-$index'),
        ),
    ],
    backgroundElements: [
      CanvasImageElement(
        id: CanvasElementId('background-image'),
        resourceId: CanvasResourceId('background-image-resource'),
        size: const Size(5, 7),
      ),
      CanvasVectorElement(
        id: CanvasElementId('background-vector'),
        resourceId: CanvasResourceId('background-vector-resource'),
        size: const Size(11, 13),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('content-layer'),
        elements: [
          for (var index = 0; index < 6; index += 1)
            CanvasImageElement(
              id: CanvasElementId('content-$index'),
              resourceId: CanvasResourceId('content-resource-$index'),
              size: const Size(17, 19),
            ),
        ],
      ),
    ],
  );
}

// This literal combines the resource and placement facts needed to falsify a
// clear-barrier reorder, so it remains one cohesive fixture state.
// ignore: halstead-volume, source-lines-of-code
CanvasDocument _clearBarrierDocument() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('trace-background-image-resource'),
        source: CanvasResourceSource.appKey('trace-background-image-source'),
        mimeType: 'image/jpeg',
        contentHash: 'trace-background-image-hash',
        byteLength: 401,
        metadata: CanvasMetadata.fromMap({'trace': 'background-image'}),
      ),
      CanvasVectorResource(
        id: CanvasResourceId('trace-background-vector-resource'),
        source: CanvasResourceSource.appKey('trace-background-vector-source'),
        contentHash: 'trace-background-vector-hash',
        byteLength: 402,
        metadata: CanvasMetadata.fromMap({'trace': 'background-vector'}),
      ),
    ],
    backgroundElements: [
      CanvasImageElement(
        id: CanvasElementId('trace-background-image'),
        resourceId: CanvasResourceId('trace-background-image-resource'),
        size: const Size(59, 61),
        naturalSize: const Size(118, 122),
        revision: 8,
        isLocked: true,
        metadata: CanvasMetadata.fromMap({'trace': 'background-image'}),
      ),
      CanvasVectorElement(
        id: CanvasElementId('trace-background-vector'),
        resourceId: CanvasResourceId('trace-background-vector-resource'),
        size: const Size(67, 71),
        naturalSize: const Size(134, 142),
        revision: 9,
        isVisible: false,
        isDeletable: false,
        metadata: CanvasMetadata.fromMap({'trace': 'background-vector'}),
      ),
    ],
    layers: [CanvasLayer(id: CanvasLayerId('trace-content-layer'))],
  );
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

CanvasDocument _textDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasTextElement(
            id: CanvasElementId('text'),
            text: 'label',
            color: const Color(0xFF000000),
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _resourceOnlyDocument() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('resource-only'),
        source: CanvasResourceSource.appKey('asset-only'),
      ),
    ],
  );
}

CanvasDocument _multiRectDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('rect-a'),
            size: const Size(2, 2),
          ),
          CanvasRectElement(
            id: CanvasElementId('rect-b'),
            size: const Size(3, 3),
          ),
        ],
      ),
    ],
  );
}

CanvasPalette _alternatePalette() {
  return CanvasPalette(
    penColors: const [Color(0xFF000000), Color(0xFFFFFFFF)],
    backgroundColors: const [Color(0xFF112233)],
    gridSizes: const [8, 16],
  );
}

CanvasDocument _paintedStrokeDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasPathElement(
            id: CanvasElementId('path'),
            svgPathData: 'M 0 0 L 1 1',
            strokeWidth: 2,
          ),
          CanvasRectElement(
            id: CanvasElementId('rect'),
            size: const Size(2, 3),
            strokeWidth: 2,
          ),
        ],
      ),
    ],
  );
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

sealed class _StoreClearTraceAction {
  const _StoreClearTraceAction();

  const factory _StoreClearTraceAction.upsert(CanvasResource resource) =
      _StoreClearTraceUpsert;
  const factory _StoreClearTraceAction.add(CanvasElement element) =
      _StoreClearTraceAdd;
  const factory _StoreClearTraceAction.clear({
    required bool removeUnusedResources,
  }) = _StoreClearTraceClear;
  const factory _StoreClearTraceAction.removeUnused(String id) =
      _StoreClearTraceRemoveUnused;

  StoreSparseMutation get mutation;
  void applyTo(_StoreClearTraceOracle oracle);
}

final class _StoreClearTraceUpsert extends _StoreClearTraceAction {
  const _StoreClearTraceUpsert(this.resource);

  final CanvasResource resource;

  @override
  StoreSparseMutation get mutation => StoreSparseUpsertResource(resource);

  @override
  void applyTo(_StoreClearTraceOracle oracle) {
    oracle.upsertResource(resource);
  }
}

final class _StoreClearTraceAdd extends _StoreClearTraceAction {
  const _StoreClearTraceAdd(this.element);

  final CanvasElement element;

  @override
  StoreSparseMutation get mutation => StoreSparseAddElement(
    element: element,
    layerId: CanvasLayerId('trace-content-layer'),
  );

  @override
  void applyTo(_StoreClearTraceOracle oracle) {
    oracle.addContentElement(element);
  }
}

final class _StoreClearTraceClear extends _StoreClearTraceAction {
  const _StoreClearTraceClear({required this.removeUnusedResources});

  final bool removeUnusedResources;

  @override
  StoreSparseMutation get mutation =>
      StoreSparseClearContent(removeUnusedResources: removeUnusedResources);

  @override
  void applyTo(_StoreClearTraceOracle oracle) {
    oracle.clearContent(removeUnusedResources: removeUnusedResources);
  }
}

final class _StoreClearTraceRemoveUnused extends _StoreClearTraceAction {
  const _StoreClearTraceRemoveUnused(this.id);

  final String id;

  @override
  StoreSparseMutation get mutation =>
      StoreSparseRemoveUnusedResource(CanvasResourceId(id));

  @override
  void applyTo(_StoreClearTraceOracle oracle) {
    oracle.removeUnusedResource(CanvasResourceId(id));
  }
}

final class _StoreClearTraceResult {
  const _StoreClearTraceResult({required this.oracle, required this.prepared});

  final _StoreClearTraceOracle oracle;
  final PreparedSparseStoreCommit prepared;
}

// This type deliberately groups one trace's independent state.
// Splitting it would duplicate the scenario model.
// ignore: number-of-methods, weighted-methods-per-class
final class _StoreClearTraceOracle {
  _StoreClearTraceOracle(CanvasDocument document)
    : _initialContentElementIds = {
        for (final layer in document.layers) ...layer.elements.map((e) => e.id),
      },
      _initialResourceIds = {
        for (final resource in document.resources) resource.id,
      },
      backgroundElementIds = List.of(
        document.backgroundElements.map((element) => element.id),
      ),
      contentElementIds = [
        for (final layer in document.layers) ...layer.elements.map((e) => e.id),
      ],
      _elements = {
        for (final element in [
          ...document.backgroundElements,
          for (final layer in document.layers) ...layer.elements,
        ])
          element.id: element,
      },
      _resources = {
        for (final resource in document.resources) resource.id: resource,
      };

  final Set<CanvasElementId> _initialContentElementIds;
  final Set<CanvasResourceId> _initialResourceIds;
  final List<CanvasElementId> backgroundElementIds;
  final List<CanvasElementId> contentElementIds;
  final Map<CanvasElementId, CanvasElement> _elements;
  final Map<CanvasResourceId, CanvasResource> _resources;

  Set<CanvasResourceId> get resourceIds => Set.unmodifiable(_resources.keys);
  Set<CanvasElementId> get addedElementIds => {
    for (final id in contentElementIds)
      if (!_initialContentElementIds.contains(id)) id,
  };
  Set<CanvasElementId> get removedElementIds => {
    for (final id in _initialContentElementIds)
      if (!contentElementIds.contains(id)) id,
  };
  Set<CanvasResourceId> get changedResourceIds => {
    for (final id in _initialResourceIds)
      if (!_resources.containsKey(id)) id,
    for (final id in _resources.keys)
      if (!_initialResourceIds.contains(id)) id,
  };
  bool get hasStructuralChange =>
      addedElementIds.isNotEmpty || removedElementIds.isNotEmpty;
  bool get hasResourceChange => changedResourceIds.isNotEmpty;
  bool get hasChanges => hasStructuralChange || hasResourceChange;

  CanvasElement elementById(CanvasElementId id) => _elements[id]!;
  CanvasResource resourceById(CanvasResourceId id) => _resources[id]!;

  int resourceRevisionFor(CanvasResourceId id) {
    return _initialResourceIds.contains(id) ? 1 : 2;
  }

  void upsertResource(CanvasResource resource) {
    _resources[resource.id] = resource;
  }

  void addContentElement(CanvasElement element) {
    _elements[element.id] = element;
    contentElementIds.add(element.id);
  }

  void clearContent({required bool removeUnusedResources}) {
    for (final id in contentElementIds) {
      _elements.remove(id);
    }
    contentElementIds.clear();
    if (removeUnusedResources) {
      _resources.removeWhere((id, _) => !_isResourceReferenced(id));
    }
  }

  void removeUnusedResource(CanvasResourceId id) {
    if (!_isResourceReferenced(id)) {
      _resources.remove(id);
    }
  }

  bool _isResourceReferenced(CanvasResourceId id) {
    return _elements.values.any(
      (element) => switch (element) {
        CanvasImageElement() => element.resourceId == id,
        CanvasVectorElement() => element.resourceId == id,
        _ => false,
      },
    );
  }
}
