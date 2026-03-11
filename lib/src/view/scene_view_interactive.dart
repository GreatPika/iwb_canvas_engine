import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../core/geometry.dart';
import '../core/numeric_clamp.dart';
import '../core/pointer_input.dart';
import '../interactive/scene_controller_interactive.dart';
import '../contract/canvas_pointer_input.dart';
import '../render/scene_painter.dart';
import '../render/render_geometry_cache.dart';
import '../render/scene_render_caches.dart';
import 'scene_view_pointer_router.dart';

ui.Image? _defaultImageResolver(String _) => null;

@visibleForTesting
SceneRenderCaches debugSceneViewInteractiveRenderCachesOf(
  BuildContext context,
) {
  final state = switch (context) {
    StatefulElement(:final state) when state is _SceneViewInteractiveState =>
      state,
    _ => context.findAncestorStateOfType<_SceneViewInteractiveState>(),
  };
  if (state == null) {
    throw StateError(
      'No SceneViewInteractive state found for the provided BuildContext.',
    );
  }
  return SceneRenderCaches(
    staticLayerCache: state.debugStaticLayerCache,
    textLayoutCache: state.debugTextLayoutCache,
    strokePathCache: state.debugStrokePathCache,
    pathMetricsCache: state.debugPathMetricsCache,
    geometryCache: state.debugGeometryCache,
  );
}

class SceneViewInteractive extends StatefulWidget {
  const SceneViewInteractive({
    required this.controller,
    this.imageResolver,
    this.selectionColor = const Color(0xFF1565C0),
    this.selectionStrokeWidth = 1,
    this.gridStrokeWidth = 1,
    super.key,
  });

  final SceneControllerInteractive controller;
  final ui.Image? Function(String imageId)? imageResolver;
  final Color selectionColor;
  final double selectionStrokeWidth;
  final double gridStrokeWidth;

  @override
  State<SceneViewInteractive> createState() => _SceneViewInteractiveState();
}

class _SceneViewInteractiveState extends State<SceneViewInteractive> {
  late PointerInputTracker _pointerTracker;
  late PointerInputSettings _lastPointerSettings;
  PointerInputSettings? _pendingPointerSettings;
  Timer? _pendingTapTimer;
  int? _pendingTapFlushTimestampMs;
  final SceneViewPointerRouter _pointerRouter = SceneViewPointerRouter();
  int _lastEpoch = 0;

  late SceneRenderCaches _renderCaches;

  @visibleForTesting
  SceneStaticLayerCache get debugStaticLayerCache =>
      _renderCaches.staticLayerCache;
  @visibleForTesting
  SceneTextLayoutCache get debugTextLayoutCache =>
      _renderCaches.textLayoutCache;
  @visibleForTesting
  SceneStrokePathCache get debugStrokePathCache =>
      _renderCaches.strokePathCache;
  @visibleForTesting
  ScenePathMetricsCache get debugPathMetricsCache =>
      _renderCaches.pathMetricsCache;
  @visibleForTesting
  RenderGeometryCache get debugGeometryCache => _renderCaches.geometryCache;

  @override
  void initState() {
    super.initState();
    _renderCaches = _createRenderCaches();
    _lastEpoch = sceneControllerInteractiveInternalEpoch(widget.controller);
    widget.controller.addListener(_handleControllerChanged);
    _lastPointerSettings = widget.controller.pointerSettings;
    _pointerTracker = PointerInputTracker(settings: _lastPointerSettings);
  }

