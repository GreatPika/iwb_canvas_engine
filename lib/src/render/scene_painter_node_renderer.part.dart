part of 'scene_painter.dart';

typedef _FillAndStrokeStyle = ({
  Color? fillColor,
  double opacity,
  Color? strokeColor,
  double strokeWidth,
});

class _SceneNodeRenderSupport {
  _SceneNodeRenderSupport({
    required ImageResolver imageResolver,
    required SceneTextLayoutCache? textLayoutCache,
    required SceneStrokePathCache? strokePathCache,
    required TextDirection textDirection,
  }) : shapes = _SceneShapeNodeRenderer(),
       strokes = _SceneStrokeNodeRenderer(strokePathCache: strokePathCache),
       rich = _SceneRichNodeRenderer(
         imageResolver: imageResolver,
         textLayoutCache: textLayoutCache,
         textDirection: textDirection,
       );

  final _SceneShapeNodeRenderer shapes;
  final _SceneStrokeNodeRenderer strokes;
  final _SceneRichNodeRenderer rich;
}

class _SceneNodeRenderContext {
  const _SceneNodeRenderContext({
    required this.canvas,
    required this.cameraOffset,
    required this.transformBuffer,
  });

  final Canvas canvas;
  final Offset cameraOffset;
  final Float64List transformBuffer;
}

class _SceneShapeNodeRenderer {
  const _SceneShapeNodeRenderer();

  void drawRectNode(RectNodeSnapshot node, _SceneNodeRenderContext context) {
    if (!node.transform.isFinite) {
      return;
    }
    final rect = _centerRect(node.size);
    withTransform(
      context.canvas,
      _toViewTransform(
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
    _SceneNodeRenderContext context,
  ) {
    if (!node.transform.isFinite || localPath == null) {
      return;
    }

    withTransform(
      context.canvas,
      _toViewTransform(
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

class _SceneStrokeNodeRenderer {
  const _SceneStrokeNodeRenderer({required this.strokePathCache});

  final SceneStrokePathCache? strokePathCache;

  void drawLineNode(LineNodeSnapshot node, _SceneNodeRenderContext context) {
    if (!node.transform.isFinite ||
        !_isFiniteOffset(node.start) ||
        !_isFiniteOffset(node.end)) {
      return;
    }
    withTransform(
      context.canvas,
      _toViewTransform(
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
            ..color = _applyOpacity(node.color, node.opacity),
        );
      },
    );
  }

  void drawStrokeNode(
    StrokeNodeSnapshot node,
    _SceneNodeRenderContext context,
  ) {
    if (!_canPaintStrokeNode(node)) {
      return;
    }

    final thickness = clampNonNegativeFinite(node.thickness);
    withTransform(
      context.canvas,
      _toViewTransform(
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
              ..color = _applyOpacity(node.color, node.opacity),
          );
          return;
        }

        final path = _resolveStrokePath(node, strokePathCache);

        context.canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = thickness
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = _applyOpacity(node.color, node.opacity),
        );
      },
    );
  }
}

class _SceneRichNodeRenderer {
  const _SceneRichNodeRenderer({
    required this.imageResolver,
    required this.textLayoutCache,
    required this.textDirection,
  });

  final ImageResolver imageResolver;
  final SceneTextLayoutCache? textLayoutCache;
  final TextDirection textDirection;

  void drawTextNode(TextNodeSnapshot node, _SceneNodeRenderContext context) {
    if (!node.transform.isFinite) {
      return;
    }
    final safeSize = clampNonNegativeSizeFinite(node.size);
    final textLayoutCache = this.textLayoutCache;
    final textPainter = textLayoutCache != null
        ? textLayoutCache.getOrBuild(node: node, textDirection: textDirection)
        : buildSceneTextPainter(node: node, textDirection: textDirection);

    final alignOffset = _textAlignOffset(
      node.align,
      safeSize.width,
      textPainter.width,
      textDirection,
    );

    withTransform(
      context.canvas,
      _toViewTransform(
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

  void drawImageNode(ImageNodeSnapshot node, _SceneNodeRenderContext context) {
    if (!node.transform.isFinite) {
      return;
    }
    final rect = _centerRect(node.size);
    final image = imageResolver(node.imageId);
    withTransform(
      context.canvas,
      _toViewTransform(
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
          opacity: _alpha01(node.opacity),
        );
      },
    );
  }
}

void _drawResolvedNode(
  _ResolvedNodePaintData resolvedNode,
  _SceneNodeRenderContext context,
  _SceneNodeRenderSupport support,
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
  _SceneNodeRenderContext context,
  _SceneNodeRenderSupport support,
) {
  support.shapes.drawPathNode(node, localPath, context);
}

void _drawFilledAndStrokedShape({
  required _FillAndStrokeStyle style,
  required void Function(Paint paint) draw,
}) {
  final fillColor = style.fillColor;
  if (fillColor != null) {
    draw(
      Paint()
        ..style = PaintingStyle.fill
        ..color = _applyOpacity(fillColor, style.opacity),
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
      ..color = _applyOpacity(strokeColor, style.opacity),
  );
}
