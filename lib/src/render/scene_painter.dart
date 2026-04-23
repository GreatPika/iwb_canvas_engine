import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/rendering.dart';

import '../contract/scene_view_render_state.dart';
import 'cache/scene_path_metrics_cache.dart';
import 'cache/scene_static_layer_cache.dart';
import 'cache/scene_stroke_path_cache.dart';
import 'cache/scene_text_layout_cache.dart';
import 'render_geometry_cache.dart';
import 'scene_painter_background.dart';
import 'scene_painter_contract.dart';
import 'scene_painter_frame.dart';
import 'scene_painter_node_renderer.dart';
import 'scene_painter_selection.dart';
import 'scene_painter_shell.dart';

export 'cache/scene_path_metrics_cache.dart';
export 'cache/scene_static_layer_cache.dart';
export 'cache/scene_stroke_path_cache.dart';
export 'cache/scene_text_layout_cache.dart';

typedef ImageResolver = Image? Function(String imageId);

final class ScenePainterPreparedScene {
  const ScenePainterPreparedScene._({
    required this.size,
    required this.frameRead,
    required this.frame,
  });

  final Size size;
  final SceneViewFrameRead frameRead;
  final ScenePainterPreparedFrame frame;
}

class ScenePainter extends CustomPainter {
  ScenePainter({
    required this.controller,
    required this.imageResolver,
    this.staticLayerCache,
    this.textLayoutCache,
    this.strokePathCache,
    this.pathMetricsCache,
    RenderGeometryCache? geometryCache,
    this.selectionColor = const Color(0xFF1565C0),
    this.selectionStrokeWidth = 1,
    this.gridStrokeWidth = 1,
  }) : _shell = _createScenePainterShell(
         _ScenePainterConfig(
           controller: controller,
           imageResolver: imageResolver,
           staticLayerCache: staticLayerCache,
           textLayoutCache: textLayoutCache,
           strokePathCache: strokePathCache,
           pathMetricsCache: pathMetricsCache,
           geometryCache: geometryCache ?? RenderGeometryCache(),
           selectionColor: selectionColor,
           selectionStrokeWidth: selectionStrokeWidth,
           gridStrokeWidth: gridStrokeWidth,
         ),
       ),
       super(repaint: controller);

  final SceneViewMainSceneRenderRead controller;
  final ImageResolver imageResolver;
  final SceneStaticLayerCache? staticLayerCache;
  final SceneTextLayoutCache? textLayoutCache;
  final SceneStrokePathCache? strokePathCache;
  final ScenePathMetricsCache? pathMetricsCache;
  final Color selectionColor;
  final double selectionStrokeWidth;
  final double gridStrokeWidth;
  final ScenePainterShell _shell;

  @override
  void paint(Canvas canvas, Size size) {
    _shell.paint(canvas, size, controller.captureFrameRead());
  }

  ScenePainterPreparedScene prepareForPaint(Size size) {
    final frameRead = controller.captureFrameRead();
    return ScenePainterPreparedScene._(
      size: size,
      frameRead: frameRead,
      frame: _shell.prepareFrame(size, frameRead),
    );
  }

  void paintPrepared(Canvas canvas, ScenePainterPreparedScene preparedScene) {
    _shell.paintPrepared(
      canvas,
      preparedScene.size,
      preparedScene.frameRead,
      preparedScene.frame,
    );
  }

  @override
  bool shouldRepaint(covariant ScenePainter oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate._repaintConfiguration() != _repaintConfiguration();
  }

  (
    ImageResolver,
    SceneStaticLayerCache?,
    SceneTextLayoutCache?,
    SceneStrokePathCache?,
    ScenePathMetricsCache?,
    Color,
    double,
    double,
  )
  _repaintConfiguration() {
    return (
      imageResolver,
      staticLayerCache,
      textLayoutCache,
      strokePathCache,
      pathMetricsCache,
      selectionColor,
      selectionStrokeWidth,
      gridStrokeWidth,
    );
  }
}

class _ScenePainterConfig {
  const _ScenePainterConfig({
    required this.controller,
    required this.imageResolver,
    required this.staticLayerCache,
    required this.textLayoutCache,
    required this.strokePathCache,
    required this.pathMetricsCache,
    required this.geometryCache,
    required this.selectionColor,
    required this.selectionStrokeWidth,
    required this.gridStrokeWidth,
  });

  final SceneViewMainSceneRenderRead controller;
  final ImageResolver imageResolver;
  final SceneStaticLayerCache? staticLayerCache;
  final SceneTextLayoutCache? textLayoutCache;
  final SceneStrokePathCache? strokePathCache;
  final ScenePathMetricsCache? pathMetricsCache;
  final RenderGeometryCache geometryCache;
  final Color selectionColor;
  final double selectionStrokeWidth;
  final double gridStrokeWidth;
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
      renderState: config.controller,
      textLayoutCache: config.textLayoutCache,
      geometryCache: config.geometryCache,
      selectionColor: config.selectionColor,
      selectionStrokeWidth: config.selectionStrokeWidth,
    ),
    nodeRenderer: ScenePainterNodeRenderer(
      imageResolver: config.imageResolver,
      strokePathCache: config.strokePathCache,
      transformBuffer: nodeTransformBuffer,
    ),
    selectionRenderer: ScenePainterSelectionRenderer(
      strokePathCache: config.strokePathCache,
      pathMetricsCache: config.pathMetricsCache,
      transformBuffer: selectionTransformBuffer,
    ),
  );
}
