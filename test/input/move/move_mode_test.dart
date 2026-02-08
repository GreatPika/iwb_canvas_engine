import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // INV:INV-INPUT-MOVE-DRAG-ROLLBACK

  RectNode rectNode(String id, Offset position, {bool isLocked = false}) {
    return RectNode(
      id: id,
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
      isLocked: isLocked,
    )..position = position;
  }

  test('tap selects topmost node across layers', () {
    final bottom = rectNode('bottom', const Offset(0, 0));
    final top = rectNode('top', const Offset(0, 0));
    final scene = Scene(
      layers: [
        Layer(nodes: [bottom]),
        Layer(nodes: [top]),
      ],
    );
    final controller = SceneController(
      scene: scene,
      pointerSettings: const PointerInputSettings(tapSlop: 4),
    );

    controller.handlePointer(
      PointerSample(
        pointerId: 1,
        position: const Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 1,
        position: const Offset(0, 0),
        timestampMs: 10,
        phase: PointerPhase.up,
      ),
    );

    expect(controller.selectedNodeIds, {'top'});
  });

  test('tap on empty clears selection', () {
    final node = rectNode('node-1', const Offset(0, 0));
    final scene = Scene(
      layers: [
        Layer(nodes: [node]),
      ],
    );
    final controller = SceneController(scene: scene);

    controller.handlePointer(
      PointerSample(
        pointerId: 2,
        position: const Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 2,
        position: const Offset(0, 0),
        timestampMs: 10,
        phase: PointerPhase.up,
      ),
    );
    expect(controller.selectedNodeIds, {'node-1'});

    controller.handlePointer(
      PointerSample(
        pointerId: 3,
        position: const Offset(200, 200),
        timestampMs: 20,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 3,
        position: const Offset(200, 200),
        timestampMs: 30,
        phase: PointerPhase.up,
      ),
    );

    expect(controller.selectedNodeIds, isEmpty);
  });

  test('marquee selects intersecting nodes and emits action', () {
    final first = rectNode('node-1', const Offset(0, 0));
    final second = rectNode('node-2', const Offset(50, 0));
    final third = rectNode('node-3', const Offset(200, 0));
    final scene = Scene(
      layers: [
        Layer(nodes: [first, second, third]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    final actions = <ActionCommitted>[];
    controller.actions.listen(actions.add);

    controller.handlePointer(
      PointerSample(
        pointerId: 4,
        position: const Offset(-20, -20),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 4,
        position: const Offset(80, 20),
        timestampMs: 10,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 4,
        position: const Offset(80, 20),
        timestampMs: 20,
        phase: PointerPhase.up,
      ),
    );

    expect(controller.selectionRect, isNull);
    expect(controller.selectedNodeIds, {'node-1', 'node-2'});
    expect(actions, hasLength(1));
    expect(actions.single.type, ActionType.selectMarquee);
    expect(actions.single.nodeIds, ['node-1', 'node-2']);
  });

  test('drag move updates selection and emits action with moved ids', () {
    final movable = rectNode('movable', const Offset(0, 0));
    final locked = rectNode('locked', const Offset(50, 0), isLocked: true);
    final scene = Scene(
      layers: [
        Layer(nodes: [movable, locked]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    final actions = <ActionCommitted>[];
    controller.actions.listen(actions.add);

    controller.handlePointer(
      PointerSample(
        pointerId: 5,
        position: const Offset(-20, -20),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 5,
        position: const Offset(60, 20),
        timestampMs: 10,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 5,
        position: const Offset(60, 20),
        timestampMs: 20,
        phase: PointerPhase.up,
      ),
    );

    expect(controller.selectedNodeIds, {'movable', 'locked'});

    controller.handlePointer(
      PointerSample(
        pointerId: 6,
        position: const Offset(0, 0),
        timestampMs: 30,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 6,
        position: const Offset(20, 0),
        timestampMs: 40,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 6,
        position: const Offset(20, 0),
        timestampMs: 50,
        phase: PointerPhase.up,
      ),
    );

    expect(movable.position, const Offset(20, 0));
    expect(locked.position, const Offset(50, 0));
    expect(actions.last.type, ActionType.transform);
    expect(actions.last.nodeIds, ['movable']);
    final delta = (actions.last.payload!['delta'] as Map).cast<String, num>();
    expect(delta['tx']?.toDouble(), 20.0);
    expect(delta['ty']?.toDouble(), 0.0);
  });

  test('drag cancel restores moved nodes and emits no transform action', () {
    final movable = rectNode('movable', const Offset(0, 0));
    final scene = Scene(
      layers: [
        Layer(nodes: [movable]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    addTearDown(controller.dispose);
    controller.setSelection(const <NodeId>{'movable'});

    final actions = <ActionCommitted>[];
    final sub = controller.actions.listen(actions.add);
    addTearDown(sub.cancel);

    controller.handlePointer(
      const PointerSample(
        pointerId: 10,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 10,
        position: Offset(20, 0),
        timestampMs: 10,
        phase: PointerPhase.move,
      ),
    );
    expect(movable.position, const Offset(20, 0));

    controller.handlePointer(
      const PointerSample(
        pointerId: 10,
        position: Offset(20, 0),
        timestampMs: 20,
        phase: PointerPhase.cancel,
      ),
    );

    expect(movable.position, const Offset(0, 0));
    expect(
      actions.where((event) => event.type == ActionType.transform),
      isEmpty,
    );
  });

  test(
    'setMode during drag restores moved nodes and emits no transform action',
    () {
      final movable = rectNode('movable', const Offset(0, 0));
      final scene = Scene(
        layers: [
          Layer(nodes: [movable]),
        ],
      );
      final controller = SceneController(scene: scene, dragStartSlop: 0);
      addTearDown(controller.dispose);
      controller.setSelection(const <NodeId>{'movable'});

      final actions = <ActionCommitted>[];
      final sub = controller.actions.listen(actions.add);
      addTearDown(sub.cancel);

      controller.handlePointer(
        const PointerSample(
          pointerId: 11,
          position: Offset(0, 0),
          timestampMs: 0,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        const PointerSample(
          pointerId: 11,
          position: Offset(20, 0),
          timestampMs: 10,
          phase: PointerPhase.move,
        ),
      );
      expect(movable.position, const Offset(20, 0));

      controller.setMode(CanvasMode.draw);

      expect(movable.position, const Offset(0, 0));
      expect(controller.mode, CanvasMode.draw);
      expect(
        actions.where((event) => event.type == ActionType.transform),
        isEmpty,
      );
    },
  );
}
