import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/legacy_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Layer firstNonBackgroundLayer(Scene scene) =>
      scene.layers.firstWhere((layer) => !layer.isBackground);

  test('stroke input decimation keeps only points beyond 0.75 scene units', () {
    final scene = Scene(layers: [Layer()]);
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    addTearDown(controller.dispose);
    controller
      ..setMode(CanvasMode.draw)
      ..setDrawTool(DrawTool.pen);

    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0.2, 0),
        timestampMs: 1,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0.4, 0),
        timestampMs: 2,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0.74, 0),
        timestampMs: 3,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(0.76, 0),
        timestampMs: 4,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      const PointerSample(
        pointerId: 1,
        position: Offset(1.0, 0),
        timestampMs: 5,
        phase: PointerPhase.up,
      ),
    );

    final stroke = firstNonBackgroundLayer(scene).nodes.single as StrokeNode;
    expect(stroke.points.length, 3);
  });

  test(
    'eraser appends final up-point even when below decimation threshold',
    () {
      final target = LineNode(
        id: 'line-1',
        start: const Offset(0.6, -1),
        end: const Offset(0.6, 1),
        thickness: 0.1,
        color: const Color(0xFF000000),
      );
      final scene = Scene(
        layers: [
          Layer(nodes: [target]),
        ],
      );
      final controller = SceneController(scene: scene, dragStartSlop: 0);
      addTearDown(controller.dispose);
      controller
        ..setMode(CanvasMode.draw)
        ..setDrawTool(DrawTool.eraser)
        ..eraserThickness = 0.1;

      controller.handlePointer(
        const PointerSample(
          pointerId: 1,
          position: Offset(0, 0),
          timestampMs: 0,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        const PointerSample(
          pointerId: 1,
          position: Offset(0.6, 0),
          timestampMs: 1,
          phase: PointerPhase.up,
        ),
      );

      expect(firstNonBackgroundLayer(scene).nodes, isEmpty);
    },
  );
}
