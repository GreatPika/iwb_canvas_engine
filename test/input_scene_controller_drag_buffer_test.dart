import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';

PointerSample sample({
  required int pointerId,
  required Offset position,
  required int timestampMs,
  required PointerPhase phase,
}) {
  return PointerSample(
    pointerId: pointerId,
    position: position,
    timestampMs: timestampMs,
    phase: phase,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('click without drag does not build move gesture buffer', (
    tester,
  ) async {
    final node = RectNode(
      id: 'n1',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
    )..position = const Offset(0, 0);
    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [node]),
        ],
      ),
      dragStartSlop: 0,
    );
    addTearDown(controller.dispose);

    controller.handlePointer(
      sample(
        pointerId: 1,
        position: const Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      sample(
        pointerId: 1,
        position: const Offset(0, 0),
        timestampMs: 10,
        phase: PointerPhase.up,
      ),
    );

    expect(controller.debugMoveGestureBuildCount, 0);
    expect(controller.debugMoveGestureNodes, isNull);

    await tester.pump();
  });

  testWidgets('drag builds move gesture buffer only once', (tester) async {
    final node = RectNode(
      id: 'n1',
      size: const Size(10, 10),
      fillColor: const Color(0xFF000000),
    )..position = const Offset(0, 0);
    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [node]),
        ],
      ),
      dragStartSlop: 0,
    );
    addTearDown(controller.dispose);

    controller.handlePointer(
      sample(
        pointerId: 1,
        position: const Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      sample(
        pointerId: 1,
        position: const Offset(10, 0),
        timestampMs: 10,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      sample(
        pointerId: 1,
        position: const Offset(20, 0),
        timestampMs: 20,
        phase: PointerPhase.move,
      ),
    );

    expect(controller.debugMoveGestureBuildCount, 1);
    expect(controller.debugMoveGestureNodes, isNotNull);

    controller.handlePointer(
      sample(
        pointerId: 1,
        position: const Offset(20, 0),
        timestampMs: 30,
        phase: PointerPhase.up,
      ),
    );

    await tester.pump();
  });

  testWidgets(
    'structural scene change during drag disables buffer but keeps drag active',
    (tester) async {
      final node = RectNode(
        id: 'n1',
        size: const Size(10, 10),
        fillColor: const Color(0xFF000000),
      )..position = const Offset(0, 0);
      final controller = SceneController(
        scene: Scene(
          layers: [
            Layer(nodes: [node]),
          ],
        ),
        dragStartSlop: 0,
      );
      addTearDown(controller.dispose);

      controller.handlePointer(
        sample(
          pointerId: 1,
          position: const Offset(0, 0),
          timestampMs: 0,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        sample(
          pointerId: 1,
          position: const Offset(10, 0),
          timestampMs: 10,
          phase: PointerPhase.move,
        ),
      );

      final positionAfterStart = node.position;
      expect(positionAfterStart.dx, greaterThan(0));
      expect(controller.debugMoveGestureNodes, isNotNull);

      controller.addNode(
        RectNode(
          id: 'n2',
          size: const Size(10, 10),
          fillColor: const Color(0xFF000000),
        )..position = const Offset(100, 0),
      );

      controller.handlePointer(
        sample(
          pointerId: 1,
          position: const Offset(20, 0),
          timestampMs: 20,
          phase: PointerPhase.move,
        ),
      );

      expect(controller.debugMoveGestureNodes, isNull);
      expect(node.position.dx, greaterThan(positionAfterStart.dx));

      controller.handlePointer(
        sample(
          pointerId: 1,
          position: const Offset(20, 0),
          timestampMs: 30,
          phase: PointerPhase.up,
        ),
      );

      await tester.pump();
    },
  );
}
