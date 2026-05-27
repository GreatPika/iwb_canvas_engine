import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'canvas_value_validators.dart';

@immutable
/// Public API v1 declaration for [CanvasSelectionStyle].
final class CanvasSelectionStyle {
  factory CanvasSelectionStyle({
    Color color = const Color(0xFF1565C0),
    double strokeWidth = 1.0,
    double marqueeFillOpacity = 0.15,
    double haloWidth = 4.0,
  }) {
    validateNonNegativeDouble(strokeWidth, path: 'selectionStyle.strokeWidth');
    validateDoubleRange(
      marqueeFillOpacity,
      path: 'selectionStyle.marqueeFillOpacity',
      min: 0,
      max: 1,
    );
    validateNonNegativeDouble(haloWidth, path: 'selectionStyle.haloWidth');

    return CanvasSelectionStyle._(
      color: color,
      strokeWidth: strokeWidth,
      marqueeFillOpacity: marqueeFillOpacity,
      haloWidth: haloWidth,
    );
  }

  const CanvasSelectionStyle._({
    required this.color,
    required this.strokeWidth,
    required this.marqueeFillOpacity,
    required this.haloWidth,
  });

  static const defaultStyle = CanvasSelectionStyle._(
    color: Color(0xFF1565C0),
    strokeWidth: 1.0,
    marqueeFillOpacity: 0.15,
    haloWidth: 4.0,
  );
  final Color color;
  final double strokeWidth;
  final double marqueeFillOpacity;
  final double haloWidth;

  @override
  bool operator ==(Object other) {
    return other is CanvasSelectionStyle &&
        other.color == color &&
        other.strokeWidth == strokeWidth &&
        other.marqueeFillOpacity == marqueeFillOpacity &&
        other.haloWidth == haloWidth;
  }

  @override
  int get hashCode {
    return Object.hash(color, strokeWidth, marqueeFillOpacity, haloWidth);
  }
}

@immutable
/// Public API v1 declaration for [CanvasGridStyle].
final class CanvasGridStyle {
  factory CanvasGridStyle({double strokeWidth = 1.0}) {
    validateNonNegativeDouble(strokeWidth, path: 'gridStyle.strokeWidth');

    return CanvasGridStyle._(strokeWidth: strokeWidth);
  }

  const CanvasGridStyle._({required this.strokeWidth});

  static const defaultStyle = CanvasGridStyle._(strokeWidth: 1.0);
  final double strokeWidth;

  @override
  bool operator ==(Object other) {
    return other is CanvasGridStyle && other.strokeWidth == strokeWidth;
  }

  @override
  int get hashCode => strokeWidth.hashCode;
}
