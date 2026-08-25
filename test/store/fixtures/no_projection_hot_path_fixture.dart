import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/deletion_entry_projection_port.dart';
import 'package:iwb_canvas_engine/src/store/canvas_element_snapshot.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

import '../../support/document_store_with_document.dart';
import '../../support/runtime_root_with_committed_document_seed.dart';

void main() {
  _registerProjectionCacheTests();
  _registerDeletionProjectionTests();
}

void _registerProjectionCacheTests() {
  test(
    'projection cache is touched only by explicit readDocument',
    () =>
        expect(_projectionCacheBuildsOnlyThroughExplicitRead, returnsNormally),
  );
  test(
    'sparse store add update and no-op do not build projection',
    () => expect(
      _sparseStoreAddUpdateAndNoOpDoNotBuildProjection,
      returnsNormally,
    ),
  );
  test(
    'ordinary public edit route does not build projection before explicit read',
    () =>
        expect(_ordinaryPublicEditRouteDoesNotBuildProjection, returnsNormally),
  );
  test(
    'draftSummary public edit route does not build projection',
    () => expect(_draftSummaryRouteDoesNotBuildProjection, returnsNormally),
  );
  test(
    'selection-only route does not build projection',
    () => expect(_selectionOnlyRouteDoesNotBuildProjection, returnsNormally),
  );
  test(
    'selection deletion projects only selected entries without CanvasDocument',
    () => expect(
      _selectionDeletionDoesNotBuildDocumentProjection,
      returnsNormally,
    ),
  );
}

void _registerDeletionProjectionTests() {
  test(
    'Store deletion projection preserves committed entry facts without a document projection',
    () => expect(
      _storeDeletionProjectionUsesCommittedEntryFacts,
      returnsNormally,
    ),
  );
  test(
    'Store deletion projection has canonical and arbitrary order work bounds',
    () => expect(_storeDeletionProjectionHasBoundedOrderWork, returnsNormally),
  );
}

void _projectionCacheBuildsOnlyThroughExplicitRead() {
  final root = runtimeRootWithCommittedDocumentSeed(
    CanvasDocument(layers: [CanvasLayer(id: CanvasLayerId('layer-a'))]),
    config: const CanvasRuntimeConfig(
      deletionCommitResolver: _acceptDeletionCommit,
    ),
  );

  expect(root.projectionBuildCount, 0);
  expect(root.state.value.summary.layerCount, 1);
  expect(root.generateElementId(), CanvasElementId('e0'));
  expect(root.generateLayerId(), CanvasLayerId('l0'));
  expect(root.generateResourceId(), CanvasResourceId('r0'));
  expect(root.projectionBuildCount, 0);

  root.readDocument();
  expect(root.projectionBuildCount, 1);
  root.readDocument();
  expect(root.projectionBuildCount, 1);

  root.dispose();
}

void _sparseStoreAddUpdateAndNoOpDoNotBuildProjection() {
  final store = documentStoreWithDocument(
    CanvasDocument(
      backgroundElements: [_rect('background')],
      layers: [
        CanvasLayer(
          id: CanvasLayerId('layer-a'),
          elements: [
            CanvasRectElement(
              id: CanvasElementId('element-a'),
              size: const Size(1, 1),
            ),
          ],
        ),
      ],
    ),
  );

  _installSparseAdd(store);
  expect(store.projectionBuildCount, 0);

  _installSparseTransform(store);
  expect(store.projectionBuildCount, 0);

  _installSparseTransformNoOp(store);
  expect(store.projectionBuildCount, 0);

  store.readDocument();
  expect(store.projectionBuildCount, 1);
}

// This route must retain every edit and the read boundary in one witness so a
// projection built by any public operation remains directly attributable.
// ignore: halstead-volume
void _ordinaryPublicEditRouteDoesNotBuildProjection() {
  final root = runtimeRootWithCommittedDocumentSeed(
    CanvasDocument(
      layers: [
        CanvasLayer(
          id: CanvasLayerId('layer-a'),
          elements: [
            CanvasRectElement(
              id: CanvasElementId('element-a'),
              size: const Size(1, 1),
            ),
          ],
        ),
      ],
    ),
    config: const CanvasRuntimeConfig(
      deletionCommitResolver: _acceptDeletionCommit,
    ),
  );

  root.edits.edit((edit) {
    edit.addElement(_rect('element-b'), layerId: CanvasLayerId('layer-a'));
  });
  root.edits.edit((edit) {
    edit.updateElement(
      CanvasRectElementUpdate(
        id: CanvasElementId('element-a'),
        fillColor: const CanvasFieldSet(Color(0xFF00FF00)),
      ),
    );
  });
  root.edits.edit((edit) {
    expect(edit.ensureLayer(CanvasLayerId('layer-a')), isFalse);
  });
  expect(root.projectionBuildCount, 0);

  root.edits.edit((edit) {
    edit.readDraftDocument();
  });
  expect(root.projectionBuildCount, 1);
}

