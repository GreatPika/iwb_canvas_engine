import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'canvas_contract_limits.dart';
import 'canvas_pointer.dart';
import 'canvas_value_validators.dart';

enum CanvasInteractionMode { move, draw }

enum CanvasDrawTool { pencil, marker, line, eraser }

@immutable
final class CanvasDrawStyle {
  factory CanvasDrawStyle({
    CanvasDrawTool tool = CanvasDrawTool.pencil,
    Color color = const Color(0xFF000000),
    double pencilThickness = 3.0,
    double markerThickness = 12.0,
    double markerOpacity = 0.4,
    double lineThickness = 3.0,
    double eraserThickness = 20.0,
  }) {
    validatePositiveDouble(
      pencilThickness,
      path: 'drawStyle.pencilThickness',
      max: canvasMaxThickness,
    );
    validatePositiveDouble(
      markerThickness,
      path: 'drawStyle.markerThickness',
      max: canvasMaxThickness,
    );
    validateDoubleRange(
      markerOpacity,
      path: 'drawStyle.markerOpacity',
      min: 0,
      max: 1,
    );
    validatePositiveDouble(
      lineThickness,
      path: 'drawStyle.lineThickness',
      max: canvasMaxThickness,
    );
    validatePositiveDouble(
      eraserThickness,
      path: 'drawStyle.eraserThickness',
      max: canvasMaxThickness,
    );

    return CanvasDrawStyle._(
      tool: tool,
      color: color,
      pencilThickness: pencilThickness,
      markerThickness: markerThickness,
      markerOpacity: markerOpacity,
      lineThickness: lineThickness,
      eraserThickness: eraserThickness,
    );
  }

  const CanvasDrawStyle._({
    this.tool = CanvasDrawTool.pencil,
    this.color = const Color(0xFF000000),
    this.pencilThickness = 3.0,
    this.markerThickness = 12.0,
    this.markerOpacity = 0.4,
    this.lineThickness = 3.0,
    this.eraserThickness = 20.0,
  });

  static const defaultStyle = CanvasDrawStyle._();
  final CanvasDrawTool tool;
  final Color color;
  final double pencilThickness;
  final double markerThickness;
  final double markerOpacity;
  final double lineThickness;
  final double eraserThickness;

  @override
  bool operator ==(Object other) {
    return other is CanvasDrawStyle &&
        other.tool == tool &&
        other.color == color &&
        other.pencilThickness == pencilThickness &&
        other.markerThickness == markerThickness &&
        other.markerOpacity == markerOpacity &&
        other.lineThickness == lineThickness &&
        other.eraserThickness == eraserThickness;
  }

  @override
  int get hashCode {
    return Object.hash(
      tool,
      color,
      pencilThickness,
      markerThickness,
      markerOpacity,
      lineThickness,
      eraserThickness,
    );
  }
}

abstract interface class CanvasToolPort {
  CanvasInteractionMode get mode;
  CanvasDrawStyle get drawStyle;
  CanvasPointerPolicy get pointerPolicy;

  void setMode(CanvasInteractionMode mode);
  void setDrawStyle(CanvasDrawStyle style);
  void setDrawTool(CanvasDrawTool tool);
  void setDrawColor(Color color);
  void setPointerPolicy(CanvasPointerPolicy policy);
  void handlePointer(CanvasPointerSample sample);
  void handleDoubleTap({required Offset position, int? timestampMs});
}
