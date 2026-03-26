import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/rendering.dart';

import '../contract/scene_render_state.dart';
import '../contract/snapshot.dart';
import 'cache/scene_path_metrics_cache.dart';
import 'cache/scene_static_layer_cache.dart';
import 'cache/scene_stroke_path_cache.dart';
import 'cache/scene_text_layout_cache.dart';
import 'render_geometry_cache.dart';
import 'scene_painter_background.dart';
import 'scene_painter_frame.dart';
import 'scene_painter_node_renderer.dart';
import 'scene_painter_selection.dart';
import 'scene_painter_shell.dart';

export 'cache/scene_path_metrics_cache.dart';
export 'cache/scene_static_layer_cache.dart';
export 'cache/scene_stroke_path_cache.dart';
export 'cache/scene_text_layout_cache.dart';

typedef ImageResolver = Image? Function(String imageId);
typedef NodePreviewOffsetResolver = Offset Function(NodeId nodeId);

class ScenePainter extends CustomPainter {
  ScenePainter({
    required this.controller,
    required this.imageResolver,
    this.nodePreviewOffsetResolver,
    this.staticLayerCache,
    this.textLayoutCache,
    this.strokePathCache,
    this.pathMetricsCache,
    RenderGeometryCache? geometryCache,
    this.selectionRect,
    this.selectionColor = const Color(0xFF1565C0),
    this.selectionStrokeWidth = 1,
    this.gridStrokeWidth = 1,
    this.textDirection = TextDirection.ltr,
  }) : _shell = _createScenePainterShell(
         _ScenePainterConfig(
           controller: controller,
           imageResolver: imageResolver,
           nodePreviewOffsetResolver: nodePreviewOffsetResolver,
           staticLayerCache: staticLayerCache,
           textLayoutCache: textLayoutCache,
           strokePathCache: strokePathCache,
           pathMetricsCache: pathMetricsCache,
           geometryCache: geometryCache ?? RenderGeometryCache(),
           selectionRect: selectionRect,
           selectionColor: selectionColor,
           selectionStrokeWidth: selectionStrokeWidth,
           gridStrokeWidth: gridStrokeWidth,
           textDirection: textDirection,
         ),
       ),
       super(repaint: controller);

  final SceneRenderState controller;
  final ImageResolver imageResolver;
  final NodePreviewOffsetResolver? nodePreviewOffsetResolver;
  final SceneStaticLayerCache? staticLayerCache;
  final SceneTextLayoutCache? textLayoutCache;
  final SceneStrokePathCache? strokePathCache;
  final ScenePathMetricsCache? pathMetricsCache;
  final Rect? selectionRect;
  final Color selectionColor;
  final double selectionStrokeWidth;
  final double gridStrokeWidth;
  final TextDirection textDirection;
  final ScenePainterShell _shell;

  @override
  void paint(Canvas canvas, Size size) {
    _shell.paint(canvas, size, controller.snapshot);
  }

  @override
  bool shouldRepaint(covariant ScenePainter oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate._repaintConfiguration() != _repaintConfiguration();
  }

  (
    ImageResolver,
    NodePreviewOffsetResolver?,
    SceneStaticLayerCache?,
    SceneTextLayoutCache?,
    SceneStrokePathCache?,
    ScenePathMetricsCache?,
    Rect?,
    Color,
    double,
    double,
    TextDirection,
  )
  _repaintConfiguration() {
    return (
      imageResolver,
      nodePreviewOffsetResolver,
      staticLayerCache,
      textLayoutCache,
      strokePathCache,
      pathMetricsCache,
      selectionRect,
      selectionColor,
      selectionStrokeWidth,
      gridStrokeWidth,
      textDirection,
    );
  }
}

class _ScenePainterConfig {
  const _ScenePainterConfig({
    required this.controller,
    required this.imageResolver,
    required this.nodePreviewOffsetResolver,
    required this.staticLayerCache,
    required this.textLayoutCache,
    required this.strokePathCache,
    required this.pathMetricsCache,
    required this.geometryCache,
    required this.selectionRect,
    required this.selectionColor,
    required this.selectionStrokeWidth,
    required this.gridStrokeWidth,
    required this.textDirection,
  });

  final SceneRenderState controller;
  final ImageResolver imageResolver;
  final NodePreviewOffsetResolver? nodePreviewOffsetResolver;
  final SceneStaticLayerCache? staticLayerCache;
  final SceneTextLayoutCache? textLayoutCache;
  final SceneStrokePathCache? strokePathCache;
  final ScenePathMetricsCache? pathMetricsCache;
  final RenderGeometryCache geometryCache;
  final Rect? selectionRect;
  final Color selectionColor;
  final double selectionStrokeWidth;
  final double gridStrokeWidth;
  final TextDirection textDirection;
}

ScenePainterShell _createScenePainterShell(_ScenePainterConfig config) {
  final nodeTransformBuffer = Float64List(16);
  final selectionTransformBuffer = Float64List(16);
  return ScenePainterShell(
    backgroundOwner: ScenePainterBackgroundOwner(
      staticLayerCache: config.staticLayerCache,
      gridStrokeWidth: config.gridStrokeWidth,
    ),
    frameOwner: ScenePainterFrameOwner(
      controller: config.controller,
      geometryCache: config.geometryCache,
      nodePreviewOffsetResolver: config.nodePreviewOffsetResolver,
      selectionRect: config.selectionRect,
      selectionColor: config.selectionColor,
      selectionStrokeWidth: config.selectionStrokeWidth,
    ),
    nodeRenderer: ScenePainterNodeRenderer(
      imageResolver: config.imageResolver,
      textLayoutCache: config.textLayoutCache,
      strokePathCache: config.strokePathCache,
      textDirection: config.textDirection,
      transformBuffer: nodeTransformBuffer,
    ),
    selectionRenderer: ScenePainterSelectionRenderer(
      strokePathCache: config.strokePathCache,
      pathMetricsCache: config.pathMetricsCache,
      transformBuffer: selectionTransformBuffer,
    ),
  );
}
