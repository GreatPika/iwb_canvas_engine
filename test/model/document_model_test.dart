import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/model/document.dart';

// INV:INV-V2-TEXT-SIZE-DERIVED

void main() {
  Scene sceneWithAllNodeTypes() {
    return Scene(
      layers: <ContentLayer>[
        ContentLayer(nodes: <SceneNode>[]),
        ContentLayer(
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
    final stroke = scene.layers[1].nodes[2] as StrokeNode;
    stroke.points[0] = const Offset(-1, -1);
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
    expect(
      (snapshot.layers[1].nodes[2] as StrokeNodeSnapshot).pointsRevision,
      1,
    );
    expect((nodes[2] as StrokeNode).pointsRevision, 1);
  });

  test('txnSceneFromSnapshot rejects negative stroke pointsRevision', () {
    expect(
      () => txnSceneFromSnapshot(
        SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              nodes: <NodeSnapshot>[
                StrokeNodeSnapshot(
                  id: 's',
                  points: const <Offset>[Offset(0, 0), Offset(1, 1)],
                  pointsRevision: -1,
                  thickness: 1,
                  color: const Color(0xFF000000),
                ),
              ],
            ),
          ],
        ),
      ),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'layers[0].nodes[0].pointsRevision' &&
              e.message ==
                  'Field layers[0].nodes[0].pointsRevision must be >= 0.',
        ),
      ),
    );
  });

  test('txnSceneFromSnapshot preserves dedicated background layer', () {
    final scene = txnSceneFromSnapshot(
      SceneSnapshot(
        backgroundLayer: BackgroundLayerSnapshot(
          nodes: const <NodeSnapshot>[
            RectNodeSnapshot(id: 'bg', size: Size(1, 1)),
          ],
        ),
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            nodes: const <NodeSnapshot>[
              RectNodeSnapshot(id: 'n1', size: Size(1, 1)),
            ],
          ),
          ContentLayerSnapshot(
            nodes: const <NodeSnapshot>[
              RectNodeSnapshot(id: 'n2', size: Size(1, 1)),
            ],
          ),
        ],
      ),
    );

    expect(scene.backgroundLayer, isNotNull);
    expect(scene.backgroundLayer!.nodes.single.id, 'bg');
    expect(scene.layers.length, 2);
    expect(scene.layers[0].nodes.single.id, 'n1');
    expect(scene.layers[1].nodes.single.id, 'n2');
  });

  test('txnSceneFromSnapshot canonicalizes missing background layer', () {
    // INV:INV-SER-CANONICAL-BACKGROUND-LAYER
    final scene = txnSceneFromSnapshot(
      SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            nodes: const <NodeSnapshot>[
              RectNodeSnapshot(id: 'n1', size: Size(1, 1)),
            ],
          ),
        ],
      ),
    );

    expect(scene.layers.length, 1);
    expect(scene.backgroundLayer, isNotNull);
    expect(scene.backgroundLayer!.nodes, isEmpty);
  });

  test(
    'snapshot import/export round-trip keeps canonical single background layer',
    () {
      // INV:INV-SER-CANONICAL-BACKGROUND-LAYER
      final imported = txnSceneFromSnapshot(
        SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              nodes: const <NodeSnapshot>[
                RectNodeSnapshot(id: 'n1', size: Size(1, 1)),
              ],
            ),
          ],
        ),
      );

      final exported = txnSceneToSnapshot(imported);
      final reimported = txnSceneFromSnapshot(exported);

      expect(exported.backgroundLayer, isNotNull);
      expect(exported.backgroundLayer!.nodes, isEmpty);
      expect(reimported.backgroundLayer, isNotNull);
      expect(reimported.backgroundLayer!.nodes, isEmpty);
      expect(reimported.layers.length, 1);
      expect(reimported.layers[0].nodes.single.id, 'n1');
    },
  );

  test('txnSceneFromSnapshot rejects duplicate node ids with field path', () {
    expect(
      () => txnSceneFromSnapshot(
        SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              nodes: const <NodeSnapshot>[
                RectNodeSnapshot(id: 'dup', size: Size(1, 1)),
              ],
            ),
            ContentLayerSnapshot(
              nodes: const <NodeSnapshot>[
                RectNodeSnapshot(id: 'dup', size: Size(2, 2)),
              ],
            ),
          ],
        ),
      ),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.duplicateNodeId &&
              e.path == 'layers[1].nodes[0].id' &&
              e.message == 'Must be unique across scene layers.',
        ),
      ),
    );
  });

  test('txnSceneFromSnapshot rejects non-finite transform values', () {
    expect(
      () => txnSceneFromSnapshot(
        SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              nodes: const <NodeSnapshot>[
                RectNodeSnapshot(
                  id: 'r1',
                  size: Size(1, 1),
                  transform: Transform2D(
                    a: double.nan,
                    b: 0,
                    c: 0,
                    d: 1,
                    tx: 0,
                    ty: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'layers[0].nodes[0].transform.a' &&
              e.message ==
                  'Field layers[0].nodes[0].transform.a must be finite.',
        ),
      ),
    );
  });

  test('find/locator/insert/erase node utilities work across layers', () {
    final scene = sceneWithAllNodeTypes();
    final locator = txnBuildNodeLocator(scene);

    final found = txnFindNodeById(scene, 'txt');
    expect(found, isNotNull);
    expect(found!.layerIndex, 1);
    expect(found.nodeIndex, 1);
    expect(txnFindNodeById(scene, 'missing'), isNull);
    final foundByLocator = txnFindNodeByLocator(
      scene: scene,
      nodeLocator: locator,
      nodeId: 'txt',
    );
    expect(foundByLocator, isNotNull);
    expect(foundByLocator!.layerIndex, 1);
    expect(foundByLocator.nodeIndex, 1);
    expect(
      txnFindNodeByLocator(
        scene: scene,
        nodeLocator: locator,
        nodeId: 'missing',
      ),
      isNull,
    );

    final inserted = RectNode(id: 'new', size: const Size(1, 1));
    txnInsertNodeInScene(scene: scene, nodeLocator: locator, node: inserted);
    final insertedFound = txnFindNodeByLocator(
      scene: scene,
      nodeLocator: locator,
      nodeId: 'new',
    );
    expect(insertedFound, isNotNull);
    expect(insertedFound!.layerIndex, 2);
    expect(insertedFound.nodeIndex, scene.layers[2].nodes.length - 1);

    final erased = txnEraseNodeFromScene(
      scene: scene,
      nodeLocator: locator,
      nodeId: 'new',
    );
    expect(erased, isNotNull);
    expect(
      txnEraseNodeFromScene(scene: scene, nodeLocator: locator, nodeId: 'new'),
      isNull,
    );
  });

  test('find/locator/erase utilities handle dedicated background layer', () {
    final scene = Scene(
      backgroundLayer: BackgroundLayer(
        nodes: <SceneNode>[
          RectNode(id: 'bg-a', size: const Size(1, 1)),
          RectNode(id: 'bg-b', size: const Size(1, 1)),
        ],
      ),
      layers: <ContentLayer>[
        ContentLayer(
          nodes: <SceneNode>[RectNode(id: 'fg-a', size: const Size(1, 1))],
        ),
      ],
    );
    final locator = txnBuildNodeLocator(scene);

    final bgFound = txnFindNodeById(scene, 'bg-a');
    expect(bgFound, isNotNull);
    expect(bgFound!.layerIndex, -1);
    expect(bgFound.nodeIndex, 0);

    final bgByLocator = txnFindNodeByLocator(
      scene: scene,
      nodeLocator: locator,
      nodeId: 'bg-b',
    );
    expect(bgByLocator, isNotNull);
    expect(bgByLocator!.layerIndex, -1);
    expect(bgByLocator.nodeIndex, 1);

    final wrongIndexLocator = <NodeId, NodeLocatorEntry>{
      ...locator,
      'bg-b': (layerIndex: -1, nodeIndex: 99),
    };
    expect(
      txnFindNodeByLocator(
        scene: scene,
        nodeLocator: wrongIndexLocator,
        nodeId: 'bg-b',
      ),
      isNull,
    );

    final wrongIdLocator = <NodeId, NodeLocatorEntry>{
      ...locator,
      'bg-a': (layerIndex: -1, nodeIndex: 1),
    };
    expect(
      txnFindNodeByLocator(
        scene: scene,
        nodeLocator: wrongIdLocator,
        nodeId: 'bg-a',
      ),
      isNull,
    );

    final removed = txnEraseNodeFromScene(
      scene: scene,
      nodeLocator: locator,
      nodeId: 'bg-a',
    );
    expect(removed, isNotNull);
    expect(locator.containsKey('bg-a'), isFalse);
    expect(locator['bg-b'], (layerIndex: -1, nodeIndex: 0));

    scene.backgroundLayer = null;
    expect(
      txnFindNodeByLocator(scene: scene, nodeLocator: locator, nodeId: 'bg-b'),
      isNull,
    );
  });

  test('erase updates locator indexes for layer tail', () {
    final scene = Scene(
      layers: <ContentLayer>[
        ContentLayer(
          nodes: <SceneNode>[
            RectNode(id: 'a', size: const Size(1, 1)),
            RectNode(id: 'b', size: const Size(1, 1)),
            RectNode(id: 'c', size: const Size(1, 1)),
          ],
        ),
      ],
    );
    final locator = txnBuildNodeLocator(scene);

    final removed = txnEraseNodeFromScene(
      scene: scene,
      nodeLocator: locator,
      nodeId: 'b',
    );
    expect(removed, isNotNull);
    expect(locator.containsKey('b'), isFalse);
    expect(locator['a'], (layerIndex: 0, nodeIndex: 0));
    expect(locator['c'], (layerIndex: 0, nodeIndex: 1));
  });

  test(
    'resolve layer index validates range and creates non-background layer',
    () {
      final scene = Scene(layers: <ContentLayer>[ContentLayer()]);

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
      expect(scene.layers.last, isA<ContentLayer>());
    },
  );

  test('selection/grid helpers enforce transaction invariants', () {
    final scene = Scene(
      backgroundLayer: BackgroundLayer(
        nodes: <SceneNode>[RectNode(id: 'bg', size: const Size(1, 1))],
      ),
      layers: <ContentLayer>[
        ContentLayer(
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
    expect(normalized, <NodeId>{'ok', 'nonsel'});

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
      ImageNodeSpec(
        imageId: 'i',
        size: const Size(1, 2),
        naturalSize: const Size(2, 4),
      ),
      fallbackId: 'auto-1',
    );
    final text = txnNodeFromSpec(
      TextNodeSpec(
        text: 't',
        maxWidth: 20,
        lineHeight: 1.5,
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
    expect((image as ImageNode).naturalSize, const Size(2, 4));
    final textNode = text as TextNode;
    expect(text.id, 'auto-2');
    expect(textNode.maxWidth, 20);
    expect(textNode.lineHeight, 1.5);
    expect(stroke.id, 'auto-3');
    expect(line.id, 'auto-4');
    expect(rect.id, 'auto-5');
    expect(path.id, 'auto-6');
    expect((path as PathNode).fillRule, PathFillRule.evenOdd);
    expect(explicit.id, 'explicit');
  });

  test('node-from-spec allocates instanceRevision from allocator', () {
    var nextInstanceRevision = 5;
    int allocate() => nextInstanceRevision++;

    final a = txnNodeFromSpec(
      RectNodeSpec(size: const Size(1, 1)),
      fallbackId: 'a',
      nextInstanceRevision: allocate,
    );
    final b = txnNodeFromSpec(
      RectNodeSpec(size: const Size(1, 1)),
      fallbackId: 'b',
      nextInstanceRevision: allocate,
    );

    expect(a.instanceRevision, 5);
    expect(b.instanceRevision, 6);
  });

  test(
    'node-from-snapshot preserves positive instanceRevision and allocates non-positive',
    () {
      var nextInstanceRevision = 10;
      int allocate() => nextInstanceRevision++;

      final preserved = txnNodeFromSnapshot(
        const RectNodeSnapshot(
          id: 'preserved',
          instanceRevision: 7,
          size: Size(1, 1),
        ),
        nextInstanceRevision: allocate,
      );
      final allocated = txnNodeFromSnapshot(
        const RectNodeSnapshot(id: 'allocated', size: Size(1, 1)),
        nextInstanceRevision: allocate,
      );

      expect(preserved.instanceRevision, 7);
      expect(allocated.instanceRevision, 10);
    },
  );

  test(
    'txnSceneFromSnapshot allocates instanceRevision for non-positive values',
    () {
      var nextInstanceRevision = 20;
      int allocate() => nextInstanceRevision++;

      final scene = txnSceneFromSnapshot(
        SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              nodes: const <NodeSnapshot>[
                RectNodeSnapshot(id: 'a', size: Size(1, 1)),
                RectNodeSnapshot(
                  id: 'b',
                  instanceRevision: 9,
                  size: Size(1, 1),
                ),
              ],
            ),
          ],
        ),
        nextInstanceRevision: allocate,
      );

      final nodeA = txnFindNodeById(scene, 'a')!.node;
      final nodeB = txnFindNodeById(scene, 'b')!.node;
      expect(nodeA.instanceRevision, 20);
      expect(nodeB.instanceRevision, 9);
    },
  );

  test('text node from spec derives size from text layout', () {
    final node =
        txnNodeFromSpec(
              TextNodeSpec(
                text: 'Derived size',
                fontSize: 20,
                color: const Color(0xFF000000),
              ),
              fallbackId: 'auto-text',
            )
            as TextNode;

    expect(node.size.width, greaterThan(0));
    expect(node.size.height, greaterThan(0));
  });

  test('text node from snapshot recomputes stale serialized size', () {
    final node =
        txnNodeFromSnapshot(
              const TextNodeSnapshot(
                id: 'text-stale',
                text: 'Derived size',
                size: Size(1, 1),
                fontSize: 24,
                color: Color(0xFF000000),
              ),
            )
            as TextNode;

    expect(node.size, isNot(const Size(1, 1)));
    expect(node.size.width, greaterThan(1));
    expect(node.size.height, greaterThan(1));
  });

  test('node-from-spec rejects invalid numeric fields with field path', () {
    final invalidCases = <({NodeSpec spec, String field, String message})>[
      (
        spec: RectNodeSpec(size: const Size(1, 1), opacity: 1.1),
        field: 'spec.opacity',
        message: 'Must be within [0,1].',
      ),
      (
        spec: RectNodeSpec(
          size: const Size(1, 1),
          transform: const Transform2D(
            a: double.nan,
            b: 0,
            c: 0,
            d: 1,
            tx: 0,
            ty: 0,
          ),
        ),
        field: 'spec.transform.a',
        message: 'Must be finite.',
      ),
      (
        spec: TextNodeSpec(
          text: 't',
          fontSize: 0,
          color: const Color(0xFF000000),
        ),
        field: 'spec.fontSize',
        message: 'Must be > 0.',
      ),
      (
        spec: StrokeNodeSpec(
          points: <Offset>[const Offset(double.infinity, 0)],
          thickness: 1,
          color: const Color(0xFF000000),
        ),
        field: 'spec.points[0].dx',
        message: 'Must be finite.',
      ),
      (
        spec: RectNodeSpec(size: const Size(1, 1), strokeWidth: -1),
        field: 'spec.strokeWidth',
        message: 'Must be >= 0.',
      ),
      (
        spec: PathNodeSpec(svgPathData: 'not-a-path'),
        field: 'spec.svgPathData',
        message: 'Must be valid SVG path data.',
      ),
    ];

    for (final invalid in invalidCases) {
      expect(
        () => txnNodeFromSpec(invalid.spec, fallbackId: 'auto-id'),
        throwsA(
          predicate(
            (e) =>
                e is ArgumentError &&
                e.name == invalid.field &&
                e.message == invalid.message,
          ),
        ),
      );
    }
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
    final strokeRevisionBeforePatch = stroke.pointsRevision;
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
    expect(stroke.pointsRevision, greaterThan(strokeRevisionBeforePatch));

    final strokeRevisionAfterGeometryPatch = stroke.pointsRevision;
    expect(
      txnApplyNodePatch(
        stroke,
        const StrokeNodePatch(
          id: 'str',
          color: PatchField<Color>.value(Color(0xFF222222)),
        ),
      ),
      isTrue,
    );
    expect(stroke.pointsRevision, strokeRevisionAfterGeometryPatch);

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

  test(
    'node patch validates only present fields and rejects invalid write values',
    () {
      final rect = RectNode(id: 'r1', size: const Size(1, 1));

      expect(txnApplyNodePatch(rect, const RectNodePatch(id: 'r1')), isFalse);

      final invalidCases = <({NodePatch patch, String field, String message})>[
        (
          patch: const RectNodePatch(
            id: 'r1',
            common: CommonNodePatch(opacity: PatchField<double>.value(1.1)),
          ),
          field: 'patch.common.opacity',
          message: 'Must be within [0,1].',
        ),
        (
          patch: const RectNodePatch(
            id: 'r1',
            common: CommonNodePatch(
              transform: PatchField<Transform2D>.value(
                Transform2D(a: 1, b: 0, c: 0, d: 1, tx: double.nan, ty: 0),
              ),
            ),
          ),
          field: 'patch.common.transform.tx',
          message: 'Must be finite.',
        ),
        (
          patch: const RectNodePatch(
            id: 'r1',
            size: PatchField<Size>.nullValue(),
          ),
          field: 'patch.size',
          message: 'PatchField.nullValue() is invalid for non-nullable field.',
        ),
      ];

      for (final invalid in invalidCases) {
        expect(
          () => txnApplyNodePatch(rect, invalid.patch),
          throwsA(
            predicate(
              (e) =>
                  e is ArgumentError &&
                  e.name == invalid.field &&
                  e.message == invalid.message,
            ),
          ),
        );
      }
    },
  );
}
