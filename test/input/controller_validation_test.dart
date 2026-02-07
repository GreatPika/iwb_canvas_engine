import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';

void main() {
  test('SceneController numeric setters reject invalid values', () {
    // INV:INV-INPUT-CAMERA-OFFSET-FINITE
    final controller = SceneController(scene: Scene(layers: [Layer()]));
    addTearDown(controller.dispose);

    expect(() => controller.penThickness = 0, throwsArgumentError);
    expect(() => controller.penThickness = -1, throwsArgumentError);
    expect(() => controller.penThickness = double.nan, throwsArgumentError);
    expect(
      () => controller.penThickness = double.infinity,
      throwsArgumentError,
    );

    expect(() => controller.highlighterThickness = 0, throwsArgumentError);
    expect(() => controller.lineThickness = 0, throwsArgumentError);
    expect(() => controller.eraserThickness = 0, throwsArgumentError);

    expect(() => controller.highlighterOpacity = -0.01, throwsArgumentError);
    expect(() => controller.highlighterOpacity = 1.01, throwsArgumentError);
    expect(
      () => controller.highlighterOpacity = double.infinity,
      throwsArgumentError,
    );

    expect(() => controller.setGridCellSize(0), throwsArgumentError);
    expect(() => controller.setGridCellSize(double.nan), throwsArgumentError);
    expect(
      () => controller.setCameraOffset(const Offset(double.nan, 0)),
      throwsArgumentError,
    );
    expect(
      () => controller.setCameraOffset(const Offset(0, double.infinity)),
      throwsArgumentError,
    );
  });

  test('SceneController numeric setters accept valid values', () {
    final controller = SceneController(scene: Scene(layers: [Layer()]));
    addTearDown(controller.dispose);

    controller.penThickness = 3;
    controller.highlighterThickness = 5;
    controller.lineThickness = 4;
    controller.eraserThickness = 8;
    controller.highlighterOpacity = 0.4;
    controller.setGridCellSize(12);

    expect(controller.penThickness, 3);
    expect(controller.highlighterOpacity, 0.4);
    expect(controller.scene.background.grid.cellSize, 12);
  });

  test('setGridCellSize clamps to minimum when grid is enabled', () {
    // INV:INV-RENDER-GRID-SAFETY-LIMITS
    final controller = SceneController(scene: Scene(layers: [Layer()]));
    addTearDown(controller.dispose);

    controller.setGridEnabled(true);
    controller.setGridCellSize(0.5);

    expect(controller.scene.background.grid.cellSize, 1.0);
  });

  test('setCameraOffset rejection does not mutate scene offset', () {
    final controller = SceneController(scene: Scene(layers: [Layer()]));
    addTearDown(controller.dispose);

    controller.setCameraOffset(const Offset(4, 6));
    expect(
      () => controller.setCameraOffset(const Offset(double.nan, 0)),
      throwsArgumentError,
    );

    expect(controller.scene.camera.offset, const Offset(4, 6));
  });

  test(
    'after invalid camera offset rejection drag keeps finite transforms',
    () {
      final node = RectNode(
        id: 'rect-1',
        size: const Size(40, 20),
        fillColor: const Color(0xFF000000),
      );
      final controller = SceneController(
        scene: Scene(
          layers: [
            Layer(nodes: [node]),
          ],
        ),
      );
      addTearDown(controller.dispose);

      expect(
        () => controller.setCameraOffset(const Offset(double.nan, 0)),
        throwsArgumentError,
      );

      controller.handlePointer(
        const PointerSample(
          pointerId: 1,
          position: Offset(0, 0),
          timestampMs: 1,
          phase: PointerPhase.down,
        ),
      );
      controller.handlePointer(
        const PointerSample(
          pointerId: 1,
          position: Offset(20, 10),
          timestampMs: 2,
          phase: PointerPhase.move,
        ),
      );
      controller.handlePointer(
        const PointerSample(
          pointerId: 1,
          position: Offset(20, 10),
          timestampMs: 3,
          phase: PointerPhase.up,
        ),
      );

      final t = node.transform;
      expect(t.a.isFinite, isTrue);
      expect(t.b.isFinite, isTrue);
      expect(t.c.isFinite, isTrue);
      expect(t.d.isFinite, isTrue);
      expect(t.tx.isFinite, isTrue);
      expect(t.ty.isFinite, isTrue);
    },
  );
}
