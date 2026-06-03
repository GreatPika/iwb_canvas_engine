import 'package:flutter/widgets.dart';

import '../api/canvas_runtime.dart';
import '../api/canvas_runtime_surface_bridge.dart';
import '../contracts/public/canvas_resource.dart';
import '../contracts/public/canvas_surface_styles.dart';
import '../resources/surface_resource_session.dart';
import 'image_bridge.dart';
import 'main_painter.dart';
import 'overlay_painter.dart';
import 'pointer_adapter.dart';

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
  SurfaceResourceSession? _activeSession;
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

    if (!identical(oldWidget.resourceResolver, widget.resourceResolver)) {
      _activeSession?.replaceResolver(widget.resourceResolver);
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
    SurfaceResourceSession? session;
    try {
      port.attachSurface(_surfaceToken);
      session = SurfaceResourceSession(
        resolver: widget.resourceResolver,
        mutationGuard: port.resolverMutationGuard,
      );
      port.installSurfaceResourceSession(_surfaceToken, session);
    } catch (_) {
      session?.drop();
      port.detachSurface(_surfaceToken);
      rethrow;
    }
    _activeRuntime = runtime;
    _activePort = port;
    _activeSession = session;
    _isSurfaceAttached = true;
  }

  void _detachSurface() {
    final session = _activeSession;
    if (!_isSurfaceAttached) {
      session?.drop();
      _activeSession = null;
      _activeRuntime = null;
      _activePort = null;

      return;
    }
    final didRuntimeDetach = _activePort?.detachSurface(_surfaceToken) ?? false;
    if (!didRuntimeDetach) {
      session?.drop();
    }
    _isSurfaceAttached = false;
    _activeSession = null;
    _activeRuntime = null;
    _activePort = null;
  }

  Widget _buildPaintHost({
    required CanvasRuntimeSurfacePort port,
    required Size paintSize,
    required Rect viewport,
    required double devicePixelRatio,
  }) {
    final session = _activeSession;
    if (session == null) {
      return const SizedBox.shrink();
    }
    final mainOutput = port.buildSurfaceMainFrame(
      _surfaceToken,
      viewportWorldBounds: viewport,
      devicePixelRatio: devicePixelRatio,
      selectionStyle: widget.selectionStyle,
      gridStyle: widget.gridStyle,
      bindAssets: const CanvasSurfaceImageBridge().bindAssets(session),
    );
    final overlayOutput = port.buildSurfaceOverlayFrame(
      _surfaceToken,
      viewportWorldBounds: viewport,
      devicePixelRatio: devicePixelRatio,
      selectionStyle: widget.selectionStyle,
      gridStyle: widget.gridStyle,
    );

    final paintHost = CustomPaint(
      key: const ValueKey<String>('iwb_canvas_surface.paint_host'),
      painter: MainFramePainter(output: mainOutput),
      foregroundPainter: OverlayFramePainter(output: overlayOutput),
      size: paintSize,
    );
    if (!widget.interactive) {
      return paintHost;
    }

    return CanvasSurfacePointerAdapter(
      routeSample: (sample) {
        port.handlePointer(_surfaceToken, sample);
      },
      child: paintHost,
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
