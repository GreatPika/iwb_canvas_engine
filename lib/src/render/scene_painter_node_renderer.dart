import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/rendering.dart';

import '../contract/snapshot.dart';
import '../core/numeric_clamp.dart';
import 'cache/scene_stroke_path_cache.dart';
import 'cache/scene_text_layout_cache.dart';
import 'canvas_scope.dart';
import 'scene_painter_contract.dart';
import 'scene_painter_shared.dart';

class ScenePainterNodeRenderer {
  ScenePainterNodeRenderer({
    required Image? Function(String imageId) imageResolver,
    required SceneTextLayoutCache? textLayoutCache,
    required SceneStrokePathCache? strokePathCache,
    required TextDirection textDirection,
    required Float64List transformBuffer,
  }) : _transformBuffer = transformBuffer,
       _support = SceneNodeRenderSupport(
         imageResolver: imageResolver,
         textLayoutCache: textLayoutCache,
         strokePathCache: strokePathCache,
         textDirection: textDirection,
       );

  final Float64List _transformBuffer;
  final SceneNodeRenderSupport _support;

  void paintNodeLayers({
    required Canvas canvas,
    required SceneSnapshot snapshot,
    required ScenePainterPaintFrame frame,
    required ScenePainterResolvedNodePaintData Function(NodeSnapshot node)
    resolveNodePaintData,
  }) {
    _drawVisibleNodes(
      canvas: canvas,
      nodes: snapshot.backgroundLayer.nodes,
      frame: frame,
      resolveNodePaintData: resolveNodePaintData,
    );
    for (final layer in snapshot.layers) {
      _drawVisibleNodes(
        canvas: canvas,
        nodes: layer.nodes,
        frame: frame,
        resolveNodePaintData: resolveNodePaintData,
      );
    }
  }

  void _drawVisibleNodes({
    required Canvas canvas,
    required Iterable<NodeSnapshot> nodes,
    required ScenePainterPaintFrame frame,
    required ScenePainterResolvedNodePaintData Function(NodeSnapshot node)
    resolveNodePaintData,
  }) {
    final renderContext = SceneNodeRenderContext(
      canvas: canvas,
      cameraOffset: frame.cameraOffset,
      transformBuffer: _transformBuffer,
    );
    for (final node in nodes) {
      if (!node.isVisible) {
        continue;
      }
      final resolvedNode = resolveNodePaintData(node);
      if (!_canPaintNodeInFrame(resolvedNode, frame.viewRect)) {
        continue;
      }
      _drawResolvedNode(resolvedNode, renderContext, _support);
      if (frame.isSelected(node.id)) {
        frame.selectedNodes.add(resolvedNode);
      }
    }
  }
}

class SceneNodeRenderSupport {
  SceneNodeRenderSupport({
    required Image? Function(String imageId) imageResolver,
    required SceneTextLayoutCache? textLayoutCache,
    required SceneStrokePathCache? strokePathCache,
    required TextDirection textDirection,
  }) : shapes = SceneShapeNodeRenderer(),
       strokes = SceneStrokeNodeRenderer(strokePathCache: strokePathCache),
       rich = SceneRichNodeRenderer(
         imageResolver: imageResolver,
         textLayoutCache: textLayoutCache,
         textDirection: textDirection,
       );

  final SceneShapeNodeRenderer shapes;
  final SceneStrokeNodeRenderer strokes;
  final SceneRichNodeRenderer rich;
}

class SceneNodeRenderContext {
  const SceneNodeRenderContext({
    required this.canvas,
    required this.cameraOffset,
    required this.transformBuffer,
  });

  final Canvas canvas;
  final Offset cameraOffset;
  final Float64List transformBuffer;
}

class SceneShapeNodeRenderer {
  const SceneShapeNodeRenderer();

  void drawRectNode(RectNodeSnapshot node, SceneNodeRenderContext context) {
    if (!node.transform.isFinite) {
      return;
    }
    final rect = scenePainterCenterRect(node.size);
    withTransform(
      context.canvas,
      scenePainterToViewTransform(
        context.transformBuffer,
        node.transform,
        context.cameraOffset,
      ),
      () {
        _drawFilledAndStrokedShape(
          style: (
            fillColor: node.fillColor,
            strokeColor: node.strokeColor,
            strokeWidth: node.strokeWidth,
            opacity: node.opacity,
          ),
          draw: (paint) => context.canvas.drawRect(rect, paint),
        );
      },
    );
  }

  void drawPathNode(
    PathNodeSnapshot node,
    Path? localPath,
    SceneNodeRenderContext context,
  ) {
    if (!node.transform.isFinite || localPath == null) {
      return;
    }

    withTransform(
      context.canvas,
      scenePainterToViewTransform(
        context.transformBuffer,
        node.transform,
        context.cameraOffset,
      ),
      () {
        _drawFilledAndStrokedShape(
          style: (
            fillColor: node.fillColor,
            strokeColor: node.strokeColor,
            strokeWidth: node.strokeWidth,
            opacity: node.opacity,
          ),
          draw: (paint) => context.canvas.drawPath(localPath, paint),
        );
      },
    );
  }
}

class SceneStrokeNodeRenderer {
  const SceneStrokeNodeRenderer({required this.strokePathCache});

  final SceneStrokePathCache? strokePathCache;

