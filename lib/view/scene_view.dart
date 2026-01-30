import 'dart:async';

import 'package:flutter/widgets.dart';

import '../input/pointer_input.dart';
import '../input/scene_controller.dart';
import '../render/scene_painter.dart';

class SceneView extends StatefulWidget {
  const SceneView({
    required this.controller,
    required this.imageResolver,
    this.selectionColor = const Color(0xFF1565C0),
    this.selectionStrokeWidth = 1,
    this.gridStrokeWidth = 1,
    super.key,
  });

  final SceneController controller;
  final ImageResolver imageResolver;
  final Color selectionColor;
  final double selectionStrokeWidth;
  final double gridStrokeWidth;

  @override
  State<SceneView> createState() => _SceneViewState();
}

class _SceneViewState extends State<SceneView> {
  late PointerInputTracker _pointerTracker;
  Timer? _pendingTapTimer;
  int _lastTimestampMs = 0;

  @override
  void initState() {
    super.initState();
    _pointerTracker = PointerInputTracker(
      settings: widget.controller.pointerSettings,
    );
  }

  @override
  void didUpdateWidget(SceneView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _pointerTracker = PointerInputTracker(
        settings: widget.controller.pointerSettings,
      );
      _pendingTapTimer?.cancel();
      _lastTimestampMs = 0;
    }
  }

  @override
  void dispose() {
    _pendingTapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) => _handlePointerEvent(
        event,
        PointerPhase.down,
      ),
      onPointerMove: (event) => _handlePointerEvent(
        event,
        PointerPhase.move,
      ),
      onPointerUp: (event) => _handlePointerEvent(
        event,
        PointerPhase.up,
      ),
      onPointerCancel: (event) => _handlePointerEvent(
        event,
        PointerPhase.cancel,
      ),
      child: CustomPaint(
        painter: ScenePainter(
          scene: widget.controller.scene,
          imageResolver: widget.imageResolver,
          selectedNodeIds: widget.controller.selectedNodeIds,
          selectionRect: widget.controller.selectionRect,
          selectionColor: widget.selectionColor,
          selectionStrokeWidth: widget.selectionStrokeWidth,
          gridStrokeWidth: widget.gridStrokeWidth,
          repaint: widget.controller,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  void _handlePointerEvent(PointerEvent event, PointerPhase phase) {
    final sample = PointerSample(
      pointerId: event.pointer,
      position: event.localPosition,
      timestampMs: event.timeStamp.inMilliseconds,
      phase: phase,
      kind: event.kind,
    );

    widget.controller.handlePointer(sample);

    final signals = _pointerTracker.handle(sample);
    _dispatchSignals(signals);
    _schedulePendingFlush(sample.timestampMs);
  }

  void _dispatchSignals(List<PointerSignal> signals) {
    for (final signal in signals) {
      if (signal.type == PointerSignalType.doubleTap) {
        widget.controller.handlePointerSignal(signal);
      }
    }
  }

  void _schedulePendingFlush(int timestampMs) {
    _lastTimestampMs = timestampMs;
    _pendingTapTimer?.cancel();
    final delayMs =
        widget.controller.pointerSettings.doubleTapMaxDelayMs + 1;
    _pendingTapTimer = Timer(Duration(milliseconds: delayMs), () {
      final flushTimestamp = _lastTimestampMs + delayMs;
      final signals = _pointerTracker.flushPending(flushTimestamp);
      _dispatchSignals(signals);
    });
  }
}
