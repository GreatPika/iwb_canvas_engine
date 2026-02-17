import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/scene.dart';

import '../test_support/interactive_controller_fixtures.dart';

void main() {
  group('SceneControllerInteractive unit', () {
    group('interactive hardening: invalid pointer data', () {
      test(
        'invalid pointer coordinates are ignored without side effects',
        () async {
          // INV:INV-ENG-INTERACTIVE-POINTER-FINITE
          final controller = SceneControllerInteractive(
            initialSnapshot: SceneSnapshot(
              layers: <ContentLayerSnapshot>[
                ContentLayerSnapshot(id: 'layer-auto-0'),
                ContentLayerSnapshot(id: 'layer-auto-1'),
              ],
            ),
          );
          addTearDown(controller.dispose);
          controller.setMode(CanvasMode.draw);
          controller.setDrawTool(DrawTool.pen);

          final actions = <ActionCommitted>[];
          final edits = <EditTextRequested>[];
          final actionSub = controller.actions.listen(actions.add);
          final editSub = controller.editTextRequests.listen(edits.add);
          addTearDown(actionSub.cancel);
          addTearDown(editSub.cancel);

          final beforeSnapshot = controller.snapshot;

          expect(
            () => controller.handlePointer(
              const CanvasPointerInput(
                pointerId: 1,
                position: Offset(double.nan, 0),
                phase: CanvasPointerPhase.down,
                kind: PointerDeviceKind.touch,
              ),
            ),
            returnsNormally,
          );
          expect(
            () => controller.handlePointer(
              const CanvasPointerInput(
                pointerId: 1,
                position: Offset(double.infinity, 1),
                phase: CanvasPointerPhase.move,
                kind: PointerDeviceKind.touch,
              ),
            ),
            returnsNormally,
          );
          expect(controller.snapshot, same(beforeSnapshot));
          expect(controller.selectedNodeIds, isEmpty);
          expect(controller.hasActiveStrokePreview, isFalse);
          expect(controller.hasActiveLinePreview, isFalse);
          expect(controller.hasPendingLineStart, isFalse);

          controller.handlePointer(
            const CanvasPointerInput(
              pointerId: 1,
              position: Offset(10, 10),
              phase: CanvasPointerPhase.down,
              kind: PointerDeviceKind.touch,
            ),
          );
          controller.handlePointer(
            const CanvasPointerInput(
              pointerId: 1,
              position: Offset(20, 20),
              phase: CanvasPointerPhase.up,
              kind: PointerDeviceKind.touch,
            ),
          );

          await pumpEventQueue();
          expect(actions, hasLength(1));
          expect(actions.single.type, ActionType.drawStroke);
          expect(actions.single.timestampMs, 1);
          expect(edits, isEmpty);
        },
      );

      test(
        'invalid up/cancel coordinates are ignored and gesture can recover',
        () async {
          // INV:INV-ENG-INTERACTIVE-POINTER-FINITE
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
          final actionSub = controller.actions.listen(actions.add);
          addTearDown(actionSub.cancel);

          controller.handlePointer(
            const CanvasPointerInput(
              pointerId: 1,
              position: Offset(10, 10),
              phase: CanvasPointerPhase.down,
              kind: PointerDeviceKind.touch,
            ),
          );
          expect(controller.hasActiveStrokePreview, isTrue);

          expect(
            () => controller.handlePointer(
              const CanvasPointerInput(
                pointerId: 1,
                position: Offset(double.nan, 20),
                phase: CanvasPointerPhase.up,
                kind: PointerDeviceKind.touch,
              ),
            ),
            returnsNormally,
          );
          expect(
            () => controller.handlePointer(
              const CanvasPointerInput(
                pointerId: 1,
                position: Offset(20, double.infinity),
                phase: CanvasPointerPhase.cancel,
                kind: PointerDeviceKind.touch,
              ),
            ),
            returnsNormally,
          );

          await pumpEventQueue();
          expect(actions, isEmpty);
          expect(controller.hasActiveStrokePreview, isTrue);

          controller.handlePointer(
            const CanvasPointerInput(
              pointerId: 1,
              position: Offset(10, 10),
              phase: CanvasPointerPhase.cancel,
              kind: PointerDeviceKind.touch,
            ),
          );
          expect(controller.hasActiveStrokePreview, isFalse);
          expect(controller.activeStrokePreviewPoints, isEmpty);

          controller.handlePointer(
            const CanvasPointerInput(
              pointerId: 2,
              position: Offset(30, 30),
              phase: CanvasPointerPhase.down,
              kind: PointerDeviceKind.touch,
            ),
          );
          controller.handlePointer(
            const CanvasPointerInput(
              pointerId: 2,
              position: Offset(40, 30),
              phase: CanvasPointerPhase.up,
              kind: PointerDeviceKind.touch,
            ),
          );

          await pumpEventQueue();
          expect(actions, hasLength(1));
          expect(actions.single.type, ActionType.drawStroke);
        },
      );

      test('invalid double-tap coordinates are ignored', () async {
        // INV:INV-ENG-INTERACTIVE-POINTER-FINITE
        final text = TextNode(
          id: 'text',
          text: 'note',
          size: const Size(80, 30),
          color: const Color(0xFF000000),
        )..position = const Offset(100, 100);
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-4'),
              ContentLayer(id: 'layer-auto-5', nodes: <SceneNode>[text]),
            ],
          ),
        );
        addTearDown(controller.dispose);

        final requests = <EditTextRequested>[];
        final sub = controller.editTextRequests.listen(requests.add);
        addTearDown(sub.cancel);

        expect(
          () => controller.handleDoubleTap(
            position: const Offset(double.nan, 100),
            timestampMs: 10,
          ),
          returnsNormally,
        );
        expect(
          () => controller.handleDoubleTap(
            position: const Offset(100, double.infinity),
            timestampMs: 11,
          ),
          returnsNormally,
        );

        controller.handleDoubleTap(
          position: const Offset(100, 100),
          timestampMs: 12,
        );

        await pumpEventQueue();
        expect(requests, hasLength(1));
        expect(requests.single.nodeId, 'text');
        expect(requests.single.timestampMs, 12);
      });
    });

    test(
      'double-tap edit request only in move mode on text top node',
      () async {
        final text = TextNode(
          id: 'text',
          text: 'note',
          size: const Size(80, 30),
          color: const Color(0xFF000000),
        )..position = const Offset(100, 100);
        final rect = RectNode(id: 'rect', size: const Size(80, 30))
          ..position = const Offset(200, 100);
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-6'),
              ContentLayer(id: 'layer-auto-7', nodes: <SceneNode>[rect, text]),
            ],
          ),
        );
        addTearDown(controller.dispose);

        final requests = <EditTextRequested>[];
        final sub = controller.editTextRequests.listen(requests.add);
        addTearDown(sub.cancel);

        controller.setMode(CanvasMode.draw);
        controller.handleDoubleTap(
          position: const Offset(100, 100),
          timestampMs: 10,
        );

        controller.setMode(CanvasMode.move);
        controller.handleDoubleTap(
          position: const Offset(200, 100),
          timestampMs: 12,
        );
        controller.handleDoubleTap(
          position: const Offset(100, 100),
          timestampMs: 13,
        );

        await pumpEventQueue();
        expect(requests.length, 1);
        expect(requests.single.nodeId, 'text');
        expect(requests.single.position, const Offset(100, 100));
      },
    );

    test('editTextRequests stream delivery is asynchronous', () async {
      // INV:INV-ENG-INTERACTIVE-ASYNC-DELIVERY
      final text = TextNode(
        id: 'text',
        text: 'note',
        size: const Size(80, 30),
        color: const Color(0xFF000000),
      )..position = const Offset(100, 100);
      final controller = controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(id: 'layer-auto-8'),
            ContentLayer(id: 'layer-auto-9', nodes: <SceneNode>[text]),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final requests = <EditTextRequested>[];
      final sub = controller.editTextRequests.listen(requests.add);
      addTearDown(sub.cancel);

      controller.handleDoubleTap(
        position: const Offset(100, 100),
        timestampMs: 10,
      );
      expect(requests, isEmpty);

      await pumpEventQueue();

      expect(requests, hasLength(1));
      expect(requests.single.nodeId, 'text');
    });
  });
}
