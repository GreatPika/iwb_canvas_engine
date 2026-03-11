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
                ContentLayerSnapshot(id: 'layer-auto-0'),
                ContentLayerSnapshot(id: 'layer-auto-1'),
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

      test(
        'forced reset clears pending line and stray normalized terminal stays no-op',
        () async {
          // INV:INV-ENG-INTERACTIVE-CANCEL-STATE-RESET
          final controller = SceneControllerInteractive(
            initialSnapshot: SceneSnapshot(
              layers: <ContentLayerSnapshot>[
                ContentLayerSnapshot(id: 'layer-auto-10'),
                ContentLayerSnapshot(id: 'layer-auto-11'),
              ],
            ),
          );
          addTearDown(controller.dispose);

          final actions = <ActionCommitted>[];
          final sub = controller.actions.listen(actions.add);
          addTearDown(sub.cancel);

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
              position: const Offset(40, 20),
              timestampMs: 3,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.setCameraOffset(const Offset(5, 5));

          expect(controller.hasPendingLineStart, isFalse);
          expect(controller.hasActiveLinePreview, isFalse);

          expect(
            () => controller.handlePointer(
              const CanvasPointerInput(
                pointerId: 2,
                position: Offset(double.nan, 20),
                timestampMs: 4,
                phase: CanvasPointerPhase.up,
                kind: PointerDeviceKind.touch,
              ),
            ),
            returnsNormally,
          );

          await pumpEventQueue();
          expect(controller.hasPendingLineStart, isFalse);
          expect(controller.hasActiveLinePreview, isFalse);
          expect(
            actions.where((event) => event.type == ActionType.drawLine),
            isEmpty,
          );
          expect(
            controller.snapshot.layers
                .expand((layer) => layer.nodes)
                .whereType<LineNodeSnapshot>(),
            isEmpty,
          );
        },
      );

      test('line pending start is cleared on pointer cancel', () {
        // INV:INV-ENG-INTERACTIVE-CANCEL-STATE-RESET
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
              ContentLayerSnapshot(id: 'layer-auto-4'),
              ContentLayerSnapshot(id: 'layer-auto-5'),
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

      test(
        'invalid second tap up preserves line commit semantics via last finite position',
        () async {
          final controller = SceneControllerInteractive(
            initialSnapshot: SceneSnapshot(
              layers: <ContentLayerSnapshot>[
                ContentLayerSnapshot(id: 'layer-auto-6'),
                ContentLayerSnapshot(id: 'layer-auto-7'),
              ],
            ),
          );
          addTearDown(controller.dispose);

          controller.setMode(CanvasMode.draw);
          controller.setDrawTool(DrawTool.line);

          final actions = <ActionCommitted>[];
          final actionSub = controller.actions.listen(actions.add);
          addTearDown(actionSub.cancel);

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
              position: const Offset(40, 30),
              timestampMs: 3,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.handlePointer(
            const CanvasPointerInput(
              pointerId: 2,
              position: Offset(double.nan, 30),
              timestampMs: 4,
              phase: CanvasPointerPhase.up,
              kind: PointerDeviceKind.touch,
            ),
          );

          await pumpEventQueue();
          expect(controller.hasPendingLineStart, isFalse);
          expect(actions, hasLength(1));
          expect(actions.single.type, ActionType.drawLine);
          expect(actions.single.timestampMs, 4);

          final lineNodes = controller.snapshot.layers
              .expand((layer) => layer.nodes)
              .whereType<LineNodeSnapshot>()
              .toList(growable: false);
          expect(lineNodes, hasLength(1));
          final line = lineNodes.single;
          expect(line.transform.applyToPoint(line.start), const Offset(10, 10));
          expect(line.transform.applyToPoint(line.end), const Offset(40, 30));
        },
      );
    });
  });
}
