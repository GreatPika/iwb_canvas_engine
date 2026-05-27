import 'package:flutter/widgets.dart';

import '../contracts/public/canvas_surface.dart';
import 'canvas_resource.dart';
import 'canvas_runtime.dart';

export '../contracts/public/canvas_surface.dart';

/// Public API v1 declaration for [CanvasSurface].
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

final class _CanvasSurfaceState extends State<CanvasSurface> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