void _draftSummaryRouteDoesNotBuildProjection() {
  final root = runtimeRootWithCommittedDocumentSeed(
    CanvasDocument(
      resources: [
        CanvasImageResource(
          id: CanvasResourceId('resource-a'),
          source: CanvasResourceSource.appKey('resource-a'),
        ),
      ],
      layers: [
        CanvasLayer(
          id: CanvasLayerId('layer-a'),
          elements: [_rect('element-a')],
        ),
      ],
    ),
    config: const CanvasRuntimeConfig(
      deletionCommitResolver: _acceptDeletionCommit,
    ),
  );

  final summary = root.edits.edit((edit) {
    edit.addElement(_rect('element-b'), layerId: CanvasLayerId('layer-a'));

    return edit.draftSummary;
  });

  expect(
    summary,
    const CanvasDocumentSummary(
      elementCount: 2,
      layerCount: 1,
      resourceCount: 1,
    ),
  );
  expect(root.projectionBuildCount, 0);
}

void _selectionOnlyRouteDoesNotBuildProjection() {
  final root = runtimeRootWithCommittedDocumentSeed(
    CanvasDocument(
      layers: [
        CanvasLayer(
          id: CanvasLayerId('layer-a'),
          elements: [_rect('element-a')],
        ),
      ],
    ),
    config: const CanvasRuntimeConfig(
      deletionCommitResolver: _acceptDeletionCommit,
    ),
  );

  root.selection.setSelection([CanvasElementId('element-a')]);

  expect(root.selectedElementIds, {CanvasElementId('element-a')});
  expect(root.projectionBuildCount, 0);
}

void _selectionDeletionDoesNotBuildDocumentProjection() {
  final root = runtimeRootWithCommittedDocumentSeed(
    CanvasDocument(
      layers: [
        CanvasLayer(
          id: CanvasLayerId('layer-a'),
          elements: [_rect('before'), _rect('selected-a')],
        ),
        CanvasLayer(
          id: CanvasLayerId('layer-b'),
          elements: [_rect('selected-b'), _rect('after')],
        ),
      ],
    ),
    config: const CanvasRuntimeConfig(
      deletionCommitResolver: _acceptDeletionCommit,
    ),
  );
  addTearDown(root.dispose);

  root.selection.setSelection([
    CanvasElementId('selected-b'),
    CanvasElementId('selected-a'),
  ]);
  root.selection.deleteSelection();

  expect(root.projectionBuildCount, 0);
}

// One compact matrix keeps the same committed snapshot, background boundary,
// and pre-mutation entry facts together; splitting it would obscure its oracle.
// ignore: halstead-volume
void _storeDeletionProjectionUsesCommittedEntryFacts() {
  final background = _rect('background');
  final first = _rect('first');
  final selected = _rect('selected');
  final later = _rect('later');
  final last = _rect('last');
  final store = documentStoreWithDocument(
    CanvasDocument(
      backgroundElements: [background],
      layers: [
        CanvasLayer(id: CanvasLayerId('layer-a'), elements: [first, selected]),
        CanvasLayer(id: CanvasLayerId('layer-b'), elements: [later, last]),
      ],
    ),
  );

  final entries = store.projectDeletionEntries([
    last.id,
    selected.id,
    selected.id,
    later.id,
    CanvasElementId('missing'),
    CanvasElementId('background'),
  ]).entries;

  _expectProjectedEntryFacts(entries, store, [
    _ExpectedDeletionEntry(selected.id, CanvasLayerId('layer-a'), 1, 2),
    _ExpectedDeletionEntry(later.id, CanvasLayerId('layer-b'), 0, 3),
    _ExpectedDeletionEntry(last.id, CanvasLayerId('layer-b'), 1, 4),
  ]);
  expect(() => entries.clear(), throwsUnsupportedError);
  expect(() => entries.add(entries.first), throwsUnsupportedError);
  expect(store.backgroundElementIds, contains(background.id));
  expect(store.elementById(background.id), isNotNull);
  expect(entries.map((entry) => entry.id), isNot(contains(background.id)));
  expect(
    entries.map((entry) => entry.id),
    isNot(contains(CanvasElementId('missing'))),
  );
  expect(store.projectionBuildCount, 0);
}

void _expectProjectedEntryFacts(
  List<DeletionEntryFacts> entries,
  DocumentStoreKernel store,
  List<_ExpectedDeletionEntry> expectedEntries,
) {
  expect(
    entries.map((entry) => entry.id),
    expectedEntries.map((entry) => entry.id),
  );
  expect(entries[0].element, isA<CanvasRectElement>());
  for (var index = 0; index < entries.length; index += 1) {
    _expectEntry(entries[index], store, expectedEntries[index]);
  }
}

void _expectEntry(
  DeletionEntryFacts entry,
  DocumentStoreKernel store,
  _ExpectedDeletionEntry expected,
) {
  final committedElement = store.elementById(entry.id);
  expect(committedElement, isNotNull);
  if (committedElement == null) {
    fail('Store did not retain projected entry ${entry.id}');
  }
  expect(sameCanvasElementSnapshot(entry.element, committedElement), isTrue);
  expect(entry.layerId, expected.layerId);
  expect(entry.elementIndex, expected.elementIndex);
  expect(entry.orderToken, expected.orderToken);
}

