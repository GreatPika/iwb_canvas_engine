import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/scene.dart';

import '../test_support/interactive_controller_fixtures.dart';

void main() {
  group('SceneControllerInteractive unit', () {
    test('eraser removes line and stroke nodes on pointer up', () {
      final line = LineNode(
        id: 'line',
        start: const Offset(-20, 0),
        end: const Offset(20, 0),
        thickness: 2,
        color: const Color(0xFF000000),
      )..position = const Offset(120, 120);
      final stroke = StrokeNode(
        id: 'stroke',
        points: const <Offset>[Offset.zero],
        thickness: 2,
        color: const Color(0xFF000000),
      )..position = const Offset(170, 120);
      final controller = controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(id: 'layer-auto-0'),
            ContentLayer(id: 'layer-auto-1', nodes: <SceneNode>[line, stroke]),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.setMode(CanvasMode.draw);
      controller.setDrawTool(DrawTool.eraser);
      controller.eraserThickness = 30;

      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(120, 120),
          timestampMs: 10,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(120, 120),
          timestampMs: 11,
          phase: CanvasPointerPhase.up,
        ),
      );

      controller.handlePointer(
        sampleInput(
          pointerId: 2,
          position: const Offset(170, 120),
          timestampMs: 20,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        sampleInput(
          pointerId: 2,
          position: const Offset(176, 120),
          timestampMs: 21,
          phase: CanvasPointerPhase.up,
        ),
      );

      final ids = <NodeId>{
        for (final layer in controller.snapshot.layers)
          for (final node in layer.nodes) node.id,
      };
      expect(ids.contains('line'), isFalse);
      expect(ids.contains('stroke'), isFalse);

      controller.handlePointer(
        sampleInput(
          pointerId: 3,
          position: const Offset(10, 10),
          timestampMs: 30,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        sampleInput(
          pointerId: 3,
          position: const Offset(10, 10),
          timestampMs: 31,
          phase: CanvasPointerPhase.cancel,
        ),
      );
    });

    test('hit-test marquee and eraser keep foreground behavior', () {
      final backgroundRect = RectNode(
        id: 'bg',
        size: const Size(200, 200),
        isSelectable: true,
      )..position = const Offset(100, 100);
      final foregroundRect = RectNode(id: 'fg', size: const Size(40, 40))
        ..position = const Offset(100, 100);
      final foregroundLine = LineNode(
        id: 'line',
        start: const Offset(-15, 0),
        end: const Offset(15, 0),
        thickness: 2,
        color: const Color(0xFF000000),
      )..position = const Offset(160, 100);
      final controller = controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(
              id: 'layer-auto-2',
              nodes: <SceneNode>[backgroundRect],
            ),
            ContentLayer(
              id: 'layer-auto-3',
              nodes: <SceneNode>[foregroundRect, foregroundLine],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(100, 100),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(100, 100),
          timestampMs: 2,
          phase: CanvasPointerPhase.up,
        ),
      );
      expect(controller.selectedNodeIds, const <NodeId>{'fg'});

      controller.handlePointer(
        sampleInput(
          pointerId: 2,
          position: const Offset(80, 80),
          timestampMs: 3,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        sampleInput(
          pointerId: 2,
          position: const Offset(120, 120),
          timestampMs: 4,
          phase: CanvasPointerPhase.move,
        ),
      );
      controller.handlePointer(
        sampleInput(
          pointerId: 2,
          position: const Offset(120, 120),
          timestampMs: 5,
          phase: CanvasPointerPhase.up,
        ),
      );
      expect(controller.selectedNodeIds, const <NodeId>{'fg'});

      controller.setMode(CanvasMode.draw);
      controller.setDrawTool(DrawTool.eraser);
      controller.eraserThickness = 20;
      controller.handlePointer(
        sampleInput(
          pointerId: 3,
          position: const Offset(160, 100),
          timestampMs: 6,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        sampleInput(
          pointerId: 3,
          position: const Offset(160, 100),
          timestampMs: 7,
          phase: CanvasPointerPhase.up,
        ),
      );

      final ids = <NodeId>{
        for (final layer in controller.snapshot.layers)
          for (final node in layer.nodes) node.id,
      };
      expect(ids.contains('line'), isFalse);
      expect(ids.contains('bg'), isTrue);
      expect(ids.contains('fg'), isTrue);
    });
  });
}
