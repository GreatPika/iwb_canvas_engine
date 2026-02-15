import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/background_layer_invariants.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/public/snapshot.dart';

void main() {
  test('ensureBackgroundLayer creates background layer when missing', () {
    final scene = Scene(layers: <ContentLayer>[ContentLayer()]);

    final layer = ensureBackgroundLayer(scene);

    expect(scene.backgroundLayer, isNotNull);
    expect(identical(scene.backgroundLayer, layer), isTrue);
  });

  test('ensureBackgroundLayer returns existing layer without replacement', () {
    final existing = BackgroundLayer();
    final scene = Scene(
      backgroundLayer: existing,
      layers: <ContentLayer>[ContentLayer()],
    );

    final resolved = ensureBackgroundLayer(scene);

    expect(identical(resolved, existing), isTrue);
    expect(identical(scene.backgroundLayer, existing), isTrue);
  });

  test(
    'canonicalizeBackgroundLayerSnapshot adds empty background layer when missing',
    () {
      final snapshot = SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            nodes: const <NodeSnapshot>[
              RectNodeSnapshot(id: 'n1', size: Size(1, 1)),
            ],
          ),
        ],
      );

      final canonical = canonicalizeBackgroundLayerSnapshot(snapshot);

      expect(canonical.backgroundLayer.nodes, isEmpty);
      expect(canonical.layers.single.nodes.single.id, 'n1');
    },
  );

  test(
    'canonicalizeBackgroundLayerSnapshot keeps identity when already canonical',
    () {
      final snapshot = SceneSnapshot(
        backgroundLayer: BackgroundLayerSnapshot(
          nodes: const <NodeSnapshot>[
            RectNodeSnapshot(id: 'bg', size: Size(1, 1)),
          ],
        ),
        layers: <ContentLayerSnapshot>[ContentLayerSnapshot()],
      );

      final canonical = canonicalizeBackgroundLayerSnapshot(snapshot);

      expect(identical(canonical, snapshot), isTrue);
      expect(canonical.backgroundLayer.nodes.single.id, 'bg');
    },
  );
}
