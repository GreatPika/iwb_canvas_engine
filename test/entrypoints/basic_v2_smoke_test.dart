import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/basic_v2.dart';

// INV:INV-V2-NO-EXTERNAL-MUTATION

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('basic_v2.dart exports immutable snapshots/specs/patches', () {
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

    final imageSpec = ImageNodeSpec(
      id: 'img-1',
      imageId: 'image://1',
      size: Size(32, 32),
      naturalSize: Size(64, 64),
      transform: Transform2D(a: 1, b: 0, c: 0, d: 1, tx: 1, ty: 2),
      opacity: 0.5,
      hitPadding: 1,
      isVisible: false,
      isSelectable: false,
      isLocked: true,
      isDeletable: false,
      isTransformable: false,
    );

    final textSpec = TextNodeSpec(
      text: 'Hello',
      size: Size(100, 40),
      fontSize: 20,
      color: Color(0xFF123456),
      align: TextAlign.end,
      isBold: true,
      isItalic: true,
      isUnderline: true,
      fontFamily: 'Serif',
      maxWidth: 120,
      lineHeight: 1.4,
    );

    final strokeSpec = StrokeNodeSpec(
      points: <Offset>[const Offset(0, 0), const Offset(1, 1)],
      thickness: 3,
      color: const Color(0xFF654321),
    );

    final lineSpec = LineNodeSpec(
      start: Offset(1, 2),
      end: Offset(3, 4),
      thickness: 2,
      color: Color(0xFFFF00FF),
    );

    final rectSpec = RectNodeSpec(
      size: Size(20, 10),
      fillColor: Color(0xFF00FFFF),
      strokeColor: Color(0xFF000000),
      strokeWidth: 1.5,
    );

    final pathSpec = PathNodeSpec(
      svgPathData: 'M0 0 H10 V10 Z',
      fillColor: Color(0xFF111111),
      strokeColor: Color(0xFF222222),
      strokeWidth: 2,
      fillRule: V2PathFillRule.evenOdd,
    );

    expect(imageSpec.id, 'img-1');
    expect(imageSpec.isTransformable, isFalse);
    expect(textSpec.fontFamily, 'Serif');
    expect(textSpec.align, TextAlign.end);
    expect(strokeSpec.points.length, 2);
    expect(
      () => strokeSpec.points.add(const Offset(2, 2)),
      throwsUnsupportedError,
    );
    expect(lineSpec.end, const Offset(3, 4));
    expect(rectSpec.fillColor, const Color(0xFF00FFFF));
    expect(pathSpec.fillRule, V2PathFillRule.evenOdd);

    final implicitIdSpec = RectNodeSpec(size: const Size(1, 1));
    expect(implicitIdSpec.id, isNull);

    const patch = RectNodePatch(
      id: 'rect-1',
      size: PatchField<Size>.value(Size(50, 30)),
    );
    expect(patch.size.value, const Size(50, 30));
  });

  test('basic_v2.dart exports snapshot json codec helpers', () {
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
    final encodedJson = encodeSceneToJson(scene);
    final decodedJson = decodeSceneFromJson(encodedJson);
    final decodedNode = decoded.layers
        .firstWhere((layer) => !layer.isBackground)
        .nodes
        .single;
    final decodedJsonNode = decodedJson.layers
        .firstWhere((layer) => !layer.isBackground)
        .nodes
        .single;

    expect(encoded['schemaVersion'], schemaVersionWrite);
    expect(decodedNode.id, 'rect-json-1');
    expect(decodedJsonNode.id, 'rect-json-1');
  });
}
