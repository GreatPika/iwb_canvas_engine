import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../core/pointer_input.dart';
import '../interactive/scene_controller_interactive.dart';
import '../render/scene_painter.dart';
import '../render/scene_render_caches.dart';
import 'scene_view_defaults.dart';
import 'scene_view_interactive_overlay_painter.dart';
import 'scene_view_interactive_pointer_host.dart';

_SceneViewInteractiveState _sceneViewInteractiveStateOf(BuildContext context) {
  return switch (context) {
        StatefulElement(:final state)
            when state is _SceneViewInteractiveState =>
          state,
        _ => context.findAncestorStateOfType<_SceneViewInteractiveState>(),
      } ??
      (throw StateError(
        'No SceneViewInteractive state found for the provided BuildContext.',
      ));
}

@visibleForTesting
SceneRenderCaches debugSceneViewInteractiveRenderCachesOf(
  BuildContext context,
) {
  final state = _sceneViewInteractiveStateOf(context);
  return state.debugRenderCaches;
}

@visibleForTesting
int debugSceneViewInteractiveLiveRawPointerCountOf(BuildContext context) {
  return _sceneViewInteractiveStateOf(context).debugLiveRawPointerCount;
}

@visibleForTesting
int? debugSceneViewInteractivePendingTapFlushTimestampMsOf(
  BuildContext context,
) {
  return _sceneViewInteractiveStateOf(context).debugPendingTapFlushTimestampMs;
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
  late final SceneViewInteractivePointerHost _pointerHost;
  late final SceneViewRenderCacheLifecycle _renderCacheLifecycle =
      SceneViewRenderCacheLifecycle(create: _createRenderCaches);

  @visibleForTesting
  SceneRenderCaches get debugRenderCaches => _renderCacheLifecycle.debugCaches;
  @visibleForTesting
  int get debugLiveRawPointerCount => _pointerHost.debugLiveRawPointerCount;
  @visibleForTesting
  int? get debugPendingTapFlushTimestampMs =>
      _pointerHost.debugPendingTapFlushTimestampMs;

  @override
  void initState() {
    super.initState();
    _renderCacheLifecycle.initialize(
      controllerEpoch: sceneControllerInteractiveInternalEpoch(
        widget.controller,
      ),
    );
    _pointerHost = SceneViewInteractivePointerHost(
      controller: widget.controller,
      isMounted: () => mounted,
      onControllerChanged: _handleControllerChanged,
    );
  }

  @override
  void didUpdateWidget(SceneViewInteractive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _pointerHost.updateController(widget.controller);
      _renderCacheLifecycle.handleControllerSwap(
        controllerEpoch: sceneControllerInteractiveInternalEpoch(
          widget.controller,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pointerHost.dispose();
    _renderCacheLifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) =>
          _pointerHost.handlePointerEvent(event, PointerPhase.down),
      onPointerMove: (event) =>
          _pointerHost.handlePointerEvent(event, PointerPhase.move),
      onPointerUp: (event) =>
          _pointerHost.handlePointerEvent(event, PointerPhase.up),
      onPointerCancel: (event) =>
          _pointerHost.handlePointerEvent(event, PointerPhase.cancel),
      child: CustomPaint(
        painter: ScenePainter(
          controller: widget.controller,
          imageResolver: widget.imageResolver ?? sceneViewDefaultImageResolver,
          nodePreviewOffsetResolver: (nodeId) =>
              sceneControllerInteractiveInternalPreviewDeltaForNode(
                widget.controller,
                nodeId,
              ),
          staticLayerCache: _renderCacheLifecycle.staticLayerCache,
          textLayoutCache: _renderCacheLifecycle.textLayoutCache,
          strokePathCache: _renderCacheLifecycle.strokePathCache,
          pathMetricsCache: _renderCacheLifecycle.pathMetricsCache,
          geometryCache: _renderCacheLifecycle.geometryCache,
          selectionRect: widget.controller.selectionRect,
          selectionColor: widget.selectionColor,
          selectionStrokeWidth: widget.selectionStrokeWidth,
          gridStrokeWidth: widget.gridStrokeWidth,
          textDirection: textDirection,
        ),
        foregroundPainter: SceneViewInteractiveOverlayPainter(
          controller: widget.controller,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  void _handleControllerChanged() {
    _renderCacheLifecycle.clearIfEpochChanged(
      sceneControllerInteractiveInternalEpoch(widget.controller),
    );
  }

  SceneRenderCaches _createRenderCaches() {
    return SceneRenderCaches();
  }
}

typedef SceneView = SceneViewInteractive;