  void drawLineNode(LineNodeSnapshot node, SceneNodeRenderContext context) {
    if (!node.transform.isFinite ||
        !scenePainterIsFiniteOffset(node.start) ||
        !scenePainterIsFiniteOffset(node.end)) {
      return;
    }
    withTransform(
      context.canvas,
      scenePainterToViewTransform(
        context.transformBuffer,
        node.transform,
        context.cameraOffset,
      ),
      () {
        context.canvas.drawLine(
          node.start,
          node.end,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = clampNonNegativeFinite(node.thickness)
            ..strokeCap = StrokeCap.round
            ..color = scenePainterApplyOpacity(node.color, node.opacity),
        );
      },
    );
  }

  void drawStrokeNode(StrokeNodeSnapshot node, SceneNodeRenderContext context) {
    if (!scenePainterCanPaintStrokeNode(node)) {
      return;
    }

    final thickness = clampNonNegativeFinite(node.thickness);
    withTransform(
      context.canvas,
      scenePainterToViewTransform(
        context.transformBuffer,
        node.transform,
        context.cameraOffset,
      ),
      () {
        if (node.points.length == 1) {
          context.canvas.drawCircle(
            node.points.first,
            thickness / 2,
            Paint()
              ..style = PaintingStyle.fill
              ..color = scenePainterApplyOpacity(node.color, node.opacity),
          );
          return;
        }

        final path = scenePainterResolveStrokePath(node, strokePathCache);

        context.canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = thickness
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = scenePainterApplyOpacity(node.color, node.opacity),
        );
      },
    );
  }
}

class SceneRichNodeRenderer {
  const SceneRichNodeRenderer({
    required this.imageResolver,
    required this.textLayoutCache,
    required this.textDirection,
  });

  final Image? Function(String imageId) imageResolver;
  final SceneTextLayoutCache? textLayoutCache;
  final TextDirection textDirection;

  void drawTextNode(TextNodeSnapshot node, SceneNodeRenderContext context) {
    if (!node.transform.isFinite) {
      return;
    }
    final safeSize = clampNonNegativeSizeFinite(node.size);
    final textLayoutCache = this.textLayoutCache;
    final textPainter = textLayoutCache != null
        ? textLayoutCache.getOrBuild(node: node, textDirection: textDirection)
        : buildSceneTextPainter(node: node, textDirection: textDirection);

    final alignOffset = scenePainterTextAlignOffset(
      node.align,
      safeSize.width,
      textPainter.width,
      textDirection,
    );

    withTransform(
      context.canvas,
      scenePainterToViewTransform(
        context.transformBuffer,
        node.transform,
        context.cameraOffset,
      ),
      () {
        textPainter.paint(
          context.canvas,
          Offset(-safeSize.width / 2 + alignOffset, -safeSize.height / 2),
        );
      },
    );
  }

  void drawImageNode(ImageNodeSnapshot node, SceneNodeRenderContext context) {
    if (!node.transform.isFinite) {
      return;
    }
    final rect = scenePainterCenterRect(node.size);
    final image = imageResolver(node.imageId);
    withTransform(
      context.canvas,
      scenePainterToViewTransform(
        context.transformBuffer,
        node.transform,
        context.cameraOffset,
      ),
      () {
        if (image == null) {
          context.canvas.drawRect(
            rect,
            Paint()
              ..style = PaintingStyle.stroke
              ..color = const Color(0xFF9E9E9E),
          );
          return;
        }

        paintImage(
          canvas: context.canvas,
          rect: rect,
          image: image,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
          opacity: scenePainterAlpha01(node.opacity),
        );
      },
    );
  }
}

bool _canPaintNodeInFrame(
  ScenePainterResolvedNodePaintData resolvedNode,
  Rect viewRect,
) {
  final worldBounds = resolvedNode.worldBounds;
  return scenePainterIsFiniteRect(worldBounds) &&
      viewRect.overlaps(worldBounds);
}

void _drawResolvedNode(
  ScenePainterResolvedNodePaintData resolvedNode,
  SceneNodeRenderContext context,
  SceneNodeRenderSupport support,
) {
  withTranslate(context.canvas, resolvedNode.previewDelta, () {
    switch (resolvedNode.node) {
      case RectNodeSnapshot rectNode:
        support.shapes.drawRectNode(rectNode, context);
      case LineNodeSnapshot lineNode:
        support.strokes.drawLineNode(lineNode, context);
      case StrokeNodeSnapshot strokeNode:
        support.strokes.drawStrokeNode(strokeNode, context);
      case TextNodeSnapshot textNode:
        support.rich.drawTextNode(textNode, context);
      case ImageNodeSnapshot imageNode:
        support.rich.drawImageNode(imageNode, context);
      case PathNodeSnapshot pathNode:
        _drawPathNode(
          pathNode,
          resolvedNode.geometry.localPath,
          context,
          support,
        );
    }
  });
}

void _drawPathNode(
  PathNodeSnapshot node,
  Path? localPath,
  SceneNodeRenderContext context,
  SceneNodeRenderSupport support,
) {
  support.shapes.drawPathNode(node, localPath, context);
}

typedef _FillAndStrokeStyle = ({
  Color? fillColor,
  double opacity,
  Color? strokeColor,
  double strokeWidth,
});

void _drawFilledAndStrokedShape({
  required _FillAndStrokeStyle style,
  required void Function(Paint paint) draw,
}) {
  final fillColor = style.fillColor;
  if (fillColor != null) {
    draw(
      Paint()
        ..style = PaintingStyle.fill
        ..color = scenePainterApplyOpacity(fillColor, style.opacity),
    );
  }
  final safeStrokeWidth = clampNonNegativeFinite(style.strokeWidth);
  final strokeColor = style.strokeColor;
  if (strokeColor == null || safeStrokeWidth <= 0) {
    return;
  }
  draw(
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = safeStrokeWidth
      ..color = scenePainterApplyOpacity(strokeColor, style.opacity),
  );
}
