import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

import '../../support/document_store_with_document.dart';

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
  _registerSparseUpdateInstallTests();
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
  expect(
    _prepareMissingResourceAdd(
      store,
      revisionDelta: const StoreRevisionDelta(document: true, structural: true),
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
  expect(store.projectionBuildCount, 0);
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
  _clearsContentWithResources();
  _clearsResourceOnlyDocument();
}

void _clearsContentWithResources() {
  final store = documentStoreWithDocument(_baseDocument());

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

void _clearsResourceOnlyDocument() {
  final resourceOnlyStore = documentStoreWithDocument(_resourceOnlyDocument());
  resourceOnlyStore.installSparseCommit(
    resourceOnlyStore.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.resource(),
        mutations: const [StoreSparseClearContent(removeUnusedResources: true)],
      ),
    ),
  );
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

void Function() _prepareMissingResourceAdd(
  DocumentStoreKernel store, {
  StoreRevisionDelta revisionDelta = const StoreRevisionDelta.structural(),
}) {
  return () => store.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: revisionDelta,
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
