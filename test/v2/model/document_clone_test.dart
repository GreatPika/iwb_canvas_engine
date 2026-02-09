import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/core/transform2d.dart';
import 'package:iwb_canvas_engine/src/v2/model/document_clone.dart';

void main() {
  Scene sourceScene() {
    return Scene(
      layers: <Layer>[
        Layer(
          isBackground: true,
          nodes: <SceneNode>[RectNode(id: 'bg-0', size: const Size(100, 100))],
        ),
        Layer(
          nodes: <SceneNode>[
            ImageNode(
              id: 'node-1',
              imageId: 'image://1',
              size: const Size(10, 10),
              naturalSize: const Size(20, 20),
              transform: const Transform2D(
                a: 1,
                b: 0,
                c: 0,
                d: 1,
                tx: 1,
                ty: 2,
              ),
            ),
            TextNode(
              id: 'node-2',
              text: 'hello',
              size: const Size(10, 5),
              fontSize: 12,
              color: const Color(0xFF111111),
              align: TextAlign.right,
              isBold: true,
              isItalic: true,
              isUnderline: true,
              fontFamily: 'Mono',
              maxWidth: 80,
              lineHeight: 1.3,
            ),
            StrokeNode(
              id: 'node-3',
              points: <Offset>[const Offset(0, 0), const Offset(3, 4)],
              thickness: 2,
              color: const Color(0xFF222222),
            ),
            LineNode(
              id: 'node-4',
              start: const Offset(0, 0),
              end: const Offset(5, 5),
              thickness: 2,
              color: const Color(0xFF333333),
            ),
            RectNode(
              id: 'node-5',
              size: const Size(4, 6),
              fillColor: const Color(0xFF444444),
              strokeColor: const Color(0xFF555555),
              strokeWidth: 2,
            ),
            PathNode(
              id: 'node-6',
              svgPathData: 'M0 0 L5 5',
              fillColor: const Color(0xFF666666),
              strokeColor: const Color(0xFF777777),
              strokeWidth: 3,
              fillRule: PathFillRule.evenOdd,
            ),
            RectNode(id: 'custom-id', size: const Size(1, 1)),
          ],
        ),
      ],
      camera: Camera(offset: const Offset(10, 20)),
      background: Background(
        color: const Color(0xFFFAFAFA),
        grid: GridSettings(
          isEnabled: true,
          cellSize: 12,
          color: const Color(0xFF101010),
        ),
      ),
      palette: ScenePalette(
        penColors: <Color>[const Color(0xFF000001)],
        backgroundColors: <Color>[const Color(0xFF000002)],
        gridSizes: <double>[12, 24],
      ),
    );
  }

  test('txnCloneScene deep clones scene, layers, nodes and mutable lists', () {
    final source = sourceScene();
    final clone = txnCloneScene(source);

    expect(clone, isNot(same(source)));
    expect(clone.layers, isNot(same(source.layers)));
    expect(clone.layers.length, source.layers.length);
    expect(clone.camera.offset, source.camera.offset);
    expect(clone.background.grid.cellSize, 12);
    expect(clone.palette.penColors, source.palette.penColors);

    final sourceNode = source.layers[1].nodes[2] as StrokeNode;
    final cloneNode = clone.layers[1].nodes[2] as StrokeNode;
    expect(cloneNode, isNot(same(sourceNode)));
    expect(cloneNode.points, isNot(same(sourceNode.points)));
    expect(cloneNode.points, sourceNode.points);

    cloneNode.points.add(const Offset(99, 99));
    expect(sourceNode.points.length, 2);

    final cloneRect = clone.layers[1].nodes[4] as RectNode;
    cloneRect.size = const Size(100, 200);
    final sourceRect = source.layers[1].nodes[4] as RectNode;
    expect(sourceRect.size, const Size(4, 6));
  });

  test('txnCloneLayer and txnCloneNode keep node type fidelity', () {
    final source = sourceScene();
    final layerClone = txnCloneLayer(source.layers[1]);

    expect(layerClone.isBackground, isFalse);
    expect(layerClone.nodes.length, source.layers[1].nodes.length);
    expect(layerClone.nodes[0], isA<ImageNode>());
    expect(layerClone.nodes[1], isA<TextNode>());
    expect(layerClone.nodes[2], isA<StrokeNode>());
    expect(layerClone.nodes[3], isA<LineNode>());
    expect(layerClone.nodes[4], isA<RectNode>());
    expect(layerClone.nodes[5], isA<PathNode>());

    final clonedPath = txnCloneNode(source.layers[1].nodes[5]) as PathNode;
    expect(clonedPath.fillRule, PathFillRule.evenOdd);
  });

  test('txnCollectNodeIds gathers all ids across layers', () {
    final ids = txnCollectNodeIds(sourceScene());
    expect(
      ids,
      containsAll(<NodeId>{
        'bg-0',
        'node-1',
        'node-2',
        'node-3',
        'node-4',
        'node-5',
        'node-6',
        'custom-id',
      }),
    );
  });

  test(
    'txnInitialNodeIdSeed finds max numeric node-* id and ignores invalid ids',
    () {
      final scene = sourceScene();
      scene.layers[1].nodes.add(
        RectNode(id: 'node-10', size: const Size(1, 1)),
      );
      scene.layers[1].nodes.add(
        RectNode(id: 'node--1', size: const Size(1, 1)),
      );
      scene.layers[1].nodes.add(
        RectNode(id: 'node-abc', size: const Size(1, 1)),
      );
      scene.layers[1].nodes.add(RectNode(id: 'node-', size: const Size(1, 1)));
      scene.layers[1].nodes.add(
        RectNode(id: 'plain-id', size: const Size(1, 1)),
      );

      expect(txnInitialNodeIdSeed(scene), 11);
      expect(txnInitialNodeIdSeed(Scene()), 0);
    },
  );
}
