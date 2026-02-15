import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller.dart';

import '../../utils/scene_invariants.dart';

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

void assertControllerInvariants(SceneControllerCore controller) {
  assertSceneInvariants(
    controller.snapshot,
    selectedNodeIds: controller.selectedNodeIds,
  );
}

void main() {
  test('move commands translate selected nodes in one commit', () {
    final controller = buildController();
    addTearDown(controller.dispose);

    controller.commands.writeSelectionReplace(const <NodeId>{'base'});
    final moved = controller.move.writeTranslateSelection(const Offset(7, 3));

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

    controller.commands.writeSelectionReplace(const <NodeId>{'base'});

    expect(
      () =>
          controller.move.writeTranslateSelection(const Offset(double.nan, 1)),
      throwsArgumentError,
    );
    assertControllerInvariants(controller);
  });
}
