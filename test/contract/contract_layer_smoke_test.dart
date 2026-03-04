import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';

void main() {
  test('contract snapshot remains the canonical immutable contract owner', () {
    final snapshot = SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          id: 'layer-1',
          nodes: const <NodeSnapshot>[
            RectNodeSnapshot(
              id: 'rect-1',
              size: Size(10, 12),
              strokeColor: Color(0xFF000000),
            ),
          ],
        ),
      ],
    );

    expect(snapshot.layers.single.id, 'layer-1');
    expect(snapshot.layers.single.nodes.single.id, 'rect-1');
    expect(snapshot.backgroundLayer.nodes, isEmpty);
  });
}
