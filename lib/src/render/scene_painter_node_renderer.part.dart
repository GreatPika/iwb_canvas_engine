part of 'scene_painter.dart';

typedef _FillAndStrokeStyle = ({
  Color? fillColor,
  double opacity,
  Color? strokeColor,
  double strokeWidth,
});

class _ScenePainterNodeRenderer {
  const _ScenePainterNodeRenderer({
    required this.imageResolver,
    required this.textLayoutCache,
    required this.strokePathCache,
    required this.textDirection,
    required this.transformBuffer,
  });

  final ImageResolver imageResolver;
  final SceneTextLayoutCache? textLayoutCache;
  final SceneStrokePathCache? strokePathCache;
  final TextDirection textDirection;
  final Float64List transformBuffer;

  void draw(
    Canvas canvas,
    _ResolvedNodePaintData resolvedNode,
    Offset cameraOffset,
  ) {
    withTranslate(canvas, resolvedNode.previewDelta, () {
      switch (resolvedNode.node) {
        case RectNodeSnapshot rectNode:
          _drawRectNode(canvas, rectNode, cameraOffset);
        case LineNodeSnapshot lineNode:
          _drawLineNode(canvas, lineNode, cameraOffset);
        case StrokeNodeSnapshot strokeNode:
          _drawStrokeNode(canvas, strokeNode, cameraOffset);
        case TextNodeSnapshot textNode:
          _drawTextNode(canvas, textNode, cameraOffset);
        case ImageNodeSnapshot imageNode:
          _drawImageNode(canvas, imageNode, cameraOffset);
        case PathNodeSnapshot pathNode:
          _drawPathNode(
            canvas,
            pathNode,
            cameraOffset,
            localPath: resolvedNode.geometry.localPath,
          );
      }
    });
  }

  void _drawRectNode(
    Canvas canvas,
    RectNodeSnapshot node,
    Offset cameraOffset,
  ) {
    if (!node.transform.isFinite) {
      return;
    }
    final rect = _centerRect(node.size);
    withTransform(
      canvas,
      _toViewTransform(transformBuffer, node.transform, cameraOffset),
      () {
        _drawFilledAndStrokedShape(
          style: (
            fillColor: node.fillColor,
            strokeColor: node.strokeColor,
            strokeWidth: node.strokeWidth,
            opacity: node.opacity,
          ),
          draw: (paint) => canvas.drawRect(rect, paint),
        );
      },
    );
  }

  void _drawLineNode(
    Canvas canvas,
    LineNodeSnapshot node,
    Offset cameraOffset,
  ) {
    if (!node.transform.isFinite ||
        !_isFiniteOffset(node.start) ||
        !_isFiniteOffset(node.end)) {
      return;
    }
    withTransform(
      canvas,
      _toViewTransform(transformBuffer, node.transform, cameraOffset),
      () {
        canvas.drawLine(
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

  void _drawStrokeNode(
    Canvas canvas,
    StrokeNodeSnapshot node,
    Offset cameraOffset,
  ) {
    if (!_canPaintStrokeNode(node)) {
      return;
    }

    final thickness = clampNonNegativeFinite(node.thickness);
    withTransform(
      canvas,
      _toViewTransform(transformBuffer, node.transform, cameraOffset),
      () {
        if (node.points.length == 1) {
          canvas.drawCircle(
            node.points.first,
            thickness / 2,
            Paint()
              ..style = PaintingStyle.fill
              ..color = _applyOpacity(node.color, node.opacity),
          );
          return;
        }

        final path = _resolveStrokePath(node, strokePathCache);

        canvas.drawPath(
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

  void _drawTextNode(
    Canvas canvas,
    TextNodeSnapshot node,
    Offset cameraOffset,
  ) {
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
      canvas,
      _toViewTransform(transformBuffer, node.transform, cameraOffset),
      () {
        textPainter.paint(
          canvas,
          Offset(-safeSize.width / 2 + alignOffset, -safeSize.height / 2),
        );
      },
    );
  }

  void _drawImageNode(
    Canvas canvas,
    ImageNodeSnapshot node,
    Offset cameraOffset,
  ) {
    if (!node.transform.isFinite) {
      return;
    }
    final rect = _centerRect(node.size);
    final image = imageResolver(node.imageId);
    withTransform(
      canvas,
      _toViewTransform(transformBuffer, node.transform, cameraOffset),
      () {
        if (image == null) {
          canvas.drawRect(
            rect,
            Paint()
              ..style = PaintingStyle.stroke
              ..color = const Color(0xFF9E9E9E),
          );
          return;
        }

        paintImage(
          canvas: canvas,
          rect: rect,
          image: image,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
          opacity: _alpha01(node.opacity),
        );
      },
    );
  }

  void _drawPathNode(
    Canvas canvas,
    PathNodeSnapshot node,
    Offset cameraOffset, {
    required Path? localPath,
  }) {
    if (!node.transform.isFinite || localPath == null) {
      return;
    }

    withTransform(
      canvas,
      _toViewTransform(transformBuffer, node.transform, cameraOffset),
      () {
        _drawFilledAndStrokedShape(
          style: (
            fillColor: node.fillColor,
            strokeColor: node.strokeColor,
            strokeWidth: node.strokeWidth,
            opacity: node.opacity,
          ),
          draw: (paint) => canvas.drawPath(localPath, paint),
        );
      },
    );
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
}
