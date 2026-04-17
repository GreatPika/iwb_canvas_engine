import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/controller/scene_store_controller.dart';

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

  test(
    'resolveSpatialCandidateSnapshot accepts valid foreground candidate',
    () {
      final controller = SceneStoreController(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      final candidates = controller.queryHitTestCandidates(
        const Rect.fromLTWH(0, 0, 0, 0),
      );
      expect(candidates, isNotEmpty);

      final resolved = controller.resolveSpatialCandidateSnapshot((
        nodeId: candidates.first.nodeId,
        layerIndex: candidates.first.layerIndex,
        nodeIndex: candidates.first.nodeIndex,
      ));
      expect(resolved, isNotNull);
      expect(resolved?.id, candidates.first.nodeId);
    },
  );

  test(
    'resolveSpatialCandidateSnapshot rejects candidate from background locator',
    () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          backgroundLayer: BackgroundLayerSnapshot(
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(id: 'bg-node', size: Size(10, 10)),
            ],
          ),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-auto-1'),
          ],
        ),
      );
      addTearDown(controller.dispose);

      const backgroundCandidate = (
        nodeId: 'bg-node',
        layerIndex: -1,
        nodeIndex: 0,
      );
      expect(
        controller.resolveSpatialCandidateSnapshot(backgroundCandidate),
        isNull,
      );
    },
  );

  test('resolveSpatialCandidateSnapshot rejects out-of-range indices', () {
    final controller = SceneStoreController(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    const outOfRangeLayer = (nodeId: 'r1', layerIndex: 99, nodeIndex: 0);
    const outOfRangeNode = (nodeId: 'r1', layerIndex: 0, nodeIndex: 99);

    expect(controller.resolveSpatialCandidateSnapshot(outOfRangeLayer), isNull);
    expect(controller.resolveSpatialCandidateSnapshot(outOfRangeNode), isNull);
  });

  test(
    'resolveSpatialCandidateSnapshot rejects stale identity after replaceScene',
    () {
      final controller = SceneStoreController(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      final stale = controller
          .queryHitTestCandidates(const Rect.fromLTWH(0, 0, 0, 0))
          .first;

      controller.writeReplaceScene(
        SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-2',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(id: 'fresh-1', size: Size(10, 10)),
                RectNodeSnapshot(id: 'fresh-2', size: Size(12, 12)),
              ],
            ),
          ],
        ),
      );

      expect(
        controller.resolveSpatialCandidateSnapshot((
          nodeId: stale.nodeId,
          layerIndex: stale.layerIndex,
          nodeIndex: stale.nodeIndex,
        )),
        isNull,
      );
    },
  );

  test(
    'resolveSpatialCandidateSnapshot accepts non-geometry clone after selection write',
    () {
      final controller = SceneStoreController(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      final candidate = controller
          .queryHitTestCandidates(const Rect.fromLTWH(0, 0, 0, 0))
          .first;

      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'r1'});
      });

      final resolved = controller.resolveSpatialCandidateSnapshot((
        nodeId: candidate.nodeId,
        layerIndex: candidate.layerIndex,
        nodeIndex: candidate.nodeIndex,
      ));
      expect(resolved, isNotNull);
      if (resolved == null) {
        fail('Expected spatial candidate resolution to return selected node.');
      }
      expect(resolved.id, candidate.nodeId);
      expect(resolved, isA<RectNodeSnapshot>());
    },
  );

  test(
    'resolveSnapshotNodeById accepts valid content locator and validates id at location',
    () {
      final controller = SceneStoreController(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      final resolved = controller.resolveSnapshotNodeById('r2');

      expect(resolved, isNotNull);
      expect(resolved?.layerIndex, 0);
      expect(resolved?.nodeIndex, 1);
      expect(resolved?.node.id, 'r2');
    },
  );

  test(
    'resolveSnapshotNodeById supports background locator with layerIndex -1',
    () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          backgroundLayer: BackgroundLayerSnapshot(
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(id: 'bg-node', size: Size(10, 10)),
            ],
          ),
        ),
      );
      addTearDown(controller.dispose);

      final resolved = controller.resolveSnapshotNodeById('bg-node');

      expect(resolved, isNotNull);
      expect(resolved?.layerIndex, -1);
      expect(resolved?.nodeIndex, 0);
      expect(resolved?.node.id, 'bg-node');
    },
  );

  test(
    'resolveSnapshotNodeById rejects stale locator after replaceScene without snapshot scan fallback',
    () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-0',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(id: 'stale', size: Size(10, 10)),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      expect(controller.resolveSnapshotNodeById('stale'), isNotNull);

      controller.writeReplaceScene(
        SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-1',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(id: 'fresh', size: Size(10, 10)),
                RectNodeSnapshot(id: 'stale', size: Size(10, 10)),
              ],
            ),
          ],
        ),
      );

      expect(controller.resolveSnapshotNodeById('stale')?.nodeIndex, 1);
      expect(
        controller.resolveSpatialCandidateSnapshot(const (
          nodeId: 'stale',
          layerIndex: 0,
          nodeIndex: 0,
        )),
        isNull,
      );
    },
  );
}
