import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import '../test_support/interactive_controller_fixtures.dart';

void main() {
  group('SceneController unit', () {
    test('line preview does not mutate scene until pointer up commit', () {
      // INV:INV-ENG-INTERACTIVE-PREVIEW-COMMIT-ON-UP
      final controller = SceneController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-auto-0'),
            ContentLayerSnapshot(id: 'layer-auto-1'),
          ],
        ),
        dragStartSlop: 10,
      );
      addTearDown(controller.dispose);

      controller.interaction.setMode(CanvasMode.draw);
      controller.interaction.setDrawTool(DrawTool.line);

      final beforeNodeCount = controller.snapshot.layers[1].nodes.length;
      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(10, 10),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(30, 10),
          timestampMs: 2,
          phase: CanvasPointerPhase.move,
        ),
      );

      expect(controller.interaction.hasActiveLinePreview, isTrue);
      expect(controller.snapshot.layers[1].nodes.length, beforeNodeCount);

      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(30, 10),
          timestampMs: 3,
          phase: CanvasPointerPhase.up,
        ),
      );

      expect(controller.interaction.hasActiveLinePreview, isFalse);
      expect(controller.snapshot.layers[1].nodes.length, beforeNodeCount + 1);
    });
  });
}
