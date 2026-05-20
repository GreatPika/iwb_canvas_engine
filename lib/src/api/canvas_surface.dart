import 'package:flutter/widgets.dart';

import 'canvas_resource.dart';
import 'canvas_runtime.dart';

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
  const CanvasSelectionStyle({
    this.color = const Color(0xFF1565C0),
    this.strokeWidth = 1.0,
    this.marqueeFillOpacity = 0.15,
    this.haloWidth = 4.0,
  });

  static const defaultStyle = CanvasSelectionStyle();
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
  const CanvasGridStyle({this.strokeWidth = 1.0});
  static const defaultStyle = CanvasGridStyle();
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