  @override
  void didUpdateWidget(SceneViewInteractive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _resetPointerTracking(settings: widget.controller.pointerSettings);
      _lastEpoch = sceneControllerInteractiveInternalEpoch(widget.controller);
      _clearAllCaches();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _clearPendingTapTimer();
    _renderCaches.disposeOwned();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) => _handlePointerEvent(event, PointerPhase.down),
      onPointerMove: (event) => _handlePointerEvent(event, PointerPhase.move),
      onPointerUp: (event) => _handlePointerEvent(event, PointerPhase.up),
      onPointerCancel: (event) =>
          _handlePointerEvent(event, PointerPhase.cancel),
      child: CustomPaint(
        painter: ScenePainter(
          controller: widget.controller,
          imageResolver: widget.imageResolver ?? _defaultImageResolver,
          nodePreviewOffsetResolver: (nodeId) =>
              sceneControllerInteractiveInternalPreviewDeltaForNode(
                widget.controller,
                nodeId,
              ),
          staticLayerCache: _renderCaches.staticLayerCache,
          textLayoutCache: _renderCaches.textLayoutCache,
          strokePathCache: _renderCaches.strokePathCache,
          pathMetricsCache: _renderCaches.pathMetricsCache,
          geometryCache: _renderCaches.geometryCache,
          selectionRect: widget.controller.selectionRect,
          selectionColor: widget.selectionColor,
          selectionStrokeWidth: widget.selectionStrokeWidth,
          gridStrokeWidth: widget.gridStrokeWidth,
          textDirection: textDirection,
        ),
        foregroundPainter: _SceneInteractiveOverlayPainter(
          controller: widget.controller,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  void _handlePointerEvent(PointerEvent event, PointerPhase phase) {
    final routedPointer = _pointerRouter.route(
      rawPointer: event.pointer,
      phase: phase,
    );
    if (routedPointer.isStray) {
      return;
    }

    final pointerId = routedPointer.pointerId;
    if (pointerId == null) {
      return;
    }
    final input = CanvasPointerInput(
      pointerId: pointerId,
      position: event.localPosition,
      timestampMs: event.timeStamp.inMilliseconds,
      phase: _toCanvasPointerPhase(phase),
      kind: event.kind,
    );
    final sample = PointerSample(
      pointerId: input.pointerId,
      position: input.position,
      timestampMs: input.timestampMs ?? event.timeStamp.inMilliseconds,
      phase: phase,
      kind: input.kind,
    );

    widget.controller.handlePointer(input);
    _handleTrackedSignals(sample);
    _syncPendingFlushTimer(referenceTimestampMs: sample.timestampMs);
    _releasePointerIfEnded(event.pointer, phase);
  }

  void _handleTrackedSignals(PointerSample sample) {
    if (!_pointerRouter.shouldTrackSignals(
      pointerId: sample.pointerId,
      phase: sample.phase,
    )) {
      return;
    }
    for (final signal in _pointerTracker.handle(sample)) {
      _handlePointerSignal(signal);
    }
  }

  void _handlePointerSignal(PointerSignal signal) {
    if (signal.type != PointerSignalType.doubleTap) {
      return;
    }
    widget.controller.handleDoubleTap(
      position: signal.position,
      timestampMs: signal.timestampMs,
    );
  }

  void _syncPendingFlushTimer({required int referenceTimestampMs}) {
    final nextFlushTimestampMs = _pointerTracker.nextPendingFlushTimestampMs;
    if (nextFlushTimestampMs == null) {
      _clearPendingTapTimer();
      return;
    }

    if (_pendingTapTimer != null &&
        _pendingTapFlushTimestampMs == nextFlushTimestampMs) {
      return;
    }

    _clearPendingTapTimer();
    _pendingTapFlushTimestampMs = nextFlushTimestampMs;
    final delayMs = (nextFlushTimestampMs - referenceTimestampMs).clamp(
      0,
      1 << 30,
    );
    _pendingTapTimer = Timer(
      Duration(milliseconds: delayMs),
      _handlePendingTapTimer,
    );
  }

  void _handlePendingTapTimer() {
    final flushTimestampMs = _pendingTapFlushTimestampMs;
    _pendingTapTimer = null;
    _pendingTapFlushTimestampMs = null;
    if (flushTimestampMs == null) return;

    // Timer flush emits deferred single taps only; double taps are emitted in
    // the immediate handle(...) path when the second tap arrives.
    _pointerTracker.flushPending(flushTimestampMs);
    _syncPendingFlushTimer(referenceTimestampMs: flushTimestampMs);
  }

  void _clearPendingTapTimer() {
    _pendingTapTimer?.cancel();
    _pendingTapTimer = null;
    _pendingTapFlushTimestampMs = null;
  }

  void _releasePointerIfEnded(int rawPointer, PointerPhase phase) {
    if (phase != PointerPhase.up && phase != PointerPhase.cancel) {
      return;
    }
    final release = _pointerRouter.release(rawPointer);
    if (release.isIdleAfterRelease) {
      _applyPendingPointerSettingsIfPossible();
    }
  }

  void _clearAllCaches() {
    _renderCaches.clearAll();
  }

  void _handleControllerChanged() {
    final nextPointerSettings = widget.controller.pointerSettings;
    if (!_pointerSettingsEqual(_lastPointerSettings, nextPointerSettings)) {
      if (_pointerRouter.hasLiveRawPointers) {
        _pendingPointerSettings = nextPointerSettings;
      } else {
        _resetPointerTracking(settings: nextPointerSettings);
      }
    }
    final epoch = sceneControllerInteractiveInternalEpoch(widget.controller);
    if (epoch == _lastEpoch) {
      return;
    }
    _lastEpoch = epoch;
    _clearAllCaches();
  }

  SceneRenderCaches _createRenderCaches() {
    return SceneRenderCaches();
  }

  void _resetPointerTracking({required PointerInputSettings settings}) {
    _pendingPointerSettings = null;
    _lastPointerSettings = settings;
    _pointerTracker = PointerInputTracker(settings: settings);
    _clearPendingTapTimer();
    _pointerRouter.reset();
  }

  void _applyPendingPointerSettingsIfPossible() {
    final pending = _pendingPointerSettings;
    if (pending == null || !_pointerRouter.isIdle) return;
    _resetPointerTracking(settings: pending);
  }

  bool _pointerSettingsEqual(
    PointerInputSettings left,
    PointerInputSettings right,
  ) {
    return left.tapSlop == right.tapSlop &&
        left.doubleTapSlop == right.doubleTapSlop &&
        left.doubleTapMaxDelayMs == right.doubleTapMaxDelayMs &&
        left.deferSingleTap == right.deferSingleTap;
  }

  CanvasPointerPhase _toCanvasPointerPhase(PointerPhase phase) {
    switch (phase) {
      case PointerPhase.down:
        return CanvasPointerPhase.down;
      case PointerPhase.move:
        return CanvasPointerPhase.move;
      case PointerPhase.up:
        return CanvasPointerPhase.up;
      case PointerPhase.cancel:
        return CanvasPointerPhase.cancel;
    }
  }
}

class _SceneInteractiveOverlayPainter extends CustomPainter {
  const _SceneInteractiveOverlayPainter({required this.controller})
    : super(repaint: controller);

  final SceneControllerInteractive controller;

  @override
  void paint(Canvas canvas, Size size) {
    final cameraOffset = sanitizeFiniteOffset(
      controller.snapshot.camera.offset,
    );
    _paintStrokePreview(canvas, cameraOffset);
    _paintLinePreview(canvas, cameraOffset);
  }

  @override
  bool shouldRepaint(covariant _SceneInteractiveOverlayPainter oldDelegate) {
    return oldDelegate.controller != controller;
  }

  void _paintStrokePreview(Canvas canvas, Offset cameraOffset) {
    if (!controller.hasActiveStrokePreview) {
      return;
    }

    final points = controller.activeStrokePreviewPoints;
    if (points.isEmpty) {
      return;
    }

    final thickness = controller.activeStrokePreviewThickness;
    if (!thickness.isFinite || thickness <= 0) {
      return;
    }

    final color = _applyOpacity(
      controller.activeStrokePreviewColor,
      controller.activeStrokePreviewOpacity,
    );

    if (points.length == 1) {
      _drawSinglePointStrokePreview(
        canvas: canvas,
        cameraOffset: cameraOffset,
        point: points.first,
        thickness: thickness,
        color: color,
      );
      return;
    }

    canvas.drawPath(
      _buildStrokePreviewPath(points, cameraOffset),
      _buildStrokePreviewPaint(thickness, color),
    );
  }

  void _drawSinglePointStrokePreview({
    required Canvas canvas,
    required Offset cameraOffset,
    required Offset point,
    required double thickness,
    required Color color,
  }) {
    canvas.drawCircle(
      toView(point, cameraOffset),
      thickness / 2,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color,
    );
  }

  Path _buildStrokePreviewPath(List<Offset> points, Offset cameraOffset) {
    final path = Path()
      ..moveTo(
        points.first.dx - cameraOffset.dx,
        points.first.dy - cameraOffset.dy,
      );
    for (var i = 1; i < points.length; i++) {
      final point = points[i];
      path.lineTo(point.dx - cameraOffset.dx, point.dy - cameraOffset.dy);
    }
    return path;
  }

  Paint _buildStrokePreviewPaint(double thickness, Color color) {
    return Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
  }

  void _paintLinePreview(Canvas canvas, Offset cameraOffset) {
    if (!controller.hasActiveLinePreview) {
      return;
    }

    final start = controller.activeLinePreviewStart;
    final end = controller.activeLinePreviewEnd;
    if (start == null || end == null) {
      return;
    }

    final thickness = controller.activeLinePreviewThickness;
    if (!thickness.isFinite || thickness <= 0) {
      return;
    }

    canvas.drawLine(
      toView(start, cameraOffset),
      toView(end, cameraOffset),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round
        ..color = controller.activeLinePreviewColor,
    );
  }

  Color _applyOpacity(Color color, double opacity) {
    final clamped = opacity.clamp(0.0, 1.0).toDouble();
    return color.withValues(alpha: clamped * color.a);
  }
}

typedef SceneView = SceneViewInteractive;
