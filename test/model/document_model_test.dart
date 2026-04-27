import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/contract/internal/snapshot_fast_path.dart';
import 'package:iwb_canvas_engine/src/contract/internal/unsafe_snapshot_materialization.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/core/scene_limits.dart'
    show kMaxContentLayersPerScene, kMaxImageIdLength, kMaxNodesPerScene;
import 'package:iwb_canvas_engine/src/model/document.dart';

// INV:INV-ENG-TEXT-SIZE-DERIVED
// INV:INV-ENG-RUNTIME-NODE-VALUE-OWNERS

void main() {
  SceneSnapshot duplicateNodeSnapshotFromInternalBypass() {
    return unsafeMaterializeSceneSnapshot(
      sceneSnapshotBackingFromValidated(
        layers: <ContentLayerSnapshotBacking>[
          contentLayerSnapshotBackingFromValidated(
            id: 'layer-auto-5',
            nodes: <NodeSnapshotBacking>[
              nodeSnapshotBackingOf(
                RectNodeSnapshot(id: 'dup', size: const Size(1, 1)),
              ),
            ],
          ),
          contentLayerSnapshotBackingFromValidated(
            id: 'layer-auto-6',
            nodes: <NodeSnapshotBacking>[
              nodeSnapshotBackingOf(
                RectNodeSnapshot(id: 'dup', size: const Size(2, 2)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // INV:INV-ENG-PALETTE-RUNTIME-VALUE-OWNER
  Scene sceneWithAllNodeTypes() {
    return Scene(
      layers: <ContentLayer>[
        ContentLayer(id: 'layer-auto-9', nodes: <SceneNode>[]),
        ContentLayer(
          id: 'layer-auto-10',
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
    stroke.replacePoints(const <Offset>[Offset(-1, -1), Offset(3, 4)]);
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
      (snapshot.layers[1].nodes[2] as StrokeNodeSnapshot).points,
      const <Offset>[Offset(-1, -1), Offset(3, 4)],
    );
    expect((nodes[2] as StrokeNode).pointsRevision, 0);
  });

  test('txnNodeToSnapshot delegates node conversion through shared owner', () {
    final node = RectNode(
      id: 'rect-direct',
      size: const Size(12, 9),
      fillColor: const Color(0xFFEEEEEE),
      strokeColor: const Color(0xFF222222),
      strokeWidth: 1.5,
      opacity: 0.5,
      hitPadding: 0.3,
    );

    final snapshot = txnNodeToSnapshot(node);

    expect(snapshot, isA<RectNodeSnapshot>());
    final rectSnapshot = snapshot as RectNodeSnapshot;
    expect(rectSnapshot.id, 'rect-direct');
    expect(rectSnapshot.size, const Size(12, 9));
    expect(rectSnapshot.fillColor, const Color(0xFFEEEEEE));
    expect(rectSnapshot.strokeColor, const Color(0xFF222222));
    expect(rectSnapshot.strokeWidth, 1.5);
    expect(rectSnapshot.opacity, 0.5);
    expect(rectSnapshot.hitPadding, 0.3);
  });

  test(
    'txnSceneFromSnapshot materializes runtime stroke revision from defaults',
    () {
      final scene = txnSceneFromSnapshot(
        sceneSnapshotFromValidated(
          layers: <ContentLayerSnapshot>[
            contentLayerSnapshotFromValidated(
              id: 'layer-auto-0',
              nodes: <NodeSnapshot>[
                strokeNodeSnapshotFromValidated(
                  common: nodeSnapshotCommonFieldsFromValidated(id: 's'),
                  fields: (
                    points: const <Offset>[Offset(0, 0), Offset(1, 1)],
                    thickness: 1,
                    color: const Color(0xFF000000),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      final stroke = scene.layers.single.nodes.single as StrokeNode;
      expect(stroke.points, const <Offset>[Offset(0, 0), Offset(1, 1)]);
      expect(stroke.pointsRevision, 0);
    },
  );

  test(
    'txnSceneFromSnapshot rejects enabled grid cellSize below the import minimum',
    () {
      expect(
        () => txnSceneFromSnapshot(
          unsafeMaterializeSceneSnapshot(
            SceneSnapshotBacking(
              background: const BackgroundSnapshotBacking(
                grid: GridSnapshotBacking(isEnabled: true, cellSize: 0.5),
              ),
            ),
          ),
        ),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.code == SceneDataErrorCode.invalidValue &&
                e.path == 'background.grid.cellSize' &&
                e.message ==
                    'Field background.grid.cellSize must be >= 1.0 when background.grid.enabled is true.',
          ),
        ),
      );
    },
  );

  test('txnSceneFromSnapshot preserves dedicated background layer', () {
    final scene = txnSceneFromSnapshot(
      SceneSnapshot(
        backgroundLayer: BackgroundLayerSnapshot(
          nodes: <NodeSnapshot>[RectNodeSnapshot(id: 'bg', size: Size(1, 1))],
        ),
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-auto-1',
            nodes: <NodeSnapshot>[RectNodeSnapshot(id: 'n1', size: Size(1, 1))],
          ),
          ContentLayerSnapshot(
            id: 'layer-auto-2',
            nodes: <NodeSnapshot>[RectNodeSnapshot(id: 'n2', size: Size(1, 1))],
          ),
        ],
      ),
    );

    expect(scene.backgroundLayer, isNotNull);
    final backgroundLayer = scene.backgroundLayer;
    if (backgroundLayer == null) {
      fail('Expected canonical background layer.');
    }
    expect(backgroundLayer.nodes.single.id, 'bg');
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
            id: 'layer-auto-3',
            nodes: <NodeSnapshot>[RectNodeSnapshot(id: 'n1', size: Size(1, 1))],
          ),
        ],
      ),
    );

    expect(scene.layers.length, 1);
    expect(scene.backgroundLayer, isNotNull);
    final backgroundLayer = scene.backgroundLayer;
    if (backgroundLayer == null) {
      fail('Expected canonical background layer.');
    }
    expect(backgroundLayer.nodes, isEmpty);
  });

  test(
    'runtime ScenePalette freezes constructor lists and supports replacement',
    () {
      final sourcePenColors = <Color>[const Color(0xFF111111)];
      final sourceBackgroundColors = <Color>[const Color(0xFFEEEEEE)];
      final sourceGridSizes = <double>[8, 16];
      final palette = ScenePalette(
        penColors: sourcePenColors,
        backgroundColors: sourceBackgroundColors,
        gridSizes: sourceGridSizes,
      );
      final scene = Scene(palette: palette);

      sourcePenColors.add(const Color(0xFF222222));
      sourceBackgroundColors.add(const Color(0xFFDDDDDD));
      sourceGridSizes.add(24);

      expect(scene.palette.penColors, <Color>[const Color(0xFF111111)]);
      expect(scene.palette.backgroundColors, <Color>[const Color(0xFFEEEEEE)]);
      expect(scene.palette.gridSizes, <double>[8, 16]);
      expect(
        () => scene.palette.penColors.add(const Color(0xFF333333)),
        throwsUnsupportedError,
      );
      expect(
        () => scene.palette.backgroundColors.add(const Color(0xFFCCCCCC)),
        throwsUnsupportedError,
      );
      expect(() => scene.palette.gridSizes.add(32), throwsUnsupportedError);

      scene.palette = ScenePalette(
        penColors: <Color>[const Color(0xFFABCDEF)],
        backgroundColors: <Color>[const Color(0xFFFEDCBA)],
        gridSizes: <double>[32],
      );

      expect(scene.palette.penColors, <Color>[const Color(0xFFABCDEF)]);
      expect(scene.palette.backgroundColors, <Color>[const Color(0xFFFEDCBA)]);
      expect(scene.palette.gridSizes, <double>[32]);
    },
  );

  test('txnSceneToSnapshot canonicalizes null runtime background layer', () {
    // INV:INV-SER-TYPED-LAYER-SPLIT
    // INV:INV-SER-CANONICAL-BACKGROUND-LAYER
    final snapshot = txnSceneToSnapshot(
      Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-3a',
            nodes: <SceneNode>[RectNode(id: 'n1', size: const Size(1, 1))],
          ),
        ],
      ),
    );

    expect(snapshot.backgroundLayer.nodes, isEmpty);
    expect(snapshot.layers.single.nodes.single.id, 'n1');
  });

  test(
    'snapshot import/export round-trip keeps canonical single background layer',
    () {
      // INV:INV-SER-CANONICAL-BACKGROUND-LAYER
      final imported = txnSceneFromSnapshot(
        SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-4',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(id: 'n1', size: Size(1, 1)),
              ],
            ),
          ],
        ),
      );

      final exported = txnSceneToSnapshot(imported);
      final reimported = txnSceneFromSnapshot(exported);

      expect(exported.backgroundLayer.nodes, isEmpty);
      expect(reimported.backgroundLayer, isNotNull);
      final reimportedBackgroundLayer = reimported.backgroundLayer;
      if (reimportedBackgroundLayer == null) {
        fail('Expected canonical background layer after reimport.');
      }
      expect(reimportedBackgroundLayer.nodes, isEmpty);
      expect(reimported.layers.length, 1);
      expect(reimported.layers[0].nodes.single.id, 'n1');
    },
  );

  test('txnSceneToSnapshot rejects duplicate node ids with field path', () {
    expect(
      () => txnSceneToSnapshot(
        Scene(
          backgroundLayer: BackgroundLayer(
            nodes: <SceneNode>[RectNode(id: 'dup', size: const Size(1, 1))],
          ),
          layers: <ContentLayer>[
            ContentLayer(
              id: 'layer-auto-runtime-dup',
              nodes: <SceneNode>[RectNode(id: 'dup', size: const Size(2, 2))],
            ),
          ],
        ),
      ),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.duplicateNodeId &&
              e.path == 'layers[0].nodes[0].id' &&
              e.message == 'Must be unique across scene layers.',
        ),
      ),
    );
  });

  test('txnSceneToSnapshot rejects duplicate layer ids with field path', () {
    expect(
      () => txnSceneToSnapshot(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(id: 'layer-auto-dup'),
            ContentLayer(id: 'layer-auto-dup'),
          ],
        ),
      ),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.duplicateLayerId &&
              e.path == 'layers[1].id' &&
              e.details['template'] == 'duplicateLayerId',
        ),
      ),
    );
  });

  test('txnSceneToSnapshot rejects content-layer overflow with field path', () {
    expect(
      () => txnSceneToSnapshot(
        Scene(
          layers: <ContentLayer>[
            for (var i = 0; i < kMaxContentLayersPerScene + 1; i++)
              ContentLayer(id: 'layer-runtime-$i'),
          ],
        ),
      ),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'layers' &&
              e.details['template'] == 'maxItems',
        ),
      ),
    );
  });

  test('txnSceneToSnapshot rejects node overflow with field path', () {
    expect(
      () => txnSceneToSnapshot(
        Scene(
          backgroundLayer: BackgroundLayer(
            nodes: <SceneNode>[
              for (var i = 0; i < kMaxNodesPerScene + 1; i++)
                RectNode(id: 'node-runtime-$i', size: const Size(1, 1)),
            ],
          ),
        ),
      ),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'backgroundLayer.nodes' &&
              e.details['template'] == 'maxNodes',
        ),
      ),
    );
  });

  test('txnSceneFromSnapshot rejects duplicate node ids with field path', () {
    expect(
      () => txnSceneFromSnapshot(duplicateNodeSnapshotFromInternalBypass()),
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
        sceneSnapshotFromValidated(
          layers: <ContentLayerSnapshot>[
            contentLayerSnapshotFromValidated(
              id: 'layer-auto-7',
              nodes: <NodeSnapshot>[
                rectNodeSnapshotFromValidated(
                  common: nodeSnapshotCommonFieldsFromValidated(
                    id: 'r1',
                    transform: const Transform2D(
                      a: double.nan,
                      b: 0,
                      c: 0,
                      d: 1,
                      tx: 0,
                      ty: 0,
                    ),
                  ),
                  fields: (
                    size: const Size(1, 1),
                    fillColor: null,
                    strokeColor: null,
                    strokeWidth: 0,
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

  test('txnSceneFromSnapshot rejects out-of-range transform values', () {
    expect(
      () => txnSceneFromSnapshot(
        SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-out-of-range',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(
                  id: 'rect-out-of-range',
                  size: const Size(1, 1),
                  transform: const Transform2D(
                    a: 1,
                    b: 0,
                    c: 0,
                    d: 1,
                    tx: 10000001,
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
              e.code == SceneDataErrorCode.outOfRange &&
              e.path == 'layers[0].nodes[0].transform.tx',
        ),
      ),
    );
  });

  test('find/locator/insert/erase node utilities work across layers', () {
    final scene = sceneWithAllNodeTypes();
    final locator = txnBuildNodeLocator(scene);

    final found = txnFindNodeById(scene, 'txt');
    expect(found, isNotNull);
    if (found == null) {
      fail('Expected locator result for txt.');
    }
    expect(found.layerIndex, 1);
    expect(found.nodeIndex, 1);
    expect(txnFindNodeById(scene, 'missing'), isNull);
    final foundByLocator = txnFindNodeByLocator(
      scene: scene,
      nodeLocator: locator,
      nodeId: 'txt',
    );
    expect(foundByLocator, isNotNull);
    if (foundByLocator == null) {
      fail('Expected node locator entry for txt.');
    }
    expect(foundByLocator.layerIndex, 1);
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
    txnInsertNodeInScene(
      scene: scene,
      nodeLocator: locator,
      node: inserted,
      layerIndex: 1,
    );
    final insertedFound = txnFindNodeByLocator(
      scene: scene,
      nodeLocator: locator,
      nodeId: 'new',
    );
    expect(insertedFound, isNotNull);
    if (insertedFound == null) {
      fail('Expected inserted node locator entry.');
    }
    expect(insertedFound.layerIndex, 1);
    expect(insertedFound.nodeIndex, scene.layers[1].nodes.length - 1);

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

  test(
    'txnInsertContentLayerInScene keeps stable locator entries and updates layerIndexById',
    () {
      final scene = Scene(
        backgroundLayer: BackgroundLayer(
          nodes: <SceneNode>[RectNode(id: 'bg', size: const Size(1, 1))],
        ),
        layers: <ContentLayer>[
          ContentLayer(id: 'layer-a'),
          ContentLayer(
            id: 'layer-b',
            nodes: <SceneNode>[RectNode(id: 'tail', size: const Size(1, 1))],
          ),
          ContentLayer(
            id: 'layer-c',
            nodes: <SceneNode>[RectNode(id: 'tail-2', size: const Size(1, 1))],
          ),
        ],
      );
      final locator = txnBuildNodeLocator(scene);
      final layerIndexById = txnBuildLayerIndexById(scene);

      txnInsertContentLayerInScene(
        scene: scene,
        layerId: 'layer-inserted',
        layerIndexById: layerIndexById,
        insertIndex: 1,
      );

      expect(locator['bg'], (contentLayerId: null, nodeIndex: 0));
      expect(locator['tail'], (contentLayerId: 'layer-b', nodeIndex: 0));
      expect(locator['tail-2'], (contentLayerId: 'layer-c', nodeIndex: 0));
      expect(layerIndexById, <LayerId, int>{
        'layer-a': 0,
        'layer-inserted': 1,
        'layer-b': 2,
        'layer-c': 3,
      });
      expect(
        txnFindNodeByLocator(
          scene: scene,
          nodeLocator: locator,
          layerIndexById: layerIndexById,
          nodeId: 'tail',
        )?.layerIndex,
        2,
      );
    },
  );

  test('txnInsertContentLayerInScene rejects duplicate content layer ids', () {
    final scene = Scene(
      layers: <ContentLayer>[
        ContentLayer(id: 'layer-a'),
        ContentLayer(id: 'layer-b'),
      ],
    );

    expect(
      () => txnInsertContentLayerInScene(
        scene: scene,
        layerId: 'layer-b',
        layerIndexById: txnBuildLayerIndexById(scene),
      ),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.duplicateLayerId &&
              e.path == 'layers[2].id',
        ),
      ),
    );
  });

  test('txnInsertNodeInScene rejects duplicate node ids', () {
    final scene = Scene(
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-auto-11',
          nodes: <SceneNode>[RectNode(id: 'dup', size: const Size(1, 1))],
        ),
      ],
    );
    final locator = txnBuildNodeLocator(scene);

    expect(
      () => txnInsertNodeInScene(
        scene: scene,
        nodeLocator: locator,
        node: RectNode(id: 'dup', size: const Size(2, 2)),
        layerIndex: 0,
      ),
      throwsStateError,
    );
  });

  test('txnInsertNodeInScene rejects out-of-range layer index', () {
    final scene = Scene(
      layers: <ContentLayer>[ContentLayer(id: 'layer-auto-11a')],
    );
    final locator = txnBuildNodeLocator(scene);

    expect(
      () => txnInsertNodeInScene(
        scene: scene,
        nodeLocator: locator,
        node: RectNode(id: 'new', size: const Size(2, 2)),
        layerIndex: 2,
      ),
      throwsRangeError,
    );
  });

  test('txnInsertNodeInScene inserts by index and reindexes shifted nodes', () {
    final scene = Scene(
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-auto-11b',
          nodes: <SceneNode>[
            RectNode(id: 'a', size: const Size(1, 1)),
            RectNode(id: 'b', size: const Size(1, 1)),
          ],
        ),
      ],
    );
    final locator = txnBuildNodeLocator(scene);

    txnInsertNodeInScene(
      scene: scene,
      nodeLocator: locator,
      node: RectNode(id: 'mid', size: const Size(2, 2)),
      layerIndex: 0,
      insertIndex: 1,
    );

    expect(
      scene.layers.single.nodes.map((node) => node.id).toList(growable: false),
      <String>['a', 'mid', 'b'],
    );
    expect(locator['mid'], (contentLayerId: 'layer-auto-11b', nodeIndex: 1));
    expect(locator['b'], (contentLayerId: 'layer-auto-11b', nodeIndex: 2));

    expect(
      () => txnInsertNodeInScene(
        scene: scene,
        nodeLocator: locator,
        node: RectNode(id: 'bad', size: const Size(1, 1)),
        layerIndex: 0,
        insertIndex: 4,
      ),
      throwsRangeError,
    );
  });

  test('txnInsertNodeInScene rejects node overflow before layer mutation', () {
    final scene = Scene(
      layers: <ContentLayer>[ContentLayer(id: 'layer-auto-overflow')],
      backgroundLayer: BackgroundLayer(
        nodes: <SceneNode>[
          for (var i = 0; i < kMaxNodesPerScene; i++)
            RectNode(id: 'node-$i', size: const Size(1, 1)),
        ],
      ),
    );
    final locator = txnBuildNodeLocator(scene);
    final backgroundLayer = scene.backgroundLayer;
    if (backgroundLayer == null) {
      fail('Expected populated background layer for node-budget test.');
    }
    final beforeNodeIds = backgroundLayer.nodes
        .map((node) => node.id)
        .toList(growable: false);

    expect(
      () => txnInsertNodeInScene(
        scene: scene,
        nodeLocator: locator,
        node: RectNode(id: 'overflow', size: const Size(2, 2)),
        layerIndex: 0,
      ),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'layers[0].nodes' &&
              e.details['template'] == 'maxNodes',
        ),
      ),
    );
    expect(scene.layers.single.nodes, isEmpty);
    expect(
      backgroundLayer.nodes.map((node) => node.id).toList(growable: false),
      beforeNodeIds,
    );
    expect(locator.containsKey('overflow'), isFalse);
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
          id: 'layer-auto-12',
          nodes: <SceneNode>[RectNode(id: 'fg-a', size: const Size(1, 1))],
        ),
      ],
    );
    final locator = txnBuildNodeLocator(scene);

    final bgFound = txnFindNodeById(scene, 'bg-a');
    expect(bgFound, isNotNull);
    if (bgFound == null) {
      fail('Expected background node lookup result.');
    }
    expect(bgFound.layerIndex, -1);
    expect(bgFound.nodeIndex, 0);

    final bgByLocator = txnFindNodeByLocator(
      scene: scene,
      nodeLocator: locator,
      nodeId: 'bg-b',
    );
    expect(bgByLocator, isNotNull);
    if (bgByLocator == null) {
      fail('Expected background locator result.');
    }
    expect(bgByLocator.layerIndex, -1);
    expect(bgByLocator.nodeIndex, 1);

    final wrongIndexLocator = <NodeId, NodeLocatorEntry>{
      ...locator,
      'bg-b': (contentLayerId: null, nodeIndex: 99),
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
      'bg-a': (contentLayerId: null, nodeIndex: 1),
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
    expect(locator['bg-b'], (contentLayerId: null, nodeIndex: 0));

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
          id: 'layer-auto-13',
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
    expect(locator['a'], (contentLayerId: 'layer-auto-13', nodeIndex: 0));
    expect(locator['c'], (contentLayerId: 'layer-auto-13', nodeIndex: 1));
  });

  test(
    'txnEraseNodesFromScene removes deletable content nodes in deterministic scene order',
    () {
      final scene = Scene(
        backgroundLayer: BackgroundLayer(
          nodes: <SceneNode>[RectNode(id: 'bg', size: const Size(1, 1))],
        ),
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-13a',
            nodes: <SceneNode>[
              RectNode(id: 'a', size: const Size(1, 1)),
              RectNode(
                id: 'locked',
                size: const Size(1, 1),
                isDeletable: false,
              ),
            ],
          ),
          ContentLayer(
            id: 'layer-auto-13b',
            nodes: <SceneNode>[
              RectNode(id: 'b', size: const Size(1, 1)),
              RectNode(id: 'c', size: const Size(1, 1)),
            ],
          ),
        ],
      );
      final locator = txnBuildNodeLocator(scene);

      final removed = txnEraseNodesFromScene(
        scene: scene,
        nodeLocator: locator,
        nodeIds: const <NodeId>{'c', 'bg', 'a', 'missing', 'locked'},
      );

      expect(removed, const <NodeId>['a', 'c']);
      expect(() => removed.add('late'), throwsUnsupportedError);
      expect(
        scene.layers[0].nodes.map((node) => node.id).toList(growable: false),
        const <NodeId>['locked'],
      );
      expect(
        scene.layers[1].nodes.map((node) => node.id).toList(growable: false),
        const <NodeId>['b'],
      );
      expect(locator['bg'], (contentLayerId: null, nodeIndex: 0));
      expect(locator['locked'], (
        contentLayerId: 'layer-auto-13a',
        nodeIndex: 0,
      ));
      expect(locator['b'], (contentLayerId: 'layer-auto-13b', nodeIndex: 0));
    },
  );

  test(
    'txnErasePreparedNodesFromScene removes prepared targets without scene rescan',
    () {
      final scene = Scene(
        backgroundLayer: BackgroundLayer(
          nodes: <SceneNode>[
            RectNode(id: 'bg-a', size: const Size(1, 1)),
            RectNode(id: 'bg-b', size: const Size(1, 1)),
          ],
        ),
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-13aa',
            nodes: <SceneNode>[
              RectNode(id: 'a', size: const Size(1, 1)),
              RectNode(id: 'b', size: const Size(1, 1)),
            ],
          ),
          ContentLayer(
            id: 'layer-auto-13ab',
            nodes: <SceneNode>[
              RectNode(id: 'c', size: const Size(1, 1)),
              RectNode(id: 'd', size: const Size(1, 1)),
            ],
          ),
        ],
      );
      final locator = txnBuildNodeLocator(scene);

      final removed = txnErasePreparedNodesFromScene(
        scene: scene,
        nodeLocator: locator,
        removalsByLayer: <int, List<PreparedNodeRemoval>>{
          1: <PreparedNodeRemoval>[(nodeId: 'd', nodeIndex: 1)],
          -1: <PreparedNodeRemoval>[(nodeId: 'bg-a', nodeIndex: 0)],
          0: <PreparedNodeRemoval>[(nodeId: 'b', nodeIndex: 1)],
        },
      );

      expect(removed, const <NodeId>['bg-a', 'b', 'd']);
      expect(() => removed.add('late'), throwsUnsupportedError);
      expect(
        scene.backgroundLayer?.nodes
            .map((node) => node.id)
            .toList(growable: false),
        const <NodeId>['bg-b'],
      );
      expect(
        scene.layers[0].nodes.map((node) => node.id).toList(growable: false),
        const <NodeId>['a'],
      );
      expect(
        scene.layers[1].nodes.map((node) => node.id).toList(growable: false),
        const <NodeId>['c'],
      );
      expect(locator['bg-b'], (contentLayerId: null, nodeIndex: 0));
      expect(locator['a'], (contentLayerId: 'layer-auto-13aa', nodeIndex: 0));
      expect(locator['c'], (contentLayerId: 'layer-auto-13ab', nodeIndex: 0));
    },
  );

  test(
    'txnErasePreparedNodesFromScene asserts on duplicate prepared removals',
    () {
      final scene = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-13ac',
            nodes: <SceneNode>[
              RectNode(id: 'a', size: const Size(1, 1)),
              RectNode(id: 'b', size: const Size(1, 1)),
              RectNode(id: 'c', size: const Size(1, 1)),
            ],
          ),
        ],
      );
      final locator = txnBuildNodeLocator(scene);

      expect(
        () => txnErasePreparedNodesFromScene(
          scene: scene,
          nodeLocator: locator,
          removalsByLayer: <int, List<PreparedNodeRemoval>>{
            0: <PreparedNodeRemoval>[
              (nodeId: 'b', nodeIndex: 1),
              (nodeId: 'b', nodeIndex: 1),
            ],
          },
        ),
        throwsA(isA<AssertionError>()),
      );
    },
  );

  test(
    'txnClearSceneKeepBackground removes content layers and marks structural-only clear',
    () {
      final scene = Scene(
        layers: <ContentLayer>[
          ContentLayer(id: 'layer-auto-13c'),
          ContentLayer(
            id: 'layer-auto-13d',
            nodes: <SceneNode>[RectNode(id: 'a', size: const Size(1, 1))],
          ),
        ],
      );
      final locator = txnBuildNodeLocator(scene);
      final layerIndexById = txnBuildLayerIndexById(scene);

      final cleared = txnClearSceneKeepBackground(
        scene: scene,
        nodeLocator: locator,
        layerIndexById: layerIndexById,
      );

      expect(cleared.didStructuralClear, isTrue);
      expect(cleared.removedNodeIds, const <NodeId>['a']);
      expect(() => cleared.removedNodeIds.add('late'), throwsUnsupportedError);
      expect(scene.layers, isEmpty);
      expect(scene.backgroundLayer, isNotNull);
      expect(locator, isEmpty);
      expect(layerIndexById, isEmpty);

      final noop = txnClearSceneKeepBackground(
        scene: scene,
        nodeLocator: locator,
        layerIndexById: layerIndexById,
      );
      expect(noop.didStructuralClear, isFalse);
      expect(noop.removedNodeIds, isEmpty);
      expect(layerIndexById, isEmpty);
    },
  );

  test(
    'resolve layer index validates layerId and uses last layer by default',
    () {
      final scene = Scene(
        layers: <ContentLayer>[ContentLayer(id: 'layer-auto-14')],
      );

      expect(
        () =>
            txnResolveInsertLayerIndex(scene: scene, layerId: 'missing-layer'),
        throwsArgumentError,
      );

      final index = txnResolveInsertLayerIndex(scene: scene, layerId: null);
      expect(index, 0);
      expect(scene.layers.length, 1);
      expect(scene.layers.last, isA<ContentLayer>());
    },
  );

  test('resolve layer index creates one layer for empty scene by default', () {
    final emptyScene = Scene();
    final layerIndexById = <LayerId, int>{};

    final index = txnResolveInsertLayerIndex(
      scene: emptyScene,
      layerId: null,
      nextLayerId: () => 'layer-0',
      layerIndexById: layerIndexById,
    );
    expect(index, 0);
    expect(emptyScene.layers.length, 1);
    expect(emptyScene.layers.single.id, 'layer-0');
    expect(emptyScene.layers.last, isA<ContentLayer>());
    expect(layerIndexById, <LayerId, int>{'layer-0': 0});
  });

  test(
    'resolve layer index creates one layer for empty scene without companion index map',
    () {
      final emptyScene = Scene();

      final index = txnResolveInsertLayerIndex(
        scene: emptyScene,
        layerId: null,
        nextLayerId: () => 'layer-0',
      );

      expect(index, 0);
      expect(emptyScene.layers.length, 1);
      expect(emptyScene.layers.single.id, 'layer-0');
    },
  );

  test(
    'txnInsertContentLayerInScene rejects overflow before scene mutation',
    () {
      final scene = Scene(
        layers: <ContentLayer>[
          for (var i = 0; i < kMaxContentLayersPerScene; i++)
            ContentLayer(id: 'layer-$i'),
        ],
      );
      final beforeLayerIds = scene.layers
          .map((layer) => layer.id)
          .toList(growable: false);

      expect(
        () => txnInsertContentLayerInScene(
          scene: scene,
          layerId: 'layer-overflow',
        ),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.code == SceneDataErrorCode.invalidValue &&
                e.path == 'layers' &&
                e.details['template'] == 'maxItems',
          ),
        ),
      );
      expect(
        scene.layers.map((layer) => layer.id).toList(growable: false),
        beforeLayerIds,
      );
    },
  );

  test('find content layer index resolves known and missing layer ids', () {
    final scene = Scene(
      layers: <ContentLayer>[
        ContentLayer(id: 'layer-auto-20'),
        ContentLayer(id: 'layer-auto-21'),
      ],
    );

    expect(
      txnFindContentLayerIndexById(scene: scene, layerId: 'layer-auto-20'),
      0,
    );
    expect(
      txnFindContentLayerIndexById(scene: scene, layerId: 'layer-auto-21'),
      1,
    );
    expect(
      txnFindContentLayerIndexById(scene: scene, layerId: 'layer-auto-missing'),
      isNull,
    );
  });

  test(
    'txnReplaceContentLayerSlotInScene preserves topology while swapping the owning layer object',
    () {
      final firstNode = RectNode(id: 'slot-node-1', size: const Size(1, 1));
      final secondNode = RectNode(id: 'slot-node-2', size: const Size(2, 2));
      final original = ContentLayer(
        id: 'layer-auto-slot',
        nodes: <SceneNode>[firstNode, secondNode],
      );
      final scene = Scene(layers: <ContentLayer>[original]);
      final replacement = ContentLayer(
        id: original.id,
        nodes: <SceneNode>[firstNode, secondNode],
      );

      txnReplaceContentLayerSlotInScene(
        scene: scene,
        layerIndex: 0,
        layer: replacement,
      );

      expect(scene.layers.single, same(replacement));
      expect(scene.layers.single.id, original.id);
      expect(scene.layers.single.nodes, hasLength(original.nodes.length));
      expect(scene.layers.single.nodes[0], same(firstNode));
      expect(scene.layers.single.nodes[1], same(secondNode));
      expect(scene.layers.single.nodes, isNot(same(original.nodes)));
      expect(
        () => txnReplaceContentLayerSlotInScene(
          scene: scene,
          layerIndex: -1,
          layer: replacement,
        ),
        throwsRangeError,
      );
    },
  );

  test(
    'txnReplaceContentLayerSlotInScene rejects semantic topology changes',
    () {
      final firstNode = RectNode(id: 'slot-node-3', size: const Size(1, 1));
      final secondNode = RectNode(id: 'slot-node-4', size: const Size(2, 2));
      final scene = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-slot',
            nodes: <SceneNode>[firstNode, secondNode],
          ),
        ],
      );

      expect(
        () => txnReplaceContentLayerSlotInScene(
          scene: scene,
          layerIndex: 0,
          layer: ContentLayer(
            id: 'layer-auto-other',
            nodes: <SceneNode>[firstNode, secondNode],
          ),
        ),
        throwsStateError,
      );
      expect(
        () => txnReplaceContentLayerSlotInScene(
          scene: scene,
          layerIndex: 0,
          layer: ContentLayer(
            id: 'layer-auto-slot',
            nodes: <SceneNode>[firstNode],
          ),
        ),
        throwsStateError,
      );
      expect(
        () => txnReplaceContentLayerSlotInScene(
          scene: scene,
          layerIndex: 0,
          layer: ContentLayer(
            id: 'layer-auto-slot',
            nodes: <SceneNode>[
              RectNode(id: 'replacement', size: const Size(3, 3)),
              secondNode,
            ],
          ),
        ),
        throwsStateError,
      );
    },
  );

  test('selection/grid helpers enforce transaction invariants', () {
    final scene = Scene(
      backgroundLayer: BackgroundLayer(
        nodes: <SceneNode>[RectNode(id: 'bg', size: const Size(1, 1))],
      ),
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-auto-15',
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
      background: Background(grid: GridSettings(isEnabled: true, cellSize: 1)),
    );

    final normalized = txnNormalizeSelection(
      rawSelection: <NodeId>{'ok', 'hidden', 'nonsel', 'bg', 'missing'},
      scene: scene,
      nodeLocator: txnBuildNodeLocator(scene),
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

    final okEntry = txnFindNodeById(scene, 'ok');
    if (okEntry == null) {
      fail('Expected translated node lookup result.');
    }
    final ok = okEntry.node as RectNode;
    expect(ok.transform.tx, 10);

    final grid = scene.background.grid;
    expect(() => grid.cellSize = 0, throwsArgumentError);
    expect(() => grid.cellSize = double.nan, throwsArgumentError);
    grid.isEnabled = false;
    grid.cellSize = 0.5;
    expect(grid.cellSize, 0.5);
    expect(() => grid.isEnabled = true, throwsArgumentError);
    grid.cellSize = 2;
    grid.isEnabled = true;
    expect(grid.isEnabled, isTrue);
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
        textDirection: TextDirection.ltr,
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
      PathNodeSpec(svgPathData: 'M0 0 L1 1', fillRule: PathFillRule.evenOdd),
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
        RectNodeSnapshot(
          id: 'preserved',
          instanceRevision: 7,
          size: Size(1, 1),
        ),
        nextInstanceRevision: allocate,
      );
      final allocated = txnNodeFromSnapshot(
        RectNodeSnapshot(id: 'allocated', size: Size(1, 1)),
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
              id: 'layer-auto-8',
              nodes: <NodeSnapshot>[
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

      final nodeAEntry = txnFindNodeById(scene, 'a');
      final nodeBEntry = txnFindNodeById(scene, 'b');
      if (nodeAEntry == null || nodeBEntry == null) {
        fail('Expected both nodes to exist after revision normalization.');
      }
      final nodeA = nodeAEntry.node;
      final nodeB = nodeBEntry.node;
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
                textDirection: TextDirection.ltr,
              ),
              fallbackId: 'auto-text',
            )
            as TextNode;

    expect(node.localBounds.width, greaterThan(0));
    expect(node.localBounds.height, greaterThan(0));
  });

  test('text node from snapshot derives bounds from layout inputs', () {
    final node =
        txnNodeFromSnapshot(
              TextNodeSnapshot(
                id: 'text-stale',
                text: 'Derived size',
                fontSize: 24,
                color: Color(0xFF000000),
                textDirection: TextDirection.ltr,
              ),
            )
            as TextNode;

    expect(node.localBounds.width, greaterThan(1));
    expect(node.localBounds.height, greaterThan(1));
  });

  test('text node patch touching layout re-derives bounds', () {
    final text = TextNode(
      id: 'text-layout-patch',
      text: 'Derived size',
      fontSize: 24,
      color: const Color(0xFF000000),
    );
    final beforeHeight = text.localBounds.height;

    final changed = txnApplyNodePatch(
      text,
      TextNodePatch(
        id: 'text-layout-patch',
        fontSize: PatchField<double>.value(28),
      ),
    );

    expect(changed, isTrue);
    expect(text.localBounds.width, greaterThan(1));
    expect(text.localBounds.height, greaterThan(beforeHeight));
  });

  test(
    'textDirection patch updates text node and keeps derived bounds valid',
    () {
      final text = TextNode(
        id: 'text-direction-patch',
        text: 'abc אבג',
        fontSize: 24,
        color: const Color(0xFF000000),
        textDirection: TextDirection.ltr,
        align: TextAlign.start,
      );

      final changed = txnApplyNodePatch(
        text,
        TextNodePatch(
          id: 'text-direction-patch',
          textDirection: PatchField<TextDirection>.value(TextDirection.rtl),
        ),
      );

      expect(changed, isTrue);
      expect(text.textDirection, TextDirection.rtl);
      expect(text.localBounds.width, greaterThan(1));
      expect(text.localBounds.height, greaterThan(1));
    },
  );

  test('text node patch without layout fields keeps derived size', () {
    final text =
        txnNodeFromSpec(
              TextNodeSpec(
                text: 'Stable derived size',
                fontSize: 20,
                color: const Color(0xFF000000),
                textDirection: TextDirection.ltr,
              ),
              fallbackId: 'text-non-layout-patch',
            )
            as TextNode;
    final sizeBefore = text.localBounds.size;

    final changed = txnApplyNodePatch(
      text,
      TextNodePatch(
        id: 'text-non-layout-patch',
        color: PatchField<Color>.value(Color(0xFF123456)),
      ),
    );

    expect(changed, isTrue);
    expect(text.localBounds.size, sizeBefore);
  });

  test('node-from-spec rejects invalid numeric fields with field path', () {
    final invalidCases =
        <({NodeSpec Function() create, String field, String message})>[
          (
            create: () => RectNodeSpec(size: const Size(1, 1), opacity: 1.1),
            field: 'opacity',
            message: 'Must be within [0,1].',
          ),
          (
            create: () => RectNodeSpec(
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
            field: 'transform.a',
            message: 'Must be finite.',
          ),
          (
            create: () => TextNodeSpec(
              text: 't',
              fontSize: 0,
              color: const Color(0xFF000000),
              textDirection: TextDirection.ltr,
            ),
            field: 'fontSize',
            message: 'Must be > 0.',
          ),
          (
            create: () => StrokeNodeSpec(
              points: <Offset>[const Offset(double.infinity, 0)],
              thickness: 1,
              color: const Color(0xFF000000),
            ),
            field: 'points[0].dx',
            message: 'Must be finite.',
          ),
          (
            create: () => ImageNodeSpec(
              imageId: 'x' * (kMaxImageIdLength + 1),
              size: const Size(1, 1),
            ),
            field: 'imageId',
            message: 'Length must be <= $kMaxImageIdLength characters.',
          ),
          (
            create: () => RectNodeSpec(size: const Size(1, 1), strokeWidth: -1),
            field: 'strokeWidth',
            message: 'Must be >= 0.',
          ),
          (
            create: () => PathNodeSpec(svgPathData: 'not-a-path'),
            field: 'svgPathData',
            message: 'Must be valid SVG path data.',
          ),
        ];

    for (final invalid in invalidCases) {
      expect(
        invalid.create,
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
        ImageNodePatch(
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

    final text = TextNode(id: 'txt', text: 'x', color: const Color(0xFF000000));
    expect(
      txnApplyNodePatch(
        text,
        TextNodePatch(
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
    final sourcePatchPoints = <Offset>[const Offset(2, 2), const Offset(3, 3)];
    final strokeRevisionBeforePatch = stroke.pointsRevision;
    expect(
      txnApplyNodePatch(
        stroke,
        StrokeNodePatch(
          id: 'str',
          points: PatchField<List<Offset>>.value(sourcePatchPoints),
          thickness: PatchField<double>.value(4),
          color: PatchField<Color>.value(Color(0xFF333333)),
        ),
      ),
      isTrue,
    );
    sourcePatchPoints[1] = const Offset(30, 30);
    expect(stroke.points, <Offset>[const Offset(2, 2), const Offset(3, 3)]);
    expect(stroke.pointsRevision, strokeRevisionBeforePatch + 1);

    final strokeRevisionAfterGeometryPatch = stroke.pointsRevision;
    expect(
      txnApplyNodePatch(
        stroke,
        StrokeNodePatch(
          id: 'str',
          color: PatchField<Color>.value(Color(0xFF222222)),
        ),
      ),
      isTrue,
    );
    expect(stroke.pointsRevision, strokeRevisionAfterGeometryPatch);

    final strokePointsBeforeNoop = stroke.points;
    expect(
      txnApplyNodePatch(
        stroke,
        StrokeNodePatch(
          id: 'str',
          points: PatchField<List<Offset>>.value(<Offset>[
            const Offset(2, 2),
            const Offset(3, 3),
          ]),
        ),
      ),
      isFalse,
    );
    expect(stroke.pointsRevision, strokeRevisionAfterGeometryPatch);
    expect(identical(stroke.points, strokePointsBeforeNoop), isTrue);

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
        LineNodePatch(
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
        RectNodePatch(
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
        PathNodePatch(
          id: 'pth',
          svgPathData: PatchField<String>.value('M0 0 L5 5'),
          fillColor: PatchField<Color?>.value(Color(0xFF111111)),
          strokeColor: PatchField<Color?>.nullValue(),
          strokeWidth: PatchField<double>.value(4),
          fillRule: PatchField<PathFillRule>.value(PathFillRule.evenOdd),
        ),
      ),
      isTrue,
    );
    expect(path.svgPathData, 'M0 0 L5 5');
    expect(path.strokeColor, isNull);
    expect(path.fillRule, PathFillRule.evenOdd);
  });

  test('runtime node owners reject invalid constrained write values', () {
    final image = ImageNode(
      id: 'img-owner',
      imageId: 'image://1',
      size: const Size(10, 10),
    );
    expect(
      () => image.imageId = 'x' * (kMaxImageIdLength + 1),
      throwsA(predicate((e) => e is ArgumentError && e.name == 'imageId')),
    );
    expect(
      () => image.naturalSize = const Size(10, double.infinity),
      throwsA(
        predicate((e) => e is ArgumentError && e.name == 'naturalSize.height'),
      ),
    );

    final text = TextNode(
      id: 'txt-owner',
      text: 'hello',
      color: const Color(0xFF000000),
    );
    expect(
      () => text.fontSize = 0,
      throwsA(predicate((e) => e is ArgumentError && e.name == 'fontSize')),
    );
    expect(
      () => text.maxWidth = 0,
      throwsA(predicate((e) => e is ArgumentError && e.name == 'maxWidth')),
    );

    final line = LineNode(
      id: 'line-owner',
      start: const Offset(0, 0),
      end: const Offset(1, 1),
      thickness: 1,
      color: const Color(0xFF000000),
    );
    expect(
      () => line.start = const Offset(double.infinity, 0),
      throwsA(predicate((e) => e is ArgumentError && e.name == 'start.dx')),
    );

    final path = PathNode(id: 'path-owner', svgPathData: 'M0 0 L1 1');
    expect(
      () => path.svgPathData = 'not-a-path',
      throwsA(predicate((e) => e is ArgumentError && e.name == 'svgPathData')),
    );
  });

  test('node patch validates id, patch type and nullability constraints', () {
    final rectNoop = RectNode(id: 'x', size: const Size(1, 1));
    expect(txnApplyNodePatch(rectNoop, RectNodePatch(id: 'x')), isFalse);

    final rect = RectNode(id: 'r1', size: const Size(1, 1));
    expect(
      () => txnApplyNodePatch(rect, RectNodePatch(id: 'other')),
      throwsArgumentError,
    );
    expect(
      () => txnApplyNodePatch(
        rect,
        RectNodePatch(id: 'r1', size: PatchField<Size>.nullValue()),
      ),
      throwsArgumentError,
    );
    expect(
      () => txnApplyNodePatch(rect, PathNodePatch(id: 'r1')),
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
        StrokeNodePatch(id: 's1', points: PatchField<List<Offset>>.nullValue()),
      ),
      throwsArgumentError,
    );
  });

  test(
    'nullable patch value(null) applies as the canonical explicit-null write',
    () {
      final rect = RectNode(
        id: 'rect-null-canonical',
        size: const Size(1, 1),
        fillColor: const Color(0xFF123456),
      );

      expect(
        txnApplyNodePatch(
          rect,
          RectNodePatch(
            id: 'rect-null-canonical',
            fillColor: PatchField<Color?>.value(null),
          ),
        ),
        isTrue,
      );
      expect(rect.fillColor, isNull);
    },
  );

  test('node patch rejects explicit null for non-nullable public fields', () {
    final invalidCases =
        <({Object Function() create, String field, String message})>[
          (
            create: () =>
                CommonNodePatch(isVisible: PatchField<bool>.nullValue()),
            field: 'isVisible',
            message:
                'PatchField.nullValue() is invalid for non-nullable field.',
          ),
          (
            create: () =>
                CommonNodePatch(isSelectable: PatchField<bool>.nullValue()),
            field: 'isSelectable',
            message:
                'PatchField.nullValue() is invalid for non-nullable field.',
          ),
          (
            create: () =>
                CommonNodePatch(isLocked: PatchField<bool>.nullValue()),
            field: 'isLocked',
            message:
                'PatchField.nullValue() is invalid for non-nullable field.',
          ),
          (
            create: () =>
                CommonNodePatch(isDeletable: PatchField<bool>.nullValue()),
            field: 'isDeletable',
            message:
                'PatchField.nullValue() is invalid for non-nullable field.',
          ),
          (
            create: () =>
                CommonNodePatch(isTransformable: PatchField<bool>.nullValue()),
            field: 'isTransformable',
            message:
                'PatchField.nullValue() is invalid for non-nullable field.',
          ),
          (
            create: () => TextNodePatch(
              id: 'text-null',
              color: PatchField<Color>.nullValue(),
            ),
            field: 'color',
            message:
                'PatchField.nullValue() is invalid for non-nullable field.',
          ),
          (
            create: () => TextNodePatch(
              id: 'text-null',
              align: PatchField<TextAlign>.nullValue(),
            ),
            field: 'align',
            message:
                'PatchField.nullValue() is invalid for non-nullable field.',
          ),
          (
            create: () => TextNodePatch(
              id: 'text-null',
              textDirection: PatchField<TextDirection>.nullValue(),
            ),
            field: 'textDirection',
            message:
                'PatchField.nullValue() is invalid for non-nullable field.',
          ),
          (
            create: () => TextNodePatch(
              id: 'text-null',
              isBold: PatchField<bool>.nullValue(),
            ),
            field: 'isBold',
            message:
                'PatchField.nullValue() is invalid for non-nullable field.',
          ),
          (
            create: () => TextNodePatch(
              id: 'text-null',
              isItalic: PatchField<bool>.nullValue(),
            ),
            field: 'isItalic',
            message:
                'PatchField.nullValue() is invalid for non-nullable field.',
          ),
          (
            create: () => TextNodePatch(
              id: 'text-null',
              isUnderline: PatchField<bool>.nullValue(),
            ),
            field: 'isUnderline',
            message:
                'PatchField.nullValue() is invalid for non-nullable field.',
          ),
          (
            create: () => StrokeNodePatch(
              id: 'stroke-null',
              color: PatchField<Color>.nullValue(),
            ),
            field: 'color',
            message:
                'PatchField.nullValue() is invalid for non-nullable field.',
          ),
          (
            create: () => LineNodePatch(
              id: 'line-null',
              color: PatchField<Color>.nullValue(),
            ),
            field: 'color',
            message:
                'PatchField.nullValue() is invalid for non-nullable field.',
          ),
          (
            create: () => PathNodePatch(
              id: 'path-null',
              fillRule: PatchField<PathFillRule>.nullValue(),
            ),
            field: 'fillRule',
            message:
                'PatchField.nullValue() is invalid for non-nullable field.',
          ),
        ];

    for (final invalid in invalidCases) {
      expect(
        invalid.create,
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

    expect(CommonNodePatch.new, returnsNormally);
    expect(() => TextNodePatch(id: 'text-absent'), returnsNormally);
    expect(() => StrokeNodePatch(id: 'stroke-absent'), returnsNormally);
    expect(() => LineNodePatch(id: 'line-absent'), returnsNormally);
    expect(() => PathNodePatch(id: 'path-absent'), returnsNormally);

    expect(
      () => CommonNodePatch(
        isVisible: PatchField<bool>.value(true),
        isSelectable: PatchField<bool>.value(true),
        isLocked: PatchField<bool>.value(false),
        isDeletable: PatchField<bool>.value(true),
        isTransformable: PatchField<bool>.value(true),
      ),
      returnsNormally,
    );
    expect(
      () => TextNodePatch(
        id: 'text-value',
        color: PatchField<Color>.value(const Color(0xFF123456)),
        align: PatchField<TextAlign>.value(TextAlign.center),
        textDirection: PatchField<TextDirection>.value(TextDirection.ltr),
        isBold: PatchField<bool>.value(true),
        isItalic: PatchField<bool>.value(false),
        isUnderline: PatchField<bool>.value(true),
      ),
      returnsNormally,
    );
    expect(
      () => StrokeNodePatch(
        id: 'stroke-value',
        color: PatchField<Color>.value(const Color(0xFF654321)),
      ),
      returnsNormally,
    );
    expect(
      () => LineNodePatch(
        id: 'line-value',
        color: PatchField<Color>.value(const Color(0xFFABCDEF)),
      ),
      returnsNormally,
    );
    expect(
      () => PathNodePatch(
        id: 'path-value',
        fillRule: PatchField<PathFillRule>.value(PathFillRule.evenOdd),
      ),
      returnsNormally,
    );

    expect(
      () => ImageNodePatch(
        id: 'image-nullable-null',
        naturalSize: PatchField<Size?>.nullValue(),
      ),
      returnsNormally,
    );
    expect(
      () => TextNodePatch(
        id: 'text-nullable-null',
        fontFamily: PatchField<String?>.nullValue(),
        maxWidth: PatchField<double?>.nullValue(),
        lineHeight: PatchField<double?>.nullValue(),
      ),
      returnsNormally,
    );
    expect(
      () => RectNodePatch(
        id: 'rect-nullable-null',
        fillColor: PatchField<Color?>.nullValue(),
        strokeColor: PatchField<Color?>.nullValue(),
      ),
      returnsNormally,
    );
    expect(
      () => PathNodePatch(
        id: 'path-nullable-null',
        fillColor: PatchField<Color?>.nullValue(),
        strokeColor: PatchField<Color?>.nullValue(),
      ),
      returnsNormally,
    );
  });

  test(
    'node patch validates only present fields and rejects invalid write values',
    () {
      final rect = RectNode(id: 'r1', size: const Size(1, 1));

      expect(txnApplyNodePatch(rect, RectNodePatch(id: 'r1')), isFalse);

      final invalidCases =
          <({NodePatch Function() create, String field, String message})>[
            (
              create: () => RectNodePatch(
                id: 'r1',
                common: CommonNodePatch(opacity: PatchField<double>.value(1.1)),
              ),
              field: 'opacity',
              message: 'Must be within [0,1].',
            ),
            (
              create: () => RectNodePatch(
                id: 'r1',
                common: CommonNodePatch(
                  transform: PatchField<Transform2D>.value(
                    Transform2D(a: 1, b: 0, c: 0, d: 1, tx: double.nan, ty: 0),
                  ),
                ),
              ),
              field: 'transform.tx',
              message: 'Must be finite.',
            ),
            (
              create: () =>
                  RectNodePatch(id: 'r1', size: PatchField<Size>.nullValue()),
              field: 'size',
              message:
                  'PatchField.nullValue() is invalid for non-nullable field.',
            ),
            (
              create: () => RectNodePatch(
                id: 'r1',
                common: CommonNodePatch(
                  hitPadding: PatchField<double>.value(-1),
                ),
              ),
              field: 'hitPadding',
              message: 'Must be >= 0.',
            ),
            (
              create: () => RectNodePatch(
                id: 'r1',
                strokeWidth: PatchField<double>.value(-1),
              ),
              field: 'strokeWidth',
              message: 'Must be >= 0.',
            ),
          ];

      for (final invalid in invalidCases) {
        expect(
          invalid.create,
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

  test('node patch rejects invalid image and text boundary values', () {
    expect(
      () => ImageNodePatch(
        id: 'img-boundary',
        imageId: PatchField<String>.value('x' * (kMaxImageIdLength + 1)),
      ),
      throwsA(
        predicate(
          (e) =>
              e is ArgumentError &&
              e.name == 'imageId' &&
              e.message == 'Length must be <= $kMaxImageIdLength characters.',
        ),
      ),
    );

    final invalidCases =
        <({NodePatch Function() create, String field, String message})>[
          (
            create: () => TextNodePatch(
              id: 'text-boundary',
              fontSize: PatchField<double>.value(0),
            ),
            field: 'fontSize',
            message: 'Must be > 0.',
          ),
          (
            create: () => TextNodePatch(
              id: 'text-boundary',
              maxWidth: PatchField<double?>.value(0),
            ),
            field: 'maxWidth',
            message: 'Must be > 0.',
          ),
          (
            create: () => TextNodePatch(
              id: 'text-boundary',
              lineHeight: PatchField<double?>.value(0),
            ),
            field: 'lineHeight',
            message: 'Must be > 0.',
          ),
        ];

    for (final invalid in invalidCases) {
      expect(
        invalid.create,
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
}
