// CanvasSurface owns the public Flutter boundary wiring in one file so attach,
// detach, pointer, resource, and layer-cache ordering remain auditable.
// ignore_for_file: number-of-imports

import 'package:flutter/widgets.dart';

import '../api/canvas_runtime.dart';
import '../api/canvas_runtime_surface_bridge.dart';
import '../contracts/public/canvas_resource.dart';
import '../contracts/public/canvas_surface_styles.dart';
import '../resources/surface_resource_session.dart';
import 'image_bridge.dart';
import 'layer_frame_output_cache.dart';
import 'layer_paint_host.dart';
import 'pointer_adapter.dart';
import 'surface_frame_output_cache.dart';

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

// The state keeps attach, cleanup, paint, and detach ordering together so the
// temporal surface lifecycle is auditable at the Flutter boundary.
// Budget follow-up scheduling stays here so mounted/runtime/session identity
// guards remain beside attach, detach, and frame binding.
// ignore: coupling-between-object-classes, number-of-methods, response-for-class, weighted-methods-per-class
final class _CanvasSurfaceState extends State<CanvasSurface> {
  final Object _surfaceToken = Object();
  CanvasRuntime? _activeRuntime;
  CanvasRuntimeSurfacePort? _activePort;
  SurfaceResourceSession? _activeSession;
  final LayerFrameOutputCache _outputCache = LayerFrameOutputCache();
  bool _isSurfaceAttached = false;
  bool _hasPendingBudgetFollowUpFrame = false;
  bool _applyBudgetFollowUpOnNextBuild = false;

  @override
  void initState() {
    super.initState();
    _attachSurface(widget.runtime);
  }

