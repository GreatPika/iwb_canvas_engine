import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller_committed_mutation_access.dart';
import 'package:iwb_canvas_engine/src/controller/scene_store_controller.dart';

void main() {
  test(
    'adapter stays a thin committed mutation bridge over store controller',
    () async {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-0',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(
                  id: 'a',
                  size: const Size(20, 10),
                  transform: Transform2D.translation(const Offset(10, 10)),
                ),
                RectNodeSnapshot(
                  id: 'b',
                  size: const Size(20, 10),
                  transform: Transform2D.translation(const Offset(40, 10)),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final access = SceneStoreControllerCommittedMutationAccess(controller);
      expect(access.ensureLayer('layer-auto-1', index: 0), isTrue);
      expect(
        access.addNode(
          RectNodeSpec(id: 'c', size: const Size(8, 8)),
          layerId: 'layer-auto-1',
        ),
        'c',
      );
      expect(
        access.patchNode(
          RectNodePatch(id: 'c', strokeWidth: PatchField<double>.value(2)),
        ),
        isTrue,
      );
      expect(access.removeNode('c'), isTrue);

      access.setBackgroundColor(const Color(0xFF00FF00));
      access.setGridEnabled(true);
      access.setGridCellSize(16);
      access.setCameraOffset(const Offset(5, 6));
      expect(controller.snapshot.background.color, const Color(0xFF00FF00));
      expect(controller.snapshot.background.grid.isEnabled, isTrue);
      expect(controller.snapshot.background.grid.cellSize, 16);
      expect(controller.snapshot.camera.offset, const Offset(5, 6));

      access.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'a'});
      });
      expect(access.selectedNodeIds, const <NodeId>{'a'});

      access.replaceSelection(const <NodeId>{'b'});
      access.toggleSelection('a');
      expect(access.selectedNodeIds, const <NodeId>{'a', 'b'});
      access.clearSelection();
      expect(access.selectedNodeIds, isEmpty);
      expect(access.selectAll(onlySelectable: false), 2);
      expect(access.selectedNodeIds, const <NodeId>{'a', 'b'});

      final contentNodes = controller.snapshot.layers.last.nodes;
      final center = access.centerWorldForNodeSnapshots(contentNodes);
      expect(center, const Offset(25, 10));

      expect(
        access.transformSelection(Transform2D.translation(const Offset(5, 0))),
        2,
      );
      final movedB =
          controller.snapshot.layers.last.nodes.last as RectNodeSnapshot;
      expect(movedB.transform.translation, const Offset(45, 10));

      expect(access.deleteSelection(), 2);
      expect(controller.snapshot.layers.last.nodes, isEmpty);

      final strokeId = access.commitDrawStroke(
        points: const <Offset>[Offset.zero, Offset(4, 4)],
        thickness: 2,
        color: const Color(0xFF112233),
        opacity: 1,
      );
      final lineId = access.commitDrawLineFromWorldSegment(
        start: const Offset(2, 2),
        end: const Offset(8, 8),
        thickness: 3,
        color: const Color(0xFF445566),
        opacity: 1,
      );
      expect(access.commitEraseNodes(<NodeId>{strokeId}), 1);
      expect(
        controller.snapshot.layers
            .expand((layer) => layer.nodes)
            .map((node) => node.id),
        contains(lineId),
      );

      final clearResult = access.clearSceneExactResult();
      expect(clearResult.didStructuralClear, isTrue);
      expect(clearResult.removedNodeIds, <NodeId>[lineId]);

      final replacement = access.prepareSceneReplacement(
        SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-replaced',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(id: 'fresh', size: const Size(4, 4)),
              ],
            ),
          ],
        ),
      );
      access.writePreparedSceneReplacement(replacement);
      expect(controller.snapshot.layers.single.nodes.single.id, 'fresh');

      var notifications = 0;
      controller.addListener(() {
        notifications = notifications + 1;
      });
      access.requestRepaint();
      await pumpEventQueue();
      expect(notifications, greaterThan(0));
    },
  );
}
