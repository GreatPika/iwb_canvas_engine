import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../core/numeric_clamp.dart';
import '../contract/transform2d.dart';
import '../contract/scene_render_state.dart';
import '../contract/snapshot.dart';
import 'canvas_scope.dart';
import 'cache/scene_path_metrics_cache.dart';
import 'cache/scene_static_layer_cache.dart';
import 'cache/scene_stroke_path_cache.dart';
import 'cache/scene_text_layout_cache.dart';
import 'render_geometry_cache.dart';
import 'scene_grid_renderer.dart';

export 'cache/scene_path_metrics_cache.dart';
export 'cache/scene_static_layer_cache.dart';
export 'cache/scene_stroke_path_cache.dart';
export 'cache/scene_text_layout_cache.dart';

part 'scene_painter_frame.part.dart';
part 'scene_painter_node_renderer.part.dart';
part 'scene_painter_selection.part.dart';

typedef ImageResolver = Image? Function(String imageId);
typedef NodePreviewOffsetResolver = Offset Function(NodeId nodeId);

const _gridRenderer = SceneGridRenderer();

class ScenePainter extends CustomPainter {
  static const double _cullPadding = 1.0;

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
  }) : _frameOwner = _ScenePainterFrameOwner(
         controller: controller,
         geometryCache: geometryCache ?? RenderGeometryCache(),
         nodePreviewOffsetResolver: nodePreviewOffsetResolver,
         selectionRect: selectionRect,
         selectionColor: selectionColor,
         selectionStrokeWidth: selectionStrokeWidth,
       ),
       super(repaint: controller) {
    _selectionOwner = _ScenePainterSelectionOwner(
      strokePathCache: strokePathCache,
      pathMetricsCache: pathMetricsCache,
      transformBuffer: _transformBuffer,
    );
    _nodeRenderer = _ScenePainterNodeRenderer(
      imageResolver: imageResolver,
      textLayoutCache: textLayoutCache,
      strokePathCache: strokePathCache,
      textDirection: textDirection,
      transformBuffer: _transformBuffer,
    );
  }

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
  final _ScenePainterFrameOwner _frameOwner;
  late final _ScenePainterNodeRenderer _nodeRenderer;
  late final _ScenePainterSelectionOwner _selectionOwner;

  final Float64List _transformBuffer = Float64List(16);

  @override
  void paint(Canvas canvas, Size size) {
    final snapshot = controller.snapshot;
    final frame = _frameOwner.create(snapshot, size);

    final staticLayerCache = this.staticLayerCache;
    if (staticLayerCache != null) {
      staticLayerCache.draw(
        canvas,
        SceneGridRenderRequest(
          grid: snapshot.background.grid,
          size: size,
          cameraOffset: frame.cameraOffset,
          gridStrokeWidth: gridStrokeWidth,
        ),
        backgroundColor: snapshot.background.color,
      );
    } else {
      _drawBackground(canvas, size, snapshot.background.color);
      _gridRenderer.draw(
        canvas,
        SceneGridRenderRequest(
          grid: snapshot.background.grid,
          size: size,
          cameraOffset: frame.cameraOffset,
          gridStrokeWidth: gridStrokeWidth,
        ),
      );
    }

    _drawNodeLayers(canvas, snapshot, frame);
    _selectionOwner.draw(canvas, frame);
  }

  void _drawNodeLayers(
    Canvas canvas,
    SceneSnapshot snapshot,
    _PaintFrame frame,
  ) {
    _drawVisibleNodes(
      canvas: canvas,
      nodes: snapshot.backgroundLayer.nodes,
      frame: frame,
    );
    for (final layer in snapshot.layers) {
      _drawVisibleNodes(canvas: canvas, nodes: layer.nodes, frame: frame);
    }
  }

  void _drawVisibleNodes({
    required Canvas canvas,
    required Iterable<NodeSnapshot> nodes,
    required _PaintFrame frame,
  }) {
    for (final node in nodes) {
      if (!node.isVisible) {
        continue;
      }
      final resolvedNode = _frameOwner.resolveNodePaintData(node);
      if (!_frameOwner.canPaintNodeInFrame(resolvedNode, frame.viewRect)) {
        continue;
      }
      _nodeRenderer.draw(canvas, resolvedNode, frame.cameraOffset);
      if (frame.isSelected(node.id)) {
        frame.selectedNodes.add(resolvedNode);
      }
    }
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

void _drawBackground(Canvas canvas, Size size, Color color) {
  canvas.drawRect(Offset.zero & size, Paint()..color = color);
}

Rect _centerRect(Size size) {
  final safe = clampNonNegativeSizeFinite(size);
  return Rect.fromCenter(
    center: Offset.zero,
    width: safe.width,
    height: safe.height,
  );
}

Rect _normalizeRect(Rect rect) {
  final left = rect.left < rect.right ? rect.left : rect.right;
  final right = rect.left < rect.right ? rect.right : rect.left;
  final top = rect.top < rect.bottom ? rect.top : rect.bottom;
  final bottom = rect.top < rect.bottom ? rect.bottom : rect.top;
  return Rect.fromLTRB(left, top, right, bottom);
}

Color _applyOpacity(Color color, double opacity) {
  final alpha = (_alpha01(opacity) * 255.0).round().clamp(0, 255);
  return color.withAlpha(alpha);
}

double _alpha01(double opacity) {
  return clampNonNegativeFinite(opacity).clamp(0.0, 1.0);
}

double _textAlignOffset(
  TextAlign align,
  double boxWidth,
  double textWidth,
  TextDirection textDirection,
) {
  switch (align) {
    case TextAlign.right:
      return boxWidth - textWidth;
    case TextAlign.end:
      return textDirection == TextDirection.rtl ? 0 : boxWidth - textWidth;
    case TextAlign.center:
      return (boxWidth - textWidth) / 2;
    case TextAlign.left:
      return 0;
    case TextAlign.start:
    case TextAlign.justify:
      return textDirection == TextDirection.rtl ? boxWidth - textWidth : 0;
  }
}

bool _isFiniteRect(Rect rect) {
  return rect.left.isFinite &&
      rect.top.isFinite &&
      rect.right.isFinite &&
      rect.bottom.isFinite;
}

bool _isFiniteOffset(Offset offset) {
  return offset.dx.isFinite && offset.dy.isFinite;
}

bool _areFiniteOffsets(List<Offset> offsets) {
  for (final offset in offsets) {
    if (!_isFiniteOffset(offset)) {
      return false;
    }
  }
  return true;
}

bool _canPaintStrokeNode(StrokeNodeSnapshot node) {
  return node.points.isNotEmpty &&
      node.transform.isFinite &&
      _areFiniteOffsets(node.points);
}

Path _resolveStrokePath(
  StrokeNodeSnapshot node,
  SceneStrokePathCache? strokePathCache,
) {
  return strokePathCache != null
      ? strokePathCache.getOrBuild(node)
      : buildStrokePath(node.points);
}

Float64List _toViewTransform(
  Float64List transformBuffer,
  Transform2D transform,
  Offset cameraOffset,
) {
  transformBuffer[0] = transform.a;
  transformBuffer[1] = transform.b;
  transformBuffer[2] = 0;
  transformBuffer[3] = 0;
  transformBuffer[4] = transform.c;
  transformBuffer[5] = transform.d;
  transformBuffer[6] = 0;
  transformBuffer[7] = 0;
  transformBuffer[8] = 0;
  transformBuffer[9] = 0;
  transformBuffer[10] = 1;
  transformBuffer[11] = 0;
  transformBuffer[12] = transform.tx - cameraOffset.dx;
  transformBuffer[13] = transform.ty - cameraOffset.dy;
  transformBuffer[14] = 0;
  transformBuffer[15] = 1;
  return transformBuffer;
}
