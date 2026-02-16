import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import '../test_support/interactive_controller_fixtures.dart';

void main() {
  group('SceneControllerInteractive unit', () {
    group('interactive hardening: long gesture guardrails (stroke)', () {
      test('pen commit caps very long stroke and preserves endpoints', () {
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
        controller.setDrawTool(DrawTool.pen);
        controller.penThickness = 2;

        const totalRawPoints = 20050;
        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(0, 0),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        for (var i = 1; i < totalRawPoints - 1; i++) {
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
            position: Offset((totalRawPoints - 1).toDouble(), 0),
            timestampMs: totalRawPoints + 1,
            phase: CanvasPointerPhase.up,
          ),
        );

        final strokeSnap = controller.snapshot.layers
            .expand((layer) => layer.nodes)
            .whereType<StrokeNodeSnapshot>()
            .single;
        expect(strokeSnap.points.length, 20000);
        expect(strokeSnap.points.first, const Offset(0, 0));
        expect(
          strokeSnap.points.last,
          Offset((totalRawPoints - 1).toDouble(), 0),
        );
      });

      test('pen preview buffer is soft-capped during long move', () {
        // INV:INV-ENG-INTERACTIVE-GESTURE-BUFFER-SOFT-CAP
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
        controller.setDrawTool(DrawTool.pen);

        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(0, 0),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );

        for (var i = 1; i <= 26000; i++) {
          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: Offset(i.toDouble(), 0),
              timestampMs: i + 1,
              phase: CanvasPointerPhase.move,
            ),
          );
        }

        expect(controller.hasActiveStrokePreview, isTrue);
        expect(
          controller.activeStrokePreviewPoints.length,
          lessThanOrEqualTo(interactiveStrokePointsSoftLimit),
        );
      });

      test('soft-capped stroke preview keeps endpoints after pruning', () {
        // INV:INV-ENG-INTERACTIVE-GESTURE-BUFFER-SOFT-CAP
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
        controller.setDrawTool(DrawTool.pen);

        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(0, 0),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );

        const latestPoint = Offset(26000, 0);
        for (var i = 1; i <= latestPoint.dx; i++) {
          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: Offset(i.toDouble(), 0),
              timestampMs: i + 1,
              phase: CanvasPointerPhase.move,
            ),
          );
        }

        expect(controller.activeStrokePreviewPoints, isNotEmpty);
        expect(controller.activeStrokePreviewPoints.first, const Offset(0, 0));
        expect(controller.activeStrokePreviewPoints.last, latestPoint);
      });

      test(
        'highlighter long preview and commit keep soft-limit and endpoints',
        () async {
          // INV:INV-ENG-INTERACTIVE-GESTURE-BUFFER-SOFT-CAP
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
          controller.setDrawTool(DrawTool.highlighter);
          controller.highlighterThickness = 7;
          controller.highlighterOpacity = 0.35;

          final actions = <ActionCommitted>[];
          final sub = controller.actions.listen(actions.add);
          addTearDown(sub.cancel);

          const latestPoint = Offset(26000, 0);
          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(0, 0),
              timestampMs: 1,
              phase: CanvasPointerPhase.down,
            ),
          );
          for (var i = 1; i <= latestPoint.dx; i++) {
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
            controller.activeStrokePreviewPoints.length,
            lessThanOrEqualTo(interactiveStrokePointsSoftLimit),
          );
          expect(
            controller.activeStrokePreviewPoints.first,
            const Offset(0, 0),
          );
          expect(controller.activeStrokePreviewPoints.last, latestPoint);

          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: latestPoint,
              timestampMs: 26002,
              phase: CanvasPointerPhase.up,
            ),
          );
          await pumpEventQueue();

          expect(
            actions.where((a) => a.type == ActionType.drawHighlighter),
            hasLength(1),
          );
          final strokeSnap = controller.snapshot.layers
              .expand((layer) => layer.nodes)
              .whereType<StrokeNodeSnapshot>()
              .single;
          expect(strokeSnap.points.first, const Offset(0, 0));
          expect(strokeSnap.points.last, latestPoint);
          expect(strokeSnap.points.length, lessThanOrEqualTo(20000));
          expect(strokeSnap.opacity, closeTo(0.35, 1e-6));
        },
      );

      test('invalid soft-limit config throws ArgumentError', () {
        // INV:INV-ENG-INTERACTIVE-GESTURE-BUFFER-SOFT-CAP
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(),
              ContentLayerSnapshot(),
            ],
          ),
        );
        addTearDown(controller.dispose);

        final points = <Offset>[const Offset(0, 0), const Offset(1, 0)];

        expect(
          () => enforceGestureBufferSoftLimitForTest(
            controller,
            points: points,
            softLimit: 10,
            trimTo: 1,
          ),
          throwsArgumentError,
        );
        expect(
          () => enforceGestureBufferSoftLimitForTest(
            controller,
            points: points,
            softLimit: 5,
            trimTo: 5,
          ),
          throwsArgumentError,
        );
        expect(
          () => enforceGestureBufferSoftLimitForTest(
            controller,
            points: points,
            softLimit: 1,
            trimTo: 1,
          ),
          throwsArgumentError,
        );
      });
    });

    test('stroke preview is available during drag and clears on up', () {
      // INV:INV-ENG-INTERACTIVE-PREVIEW-COMMIT-ON-UP
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
      controller.setDrawTool(DrawTool.highlighter);
      controller.highlighterThickness = 8;
      controller.highlighterOpacity = 0.3;

      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(10, 10),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );
      expect(controller.hasActiveStrokePreview, isTrue);
      expect(controller.activeStrokePreviewPoints, const <Offset>[
        Offset(10, 10),
      ]);
      expect(controller.activeStrokePreviewThickness, 8);
      expect(controller.activeStrokePreviewOpacity, 0.3);

      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(14, 10),
          timestampMs: 2,
          phase: CanvasPointerPhase.move,
        ),
      );
      expect(controller.activeStrokePreviewPoints.length, 2);

      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(14, 10),
          timestampMs: 3,
          phase: CanvasPointerPhase.up,
        ),
      );
      expect(controller.hasActiveStrokePreview, isFalse);
      expect(controller.activeStrokePreviewPoints, isEmpty);
    });
  });
}
