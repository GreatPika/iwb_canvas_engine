import 'package:flutter/widgets.dart';

import '../contract/scene_render_state.dart';
import '../render/scene_painter.dart';
import '../render/scene_render_caches.dart';

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

class SceneViewRenderSurface extends StatefulWidget {
  const SceneViewRenderSurface({
    required this.controller,
    required this.repaint,
    required this.readControllerEpoch,
    required this.createRenderCaches,
    required this.cacheDependencies,
    required this.imageResolver,
    this.nodePreviewOffsetResolver,
    this.selectionRect,
    this.selectionColor = const Color(0xFF1565C0),
    this.selectionStrokeWidth = 1,
    this.gridStrokeWidth = 1,
    this.textDirection = TextDirection.ltr,
    this.child = const SizedBox.expand(),
    super.key,
  });

  final SceneRenderState controller;
  final Listenable repaint;
  final int Function() readControllerEpoch;
  final SceneRenderCaches Function() createRenderCaches;
  final Object? cacheDependencies;
  final ImageResolver imageResolver;
  final NodePreviewOffsetResolver? nodePreviewOffsetResolver;
  final Rect? selectionRect;
  final Color selectionColor;
  final double selectionStrokeWidth;
  final double gridStrokeWidth;
  final TextDirection textDirection;
  final Widget child;

  @override
  State<SceneViewRenderSurface> createState() => SceneViewRenderSurfaceState();
}

class SceneViewRenderSurfaceState extends State<SceneViewRenderSurface> {
  late final SceneViewRenderCacheLifecycle _renderCacheLifecycle =
      SceneViewRenderCacheLifecycle(create: widget.createRenderCaches);

  SceneRenderCaches get debugRenderCaches => _renderCacheLifecycle.debugCaches;

  @override
  void initState() {
    super.initState();
    _renderCacheLifecycle.initialize(
      controllerEpoch: widget.readControllerEpoch(),
    );
    widget.repaint.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(SceneViewRenderSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repaint != widget.repaint) {
      oldWidget.repaint.removeListener(_handleControllerChanged);
      widget.repaint.addListener(_handleControllerChanged);
      _renderCacheLifecycle.handleControllerSwap(
        controllerEpoch: widget.readControllerEpoch(),
      );
    }
    if (oldWidget.cacheDependencies != widget.cacheDependencies) {
      _renderCacheLifecycle.recreateCaches();
    }
  }

  @override
  void dispose() {
    widget.repaint.removeListener(_handleControllerChanged);
    _renderCacheLifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ScenePainter(
        controller: widget.controller,
        imageResolver: widget.imageResolver,
        nodePreviewOffsetResolver: widget.nodePreviewOffsetResolver,
        staticLayerCache: _renderCacheLifecycle.staticLayerCache,
        textLayoutCache: _renderCacheLifecycle.textLayoutCache,
        strokePathCache: _renderCacheLifecycle.strokePathCache,
        pathMetricsCache: _renderCacheLifecycle.pathMetricsCache,
        geometryCache: _renderCacheLifecycle.geometryCache,
        selectionRect: widget.selectionRect,
        selectionColor: widget.selectionColor,
        selectionStrokeWidth: widget.selectionStrokeWidth,
        gridStrokeWidth: widget.gridStrokeWidth,
        textDirection: widget.textDirection,
      ),
      child: widget.child,
    );
  }

  void _handleControllerChanged() {
    _renderCacheLifecycle.clearIfEpochChanged(widget.readControllerEpoch());
  }
}
