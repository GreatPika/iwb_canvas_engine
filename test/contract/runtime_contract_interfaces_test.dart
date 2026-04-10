import 'dart:ui';

// INV:INV-ENG-SCENE-WRITE-TXN-ADAPTER-BOUNDARY
// INV:INV-ENG-VIEW-RENDER-READ-STATE-BOUNDARY
// INV:INV-ENG-VIEW-POINTER-SEMANTICS-BOUNDARY
// INV:INV-ENG-CONTROLLER-NO-FULL-VIEW-RENDER-STATE

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/controller/scene_store_controller.dart';
import 'package:iwb_canvas_engine/src/contract/node_spec.dart';
import 'package:iwb_canvas_engine/src/contract/canvas_pointer_input.dart';
import 'package:iwb_canvas_engine/src/contract/pointer_input.dart';
import 'package:iwb_canvas_engine/src/contract/pointer_phase_codec.dart';
import 'package:iwb_canvas_engine/src/contract/scene_render_state.dart';
import 'package:iwb_canvas_engine/src/contract/scene_view_render_state.dart';
import 'package:iwb_canvas_engine/src/contract/scene_view_runtime.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
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

    test(
      'interactive SceneController routes committed scene and overlay repaints exactly',
      () async {
        final controller = interactive.SceneController(
          initialSnapshot: SceneSnapshot(
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
          ),
        );
        addTearDown(controller.dispose);

        final renderState = interactive
            .sceneControllerViewRuntimeOf(controller)
            .renderState;
        var sceneRepaints = 0;
        var overlayRepaints = 0;
        renderState.addListener(() {
          sceneRepaints += 1;
        });
        renderState.overlayRepaintListenable.addListener(() {
          overlayRepaints += 1;
        });

        controller.selection.setSelection(const <String>{'rect-1'});
        await pumpEventQueue();

        expect(sceneRepaints, 1);
        expect(overlayRepaints, 0);

        sceneRepaints = 0;
        overlayRepaints = 0;

        controller.scene.setCameraOffset(const Offset(6, 4));
        await pumpEventQueue();

        expect(sceneRepaints, 1);
        expect(overlayRepaints, 1);
      },
    );

    test(
      'interactive SceneController routes marquee and move preview repaints exactly',
      () async {
        final marqueeController = interactive.SceneController(
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
        var marqueeSceneRepaints = 0;
        var marqueeOverlayRepaints = 0;
        marqueeRenderState.addListener(() {
          marqueeSceneRepaints += 1;
        });
        marqueeRenderState.overlayRepaintListenable.addListener(() {
          marqueeOverlayRepaints += 1;
        });

        marqueeController.interaction.handlePointer(
          const CanvasPointerInput(
            pointerId: 1,
            position: Offset(12, 12),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
            kind: PointerDeviceKind.touch,
          ),
        );
        marqueeController.interaction.handlePointer(
          const CanvasPointerInput(
            pointerId: 1,
            position: Offset(76, 54),
            timestampMs: 2,
            phase: CanvasPointerPhase.move,
            kind: PointerDeviceKind.touch,
          ),
        );
        await pumpEventQueue();

        expect(marqueeController.selectionRect, isNotNull);
        expect(marqueeSceneRepaints, 0);
        expect(marqueeOverlayRepaints, 1);

        final moveController = interactive.SceneController(
          initialSnapshot: SceneSnapshot(
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
          ),
          dragStartSlop: 0.001,
        );
        addTearDown(moveController.dispose);
        moveController.selection.setSelection(const <String>{'rect-1'});
        await pumpEventQueue();

        final moveRenderState = interactive
            .sceneControllerViewRuntimeOf(moveController)
            .renderState;
        var moveSceneRepaints = 0;
        var moveOverlayRepaints = 0;
        moveRenderState.addListener(() {
          moveSceneRepaints += 1;
        });
        moveRenderState.overlayRepaintListenable.addListener(() {
          moveOverlayRepaints += 1;
        });

        moveController.interaction.handlePointer(
          const CanvasPointerInput(
            pointerId: 1,
            position: Offset(4, 4),
            timestampMs: 3,
            phase: CanvasPointerPhase.down,
            kind: PointerDeviceKind.touch,
          ),
        );
        await pumpEventQueue();
        moveSceneRepaints = 0;
        moveOverlayRepaints = 0;

        moveController.interaction.handlePointer(
          const CanvasPointerInput(
            pointerId: 1,
            position: Offset(20, 4),
            timestampMs: 4,
            phase: CanvasPointerPhase.move,
            kind: PointerDeviceKind.touch,
          ),
        );
        await pumpEventQueue();

        expect(
          moveController.previewDeltaResolver('rect-1'),
          isNot(Offset.zero),
        );
        expect(moveSceneRepaints, 1);
        expect(moveOverlayRepaints, 0);
      },
    );

    test(
      'interactive SceneController interrupts move preview through scene repaint only',
      () async {
        final controller = interactive.SceneController(
          initialSnapshot: SceneSnapshot(
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
          ),
          dragStartSlop: 0.001,
        );
        addTearDown(controller.dispose);
        controller.selection.setSelection(const <String>{'rect-1'});
        await pumpEventQueue();

        final renderState = interactive
            .sceneControllerViewRuntimeOf(controller)
            .renderState;
        var sceneRepaints = 0;
        var overlayRepaints = 0;
        renderState.addListener(() {
          sceneRepaints += 1;
        });
        renderState.overlayRepaintListenable.addListener(() {
          overlayRepaints += 1;
        });

        controller.interaction.handlePointer(
          const CanvasPointerInput(
            pointerId: 1,
            position: Offset(4, 4),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
            kind: PointerDeviceKind.touch,
          ),
        );
        controller.interaction.handlePointer(
          const CanvasPointerInput(
            pointerId: 1,
            position: Offset(20, 4),
            timestampMs: 2,
            phase: CanvasPointerPhase.move,
            kind: PointerDeviceKind.touch,
          ),
        );
        await pumpEventQueue();

        expect(controller.previewDeltaResolver('rect-1'), isNot(Offset.zero));

        sceneRepaints = 0;
        overlayRepaints = 0;

        controller.interaction.setMode(CanvasMode.draw);
        await pumpEventQueue();

        expect(controller.previewDeltaResolver('rect-1'), Offset.zero);
        expect(sceneRepaints, 1);
        expect(overlayRepaints, 0);
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