  @override
  void didUpdateWidget(covariant CanvasSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.runtime, widget.runtime)) {
      if (oldWidget.interactive) {
        _activePort?.handleSurfaceInteractiveDisabled(_surfaceToken);
      }
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
    _activePort?.surfaceFrame.removeListener(_handleSurfaceFrame);
    if (widget.interactive) {
      _activePort?.handleSurfaceInteractiveDisabled(_surfaceToken);
    }
    _detachSurface();
    _outputCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final port = _currentSurfacePort();
    if (port == null) {
      return const SizedBox.shrink();
    }

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
    port.surfaceFrame.addListener(_handleSurfaceFrame);
  }

  CanvasRuntimeSurfacePort? _currentSurfacePort() {
    final port = _activePort;
    if (!_isSurfaceAttached ||
        !identical(_activeRuntime, widget.runtime) ||
        port == null) {
      return null;
    }
    final currentPort = canvasRuntimeSurfacePortFor(widget.runtime);
    if (identical(currentPort, port)) {
      return port;
    }

    _activePort?.surfaceFrame.removeListener(_handleSurfaceFrame);
    _isSurfaceAttached = false;
    _activeSession = null;
    _activeRuntime = null;
    _activePort = null;
    _hasPendingBudgetFollowUpFrame = false;
    _applyBudgetFollowUpOnNextBuild = false;
    _outputCache.clear();

    return null;
  }

  void _detachSurface() {
    final session = _activeSession;
    _activePort?.surfaceFrame.removeListener(_handleSurfaceFrame);
    _hasPendingBudgetFollowUpFrame = false;
    _applyBudgetFollowUpOnNextBuild = false;
    if (!_isSurfaceAttached) {
      session?.drop();
      _activeSession = null;
      _activeRuntime = null;
      _activePort = null;
      _outputCache.clear();

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
    _applyBudgetFollowUpOnNextBuild = false;
    _outputCache.clear();
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
    final inputs = _SurfaceFrameBuildInputs(
      runtime: widget.runtime,
      port: port,
      session: session,
      viewport: viewport,
      devicePixelRatio: devicePixelRatio,
      selectionStyle: widget.selectionStyle,
      gridStyle: widget.gridStyle,
    );
    _updateOutputCacheForBuildInputs(inputs);

    final paintHost = LayerPaintHost(
      paintSize: paintSize,
      mainOutputListenable: _outputCache.mainOutput,
      overlayOutputListenable: _outputCache.overlayOutput,
    );
    if (!widget.interactive) {
      return paintHost;
    }

    return CanvasSurfacePointerAdapter(
      routeInput: (input) {
        port.handlePointer(_surfaceToken, input);
      },
      child: paintHost,
    );
  }

  void _updateOutputCacheForBuildInputs(_SurfaceFrameBuildInputs inputs) {
    final previousMainOutput = _outputCache.mainOutput.value;
    _outputCache.updateLocalInputs(
      SurfaceFrameLocalInputKey(
        runtimeKey: inputs.runtime,
        viewportWorldBounds: inputs.viewport,
        devicePixelRatio: inputs.devicePixelRatio,
        selectionStyle: inputs.selectionStyle,
        gridStyle: inputs.gridStyle,
        resolverGeneration: inputs.session.resolverGeneration,
      ),
      buildMain: () => _buildMainOutput(inputs),
      buildOverlay: () => _buildOverlayOutput(inputs),
    );
    _outputCache.applyPendingRuntimeFrame(
      buildMain: () => _buildMainOutput(inputs),
      buildOverlay: () => _buildOverlayOutput(inputs),
    );
    if (_applyBudgetFollowUpOnNextBuild) {
      _applyBudgetFollowUpOnNextBuild = false;
      _outputCache.applyLocalRepaintRequest(
        SurfaceFrameLocalRepaintRequest.resourceBudgetFollowUp,
        buildMain: () => _buildMainOutput(inputs),
      );
    }
    if (!identical(previousMainOutput, _outputCache.mainOutput.value)) {
      _scheduleBudgetFollowUpFrameIfNeeded(
        runtime: inputs.runtime,
        port: inputs.port,
        session: inputs.session,
      );
    }
  }

  void _handleSurfaceFrame() {
    final frame = _activePort?.surfaceFrame.value;
    if (!_isSurfaceAttached || frame == null) {
      return;
    }
    if (mounted) {
      setState(() {
        _outputCache.queueRuntimeFrame(frame);
      });
    }
  }

  Object _buildMainOutput(_SurfaceFrameBuildInputs inputs) {
    final output = inputs.port.buildSurfaceMainFrame(
      _surfaceToken,
      viewportWorldBounds: inputs.viewport,
      devicePixelRatio: inputs.devicePixelRatio,
      selectionStyle: inputs.selectionStyle,
      gridStyle: inputs.gridStyle,
      bindAssets: const CanvasSurfaceImageBridge().bindAssets(inputs.session),
    );

    return output;
  }

  Object _buildOverlayOutput(_SurfaceFrameBuildInputs inputs) {
    return inputs.port.buildSurfaceOverlayFrame(
      _surfaceToken,
      viewportWorldBounds: inputs.viewport,
      devicePixelRatio: inputs.devicePixelRatio,
      selectionStyle: inputs.selectionStyle,
      gridStyle: inputs.gridStyle,
    );
  }

  Size _paintSizeFor(BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
      throw FlutterError(
        'CanvasSurface requires bounded width and height.\n'
        'Wrap CanvasSurface in SizedBox, Expanded, AspectRatio, or another '
        'widget that supplies finite layout constraints.',
      );
    }

    return constraints.biggest;
  }

  double _devicePixelRatioFor(BuildContext context) {
    return MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
  }

  void _scheduleBudgetFollowUpFrameIfNeeded({
    required CanvasRuntime runtime,
    required CanvasRuntimeSurfacePort port,
    required SurfaceResourceSession session,
  }) {
    if (_hasPendingBudgetFollowUpFrame ||
        !session.hasPendingBudgetFollowUpRepaint) {
      return;
    }
    _hasPendingBudgetFollowUpFrame = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !identical(_activeRuntime, runtime) ||
          !identical(_activePort, port) ||
          !identical(_activeSession, session) ||
          !identical(widget.runtime, runtime)) {
        _hasPendingBudgetFollowUpFrame = false;

        return;
      }
      setState(() {
        _hasPendingBudgetFollowUpFrame = false;
        _applyBudgetFollowUpOnNextBuild = true;
      });
    });
  }
}

final class _SurfaceFrameBuildInputs {
  const _SurfaceFrameBuildInputs({
    required this.runtime,
    required this.port,
    required this.session,
    required this.viewport,
    required this.devicePixelRatio,
    required this.selectionStyle,
    required this.gridStyle,
  });

  final CanvasRuntime runtime;
  final CanvasRuntimeSurfacePort port;
  final SurfaceResourceSession session;
  final Rect viewport;
  final double devicePixelRatio;
  final CanvasSelectionStyle selectionStyle;
  final CanvasGridStyle gridStyle;
}
