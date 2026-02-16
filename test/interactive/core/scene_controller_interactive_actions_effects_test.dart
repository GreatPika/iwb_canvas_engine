import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/scene.dart';

import '../test_support/interactive_controller_fixtures.dart';

void main() {
  group('SceneControllerInteractive unit', () {
    test(
      'transform/delete/clear/notify scene APIs emit expected effects',
      () async {
        final rect = RectNode(id: 'r', size: const Size(20, 10))
          ..position = const Offset(50, 50);
        final locked = RectNode(
          id: 'locked',
          size: const Size(20, 10),
          isLocked: true,
          isDeletable: false,
        )..position = const Offset(90, 50);
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(),
              ContentLayer(nodes: <SceneNode>[rect, locked]),
            ],
          ),
        );
        addTearDown(controller.dispose);

        final actions = <ActionCommitted>[];
        final sub = controller.actions.listen(actions.add);
        addTearDown(sub.cancel);

        var notifications = 0;
        controller.addListener(() {
          notifications = notifications + 1;
        });
        controller.notifySceneChanged();
        await pumpEventQueue();
        expect(notifications, 1);

        controller.setSelection(const <NodeId>{'r', 'locked'});
        controller.rotateSelection(clockwise: true, timestampMs: 100);
        controller.flipSelectionHorizontal(timestampMs: 101);
        controller.flipSelectionVertical(timestampMs: 102);
        controller.deleteSelection(timestampMs: 103);
        expect(nodeById(controller.snapshot, 'locked').id, 'locked');

        controller.clearScene(timestampMs: 104);
        final remaining = <NodeId>{
          for (final layer in controller.snapshot.layers)
            for (final node in layer.nodes) node.id,
        };
        expect(remaining.contains('locked'), isFalse);

        await pumpEventQueue();
        expect(actions.any((a) => a.type == ActionType.transform), isTrue);
        expect(actions.any((a) => a.type == ActionType.delete), isTrue);
        expect(actions.any((a) => a.type == ActionType.clear), isTrue);
      },
    );

    test('move drag up emits transform action with delta payload', () async {
      final rect = RectNode(id: 'node', size: const Size(30, 20))
        ..position = const Offset(60, 60);
      final controller = controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(),
            ContentLayer(nodes: <SceneNode>[rect]),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final actions = <ActionCommitted>[];
      final sub = controller.actions.listen(actions.add);
      addTearDown(sub.cancel);

      controller.setSelection(const <NodeId>{'node'});
      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(60, 60),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(90, 60),
          timestampMs: 2,
          phase: CanvasPointerPhase.move,
        ),
      );
      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(100, 60),
          timestampMs: 3,
          phase: CanvasPointerPhase.up,
        ),
      );

      await pumpEventQueue();
      final transformActions = actions.where(
        (a) => a.type == ActionType.transform,
      );
      expect(transformActions, isNotEmpty);
      expect(transformActions.last.payload?['delta'], isNotNull);
    });

    test('rotateSelection emits transform for multi-node selection', () async {
      final first = RectNode(id: 'a', size: const Size(30, 20))
        ..position = const Offset(40, 40);
      final second = RectNode(id: 'b', size: const Size(30, 20))
        ..position = const Offset(140, 40);
      final controller = controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(),
            ContentLayer(nodes: <SceneNode>[first, second]),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final actions = <ActionCommitted>[];
      final sub = controller.actions.listen(actions.add);
      addTearDown(sub.cancel);

      controller.setSelection(const <NodeId>{'a', 'b'});
      controller.rotateSelection(clockwise: true, timestampMs: 200);

      await pumpEventQueue();
      final transformActions = actions
          .where((event) => event.type == ActionType.transform)
          .toList(growable: false);
      expect(transformActions, isNotEmpty);
      expect(transformActions.last.nodeIds.toSet(), const <NodeId>{'a', 'b'});
    });
  });
}
