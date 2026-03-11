import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/scene.dart';

import '../test_support/interactive_controller_fixtures.dart';

void main() {
  group('SceneControllerInteractive unit', () {
    group('single-active-pointer policy', () {
      test(
        'move mode ignores parallel pointer ids until active pointer ends',
        () {
          // INV:INV-ENG-INTERACTIVE-SINGLE-ACTIVE-POINTER
          final rect = RectNode(id: 'node', size: const Size(30, 20))
            ..position = const Offset(60, 60);
          final controller = controllerFromScene(
            Scene(
              layers: <ContentLayer>[
                ContentLayer(id: 'layer-auto-4'),
                ContentLayer(id: 'layer-auto-5', nodes: <SceneNode>[rect]),
              ],
            ),
          );
          addTearDown(controller.dispose);
          controller.setSelection(const <NodeId>{'node'});

          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(60, 60),
              timestampMs: 1,
              phase: CanvasPointerPhase.down,
            ),
          );

          controller.handlePointer(
            sampleInput(
              pointerId: 2,
              position: const Offset(60, 60),
              timestampMs: 2,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.handlePointer(
            sampleInput(
              pointerId: 2,
              position: const Offset(120, 60),
              timestampMs: 3,
              phase: CanvasPointerPhase.move,
            ),
          );
          controller.handlePointer(
            sampleInput(
              pointerId: 2,
              position: const Offset(120, 60),
              timestampMs: 4,
              phase: CanvasPointerPhase.up,
            ),
          );

          final afterParallelPointer =
              nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
          expect(afterParallelPointer.transform.tx, closeTo(60, 1e-6));
          expect(afterParallelPointer.transform.ty, closeTo(60, 1e-6));

          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(90, 60),
              timestampMs: 5,
              phase: CanvasPointerPhase.move,
            ),
          );
          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(90, 60),
              timestampMs: 6,
              phase: CanvasPointerPhase.up,
            ),
          );

          final afterPrimaryPointer =
              nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
          expect(afterPrimaryPointer.transform.tx, closeTo(90, 1e-6));
          expect(afterPrimaryPointer.transform.ty, closeTo(60, 1e-6));
        },
      );

      test('move mode releases active-pointer lock after cancel', () {
        // INV:INV-ENG-INTERACTIVE-SINGLE-ACTIVE-POINTER
        final rect = RectNode(id: 'node', size: const Size(30, 20))
          ..position = const Offset(60, 60);
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-6'),
              ContentLayer(id: 'layer-auto-7', nodes: <SceneNode>[rect]),
            ],
          ),
        );
        addTearDown(controller.dispose);
        controller.setSelection(const <NodeId>{'node'});

        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(60, 60),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(100, 60),
            timestampMs: 2,
            phase: CanvasPointerPhase.move,
          ),
        );

        controller.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(120, 60),
            timestampMs: 3,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(150, 60),
            timestampMs: 4,
            phase: CanvasPointerPhase.move,
          ),
        );
        controller.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(150, 60),
            timestampMs: 5,
            phase: CanvasPointerPhase.up,
          ),
        );

        final beforeCancel =
            nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
        expect(beforeCancel.transform.tx, closeTo(60, 1e-6));
        expect(beforeCancel.transform.ty, closeTo(60, 1e-6));

        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(100, 60),
            timestampMs: 6,
            phase: CanvasPointerPhase.cancel,
          ),
        );

        controller.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(60, 60),
            timestampMs: 7,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(90, 60),
            timestampMs: 8,
            phase: CanvasPointerPhase.move,
          ),
        );
        controller.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(90, 60),
            timestampMs: 9,
            phase: CanvasPointerPhase.up,
          ),
        );

        final afterCancelRecovery =
            nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
        expect(afterCancelRecovery.transform.tx, closeTo(90, 1e-6));
        expect(afterCancelRecovery.transform.ty, closeTo(60, 1e-6));
      });

      test('move mode rejects external selection mutations while active', () {
        final rect = RectNode(id: 'node', size: const Size(30, 20))
          ..position = const Offset(60, 60);
        final other = RectNode(id: 'other', size: const Size(30, 20))
          ..position = const Offset(120, 60);
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-30'),
              ContentLayer(
                id: 'layer-auto-31',
                nodes: <SceneNode>[rect, other],
              ),
            ],
          ),
        );
        addTearDown(controller.dispose);
        controller.setSelection(const <NodeId>{'node'});

        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(60, 60),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );

        expect(
          () => controller.setSelection(const <NodeId>{'other'}),
          throwsStateError,
        );
        expect(() => controller.toggleSelection('other'), throwsStateError);
        expect(() => controller.clearSelection(), throwsStateError);
        expect(() => controller.selectAll(), throwsStateError);

        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(60, 60),
            timestampMs: 2,
            phase: CanvasPointerPhase.cancel,
          ),
        );

        controller.setSelection(const <NodeId>{'other'});
        expect(controller.selectedNodeIds, const <NodeId>{'other'});
      });

      test(
        'draw line ignores parallel pointer ids and accepts new pointer after up',
        () async {
          // INV:INV-ENG-INTERACTIVE-SINGLE-ACTIVE-POINTER
          final controller = SceneControllerInteractive(
            initialSnapshot: SceneSnapshot(
              layers: <ContentLayerSnapshot>[
                ContentLayerSnapshot(id: 'layer-auto-0'),
                ContentLayerSnapshot(id: 'layer-auto-1'),
              ],
            ),
            dragStartSlop: 0.001,
          );
          addTearDown(controller.dispose);
          controller.setMode(CanvasMode.draw);
          controller.setDrawTool(DrawTool.line);

          final actions = <ActionCommitted>[];
          final sub = controller.actions.listen(actions.add);
          addTearDown(sub.cancel);

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
              pointerId: 2,
              position: const Offset(50, 10),
              timestampMs: 2,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.handlePointer(
            sampleInput(
              pointerId: 2,
              position: const Offset(80, 10),
              timestampMs: 3,
              phase: CanvasPointerPhase.move,
            ),
          );
          controller.handlePointer(
            sampleInput(
              pointerId: 2,
              position: const Offset(80, 10),
              timestampMs: 4,
              phase: CanvasPointerPhase.up,
            ),
          );
          expect(controller.hasActiveLinePreview, isFalse);

          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(30, 10),
              timestampMs: 5,
              phase: CanvasPointerPhase.move,
            ),
          );
          expect(controller.hasActiveLinePreview, isTrue);
          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(30, 10),
              timestampMs: 6,
              phase: CanvasPointerPhase.up,
            ),
          );

          await pumpEventQueue();
          expect(
            actions.where((a) => a.type == ActionType.drawLine),
            hasLength(1),
          );

          final lineNodes = controller.snapshot.layers
              .expand((layer) => layer.nodes)
              .whereType<LineNodeSnapshot>()
              .toList(growable: false);
          expect(lineNodes, hasLength(1));
          final committed = lineNodes.single;
          expect(
            committed.transform.applyToPoint(committed.start),
            const Offset(10, 10),
          );
          expect(
            committed.transform.applyToPoint(committed.end),
            const Offset(30, 10),
          );

          controller.handlePointer(
            sampleInput(
              pointerId: 2,
              position: const Offset(100, 100),
              timestampMs: 7,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.handlePointer(
            sampleInput(
              pointerId: 2,
              position: const Offset(100, 100),
              timestampMs: 8,
              phase: CanvasPointerPhase.up,
            ),
          );
          expect(controller.hasPendingLineStart, isTrue);
        },
      );

      test(
        'draw pen ignores parallel pointer ids and recovers after cancel',
        () async {
          // INV:INV-ENG-INTERACTIVE-SINGLE-ACTIVE-POINTER
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

          final actions = <ActionCommitted>[];
          final sub = controller.actions.listen(actions.add);
          addTearDown(sub.cancel);

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
              position: const Offset(20, 10),
              timestampMs: 2,
              phase: CanvasPointerPhase.move,
            ),
          );

          controller.handlePointer(
            sampleInput(
              pointerId: 2,
              position: const Offset(100, 100),
              timestampMs: 3,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.handlePointer(
            sampleInput(
              pointerId: 2,
              position: const Offset(120, 100),
              timestampMs: 4,
              phase: CanvasPointerPhase.move,
            ),
          );
          controller.handlePointer(
            sampleInput(
              pointerId: 2,
              position: const Offset(120, 100),
              timestampMs: 5,
              phase: CanvasPointerPhase.up,
            ),
          );

          expect(controller.hasActiveStrokePreview, isTrue);
          expect(
            controller.activeStrokePreviewPoints.first,
            const Offset(10, 10),
          );
          expect(
            controller.activeStrokePreviewPoints.last,
            const Offset(20, 10),
          );

          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(20, 10),
              timestampMs: 6,
              phase: CanvasPointerPhase.cancel,
            ),
          );
          expect(controller.hasActiveStrokePreview, isFalse);

          controller.handlePointer(
            sampleInput(
              pointerId: 2,
              position: const Offset(30, 10),
              timestampMs: 7,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.handlePointer(
            sampleInput(
              pointerId: 2,
              position: const Offset(40, 10),
              timestampMs: 8,
              phase: CanvasPointerPhase.move,
            ),
          );
          controller.handlePointer(
            sampleInput(
              pointerId: 2,
              position: const Offset(40, 10),
              timestampMs: 9,
              phase: CanvasPointerPhase.up,
            ),
          );

          await pumpEventQueue();
          expect(
            actions.where((event) => event.type == ActionType.drawStroke),
            hasLength(1),
          );

          final strokeNodes = controller.snapshot.layers
              .expand((layer) => layer.nodes)
              .whereType<StrokeNodeSnapshot>()
              .toList(growable: false);
          expect(strokeNodes, hasLength(1));
          final stroke = strokeNodes.single;
          expect(
            stroke.transform.applyToPoint(stroke.points.first),
            const Offset(30, 10),
          );
          expect(
            stroke.transform.applyToPoint(stroke.points.last),
            const Offset(40, 10),
          );
        },
      );

      test('draw mode rejects external selection mutations while active', () {
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(id: 'layer-auto-40'),
              ContentLayerSnapshot(id: 'layer-auto-41'),
            ],
          ),
          dragStartSlop: 0.001,
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

        expect(
          () => controller.setSelection(const <NodeId>{'x'}),
          throwsStateError,
        );
        expect(() => controller.toggleSelection('x'), throwsStateError);
        expect(() => controller.clearSelection(), throwsStateError);
        expect(() => controller.selectAll(), throwsStateError);

        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(10, 10),
            timestampMs: 2,
            phase: CanvasPointerPhase.cancel,
          ),
        );

        controller.clearSelection();
        expect(controller.selectedNodeIds, isEmpty);
      });
    });
  });
}
