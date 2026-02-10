import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/basic_v2.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/v2/model/document.dart';

void main() {
  Scene sceneWithAllNodeTypes() {
    return Scene(
      layers: <Layer>[
        Layer(isBackground: true, nodes: <SceneNode>[]),
        Layer(
          nodes: <SceneNode>[
            ImageNode(
              id: 'img',
              imageId: 'image://1',
              size: const Size(10, 20),
              naturalSize: const Size(20, 40),
              opacity: 0.9,
              hitPadding: 1,
            ),
            TextNode(
              id: 'txt',
              text: 'hello',
              size: const Size(30, 12),
              fontSize: 14,
              color: const Color(0xFF123456),
              align: TextAlign.center,
              isBold: true,
              isItalic: true,
              isUnderline: true,
              fontFamily: 'Mono',
              maxWidth: 120,
              lineHeight: 1.2,
              opacity: 0.8,
              hitPadding: 2,
            ),
            StrokeNode(
              id: 'str',
              points: <Offset>[const Offset(0, 0), const Offset(5, 5)],
              thickness: 2,
              color: const Color(0xFF000000),
              opacity: 0.7,
              hitPadding: 0.5,
            ),
            LineNode(
              id: 'lin',
              start: const Offset(0, 0),
              end: const Offset(10, 0),
              thickness: 3,
              color: const Color(0xFF111111),
              opacity: 0.6,
              hitPadding: 0.2,
            ),
            RectNode(
              id: 'rec',
              size: const Size(12, 9),
              fillColor: const Color(0xFFEEEEEE),
              strokeColor: const Color(0xFF222222),
              strokeWidth: 1.5,
              opacity: 0.5,
              hitPadding: 0.3,
            ),
            PathNode(
              id: 'pth',
              svgPathData: 'M0 0 L10 10',
              fillColor: const Color(0xFFAAAAAA),
              strokeColor: const Color(0xFF333333),
              strokeWidth: 2,
              fillRule: PathFillRule.evenOdd,
              opacity: 0.4,
              hitPadding: 0.4,
            ),
          ],
        ),
      ],
      camera: Camera(offset: const Offset(2, 3)),
      background: Background(
        color: const Color(0xFFF5F5F5),
        grid: GridSettings(
          isEnabled: true,
          cellSize: 16,
          color: const Color(0xFF202020),
        ),
      ),
      palette: ScenePalette(
        penColors: <Color>[const Color(0xFF101010)],
        backgroundColors: <Color>[const Color(0xFFFFFFFF)],
        gridSizes: <double>[8, 16, 24],
      ),
    );
  }

  test('scene <-> snapshot conversion preserves node variants', () {
    final scene = sceneWithAllNodeTypes();
    final snapshot = txnSceneToSnapshot(scene);
    final restored = txnSceneFromSnapshot(snapshot);

    expect(restored.layers.length, scene.layers.length);
    expect(restored.camera.offset, const Offset(2, 3));
    expect(restored.background.grid.isEnabled, isTrue);
    expect(restored.background.grid.cellSize, 16);

    final nodes = restored.layers[1].nodes;
    expect(nodes[0], isA<ImageNode>());
    expect(nodes[1], isA<TextNode>());
    expect(nodes[2], isA<StrokeNode>());
    expect(nodes[3], isA<LineNode>());
    expect(nodes[4], isA<RectNode>());
    expect(nodes[5], isA<PathNode>());
    expect((nodes[5] as PathNode).fillRule, PathFillRule.evenOdd);
  });

  test('find/insert/erase node utilities work across layers', () {
    final scene = sceneWithAllNodeTypes();

    final found = txnFindNodeById(scene, 'txt');
    expect(found, isNotNull);
    expect(found!.layerIndex, 1);
    expect(found.nodeIndex, 1);
    expect(txnFindNodeById(scene, 'missing'), isNull);

    final inserted = RectNode(id: 'new', size: const Size(1, 1));
    txnInsertNodeInScene(scene: scene, node: inserted);
    expect(txnFindNodeById(scene, 'new'), isNotNull);

    final erased = txnEraseNodeFromScene(scene: scene, nodeId: 'new');
    expect(erased, isNotNull);
    expect(txnEraseNodeFromScene(scene: scene, nodeId: 'new'), isNull);
  });

  test(
    'resolve layer index validates range and creates non-background layer',
    () {
      final scene = Scene(layers: <Layer>[Layer(isBackground: true)]);

      expect(
        () => txnResolveInsertLayerIndex(scene: scene, layerIndex: -1),
        throwsRangeError,
      );
      expect(
        () => txnResolveInsertLayerIndex(scene: scene, layerIndex: 10),
        throwsRangeError,
      );

      final index = txnResolveInsertLayerIndex(scene: scene, layerIndex: null);
      expect(index, 1);
      expect(scene.layers.length, 2);
      expect(scene.layers.last.isBackground, isFalse);
    },
  );

  test('selection/grid helpers enforce transaction invariants', () {
    final scene = Scene(
      layers: <Layer>[
        Layer(
          isBackground: true,
          nodes: <SceneNode>[RectNode(id: 'bg', size: const Size(1, 1))],
        ),
        Layer(
          nodes: <SceneNode>[
            RectNode(id: 'ok', size: const Size(1, 1)),
            RectNode(id: 'hidden', size: const Size(1, 1), isVisible: false),
            RectNode(id: 'nonsel', size: const Size(1, 1), isSelectable: false),
            RectNode(id: 'locked', size: const Size(1, 1), isLocked: true),
            RectNode(
              id: 'fixed',
              size: const Size(1, 1),
              isTransformable: false,
            ),
          ],
        ),
      ],
      background: Background(
        grid: GridSettings(isEnabled: true, cellSize: 0.2),
      ),
    );

    final normalized = txnNormalizeSelection(
      rawSelection: <NodeId>{'ok', 'hidden', 'nonsel', 'bg', 'missing'},
      scene: scene,
    );
    expect(normalized, <NodeId>{'ok'});

    expect(
      txnTranslateSelection(
        scene: scene,
        selectedNodeIds: <NodeId>{'ok'},
        delta: Offset.zero,
      ),
      isEmpty,
    );

    final moved = txnTranslateSelection(
      scene: scene,
      selectedNodeIds: <NodeId>{'ok', 'locked', 'fixed', 'bg'},
      delta: const Offset(10, 2),
    );
    expect(moved, <NodeId>{'ok'});

    final ok = txnFindNodeById(scene, 'ok')!.node as RectNode;
    expect(ok.transform.tx, 10);

    expect(txnNormalizeGrid(scene), isTrue);
    expect(scene.background.grid.cellSize, 1.0);
    expect(txnNormalizeGrid(scene), isFalse);
  });

  test('node-from-spec maps all variants and fallback id behavior', () {
    final image = txnNodeFromSpec(
      ImageNodeSpec(imageId: 'i', size: const Size(1, 2)),
      fallbackId: 'auto-1',
    );
    final text = txnNodeFromSpec(
      TextNodeSpec(
        text: 't',
        size: const Size(3, 4),
        color: const Color(0xFF000000),
      ),
      fallbackId: 'auto-2',
    );
    final stroke = txnNodeFromSpec(
      StrokeNodeSpec(
        points: <Offset>[const Offset(0, 0), const Offset(1, 1)],
        thickness: 2,
        color: const Color(0xFF111111),
      ),
      fallbackId: 'auto-3',
    );
    final line = txnNodeFromSpec(
      LineNodeSpec(
        start: const Offset(0, 0),
        end: const Offset(1, 1),
        thickness: 2,
        color: const Color(0xFF222222),
      ),
      fallbackId: 'auto-4',
    );
    final rect = txnNodeFromSpec(
      RectNodeSpec(size: const Size(2, 2)),
      fallbackId: 'auto-5',
    );
    final path = txnNodeFromSpec(
      PathNodeSpec(svgPathData: 'M0 0 L1 1', fillRule: V2PathFillRule.evenOdd),
      fallbackId: 'auto-6',
    );
    final explicit = txnNodeFromSpec(
      RectNodeSpec(id: 'explicit', size: const Size(4, 4)),
      fallbackId: 'ignored',
    );

    expect(image.id, 'auto-1');
    expect(text.id, 'auto-2');
    expect(stroke.id, 'auto-3');
    expect(line.id, 'auto-4');
    expect(rect.id, 'auto-5');
    expect(path.id, 'auto-6');
    expect((path as PathNode).fillRule, PathFillRule.evenOdd);
    expect(explicit.id, 'explicit');
  });

  test('node patch applies type-specific fields and common fields', () {
    final image = ImageNode(id: 'img', imageId: 'a', size: const Size(1, 1));
    expect(
      txnApplyNodePatch(
        image,
        const ImageNodePatch(
          id: 'img',
          common: CommonNodePatch(
            opacity: PatchField<double>.value(0.5),
            hitPadding: PatchField<double>.value(2),
            isVisible: PatchField<bool>.value(false),
            isSelectable: PatchField<bool>.value(false),
            isLocked: PatchField<bool>.value(true),
            isDeletable: PatchField<bool>.value(false),
            isTransformable: PatchField<bool>.value(false),
          ),
          imageId: PatchField<String>.value('b'),
          size: PatchField<Size>.value(Size(2, 3)),
          naturalSize: PatchField<Size?>.value(Size(4, 5)),
        ),
      ),
      isTrue,
    );
    expect(image.imageId, 'b');
    expect(image.opacity, 0.5);
    expect(image.hitPadding, 2);
    expect(image.isVisible, isFalse);
    expect(image.isSelectable, isFalse);
    expect(image.isLocked, isTrue);
    expect(image.isDeletable, isFalse);
    expect(image.isTransformable, isFalse);

    final text = TextNode(
      id: 'txt',
      text: 'x',
      size: const Size(1, 1),
      color: const Color(0xFF000000),
    );
    expect(
      txnApplyNodePatch(
        text,
        const TextNodePatch(
          id: 'txt',
          text: PatchField<String>.value('y'),
          size: PatchField<Size>.value(Size(4, 4)),
          fontSize: PatchField<double>.value(18),
          color: PatchField<Color>.value(Color(0xFF111111)),
          align: PatchField<TextAlign>.value(TextAlign.right),
          isBold: PatchField<bool>.value(true),
          isItalic: PatchField<bool>.value(true),
          isUnderline: PatchField<bool>.value(true),
          fontFamily: PatchField<String?>.value('Mono'),
          maxWidth: PatchField<double?>.value(100),
          lineHeight: PatchField<double?>.value(1.5),
        ),
      ),
      isTrue,
    );
    expect(text.text, 'y');
    expect(text.align, TextAlign.right);
    expect(text.fontFamily, 'Mono');

    final stroke = StrokeNode(
      id: 'str',
      points: <Offset>[const Offset(0, 0), const Offset(1, 1)],
      thickness: 1,
      color: const Color(0xFF000000),
    );
    expect(
      txnApplyNodePatch(
        stroke,
        const StrokeNodePatch(
          id: 'str',
          points: PatchField<List<Offset>>.value(<Offset>[
            Offset(2, 2),
            Offset(3, 3),
          ]),
          thickness: PatchField<double>.value(4),
          color: PatchField<Color>.value(Color(0xFF333333)),
        ),
      ),
      isTrue,
    );
    expect(stroke.points, <Offset>[const Offset(2, 2), const Offset(3, 3)]);

    final line = LineNode(
      id: 'lin',
      start: const Offset(0, 0),
      end: const Offset(1, 1),
      thickness: 1,
      color: const Color(0xFF000000),
    );
    expect(
      txnApplyNodePatch(
        line,
        const LineNodePatch(
          id: 'lin',
          start: PatchField<Offset>.value(Offset(2, 0)),
          end: PatchField<Offset>.value(Offset(5, 1)),
          thickness: PatchField<double>.value(2),
          color: PatchField<Color>.value(Color(0xFF444444)),
        ),
      ),
      isTrue,
    );
    expect(line.start, const Offset(2, 0));

    final rect = RectNode(
      id: 'rec',
      size: const Size(1, 1),
      fillColor: const Color(0xFFAAAAAA),
      strokeColor: const Color(0xFFBBBBBB),
      strokeWidth: 1,
    );
    expect(
      txnApplyNodePatch(
        rect,
        const RectNodePatch(
          id: 'rec',
          size: PatchField<Size>.value(Size(6, 7)),
          fillColor: PatchField<Color?>.nullValue(),
          strokeColor: PatchField<Color?>.value(Color(0xFFCCCCCC)),
          strokeWidth: PatchField<double>.value(3),
        ),
      ),
      isTrue,
    );
    expect(rect.fillColor, isNull);
    expect(rect.strokeColor, const Color(0xFFCCCCCC));

    final path = PathNode(
      id: 'pth',
      svgPathData: 'M0 0 L1 1',
      strokeColor: const Color(0xFF020202),
      fillRule: PathFillRule.nonZero,
    );
    expect(
      txnApplyNodePatch(
        path,
        const PathNodePatch(
          id: 'pth',
          svgPathData: PatchField<String>.value('M0 0 L5 5'),
          fillColor: PatchField<Color?>.value(Color(0xFF111111)),
          strokeColor: PatchField<Color?>.nullValue(),
          strokeWidth: PatchField<double>.value(4),
          fillRule: PatchField<V2PathFillRule>.value(V2PathFillRule.evenOdd),
        ),
      ),
      isTrue,
    );
    expect(path.svgPathData, 'M0 0 L5 5');
    expect(path.strokeColor, isNull);
    expect(path.fillRule, PathFillRule.evenOdd);
  });

  test('node patch validates id, patch type and nullability constraints', () {
    final rectNoop = RectNode(id: 'x', size: const Size(1, 1));
    expect(txnApplyNodePatch(rectNoop, const RectNodePatch(id: 'x')), isFalse);

    final rect = RectNode(id: 'r1', size: const Size(1, 1));
    expect(
      () => txnApplyNodePatch(rect, const RectNodePatch(id: 'other')),
      throwsArgumentError,
    );
    expect(
      () => txnApplyNodePatch(
        rect,
        const RectNodePatch(id: 'r1', size: PatchField<Size>.nullValue()),
      ),
      throwsArgumentError,
    );
    expect(
      () => txnApplyNodePatch(rect, const PathNodePatch(id: 'r1')),
      throwsArgumentError,
    );

    final stroke = StrokeNode(
      id: 's1',
      points: <Offset>[const Offset(0, 0)],
      thickness: 1,
      color: const Color(0xFF000000),
    );
    expect(
      () => txnApplyNodePatch(
        stroke,
        const StrokeNodePatch(
          id: 's1',
          points: PatchField<List<Offset>>.nullValue(),
        ),
      ),
      throwsArgumentError,
    );
  });
}
