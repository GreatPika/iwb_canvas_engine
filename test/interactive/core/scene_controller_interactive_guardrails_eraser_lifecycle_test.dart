import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/scene.dart';

import '../test_support/interactive_controller_fixtures.dart';

void main() {
  group('SceneControllerInteractive unit', () {
    group('interactive hardening: eraser lifecycle', () {
      test('long eraser gesture does not throw', () {
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(id: 'layer-auto-0'),
              ContentLayerSnapshot(id: 'layer-auto-1'),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.eraser);

        expect(() {
          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(0, 0),
              timestampMs: 1,
              phase: CanvasPointerPhase.down,
            ),
          );
          for (var i = 1; i <= 20000; i++) {
            controller.handlePointer(
              sampleInput(
                pointerId: 1,
                position: Offset(i.toDouble(), 0),
                timestampMs: i + 1,
                phase: CanvasPointerPhase.move,
              ),
            );
          }
          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(20000, 0),
              timestampMs: 20002,
              phase: CanvasPointerPhase.up,
            ),
          );
        }, returnsNormally);
      });

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

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.eraser);
        controller.eraserThickness = 24;

        final actions = <ActionCommitted>[];
        final sub = controller.actions.listen(actions.add);
        addTearDown(sub.cancel);

        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(20, 50),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        for (var i = 21; i <= 9000; i++) {
          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: Offset(i.toDouble(), 50),
              timestampMs: i,
              phase: CanvasPointerPhase.move,
            ),
          );
        }
        controller.handlePointer(
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
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(id: 'layer-auto-2'),
              ContentLayerSnapshot(id: 'layer-auto-3'),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.eraser);

        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(0, 0),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        for (var i = 1; i <= 20000; i++) {
          controller.handlePointer(
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
    });
  });
}
