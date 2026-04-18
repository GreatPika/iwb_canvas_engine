import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/core/scene_limits.dart';
import 'package:iwb_canvas_engine/src/core/id_generator.dart';
import 'package:iwb_canvas_engine/src/core/scene_spatial_index.dart';
import 'package:iwb_canvas_engine/src/controller/change_set.dart';
import 'package:iwb_canvas_engine/src/controller/mutation_executor.dart';
import 'package:iwb_canvas_engine/src/controller/scene_writer.dart';
import 'package:iwb_canvas_engine/src/controller/scene_writer_runtime.dart';
import 'package:iwb_canvas_engine/src/controller/txn_context.dart';
import 'package:iwb_canvas_engine/src/controller/internal/spatial_index_cache.dart';

// INV:INV-ENG-SPATIAL-INDEX-REBUILD-ON-INVALID

void main() {
  test(
    'SceneWriter clearScene creates missing background layer and clears',
    () {
      final ctx = TxnContext(
        baseScene: Scene(
          layers: <ContentLayer>[
            ContentLayer(id: 'layer-auto-0'),
            ContentLayer(id: 'layer-auto-1'),
          ],
        ),
        workingSelection: <NodeId>{},
        baseAllNodeIds: <NodeId>{},
        idGeneratorState: createIdGeneratorStateForTesting(
          nextNodeCounter: 1,
          nextLayerCounter: 1,
        ),
        nextInstanceRevision: 1,
      );
      final writer = SceneWriter(
        SceneWriterRuntime(
          ctx: ctx,
          mutationExecutor: MutationExecutor(),
          txnSignalSink: (_) {},
        ),
      );

      final clearResult = writer.writeClearSceneKeepBackgroundResult();
      expect(clearResult.removedNodeIds, isEmpty);
      expect(clearResult.didStructuralClear, isTrue);
      expect(ctx.workingScene.layers, isEmpty);
      expect(ctx.workingScene.backgroundLayer, isNotNull);
    },
  );

  test(
    'SpatialIndexCache caches, applies incremental changes and falls back safely',
    () {
      final slice = SpatialIndexCache();
      final scene = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-2',
            nodes: <SceneNode>[RectNode(id: 'r1', size: const Size(10, 10))],
          ),
        ],
      );
      final nodeLocator = <NodeId, ({int layerIndex, int nodeIndex})>{
        'r1': (layerIndex: 0, nodeIndex: 0),
      };

      final first = slice.writeQueryHitTestCandidates(
        scene: scene,
        nodeLocator: nodeLocator,
        worldBounds: const Rect.fromLTWH(0, 0, 20, 20),
        controllerEpoch: 0,
      );
      expect(first, isNotEmpty);
      expect(slice.debugBuildCount, 1);
      expect(slice.debugIncrementalApplyCount, 0);

      slice.writeQueryHitTestCandidates(
        scene: scene,
        nodeLocator: nodeLocator,
        worldBounds: const Rect.fromLTWH(0, 0, 20, 20),
        controllerEpoch: 0,
      );
      expect(slice.debugBuildCount, 1);

      final noChange = ChangeSet();
      slice.writeHandleCommit(
        scene: scene,
        nodeLocator: nodeLocator,
        changeSet: noChange,
        controllerEpoch: 0,
      );
      slice.writeQueryHitTestCandidates(
        scene: scene,
        nodeLocator: nodeLocator,
        worldBounds: const Rect.fromLTWH(0, 0, 20, 20),
        controllerEpoch: 0,
      );
      expect(slice.debugBuildCount, 1);
      expect(slice.debugIncrementalApplyCount, 0);

      final movedScene = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-3',
            nodes: <SceneNode>[
              RectNode(
                id: 'r1',
                size: const Size(10, 10),
                transform: Transform2D.translation(const Offset(100, 0)),
              ),
            ],
          ),
        ],
      );
      final movedLocator = <NodeId, ({int layerIndex, int nodeIndex})>{
        'r1': (layerIndex: 0, nodeIndex: 0),
      };
      final movedChange = ChangeSet()
        ..txnMarkBoundsChanged()
        ..txnTrackUpdated('r1')
        ..txnTrackSpatialGeometryChanged('r1');
      slice.writeHandleCommit(
        scene: movedScene,
        nodeLocator: movedLocator,
        changeSet: movedChange,
        controllerEpoch: 0,
      );
      final movedCandidates = slice.writeQueryHitTestCandidates(
        scene: movedScene,
        nodeLocator: movedLocator,
        worldBounds: const Rect.fromLTWH(100, 0, 20, 20),
        controllerEpoch: 0,
      );
      expect(movedCandidates, isNotEmpty);
      final oldCandidatesAfterMove = slice.writeQueryHitTestCandidates(
        scene: movedScene,
        nodeLocator: movedLocator,
        worldBounds: const Rect.fromLTWH(0, 0, 20, 20),
        controllerEpoch: 0,
      );
      expect(oldCandidatesAfterMove, isEmpty);
      expect(slice.debugBuildCount, 1);
      expect(slice.debugIncrementalApplyCount, 1);

      final malformedAdded = ChangeSet()
        ..txnMarkStructuralChanged()
        ..txnTrackAdded('ghost');
      slice.writeHandleCommit(
        scene: movedScene,
        nodeLocator: movedLocator,
        changeSet: malformedAdded,
        controllerEpoch: 0,
      );
      final rebuiltAfterMalformedAdd = slice.writeQueryHitTestCandidates(
        scene: movedScene,
        nodeLocator: movedLocator,
        worldBounds: const Rect.fromLTWH(100, 0, 20, 20),
        controllerEpoch: 0,
      );
      expect(
        rebuiltAfterMalformedAdd.map((candidate) => candidate.nodeId),
        <NodeId>['r1'],
      );
      expect(slice.debugBuildCount, 2);

      final malformedBoundsOnly = ChangeSet()..txnMarkBoundsChanged();
      slice.writeHandleCommit(
        scene: movedScene,
        nodeLocator: movedLocator,
        changeSet: malformedBoundsOnly,
        controllerEpoch: 0,
      );
      slice.writeQueryHitTestCandidates(
        scene: movedScene,
        nodeLocator: movedLocator,
        worldBounds: const Rect.fromLTWH(100, 0, 20, 20),
        controllerEpoch: 0,
      );
      expect(slice.debugBuildCount, 3);

      slice.writeHandleCommit(
        scene: movedScene,
        nodeLocator: movedLocator,
        changeSet: noChange,
        controllerEpoch: 1,
      );
      slice.writeQueryHitTestCandidates(
        scene: movedScene,
        nodeLocator: movedLocator,
        worldBounds: const Rect.fromLTWH(100, 0, 20, 20),
        controllerEpoch: 1,
      );
      expect(slice.debugBuildCount, 4);

      final gridOnly = ChangeSet()..txnMarkGridChanged();
      slice.writeHandleCommit(
        scene: movedScene,
        nodeLocator: movedLocator,
        changeSet: gridOnly,
        controllerEpoch: 1,
      );
      slice.writeQueryHitTestCandidates(
        scene: movedScene,
        nodeLocator: movedLocator,
        worldBounds: const Rect.fromLTWH(100, 0, 20, 20),
        controllerEpoch: 1,
      );
      expect(slice.debugBuildCount, 4);

      final outOfRangeScene = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-4',
            nodes: <SceneNode>[
              RectNode(
                id: 'r1',
                size: const Size(10, 10),
                transform: Transform2D.translation(
                  Offset(sceneCoordMax + 500, 0),
                ),
              ),
            ],
          ),
        ],
      );
      final outOfRangeLocator = <NodeId, ({int layerIndex, int nodeIndex})>{
        'r1': (layerIndex: 0, nodeIndex: 0),
      };
      final outOfRangeBounds = Rect.fromLTWH(sceneCoordMax + 450, -20, 100, 40);
      final invalidFirst = slice.writeQueryHitTestCandidates(
        scene: outOfRangeScene,
        nodeLocator: outOfRangeLocator,
        worldBounds: outOfRangeBounds,
        controllerEpoch: 2,
      );
      expect(invalidFirst, isNotEmpty);
      expect(slice.debugBuildCount, 5);

      final outOfRangeChange = ChangeSet()
        ..txnMarkBoundsChanged()
        ..txnTrackUpdated('r1')
        ..txnTrackSpatialGeometryChanged('r1');
      slice.writeHandleCommit(
        scene: outOfRangeScene,
        nodeLocator: outOfRangeLocator,
        changeSet: outOfRangeChange,
        controllerEpoch: 2,
      );
      // INV:INV-ENG-SPATIAL-INDEX-REBUILD-ON-INVALID
      final invalidSecond = slice.writeQueryHitTestCandidates(
        scene: outOfRangeScene,
        nodeLocator: outOfRangeLocator,
        worldBounds: outOfRangeBounds,
        controllerEpoch: 2,
      );
      expect(invalidSecond, isNotEmpty);
      expect(slice.debugBuildCount, 6);

      final invalidThird = slice.writeQueryHitTestCandidates(
        scene: outOfRangeScene,
        nodeLocator: outOfRangeLocator,
        worldBounds: outOfRangeBounds,
        controllerEpoch: 2,
      );
      expect(invalidThird, isNotEmpty);
      expect(slice.debugBuildCount, 6);
    },
  );

  test(
    'SpatialIndexCache falls back to full rebuild when incremental prepare throws',
    () {
      final slice = SpatialIndexCache();
      final scene = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-5',
            nodes: <SceneNode>[RectNode(id: 'r1', size: const Size(10, 10))],
          ),
        ],
      );
      final nodeLocator = <NodeId, ({int layerIndex, int nodeIndex})>{
        'r1': (layerIndex: 0, nodeIndex: 0),
      };

      slice.writeQueryHitTestCandidates(
        scene: scene,
        nodeLocator: nodeLocator,
        worldBounds: const Rect.fromLTWH(0, 0, 20, 20),
        controllerEpoch: 0,
      );
      expect(slice.debugBuildCount, 1);
      expect(slice.debugIncrementalApplyCount, 0);

      final movedScene = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-6',
            nodes: <SceneNode>[
              RectNode(
                id: 'r1',
                size: const Size(10, 10),
                transform: Transform2D.translation(const Offset(100, 0)),
              ),
            ],
          ),
        ],
      );
      final movedLocator = <NodeId, ({int layerIndex, int nodeIndex})>{
        'r1': (layerIndex: 0, nodeIndex: 0),
      };
      final movedChange = ChangeSet()
        ..txnMarkBoundsChanged()
        ..txnTrackUpdated('r1')
        ..txnTrackSpatialGeometryChanged('r1');

      slice.debugBeforeIncrementalPrepareHook = () {
        throw StateError('forced incremental prepare failure');
      };
      slice.writeHandleCommit(
        scene: movedScene,
        nodeLocator: movedLocator,
        changeSet: movedChange,
        controllerEpoch: 0,
      );

      final movedCandidates = slice.writeQueryHitTestCandidates(
        scene: movedScene,
        nodeLocator: movedLocator,
        worldBounds: const Rect.fromLTWH(100, 0, 20, 20),
        controllerEpoch: 0,
      );
      final oldCandidates = slice.writeQueryHitTestCandidates(
        scene: movedScene,
        nodeLocator: movedLocator,
        worldBounds: const Rect.fromLTWH(0, 0, 20, 20),
        controllerEpoch: 0,
      );

      expect(movedCandidates.map((candidate) => candidate.nodeId), <NodeId>[
        'r1',
      ]);
      expect(oldCandidates, isEmpty);
      expect(slice.debugBuildCount, 2);
      expect(slice.debugIncrementalApplyCount, 0);
    },
  );

  test(
    'SpatialIndexCache rethrows when fallback rebuild also fails and keeps active index',
    () {
      final slice = SpatialIndexCache();
      final scene = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-7',
            nodes: <SceneNode>[RectNode(id: 'r1', size: const Size(10, 10))],
          ),
        ],
      );
      final nodeLocator = <NodeId, ({int layerIndex, int nodeIndex})>{
        'r1': (layerIndex: 0, nodeIndex: 0),
      };

      final initialCandidates = slice.writeQueryHitTestCandidates(
        scene: scene,
        nodeLocator: nodeLocator,
        worldBounds: const Rect.fromLTWH(0, 0, 20, 20),
        controllerEpoch: 0,
      );
      expect(initialCandidates.map((candidate) => candidate.nodeId), <NodeId>[
        'r1',
      ]);
      expect(slice.debugBuildCount, 1);

      final movedScene = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-8',
            nodes: <SceneNode>[
              RectNode(
                id: 'r1',
                size: const Size(10, 10),
                transform: Transform2D.translation(const Offset(100, 0)),
              ),
            ],
          ),
        ],
      );
      final movedLocator = <NodeId, ({int layerIndex, int nodeIndex})>{
        'r1': (layerIndex: 0, nodeIndex: 0),
      };
      final movedChange = ChangeSet()
        ..txnMarkBoundsChanged()
        ..txnTrackUpdated('r1')
        ..txnTrackSpatialGeometryChanged('r1');

      slice.debugBeforeIncrementalPrepareHook = () {
        throw StateError('forced incremental prepare failure');
      };
      slice.debugBeforeFallbackRebuildHook = () {
        throw StateError('forced fallback rebuild failure');
      };

      expect(
        () => slice.writeHandleCommit(
          scene: movedScene,
          nodeLocator: movedLocator,
          changeSet: movedChange,
          controllerEpoch: 0,
        ),
        throwsStateError,
      );

      final stillOldAtOrigin = slice.writeQueryHitTestCandidates(
        scene: scene,
        nodeLocator: nodeLocator,
        worldBounds: const Rect.fromLTWH(0, 0, 20, 20),
        controllerEpoch: 0,
      );
      final noMovedCandidates = slice.writeQueryHitTestCandidates(
        scene: movedScene,
        nodeLocator: movedLocator,
        worldBounds: const Rect.fromLTWH(100, 0, 20, 20),
        controllerEpoch: 0,
      );
      expect(stillOldAtOrigin.map((candidate) => candidate.nodeId), <NodeId>[
        'r1',
      ]);
      expect(noMovedCandidates, isEmpty);
      expect(slice.debugBuildCount, 1);
      expect(slice.debugIncrementalApplyCount, 0);
    },
  );

  test('writeQueryPaintCandidates threads scoped background paint queries', () {
    final cache = SpatialIndexCache();
    final scene = Scene(
      backgroundLayer: BackgroundLayer(
        nodes: <SceneNode>[
          RectNode(
            id: 'bg',
            size: const Size(10, 10),
            transform: Transform2D.translation(const Offset(5, 5)),
          ),
        ],
      ),
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-auto-scope',
          nodes: <SceneNode>[
            RectNode(
              id: 'fg',
              size: const Size(10, 10),
              transform: Transform2D.translation(const Offset(5, 5)),
            ),
          ],
        ),
      ],
    );
    final nodeLocator = <NodeId, ({int layerIndex, int nodeIndex})>{
      'bg': (layerIndex: -1, nodeIndex: 0),
      'fg': (layerIndex: 0, nodeIndex: 0),
    };

    expect(
      cache
          .writeQueryPaintCandidates(
            scene: scene,
            nodeLocator: nodeLocator,
            worldBounds: const Rect.fromLTWH(0, 0, 20, 20),
            controllerEpoch: 0,
          )
          .map((candidate) => candidate.nodeId),
      <NodeId>['fg'],
    );

    expect(
      cache
          .writeQueryPaintCandidates(
            scene: scene,
            nodeLocator: nodeLocator,
            worldBounds: const Rect.fromLTWH(0, 0, 20, 20),
            controllerEpoch: 0,
            scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers,
          )
          .map((candidate) => candidate.nodeId)
          .toSet(),
      <NodeId>{'bg', 'fg'},
    );
  });
}
