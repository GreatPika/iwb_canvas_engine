import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/basic.dart';

void main() {
  // INV:INV-CORE-SCENE-LAYER-DEFENSIVE-LISTS
  test('Scene constructor defensively copies layers list', () {
    final externalLayers = <Layer>[Layer()];
    final scene = Scene(layers: externalLayers);

    expect(scene.layers.length, 1);

    externalLayers.add(Layer());
    expect(scene.layers.length, 1);

    externalLayers.clear();
    expect(scene.layers.length, 1);
  });

  test('Layer constructor defensively copies nodes list', () {
    final externalNodes = <SceneNode>[
      RectNode(
        id: 'rect-1',
        size: const Size(10, 10),
        fillColor: const Color(0xFF000000),
      ),
    ];
    final layer = Layer(nodes: externalNodes);

    expect(layer.nodes.length, 1);

    externalNodes.add(
      RectNode(
        id: 'rect-2',
        size: const Size(20, 20),
        fillColor: const Color(0xFF000000),
      ),
    );
    expect(layer.nodes.length, 1);

    externalNodes.clear();
    expect(layer.nodes.length, 1);
  });

  test('Scene and Layer default lists remain mutable', () {
    final scene = Scene();
    expect(scene.layers, isEmpty);
    scene.layers.add(Layer());
    expect(scene.layers.length, 1);

    final layer = Layer();
    expect(layer.nodes, isEmpty);
    layer.nodes.add(
      RectNode(
        id: 'rect-3',
        size: const Size(1, 1),
        fillColor: const Color(0xFF000000),
      ),
    );
    expect(layer.nodes.length, 1);
  });
}
