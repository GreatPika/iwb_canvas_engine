import 'render_geometry_cache.dart';
import 'cache/scene_path_metrics_cache.dart';
import 'cache/scene_static_layer_cache.dart';
import 'cache/scene_stroke_path_cache.dart';
import 'cache/scene_text_layout_cache.dart';

/// Unified render-cache ownership for scene view variants.
///
/// Views own cache lifecycle (clear on epoch/document boundary, dispose when
/// owned), while `ScenePainter` only consumes provided cache instances.
class SceneRenderCaches {
  SceneRenderCaches({
    SceneStaticLayerCache? staticLayerCache,
    SceneTextLayoutCache? textLayoutCache,
    SceneStrokePathCache? strokePathCache,
    ScenePathMetricsCache? pathMetricsCache,
    RenderGeometryCache? geometryCache,
  }) : staticLayerCache = staticLayerCache ?? SceneStaticLayerCache(),
       textLayoutCache = textLayoutCache ?? SceneTextLayoutCache(),
       strokePathCache = strokePathCache ?? SceneStrokePathCache(),
       pathMetricsCache = pathMetricsCache ?? ScenePathMetricsCache(),
       geometryCache = geometryCache ?? RenderGeometryCache(),
       _ownsStaticLayerCache = staticLayerCache == null,
       _ownsTextLayoutCache = textLayoutCache == null,
       _ownsStrokePathCache = strokePathCache == null,
       _ownsPathMetricsCache = pathMetricsCache == null,
       _ownsGeometryCache = geometryCache == null;

  final SceneStaticLayerCache staticLayerCache;
  final SceneTextLayoutCache textLayoutCache;
  final SceneStrokePathCache strokePathCache;
  final ScenePathMetricsCache pathMetricsCache;
  final RenderGeometryCache geometryCache;

  final bool _ownsStaticLayerCache;
  final bool _ownsTextLayoutCache;
  final bool _ownsStrokePathCache;
  final bool _ownsPathMetricsCache;
  final bool _ownsGeometryCache;

  void clearAll() {
    staticLayerCache.clear();
    textLayoutCache.clear();
    strokePathCache.clear();
    pathMetricsCache.clear();
    geometryCache.invalidateAll();
  }

  void disposeOwned() {
    if (_ownsStaticLayerCache) {
      staticLayerCache.dispose();
    }
    if (_ownsTextLayoutCache) {
      textLayoutCache.clear();
    }
    if (_ownsStrokePathCache) {
      strokePathCache.clear();
    }
    if (_ownsPathMetricsCache) {
      pathMetricsCache.clear();
    }
    if (_ownsGeometryCache) {
      geometryCache.invalidateAll();
    }
  }
}
