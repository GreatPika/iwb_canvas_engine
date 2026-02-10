import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../core/geometry.dart';
import '../core/pointer_input.dart';
import '../interactive/scene_controller_interactive.dart';
import '../render/scene_painter.dart';

ui.Image? _defaultImageResolver(String _) => null;

class SceneViewInteractiveV2 extends StatefulWidget {
  const SceneViewInteractiveV2({
    required this.controller,
    this.imageResolver,
    this.staticLayerCache,
    this.textLayoutCache,
    this.strokePathCache,
    this.pathMetricsCache,
    this.selectionColor = const Color(0xFF1565C0),
    this.selectionStrokeWidth = 1,
    this.gridStrokeWidth = 1,
    super.key,
  });

  final SceneControllerInteractiveV2 controller;
  final ImageResolverV2? imageResolver;
  final SceneStaticLayerCacheV2? staticLayerCache;
  final SceneTextLayoutCacheV2? textLayoutCache;
  final SceneStrokePathCacheV2? strokePathCache;
  final ScenePathMetricsCacheV2? pathMetricsCache;
  final Color selectionColor;
  final double selectionStrokeWidth;
  final double gridStrokeWidth;

  @override
  State<SceneViewInteractiveV2> createState() => _SceneViewInteractiveV2State();
}

class _SceneViewInteractiveV2State extends State<SceneViewInteractiveV2> {
  late PointerInputTracker _pointerTracker;
  Timer? _pendingTapTimer;
  int? _pendingTapFlushTimestampMs;
  int? _activePointerId;

  final Map<int, int> _pointerSlotByRawPointer = <int, int>{};
  final List<int> _freePointerSlots = <int>[];
  int _nextPointerSlotId = 1;

  late SceneStaticLayerCacheV2 _staticLayerCache;
  late bool _ownsStaticLayerCache;
  late SceneTextLayoutCacheV2 _textLayoutCache;
  late bool _ownsTextLayoutCache;
  late SceneStrokePathCacheV2 _strokePathCache;
  late bool _ownsStrokePathCache;
  late ScenePathMetricsCacheV2 _pathMetricsCache;
  late bool _ownsPathMetricsCache;

  @override
  void initState() {
    super.initState();
    _pointerTracker = PointerInputTracker(
      settings: widget.controller.pointerSettings,
    );
    _initStaticLayerCache();
    _initTextLayoutCache();
    _initStrokePathCache();
    _initPathMetricsCache();
  }

