import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import '../test_support/interactive_controller_fixtures.dart';

void main() {
  group('SceneControllerInteractive unit', () {
    test('line tool supports drag flow and two-tap pending flow', () async {
      final controller = SceneControllerInteractive(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-auto-0'),
            ContentLayerSnapshot(id: 'layer-auto-1'),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final actions = <ActionCommitted>[];
      final sub = controller.actions.listen(actions.add);
      addTearDown(sub.cancel);

      controller.setMode(CanvasMode.draw);
      controller.setDrawTool(DrawTool.line);
      controller.setDragStartSlop(0.001);

      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(20, 20),
          timestampMs: 10,
          phase: CanvasPointerPhase.down,
        ),
      );
      expect(controller.hasActiveLinePreview, isFalse);
      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(50, 20),
          timestampMs: 11,
          phase: CanvasPointerPhase.move,
        ),
      );
      expect(controller.hasActiveLinePreview, isTrue);
      expect(controller.activeLinePreviewStart, const Offset(20, 20));
      expect(controller.activeLinePreviewEnd, const Offset(50, 20));
      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(60, 20),
          timestampMs: 12,
          phase: CanvasPointerPhase.up,
        ),
      );
      expect(controller.hasActiveLinePreview, isFalse);
      expect(controller.hasPendingLineStart, isFalse);

      final dragLine = controller.snapshot.layers
          .expand((layer) => layer.nodes)
          .whereType<LineNodeSnapshot>()
          .first;
      expect(dragLine.transform.tx, 40);
      expect(dragLine.transform.ty, 20);
      expect(dragLine.start, const Offset(-20, 0));
      expect(dragLine.end, const Offset(20, 0));
      expect(
        dragLine.transform.applyToPoint(dragLine.start),
        const Offset(20, 20),
      );
      expect(
        dragLine.transform.applyToPoint(dragLine.end),
        const Offset(60, 20),
      );

      controller.handlePointer(
        sampleInput(
          pointerId: 2,
          position: const Offset(100, 100),
          timestampMs: 30,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        sampleInput(
          pointerId: 2,
          position: const Offset(100, 100),
          timestampMs: 31,
          phase: CanvasPointerPhase.up,
        ),
      );
      expect(controller.hasPendingLineStart, isTrue);
      expect(controller.pendingLineTimestampMs, 31);

      controller.handlePointer(
        sampleInput(
          pointerId: 20,
          position: const Offset(220, 220),
          timestampMs: 32,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        sampleInput(
          pointerId: 20,
          position: const Offset(280, 220),
          timestampMs: 33,
          phase: CanvasPointerPhase.move,
        ),
      );
      expect(controller.hasActiveLinePreview, isTrue);
      expect(controller.activeLinePreviewStart, const Offset(220, 220));
      expect(controller.activeLinePreviewEnd, const Offset(280, 220));
      controller.handlePointer(
        sampleInput(
          pointerId: 20,
          position: const Offset(280, 220),
          timestampMs: 34,
          phase: CanvasPointerPhase.up,
        ),
      );
      controller.handlePointer(
        sampleInput(
          pointerId: 3,
          position: const Offset(130, 130),
          timestampMs: 40,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        sampleInput(
          pointerId: 3,
          position: const Offset(130, 130),
          timestampMs: 41,
          phase: CanvasPointerPhase.up,
        ),
      );
      controller.handlePointer(
        sampleInput(
          pointerId: 4,
          position: const Offset(150, 150),
          timestampMs: 50,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        sampleInput(
          pointerId: 4,
          position: const Offset(150, 150),
          timestampMs: 51,
          phase: CanvasPointerPhase.up,
        ),
      );
      controller.setDrawTool(DrawTool.pen);
      expect(controller.hasPendingLineStart, isFalse);

      await pumpEventQueue();
      expect(
        actions.where((a) => a.type == ActionType.drawLine).length,
        greaterThanOrEqualTo(2),
      );
      final lines = controller.snapshot.layers
          .expand((layer) => layer.nodes)
          .whereType<LineNodeSnapshot>();
      expect(
        lines.any((line) {
          final worldStart = line.transform.applyToPoint(line.start);
          final worldEnd = line.transform.applyToPoint(line.end);
          return worldStart == const Offset(130, 130) &&
              worldEnd == const Offset(150, 150);
        }),
        isTrue,
      );

      controller.setMode(CanvasMode.move);
      controller.toggleSelection('missing');
      controller.clearSelection();
      controller.selectAll(onlySelectable: false);
      expect(controller.selectedNodeIds, isNotEmpty);
    });

    test(
      'pen commit adds up-point and eraser single point hits stroke segment',
      () {
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
        controller.setDrawTool(DrawTool.pen);
        controller.penThickness = 2;
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
            position: const Offset(13, 10),
            timestampMs: 2,
            phase: CanvasPointerPhase.up,
          ),
        );

        final strokeSnap = controller.snapshot.layers
            .expand((layer) => layer.nodes)
            .whereType<StrokeNodeSnapshot>()
            .single;
        expect(strokeSnap.points.length, 2);

        controller.setDrawTool(DrawTool.eraser);
        controller.eraserThickness = 20;
        controller.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(11, 10),
            timestampMs: 3,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(11, 10),
            timestampMs: 4,
            phase: CanvasPointerPhase.up,
          ),
        );

        expect(
          controller.snapshot.layers
              .expand((layer) => layer.nodes)
              .whereType<StrokeNodeSnapshot>(),
          isEmpty,
        );
      },
    );
  });
}
