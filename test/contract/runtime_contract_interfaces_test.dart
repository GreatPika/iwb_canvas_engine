import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller.dart';
import 'package:iwb_canvas_engine/src/contract/node_spec.dart';
import 'package:iwb_canvas_engine/src/contract/scene_render_state.dart';
import 'package:iwb_canvas_engine/src/contract/scene_view_render_state.dart';
import 'package:iwb_canvas_engine/src/interactive/scene_controller.dart'
    as interactive;
import 'package:iwb_canvas_engine/src/interactive/scene_view_pointer_semantics.dart';

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

    test(
      'SceneControllerCore exposes committed-only defaults as SceneViewRenderState',
      () {
        final controller = SceneControllerCore();
        addTearDown(controller.dispose);

        final state = controller as SceneViewRenderState;

        expect(state.controllerEpoch, 0);
        expect(state.selectionRect, isNull);
        expect(state.cameraOffset, Offset.zero);
        expect(state.previewDeltaResolver.call('node-1'), Offset.zero);
        expect(state.hasActiveStrokePreview, isFalse);
        expect(state.activeStrokePreviewPoints, isEmpty);
        expect(state.activeStrokePreviewThickness, 0);
        expect(state.activeStrokePreviewColor, const Color(0x00000000));
        expect(state.activeStrokePreviewOpacity, 0);
        expect(state.hasActiveLinePreview, isFalse);
        expect(state.activeLinePreviewStart, isNull);
        expect(state.activeLinePreviewEnd, isNull);
        expect(state.activeLinePreviewThickness, 0);
        expect(state.activeLinePreviewColor, const Color(0x00000000));
      },
    );

    test(
      'interactive SceneController exposes view pointer semantics source',
      () {
        final controller = interactive.SceneController();
        addTearDown(controller.dispose);

        final source = controller as SceneViewPointerSemanticsSource;
        final bridge = source.createPointerSemanticsBridge(
          isMounted: () => true,
        );
        addTearDown(bridge.dispose);

        expect(bridge.pendingTapFlushTimestampMs, isNull);
        expect(controller, isA<SceneViewRenderState>());
      },
    );

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
