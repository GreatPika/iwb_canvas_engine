import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/scene_spatial_index.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller.dart';

// INV:INV-ENG-ID-INDEX-FROM-SCENE

void main() {
  SceneSnapshot twoRectSnapshot() {
    return SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          id: 'layer-auto-0',
          nodes: <NodeSnapshot>[
            RectNodeSnapshot(id: 'r1', size: Size(10, 10)),
            RectNodeSnapshot(id: 'r2', size: Size(12, 12)),
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
            id: 'layer-auto-1',
            nodes: <NodeSnapshot>[
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
            id: 'layer-auto-2',
            nodes: <NodeSnapshot>[
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
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-auto-3'),
          ],
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
              id: 'layer-auto-4',
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
              id: 'layer-auto-5',
              nodes: <NodeSnapshot>[
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
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-auto-6'),
          ],
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
}
