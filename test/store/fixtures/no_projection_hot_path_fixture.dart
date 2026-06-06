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

  _installSparseTransform(store);
  expect(store.projectionBuildCount, 0);

  store.readDocument();
  expect(store.projectionBuildCount, 1);
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

void _installSparseTransform(DocumentStoreKernel store) {
  store.installSparseCommit(
    store.prepareSparseCommit(
      StoreSparseCommit(
        revisionDelta: const StoreRevisionDelta.elementBounds(),
        mutations: [
          StoreSparseUpdateElement(
            CanvasRectElement(
              id: CanvasElementId('element-a'),
              size: const Size(1, 1),
              transform: CanvasTransform.translation(const Offset(1, 1)),
            ),
          ),
        ],
      ),
    ),
  );
}
