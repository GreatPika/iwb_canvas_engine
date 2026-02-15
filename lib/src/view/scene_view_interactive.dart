import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../core/geometry.dart';
import '../core/pointer_input.dart';
import '../interactive/scene_controller_interactive.dart';
import '../public/canvas_pointer_input.dart';
import '../render/scene_painter.dart';
import '../render/scene_render_caches.dart';

ui.Image? _defaultImageResolver(String _) => null;

class SceneViewInteractive extends StatefulWidget {
  const SceneViewInteractive({
    required this.controller,
    this.imageResolver,
    this.selectionColor = const Color(0xFF1565C0),
    this.selectionStrokeWidth = 1,
    this.gridStrokeWidth = 1,
    super.key,
  });

  final SceneControllerInteractiveV2 controller;
  final ui.Image? Function(String imageId)? imageResolver;
  final Color selectionColor;
  final double selectionStrokeWidth;
  final double gridStrokeWidth;

  @override
  State<SceneViewInteractive> createState() => _SceneViewInteractiveState();
}

class _SceneViewInteractiveState extends State<SceneViewInteractive> {
  late PointerInputTracker _pointerTracker;
  Timer? _pendingTapTimer;
  int? _pendingTapFlushTimestampMs;
  int? _activePointerId;

  final Map<int, int> _pointerSlotByRawPointer = <int, int>{};
  final List<int> _freePointerSlots = <int>[];
  int _nextPointerSlotId = 1;
  int _lastEpoch = 0;

  late SceneRenderCaches _renderCaches;

  @override
  void initState() {
    super.initState();
    _renderCaches = _createRenderCaches();
    _lastEpoch = widget.controller.controllerEpoch;
    widget.controller.addListener(_handleControllerChanged);
    _pointerTracker = PointerInputTracker(
      settings: widget.controller.pointerSettings,
    );
  }

  @override
  void didUpdateWidget(SceneViewInteractive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _pointerTracker = PointerInputTracker(
        settings: widget.controller.pointerSettings,
      );
      _activePointerId = null;
      _clearPendingTapTimer();
      _pointerSlotByRawPointer.clear();
      _freePointerSlots.clear();
      _nextPointerSlotId = 1;
      _lastEpoch = widget.controller.controllerEpoch;
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
          nodePreviewOffsetResolver: widget.controller.movePreviewDeltaForNode,
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
    final pointerId = _resolvePointerId(event, phase);
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

    _captureActivePointer(sample);
    widget.controller.handlePointer(input);

    if (_shouldTrackSignals(sample)) {
      final signals = _pointerTracker.handle(sample);
      for (final signal in signals) {
        if (signal.type == PointerSignalType.doubleTap) {
          widget.controller.handleDoubleTap(
            position: signal.position,
            timestampMs: signal.timestampMs,
          );
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
    _renderCaches.clearAll();
  }

  void _handleControllerChanged() {
    final epoch = widget.controller.controllerEpoch;
    if (epoch == _lastEpoch) {
      return;
    }
    _lastEpoch = epoch;
    _clearAllCaches();
  }

  SceneRenderCaches _createRenderCaches() {
    return SceneRenderCaches();
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

  final SceneControllerInteractiveV2 controller;

  @override
  void paint(Canvas canvas, Size size) {
    final cameraOffset = controller.snapshot.camera.offset;
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

typedef SceneView = SceneViewInteractive;
