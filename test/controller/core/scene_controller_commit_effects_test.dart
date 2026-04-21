import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/controller/scene_store_controller.dart';

// INV:INV-ENG-TXN-ATOMIC-COMMIT
// INV:INV-ENG-EPOCH-INVALIDATION
// INV:INV-ENG-SIGNALS-AFTER-COMMIT
// INV:INV-ENG-ID-INDEX-FROM-SCENE
// INV:INV-ENG-TXN-COPY-ON-WRITE
// INV:INV-ENG-TXN-WRITER-LIFETIME
// INV:INV-ENG-TEXT-SIZE-DERIVED
// INV:INV-ENG-DISPOSE-FAIL-FAST

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

  test('changeset tracks added removed and updated node ids', () {
    final controller = SceneStoreController(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeNodeInsert(RectNodeSpec(id: 'r3', size: const Size(8, 8)));
      writer.writeNodePatch(
        RectNodePatch(id: 'r1', strokeWidth: PatchField<double>.value(2)),
      );
      writer.writeNodeErase('r2');
    });

    final changes = controller.debug.lastChangeSet;
    expect(changes.addedNodeIds, <NodeId>{'r3'});
    expect(changes.removedNodeIds, <NodeId>{'r2'});
    expect(changes.updatedNodeIds, <NodeId>{'r1'});
  });

  test('boundsChanged is auto-detected for transform patch', () {
    final controller = SceneStoreController(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeNodePatch(
        RectNodePatch(
          id: 'r1',
          common: CommonNodePatch(
            transform: PatchField<Transform2D>.value(
              Transform2D(a: 1, b: 0, c: 0, d: 1, tx: 100, ty: 0),
            ),
          ),
        ),
      );
    });

    expect(controller.debug.lastChangeSet.boundsChanged, isTrue);
    expect(controller.boundsRevision, 1);
  });

  test('node patch changing isSelectable keeps explicitly selected ids', () {
    final controller = SceneStoreController(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeSelectionReplace(const <NodeId>{'r1'});
    });
    expect(controller.selectedNodeIds, const <NodeId>{'r1'});

    controller.write<void>((writer) {
      writer.writeNodePatch(
        RectNodePatch(
          id: 'r1',
          common: CommonNodePatch(isSelectable: PatchField<bool>.value(false)),
        ),
      );
    });

    expect(controller.selectedNodeIds, const <NodeId>{'r1'});
    expect(controller.debug.lastChangeSet.selectionChanged, isFalse);
  });

  test(
    'selectAll with onlySelectable false preserves non-selectable ids after commit',
    () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-1',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(id: 'selectable', size: Size(10, 10)),
                RectNodeSnapshot(
                  id: 'nonsel',
                  size: Size(10, 10),
                  isSelectable: false,
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.commands.writeSelectionSelectAll(onlySelectable: false);

      expect(controller.selectedNodeIds, const <NodeId>{
        'selectable',
        'nonsel',
      });
    },
  );

  test(
    'writeReplaceScene increments epoch clears selection and has no action signal',
    () async {
      final controller = SceneStoreController(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'r1'});
      });

      final signals = <Object>[];
      final sub = controller.signals.listen(signals.add);
      addTearDown(sub.cancel);

      var notifications = 0;
      controller.addListener(() {
        notifications = notifications + 1;
      });

      controller.writeReplaceScene(
        SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-2',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(id: 'fresh', size: Size(4, 4)),
              ],
            ),
          ],
        ),
      );
      await pumpEventQueue();

      expect(controller.controllerEpoch, 1);
      expect(controller.selectedNodeIds, isEmpty);
      expect(controller.snapshot.layers.first.nodes.single.id, 'fresh');
      expect(controller.debug.lastChangeSet.documentReplaced, isTrue);
      expect(notifications, 1);
      expect(signals, isEmpty);
    },
  );
}
