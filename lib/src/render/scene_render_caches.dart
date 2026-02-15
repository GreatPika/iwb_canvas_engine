import 'render_geometry_cache.dart';
import 'cache/scene_path_metrics_cache_v2.dart';
import 'cache/scene_static_layer_cache_v2.dart';
import 'cache/scene_stroke_path_cache_v2.dart';
import 'cache/scene_text_layout_cache_v2.dart';

/// Unified render-cache ownership for `SceneViewV2` variants.
///
/// Views own cache lifecycle (clear on epoch/document boundary, dispose when
/// owned), while `ScenePainterV2` only consumes provided cache instances.
class SceneRenderCachesV2 {
  SceneRenderCachesV2({
    SceneStaticLayerCacheV2? staticLayerCache,
    SceneTextLayoutCacheV2? textLayoutCache,
    SceneStrokePathCacheV2? strokePathCache,
    ScenePathMetricsCacheV2? pathMetricsCache,
    RenderGeometryCache? geometryCache,
  }) : staticLayerCache = staticLayerCache ?? SceneStaticLayerCacheV2(),
       textLayoutCache = textLayoutCache ?? SceneTextLayoutCacheV2(),
       strokePathCache = strokePathCache ?? SceneStrokePathCacheV2(),
       pathMetricsCache = pathMetricsCache ?? ScenePathMetricsCacheV2(),
       geometryCache = geometryCache ?? RenderGeometryCache(),
       _ownsStaticLayerCache = staticLayerCache == null,
       _ownsTextLayoutCache = textLayoutCache == null,
       _ownsStrokePathCache = strokePathCache == null,
       _ownsPathMetricsCache = pathMetricsCache == null,
       _ownsGeometryCache = geometryCache == null;

  final SceneStaticLayerCacheV2 staticLayerCache;
  final SceneTextLayoutCacheV2 textLayoutCache;
  final SceneStrokePathCacheV2 strokePathCache;
  final ScenePathMetricsCacheV2 pathMetricsCache;
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
