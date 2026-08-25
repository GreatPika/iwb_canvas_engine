import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import '../../support/runtime_with_document.dart';

void main() {
  test('readDocument projects committed document facts', () {
    final initial = _document();
    final runtime = runtimeWithDocument(initial);

    final projection = runtime.readDocument();

    expect(identical(projection, initial), isFalse);
    expect(projection.resources.single.id, CanvasResourceId('r0'));
    expect(projection.backgroundElements.single.id, CanvasElementId('e0'));
    expect(projection.layers.single.id, CanvasLayerId('l0'));
    expect(projection.layers.single.elements.single.id, CanvasElementId('e2'));
    expect(projection.camera, CanvasCamera(offset: const Offset(4, 5)));

    runtime.dispose();
  });
}

CanvasDocument _document() {
  return CanvasDocument(
    camera: CanvasCamera(offset: const Offset(4, 5)),
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('r0'),
        source: CanvasResourceSource.appKey('asset-a'),
      ),
    ],
    backgroundElements: [
      CanvasRectElement(id: CanvasElementId('e0'), size: const Size(1, 1)),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('l0'),
        elements: [
          CanvasRectElement(id: CanvasElementId('e2'), size: const Size(2, 2)),
        ],
      ),
    ],
  );
}
