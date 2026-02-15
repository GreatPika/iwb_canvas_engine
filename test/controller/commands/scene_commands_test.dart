import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller.dart';

void main() {
  // INV:INV-V2-TXN-ATOMIC-COMMIT
  // INV:INV-V2-SIGNALS-AFTER-COMMIT

  SceneControllerCore buildController() {
    return SceneControllerCore(
      initialSnapshot: SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            nodes: const <NodeSnapshot>[
              RectNodeSnapshot(id: 'base', size: Size(20, 10)),
            ],
          ),
        ],
      ),
    );
  }

  test('scene commands route structural updates through write', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    var notifications = 0;
    controller.addListener(() {
      notifications = notifications + 1;
    });

    final created = controller.commands.writeAddNode(
      RectNodeSpec(id: 'cmd-added', size: const Size(6, 6)),
    );
    await pumpEventQueue();

    expect(created, 'cmd-added');
    expect(controller.snapshot.layers, hasLength(2));
    expect(controller.snapshot.layers.first.nodes.length, 1);
    expect(controller.snapshot.layers.last.nodes.single.id, 'cmd-added');
    expect(controller.structuralRevision, 1);
    expect(notifications, 1);
  });

  test(
    'scene commands handle missing patch/delete and selection commands',
    () async {
      final controller = buildController();
      addTearDown(controller.dispose);

      final signalTypes = <String>[];
      final sub = controller.signals.listen((signal) {
        signalTypes.add(signal.type);
      });
      addTearDown(sub.cancel);

      final patchMissing = controller.commands.writePatchNode(
        const RectNodePatch(
          id: 'missing',
          strokeWidth: PatchField<double>.value(2),
        ),
      );
      final patchExisting = controller.commands.writePatchNode(
        const RectNodePatch(
          id: 'base',
          strokeWidth: PatchField<double>.value(3),
        ),
      );
      final deleteMissing = controller.commands.writeDeleteNode('missing');
      final deleteExisting = controller.commands.writeDeleteNode('base');

      controller.commands.writeSelectionReplace(const <NodeId>{'base'});
      controller.commands.writeSelectionToggle('base');
      await pumpEventQueue();

      expect(patchMissing, isFalse);
      expect(patchExisting, isTrue);
      expect(deleteMissing, isFalse);
      expect(deleteExisting, isTrue);
      expect(
        signalTypes,
        containsAll(<String>[
          'node.updated',
          'node.removed',
          'selection.replaced',
          'selection.toggled',
        ]),
      );
    },
  );

  test(
    'scene commands cover selection transform/delete/clear helpers',
    () async {
      final controller = buildController();
      addTearDown(controller.dispose);

      final signalTypes = <String>[];
      final sub = controller.signals.listen((signal) {
        signalTypes.add(signal.type);
      });
      addTearDown(sub.cancel);

      controller.commands.writeSelectionClear();
      await pumpEventQueue();
      expect(signalTypes, contains('selection.cleared'));

      final selectNone = controller.commands.writeSelectionSelectAll(
        onlySelectable: false,
      );
      await pumpEventQueue();
      expect(selectNone, 1);
      expect(signalTypes, contains('selection.all'));
      expect(controller.selectedNodeIds, const <NodeId>{'base'});

      final transformed = controller.commands.writeSelectionTransform(
        Transform2D.translation(const Offset(4, 6)),
      );
      await pumpEventQueue();
      expect(transformed, 1);
      expect(signalTypes, contains('selection.transformed'));

      final deleted = controller.commands.writeDeleteSelection();
      await pumpEventQueue();
      expect(deleted, 1);
      expect(signalTypes, contains('selection.deleted'));

      controller.commands.writeAddNode(
        RectNodeSpec(id: 'temp', size: const Size(4, 4)),
      );
      final cleared = controller.commands.writeClearScene();
      await pumpEventQueue();
      expect(cleared, 1);
      expect(signalTypes, contains('scene.cleared'));

      controller.commands.writeBackgroundColorSet(const Color(0xFFAA5500));
      controller.commands.writeGridEnabledSet(true);
      controller.commands.writeGridCellSizeSet(42);
      controller.commands.writeCameraOffsetSet(const Offset(10, -4));
      await pumpEventQueue();
      expect(
        signalTypes,
        containsAll(<String>[
          'background.updated',
          'grid.enabled.updated',
          'grid.cell.updated',
          'camera.updated',
        ]),
      );
    },
  );
}
