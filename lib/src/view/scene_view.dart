import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../controller/scene_controller.dart';
import '../render/render_geometry_cache.dart';
import '../render/scene_painter.dart';
import '../render/scene_render_caches.dart';

ui.Image? _defaultImageResolver(String _) => null;

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
  late SceneRenderCaches _renderCaches;

  int _lastEpoch = 0;

  @visibleForTesting
  SceneStaticLayerCache get debugStaticLayerCache =>
      _renderCaches.staticLayerCache;
  @visibleForTesting
  SceneTextLayoutCache get debugTextLayoutCache =>
      _renderCaches.textLayoutCache;
  @visibleForTesting
  SceneStrokePathCache get debugStrokePathCache =>
      _renderCaches.strokePathCache;
  @visibleForTesting
  ScenePathMetricsCache get debugPathMetricsCache =>
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
  void didUpdateWidget(SceneViewCore oldWidget) {
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
      painter: ScenePainter(
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

  bool _didCacheDepsChange(SceneViewCore oldWidget) {
    return oldWidget.staticLayerCache != widget.staticLayerCache ||
        oldWidget.textLayoutCache != widget.textLayoutCache ||
        oldWidget.strokePathCache != widget.strokePathCache ||
        oldWidget.pathMetricsCache != widget.pathMetricsCache ||
        oldWidget.geometryCache != widget.geometryCache;
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
