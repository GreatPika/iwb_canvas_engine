import 'dart:ui';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

// INV:INV-V2-NO-EXTERNAL-MUTATION
// INV:INV-G-PUBLIC-ENTRYPOINTS

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('iwb_canvas_engine.dart exports immutable snapshots/specs/patches', () {
    final scene = SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
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

  test('iwb_canvas_engine.dart exports snapshot json codec helpers', () {
    final scene = SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          nodes: <NodeSnapshot>[
            const RectNodeSnapshot(id: 'rect-json-1', size: Size(2, 3)),
          ],
        ),
      ],
    );
    final encoded = encodeScene(scene);
    final decoded = decodeScene(encoded);
    final decodedNode = decoded.layers.first.nodes.single;

    expect(encoded['schemaVersion'], schemaVersionWrite);
    expect(decodedNode.id, 'rect-json-1');
  });

  test('iwb_canvas_engine.dart exports low-level pointer input contracts', () {
    const sample = PointerSample(
      pointerId: 1,
      position: Offset(10, 20),
      timestampMs: 100,
      phase: PointerPhase.down,
    );
    final signal = PointerSignal.fromSample(
      sample,
      PointerSignalType.doubleTap,
    );

    expect(sample.phase, PointerPhase.down);
    expect(signal.type, PointerSignalType.doubleTap);
    expect(signal.position, const Offset(10, 20));
  });

  test('advanced.dart entrypoint is removed', () {
    expect(File('lib/advanced.dart').existsSync(), isFalse);
  });
}
