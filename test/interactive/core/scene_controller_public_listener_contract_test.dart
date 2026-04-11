import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/interactive/scene_controller.dart'
    as interactive;

import '../test_support/interactive_controller_fixtures.dart';

// INV:INV-ENG-INTERACTIVE-PUBLIC-LISTENER-REPAINT-INDEPENDENCE

void main() {
  SceneSnapshot rectSnapshot() {
    return SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          id: 'layer-1',
          nodes: <NodeSnapshot>[
            RectNodeSnapshot(
              id: 'rect-1',
              size: const Size(10, 12),
              strokeColor: const Color(0xFF000000),
            ),
          ],
        ),
      ],
    );
  }

  test(
    'public listener notifications stay stable across split repaint channels',
    () async {
      final marqueeController = SceneController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-empty'),
          ],
        ),
        dragStartSlop: 0.001,
      );
      addTearDown(marqueeController.dispose);

      final marqueeRenderState = interactive
          .sceneControllerViewRuntimeOf(marqueeController)
          .renderState;
      var marqueePublicNotifications = 0;
      var marqueeSceneRepaints = 0;
      var marqueeOverlayRepaints = 0;
      marqueeController.addListener(() {
        marqueePublicNotifications += 1;
      });
      marqueeRenderState.addListener(() {
        marqueeSceneRepaints += 1;
      });
      marqueeRenderState.overlayRepaintListenable.addListener(() {
        marqueeOverlayRepaints += 1;
      });

      marqueeController.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(12, 12),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );
      marqueeController.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(76, 54),
          timestampMs: 2,
          phase: CanvasPointerPhase.move,
        ),
      );
      await pumpEventQueue();

      expect(marqueeController.selectionRect, isNotNull);
      expect(marqueePublicNotifications, 1);
      expect(marqueeSceneRepaints, 0);
      expect(marqueeOverlayRepaints, 1);

      final moveController = SceneController(
        initialSnapshot: rectSnapshot(),
        dragStartSlop: 0.001,
      );
      addTearDown(moveController.dispose);
      moveController.selection.setSelection(const <String>{'rect-1'});
      await pumpEventQueue();

      final moveRenderState = interactive
          .sceneControllerViewRuntimeOf(moveController)
          .renderState;
      var movePublicNotifications = 0;
      var moveSceneRepaints = 0;
      var moveOverlayRepaints = 0;
      moveController.addListener(() {
        movePublicNotifications += 1;
      });
      moveRenderState.addListener(() {
        moveSceneRepaints += 1;
      });
      moveRenderState.overlayRepaintListenable.addListener(() {
        moveOverlayRepaints += 1;
      });

      moveController.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(4, 4),
          timestampMs: 3,
          phase: CanvasPointerPhase.down,
        ),
      );
      await pumpEventQueue();
      movePublicNotifications = 0;
      moveSceneRepaints = 0;
      moveOverlayRepaints = 0;

      moveController.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(20, 4),
          timestampMs: 4,
          phase: CanvasPointerPhase.move,
        ),
      );
      await pumpEventQueue();

      expect(moveController.previewDeltaResolver('rect-1'), isNot(Offset.zero));
      expect(movePublicNotifications, 1);
      expect(moveSceneRepaints, 1);
      expect(moveOverlayRepaints, 0);
    },
  );
}
