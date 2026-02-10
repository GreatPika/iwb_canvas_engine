import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/legacy_api.dart';

// INV:INV-G-NOTIFY-SEMANTICS

Future<void> pumpFrame(WidgetTester tester) async {
  await tester.pump();
}

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

  Layer firstNonBackgroundLayer(Scene scene) =>
      scene.layers.firstWhere((layer) => !layer.isBackground);

  testWidgets('style setters schedule a repaint notification', (tester) async {
    final controller = SceneController(scene: Scene(layers: [Layer()]));
    addTearDown(controller.dispose);

    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.highlighterThickness = controller.highlighterThickness + 1;
    await pumpFrame(tester);
    expect(notifications, 1);

    controller.highlighterOpacity = controller.highlighterOpacity + 0.1;
    await pumpFrame(tester);
    expect(notifications, 2);
  });

  testWidgets('hot paths coalesce draw repaint requests to one per frame', (
    tester,
  ) async {
    final controller = SceneController(scene: Scene(layers: [Layer()]));
    addTearDown(controller.dispose);

    controller.setMode(CanvasMode.draw);
    controller.setDrawTool(DrawTool.pen);

    var notifications = 0;
    controller.addListener(() => notifications++);

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

    expect(notifications, 0);

    await pumpFrame(tester);

    expect(notifications, 1);
  });

  testWidgets('draw commit does not emit a tail notification', (tester) async {
    final controller = SceneController(scene: Scene(layers: [Layer()]));
    addTearDown(controller.dispose);

    controller.setMode(CanvasMode.draw);
    controller.setDrawTool(DrawTool.pen);

    var notifications = 0;
    controller.addListener(() => notifications++);

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

    expect(notifications, 0);

    await pumpFrame(tester);

    expect(notifications, 1);

    controller.handlePointer(
      sample(
        pointerId: 1,
        position: const Offset(20, 0),
        timestampMs: 20,
        phase: PointerPhase.up,
      ),
    );

    expect(notifications, 2);

    await pumpFrame(tester);

    expect(notifications, 2);
  });

  testWidgets('hot paths coalesce move repaint requests to one per frame', (
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
        timestampMs: 1,
        phase: PointerPhase.up,
      ),
    );

    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.handlePointer(
      sample(
        pointerId: 2,
        position: const Offset(0, 0),
        timestampMs: 10,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      sample(
        pointerId: 2,
        position: const Offset(10, 0),
        timestampMs: 20,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      sample(
        pointerId: 2,
        position: const Offset(20, 0),
        timestampMs: 30,
        phase: PointerPhase.move,
      ),
    );

    expect(notifications, 0);

    await pumpFrame(tester);

    expect(notifications, 1);
  });

  testWidgets('hot paths coalesce marquee repaint requests to one per frame', (
    tester,
  ) async {
    final controller = SceneController(scene: Scene(layers: [Layer()]));
    addTearDown(controller.dispose);

    var notifications = 0;
    controller.addListener(() => notifications++);

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
        position: const Offset(20, 20),
        timestampMs: 10,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      sample(
        pointerId: 1,
        position: const Offset(40, 40),
        timestampMs: 20,
        phase: PointerPhase.move,
      ),
    );

    expect(notifications, 0);

    await pumpFrame(tester);

    expect(notifications, 1);
  });

  testWidgets('hot paths coalesce erase repaint requests to one per frame', (
    tester,
  ) async {
    final controller = SceneController(scene: Scene(layers: [Layer()]));
    addTearDown(controller.dispose);

    controller.setMode(CanvasMode.draw);
    controller.setDrawTool(DrawTool.eraser);

    var notifications = 0;
    controller.addListener(() => notifications++);

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

    expect(notifications, 0);

    await pumpFrame(tester);

    expect(notifications, 1);
  });

  testWidgets('commit + reset does not emit a tail notification', (
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
        timestampMs: 1,
        phase: PointerPhase.up,
      ),
    );

    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.handlePointer(
      sample(
        pointerId: 2,
        position: const Offset(0, 0),
        timestampMs: 10,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      sample(
        pointerId: 2,
        position: const Offset(10, 0),
        timestampMs: 20,
        phase: PointerPhase.move,
      ),
    );

    await pumpFrame(tester);

    expect(notifications, 1);

    controller.handlePointer(
      sample(
        pointerId: 2,
        position: const Offset(10, 0),
        timestampMs: 30,
        phase: PointerPhase.up,
      ),
    );

    await pumpFrame(tester);

    expect(notifications, 1);
  });

  testWidgets('eraser up emits only one notification when deletions occur', (
    tester,
  ) async {
    final stroke = StrokeNode(
      id: 's1',
      points: const [Offset(0, 0), Offset(20, 0)],
      thickness: 3,
      color: const Color(0xFF000000),
    );
    final controller = SceneController(
      scene: Scene(
        layers: [
          Layer(nodes: [stroke]),
        ],
      ),
    );
    addTearDown(controller.dispose);

    controller.setMode(CanvasMode.draw);
    controller.setDrawTool(DrawTool.eraser);
    controller.eraserThickness = 10;

    var notifications = 0;
    controller.addListener(() => notifications++);

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
        phase: PointerPhase.up,
      ),
    );

    expect(notifications, 1);
    expect(firstNonBackgroundLayer(controller.scene).nodes, isEmpty);
  });

  testWidgets('setCameraOffset coalesces repaints to one per frame', (
    tester,
  ) async {
    final controller = SceneController();
    addTearDown(controller.dispose);

    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.setCameraOffset(const Offset(1, 1));
    controller.setCameraOffset(const Offset(2, 2));
    controller.setCameraOffset(const Offset(3, 3));

    expect(notifications, 0);

    await pumpFrame(tester);

    expect(notifications, 1);
  });
}
