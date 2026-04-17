import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contract/pointer_input.dart';
import 'package:iwb_canvas_engine/src/interactive/scene_controller.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/interactive_draw_eraser_engine.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/interactive_draw_gesture_session.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/interactive_draw_line_engine.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/interactive_draw_stroke_engine.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/interactive_draw_terminal_router.dart';

import '../test_support/interactive_controller_fixtures.dart';

void _ignoreEmitAction(
  ActionType type,
  List<NodeId> nodeIds,
  int timestampMs, {
  Map<String, Object?>? payload,
}) {}

void main() {
  group('SceneController unit', () {
    group('interactive hardening: line pending cancel semantics', () {
      test(
        'line preview starts after dragStartSlop and clears on cancel/tool/mode switch',
        () {
          // INV:INV-ENG-INTERACTIVE-CANCEL-STATE-RESET
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
              position: const Offset(18, 10),
              timestampMs: 2,
              phase: CanvasPointerPhase.move,
            ),
          );
          expect(controller.interaction.hasActiveLinePreview, isFalse);

          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(21, 10),
              timestampMs: 3,
              phase: CanvasPointerPhase.move,
            ),
          );
          expect(controller.interaction.hasActiveLinePreview, isTrue);

          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(21, 10),
              timestampMs: 4,
              phase: CanvasPointerPhase.cancel,
            ),
          );
          expect(controller.interaction.hasActiveLinePreview, isFalse);

          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 2,
              position: const Offset(30, 30),
              timestampMs: 5,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 2,
              position: const Offset(50, 30),
              timestampMs: 6,
              phase: CanvasPointerPhase.move,
            ),
          );
          expect(controller.interaction.hasActiveLinePreview, isTrue);
          controller.interaction.setDrawTool(DrawTool.pen);
          expect(controller.interaction.hasActiveLinePreview, isFalse);

          controller.interaction.setDrawTool(DrawTool.line);
          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 3,
              position: const Offset(30, 30),
              timestampMs: 7,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 3,
              position: const Offset(50, 30),
              timestampMs: 8,
              phase: CanvasPointerPhase.move,
            ),
          );
          expect(controller.interaction.hasActiveLinePreview, isTrue);
          controller.interaction.setMode(CanvasMode.move);
          expect(controller.interaction.hasActiveLinePreview, isFalse);
        },
      );

      test(
        'forced reset clears pending line and stray normalized terminal stays no-op',
        () async {
          // INV:INV-ENG-INTERACTIVE-CANCEL-STATE-RESET
          final controller = SceneController(
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

          controller.interaction.setMode(CanvasMode.draw);
          controller.interaction.setDrawTool(DrawTool.line);

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
              position: const Offset(10, 10),
              timestampMs: 2,
              phase: CanvasPointerPhase.up,
            ),
          );
          expect(controller.interaction.hasPendingLineStart, isTrue);

          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 2,
              position: const Offset(40, 20),
              timestampMs: 3,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.scene.setCameraOffset(const Offset(5, 5));

          expect(controller.interaction.hasPendingLineStart, isFalse);
          expect(controller.interaction.hasActiveLinePreview, isFalse);

          expect(
            () => controller.interaction.handlePointer(
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
          expect(controller.interaction.hasPendingLineStart, isFalse);
          expect(controller.interaction.hasActiveLinePreview, isFalse);
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
        controller.interaction.setDrawTool(DrawTool.line);

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
            position: const Offset(10, 10),
            timestampMs: 2,
            phase: CanvasPointerPhase.up,
          ),
        );
        expect(controller.interaction.hasPendingLineStart, isTrue);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(20, 20),
            timestampMs: 3,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(20, 20),
            timestampMs: 4,
            phase: CanvasPointerPhase.cancel,
          ),
        );

        expect(controller.interaction.hasPendingLineStart, isFalse);
        expect(controller.interaction.pendingLineStart, isNull);
        expect(controller.interaction.pendingLineTimestampMs, isNull);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 3,
            position: const Offset(30, 30),
            timestampMs: 5,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 3,
            position: const Offset(30, 30),
            timestampMs: 6,
            phase: CanvasPointerPhase.up,
          ),
        );
        expect(controller.interaction.hasPendingLineStart, isTrue);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 4,
            position: const Offset(50, 30),
            timestampMs: 7,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 4,
            position: const Offset(50, 30),
            timestampMs: 8,
            phase: CanvasPointerPhase.up,
          ),
        );

        expect(controller.interaction.hasPendingLineStart, isFalse);
        final lineCount = controller.snapshot.layers
            .expand((layer) => layer.nodes)
            .whereType<LineNodeSnapshot>()
            .length;
        expect(lineCount, 1);
      });

      test('line pending start survives invalid second tap input as no-op', () {
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
        controller.interaction.setDrawTool(DrawTool.line);

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
            position: const Offset(10, 10),
            timestampMs: 2,
            phase: CanvasPointerPhase.up,
          ),
        );
        expect(controller.interaction.hasPendingLineStart, isTrue);

        expect(
          () => controller.interaction.handlePointer(
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
        expect(controller.interaction.hasPendingLineStart, isTrue);
        expect(controller.interaction.pendingLineStart, const Offset(10, 10));
        expect(controller.interaction.pendingLineTimestampMs, 2);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 3,
            position: const Offset(40, 30),
            timestampMs: 4,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 3,
            position: const Offset(40, 30),
            timestampMs: 5,
            phase: CanvasPointerPhase.up,
          ),
        );

        expect(controller.interaction.hasPendingLineStart, isFalse);
        final lineCount = controller.snapshot.layers
            .expand((layer) => layer.nodes)
            .whereType<LineNodeSnapshot>()
            .length;
        expect(lineCount, 1);
      });

      test('detaching a session clears only its matching pending line', () {
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
        controller.interaction.setDrawTool(DrawTool.line);

        final session = sceneControllerViewRuntimeOf(controller)
            .createPointerSession(
              isMounted: () => true,
              hasLiveRawPointers: () => false,
            );

        session.handleRoutedSample(
          const PointerSample(
            pointerId: 10,
            position: Offset(40, 40),
            timestampMs: 1,
            phase: PointerPhase.down,
            kind: PointerDeviceKind.touch,
          ),
          shouldTrackSignals: false,
        );
        session.handleRoutedSample(
          const PointerSample(
            pointerId: 10,
            position: Offset(40, 40),
            timestampMs: 2,
            phase: PointerPhase.up,
            kind: PointerDeviceKind.touch,
          ),
          shouldTrackSignals: false,
        );

        expect(controller.interaction.pendingLineStart, const Offset(40, 40));
        session.dispose();

        expect(controller.interaction.hasPendingLineStart, isFalse);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 11,
            position: const Offset(70, 70),
            timestampMs: 3,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 11,
            position: const Offset(70, 70),
            timestampMs: 4,
            phase: CanvasPointerPhase.up,
          ),
        );
        expect(controller.interaction.pendingLineStart, const Offset(70, 70));

        final otherSession = sceneControllerViewRuntimeOf(controller)
            .createPointerSession(
              isMounted: () => true,
              hasLiveRawPointers: () => false,
            );
        otherSession.dispose();

        expect(controller.interaction.hasPendingLineStart, isTrue);
        expect(controller.interaction.pendingLineStart, const Offset(70, 70));
        expect(controller.interaction.pendingLineTimestampMs, 4);
      });

      test('public cancel does not clear session-owned pending line', () {
        final controller = SceneController(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(id: 'layer-auto-22'),
              ContentLayerSnapshot(id: 'layer-auto-23'),
            ],
          ),
        );
        addTearDown(controller.dispose);
        controller.interaction.setMode(CanvasMode.draw);
        controller.interaction.setDrawTool(DrawTool.line);

        final session = sceneControllerViewRuntimeOf(controller)
            .createPointerSession(
              isMounted: () => true,
              hasLiveRawPointers: () => false,
            );
        addTearDown(session.dispose);

        session.handleRoutedSample(
          const PointerSample(
            pointerId: 10,
            position: Offset(40, 40),
            timestampMs: 1,
            phase: PointerPhase.down,
            kind: PointerDeviceKind.touch,
          ),
          shouldTrackSignals: false,
        );
        session.handleRoutedSample(
          const PointerSample(
            pointerId: 10,
            position: Offset(40, 40),
            timestampMs: 2,
            phase: PointerPhase.up,
            kind: PointerDeviceKind.touch,
          ),
          shouldTrackSignals: false,
        );

        expect(controller.interaction.pendingLineStart, const Offset(40, 40));
        expect(controller.interaction.pendingLineTimestampMs, 2);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 11,
            position: const Offset(70, 70),
            timestampMs: 3,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 11,
            position: const Offset(70, 70),
            timestampMs: 4,
            phase: CanvasPointerPhase.cancel,
          ),
        );

        expect(controller.interaction.hasPendingLineStart, isTrue);
        expect(controller.interaction.pendingLineStart, const Offset(40, 40));
        expect(controller.interaction.pendingLineTimestampMs, 2);
      });

      test('session cancel does not clear public pending line', () {
        final controller = SceneController(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(id: 'layer-auto-24'),
              ContentLayerSnapshot(id: 'layer-auto-25'),
            ],
          ),
        );
        addTearDown(controller.dispose);
        controller.interaction.setMode(CanvasMode.draw);
        controller.interaction.setDrawTool(DrawTool.line);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(25, 25),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(25, 25),
            timestampMs: 2,
            phase: CanvasPointerPhase.up,
          ),
        );

        expect(controller.interaction.pendingLineStart, const Offset(25, 25));
        expect(controller.interaction.pendingLineTimestampMs, 2);

        final session = sceneControllerViewRuntimeOf(controller)
            .createPointerSession(
              isMounted: () => true,
              hasLiveRawPointers: () => false,
            );
        addTearDown(session.dispose);
        session.handleRoutedSample(
          const PointerSample(
            pointerId: 2,
            position: Offset(80, 80),
            timestampMs: 3,
            phase: PointerPhase.down,
            kind: PointerDeviceKind.touch,
          ),
          shouldTrackSignals: false,
        );
        session.handleRoutedSample(
          const PointerSample(
            pointerId: 2,
            position: Offset(80, 80),
            timestampMs: 4,
            phase: PointerPhase.cancel,
            kind: PointerDeviceKind.touch,
          ),
          shouldTrackSignals: false,
        );

        expect(controller.interaction.hasPendingLineStart, isTrue);
        expect(controller.interaction.pendingLineStart, const Offset(25, 25));
        expect(controller.interaction.pendingLineTimestampMs, 2);
      });

      test(
        'detaching active draw session keeps pending line owned by another source',
        () {
          final controller = SceneController(
            initialSnapshot: SceneSnapshot(
              layers: <ContentLayerSnapshot>[
                ContentLayerSnapshot(id: 'layer-auto-16'),
                ContentLayerSnapshot(id: 'layer-auto-17'),
              ],
            ),
            dragStartSlop: 0.001,
          );
          addTearDown(controller.dispose);
          controller.interaction.setMode(CanvasMode.draw);
          controller.interaction.setDrawTool(DrawTool.line);

          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(25, 25),
              timestampMs: 1,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(25, 25),
              timestampMs: 2,
              phase: CanvasPointerPhase.up,
            ),
          );
          expect(controller.interaction.pendingLineStart, const Offset(25, 25));

          final session = sceneControllerViewRuntimeOf(controller)
              .createPointerSession(
                isMounted: () => true,
                hasLiveRawPointers: () => false,
              );
          session.handleRoutedSample(
            const PointerSample(
              pointerId: 2,
              position: Offset(80, 80),
              timestampMs: 3,
              phase: PointerPhase.down,
              kind: PointerDeviceKind.touch,
            ),
            shouldTrackSignals: false,
          );
          expect(controller.interaction.hasActiveLinePreview, isFalse);
          session.dispose();

          expect(controller.interaction.hasActiveLinePreview, isFalse);
          expect(controller.interaction.hasPendingLineStart, isTrue);
          expect(controller.interaction.pendingLineStart, const Offset(25, 25));
          expect(controller.interaction.pendingLineTimestampMs, 2);
        },
      );

      test('terminal router handles missing captured style as no-op reset', () {
        final gestureSession = InteractiveDrawGestureSession();
        final lineEngine = InteractiveDrawLineEngine(
          callbacks: InteractiveDrawLineEngineCallbacks(
            onOverlayStateChanged: () {},
            emitAction: _ignoreEmitAction,
            commitDrawLineFromWorldSegment:
                ({
                  required Offset start,
                  required Offset end,
                  required double thickness,
                  required Color color,
                  required double opacity,
                }) => 'line',
          ),
        );
        final strokeEngine = InteractiveDrawStrokeEngine(
          callbacks: InteractiveDrawStrokeEngineCallbacks(
            onOverlayStateChanged: () {},
            emitAction: _ignoreEmitAction,
            commitDrawStroke:
                ({
                  required List<Offset> points,
                  required double thickness,
                  required Color color,
                  required double opacity,
                }) => 'stroke',
          ),
        );
        final eraserEngine = InteractiveDrawEraserEngine(
          callbacks: InteractiveDrawEraserEngineCallbacks(
            onOverlayStateChanged: () {},
            queryHitTestCandidates: (_) => const <Never>[],
            resolveSpatialCandidateSnapshot: (_) => null,
            commitEraseNodes: (_) => 0,
          ),
        );
        final router = InteractiveDrawTerminalRouter(
          gestureSession: gestureSession,
          lineEngine: lineEngine,
          strokeEngine: strokeEngine,
          eraserEngine: eraserEngine,
          emitAction: _ignoreEmitAction,
        );

        expect(
          () => router.handleUp(
            const PointerSample(
              pointerId: 1,
              position: Offset(10, 10),
              timestampMs: 1,
              phase: PointerPhase.up,
              kind: PointerDeviceKind.touch,
            ),
            const Offset(10, 10),
            dragStartSlop: 1,
          ),
          returnsNormally,
        );
        expect(gestureSession.downScene, isNull);
        expect(lineEngine.activeLinePreviewStart, isNull);
        expect(lineEngine.activeLinePreviewEnd, isNull);
      });

      test(
        'invalid second tap up preserves line commit semantics via last finite position',
        () async {
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
          controller.interaction.setDrawTool(DrawTool.line);

          final actions = <ActionCommitted>[];
          final actionSub = controller.actions.listen(actions.add);
          addTearDown(actionSub.cancel);

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
              position: const Offset(10, 10),
              timestampMs: 2,
              phase: CanvasPointerPhase.up,
            ),
          );
          expect(controller.interaction.hasPendingLineStart, isTrue);

          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 2,
              position: const Offset(40, 30),
              timestampMs: 3,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.interaction.handlePointer(
            const CanvasPointerInput(
              pointerId: 2,
              position: Offset(double.nan, 30),
              timestampMs: 4,
              phase: CanvasPointerPhase.up,
              kind: PointerDeviceKind.touch,
            ),
          );

          await pumpEventQueue();
          expect(controller.interaction.hasPendingLineStart, isFalse);
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
