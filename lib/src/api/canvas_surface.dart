import 'package:flutter/widgets.dart';

import '../contracts/public/canvas_surface_styles.dart';
import '../frame/main_frame_painter.dart';
import '../frame/overlay_frame_painter.dart';
import 'canvas_resource.dart';
import 'canvas_runtime.dart';
import 'canvas_runtime_frame_bridge.dart';

export '../contracts/public/canvas_surface_styles.dart';

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

// The state is the public widget boundary where Flutter layout, runtime lookup,
// frame output construction, and passive painters meet for the passive frame proof path.
// ignore: coupling-between-object-classes
final class _CanvasSurfaceState extends State<CanvasSurface> {
  @override
  void didUpdateWidget(covariant CanvasSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interactive && !widget.interactive) {
      canvasRuntimeFrameRootForSurface(
        oldWidget.runtime,
      )?.handleSurfaceInteractiveDisabled();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.runtime.state,
      builder: (context, _, _) {
        final root = canvasRuntimeFrameRootForSurface(widget.runtime);
        if (root == null) {
          return const SizedBox.shrink();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final paintSize = _paintSizeFor(constraints);
            final viewport = Offset.zero & paintSize;
            final devicePixelRatio = _devicePixelRatioFor(context);
            final mainOutput = root.buildResourceFreeMainFrame(
              viewportWorldBounds: viewport,
              devicePixelRatio: devicePixelRatio,
              selectionStyle: widget.selectionStyle,
              gridStyle: widget.gridStyle,
            );
            final overlayOutput = root.buildResourceFreeOverlayFrame(
              viewportWorldBounds: viewport,
              devicePixelRatio: devicePixelRatio,
              selectionStyle: widget.selectionStyle,
              gridStyle: widget.gridStyle,
            );

            return CustomPaint(
              key: const ValueKey<String>('iwb_canvas_surface.paint_host'),
              painter: MainFramePainter(output: mainOutput),
              foregroundPainter: OverlayFramePainter(output: overlayOutput),
              size: paintSize,
            );
          },
        );
      },
    );
  }

  Size _paintSizeFor(BoxConstraints constraints) {
    return Size(
      constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0,
      constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0,
    );
  }

  double _devicePixelRatioFor(BuildContext context) {
    return MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
  }
}
