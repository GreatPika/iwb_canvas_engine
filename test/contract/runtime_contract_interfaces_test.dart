import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller.dart';
import 'package:iwb_canvas_engine/src/contract/node_spec.dart';
import 'package:iwb_canvas_engine/src/contract/scene_render_state.dart';

void main() {
  group('runtime contract interfaces', () {
    test('SceneControllerCore is consumable as SceneRenderState', () async {
      final controller = SceneControllerCore();
      addTearDown(controller.dispose);

      final state = controller as SceneRenderState;
      var notifications = 0;
      state.addListener(() {
        notifications++;
      });

      controller.requestRepaint();
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 1);
      expect(state.snapshot.layers, isEmpty);
      expect(state.selectedNodeIds, isEmpty);
    });

    test('write callback exposes SceneWriteTxn contract', () {
      final controller = SceneControllerCore();
      addTearDown(controller.dispose);

      final insertedId = controller.write((txn) {
        final id = txn.writeNodeInsert(
          RectNodeSpec(
            size: const Size(10, 12),
            strokeColor: const Color(0xFF000000),
          ),
        );
        final changed = txn.writeSelectionReplace(<String>[id]);
        expect(changed, isTrue);
        return id;
      });

      expect(insertedId, isNotEmpty);
      expect(controller.snapshot.layers.single.nodes.single.id, insertedId);
      expect(controller.selectedNodeIds, contains(insertedId));
    });
  });
}
