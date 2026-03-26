import 'package:flutter/widgets.dart';

import '../controller/scene_controller.dart';
import '../render/render_geometry_cache.dart';
import '../render/scene_painter.dart';
import '../render/scene_render_caches.dart';
import 'scene_view_defaults.dart';
import 'scene_view_render_surface.dart';

_SceneViewCoreState _sceneViewCoreStateOf(BuildContext context) {
  return sceneViewStateOf<_SceneViewCoreState>(
    context,
    missingStateLabel: 'SceneViewCore',
  );
}

@visibleForTesting
SceneRenderCaches debugSceneViewRenderCachesOf(BuildContext context) {
  return _sceneViewCoreStateOf(context).debugRenderCaches;
}

class SceneViewCore extends StatefulWidget {
  const SceneViewCore({
    required this.controller,
    this.imageResolver,
    this.staticLayerCache,
    this.textLayoutCache,
    this.strokePathCache,
    this.pathMetricsCache,
    this.geometryCache,
    this.selectionColor = const Color(0xFF1565C0),
    this.selectionStrokeWidth = 1,
    this.gridStrokeWidth = 1,
    super.key,
  });

  final SceneControllerCore controller;
  final ImageResolver? imageResolver;
  final SceneStaticLayerCache? staticLayerCache;
  final SceneTextLayoutCache? textLayoutCache;
  final SceneStrokePathCache? strokePathCache;
  final ScenePathMetricsCache? pathMetricsCache;
  final RenderGeometryCache? geometryCache;
  final Color selectionColor;
  final double selectionStrokeWidth;
  final double gridStrokeWidth;

  @override
  State<SceneViewCore> createState() => _SceneViewCoreState();
}

class _SceneViewCoreState extends State<SceneViewCore> {
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

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    return SceneViewRenderSurface(
      key: _renderSurfaceKey,
      controller: widget.controller,
      repaint: widget.controller,
      readControllerEpoch: () => widget.controller.controllerEpoch,
      createRenderCaches: _createRenderCaches,
      cacheDependencies: (
        widget.staticLayerCache,
        widget.textLayoutCache,
        widget.strokePathCache,
        widget.pathMetricsCache,
        widget.geometryCache,
      ),
      imageResolver: widget.imageResolver ?? sceneViewDefaultImageResolver,
      selectionColor: widget.selectionColor,
      selectionStrokeWidth: widget.selectionStrokeWidth,
      gridStrokeWidth: widget.gridStrokeWidth,
      textDirection: textDirection,
    );
  }

  SceneRenderCaches _createRenderCaches() {
    return SceneRenderCaches(
      staticLayerCache: widget.staticLayerCache,
      textLayoutCache: widget.textLayoutCache,
      strokePathCache: widget.strokePathCache,
      pathMetricsCache: widget.pathMetricsCache,
      geometryCache: widget.geometryCache,
    );
  }
}
