import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('projected public document cannot mutate committed store facts', () {
    final runtime = CanvasRuntime(
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
    );

    final projection = runtime.readDocument();

    expect(
      () => projection.layers.add(CanvasLayer(id: CanvasLayerId('layer-b'))),
      throwsUnsupportedError,
    );
    expect(
      () => projection.layers.single.elements.add(
        CanvasRectElement(
          id: CanvasElementId('element-b'),
          size: const Size(1, 1),
        ),
      ),
      throwsUnsupportedError,
    );
    expect(runtime.readDocument().layers, hasLength(1));
    expect(runtime.readDocument().layers.single.elements, hasLength(1));

    runtime.dispose();
  });
}
