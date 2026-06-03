import 'package:flutter/widgets.dart';

import '../api/canvas_runtime.dart';
import '../api/canvas_runtime_surface_bridge.dart';
import '../contracts/public/canvas_resource.dart';
import '../contracts/public/canvas_surface_styles.dart';
import '../frame/paint_asset_binding_service.dart';
import 'main_painter.dart';
import 'overlay_painter.dart';

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
  final Object _surfaceToken = Object();

  @override
  void didUpdateWidget(covariant CanvasSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interactive && !widget.interactive) {
      canvasRuntimeSurfacePortFor(
        oldWidget.runtime,
      )?.handleSurfaceInteractiveDisabled(_surfaceToken);
    }
  }

  @override
  Widget build(BuildContext context) {
    final port = canvasRuntimeSurfacePortFor(widget.runtime);
    if (port == null) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder(
      valueListenable: port.state,
      builder: (context, _, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final paintSize = _paintSizeFor(constraints);
            final viewport = Offset.zero & paintSize;
            final devicePixelRatio = _devicePixelRatioFor(context);
            final mainOutput = port.buildSurfaceMainFrame(
              _surfaceToken,
              viewportWorldBounds: viewport,
              devicePixelRatio: devicePixelRatio,
              selectionStyle: widget.selectionStyle,
              gridStyle: widget.gridStyle,
              bindAssets: _emptyAssetBindings,
            );
            final overlayOutput = port.buildSurfaceOverlayFrame(
              _surfaceToken,
              viewportWorldBounds: viewport,
              devicePixelRatio: devicePixelRatio,
              selectionStyle: widget.selectionStyle,
              gridStyle: widget.gridStyle,
            );

            return CustomPaint(
              key: const ValueKey<String>('iwb_canvas_surface.paint_host'),
              painter: MainSurfacePainter(output: mainOutput),
              foregroundPainter: OverlaySurfacePainter(output: overlayOutput),
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

FrameAssetBindings _emptyAssetBindings({
  required Object frame,
  required Iterable<Object> records,
}) {
  return FrameAssetBindings.empty;
}
