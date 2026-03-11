import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/scene.dart';

import '../test_support/interactive_controller_fixtures.dart';

void main() {
  group('SceneControllerInteractive unit', () {
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
            ContentLayer(id: 'layer-auto-0'),
            ContentLayer(id: 'layer-auto-1', nodes: <SceneNode>[text]),
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
            ContentLayer(id: 'layer-auto-2'),
            ContentLayer(id: 'layer-auto-3', nodes: <SceneNode>[rect]),
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

    test(
      'move cancel restores baseline selection after marquee changed it',
      () {
        // INV:INV-ENG-INTERACTIVE-CANCEL-STATE-RESET
        final baseline = RectNode(id: 'baseline', size: const Size(40, 20))
          ..position = const Offset(40, 40);
        final other = RectNode(id: 'other', size: const Size(40, 20))
          ..position = const Offset(180, 40);
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-20'),
              ContentLayer(
                id: 'layer-auto-21',
                nodes: <SceneNode>[baseline, other],
              ),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.setSelection(const <NodeId>{'baseline'});

        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(300, 300),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(320, 320),
            timestampMs: 2,
            phase: CanvasPointerPhase.move,
          ),
        );
        expect(controller.selectedNodeIds, isEmpty);
        expect(controller.selectionRect, isNotNull);

        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(320, 320),
            timestampMs: 3,
            phase: CanvasPointerPhase.cancel,
          ),
        );

        expect(controller.selectedNodeIds, const <NodeId>{'baseline'});
        expect(controller.selectionRect, isNull);
      },
    );

    test(
      'selectable locked node changes selection but never starts move preview',
      () async {
        final baseline = TextNode(
          id: 'baseline',
          text: 'baseline',
          size: const Size(50, 20),
          color: const Color(0xFF000000),
        )..position = const Offset(40, 40);
        final locked = TextNode(
          id: 'locked',
          text: 'locked',
          size: const Size(50, 20),
          color: const Color(0xFF000000),
          isLocked: true,
        )..position = const Offset(140, 40);
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-22'),
              ContentLayer(
                id: 'layer-auto-23',
                nodes: <SceneNode>[baseline, locked],
              ),
            ],
          ),
        );
        addTearDown(controller.dispose);

        final requests = <EditTextRequested>[];
        final sub = controller.editTextRequests.listen(requests.add);
        addTearDown(sub.cancel);

        controller.setSelection(const <NodeId>{'baseline'});

        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(140, 40),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(200, 40),
            timestampMs: 2,
            phase: CanvasPointerPhase.move,
          ),
        );

        controller.handleDoubleTap(
          position: const Offset(140, 40),
          timestampMs: 3,
        );
        controller.handleDoubleTap(
          position: const Offset(260, 40),
          timestampMs: 4,
        );

        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(200, 40),
            timestampMs: 5,
            phase: CanvasPointerPhase.up,
          ),
        );

        await pumpEventQueue();
        expect(controller.selectedNodeIds, const <NodeId>{'locked'});
        expect(requests, hasLength(1));
        expect(requests.single.nodeId, 'locked');
        expect(requests.single.position, const Offset(140, 40));

        final lockedAfter =
            nodeById(controller.snapshot, 'locked') as TextNodeSnapshot;
        expect(lockedAfter.transform.tx, closeTo(140, 1e-6));
        expect(lockedAfter.transform.ty, closeTo(40, 1e-6));
      },
    );

    test('move cancel clears selection when gesture baseline was empty', () {
      // INV:INV-ENG-INTERACTIVE-CANCEL-STATE-RESET
      final locked = RectNode(
        id: 'locked',
        size: const Size(40, 20),
        isLocked: true,
      )..position = const Offset(140, 40);
      final controller = controllerFromScene(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(id: 'layer-auto-24'),
            ContentLayer(id: 'layer-auto-25', nodes: <SceneNode>[locked]),
          ],
        ),
      );
      addTearDown(controller.dispose);

      expect(controller.selectedNodeIds, isEmpty);

      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(140, 40),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );
      expect(controller.selectedNodeIds, const <NodeId>{'locked'});

      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(140, 40),
          timestampMs: 2,
          phase: CanvasPointerPhase.cancel,
        ),
      );

      expect(controller.selectedNodeIds, isEmpty);
      expect(controller.selectionRect, isNull);
    });

    test('move drag commits once on up and applies total delta exactly', () {
      // INV:INV-ENG-INTERACTIVE-PREVIEW-COMMIT-ON-UP
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
              ContentLayer(id: 'layer-auto-6'),
              ContentLayer(id: 'layer-auto-7', nodes: <SceneNode>[rect]),
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

    test(
      'active gesture keeps dragStartSlop baseline fixed until terminal',
      () {
        final rect = RectNode(id: 'node', size: const Size(30, 20))
          ..position = const Offset(60, 60);
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(id: 'layer-auto-8'),
              ContentLayer(id: 'layer-auto-9', nodes: <SceneNode>[rect]),
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

        controller.setDragStartSlop(null);
        expect(controller.dragStartSlop, 4);

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

        final afterBaselineGesture =
            nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
        expect(afterBaselineGesture.transform.tx, closeTo(60, 1e-6));
        expect(afterBaselineGesture.transform.ty, closeTo(60, 1e-6));

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

        final afterNextGesture =
            nodeById(controller.snapshot, 'node') as RectNodeSnapshot;
        expect(afterNextGesture.transform.tx, closeTo(66, 1e-6));
        expect(afterNextGesture.transform.ty, closeTo(60, 1e-6));
      },
    );
  });
}
