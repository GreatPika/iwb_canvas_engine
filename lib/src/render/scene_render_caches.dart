import 'render_geometry_cache.dart';
import 'cache/scene_path_metrics_cache.dart';
import 'cache/scene_static_layer_cache.dart';
import 'cache/scene_stroke_path_cache.dart';
import 'cache/scene_text_layout_cache.dart';

/// Unified render-cache ownership for scene view variants.
///
/// Views own cache lifecycle and must clear all caches on controller epoch or
/// controller-instance boundary changes. Individual caches therefore keep
/// document lifecycle out of their keys and only track local geometry/layout
/// validity.
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

  /// Clears all render caches for an epoch/document boundary transition.
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

/// View-local lifecycle owner for render caches.
///
/// View states remain the owner and drive this helper from their widget and
/// controller lifecycle. The helper only consolidates cache recreation, epoch
/// invalidation, and debug exposure so view variants do not keep duplicated
/// cache lifecycle code in parallel.
class SceneViewRenderCacheLifecycle {
  SceneViewRenderCacheLifecycle({required SceneRenderCaches Function() create})
    : _create = create;

  final SceneRenderCaches Function() _create;

  late SceneRenderCaches _renderCaches;
  int _lastEpoch = 0;

  SceneStaticLayerCache get staticLayerCache => _renderCaches.staticLayerCache;
  SceneTextLayoutCache get textLayoutCache => _renderCaches.textLayoutCache;
  SceneStrokePathCache get strokePathCache => _renderCaches.strokePathCache;
  ScenePathMetricsCache get pathMetricsCache => _renderCaches.pathMetricsCache;
  RenderGeometryCache get geometryCache => _renderCaches.geometryCache;

  SceneRenderCaches get debugCaches => SceneRenderCaches(
    staticLayerCache: staticLayerCache,
    textLayoutCache: textLayoutCache,
    strokePathCache: strokePathCache,
    pathMetricsCache: pathMetricsCache,
    geometryCache: geometryCache,
  );

  void initialize({required int controllerEpoch}) {
    _renderCaches = _create();
    _lastEpoch = controllerEpoch;
  }

  void handleControllerSwap({required int controllerEpoch}) {
    _lastEpoch = controllerEpoch;
    _renderCaches.clearAll();
  }

  bool clearIfEpochChanged(int controllerEpoch) {
    if (controllerEpoch == _lastEpoch) {
      return false;
    }
    _lastEpoch = controllerEpoch;
    _renderCaches.clearAll();
    return true;
  }

  void recreateCaches() {
    final previous = _renderCaches;
    _renderCaches = _create();
    previous.disposeOwned();
  }

  void dispose() {
    _renderCaches.disposeOwned();
  }
}
