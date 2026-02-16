import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import '../test_support/interactive_controller_fixtures.dart';

void main() {
  group('SceneControllerInteractive unit', () {
    group('interactive hardening: line pending cancel semantics', () {
      test(
        'line preview starts after dragStartSlop and clears on cancel/tool/mode switch',
        () {
          // INV:INV-ENG-INTERACTIVE-CANCEL-STATE-RESET
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
              position: const Offset(18, 10),
              timestampMs: 2,
              phase: CanvasPointerPhase.move,
            ),
          );
          expect(controller.hasActiveLinePreview, isFalse);

          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(21, 10),
              timestampMs: 3,
              phase: CanvasPointerPhase.move,
            ),
          );
          expect(controller.hasActiveLinePreview, isTrue);

          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(21, 10),
              timestampMs: 4,
              phase: CanvasPointerPhase.cancel,
            ),
          );
          expect(controller.hasActiveLinePreview, isFalse);

          controller.handlePointer(
            sampleInput(
              pointerId: 2,
              position: const Offset(30, 30),
              timestampMs: 5,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.handlePointer(
            sampleInput(
              pointerId: 2,
              position: const Offset(50, 30),
              timestampMs: 6,
              phase: CanvasPointerPhase.move,
            ),
          );
          expect(controller.hasActiveLinePreview, isTrue);
          controller.setDrawTool(DrawTool.pen);
          expect(controller.hasActiveLinePreview, isFalse);

          controller.setDrawTool(DrawTool.line);
          controller.handlePointer(
            sampleInput(
              pointerId: 3,
              position: const Offset(30, 30),
              timestampMs: 7,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.handlePointer(
            sampleInput(
              pointerId: 3,
              position: const Offset(50, 30),
              timestampMs: 8,
              phase: CanvasPointerPhase.move,
            ),
          );
          expect(controller.hasActiveLinePreview, isTrue);
          controller.setMode(CanvasMode.move);
          expect(controller.hasActiveLinePreview, isFalse);
        },
      );

      test('line pending start is cleared on pointer cancel', () {
        // INV:INV-ENG-INTERACTIVE-CANCEL-STATE-RESET
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(),
              ContentLayerSnapshot(),
            ],
          ),
        );
        addTearDown(controller.dispose);

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

        controller.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(20, 20),
            timestampMs: 3,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(20, 20),
            timestampMs: 4,
            phase: CanvasPointerPhase.cancel,
          ),
        );

        expect(controller.hasPendingLineStart, isFalse);
        expect(controller.pendingLineStart, isNull);
        expect(controller.pendingLineTimestampMs, isNull);

        controller.handlePointer(
          sampleInput(
            pointerId: 3,
            position: const Offset(30, 30),
            timestampMs: 5,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          sampleInput(
            pointerId: 3,
            position: const Offset(30, 30),
            timestampMs: 6,
            phase: CanvasPointerPhase.up,
          ),
        );
        expect(controller.hasPendingLineStart, isTrue);

        controller.handlePointer(
          sampleInput(
            pointerId: 4,
            position: const Offset(50, 30),
            timestampMs: 7,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          sampleInput(
            pointerId: 4,
            position: const Offset(50, 30),
            timestampMs: 8,
            phase: CanvasPointerPhase.up,
          ),
        );

        expect(controller.hasPendingLineStart, isFalse);
        final lineCount = controller.snapshot.layers
            .expand((layer) => layer.nodes)
            .whereType<LineNodeSnapshot>()
            .length;
        expect(lineCount, 1);
      });

      test('line pending start survives invalid second tap input as no-op', () {
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(),
              ContentLayerSnapshot(),
            ],
          ),
        );
        addTearDown(controller.dispose);

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

        expect(
          () => controller.handlePointer(
            const CanvasPointerInput(
              pointerId: 2,
              position: Offset(double.nan, 20),
              phase: CanvasPointerPhase.down,
              kind: PointerDeviceKind.touch,
              timestampMs: 3,
            ),
          ),
          returnsNormally,
        );
        expect(controller.hasPendingLineStart, isTrue);
        expect(controller.pendingLineStart, const Offset(10, 10));
        expect(controller.pendingLineTimestampMs, 2);

        controller.handlePointer(
          sampleInput(
            pointerId: 3,
            position: const Offset(40, 30),
            timestampMs: 4,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          sampleInput(
            pointerId: 3,
            position: const Offset(40, 30),
            timestampMs: 5,
            phase: CanvasPointerPhase.up,
          ),
        );

        expect(controller.hasPendingLineStart, isFalse);
        final lineCount = controller.snapshot.layers
            .expand((layer) => layer.nodes)
            .whereType<LineNodeSnapshot>()
            .length;
        expect(lineCount, 1);
      });
    });
  });
}
