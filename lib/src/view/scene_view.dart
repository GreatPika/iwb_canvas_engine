import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../input/pointer_input.dart';
import '../input/scene_controller.dart';
import '../render/scene_painter.dart';

ui.Image? _defaultImageResolver(String _) => null;

/// Callback invoked by [SceneView] for each pointer sample it processes.
///
/// Notes:
/// - [PointerSample.position] is in view/screen coordinates (as received from
///   `PointerEvent.localPosition`).
/// - Keep callbacks fast and side-effect free where possible; they run on the
///   UI thread.
/// - Callbacks cannot cancel the default controller handling. Use them to
///   observe or to apply app-level logic (e.g., expand selection, snap on drop).
typedef SceneViewPointerSampleCallback =
    void Function(SceneController controller, PointerSample sample);

/// A self-contained widget that renders a [SceneController] and feeds it input.
///
/// Pointer events are forwarded to [SceneController] in view/screen coordinates
/// (as received from `PointerEvent.localPosition`). The controller converts them
/// to scene coordinates using `scene.camera.offset`.
///
/// The view repaints via [SceneController] as a [CustomPainter] notifier.
class SceneView extends StatefulWidget {
  /// Creates a view for the provided [controller].
  ///
  /// If [controller] is null, the view creates and owns a controller with an
  /// empty scene. Use [onControllerReady] to access the internal controller once
  /// it is created.
  ///
  /// When [controller] is null, [pointerSettings], [dragStartSlop], and
  /// [nodeIdGenerator] are used to configure the internal controller.
  /// These parameters are ignored when an external [controller] is provided.
  ///
  /// If [staticLayerCache] is null, the view creates and owns an internal cache
  /// and disposes it when the view is disposed. If a cache is provided, the
  /// caller owns it and must dispose it.
  ///
  /// If [textLayoutCache] / [strokePathCache] are null, the view creates and
  /// owns internal LRU caches to reduce per-frame work. If caches are provided,
  /// the caller owns them.
  ///
  /// [onPointerSampleBefore] / [onPointerSampleAfter] let apps hook into the
  /// pointer pipeline without re-implementing input dispatch. The call order
  /// for each pointer sample is:
  /// 1) Create [PointerSample] from the Flutter event
  /// 2) Invoke [onPointerSampleBefore]
  /// 3) Call `controller.handlePointer(sample)`
  /// 4) Invoke [onPointerSampleAfter]
  /// 5) Process internal pointer signals (double-tap) and schedule pending flush
  ///
  /// Callbacks run synchronously and must not block for long.
  ///
  /// [thinLineSnapStrategy] controls optional pixel-grid snapping for thin
  /// axis-aligned lines/strokes in [ScenePainter]. This can improve crispness
  /// for 1 logical px lines on HiDPI displays.
  const SceneView({
    this.controller,
    this.imageResolver,
    this.staticLayerCache,
    this.textLayoutCache,
    this.strokePathCache,
    this.onPointerSampleBefore,
    this.onPointerSampleAfter,
    this.onControllerReady,
    this.pointerSettings,
    this.dragStartSlop,
    this.nodeIdGenerator,
    this.selectionColor = const Color(0xFF1565C0),
    this.selectionStrokeWidth = 1,
    this.gridStrokeWidth = 1,
    this.thinLineSnapStrategy = ThinLineSnapStrategy.autoAxisAlignedThin,
    super.key,
  });

  final SceneController? controller;
  final ImageResolver? imageResolver;
  final SceneStaticLayerCache? staticLayerCache;
  final SceneTextLayoutCache? textLayoutCache;
  final SceneStrokePathCache? strokePathCache;
  final SceneViewPointerSampleCallback? onPointerSampleBefore;
  final SceneViewPointerSampleCallback? onPointerSampleAfter;
  final ValueChanged<SceneController>? onControllerReady;
  final PointerInputSettings? pointerSettings;
  final double? dragStartSlop;
  final String Function()? nodeIdGenerator;
  final Color selectionColor;
  final double selectionStrokeWidth;
  final double gridStrokeWidth;
  final ThinLineSnapStrategy thinLineSnapStrategy;

  @override
  State<SceneView> createState() => _SceneViewState();
}

class _SceneViewState extends State<SceneView> {
  late PointerInputTracker _pointerTracker;
  late SceneStaticLayerCache _staticLayerCache;
  late bool _ownsStaticLayerCache;
  late SceneTextLayoutCache _textLayoutCache;
  late bool _ownsTextLayoutCache;
  late SceneStrokePathCache _strokePathCache;
  late bool _ownsStrokePathCache;
  Timer? _pendingTapTimer;
  int _lastTimestampMs = 0;
  SceneController? _ownedController;

  SceneController get _controller => widget.controller ?? _ownedController!;

  @visibleForTesting
  SceneStaticLayerCache get debugStaticLayerCache => _staticLayerCache;
  @visibleForTesting
  SceneTextLayoutCache get debugTextLayoutCache => _textLayoutCache;
  @visibleForTesting
  SceneStrokePathCache get debugStrokePathCache => _strokePathCache;

  @override
  void initState() {
    super.initState();
    _ensureController();
    _initStaticLayerCache();
    _initTextLayoutCache();
    _initStrokePathCache();
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
    if (oldWidget.textLayoutCache != widget.textLayoutCache) {
      _syncTextLayoutCache();
    }
    if (oldWidget.strokePathCache != widget.strokePathCache) {
      _syncStrokePathCache();
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
    if (_ownsTextLayoutCache) {
      _textLayoutCache.clear();
    }
    if (_ownsStrokePathCache) {
      _strokePathCache.clear();
    }
    _disposeOwnedController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = View.maybeOf(context);
    final devicePixelRatio = view?.devicePixelRatio ?? 1.0;
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
          imageResolver: widget.imageResolver ?? _defaultImageResolver,
          staticLayerCache: _staticLayerCache,
          textLayoutCache: _textLayoutCache,
          strokePathCache: _strokePathCache,
          selectionColor: widget.selectionColor,
          selectionStrokeWidth: widget.selectionStrokeWidth,
          gridStrokeWidth: widget.gridStrokeWidth,
          devicePixelRatio: devicePixelRatio,
          thinLineSnapStrategy: widget.thinLineSnapStrategy,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  void _initTextLayoutCache() {
    final external = widget.textLayoutCache;
    if (external != null) {
      _textLayoutCache = external;
      _ownsTextLayoutCache = false;
      return;
    }
    _textLayoutCache = SceneTextLayoutCache();
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
    _strokePathCache = SceneStrokePathCache();
    _ownsStrokePathCache = true;
  }

  void _syncStrokePathCache() {
    if (_ownsStrokePathCache) {
      _strokePathCache.clear();
    }
    _initStrokePathCache();
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

    widget.onPointerSampleBefore?.call(controller, sample);
    controller.handlePointer(sample);
    widget.onPointerSampleAfter?.call(controller, sample);

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
    _ownedController = SceneController(
      pointerSettings: widget.pointerSettings,
      dragStartSlop: widget.dragStartSlop,
      nodeIdGenerator: widget.nodeIdGenerator,
    );
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
