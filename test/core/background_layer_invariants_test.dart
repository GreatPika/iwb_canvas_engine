import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/background_layer_invariants.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';

void main() {
  test('ensureBackgroundLayer creates background layer when missing', () {
    final scene = Scene(
      layers: <ContentLayer>[ContentLayer(id: 'layer-auto-2')],
    );

    final layer = ensureBackgroundLayer(scene);

    expect(scene.backgroundLayer, isNotNull);
    expect(identical(scene.backgroundLayer, layer), isTrue);
  });

  test('ensureBackgroundLayer returns existing layer without replacement', () {
    final existing = BackgroundLayer();
    final scene = Scene(
      backgroundLayer: existing,
      layers: <ContentLayer>[ContentLayer(id: 'layer-auto-3')],
    );

    final resolved = ensureBackgroundLayer(scene);

    expect(identical(resolved, existing), isTrue);
    expect(identical(scene.backgroundLayer, existing), isTrue);
  });

  test('SceneSnapshot provides empty background layer when omitted', () {
    final snapshot = SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          id: 'layer-auto-0',
          nodes: const <NodeSnapshot>[
            RectNodeSnapshot(id: 'n1', size: Size(1, 1)),
          ],
        ),
      ],
    );

    expect(snapshot.backgroundLayer.nodes, isEmpty);
    expect(snapshot.layers.single.nodes.single.id, 'n1');
  });
}
