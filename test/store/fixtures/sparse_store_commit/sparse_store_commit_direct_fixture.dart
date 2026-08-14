import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/store/committed_document.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
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
    'admits sparse ids without scanning the installed document',
    () => expect(_admitsSparseIdsWithoutDocumentScan, returnsNormally),
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

void _admitsSparseIdsWithoutDocumentScan() {
  final store = documentStoreWithDocument(baseDocument());

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
