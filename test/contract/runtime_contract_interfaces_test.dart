import 'dart:ui';

// INV:INV-ENG-SCENE-WRITE-TXN-ADAPTER-BOUNDARY
// INV:INV-ENG-VIEW-RENDER-READ-STATE-BOUNDARY
// INV:INV-ENG-VIEW-POINTER-SEMANTICS-BOUNDARY
// INV:INV-ENG-CONTROLLER-NO-FULL-VIEW-RENDER-STATE

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/controller/scene_store_controller.dart';
import 'package:iwb_canvas_engine/src/contract/node_spec.dart';
import 'package:iwb_canvas_engine/src/contract/canvas_pointer_input.dart';
import 'package:iwb_canvas_engine/src/contract/pointer_input.dart';
import 'package:iwb_canvas_engine/src/contract/pointer_phase_codec.dart';
import 'package:iwb_canvas_engine/src/contract/scene_render_state.dart';
import 'package:iwb_canvas_engine/src/contract/scene_view_render_state.dart';
import 'package:iwb_canvas_engine/src/contract/scene_view_runtime.dart';
import 'package:iwb_canvas_engine/src/interactive/scene_controller.dart'
    as interactive;

void main() {
  group('runtime contract interfaces', () {
    test('SceneStoreController is consumable as SceneRenderState', () async {
      final controller = SceneStoreController();
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

    test('SceneStoreController is not a SceneViewRenderState', () {
      final controller = SceneStoreController();
      addTearDown(controller.dispose);

      expect(controller, isNot(isA<SceneViewRenderState>()));
    });

    test(
      'interactive SceneController exposes assembled view runtime boundary',
      () {
        final controller = interactive.SceneController();
        addTearDown(controller.dispose);

        final runtime = interactive.sceneControllerViewRuntimeOf(controller);
        final session = runtime.createPointerSession(
          isMounted: () => true,
          hasLiveRawPointers: () => false,
        );
        addTearDown(() {
          session.detach();
          session.dispose();
        });

        expect(session.pendingTapFlushTimestampMs, isNull);
        expect(() => session.detach(), returnsNormally);
        expect(runtime, isA<SceneViewRuntime>());
        expect(runtime.renderState, isA<SceneViewRenderState>());
        expect(controller, isNot(isA<SceneViewRenderState>()));
      },
    );

    test(
      'interactive SceneController rejects pointer sessions after dispose',
      () {
        final controller = interactive.SceneController();
        final runtime = interactive.sceneControllerViewRuntimeOf(controller);

        controller.dispose();

        expect(
          () => runtime.createPointerSession(
            isMounted: () => true,
            hasLiveRawPointers: () => false,
          ),
          throwsStateError,
        );
      },
    );

    test('pointer phase codec converts between canvas and internal phases', () {
      expect(
        canvasPointerPhaseFromPointerPhase(PointerPhase.down),
        CanvasPointerPhase.down,
      );
      expect(
        canvasPointerPhaseFromPointerPhase(PointerPhase.move),
        CanvasPointerPhase.move,
      );
      expect(
        canvasPointerPhaseFromPointerPhase(PointerPhase.up),
        CanvasPointerPhase.up,
      );
      expect(
        canvasPointerPhaseFromPointerPhase(PointerPhase.cancel),
        CanvasPointerPhase.cancel,
      );

      expect(
        pointerPhaseFromCanvasPointerPhase(CanvasPointerPhase.down),
        PointerPhase.down,
      );
      expect(
        pointerPhaseFromCanvasPointerPhase(CanvasPointerPhase.move),
        PointerPhase.move,
      );
      expect(
        pointerPhaseFromCanvasPointerPhase(CanvasPointerPhase.up),
        PointerPhase.up,
      );
      expect(
        pointerPhaseFromCanvasPointerPhase(CanvasPointerPhase.cancel),
        PointerPhase.cancel,
      );
    });

    test('write callback exposes SceneWriteTxn contract', () {
      final controller = SceneStoreController();
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
