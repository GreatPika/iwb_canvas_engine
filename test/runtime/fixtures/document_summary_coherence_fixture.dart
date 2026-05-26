import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('document summary coherence matches initial projection counts', () {
    final runtime = CanvasRuntime(initialDocument: _document());

    final document = runtime.readDocument();

    _expectSummaryMatchesDocument(runtime, document);
    expect(runtime.state.value.summary.elementCount, 2);

    runtime.dispose();
  });
}

CanvasDocument _document() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('resource-a'),
        source: CanvasResourceSource.appKey('asset-a'),
      ),
    ],
    backgroundElements: [
      CanvasRectElement(
        id: CanvasElementId('background-a'),
        size: const Size(1, 1),
      ),
    ],
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
  );
}

void _expectSummaryMatchesDocument(
  CanvasRuntime runtime,
  CanvasDocument document,
) {
  expect(
    document.resources,
    hasLength(runtime.state.value.summary.resourceCount),
  );
  expect(document.layers, hasLength(runtime.state.value.summary.layerCount));
  expect(_elementCount(document), runtime.state.value.summary.elementCount);
}

int _elementCount(CanvasDocument document) {
  return document.backgroundElements.length +
      document.layers.fold<int>(
        0,
        (count, layer) => count + layer.elements.length,
      );
}
