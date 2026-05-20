import 'package:flutter/widgets.dart';

import 'canvas_resource.dart';
import 'canvas_runtime.dart';
import 'canvas_value_validators.dart';

final class CanvasSurface extends StatefulWidget {
  const CanvasSurface({
    required this.runtime,
    this.resourceResolver,
    this.selectionStyle = CanvasSelectionStyle.defaultStyle,
    this.gridStyle = CanvasGridStyle.defaultStyle,
    this.interactive = true,
    super.key,
  });

  final CanvasRuntime runtime;
  final CanvasResourceResolver? resourceResolver;
  final CanvasSelectionStyle selectionStyle;
  final CanvasGridStyle gridStyle;
  final bool interactive;

  @override
  State<CanvasSurface> createState() => _CanvasSurfaceState();
}

@immutable
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

final class _CanvasSurfaceState extends State<CanvasSurface> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
