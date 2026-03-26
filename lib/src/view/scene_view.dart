import 'package:flutter/widgets.dart';

import '../controller/scene_controller.dart';
import '../render/render_geometry_cache.dart';
import '../render/scene_painter.dart';
import '../render/scene_render_caches.dart';
import 'scene_view_defaults.dart';

@visibleForTesting
SceneRenderCaches debugSceneViewRenderCachesOf(BuildContext context) {
  final state = switch (context) {
    StatefulElement(:final state) when state is _SceneViewCoreState => state,
    _ => context.findAncestorStateOfType<_SceneViewCoreState>(),
  };
  if (state == null) {
    throw StateError(
      'No SceneViewCore state found for the provided BuildContext.',
    );
  }
  return state.debugRenderCaches;
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
  late final SceneViewRenderCacheLifecycle _renderCacheLifecycle =
      SceneViewRenderCacheLifecycle(create: _createRenderCaches);

  @visibleForTesting
  SceneRenderCaches get debugRenderCaches => _renderCacheLifecycle.debugCaches;

  @override
  void initState() {
    super.initState();
    _renderCacheLifecycle.initialize(
      controllerEpoch: widget.controller.controllerEpoch,
    );
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(SceneViewCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _renderCacheLifecycle.handleControllerSwap(
        controllerEpoch: widget.controller.controllerEpoch,
      );
    }
    if (_didCacheDepsChange(oldWidget)) {
      _renderCacheLifecycle.recreateCaches();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _renderCacheLifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    return CustomPaint(
      painter: ScenePainter(
        controller: widget.controller,
        imageResolver: widget.imageResolver ?? sceneViewDefaultImageResolver,
        staticLayerCache: _renderCacheLifecycle.staticLayerCache,
        textLayoutCache: _renderCacheLifecycle.textLayoutCache,
        strokePathCache: _renderCacheLifecycle.strokePathCache,
        pathMetricsCache: _renderCacheLifecycle.pathMetricsCache,
        geometryCache: _renderCacheLifecycle.geometryCache,
        selectionColor: widget.selectionColor,
        selectionStrokeWidth: widget.selectionStrokeWidth,
        gridStrokeWidth: widget.gridStrokeWidth,
        textDirection: textDirection,
      ),
      child: const SizedBox.expand(),
    );
  }

  void _handleControllerChanged() {
    _renderCacheLifecycle.clearIfEpochChanged(
      widget.controller.controllerEpoch,
    );
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
