import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/controller/commands/move_commands.dart';
import 'package:iwb_canvas_engine/src/controller/commands/scene_commands.dart';
import 'package:iwb_canvas_engine/src/controller/scene_store_controller.dart';

import '../support/scene_snapshot_invariant_assertions.dart';

SceneStoreController buildController() {
  return SceneStoreController(
    initialSnapshot: SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          id: 'layer-auto-0',
          nodes: <NodeSnapshot>[
            RectNodeSnapshot(id: 'base', size: Size(20, 10)),
          ],
        ),
      ],
    ),
  );
}

void assertControllerInvariants(SceneStoreController controller) {
  assertSceneInvariants(
    controller.snapshot,
    selectedNodeIds: controller.selectedNodeIds,
  );
}

SceneCommands sceneCommandsFor(SceneStoreController controller) {
  return SceneCommands(controller.writeWithSceneWriter);
}

MoveCommands moveCommandsFor(SceneStoreController controller) {
  return MoveCommands(controller.writeWithSceneWriter);
}

void main() {
  test('move commands translate selected nodes in one commit', () {
    final controller = buildController();
    addTearDown(controller.dispose);

    sceneCommandsFor(controller).writeSelectionReplace(const <NodeId>{'base'});
    final moved = moveCommandsFor(
      controller,
    ).writeTranslateSelection(const Offset(7, 3));

    final node =
        controller.snapshot.layers.first.nodes.first as RectNodeSnapshot;
    expect(moved, 1);
    expect(node.transform.tx, 7);
    expect(node.transform.ty, 3);
    expect(controller.boundsRevision, greaterThan(0));
    assertControllerInvariants(controller);
  });

  test('translate selection with NaN throws ArgumentError', () {
    final controller = buildController();
    addTearDown(controller.dispose);

    sceneCommandsFor(controller).writeSelectionReplace(const <NodeId>{'base'});

    expect(
      () => moveCommandsFor(
        controller,
      ).writeTranslateSelection(const Offset(double.nan, 1)),
      throwsArgumentError,
    );
    assertControllerInvariants(controller);
  });
}
