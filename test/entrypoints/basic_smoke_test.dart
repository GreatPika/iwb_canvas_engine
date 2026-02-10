import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/basic.dart';

// INV:INV-V2-NO-EXTERNAL-MUTATION
// INV:INV-G-PUBLIC-ENTRYPOINTS

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('basic.dart exports immutable snapshots/specs/patches', () {
    final scene = SceneSnapshot(
      layers: <LayerSnapshot>[
        LayerSnapshot(
          nodes: <NodeSnapshot>[
            const RectNodeSnapshot(id: 'rect-1', size: Size(40, 20)),
          ],
        ),
      ],
    );

    expect(scene.layers.single.nodes.single.id, 'rect-1');

    const patch = RectNodePatch(
      id: 'rect-1',
      size: PatchField<Size>.value(Size(50, 30)),
    );
    expect(patch.size.value, const Size(50, 30));
  });

  test('basic.dart exports snapshot json codec helpers', () {
    final scene = SceneSnapshot(
      layers: <LayerSnapshot>[
        LayerSnapshot(
          nodes: <NodeSnapshot>[
            const RectNodeSnapshot(id: 'rect-json-1', size: Size(2, 3)),
          ],
        ),
      ],
    );
    final encoded = encodeScene(scene);
    final decoded = decodeScene(encoded);
    final decodedNode = decoded.layers
        .firstWhere((layer) => !layer.isBackground)
        .nodes
        .single;

    expect(encoded['schemaVersion'], schemaVersionWrite);
    expect(decodedNode.id, 'rect-json-1');
  });
}
