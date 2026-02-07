import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/basic.dart';

void main() {
  test('SceneController numeric setters reject invalid values', () {
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
}
