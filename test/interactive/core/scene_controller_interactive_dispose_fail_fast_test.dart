import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/scene_controller_interactive_internal_access.dart';

import '../test_support/interactive_controller_fixtures.dart';

void main() {
  group('SceneControllerInteractive unit', () {
    test(
      'dispose clears pending line timer and supports replaceScene',
      () async {
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(id: 'layer-auto-0'),
              ContentLayerSnapshot(id: 'layer-auto-1'),
            ],
          ),
        );

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.line);
        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(10, 10),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(10, 10),
            timestampMs: 2,
            phase: CanvasPointerPhase.up,
          ),
        );
        expect(controller.hasPendingLineStart, isTrue);

        controller.replaceScene(
          SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(id: 'layer-auto-2'),
              ContentLayerSnapshot(
                id: 'layer-auto-3',
                nodes: <NodeSnapshot>[
                  RectNodeSnapshot(id: 'new', size: Size(5, 5)),
                ],
              ),
            ],
          ),
        );
        expect(controller.hasPendingLineStart, isFalse);
        expect(nodeById(controller.snapshot, 'new').id, 'new');

        controller.dispose();
      },
    );

    test(
      'after dispose handlePointer fails fast and keeps state/effects unchanged',
      () async {
        // INV:INV-ENG-DISPOSE-FAIL-FAST
        final rect = RectNode(id: 'node', size: const Size(10, 10))
          ..position = const Offset(40, 40);
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-4'),
              ContentLayer(id: 'layer-auto-5', nodes: <SceneNode>[rect]),
            ],
          ),
        );

        final beforeSnapshot = controller.snapshot;
        final beforeSelection = controller.selectedNodeIds;
        final beforeMode = controller.mode;
        final beforeTool = controller.drawTool;

        final actions = <ActionCommitted>[];
        final edits = <EditTextRequested>[];
        final actionSub = controller.actions.listen(actions.add);
        final editSub = controller.editTextRequests.listen(edits.add);
        addTearDown(actionSub.cancel);
        addTearDown(editSub.cancel);

        var notifications = 0;
        controller.addListener(() {
          notifications = notifications + 1;
        });

        controller.dispose();

        expect(
          () => controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(50, 50),
              timestampMs: 1,
              phase: CanvasPointerPhase.down,
            ),
          ),
          throwsStateError,
        );
        await pumpEventQueue(times: 2);

        expect(controller.snapshot, same(beforeSnapshot));
        expect(controller.selectedNodeIds, beforeSelection);
        expect(controller.mode, beforeMode);
        expect(controller.drawTool, beforeTool);
        expect(actions, isEmpty);
        expect(edits, isEmpty);
        expect(notifications, 0);
      },
    );

    test(
      'after dispose handleDoubleTap fails fast and does not emit edit request',
      () async {
        // INV:INV-ENG-DISPOSE-FAIL-FAST
        final textNode = TextNode(
          id: 'text',
          text: 'hello',
          size: const Size(40, 20),
          color: const Color(0xFF000000),
        )..position = const Offset(40, 40);
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-6'),
              ContentLayer(id: 'layer-auto-7', nodes: <SceneNode>[textNode]),
            ],
          ),
        );

        final beforeSnapshot = controller.snapshot;
        final requests = <EditTextRequested>[];
        final sub = controller.editTextRequests.listen(requests.add);
        addTearDown(sub.cancel);

        var notifications = 0;
        controller.addListener(() {
          notifications = notifications + 1;
        });

        controller.dispose();

        expect(
          () => controller.handleDoubleTap(
            position: const Offset(40, 40),
            timestampMs: 1,
          ),
          throwsStateError,
        );
        await pumpEventQueue(times: 2);

        expect(controller.snapshot, same(beforeSnapshot));
        expect(requests, isEmpty);
        expect(notifications, 0);
      },
    );

    test(
      'after dispose representative mutating APIs fail fast and keep state',
      () async {
        // INV:INV-ENG-DISPOSE-FAIL-FAST
        final rect = RectNode(id: 'node', size: const Size(10, 10))
          ..position = const Offset(20, 20);
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-8'),
              ContentLayer(id: 'layer-auto-9', nodes: <SceneNode>[rect]),
            ],
          ),
        );

        final beforeSnapshot = controller.snapshot;
        final beforeSelection = controller.selectedNodeIds;
        final beforeMode = controller.mode;
        final beforeColor = controller.drawColor;
        final beforePenThickness = controller.penThickness;

        var notifications = 0;
        controller.addListener(() {
          notifications = notifications + 1;
        });

        controller.dispose();

        expect(
          () => controller.setDrawColor(const Color(0xFF123456)),
          throwsStateError,
        );
        expect(() => controller.penThickness = 2, throwsStateError);
        expect(() => controller.clearSelection(), throwsStateError);
        expect(
          () => controller.write<void>((writer) {
            writer.writeSelectionClear();
          }),
          throwsStateError,
        );
        expect(() => controller.notifySceneChanged(), throwsStateError);

        await pumpEventQueue(times: 2);
        expect(controller.snapshot, same(beforeSnapshot));
        expect(controller.selectedNodeIds, beforeSelection);
        expect(controller.mode, beforeMode);
        expect(controller.drawColor, beforeColor);
        expect(controller.penThickness, beforePenThickness);
        expect(notifications, 0);
      },
    );

    test('internal access throws after dispose unregisters debug owner', () {
      final controller = SceneControllerInteractive();

      controller.dispose();

      expect(
        () => sceneControllerInteractiveInternalEpoch(controller),
        throwsStateError,
      );
    });

    test(
      'dispose during interactive write fails fast and keeps controller usable',
      () async {
        // INV:INV-ENG-DISPOSE-FAIL-FAST
        final rect = RectNode(id: 'node', size: const Size(10, 10))
          ..position = const Offset(20, 20);
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-10'),
              ContentLayer(id: 'layer-auto-11', nodes: <SceneNode>[rect]),
            ],
          ),
        );
        addTearDown(controller.dispose);

        final actions = <ActionCommitted>[];
        final edits = <EditTextRequested>[];
        final actionSub = controller.actions.listen(actions.add);
        final editSub = controller.editTextRequests.listen(edits.add);
        addTearDown(actionSub.cancel);
        addTearDown(editSub.cancel);

        var notifications = 0;
        controller.addListener(() {
          notifications = notifications + 1;
        });

        controller.write<void>((writer) {
          writer.writeSelectionReplace(const <NodeId>{'node'});
          expect(() => controller.dispose(), throwsStateError);
          writer.writeSelectionTranslate(const Offset(8, 0));
        });
        await pumpEventQueue(times: 2);

        final moved =
            controller.snapshot.layers.last.nodes.single as RectNodeSnapshot;
        expect(moved.transform.tx, 28);
        expect(controller.selectedNodeIds, const <NodeId>{'node'});
        expect(notifications, 1);
        expect(actions, isEmpty);
        expect(edits, isEmpty);

        expect(
          () => controller.write<void>((writer) {
            writer.writeSelectionTranslate(const Offset(2, 0));
          }),
          returnsNormally,
        );
        await pumpEventQueue(times: 2);

        final movedAgain =
            controller.snapshot.layers.last.nodes.single as RectNodeSnapshot;
        expect(movedAgain.transform.tx, 30);
      },
    );
  });
}
