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
                ContentLayerSnapshot(),
                ContentLayerSnapshot(),
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
                ContentLayerSnapshot(),
                ContentLayerSnapshot(),
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
              ContentLayer(),
              ContentLayer(nodes: <SceneNode>[text]),
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
              ContentLayer(),
              ContentLayer(nodes: <SceneNode>[rect, text]),
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
            ContentLayer(),
            ContentLayer(nodes: <SceneNode>[text]),
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

    test('hit-test uses preview-shifted geometry during move drag', () async {
      final text = TextNode(
        id: 'text',
        text: 'note',
        size: const Size(40, 20),
        color: const Color(0xFF000000),
      )..position = const Offset(100, 100);
      final controller = controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(),
            ContentLayer(nodes: <SceneNode>[text]),
          ],
        ),
      );
      addTearDown(controller.dispose);
      controller.setSelection(const <NodeId>{'text'});
      final textSnapshotBeforeMove =
          nodeById(controller.snapshot, 'text') as TextNodeSnapshot;
      final originalCenter = Offset(
        textSnapshotBeforeMove.transform.tx,
        textSnapshotBeforeMove.transform.ty,
      );
      final originalOnlyPoint = Offset(
        originalCenter.dx - textSnapshotBeforeMove.size.width / 2 + 2,
        originalCenter.dy,
      );
      final movedPoint = originalCenter.translate(40, 0);

      final requests = <EditTextRequested>[];
      final sub = controller.editTextRequests.listen(requests.add);
      addTearDown(sub.cancel);

      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: originalCenter,
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: movedPoint,
          timestampMs: 2,
          phase: CanvasPointerPhase.move,
        ),
      );

      controller.handleDoubleTap(position: movedPoint, timestampMs: 3);
      controller.handleDoubleTap(position: originalOnlyPoint, timestampMs: 4);

      await pumpEventQueue();
      expect(requests.length, 1);
      expect(requests.single.nodeId, 'text');
      expect(requests.single.position, movedPoint);
    });

    test('move cancel keeps document unchanged and clears preview', () {
      // INV:INV-ENG-INTERACTIVE-PREVIEW-COMMIT-ON-UP
      // INV:INV-ENG-INTERACTIVE-CANCEL-STATE-RESET
      final rect = RectNode(id: 'node', size: const Size(40, 20))
        ..position = const Offset(80, 80);
      final controller = controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(),
            ContentLayer(nodes: <SceneNode>[rect]),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.setSelection(const <NodeId>{'node'});
      final beforeNode =
          nodeById(controller.snapshot, 'node') as RectNodeSnapshot;

      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(80, 80),
          timestampMs: 10,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(130, 80),
          timestampMs: 20,
          phase: CanvasPointerPhase.move,
        ),
      );
      final duringMove =
          nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
      expect(duringMove.transform.tx, closeTo(beforeNode.transform.tx, 1e-6));

      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(130, 80),
          timestampMs: 21,
          phase: CanvasPointerPhase.cancel,
        ),
      );

      final afterCancel =
          nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
      expect(afterCancel.transform.tx, closeTo(beforeNode.transform.tx, 1e-6));
      expect(afterCancel.transform.ty, closeTo(beforeNode.transform.ty, 1e-6));
      expect(controller.selectionRect, isNull);
    });

    test('move drag commits once on up and applies total delta exactly', () {
      // INV:INV-ENG-INTERACTIVE-PREVIEW-COMMIT-ON-UP
      final rect = RectNode(id: 'node', size: const Size(30, 20))
        ..position = const Offset(60, 60);
      final controller = controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(),
            ContentLayer(nodes: <SceneNode>[rect]),
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

      var position = const Offset(60, 60);
      for (var i = 0; i < 50; i++) {
        position = Offset(position.dx + 1, position.dy + 2);
        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: position,
            timestampMs: 2 + i,
            phase: CanvasPointerPhase.move,
          ),
        );
      }

      final beforeUp =
          nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
      expect(beforeUp.transform.tx, closeTo(60, 1e-6));
      expect(beforeUp.transform.ty, closeTo(60, 1e-6));

      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: position,
          timestampMs: 100,
          phase: CanvasPointerPhase.up,
        ),
      );

      final afterUp = nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
      expect(afterUp.transform.tx, closeTo(110, 1e-6));
      expect(afterUp.transform.ty, closeTo(160, 1e-6));
    });

    test(
      'move drag start threshold uses dragStartSlop and null fallback uses tapSlop',
      () {
        final rect = RectNode(id: 'node', size: const Size(30, 20))
          ..position = const Offset(60, 60);
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(),
              ContentLayer(nodes: <SceneNode>[rect]),
            ],
          ),
          pointerSettings: const PointerInputSettings(tapSlop: 4),
          dragStartSlop: 12,
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
            position: const Offset(66, 60),
            timestampMs: 2,
            phase: CanvasPointerPhase.move,
          ),
        );
        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(66, 60),
            timestampMs: 3,
            phase: CanvasPointerPhase.up,
          ),
        );

        final afterCustomSlop =
            nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
        expect(afterCustomSlop.transform.tx, closeTo(60, 1e-6));
        expect(afterCustomSlop.transform.ty, closeTo(60, 1e-6));

        controller.setDragStartSlop(null);
        expect(controller.dragStartSlop, 4);

        controller.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(60, 60),
            timestampMs: 4,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(66, 60),
            timestampMs: 5,
            phase: CanvasPointerPhase.move,
          ),
        );
        controller.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(66, 60),
            timestampMs: 6,
            phase: CanvasPointerPhase.up,
          ),
        );

        final afterFallbackSlop =
            nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
        expect(afterFallbackSlop.transform.tx, closeTo(66, 1e-6));
        expect(afterFallbackSlop.transform.ty, closeTo(60, 1e-6));
      },
    );

    // Gap matrix axis: single-active-pointer semantics.
  });
}
