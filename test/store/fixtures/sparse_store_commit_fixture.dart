import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/edit/commit_compiler.dart';
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
    'validates sparse updates through the shared element taxonomy',
    () => expect(_validatesSparseUpdatesThroughSharedTaxonomy, returnsNormally),
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
  test(
    'rejects stale element revision updates before swap',
    () => expect(_rejectsStaleElementRevisionBeforeSwap, returnsNormally),
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
  final store = DocumentStoreKernel(_multiRectDocument());

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
  final store = DocumentStoreKernel(_baseDocument());
  final beforeRevision = store.documentRevision;
  final beforeProjectionBuilds = store.projectionBuildCount;

  final noOp = store.prepareSparseCommit(
    StoreSparseCommit(
      revisionDelta: const StoreRevisionDelta.elementVisual(),
      mutations: [
        StoreSparseUpdateElement(
          element: CanvasRectElement(
            id: CanvasElementId('e-content'),
            size: const Size(4, 5),
            fillColor: const Color(0xFFFF0000),
          ),
          requiredRevisionDelta: const StoreRevisionDelta(),
        ),
        StoreSparseUpdateElement(
          element: CanvasRectElement(
            id: CanvasElementId('missing'),
            size: const Size(1, 1),
            fillColor: const Color(0xFF123456),
          ),
          requiredRevisionDelta: const StoreRevisionDelta.elementVisual(),
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

void _rejectsStaleElementRevisionBeforeSwap() {
  final store = DocumentStoreKernel(_baseDocument());
  final beforeFacts = _requireFacts(store, CanvasElementId('e-content'));

  expect(
    () => store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.elementVisual(),
        mutations: [
          StoreSparseUpdateElement(
            element: CanvasRectElement(
              id: CanvasElementId('e-content'),
              size: const Size(4, 5),
              fillColor: const Color(0xFF00FF00),
            ),
            requiredRevisionDelta: const StoreRevisionDelta.elementVisual(),
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
  _clearsContentWithResources();
  _clearsResourceOnlyDocument();
}

void _clearsContentWithResources() {
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

void _clearsResourceOnlyDocument() {
  final resourceOnlyStore = DocumentStoreKernel(_resourceOnlyDocument());
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
  expect(resourceOnlyStore.resourceRevision, 1);
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

void _admitsSparseIdsWithoutDocumentScan() {
  final store = DocumentStoreKernel(_baseDocument());

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

void _validatesSparseUpdatesThroughSharedTaxonomy() {
  _validatesUnderlineVisualUpdate();
  _validatesPathPaintedStrokeBoundsUpdate();
  _validatesRectPaintedStrokeBoundsUpdate();
}

void _validatesUnderlineVisualUpdate() {
  final underlineStore = DocumentStoreKernel(_textDocument());
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
  required CanvasElement update,
  required Color? Function(StoreElementFacts facts) strokeColorOf,
}) {
  final store = DocumentStoreKernel(_paintedStrokeDocument());
  expect(
    () => store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.elementVisual(),
        mutations: [
          StoreSparseUpdateElement(
            element: update,
            requiredRevisionDelta: const StoreRevisionDelta.elementBounds(),
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
          StoreSparseUpdateElement(
            element: update,
            requiredRevisionDelta: const StoreRevisionDelta.elementBounds(),
          ),
        ],
      ),
    ),
  );
  expect(strokeColorOf(_requireFacts(store, id)), const Color(0xFF00FF00));
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
          element: CanvasImageElement(
            id: CanvasElementId('e-image'),
            resourceId: CanvasResourceId('missing'),
            size: const Size(6, 7),
          ),
          requiredRevisionDelta: const StoreRevisionDelta.elementVisual(),
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
}) {
  return StoreSparseUpdateElement(
    element: after,
    requiredRevisionDelta: const CommitCompiler()
        .compileElementUpdate(before: before, after: after)
        .revisionDelta,
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
