import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/defaults.dart';
import 'package:iwb_canvas_engine/src/core/grid_safety_limits.dart';
import 'package:iwb_canvas_engine/src/core/interaction_types.dart';
import 'package:iwb_canvas_engine/src/core/scene_limits.dart';

void main() {
  group('Scene defaults', () {
    test(
      'palettes and grid presets are non-empty and internally consistent',
      () {
        expect(SceneDefaults.penColors, isNotEmpty);
        expect(SceneDefaults.backgroundColors, isNotEmpty);
        expect(SceneDefaults.gridSizes, isNotEmpty);
        expect(SceneDefaults.gridSizes.first, SceneDefaults.gridCellSize);
        expect(
          SceneDefaults.gridSizes,
          orderedEquals(
            SceneDefaults.gridSizes.toList()..sort((a, b) => a.compareTo(b)),
          ),
        );
        for (final gridSize in SceneDefaults.gridSizes) {
          expect(gridSize, greaterThan(0));
        }
      },
    );

    test('tool defaults are within sane UI ranges', () {
      expect(SceneDefaults.penThickness, greaterThan(0));
      expect(SceneDefaults.highlighterThickness, greaterThan(0));
      expect(SceneDefaults.eraserThickness, greaterThan(0));
      expect(SceneDefaults.highlighterOpacity, inInclusiveRange(0.0, 1.0));
    });
  });

  group('Core numeric limits', () {
    test('grid safety limits are strictly positive', () {
      expect(kMinGridCellSize, greaterThan(0));
      expect(kMaxGridLinesPerAxis, greaterThan(0));
    });

    test('scene coordinate and scale ranges are valid', () {
      expect(sceneCoordMin, lessThan(sceneCoordMax));
      expect(sceneScaleMin, greaterThan(0));
      expect(sceneScaleMin, lessThan(sceneScaleMax));
      expect(sceneSchemaVersionMin, lessThanOrEqualTo(sceneSchemaVersionMax));
    });

    test(
      'interactive point trimming guardrails keep hysteresis and endpoints',
      () {
        expect(kInteractiveStrokePointsTrimTo, greaterThanOrEqualTo(2));
        expect(
          kInteractiveStrokePointsTrimTo,
          lessThan(kInteractiveStrokePointsSoftLimit),
        );
        expect(kInteractiveEraserPointsTrimTo, greaterThanOrEqualTo(2));
        expect(
          kInteractiveEraserPointsTrimTo,
          lessThan(kInteractiveEraserPointsSoftLimit),
        );
      },
    );
  });

  group('Interaction enums', () {
    test('canvas modes keep stable names and order', () {
      expect(
        CanvasMode.values.map((m) => m.name).toList(),
        equals(<String>['move', 'draw']),
      );
    });

    test('draw tools keep stable names and order', () {
      expect(
        DrawTool.values.map((t) => t.name).toList(),
        equals(<String>['pen', 'highlighter', 'line', 'eraser']),
      );
    });
  });
}
