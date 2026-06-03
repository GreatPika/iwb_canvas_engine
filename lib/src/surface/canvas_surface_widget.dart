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
  CanvasRuntime? _activeRuntime;
  CanvasRuntimeSurfacePort? _activePort;
  bool _isSurfaceAttached = false;

  @override
  void initState() {
    super.initState();
    _attachSurface(widget.runtime);
  }

  @override
  void didUpdateWidget(covariant CanvasSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.runtime, widget.runtime)) {
      _detachSurface();
      _attachSurface(widget.runtime);

      return;
    }

    if (oldWidget.interactive && !widget.interactive) {
      _activePort?.handleSurfaceInteractiveDisabled(_surfaceToken);
    }
  }

  @override
  void dispose() {
    _detachSurface();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final port = _activePort;
    if (!_isSurfaceAttached ||
        !identical(_activeRuntime, widget.runtime) ||
        port == null) {
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
            return _buildPaintHost(
              port: port,
              paintSize: paintSize,
              viewport: viewport,
              devicePixelRatio: devicePixelRatio,
            );
          },
        );
      },
    );
  }

  void _attachSurface(CanvasRuntime runtime) {
    final port = canvasRuntimeSurfacePortFor(runtime);
    if (port == null) {
      return;
    }
    port.attachSurface(_surfaceToken);
    _activeRuntime = runtime;
    _activePort = port;
    _isSurfaceAttached = true;
  }

  void _detachSurface() {
    if (!_isSurfaceAttached) {
      _activeRuntime = null;
      _activePort = null;

      return;
    }
    _activePort?.detachSurface(_surfaceToken);
    _isSurfaceAttached = false;
    _activeRuntime = null;
    _activePort = null;
  }

  Widget _buildPaintHost({
    required CanvasRuntimeSurfacePort port,
    required Size paintSize,
    required Rect viewport,
    required double devicePixelRatio,
  }) {
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
