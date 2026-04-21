import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contract/pointer_input.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/interactive/scene_controller.dart';

import '../test_support/interactive_controller_fixtures.dart';

void main() {
  group('SceneController unit', () {
    group('interactive hardening: eraser lifecycle', () {
      test('long eraser gesture does not throw', () {
        final controller = SceneController(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(id: 'layer-auto-0'),
              ContentLayerSnapshot(id: 'layer-auto-1'),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.interaction.setMode(CanvasMode.draw);
        controller.interaction.setDrawTool(DrawTool.eraser);

        expect(() {
          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(0, 0),
              timestampMs: 1,
              phase: CanvasPointerPhase.down,
            ),
          );
          for (var i = 1; i <= 20000; i++) {
            controller.interaction.handlePointer(
              sampleInput(
                pointerId: 1,
                position: Offset(i.toDouble(), 0),
                timestampMs: i + 1,
                phase: CanvasPointerPhase.move,
              ),
            );
          }
          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(20000, 0),
              timestampMs: 20002,
              phase: CanvasPointerPhase.up,
            ),
          );
        }, returnsNormally);
      });

      test(
        'disposing owning eraser session clears draw gesture without commit',
        () async {
          final line = LineNode(
            id: 'eraser-line',
            start: const Offset(-30, 0),
            end: const Offset(30, 0),
            thickness: 4,
            color: const Color(0xFF000000),
          )..position = const Offset(80, 80);
          final controller = controllerFromScene(
            Scene(
              layers: <ContentLayer>[
                ContentLayer(id: 'layer-auto-2'),
                ContentLayer(id: 'layer-auto-3', nodes: <SceneNode>[line]),
              ],
            ),
          );
          addTearDown(controller.dispose);
          controller.interaction.setMode(CanvasMode.draw);
          controller.interaction.setDrawTool(DrawTool.eraser);
          controller.interaction.eraserThickness = 24;

          final actions = <ActionCommitted>[];
          final sub = controller.actions.listen(actions.add);
          addTearDown(sub.cancel);

          final session = sceneControllerViewRuntimeOf(controller)
              .createPointerSession(
                isMounted: () => true,
                hasLiveRawPointers: () => false,
              );

          session.handleRoutedSample(
            const PointerSample(
              pointerId: 1,
              position: Offset(80, 80),
              timestampMs: 1,
              phase: PointerPhase.down,
              kind: PointerDeviceKind.touch,
            ),
            shouldTrackSignals: false,
          );
          session.handleRoutedSample(
            const PointerSample(
              pointerId: 1,
              position: Offset(100, 80),
              timestampMs: 2,
              phase: PointerPhase.move,
              kind: PointerDeviceKind.touch,
            ),
            shouldTrackSignals: false,
          );

          session.dispose();
          await pumpEventQueue();

          expect(actions, isEmpty);
          expect(controller.snapshot.layers[1].nodes.single.id, 'eraser-line');
        },
      );

      test('long eraser gesture cancel does not mutate scene', () async {
        // INV:INV-ENG-INTERACTIVE-CANCEL-STATE-RESET
        final startLine = LineNode(
          id: 'cancel-line-start',
          start: const Offset(-12, 0),
          end: const Offset(12, 0),
          thickness: 2,
          color: const Color(0xFF000000),
        )..position = const Offset(20, 50);
        final endLine = LineNode(
          id: 'cancel-line-end',
          start: const Offset(-12, 0),
          end: const Offset(12, 0),
          thickness: 2,
          color: const Color(0xFF000000),
        )..position = const Offset(9000, 50);
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-4'),
              ContentLayer(
                id: 'layer-auto-5',
                nodes: <SceneNode>[startLine, endLine],
              ),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.interaction.setMode(CanvasMode.draw);
        controller.interaction.setDrawTool(DrawTool.eraser);
        controller.interaction.eraserThickness = 24;

        final actions = <ActionCommitted>[];
        final sub = controller.actions.listen(actions.add);
        addTearDown(sub.cancel);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(20, 50),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        for (var i = 21; i <= 9000; i++) {
          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 1,
              position: Offset(i.toDouble(), 50),
              timestampMs: i,
              phase: CanvasPointerPhase.move,
            ),
          );
        }
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(9000, 50),
            timestampMs: 9001,
            phase: CanvasPointerPhase.cancel,
          ),
        );

        await pumpEventQueue();
        final ids = <NodeId>{
          for (final layer in controller.snapshot.layers)
            for (final node in layer.nodes) node.id,
        };
        expect(ids.contains('cancel-line-start'), isTrue);
        expect(ids.contains('cancel-line-end'), isTrue);
        expect(
          actions.where((event) => event.type == ActionType.erase),
          isEmpty,
        );
      });

      test('eraser active buffer is capped during long move', () {
        // INV:INV-ENG-INTERACTIVE-GESTURE-BUFFER-SOFT-CAP
        final controller = SceneController(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(id: 'layer-auto-2'),
              ContentLayerSnapshot(id: 'layer-auto-3'),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.interaction.setMode(CanvasMode.draw);
        controller.interaction.setDrawTool(DrawTool.eraser);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(0, 0),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        for (var i = 1; i <= 20000; i++) {
          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 1,
              position: Offset(i.toDouble(), 0),
              timestampMs: i + 1,
              phase: CanvasPointerPhase.move,
            ),
          );
        }

        expect(
          activeEraserPointsLength(controller),
          lessThanOrEqualTo(interactiveEraserPointsSoftLimit),
        );
      });

      test(
        'eraser respects delete eligibility and forced reset clears gesture',
        () async {
          final lockedLine = LineNode(
            id: 'locked-line',
            start: const Offset(-12, 0),
            end: const Offset(12, 0),
            thickness: 2,
            color: const Color(0xFF000000),
            isDeletable: false,
          )..position = const Offset(20, 50);
          final freeLine = LineNode(
            id: 'free-line',
            start: const Offset(-12, 0),
            end: const Offset(12, 0),
            thickness: 2,
            color: const Color(0xFF000000),
          )..position = const Offset(60, 50);
          final controller = controllerFromScene(
            Scene(
              layers: <ContentLayer>[
                ContentLayer(id: 'layer-auto-10'),
                ContentLayer(
                  id: 'layer-auto-11',
                  nodes: <SceneNode>[lockedLine, freeLine],
                ),
              ],
            ),
          );
          addTearDown(controller.dispose);

          controller.interaction.setMode(CanvasMode.draw);
          controller.interaction.setDrawTool(DrawTool.eraser);
          controller.interaction.eraserThickness = 24;

          final actions = <ActionCommitted>[];
          final sub = controller.actions.listen(actions.add);
          addTearDown(sub.cancel);

          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(20, 50),
              timestampMs: 1,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(60, 50),
              timestampMs: 2,
              phase: CanvasPointerPhase.move,
            ),
          );
          controller.scene.setCameraOffset(const Offset(5, 0));

          expect(activeEraserPointsLength(controller), 0);

          expect(
            () => controller.interaction.handlePointer(
              const CanvasPointerInput(
                pointerId: 1,
                position: Offset(double.nan, 50),
                timestampMs: 3,
                phase: CanvasPointerPhase.up,
                kind: PointerDeviceKind.touch,
              ),
            ),
            returnsNormally,
          );

          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 2,
              position: const Offset(20, 50),
              timestampMs: 4,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 2,
              position: const Offset(60, 50),
              timestampMs: 5,
              phase: CanvasPointerPhase.move,
            ),
          );
          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 2,
              position: const Offset(60, 50),
              timestampMs: 6,
              phase: CanvasPointerPhase.up,
            ),
          );

          await pumpEventQueue();
          final ids = <NodeId>{
            for (final layer in controller.snapshot.layers)
              for (final node in layer.nodes) node.id,
          };
          expect(ids.contains('locked-line'), isTrue);
          expect(ids.contains('free-line'), isFalse);
          expect(
            actions.where((event) => event.type == ActionType.erase),
            hasLength(1),
          );
        },
      );
    });
  });
}
