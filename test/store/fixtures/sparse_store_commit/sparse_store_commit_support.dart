import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/sparse_store_commit.dart';
import 'package:iwb_canvas_engine/src/store/store_revision_delta.dart';

StoreElementFacts requireFacts(DocumentStoreKernel store, CanvasElementId id) {
  final facts = store.elementFactsById(id);
  expect(facts, isNotNull);

  return facts as StoreElementFacts;
}

StoreSparseUpdateElement sparseUpdate({
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

StoreSparseUpdateElement sparseRectFillColorUpdate({
  required String id,
  required Size size,
  required Color fillColor,
}) {
  return sparseUpdate(
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

CanvasRectElement contentRect({
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
CanvasDocument clearRetentionDocument() {
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
CanvasDocument manyResourceClearDocument() {
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
CanvasDocument clearBarrierDocument() {
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

CanvasDocument baseDocument() {
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

CanvasDocument textDocument() {
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

CanvasDocument resourceOnlyDocument() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('resource-only'),
        source: CanvasResourceSource.appKey('asset-only'),
      ),
    ],
  );
}

CanvasDocument multiRectDocument() {
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

CanvasPalette alternatePalette() {
  return CanvasPalette(
    penColors: const [Color(0xFF000000), Color(0xFFFFFFFF)],
    backgroundColors: const [Color(0xFF112233)],
    gridSizes: const [8, 16],
  );
}

CanvasDocument paintedStrokeDocument() {
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
