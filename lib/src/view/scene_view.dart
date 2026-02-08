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
  /// When this widget owns the controller, updating these parameters at
  /// runtime reconfigures the existing controller via
  /// [SceneController.reconfigureInput]. If a pointer gesture is active, the
  /// new settings are applied after that gesture ends.
  ///
  /// If [staticLayerCache] is null, the view creates and owns an internal cache
  /// and disposes it when the view is disposed. If a cache is provided, the
  /// caller owns it and must dispose it.
  ///
  /// If [textLayoutCache] / [strokePathCache] are null, the view creates and
  /// [pathMetricsCache] are null, the view creates and owns internal LRU caches
  /// to reduce per-frame work. If caches are provided, the caller owns them.
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
    this.pathMetricsCache,
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
  final ScenePathMetricsCache? pathMetricsCache;
  final SceneViewPointerSampleCallback? onPointerSampleBefore;
  final SceneViewPointerSampleCallback? onPointerSampleAfter;
  final ValueChanged<SceneController>? onControllerReady;

  /// Pointer signal/tap thresholds for the owned controller.
  final PointerInputSettings? pointerSettings;

  /// Drag threshold override for the owned controller.
  final double? dragStartSlop;

  /// Custom node ID generator for nodes created by the owned controller.
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
  late ScenePathMetricsCache _pathMetricsCache;
  late bool _ownsPathMetricsCache;
  Timer? _pendingTapTimer;
  int? _pendingTapFlushTimestampMs;
  SceneController? _ownedController;
  int? _activePointerId;
  bool _pendingPointerTrackerRefresh = false;
  final Map<int, int> _pointerSlotByRawPointer = <int, int>{};
  final List<int> _freePointerSlots = <int>[];
  int _nextPointerSlotId = 1;

  SceneController get _controller => widget.controller ?? _ownedController!;

  @visibleForTesting
  SceneStaticLayerCache get debugStaticLayerCache => _staticLayerCache;
  @visibleForTesting
  SceneTextLayoutCache get debugTextLayoutCache => _textLayoutCache;
  @visibleForTesting
  SceneStrokePathCache get debugStrokePathCache => _strokePathCache;
  @visibleForTesting
  ScenePathMetricsCache get debugPathMetricsCache => _pathMetricsCache;
  @visibleForTesting
  bool get debugHasPendingTapTimer => _pendingTapTimer != null;
  @visibleForTesting
  int? get debugPendingTapFlushTimestampMs => _pendingTapFlushTimestampMs;

  @override
  void initState() {
    super.initState();
    _ensureController();
    _initStaticLayerCache();
    _initTextLayoutCache();
    _initStrokePathCache();
    _initPathMetricsCache();
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
    if (oldWidget.pathMetricsCache != widget.pathMetricsCache) {
      _syncPathMetricsCache();
    }
    final controllerChanged = oldWidget.controller != widget.controller;
    if (controllerChanged) {
      if (oldWidget.controller == null && widget.controller != null) {
        _disposeOwnedController();
      } else if (oldWidget.controller != null && widget.controller == null) {
        _ensureController();
      }
    }
    final ownsController =
        widget.controller == null && _ownedController != null;
    if (ownsController && _ownedInputConfigChanged(oldWidget)) {
      _ownedController!.reconfigureInput(
        pointerSettings: _resolvedPointerSettings(widget.pointerSettings),
        dragStartSlop: widget.dragStartSlop,
        nodeIdGenerator: widget.nodeIdGenerator,
      );
      if (_activePointerId != null) {
        _pendingPointerTrackerRefresh = true;
      } else {
        _resetPointerTracker();
      }
    }
    if (controllerChanged ||
        (widget.controller == null && _ownedController == null)) {
      _activePointerId = null;
      _pendingPointerTrackerRefresh = false;
      _resetPointerTracker();
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
    if (_ownsPathMetricsCache) {
      _pathMetricsCache.clear();
    }
    _disposeOwnedController();
    _pointerSlotByRawPointer.clear();
    _freePointerSlots.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = View.maybeOf(context);
    final devicePixelRatio = view?.devicePixelRatio ?? 1.0;
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
          controller: _controller,
          imageResolver: widget.imageResolver ?? _defaultImageResolver,
          staticLayerCache: _staticLayerCache,
          textLayoutCache: _textLayoutCache,
          strokePathCache: _strokePathCache,
          pathMetricsCache: _pathMetricsCache,
          selectionColor: widget.selectionColor,
          selectionStrokeWidth: widget.selectionStrokeWidth,
          gridStrokeWidth: widget.gridStrokeWidth,
          devicePixelRatio: devicePixelRatio,
          thinLineSnapStrategy: widget.thinLineSnapStrategy,
          textDirection: textDirection,
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

  void _initPathMetricsCache() {
    final external = widget.pathMetricsCache;
    if (external != null) {
      _pathMetricsCache = external;
      _ownsPathMetricsCache = false;
      return;
    }
    _pathMetricsCache = ScenePathMetricsCache();
    _ownsPathMetricsCache = true;
  }

  void _syncPathMetricsCache() {
    if (_ownsPathMetricsCache) {
      _pathMetricsCache.clear();
    }
    _initPathMetricsCache();
  }

  void _handlePointerEvent(PointerEvent event, PointerPhase phase) {
    final controller = _controller;
    final pointerId = _resolvePointerId(event, phase);
    final sample = PointerSample(
      pointerId: pointerId,
      position: event.localPosition,
      // Raw host timestamp is only a hint; SceneController normalizes it into
      // an internal monotonic timeline for emitted actions/signals.
      timestampMs: event.timeStamp.inMilliseconds,
      phase: phase,
      kind: event.kind,
    );
    _captureActivePointer(sample);

    widget.onPointerSampleBefore?.call(controller, sample);
    controller.handlePointer(sample);
    widget.onPointerSampleAfter?.call(controller, sample);

    if (_shouldTrackSignals(sample)) {
      final signals = _pointerTracker.handle(sample);
      _dispatchSignals(signals);
    }
    _syncPendingFlushTimer(referenceTimestampMs: sample.timestampMs);
    _releaseActivePointerIfEnded(sample);
    _releasePointerSlotIfEnded(event, phase);
  }

  void _dispatchSignals(List<PointerSignal> signals) {
    final controller = _controller;
    for (final signal in signals) {
      if (signal.type == PointerSignalType.doubleTap) {
        controller.handlePointerSignal(signal);
      }
    }
  }

  bool _shouldTrackSignals(PointerSample sample) {
    final activePointerId = _activePointerId;
    return activePointerId == null || activePointerId == sample.pointerId;
  }

  void _syncPendingFlushTimer({required int referenceTimestampMs}) {
    final nextFlushTimestampMs = _pointerTracker.nextPendingFlushTimestampMs;
    if (nextFlushTimestampMs == null) {
      _pendingTapTimer?.cancel();
      _pendingTapTimer = null;
      _pendingTapFlushTimestampMs = null;
      return;
    }

    if (_pendingTapTimer != null &&
        _pendingTapFlushTimestampMs == nextFlushTimestampMs) {
      return;
    }

    _pendingTapTimer?.cancel();
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
    if (flushTimestampMs == null) {
      return;
    }
    final signals = _pointerTracker.flushPending(flushTimestampMs);
    _dispatchSignals(signals);
    _syncPendingFlushTimer(referenceTimestampMs: flushTimestampMs);
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

  void _resetPointerTracker() {
    _pointerTracker = PointerInputTracker(
      settings: _controller.pointerSettings,
    );
    _pendingTapTimer?.cancel();
    _pendingTapTimer = null;
    _pendingTapFlushTimestampMs = null;
    _pendingPointerTrackerRefresh = false;
    _pointerSlotByRawPointer.clear();
    _freePointerSlots.clear();
    _nextPointerSlotId = 1;
  }

  int _resolvePointerId(PointerEvent event, PointerPhase phase) {
    final rawPointer = event.pointer;
    final existing = _pointerSlotByRawPointer[rawPointer];
    if (existing != null) {
      return existing;
    }
    if (phase != PointerPhase.down) {
      // Keep graceful behavior for stray non-down events.
      return rawPointer;
    }

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
    if (phase != PointerPhase.up && phase != PointerPhase.cancel) {
      return;
    }
    final slotId = _pointerSlotByRawPointer.remove(event.pointer);
    if (slotId == null) {
      return;
    }
    _freePointerSlots.add(slotId);
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
    if (_activePointerId != sample.pointerId) {
      return;
    }
    _activePointerId = null;
    if (_pendingPointerTrackerRefresh) {
      _resetPointerTracker();
    }
  }

  bool _ownedInputConfigChanged(SceneView oldWidget) {
    return !_pointerSettingsEquivalent(
          oldWidget.pointerSettings,
          widget.pointerSettings,
        ) ||
        oldWidget.dragStartSlop != widget.dragStartSlop ||
        !identical(oldWidget.nodeIdGenerator, widget.nodeIdGenerator);
  }

  PointerInputSettings _resolvedPointerSettings(
    PointerInputSettings? settings,
  ) {
    return settings ?? const PointerInputSettings();
  }

  bool _pointerSettingsEquivalent(
    PointerInputSettings? left,
    PointerInputSettings? right,
  ) {
    final a = _resolvedPointerSettings(left);
    final b = _resolvedPointerSettings(right);
    return a.tapSlop == b.tapSlop &&
        a.doubleTapSlop == b.doubleTapSlop &&
        a.doubleTapMaxDelayMs == b.doubleTapMaxDelayMs &&
        a.deferSingleTap == b.deferSingleTap;
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
