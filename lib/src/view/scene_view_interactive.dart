import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../core/pointer_input.dart';
import '../interactive/scene_controller_interactive.dart';
import '../render/scene_render_caches.dart';
import 'scene_view_defaults.dart';
import 'scene_view_interactive_overlay_painter.dart';
import 'scene_view_interactive_pointer_host.dart';
import 'scene_view_render_surface.dart';

_SceneViewInteractiveState _sceneViewInteractiveStateOf(BuildContext context) {
  return sceneViewStateOf<_SceneViewInteractiveState>(
    context,
    missingStateLabel: 'SceneViewInteractive',
  );
}

@visibleForTesting
SceneRenderCaches debugSceneViewInteractiveRenderCachesOf(
  BuildContext context,
) {
  return _sceneViewInteractiveStateOf(context).debugRenderCaches;
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
  final GlobalKey<SceneViewRenderSurfaceState> _renderSurfaceKey =
      GlobalKey<SceneViewRenderSurfaceState>();

  @visibleForTesting
  SceneRenderCaches get debugRenderCaches {
    final renderSurfaceState = _renderSurfaceKey.currentState;
    if (renderSurfaceState == null) {
      throw StateError('SceneViewRenderSurface is not mounted.');
    }
    return renderSurfaceState.debugRenderCaches;
  }

  @visibleForTesting
  int get debugLiveRawPointerCount => _pointerHost.debugLiveRawPointerCount;
  @visibleForTesting
  int? get debugPendingTapFlushTimestampMs =>
      _pointerHost.debugPendingTapFlushTimestampMs;

  @override
  void initState() {
    super.initState();
    _pointerHost = SceneViewInteractivePointerHost(
      controller: widget.controller,
      isMounted: () => mounted,
      onControllerChanged: () {},
    );
  }

  @override
  void didUpdateWidget(SceneViewInteractive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _pointerHost.updateController(widget.controller);
    }
  }

  @override
  void dispose() {
    _pointerHost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final renderSurface = SceneViewRenderSurface(
      key: _renderSurfaceKey,
      controller: widget.controller,
      repaint: widget.controller,
      readControllerEpoch: () =>
          sceneControllerInteractiveInternalEpoch(widget.controller),
      createRenderCaches: _createRenderCaches,
      cacheDependencies: null,
      imageResolver: widget.imageResolver ?? sceneViewDefaultImageResolver,
      nodePreviewOffsetResolver: (nodeId) =>
          sceneControllerInteractiveInternalPreviewDeltaForNode(
            widget.controller,
            nodeId,
          ),
      selectionRect: widget.controller.selectionRect,
      selectionColor: widget.selectionColor,
      selectionStrokeWidth: widget.selectionStrokeWidth,
      gridStrokeWidth: widget.gridStrokeWidth,
      textDirection: textDirection,
    );
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
        foregroundPainter: SceneViewInteractiveOverlayPainter(
          controller: widget.controller,
        ),
        child: renderSurface,
      ),
    );
  }

  SceneRenderCaches _createRenderCaches() {
    return SceneRenderCaches();
  }
}

typedef SceneView = SceneViewInteractive;
