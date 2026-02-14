import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../controller/scene_controller.dart';
import '../render/render_geometry_cache.dart';
import '../render/scene_painter.dart';
import '../render/scene_render_caches.dart';

ui.Image? _defaultImageResolver(String _) => null;

class SceneViewV2 extends StatefulWidget {
  const SceneViewV2({
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

  final SceneControllerV2 controller;
  final ImageResolverV2? imageResolver;
  final SceneStaticLayerCacheV2? staticLayerCache;
  final SceneTextLayoutCacheV2? textLayoutCache;
  final SceneStrokePathCacheV2? strokePathCache;
  final ScenePathMetricsCacheV2? pathMetricsCache;
  final RenderGeometryCache? geometryCache;
  final Color selectionColor;
  final double selectionStrokeWidth;
  final double gridStrokeWidth;

  @override
  State<SceneViewV2> createState() => _SceneViewV2State();
}

class _SceneViewV2State extends State<SceneViewV2> {
  late SceneRenderCachesV2 _renderCaches;

  int _lastEpoch = 0;

  @visibleForTesting
  SceneStaticLayerCacheV2 get debugStaticLayerCache =>
      _renderCaches.staticLayerCache;
  @visibleForTesting
  SceneTextLayoutCacheV2 get debugTextLayoutCache =>
      _renderCaches.textLayoutCache;
  @visibleForTesting
  SceneStrokePathCacheV2 get debugStrokePathCache =>
      _renderCaches.strokePathCache;
  @visibleForTesting
  ScenePathMetricsCacheV2 get debugPathMetricsCache =>
      _renderCaches.pathMetricsCache;
  @visibleForTesting
  RenderGeometryCache get debugGeometryCache => _renderCaches.geometryCache;

  @override
  void initState() {
    super.initState();
    _renderCaches = _createRenderCaches();
    _lastEpoch = widget.controller.controllerEpoch;
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(SceneViewV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _lastEpoch = widget.controller.controllerEpoch;
      _clearAllCaches();
    }
    if (_didCacheDepsChange(oldWidget)) {
      final previous = _renderCaches;
      _renderCaches = _createRenderCaches();
      previous.disposeOwned();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _renderCaches.disposeOwned();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    return CustomPaint(
      painter: ScenePainterV2(
        controller: widget.controller,
        imageResolver: widget.imageResolver ?? _defaultImageResolver,
        staticLayerCache: _renderCaches.staticLayerCache,
        textLayoutCache: _renderCaches.textLayoutCache,
        strokePathCache: _renderCaches.strokePathCache,
        pathMetricsCache: _renderCaches.pathMetricsCache,
        geometryCache: _renderCaches.geometryCache,
        selectionColor: widget.selectionColor,
        selectionStrokeWidth: widget.selectionStrokeWidth,
        gridStrokeWidth: widget.gridStrokeWidth,
        textDirection: textDirection,
      ),
      child: const SizedBox.expand(),
    );
  }

  void _handleControllerChanged() {
    final epoch = widget.controller.controllerEpoch;
    if (epoch == _lastEpoch) return;
    _lastEpoch = epoch;
    _clearAllCaches();
  }

  void _clearAllCaches() {
    _renderCaches.clearAll();
  }

  bool _didCacheDepsChange(SceneViewV2 oldWidget) {
    return oldWidget.staticLayerCache != widget.staticLayerCache ||
        oldWidget.textLayoutCache != widget.textLayoutCache ||
        oldWidget.strokePathCache != widget.strokePathCache ||
        oldWidget.pathMetricsCache != widget.pathMetricsCache ||
        oldWidget.geometryCache != widget.geometryCache;
  }

  SceneRenderCachesV2 _createRenderCaches() {
    return SceneRenderCachesV2(
      staticLayerCache: widget.staticLayerCache,
      textLayoutCache: widget.textLayoutCache,
      strokePathCache: widget.strokePathCache,
      pathMetricsCache: widget.pathMetricsCache,
      geometryCache: widget.geometryCache,
    );
  }
}
