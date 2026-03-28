import 'dart:ui';

import '../../contract/scene_defaults.dart';
import '../../core/interaction_types.dart';
import '../../core/pointer_input.dart';
import '../../core/tool_defaults.dart';
import 'interactive_draw_style.dart';

final class SceneControllerInteractionConfig {
  SceneControllerInteractionConfig({
    PointerInputSettings? pointerSettings,
    double? dragStartSlop,
  }) : pointerSettings = pointerSettings ?? const PointerInputSettings(),
       dragStartSlopOverride = validateDragStartSlop(dragStartSlop);

  PointerInputSettings pointerSettings;
  double? dragStartSlopOverride;

  CanvasMode mode = CanvasMode.move;
  DrawTool drawTool = DrawTool.pen;
  Color drawColor = SceneDefaults.penColors.first;
  double penThickness = ToolDefaults.penThickness;
  double highlighterThickness = ToolDefaults.highlighterThickness;
  double lineThickness = ToolDefaults.penThickness;
  double eraserThickness = ToolDefaults.eraserThickness;
  double highlighterOpacity = ToolDefaults.highlighterOpacity;

  double dragStartSlop() => dragStartSlopOverride ?? pointerSettings.tapSlop;

  InteractiveDrawStyle currentDrawStyle() => (
    drawTool: drawTool,
    drawColor: drawColor,
    penThickness: penThickness,
    highlighterThickness: highlighterThickness,
    lineThickness: lineThickness,
    eraserThickness: eraserThickness,
    highlighterOpacity: highlighterOpacity,
  );

  static double? validateDragStartSlop(double? value) {
    if (value == null) return null;
    return requireFiniteNonNegative(value, name: 'dragStartSlop');
  }

  static double requireFinitePositive(double value, {required String name}) {
    if (value.isFinite && value > 0) return value;
    throw ArgumentError.value(value, name, 'Must be a finite number > 0.');
  }

  static double requireFiniteNonNegative(double value, {required String name}) {
    if (value.isFinite && value >= 0) return value;
    throw ArgumentError.value(value, name, 'Must be a finite number >= 0.');
  }

  static double requireFiniteInUnitInterval(
    double value, {
    required String name,
  }) {
    if (value.isFinite && value >= 0 && value <= 1) return value;
    throw ArgumentError.value(
      value,
      name,
      'Must be a finite number within [0,1].',
    );
  }

  static void requireFiniteOffset(Offset value, {required String name}) {
    if (value.dx.isFinite && value.dy.isFinite) return;
    throw ArgumentError.value(value, name, 'Offset must be finite.');
  }
}
