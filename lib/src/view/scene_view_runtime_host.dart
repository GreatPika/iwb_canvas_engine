import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../contract/pointer_input.dart';
import '../contract/scene_view_runtime.dart';
import '../render/scene_render_caches.dart';
import 'scene_view_interactive_overlay_painter.dart';
import 'scene_view_interactive_pointer_host.dart';
import 'scene_view_render_surface.dart';

_SceneViewRuntimeHostState _sceneViewRuntimeHostStateOf(BuildContext context) {
  if (context case StatefulElement(
    :final state,
  ) when state is _SceneViewRuntimeHostState) {
    return state;
  }

  final ancestorState = context
      .findAncestorStateOfType<_SceneViewRuntimeHostState>();
  if (ancestorState != null) {
    return ancestorState;
  }

  throw StateError(
    'No SceneViewRuntimeHost state found for the provided BuildContext.',
  );
}

SceneRenderCaches debugSceneViewRuntimeHostRenderCachesOf(
  BuildContext context,
) {
  return _sceneViewRuntimeHostStateOf(context).debugRenderCaches;
}

int debugSceneViewRuntimeHostLiveRawPointerCountOf(BuildContext context) {
  return _sceneViewRuntimeHostStateOf(context).debugLiveRawPointerCount;
}

int? debugSceneViewRuntimeHostPendingTapFlushTimestampMsOf(
  BuildContext context,
) {
  return _sceneViewRuntimeHostStateOf(context).debugPendingTapFlushTimestampMs;
}

class SceneViewRuntimeHost extends StatefulWidget {
  const SceneViewRuntimeHost({
    required this.runtime,
    this.imageResolver,
    this.selectionColor = const Color(0xFF1565C0),
    this.selectionStrokeWidth = 1,
    this.gridStrokeWidth = 1,
    super.key,
  });

  final SceneViewRuntime runtime;
  final ui.Image? Function(String imageId)? imageResolver;
  final Color selectionColor;
  final double selectionStrokeWidth;
  final double gridStrokeWidth;

  @override
  State<SceneViewRuntimeHost> createState() => _SceneViewRuntimeHostState();
}

class _SceneViewRuntimeHostState extends State<SceneViewRuntimeHost> {
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
      pointerSession: widget.runtime.createPointerSession(
        isMounted: () => mounted,
        hasLiveRawPointers: _hasLiveRawPointers,
      ),
    );
  }

  @override
  void didUpdateWidget(SceneViewRuntimeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.runtime != widget.runtime) {
      _pointerHost.replacePointerSession(
        widget.runtime.createPointerSession(
          isMounted: () => mounted,
          hasLiveRawPointers: _hasLiveRawPointers,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pointerHost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final renderState = widget.runtime.renderState;
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
          renderState: renderState,
        ),
        child: SceneViewRenderSurface(
          key: _renderSurfaceKey,
          renderState: renderState,
          imageResolver: widget.imageResolver,
          selectionColor: widget.selectionColor,
          selectionStrokeWidth: widget.selectionStrokeWidth,
          gridStrokeWidth: widget.gridStrokeWidth,
        ),
      ),
    );
  }

  bool _hasLiveRawPointers() => _pointerHost.debugLiveRawPointerCount > 0;
}
