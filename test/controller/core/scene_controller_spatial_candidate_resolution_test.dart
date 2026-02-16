import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart' show RectNode;
import 'package:iwb_canvas_engine/src/core/scene_spatial_index.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller.dart';

// INV:INV-ENG-ID-INDEX-FROM-SCENE

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
