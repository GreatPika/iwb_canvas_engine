import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

import '../test_support/interactive_controller_fixtures.dart';

void main() {
  group('SceneController unit', () {
    group('interactive hardening: long gesture guardrails (stroke)', () {
      test('pen commit caps very long stroke and preserves endpoints', () {
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
        controller.interaction.setDrawTool(DrawTool.pen);
        controller.interaction.penThickness = 2;

        const totalRawPoints = 20050;
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(0, 0),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        for (var i = 1; i < totalRawPoints - 1; i++) {
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
        controller.interaction.setDrawTool(DrawTool.pen);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(0, 0),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );

        for (var i = 1; i <= 26000; i++) {
          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 1,
              position: Offset(i.toDouble(), 0),
              timestampMs: i + 1,
              phase: CanvasPointerPhase.move,
            ),
          );
        }

        expect(controller.interaction.hasActiveStrokePreview, isTrue);
        expect(
          controller.interaction.activeStrokePreviewPoints.length,
          lessThanOrEqualTo(interactiveStrokePointsSoftLimit),
        );
      });

      test('soft-capped stroke preview keeps endpoints after pruning', () {
        // INV:INV-ENG-INTERACTIVE-GESTURE-BUFFER-SOFT-CAP
        final controller = SceneController(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(id: 'layer-auto-4'),
              ContentLayerSnapshot(id: 'layer-auto-5'),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.interaction.setMode(CanvasMode.draw);
        controller.interaction.setDrawTool(DrawTool.pen);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(0, 0),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );

        const latestPoint = Offset(26000, 0);
        for (var i = 1; i <= latestPoint.dx; i++) {
          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 1,
              position: Offset(i.toDouble(), 0),
              timestampMs: i + 1,
              phase: CanvasPointerPhase.move,
            ),
          );
        }

        expect(controller.interaction.activeStrokePreviewPoints, isNotEmpty);
        expect(
          controller.interaction.activeStrokePreviewPoints.first,
          const Offset(0, 0),
        );
        expect(
          controller.interaction.activeStrokePreviewPoints.last,
          latestPoint,
        );
      });

      test(
        'highlighter long preview and commit keep soft-limit and endpoints',
        () async {
          // INV:INV-ENG-INTERACTIVE-GESTURE-BUFFER-SOFT-CAP
          final controller = SceneController(
            initialSnapshot: SceneSnapshot(
              layers: <ContentLayerSnapshot>[
                ContentLayerSnapshot(id: 'layer-auto-6'),
                ContentLayerSnapshot(id: 'layer-auto-7'),
              ],
            ),
          );
          addTearDown(controller.dispose);

          controller.interaction.setMode(CanvasMode.draw);
          controller.interaction.setDrawTool(DrawTool.highlighter);
          controller.interaction.highlighterThickness = 7;
          controller.interaction.highlighterOpacity = 0.35;

          final actions = <ActionCommitted>[];
          final sub = controller.actions.listen(actions.add);
          addTearDown(sub.cancel);

          const latestPoint = Offset(26000, 0);
          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(0, 0),
              timestampMs: 1,
              phase: CanvasPointerPhase.down,
            ),
          );
          for (var i = 1; i <= latestPoint.dx; i++) {
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
            controller.interaction.activeStrokePreviewPoints.length,
            lessThanOrEqualTo(interactiveStrokePointsSoftLimit),
          );
          expect(
            controller.interaction.activeStrokePreviewPoints.first,
            const Offset(0, 0),
          );
          expect(
            controller.interaction.activeStrokePreviewPoints.last,
            latestPoint,
          );

          controller.interaction.handlePointer(
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
        final controller = SceneController(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(id: 'layer-auto-8'),
              ContentLayerSnapshot(id: 'layer-auto-9'),
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
      final controller = SceneController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-auto-10'),
            ContentLayerSnapshot(id: 'layer-auto-11'),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.interaction.setMode(CanvasMode.draw);
      controller.interaction.setDrawTool(DrawTool.highlighter);
      controller.interaction.highlighterThickness = 8;
      controller.interaction.highlighterOpacity = 0.3;

      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(10, 10),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );
      expect(controller.interaction.hasActiveStrokePreview, isTrue);
      expect(controller.interaction.activeStrokePreviewPoints, const <Offset>[
        Offset(10, 10),
      ]);
      expect(controller.interaction.activeStrokePreviewThickness, 8);
      expect(controller.interaction.activeStrokePreviewOpacity, 0.3);

      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(14, 10),
          timestampMs: 2,
          phase: CanvasPointerPhase.move,
        ),
      );
      expect(controller.interaction.activeStrokePreviewPoints.length, 2);

      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(14, 10),
          timestampMs: 3,
          phase: CanvasPointerPhase.up,
        ),
      );
      expect(controller.interaction.hasActiveStrokePreview, isFalse);
      expect(controller.interaction.activeStrokePreviewPoints, isEmpty);
    });
  });
}
