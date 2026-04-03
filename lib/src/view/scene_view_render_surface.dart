import 'package:flutter/widgets.dart';

import '../contract/scene_view_render_state.dart';
import '../render/render_geometry_cache.dart';
import '../render/scene_painter.dart';
import '../render/scene_render_caches.dart';
import 'scene_view_defaults.dart';

T sceneViewStateOf<T extends State<StatefulWidget>>(
  BuildContext context, {
  required String missingStateLabel,
}) {
  return switch (context) {
        StatefulElement(:final state) when state is T => state,
        _ => context.findAncestorStateOfType<T>(),
      } ??
      (throw StateError(
        'No $missingStateLabel state found for the provided BuildContext.',
      ));
}

@visibleForTesting
SceneRenderCaches debugSceneViewRenderCachesOf(BuildContext context) {
  return sceneViewStateOf<SceneViewRenderSurfaceState>(
    context,
    missingStateLabel: 'SceneViewRenderSurface',
  ).debugRenderCaches;
}

class SceneViewRenderSurface extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables, cache wiring keeps this constructor non-const
  SceneViewRenderSurface({
    required SceneViewRenderState renderState,
    ImageResolver? imageResolver,
    SceneStaticLayerCache? staticLayerCache,
    SceneTextLayoutCache? textLayoutCache,
    SceneStrokePathCache? strokePathCache,
    ScenePathMetricsCache? pathMetricsCache,
    RenderGeometryCache? geometryCache,
    Color selectionColor = const Color(0xFF1565C0),
    double selectionStrokeWidth = 1,
    double gridStrokeWidth = 1,
    Widget child = const SizedBox.expand(),
    super.key,
  }) : _renderState = renderState,
       _staticLayerCache = staticLayerCache,
       _textLayoutCache = textLayoutCache,
       _strokePathCache = strokePathCache,
       _pathMetricsCache = pathMetricsCache,
       _geometryCache = geometryCache,
       _imageResolver = imageResolver ?? sceneViewDefaultImageResolver,
       _selectionColor = selectionColor,
       _selectionStrokeWidth = selectionStrokeWidth,
       _gridStrokeWidth = gridStrokeWidth,
       _child = child;

  final SceneViewRenderState _renderState;
  final SceneStaticLayerCache? _staticLayerCache;
  final SceneTextLayoutCache? _textLayoutCache;
  final SceneStrokePathCache? _strokePathCache;
  final ScenePathMetricsCache? _pathMetricsCache;
  final RenderGeometryCache? _geometryCache;
  final ImageResolver _imageResolver;
  final Color _selectionColor;
  final double _selectionStrokeWidth;
  final double _gridStrokeWidth;
  final Widget _child;

  @override
  State<SceneViewRenderSurface> createState() => SceneViewRenderSurfaceState();
}

class SceneViewRenderSurfaceState extends State<SceneViewRenderSurface> {
  late final SceneViewRenderCacheLifecycle _renderCacheLifecycle =
      SceneViewRenderCacheLifecycle(create: _createRenderCaches);

  SceneRenderCaches get debugRenderCaches => _renderCacheLifecycle.debugCaches;

  SceneRenderCaches _createRenderCaches() {
    return SceneRenderCaches(
      staticLayerCache: widget._staticLayerCache,
      textLayoutCache: widget._textLayoutCache,
      strokePathCache: widget._strokePathCache,
      pathMetricsCache: widget._pathMetricsCache,
      geometryCache: widget._geometryCache,
    );
  }

  Object _cacheDependenciesOf(SceneViewRenderSurface widget) {
    return (
      widget._staticLayerCache,
      widget._textLayoutCache,
      widget._strokePathCache,
      widget._pathMetricsCache,
      widget._geometryCache,
    );
  }

  @override
  void initState() {
    super.initState();
    _renderCacheLifecycle.initialize(
      controllerEpoch: widget._renderState.controllerEpoch,
    );
    widget._renderState.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(SceneViewRenderSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget._renderState != widget._renderState) {
      oldWidget._renderState.removeListener(_handleControllerChanged);
      widget._renderState.addListener(_handleControllerChanged);
      _renderCacheLifecycle.handleControllerSwap(
        controllerEpoch: widget._renderState.controllerEpoch,
      );
    }
    if (_cacheDependenciesOf(oldWidget) != _cacheDependenciesOf(widget)) {
      _renderCacheLifecycle.recreateCaches();
    }
  }

  @override
  void dispose() {
    widget._renderState.removeListener(_handleControllerChanged);
    _renderCacheLifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ScenePainter(
        controller: widget._renderState,
        imageResolver: widget._imageResolver,
        staticLayerCache: _renderCacheLifecycle.staticLayerCache,
        textLayoutCache: _renderCacheLifecycle.textLayoutCache,
        strokePathCache: _renderCacheLifecycle.strokePathCache,
        pathMetricsCache: _renderCacheLifecycle.pathMetricsCache,
        geometryCache: _renderCacheLifecycle.geometryCache,
        selectionColor: widget._selectionColor,
        selectionStrokeWidth: widget._selectionStrokeWidth,
        gridStrokeWidth: widget._gridStrokeWidth,
      ),
      child: widget._child,
    );
  }

  void _handleControllerChanged() {
    _renderCacheLifecycle.clearIfEpochChanged(
      widget._renderState.controllerEpoch,
    );
  }
}
