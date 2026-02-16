import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import '../test_support/interactive_controller_fixtures.dart';

void main() {
  group('SceneControllerInteractive unit', () {
    test('line preview does not mutate scene until pointer up commit', () {
      // INV:INV-ENG-INTERACTIVE-PREVIEW-COMMIT-ON-UP
      final controller = SceneControllerInteractive(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(),
            ContentLayerSnapshot(),
          ],
        ),
        dragStartSlop: 10,
      );
      addTearDown(controller.dispose);

      controller.setMode(CanvasMode.draw);
      controller.setDrawTool(DrawTool.line);

      final beforeNodeCount = controller.snapshot.layers[1].nodes.length;
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
          position: const Offset(30, 10),
          timestampMs: 2,
          phase: CanvasPointerPhase.move,
        ),
      );

      expect(controller.hasActiveLinePreview, isTrue);
      expect(controller.snapshot.layers[1].nodes.length, beforeNodeCount);

      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(30, 10),
          timestampMs: 3,
          phase: CanvasPointerPhase.up,
        ),
      );

      expect(controller.hasActiveLinePreview, isFalse);
      expect(controller.snapshot.layers[1].nodes.length, beforeNodeCount + 1);
    });
  });
}