  @override
  void didUpdateWidget(SceneViewInteractiveV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _pointerTracker = PointerInputTracker(
        settings: widget.controller.pointerSettings,
      );
      _activePointerId = null;
      _clearPendingTapTimer();
      _pointerSlotByRawPointer.clear();
      _freePointerSlots.clear();
      _nextPointerSlotId = 1;
      _clearAllCaches();
    }
    if (oldWidget.staticLayerCache != widget.staticLayerCache) {
      _syncStaticLayerCache();
    }
    if (oldWidget.textLayoutCache != widget.textLayoutCache) {
      _syncTextLayoutCache();
    }
    if (oldWidget.strokePathCache != widget.strokePathCache) {
      _syncStrokePathCache();
    }
    if (oldWidget.pathMetricsCache != widget.pathMetricsCache) {
      _syncPathMetricsCache();
    }
  }

  @override
  void dispose() {
    _clearPendingTapTimer();
    if (_ownsStaticLayerCache) {
      _staticLayerCache.dispose();
    }
    if (_ownsTextLayoutCache) {
      _textLayoutCache.clear();
    }
    if (_ownsStrokePathCache) {
      _strokePathCache.clear();
    }
    if (_ownsPathMetricsCache) {
      _pathMetricsCache.clear();
    }
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
        painter: ScenePainterV2(
          controller: widget.controller.core,
          imageResolver: widget.imageResolver ?? _defaultImageResolver,
          staticLayerCache: _staticLayerCache,
          textLayoutCache: _textLayoutCache,
          strokePathCache: _strokePathCache,
          pathMetricsCache: _pathMetricsCache,
          selectionRect: widget.controller.selectionRect,
          selectionColor: widget.selectionColor,
          selectionStrokeWidth: widget.selectionStrokeWidth,
          gridStrokeWidth: widget.gridStrokeWidth,
          textDirection: textDirection,
        ),
        foregroundPainter: _SceneInteractiveOverlayPainterV2(
          controller: widget.controller,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  void _handlePointerEvent(PointerEvent event, PointerPhase phase) {
    final pointerId = _resolvePointerId(event, phase);
    final sample = PointerSample(
      pointerId: pointerId,
      position: event.localPosition,
      timestampMs: event.timeStamp.inMilliseconds,
      phase: phase,
      kind: event.kind,
    );

    _captureActivePointer(sample);
    widget.controller.handlePointer(sample);

    if (_shouldTrackSignals(sample)) {
      final signals = _pointerTracker.handle(sample);
      for (final signal in signals) {
        if (signal.type == PointerSignalType.doubleTap) {
          widget.controller.handlePointerSignal(signal);
        }
      }
    }

    _syncPendingFlushTimer(referenceTimestampMs: sample.timestampMs);
    _releaseActivePointerIfEnded(sample);
    _releasePointerSlotIfEnded(event, phase);
  }

  bool _shouldTrackSignals(PointerSample sample) {
    final active = _activePointerId;
    return active == null || active == sample.pointerId;
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

    final signals = _pointerTracker.flushPending(flushTimestampMs);
    for (final signal in signals) {
      widget.controller.handlePointerSignal(signal);
    }
    _syncPendingFlushTimer(referenceTimestampMs: flushTimestampMs);
  }

  void _clearPendingTapTimer() {
    _pendingTapTimer?.cancel();
    _pendingTapTimer = null;
    _pendingTapFlushTimestampMs = null;
  }

  void _captureActivePointer(PointerSample sample) {
    if (sample.phase == PointerPhase.down && _activePointerId == null) {
      _activePointerId = sample.pointerId;
    }
  }

  void _releaseActivePointerIfEnded(PointerSample sample) {
    if (sample.phase != PointerPhase.up &&
        sample.phase != PointerPhase.cancel) {
      return;
    }
    if (_activePointerId != sample.pointerId) return;
    _activePointerId = null;
  }

  int _resolvePointerId(PointerEvent event, PointerPhase phase) {
    final rawPointer = event.pointer;
    final existing = _pointerSlotByRawPointer[rawPointer];
    if (existing != null) return existing;
    if (phase != PointerPhase.down) return rawPointer;

    final slotId = _acquirePointerSlot();
    _pointerSlotByRawPointer[rawPointer] = slotId;
    return slotId;
  }

  int _acquirePointerSlot() {
    if (_freePointerSlots.isEmpty) {
      return _nextPointerSlotId++;
    }

    var minIndex = 0;
    var minValue = _freePointerSlots.first;
    for (var i = 1; i < _freePointerSlots.length; i++) {
      final value = _freePointerSlots[i];
      if (value < minValue) {
        minValue = value;
        minIndex = i;
      }
    }
    _freePointerSlots.removeAt(minIndex);
    return minValue;
  }

  void _releasePointerSlotIfEnded(PointerEvent event, PointerPhase phase) {
    if (phase != PointerPhase.up && phase != PointerPhase.cancel) return;
    final slotId = _pointerSlotByRawPointer.remove(event.pointer);
    if (slotId == null) return;
    _freePointerSlots.add(slotId);
  }

  void _clearAllCaches() {
    _staticLayerCache.clear();
    _textLayoutCache.clear();
    _strokePathCache.clear();
    _pathMetricsCache.clear();
  }

  void _initStaticLayerCache() {
    final external = widget.staticLayerCache;
    if (external != null) {
      _staticLayerCache = external;
      _ownsStaticLayerCache = false;
      return;
    }
    _staticLayerCache = SceneStaticLayerCacheV2();
    _ownsStaticLayerCache = true;
  }

  void _syncStaticLayerCache() {
    if (_ownsStaticLayerCache) {
      _staticLayerCache.dispose();
    }
    _initStaticLayerCache();
  }

  void _initTextLayoutCache() {
    final external = widget.textLayoutCache;
    if (external != null) {
      _textLayoutCache = external;
      _ownsTextLayoutCache = false;
      return;
    }
    _textLayoutCache = SceneTextLayoutCacheV2();
    _ownsTextLayoutCache = true;
  }

  void _syncTextLayoutCache() {
    if (_ownsTextLayoutCache) {
      _textLayoutCache.clear();
    }
    _initTextLayoutCache();
  }

  void _initStrokePathCache() {
    final external = widget.strokePathCache;
    if (external != null) {
      _strokePathCache = external;
      _ownsStrokePathCache = false;
      return;
    }
    _strokePathCache = SceneStrokePathCacheV2();
    _ownsStrokePathCache = true;
  }

  void _syncStrokePathCache() {
    if (_ownsStrokePathCache) {
      _strokePathCache.clear();
    }
    _initStrokePathCache();
  }

  void _initPathMetricsCache() {
    final external = widget.pathMetricsCache;
    if (external != null) {
      _pathMetricsCache = external;
      _ownsPathMetricsCache = false;
      return;
    }
    _pathMetricsCache = ScenePathMetricsCacheV2();
    _ownsPathMetricsCache = true;
  }

  void _syncPathMetricsCache() {
    if (_ownsPathMetricsCache) {
      _pathMetricsCache.clear();
    }
    _initPathMetricsCache();
  }
}

class _SceneInteractiveOverlayPainterV2 extends CustomPainter {
  const _SceneInteractiveOverlayPainterV2({required this.controller})
    : super(repaint: controller);

  final SceneControllerInteractiveV2 controller;

  @override
  void paint(Canvas canvas, Size size) {
    final cameraOffset = controller.snapshot.camera.offset;
    _paintStrokePreview(canvas, cameraOffset);
    _paintLinePreview(canvas, cameraOffset);
  }

  @override
  bool shouldRepaint(covariant _SceneInteractiveOverlayPainterV2 oldDelegate) {
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
      canvas.drawCircle(
        toView(points.first, cameraOffset),
        thickness / 2,
        Paint()
          ..style = PaintingStyle.fill
          ..color = color,
      );
      return;
    }

    final path = Path()
      ..moveTo(
        points.first.dx - cameraOffset.dx,
        points.first.dy - cameraOffset.dy,
      );
    for (var i = 1; i < points.length; i++) {
      final point = points[i];
      path.lineTo(point.dx - cameraOffset.dx, point.dy - cameraOffset.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
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

typedef SceneView = SceneViewInteractiveV2;
