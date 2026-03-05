import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/scene_defaults.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/core/grid_safety_limits.dart';
import 'package:iwb_canvas_engine/src/core/interaction_types.dart';
import 'package:iwb_canvas_engine/src/core/scene_limits.dart';
import 'package:iwb_canvas_engine/src/core/tool_defaults.dart';

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
      expect(ToolDefaults.penThickness, greaterThan(0));
      expect(ToolDefaults.highlighterThickness, greaterThan(0));
      expect(ToolDefaults.eraserThickness, greaterThan(0));
      expect(ToolDefaults.highlighterOpacity, inInclusiveRange(0.0, 1.0));
    });

    test('public snapshot defaults stay aligned with shared defaults', () {
      final snapshotPalette = ScenePaletteSnapshot();
      const snapshotGrid = GridSnapshot();
      const snapshotBackground = BackgroundSnapshot();

      expect(SceneDefaults.penColors, orderedEquals(snapshotPalette.penColors));
      expect(
        SceneDefaults.backgroundColors,
        orderedEquals(snapshotPalette.backgroundColors),
      );
      expect(SceneDefaults.gridSizes, orderedEquals(snapshotPalette.gridSizes));
      expect(snapshotGrid.cellSize, SceneDefaults.gridCellSize);
      expect(snapshotGrid.color, SceneDefaults.gridColor);
      expect(snapshotBackground.color, SceneDefaults.backgroundColors.first);
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
      expect(sceneSchemaVersionsRead, contains(sceneSchemaVersionWrite));
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
