import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart' show RectNode;
import 'package:iwb_canvas_engine/src/core/scene_spatial_index.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller.dart';

// INV:INV-ENG-ID-INDEX-FROM-SCENE
// INV:INV-ENG-TXN-COPY-ON-WRITE
// INV:INV-ENG-TEXT-SIZE-DERIVED

void main() {
  SceneSnapshot twoRectSnapshot() {
    return SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          nodes: <NodeSnapshot>[
            const RectNodeSnapshot(id: 'r1', size: Size(10, 10)),
            const RectNodeSnapshot(id: 'r2', size: Size(12, 12)),
          ],
        ),
      ],
    );
  }

  test('spatial index updates incrementally on bounds revision change', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final beforeQuery = controller.querySpatialCandidates(
      const Rect.fromLTWH(0, 0, 0, 0),
    );
    expect(beforeQuery, isNotEmpty);
    expect(controller.debugSpatialIndexBuildCount, 1);

    controller.write<void>((writer) {
      writer.writeSelectionReplace(const <NodeId>{'r1'});
      writer.writeSelectionTranslate(const Offset(80, 0));
    });

    final afterQuery = controller.querySpatialCandidates(
      const Rect.fromLTWH(80, 0, 0, 0),
    );
    expect(afterQuery, isNotEmpty);
    expect(controller.debugSpatialIndexBuildCount, 1);
    expect(controller.debugSpatialIndexIncrementalApplyCount, 1);
  });

  test(
    'single-node transform stays incremental without full materialization',
    () {
      final controller = SceneControllerCore(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      controller.querySpatialCandidates(const Rect.fromLTWH(0, 0, 0, 0));
      expect(controller.debugSpatialIndexBuildCount, 1);

      controller.write<void>((writer) {
        final changed = writer.writeNodeTransformSet(
          'r1',
          Transform2D.translation(const Offset(100, 0)),
        );
        expect(changed, isTrue);
      });

      final moved = controller.querySpatialCandidates(
        const Rect.fromLTWH(100, 0, 0, 0),
      );
      expect(moved.map((candidate) => candidate.node.id), contains('r1'));
      expect(controller.debugSpatialIndexBuildCount, 1);
      expect(controller.debugSpatialIndexIncrementalApplyCount, 1);
      expect(controller.debugNodeIdSetMaterializations, 0);
      expect(controller.debugNodeLocatorMaterializations, 0);
    },
  );

  test('spatial index updates incrementally on hitPadding change', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final beforeQuery = controller.querySpatialCandidates(
      const Rect.fromLTWH(30, 0, 0, 0),
    );
    expect(beforeQuery, isEmpty);
    expect(controller.debugSpatialIndexBuildCount, 1);

    controller.write<void>((writer) {
      writer.writeNodePatch(
        const RectNodePatch(
          id: 'r1',
          common: CommonNodePatch(hitPadding: PatchField<double>.value(22)),
        ),
      );
    });

    final afterQuery = controller.querySpatialCandidates(
      const Rect.fromLTWH(30, 0, 0, 0),
    );
    expect(afterQuery.map((candidate) => candidate.node.id), contains('r1'));
    expect(
      afterQuery.map((candidate) => candidate.node.id),
      isNot(contains('r2')),
    );
    expect(controller.debugSpatialIndexBuildCount, 1);
    expect(controller.debugSpatialIndexIncrementalApplyCount, 1);
  });

  test('spatial index handles huge node and updates incrementally', () {
    final controller = SceneControllerCore(
      initialSnapshot: SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            nodes: const <NodeSnapshot>[
              RectNodeSnapshot(id: 'huge', size: Size(10000, 10000)),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);

    final initial = controller.querySpatialCandidates(
      const Rect.fromLTWH(0, 0, 10, 10),
    );
    expect(initial.map((candidate) => candidate.node.id), <NodeId>['huge']);
    expect(controller.debugSpatialIndexBuildCount, 1);

    controller.write<void>((writer) {
      writer.writeSelectionReplace(const <NodeId>{'huge'});
      writer.writeSelectionTranslate(const Offset(2e6, 0));
    });

    final oldProbe = controller.querySpatialCandidates(
      const Rect.fromLTWH(0, 0, 10, 10),
    );
    expect(oldProbe, isEmpty);

    final movedProbe = controller.querySpatialCandidates(
      const Rect.fromLTWH(2e6, 0, 10, 10),
    );
    expect(movedProbe.map((candidate) => candidate.node.id), <NodeId>['huge']);
    expect(controller.debugSpatialIndexBuildCount, 1);
    expect(controller.debugSpatialIndexIncrementalApplyCount, 1);
  });

  test('spatial index invalidates and rebuilds after replaceScene', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final beforeQuery = controller.querySpatialCandidates(
      const Rect.fromLTWH(0, 0, 0, 0),
    );
    expect(beforeQuery, isNotEmpty);
    expect(controller.debugSpatialIndexBuildCount, 1);

    controller.writeReplaceScene(
      SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            nodes: const <NodeSnapshot>[
              RectNodeSnapshot(id: 'fresh', size: Size(10, 10)),
            ],
          ),
        ],
      ),
    );

    final afterQuery = controller.querySpatialCandidates(
      const Rect.fromLTWH(0, 0, 0, 0),
    );
    expect(afterQuery.map((candidate) => candidate.node.id), <NodeId>['fresh']);
    expect(controller.debugSpatialIndexBuildCount, 2);
    expect(controller.debugSpatialIndexIncrementalApplyCount, 0);
  });

  test(
    'spatial index stays consistent across insert-move-erase-replace-move',
    () {
      final controller = SceneControllerCore(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[ContentLayerSnapshot()],
        ),
      );
      addTearDown(controller.dispose);

      Set<NodeId> queryIds(Rect probe) {
        return controller
            .querySpatialCandidates(probe)
            .map((candidate) => candidate.node.id)
            .toSet();
      }

      void expectStableQuery({
        required Rect probe,
        required Set<NodeId> expectedPresent,
        required Set<NodeId> expectedAbsent,
      }) {
        final first = queryIds(probe);
        final second = queryIds(probe);
        expect(first, expectedPresent);
        expect(second, expectedPresent);
        for (final id in expectedAbsent) {
          expect(first.contains(id), isFalse);
          expect(second.contains(id), isFalse);
        }
      }

      const originProbe = Rect.fromLTWH(0, 0, 12, 12);
      const movedProbe = Rect.fromLTWH(60, 0, 12, 12);
      const replacedProbe = Rect.fromLTWH(200, 0, 12, 12);
      const movedAfterReplaceProbe = Rect.fromLTWH(260, 0, 12, 12);

      // Build index for the initial empty document.
      expectStableQuery(
        probe: originProbe,
        expectedPresent: const <NodeId>{},
        expectedAbsent: const <NodeId>{'r1', 'fresh'},
      );
      expect(controller.debugSpatialIndexBuildCount, 1);
      expect(controller.debugSpatialIndexIncrementalApplyCount, 0);

      controller.write<void>((writer) {
        writer.writeNodeInsert(
          RectNodeSpec(id: 'r1', size: const Size(10, 10)),
        );
      });
      expectStableQuery(
        probe: originProbe,
        expectedPresent: const <NodeId>{'r1'},
        expectedAbsent: const <NodeId>{'fresh'},
      );

      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'r1'});
        writer.writeSelectionTranslate(const Offset(60, 0));
      });
      expectStableQuery(
        probe: originProbe,
        expectedPresent: const <NodeId>{},
        expectedAbsent: const <NodeId>{'r1', 'fresh'},
      );
      expectStableQuery(
        probe: movedProbe,
        expectedPresent: const <NodeId>{'r1'},
        expectedAbsent: const <NodeId>{'fresh'},
      );

      controller.write<void>((writer) {
        expect(writer.writeNodeErase('r1'), isTrue);
      });
      expectStableQuery(
        probe: movedProbe,
        expectedPresent: const <NodeId>{},
        expectedAbsent: const <NodeId>{'r1', 'fresh'},
      );

      final buildCountBeforeReplace = controller.debugSpatialIndexBuildCount;
      controller.writeReplaceScene(
        SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(
                  id: 'fresh',
                  size: const Size(10, 10),
                  transform: Transform2D.translation(Offset(200, 0)),
                ),
              ],
            ),
          ],
        ),
      );
      expectStableQuery(
        probe: replacedProbe,
        expectedPresent: const <NodeId>{'fresh'},
        expectedAbsent: const <NodeId>{'r1'},
      );
      expect(
        controller.debugSpatialIndexBuildCount,
        buildCountBeforeReplace + 1,
      );

      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'fresh'});
        writer.writeSelectionTranslate(const Offset(60, 0));
      });
      expectStableQuery(
        probe: replacedProbe,
        expectedPresent: const <NodeId>{},
        expectedAbsent: const <NodeId>{'fresh', 'r1'},
      );
      expectStableQuery(
        probe: movedAfterReplaceProbe,
        expectedPresent: const <NodeId>{'fresh'},
        expectedAbsent: const <NodeId>{'r1'},
      );
    },
  );

  test(
    'spatial index keeps candidate indices after erase in middle of layer',
    () {
      final controller = SceneControllerCore(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              nodes: const <NodeSnapshot>[
                RectNodeSnapshot(id: 'r1', size: Size(10, 10)),
                RectNodeSnapshot(id: 'r2', size: Size(10, 10)),
                RectNodeSnapshot(id: 'r3', size: Size(10, 10)),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.querySpatialCandidates(const Rect.fromLTWH(0, 0, 0, 0));
      expect(controller.debugSpatialIndexBuildCount, 1);

      controller.write<void>((writer) {
        writer.writeNodeErase('r2');
      });

      final candidates = controller.querySpatialCandidates(
        const Rect.fromLTWH(0, 0, 0, 0),
      );
      final byId = <NodeId, SceneSpatialCandidate>{
        for (final candidate in candidates) candidate.node.id: candidate,
      };
      expect(byId.containsKey('r1'), isTrue);
      expect(byId.containsKey('r2'), isFalse);
      expect(byId.containsKey('r3'), isTrue);
      expect(byId['r1']!.layerIndex, 0);
      expect(byId['r1']!.nodeIndex, 0);
      expect(byId['r3']!.layerIndex, 0);
      expect(byId['r3']!.nodeIndex, 1);
      expect(controller.resolveSpatialCandidateNode(byId['r1']!), isNotNull);
      expect(controller.resolveSpatialCandidateNode(byId['r3']!), isNotNull);
      expect(controller.debugSpatialIndexBuildCount, 1);
      expect(controller.debugSpatialIndexIncrementalApplyCount, 1);
    },
  );

  test(
    'spatial index stays incremental across bulk draw-erase-redraw cycle',
    () {
      final controller = SceneControllerCore(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[ContentLayerSnapshot()],
        ),
      );
      addTearDown(controller.dispose);

      const batchSize = 120;
      final firstBandProbe = Rect.fromLTWH(-32, -32, batchSize * 16 + 64, 64);
      final allBandsProbe = Rect.fromLTWH(-32, -32, batchSize * 16 + 64, 128);

      controller.querySpatialCandidates(const Rect.fromLTWH(0, 0, 1, 1));
      expect(controller.debugSpatialIndexBuildCount, 1);
      expect(controller.debugSpatialIndexIncrementalApplyCount, 0);

      controller.write<void>((writer) {
        for (var i = 0; i < batchSize; i++) {
          writer.writeNodeInsert(
            RectNodeSpec(
              id: 'a$i',
              size: const Size(8, 8),
              transform: Transform2D.translation(Offset(i * 16, 0)),
            ),
          );
        }
      });

      final afterFirstDraw = controller.querySpatialCandidates(firstBandProbe);
      expect(
        afterFirstDraw.map((candidate) => candidate.node.id).toSet().length,
        batchSize,
      );
      expect(controller.debugSpatialIndexBuildCount, 1);
      expect(controller.debugSpatialIndexIncrementalApplyCount, 1);

      controller.write<void>((writer) {
        for (var i = 0; i < batchSize; i += 2) {
          expect(writer.writeNodeErase('a$i'), isTrue);
        }
      });

      final afterErase = controller.querySpatialCandidates(firstBandProbe);
      final afterEraseIds = afterErase
          .map((candidate) => candidate.node.id)
          .toSet();
      expect(afterEraseIds.length, batchSize ~/ 2);
      expect(afterEraseIds.contains('a0'), isFalse);
      expect(afterEraseIds.contains('a1'), isTrue);
      expect(controller.debugSpatialIndexBuildCount, 1);
      expect(controller.debugSpatialIndexIncrementalApplyCount, 2);

      controller.write<void>((writer) {
        for (var i = 0; i < batchSize; i++) {
          writer.writeNodeInsert(
            RectNodeSpec(
              id: 'b$i',
              size: const Size(8, 8),
              transform: Transform2D.translation(Offset(i * 16, 64)),
            ),
          );
        }
      });

      final afterSecondDraw = controller.querySpatialCandidates(allBandsProbe);
      final idsAfterSecondDraw = afterSecondDraw
          .map((candidate) => candidate.node.id)
          .toSet();
      expect(idsAfterSecondDraw.length, batchSize + batchSize ~/ 2);
      expect(idsAfterSecondDraw.contains('b0'), isTrue);
      expect(idsAfterSecondDraw.contains('a1'), isTrue);
      expect(idsAfterSecondDraw.contains('a0'), isFalse);
      expect(controller.debugSpatialIndexBuildCount, 1);
      expect(controller.debugSpatialIndexIncrementalApplyCount, 3);

      final repeatedQuery = controller.querySpatialCandidates(allBandsProbe);
      expect(repeatedQuery.length, afterSecondDraw.length);
      expect(controller.debugSpatialIndexBuildCount, 1);
      expect(controller.debugSpatialIndexIncrementalApplyCount, 3);
    },
  );

  test('no-op hitPadding patch does not bump bounds revision', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final beforeBounds = controller.boundsRevision;

    controller.write<void>((writer) {
      writer.writeNodePatch(
        const RectNodePatch(
          id: 'r1',
          common: CommonNodePatch(hitPadding: PatchField<double>.value(0)),
        ),
      );
    });

    expect(controller.boundsRevision, beforeBounds);
    expect(controller.debugLastChangeSet.boundsChanged, isFalse);
    expect(controller.debugLastChangeSet.hitGeometryChangedIds, isEmpty);
    expect(controller.debugSceneShallowClones, 0);
    expect(controller.debugLayerShallowClones, 0);
    expect(controller.debugNodeClones, 0);
  });

  test(
    'text layout patch recomputes derived size and bumps bounds revision',
    () {
      final controller = SceneControllerCore(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              nodes: const <NodeSnapshot>[
                TextNodeSnapshot(
                  id: 't1',
                  text: 'hello',
                  size: Size(1, 1),
                  fontSize: 12,
                  color: Color(0xFF000000),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final beforeNode =
          controller.snapshot.layers.first.nodes.single as TextNodeSnapshot;
      final beforeSize = beforeNode.size;
      final beforeBoundsRevision = controller.boundsRevision;

      controller.write<void>((writer) {
        writer.writeNodePatch(
          const TextNodePatch(id: 't1', fontSize: PatchField<double>.value(36)),
        );
      });

      final afterNode =
          controller.snapshot.layers.first.nodes.single as TextNodeSnapshot;
      expect(afterNode.size.height, greaterThan(beforeSize.height));
      expect(controller.boundsRevision, beforeBoundsRevision + 1);
      expect(controller.debugLastChangeSet.boundsChanged, isTrue);
      expect(
        controller.debugLastChangeSet.hitGeometryChangedIds,
        contains('t1'),
      );
    },
  );

  test('text visual-only patch keeps bounds revision unchanged', () {
    final controller = SceneControllerCore(
      initialSnapshot: SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            nodes: const <NodeSnapshot>[
              TextNodeSnapshot(
                id: 't1',
                text: 'hello',
                size: Size(80, 24),
                fontSize: 24,
                color: Color(0xFF000000),
              ),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);

    final beforeBoundsRevision = controller.boundsRevision;

    controller.write<void>((writer) {
      writer.writeNodePatch(
        const TextNodePatch(
          id: 't1',
          color: PatchField<Color>.value(Color(0xFF00AA00)),
        ),
      );
    });

    expect(controller.boundsRevision, beforeBoundsRevision);
    expect(controller.debugLastChangeSet.boundsChanged, isFalse);
    expect(controller.debugLastChangeSet.hitGeometryChangedIds, isEmpty);
  });

  test('camera offset write does not clone layers or nodes', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeCameraOffset(const Offset(20, 10));
    });

    expect(controller.debugSceneShallowClones, 1);
    expect(controller.debugLayerShallowClones, 0);
    expect(controller.debugNodeClones, 0);
  });

  test('single node patch clones exactly one layer and one node', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeNodePatch(
        const RectNodePatch(id: 'r1', strokeWidth: PatchField<double>.value(2)),
      );
    });

    expect(controller.debugSceneShallowClones, 1);
    expect(controller.debugLayerShallowClones, 1);
    expect(controller.debugNodeClones, 1);
  });

  test('opacity patch commit does not materialize allNodeIds', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeNodePatch(
        const RectNodePatch(
          id: 'r1',
          common: CommonNodePatch(opacity: PatchField<double>.value(0.5)),
        ),
      );
    });

    expect(controller.debugNodeIdSetMaterializations, 0);
    expect(controller.debugNodeLocatorMaterializations, 0);
  });

  test('structural commit materializes allNodeIds once', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeNodeInsert(RectNodeSpec(size: const Size(8, 8)));
    });

    expect(controller.debugNodeIdSetMaterializations, 1);
    expect(controller.debugNodeLocatorMaterializations, 1);
  });

  test('node id seed stays monotonic after deleting max node-* id', () {
    final controller = SceneControllerCore(
      initialSnapshot: SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            nodes: const <NodeSnapshot>[
              RectNodeSnapshot(id: 'node-1', size: Size(10, 10)),
              RectNodeSnapshot(id: 'node-9', size: Size(12, 12)),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeNodeErase('node-9');
    });

    late final NodeId generatedId;
    controller.write<void>((writer) {
      generatedId = writer.writeNodeInsert(
        RectNodeSpec(size: const Size(6, 6)),
      );
    });

    expect(generatedId, 'node-10');
  });

  test('nextInstanceRevision stays monotonic across replaceScene', () {
    final controller = SceneControllerCore(
      initialSnapshot: SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            nodes: const <NodeSnapshot>[
              RectNodeSnapshot(
                id: 'high',
                instanceRevision: 100,
                size: Size(10, 10),
              ),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);

    controller.writeReplaceScene(
      SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            nodes: const <NodeSnapshot>[
              RectNodeSnapshot(
                id: 'low',
                instanceRevision: 3,
                size: Size(10, 10),
              ),
            ],
          ),
        ],
      ),
    );

    late final NodeId insertedId;
    controller.write<void>((writer) {
      insertedId = writer.writeNodeInsert(RectNodeSpec(size: const Size(4, 4)));
    });

    final inserted = controller.snapshot.layers
        .expand((layer) => layer.nodes)
        .firstWhere((node) => node.id == insertedId);
    expect(inserted.instanceRevision, greaterThanOrEqualTo(101));
  });

  test('resolveSpatialCandidateNode accepts valid foreground candidate', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final candidates = controller.querySpatialCandidates(
      const Rect.fromLTWH(0, 0, 0, 0),
    );
    expect(candidates, isNotEmpty);

    final resolved = controller.resolveSpatialCandidateNode(candidates.first);
    expect(resolved, isNotNull);
    expect(identical(resolved, candidates.first.node), isTrue);
  });

  test(
    'resolveSpatialCandidateNode rejects candidate from background locator',
    () {
      final controller = SceneControllerCore(
        initialSnapshot: SceneSnapshot(
          backgroundLayer: BackgroundLayerSnapshot(
            nodes: const <NodeSnapshot>[
              RectNodeSnapshot(id: 'bg-node', size: Size(10, 10)),
            ],
          ),
          layers: <ContentLayerSnapshot>[ContentLayerSnapshot()],
        ),
      );
      addTearDown(controller.dispose);

      final backgroundNode = RectNode(id: 'bg-node', size: const Size(10, 10));
      final backgroundCandidate = SceneSpatialCandidate(
        layerIndex: -1,
        nodeIndex: 0,
        node: backgroundNode,
        candidateBoundsWorld: backgroundNode.boundsWorld,
      );
      expect(
        controller.resolveSpatialCandidateNode(backgroundCandidate),
        isNull,
      );
    },
  );

  test('resolveSpatialCandidateNode rejects out-of-range indices', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final node = RectNode(id: 'fake', size: const Size(4, 4));
    final outOfRangeLayer = SceneSpatialCandidate(
      layerIndex: 99,
      nodeIndex: 0,
      node: node,
      candidateBoundsWorld: node.boundsWorld,
    );
    final outOfRangeNode = SceneSpatialCandidate(
      layerIndex: 0,
      nodeIndex: 99,
      node: node,
      candidateBoundsWorld: node.boundsWorld,
    );

    expect(controller.resolveSpatialCandidateNode(outOfRangeLayer), isNull);
    expect(controller.resolveSpatialCandidateNode(outOfRangeNode), isNull);
  });

  test(
    'resolveSpatialCandidateNode rejects stale identity after replaceScene',
    () {
      final controller = SceneControllerCore(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      final stale = controller
          .querySpatialCandidates(const Rect.fromLTWH(0, 0, 0, 0))
          .first;

      controller.writeReplaceScene(
        SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              nodes: const <NodeSnapshot>[
                RectNodeSnapshot(id: 'fresh-1', size: Size(10, 10)),
                RectNodeSnapshot(id: 'fresh-2', size: Size(12, 12)),
              ],
            ),
          ],
        ),
      );

      expect(controller.resolveSpatialCandidateNode(stale), isNull);
    },
  );

  test(
    'resolveSpatialCandidateNode accepts non-geometry clone after selection write',
    () {
      final controller = SceneControllerCore(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      final candidate = controller
          .querySpatialCandidates(const Rect.fromLTWH(0, 0, 0, 0))
          .first;

      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'r1'});
      });

      final resolved = controller.resolveSpatialCandidateNode(candidate);
      expect(resolved, isNotNull);
      expect(resolved!.id, candidate.node.id);
      expect(resolved.type, candidate.node.type);
    },
  );
}