final class _ExpectedDeletionEntry {
  const _ExpectedDeletionEntry(
    this.id,
    this.layerId,
    this.elementIndex,
    this.orderToken,
  );

  final CanvasElementId id;
  final CanvasLayerId layerId;
  final int elementIndex;
  final int orderToken;
}

void _storeDeletionProjectionHasBoundedOrderWork() {
  final ids = [
    CanvasElementId('target-a'),
    CanvasElementId('target-b'),
    CanvasElementId('target-c'),
    CanvasElementId('target-d'),
  ];
  final canonicalWork = _deletionProjectionWork(
    _deletionProjectionStore(unrelatedElementCount: 0),
    ids,
  );
  expect(
    canonicalWork[DeletionProjectionWorkEvent.arbitraryOrderComparison],
    isNull,
  );
  expect(
    canonicalWork[DeletionProjectionWorkEvent.canonicalOrderComparison],
    3,
  );

  final arbitraryWork = _deletionProjectionWork(
    _deletionProjectionStore(unrelatedElementCount: 0),
    ids.reversed.toList(growable: false),
  );
  expect(
    arbitraryWork[DeletionProjectionWorkEvent.arbitraryOrderComparison],
    greaterThan(0),
  );
  expect(
    arbitraryWork[DeletionProjectionWorkEvent.arbitraryOrderComparison]!,
    lessThanOrEqualTo(16),
  );

  final fixedBase = _deletionProjectionWork(
    _deletionProjectionStore(unrelatedElementCount: 0),
    ids.take(2).toList(growable: false),
  );
  final fixedWithUnrelated = _deletionProjectionWork(
    _deletionProjectionStore(unrelatedElementCount: 100),
    ids.take(2).toList(growable: false),
  );
  expect(fixedWithUnrelated, fixedBase);
}

Map<DeletionProjectionWorkEvent, int> _deletionProjectionWork(
  DocumentStoreKernel store,
  List<CanvasElementId> ids,
) {
  final counts = <DeletionProjectionWorkEvent, int>{};
  final entries = DocumentStoreKernel.observeDeletionProjectionWork(
    (event) => counts.update(event, (count) => count + 1, ifAbsent: () => 1),
    () => store.projectDeletionEntries(ids).entries,
  );
  expect(entries, hasLength(ids.length));
  return counts;
}

DocumentStoreKernel _deletionProjectionStore({
  required int unrelatedElementCount,
}) {
  return documentStoreWithDocument(
    CanvasDocument(
      layers: [
        CanvasLayer(
          id: CanvasLayerId('targets'),
          elements: [
            _rect('target-a'),
            _rect('target-b'),
            _rect('target-c'),
            _rect('target-d'),
          ],
        ),
        CanvasLayer(
          id: CanvasLayerId('unrelated'),
          elements: [
            for (var index = 0; index < unrelatedElementCount; index += 1)
              _rect('unrelated-$index'),
          ],
        ),
      ],
    ),
  );
}

void _installSparseAdd(DocumentStoreKernel store) {
  store.installSparseCommit(
    store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.structural(),
        mutations: [
          StoreSparseAddElement(
            element: CanvasRectElement(
              id: CanvasElementId('element-b'),
              size: const Size(2, 2),
            ),
          ),
        ],
      ),
    ),
  );
}

CanvasRectElement _rect(String id) {
  return CanvasRectElement(id: CanvasElementId(id), size: const Size(2, 2));
}

void _installSparseTransform(DocumentStoreKernel store) {
  store.installSparseCommit(
    store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.elementBounds(),
        mutations: [
          _sparseUpdate(
            before: CanvasRectElement(
              id: CanvasElementId('element-a'),
              size: const Size(1, 1),
            ),
            after: CanvasRectElement(
              id: CanvasElementId('element-a'),
              size: const Size(1, 1),
              revision: 1,
              transform: CanvasTransform.translation(const Offset(1, 1)),
            ),
            elementRevisionDelta: const StoreRevisionDelta.elementBounds(),
          ),
        ],
      ),
    ),
  );
}

void _installSparseTransformNoOp(DocumentStoreKernel store) {
  store.installSparseCommit(
    store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta(),
        mutations: [
          _sparseUpdate(
            before: CanvasRectElement(
              id: CanvasElementId('element-a'),
              size: const Size(1, 1),
              revision: 1,
              transform: CanvasTransform.translation(const Offset(1, 1)),
            ),
            after: CanvasRectElement(
              id: CanvasElementId('element-a'),
              size: const Size(1, 1),
              revision: 1,
              transform: CanvasTransform.translation(const Offset(1, 1)),
            ),
            elementRevisionDelta: const StoreRevisionDelta(),
          ),
        ],
      ),
    ),
  );
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

CanvasDeletionDecision _acceptDeletionCommit(CanvasDeletionCommitRequest _) =>
    CanvasDeletionDecision.accept;
