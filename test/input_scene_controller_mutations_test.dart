import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';

void main() {
  test('addNode adds to layer 0 and notifies', () {
    final controller = SceneController(scene: Scene());
    addTearDown(controller.dispose);

    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.addNode(
      RectNode(
        id: 'r1',
        size: const Size(10, 10),
        fillColor: const Color(0xFF000000),
      )..position = const Offset(0, 0),
    );

    expect(controller.scene.layers, hasLength(1));
    expect(controller.scene.layers.single.nodes.single.id, 'r1');
    expect(notifications, 1);
  });

  test('addNode throws for invalid layerIndex', () {
    final controller = SceneController(scene: Scene());
    addTearDown(controller.dispose);

    expect(
      () => controller.addNode(
        RectNode(
          id: 'r0',
          size: const Size(10, 10),
          fillColor: const Color(0xFF000000),
        )..position = const Offset(0, 0),
        layerIndex: -1,
      ),
      throwsRangeError,
    );

    expect(
      () => controller.addNode(
        RectNode(
          id: 'r1',
          size: const Size(10, 10),
          fillColor: const Color(0xFF000000),
        )..position = const Offset(0, 0),
        layerIndex: 1,
      ),
      throwsRangeError,
    );
  });

  test('addNode throws for out-of-range index on non-empty scene', () {
    final controller = SceneController(scene: Scene(layers: [Layer()]));
    addTearDown(controller.dispose);

    expect(
      () => controller.addNode(
        RectNode(
          id: 'r1',
          size: const Size(10, 10),
          fillColor: const Color(0xFF000000),
        )..position = const Offset(0, 0),
        layerIndex: 1,
      ),
      throwsRangeError,
    );
  });

  test('removeNode removes node, clears selection, emits delete action', () {
    final node = RectNode(
      id: 'r1',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
    )..position = const Offset(0, 0);
    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [node]),
        ],
      ),
    );
    addTearDown(controller.dispose);

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 10,
        phase: PointerPhase.up,
      ),
    );

    expect(controller.selectedNodeIds, contains('r1'));

    final actions = <ActionCommitted>[];
    final sub = controller.actions.listen(actions.add);
    addTearDown(sub.cancel);

    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.removeNode('r1', timestampMs: 123);

    expect(controller.scene.layers.single.nodes, isEmpty);
    expect(controller.selectedNodeIds, isNot(contains('r1')));
    expect(actions, hasLength(1));
    expect(actions.single.type, ActionType.delete);
    expect(actions.single.nodeIds, ['r1']);
    expect(actions.single.timestampMs, 123);
    expect(notifications, 1);
  });

  test('removeNode default timestamp uses DateTime.now', () {
    final node = RectNode(
      id: 'r1',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
    )..position = const Offset(0, 0);
    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [node]),
        ],
      ),
    );
    addTearDown(controller.dispose);

    final actions = <ActionCommitted>[];
    final sub = controller.actions.listen(actions.add);
    addTearDown(sub.cancel);

    final before = DateTime.now().millisecondsSinceEpoch;
    controller.removeNode('r1');
    final after = DateTime.now().millisecondsSinceEpoch;

    expect(actions, hasLength(1));
    expect(actions.single.type, ActionType.delete);
    expect(actions.single.timestampMs, inInclusiveRange(before, after));
  });

  test('removeNode is a no-op for unknown id', () {
    final controller = SceneController(scene: Scene(layers: [Layer()]));
    addTearDown(controller.dispose);

    final actions = <ActionCommitted>[];
    final sub = controller.actions.listen(actions.add);
    addTearDown(sub.cancel);

    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.removeNode('missing', timestampMs: 1);

    expect(actions, isEmpty);
    expect(notifications, 0);
  });

  test(
    'moveNode moves node across layers, keeps selection, emits move action',
    () {
      final node = RectNode(
        id: 'r1',
        size: const Size(10, 10),
        fillColor: const Color(0xFF000000),
      )..position = const Offset(0, 0);
      final controller = SceneController(
        scene: Scene(
          layers: [
            Layer(nodes: [node]),
            Layer(),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.handlePointer(
        const PointerSample(
          pointerId: 1,
          position: Offset(0, 0),
          timestampMs: 0,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        const PointerSample(
          pointerId: 1,
          position: Offset(0, 0),
          timestampMs: 10,
          phase: PointerPhase.up,
        ),
      );

      final actions = <ActionCommitted>[];
      final sub = controller.actions.listen(actions.add);
      addTearDown(sub.cancel);

      controller.moveNode('r1', targetLayerIndex: 1, timestampMs: 77);

      expect(controller.scene.layers[0].nodes, isEmpty);
      expect(controller.scene.layers[1].nodes.single.id, 'r1');
      expect(controller.selectedNodeIds, contains('r1'));

      expect(actions, hasLength(1));
      expect(actions.single.type, ActionType.move);
      expect(actions.single.nodeIds, ['r1']);
      expect(actions.single.timestampMs, 77);
      expect(actions.single.payload, <String, Object?>{
        'sourceLayerIndex': 0,
        'targetLayerIndex': 1,
      });
    },
  );

  test('moveNode throws when scene has no layers', () {
    final controller = SceneController(scene: Scene());
    addTearDown(controller.dispose);

    expect(
      () => controller.moveNode('r1', targetLayerIndex: 0),
      throwsRangeError,
    );
  });

  test('moveNode default timestamp uses DateTime.now', () {
    final node = RectNode(
      id: 'r1',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
    )..position = const Offset(0, 0);
    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [node]),
          Layer(),
        ],
      ),
    );
    addTearDown(controller.dispose);

    final actions = <ActionCommitted>[];
    final sub = controller.actions.listen(actions.add);
    addTearDown(sub.cancel);

    final before = DateTime.now().millisecondsSinceEpoch;
    controller.moveNode('r1', targetLayerIndex: 1);
    final after = DateTime.now().millisecondsSinceEpoch;

    expect(actions, hasLength(1));
    expect(actions.single.type, ActionType.move);
    expect(actions.single.timestampMs, inInclusiveRange(before, after));
  });

  test('moveNode throws for invalid target layer index', () {
    final controller = SceneController(scene: Scene(layers: [Layer()]));
    addTearDown(controller.dispose);

    expect(
      () => controller.moveNode('r1', targetLayerIndex: 1, timestampMs: 0),
      throwsRangeError,
    );
  });
}
