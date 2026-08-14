import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

import '../../../support/document_store_with_document.dart';
import 'sparse_store_commit_support.dart';

void registerSparseValidationTests() {
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
  test(
    'validates sparse update revision coverage',
    () => expect(_validatesSparseUpdateRevisionCoverage, returnsNormally),
  );
}

void _validatesAddFailuresBeforeSwap() {
  _acceptsImageAndResourceAddedInEitherOrder();
  _removedResourceBeforeElementAddFailsFinalRelationshipValidation();

  final store = documentStoreWithDocument(baseDocument());
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
    final store = documentStoreWithDocument(baseDocument());
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
  final store = documentStoreWithDocument(baseDocument());
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
        sparseUpdate(
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
  final store = documentStoreWithDocument(baseDocument());
  final beforeFacts = requireFacts(store, CanvasElementId('e-content'));

  expect(
    () => store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.elementVisual(),
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
              fillColor: const Color(0xFFFF0000),
            ),
            elementRevisionDelta: const StoreRevisionDelta(),
          ),
        ],
      ),
    ),
    throwsA(isA<ArgumentError>()),
  );
  final afterFacts = requireFacts(store, CanvasElementId('e-content'));
  expect(afterFacts.size, beforeFacts.size);
  expect(afterFacts.fillColor, beforeFacts.fillColor);
  expect(afterFacts.revision, beforeFacts.revision);
  expect(store.projectionBuildCount, 0);
}

void _rejectsSparseUpdateSourceMismatchBeforeSwap() {
  final store = documentStoreWithDocument(baseDocument());
  final beforeFacts = requireFacts(store, CanvasElementId('e-content'));
  final beforeBoundsRevision = store.boundsRevision;
  final beforeVisualRevision = store.elementVisualRevision;

  expect(
    () => store.prepareSparseCommit(sparseUpdateWithMismatchedBefore()),
    throwsA(isA<ArgumentError>()),
  );
  final afterFacts = requireFacts(store, CanvasElementId('e-content'));
  expect(afterFacts.size, beforeFacts.size);
  expect(afterFacts.fillColor, beforeFacts.fillColor);
  expect(afterFacts.revision, beforeFacts.revision);
  expect(store.boundsRevision, beforeBoundsRevision);
  expect(store.elementVisualRevision, beforeVisualRevision);
  expect(store.projectionBuildCount, 0);
}

StoreSparseCommit sparseUpdateWithMismatchedBefore() {
  return StoreSparseCommit(
    revisionDelta: const StoreRevisionDelta.elementVisual(),
    mutations: [
      sparseUpdate(
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
  final store = documentStoreWithDocument(baseDocument());
  final beforeSummary = store.documentSummary;

  expect(
    () => store.prepareSparseCommit(commit),
    throwsA(isA<ArgumentError>()),
  );
  expect(store.documentSummary, beforeSummary);
  expect(store.projectionBuildCount, 0);
}

void _validatesUpdateFailuresBeforeSwap() {
  final store = documentStoreWithDocument(baseDocument());
  final beforeFacts = requireFacts(store, CanvasElementId('e-image'));

  expect(
    _prepareMissingResourceUpdate(store),
    throwsA(isA<CanvasDataException>()),
  );
  expect(
    requireFacts(store, CanvasElementId('e-image')).resourceId,
    beforeFacts.resourceId,
  );
  expect(store.projectionBuildCount, 0);
}

void _rejectsStaleElementRevisionBeforeSwap() {
  final store = documentStoreWithDocument(baseDocument());
  final beforeFacts = requireFacts(store, CanvasElementId('e-content'));

  expect(
    () => store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.elementVisual(),
        mutations: [
          sparseUpdate(
            before: contentRect(),
            after: contentRect(fillColor: const Color(0xFF00FF00)),
            elementRevisionDelta: const StoreRevisionDelta.elementVisual(),
          ),
        ],
      ),
    ),
    throwsA(isA<ArgumentError>()),
  );
  final afterFacts = requireFacts(store, CanvasElementId('e-content'));
  expect(afterFacts.fillColor, beforeFacts.fillColor);
  expect(afterFacts.revision, beforeFacts.revision);
  expect(store.projectionBuildCount, 0);
}

void _validatesSparseUpdateRevisionCoverage() {
  _validatesUnderlineVisualUpdate();
  _validatesPathPaintedStrokeBoundsUpdate();
  _validatesRectPaintedStrokeBoundsUpdate();
}

void _validatesUnderlineVisualUpdate() {
  final underlineStore = documentStoreWithDocument(textDocument());
  underlineStore.installSparseCommit(
    underlineStore.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.elementVisual(),
        mutations: [
          sparseUpdate(
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
    requireFacts(underlineStore, CanvasElementId('text')).isUnderline,
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
  final store = documentStoreWithDocument(paintedStrokeDocument());
  expect(
    () => store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.elementVisual(),
        mutations: [
          sparseUpdate(
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
          sparseUpdate(
            before: before,
            after: update,
            elementRevisionDelta: const StoreRevisionDelta.elementBounds(),
          ),
        ],
      ),
    ),
  );
  expect(strokeColorOf(requireFacts(store, id)), const Color(0xFF00FF00));
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
        sparseUpdate(
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
