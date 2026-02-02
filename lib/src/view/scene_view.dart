import 'dart:async';

import 'package:flutter/widgets.dart';

import '../input/pointer_input.dart';
import '../input/scene_controller.dart';
import '../render/scene_painter.dart';

/// A self-contained widget that renders a [SceneController] and feeds it input.
///
/// The view repaints via [SceneController] as a [CustomPainter] notifier.
class SceneView extends StatefulWidget {
  /// Creates a view for the provided [controller].
  ///
  /// If [controller] is null, the view creates and owns a controller with an
  /// empty scene. Use [onControllerReady] to access the internal controller once
  /// it is created.
  ///
  /// If [staticLayerCache] is null, the view creates and owns an internal cache
  /// and disposes it when the view is disposed. If a cache is provided, the
  /// caller owns it and must dispose it.
  const SceneView({
    this.controller,
    required this.imageResolver,
    this.staticLayerCache,
    this.onControllerReady,
    this.selectionColor = const Color(0xFF1565C0),
    this.selectionStrokeWidth = 1,
    this.gridStrokeWidth = 1,
    super.key,
  });

  final SceneController? controller;
  final ImageResolver imageResolver;
  final SceneStaticLayerCache? staticLayerCache;
  final ValueChanged<SceneController>? onControllerReady;
  final Color selectionColor;
  final double selectionStrokeWidth;
  final double gridStrokeWidth;

  @override
  State<SceneView> createState() => _SceneViewState();
}

class _SceneViewState extends State<SceneView> {
  late PointerInputTracker _pointerTracker;
  late SceneStaticLayerCache _staticLayerCache;
  late bool _ownsStaticLayerCache;
  Timer? _pendingTapTimer;
  int _lastTimestampMs = 0;
  SceneController? _ownedController;

  SceneController get _controller => widget.controller ?? _ownedController!;

  @visibleForTesting
  SceneStaticLayerCache get debugStaticLayerCache => _staticLayerCache;

  @override
  void initState() {
    super.initState();
    _ensureController();
    _initStaticLayerCache();
    _pointerTracker = PointerInputTracker(
      settings: _controller.pointerSettings,
    );
  }

  @override
  void didUpdateWidget(SceneView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.staticLayerCache != widget.staticLayerCache) {
      _syncStaticLayerCache();
    }
    final controllerChanged = oldWidget.controller != widget.controller;
    if (controllerChanged) {
      if (oldWidget.controller == null && widget.controller != null) {
        _disposeOwnedController();
      } else if (oldWidget.controller != null && widget.controller == null) {
        _ensureController();
      }
    }
    if (controllerChanged ||
        (widget.controller == null && _ownedController == null)) {
      _pointerTracker = PointerInputTracker(
        settings: _controller.pointerSettings,
      );
      _pendingTapTimer?.cancel();
      _lastTimestampMs = 0;
    }
  }

  @override
  void dispose() {
    _pendingTapTimer?.cancel();
    if (_ownsStaticLayerCache) {
      _staticLayerCache.dispose();
    }
    _disposeOwnedController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) => _handlePointerEvent(event, PointerPhase.down),
      onPointerMove: (event) => _handlePointerEvent(event, PointerPhase.move),
      onPointerUp: (event) => _handlePointerEvent(event, PointerPhase.up),
      onPointerCancel: (event) =>
          _handlePointerEvent(event, PointerPhase.cancel),
      child: CustomPaint(
        painter: ScenePainter(
          controller: _controller,
          imageResolver: widget.imageResolver,
          staticLayerCache: _staticLayerCache,
          selectionColor: widget.selectionColor,
          selectionStrokeWidth: widget.selectionStrokeWidth,
          gridStrokeWidth: widget.gridStrokeWidth,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  void _handlePointerEvent(PointerEvent event, PointerPhase phase) {
    final controller = _controller;
    final sample = PointerSample(
      pointerId: event.pointer,
      position: event.localPosition,
      timestampMs: event.timeStamp.inMilliseconds,
      phase: phase,
      kind: event.kind,
    );

    controller.handlePointer(sample);

    final signals = _pointerTracker.handle(sample);
    _dispatchSignals(signals);
    _schedulePendingFlush(sample.timestampMs);
  }

  void _dispatchSignals(List<PointerSignal> signals) {
    final controller = _controller;
    for (final signal in signals) {
      if (signal.type == PointerSignalType.doubleTap) {
        controller.handlePointerSignal(signal);
      }
    }
  }

  void _schedulePendingFlush(int timestampMs) {
    _lastTimestampMs = timestampMs;
    _pendingTapTimer?.cancel();
    final delayMs = _controller.pointerSettings.doubleTapMaxDelayMs + 1;
    _pendingTapTimer = Timer(Duration(milliseconds: delayMs), () {
      final flushTimestamp = _lastTimestampMs + delayMs;
      final signals = _pointerTracker.flushPending(flushTimestamp);
      _dispatchSignals(signals);
    });
  }

  void _ensureController() {
    if (widget.controller != null) return;
    if (_ownedController != null) return;
    _ownedController = SceneController();
    widget.onControllerReady?.call(_ownedController!);
  }

  void _disposeOwnedController() {
    _ownedController?.dispose();
    _ownedController = null;
  }

  void _initStaticLayerCache() {
    final providedCache = widget.staticLayerCache;
    if (providedCache != null) {
      _staticLayerCache = providedCache;
      _ownsStaticLayerCache = false;
      return;
    }
    _staticLayerCache = SceneStaticLayerCache();
    _ownsStaticLayerCache = true;
  }

  void _syncStaticLayerCache() {
    final providedCache = widget.staticLayerCache;
    if (providedCache != null) {
      if (_ownsStaticLayerCache) {
        _staticLayerCache.dispose();
      }
      _staticLayerCache = providedCache;
      _ownsStaticLayerCache = false;
      return;
    }

    if (!_ownsStaticLayerCache) {
      _staticLayerCache = SceneStaticLayerCache();
      _ownsStaticLayerCache = true;
    }
  }
}
