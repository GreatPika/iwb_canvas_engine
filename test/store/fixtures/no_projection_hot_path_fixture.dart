import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

void main() {
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
}

void _projectionCacheBuildsOnlyThroughExplicitRead() {
  final root = RuntimeRoot(
    initialDocument: CanvasDocument(
      layers: [CanvasLayer(id: CanvasLayerId('layer-a'))],
    ),
    config: const CanvasRuntimeConfig(),
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
  final store = DocumentStoreKernel(
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

void _ordinaryPublicEditRouteDoesNotBuildProjection() {
  final root = RuntimeRoot(
    initialDocument: CanvasDocument(
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
    config: const CanvasRuntimeConfig(),
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
  final root = RuntimeRoot(
    initialDocument: CanvasDocument(
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
    config: const CanvasRuntimeConfig(),
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
  final root = RuntimeRoot(
    initialDocument: CanvasDocument(
      layers: [
        CanvasLayer(
          id: CanvasLayerId('layer-a'),
          elements: [_rect('element-a')],
        ),
      ],
    ),
    config: const CanvasRuntimeConfig(),
  );

  root.selection.setSelection([CanvasElementId('element-a')]);

  expect(root.selectedElementIds, {CanvasElementId('element-a')});
  expect(root.projectionBuildCount, 0);
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
        revisionDelta: const StoreRevisionDelta.elementBounds(),
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
          ),
        ],
      ),
    ),
  );
}

StoreSparseUpdateElement _sparseUpdate({
  required CanvasElement before,
  required CanvasElement after,
}) {
  return StoreSparseUpdateElement(
    before: before,
    element: after,
  );
}
