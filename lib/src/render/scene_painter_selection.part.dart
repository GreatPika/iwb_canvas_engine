part of 'scene_painter.dart';

class _SceneSelectionSupport {
  const _SceneSelectionSupport({
    required this.strokePathCache,
    required this.pathMetricsCache,
    required this.transformBuffer,
  });

  final SceneStrokePathCache? strokePathCache;
  final ScenePathMetricsCache? pathMetricsCache;
  final Float64List transformBuffer;
}

class _SceneSelectionPaintContext {
  const _SceneSelectionPaintContext({
    required this.canvas,
    required this.cameraOffset,
    required this.style,
    required this.transformBuffer,
  });

  final Canvas canvas;
  final Offset cameraOffset;
  final _SelectionStyle style;
  final Float64List transformBuffer;
}

class _SelectionHaloStyle {
  const _SelectionHaloStyle({
    required this.color,
    required this.haloWidth,
    this.baseStrokeWidth = 0,
  });

  final Color color;
  final double haloWidth;
  final double baseStrokeWidth;
}

void _drawSceneSelection(
  Canvas canvas,
  _PaintFrame frame,
  _SceneSelectionSupport support,
) {
  if (frame.hasNodeSelection) {
    final context = _SceneSelectionPaintContext(
      canvas: canvas,
      cameraOffset: frame.cameraOffset,
      style: frame.selectionStyle,
      transformBuffer: support.transformBuffer,
    );
    for (final node in frame.selectedNodes) {
      _drawSelectionForNode(node, context, support);
    }
  }

  _drawMarqueeSelection(canvas, frame);
}

void _drawMarqueeSelection(Canvas canvas, _PaintFrame frame) {
  final selectionRect = frame.selectionRect;
  if (selectionRect == null || !_isFiniteRect(selectionRect)) {
    return;
  }
  final normalized = _normalizeRect(selectionRect);
  final viewRect = normalized.shift(-frame.cameraOffset);
  final fillPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = _applyOpacity(frame.selectionStyle.color, 0.15);
  final strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = frame.selectionStyle.haloWidth
    ..color = frame.selectionStyle.color;
  canvas.drawRect(viewRect, fillPaint);
  canvas.drawRect(viewRect, strokePaint);
}

void _drawSelectionForNode(
  _ResolvedNodePaintData resolvedNode,
  _SceneSelectionPaintContext context,
  _SceneSelectionSupport support,
) {
  withTranslate(context.canvas, resolvedNode.previewDelta, () {
    switch (resolvedNode.node) {
      case ImageNodeSnapshot():
      case TextNodeSnapshot():
      case RectNodeSnapshot():
        _drawWorldBoundsSelection(resolvedNode, context);
      case LineNodeSnapshot line:
        _drawLineSelection(line, context);
      case StrokeNodeSnapshot stroke:
        _drawStrokeSelection(stroke, context, support.strokePathCache);
      case PathNodeSnapshot pathNode:
        _drawPathSelection(
          pathNode,
          resolvedNode.geometry.localPath,
          context,
          support.pathMetricsCache,
        );
    }
  });
}

void _drawLineSelection(
  LineNodeSnapshot node,
  _SceneSelectionPaintContext context,
) {
  if (!node.transform.isFinite ||
      !_isFiniteOffset(node.start) ||
      !_isFiniteOffset(node.end)) {
    return;
  }
  final baseThickness = clampNonNegativeFinite(node.thickness);
  withTransform(
    context.canvas,
    _toViewTransform(
      context.transformBuffer,
      node.transform,
      context.cameraOffset,
    ),
    () {
      final style = _SelectionHaloStyle(
        color: context.style.color,
        haloWidth: context.style.haloWidth,
        baseStrokeWidth: baseThickness,
      );
      context.canvas.drawLine(
        node.start,
        node.end,
        _haloPaint(style, cap: StrokeCap.round),
      );
      context.canvas.drawLine(
        node.start,
        node.end,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = baseThickness
          ..strokeCap = StrokeCap.round
          ..color = _applyOpacity(node.color, node.opacity),
      );
    },
  );
}

void _drawStrokeSelection(
  StrokeNodeSnapshot node,
  _SceneSelectionPaintContext context,
  SceneStrokePathCache? strokePathCache,
) {
  if (!_canPaintStrokeNode(node)) {
    return;
  }
  final baseThickness = clampNonNegativeFinite(node.thickness);
  withTransform(
    context.canvas,
    _toViewTransform(
      context.transformBuffer,
      node.transform,
      context.cameraOffset,
    ),
    () {
      if (node.points.length == 1) {
        _drawDotSelection(
          context,
          center: node.points.first,
          radius: baseThickness / 2,
          baseColor: _applyOpacity(node.color, node.opacity),
        );
        return;
      }

      final path = _resolveStrokePath(node, strokePathCache);
      final style = _SelectionHaloStyle(
        color: context.style.color,
        haloWidth: context.style.haloWidth,
        baseStrokeWidth: baseThickness,
      );
      context.canvas.drawPath(
        path,
        _haloPaint(style, cap: StrokeCap.round, join: StrokeJoin.round),
      );
      context.canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = baseThickness
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = _applyOpacity(node.color, node.opacity),
      );
    },
  );
}

void _drawPathSelection(
  PathNodeSnapshot node,
  Path? localPath,
  _SceneSelectionPaintContext context,
  ScenePathMetricsCache? pathMetricsCache,
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
      final safeStrokeWidth = clampNonNegativeFinite(node.strokeWidth);
      final hasStroke = node.strokeColor != null && safeStrokeWidth > 0;
      final baseStrokeWidth = hasStroke ? safeStrokeWidth : 0.0;
      final contours = pathMetricsCache != null
          ? pathMetricsCache.getOrBuild(node: node, localPath: localPath)
          : buildPathSelectionContours(localPath, node.fillRule);
      final style = _SelectionHaloStyle(
        color: context.style.color,
        haloWidth: context.style.haloWidth,
        baseStrokeWidth: baseStrokeWidth,
      );
      _drawClosedPathSelection(context.canvas, contours.closedContours, style);
      _drawOpenPathSelection(contours.openContours, node, context, style);
    },
  );
}

void _drawClosedPathSelection(
  Canvas canvas,
  Path? closedContours,
  _SelectionHaloStyle style,
) {
  if (closedContours == null) {
    return;
  }
  _drawPathHalo(canvas, closedContours, style, clearFill: true);
}

void _drawOpenPathSelection(
  List<Path> contours,
  PathNodeSnapshot node,
  _SceneSelectionPaintContext context,
  _SelectionHaloStyle style,
) {
  for (final contour in contours) {
    context.canvas.drawPath(
      contour,
      _haloPaint(style, cap: StrokeCap.round, join: StrokeJoin.round),
    );
    if (style.baseStrokeWidth <= 0) {
      continue;
    }
    context.canvas.drawPath(
      contour,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.baseStrokeWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = _applyOpacity(
          node.strokeColor ?? context.style.color,
          node.opacity,
        ),
    );
  }
}

void _drawWorldBoundsSelection(
  _ResolvedNodePaintData node,
  _SceneSelectionPaintContext context,
) {
  final worldBounds = node.geometry.worldBounds;
  if (!_isFiniteRect(worldBounds)) {
    return;
  }
  final viewRect = worldBounds.shift(-context.cameraOffset);
  _drawRectHalo(
    context.canvas,
    viewRect,
    _SelectionHaloStyle(
      color: context.style.color,
      haloWidth: context.style.haloWidth,
    ),
    clearFill: true,
  );
}

Paint _haloPaint(
  _SelectionHaloStyle style, {
  StrokeCap cap = StrokeCap.round,
  StrokeJoin join = StrokeJoin.round,
}) {
  return Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = clampNonNegativeFinite(
      style.baseStrokeWidth + style.haloWidth * 2,
    )
    ..strokeCap = cap
    ..strokeJoin = join
    ..color = style.color;
}

void _drawDotSelection(
  _SceneSelectionPaintContext context, {
  required Offset center,
  required double radius,
  required Color baseColor,
}) {
  context.canvas.drawCircle(
    center,
    radius + context.style.haloWidth,
    Paint()
      ..style = PaintingStyle.fill
      ..color = context.style.color,
  );
  context.canvas.drawCircle(
    center,
    radius,
    Paint()
      ..style = PaintingStyle.fill
      ..color = baseColor,
  );
}

void _drawRectHalo(
  Canvas canvas,
  Rect rect,
  _SelectionHaloStyle style, {
  required bool clearFill,
}) {
  canvas.saveLayer(null, Paint());
  canvas.drawRect(
    rect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = clampNonNegativeFinite(style.haloWidth * 2)
      ..color = style.color,
  );
  final clearPaint = Paint()..blendMode = BlendMode.clear;
  if (clearFill) {
    clearPaint.style = PaintingStyle.fill;
    canvas.drawRect(rect, clearPaint);
  }
  canvas.restore();
}

void _drawPathHalo(
  Canvas canvas,
  Path path,
  _SelectionHaloStyle style, {
  required bool clearFill,
}) {
  canvas.saveLayer(null, Paint());
  canvas.drawPath(path, _haloPaint(style));
  final clearPaint = Paint()..blendMode = BlendMode.clear;
  if (clearFill) {
    clearPaint.style = PaintingStyle.fill;
    canvas.drawPath(path, clearPaint);
  }
  if (style.baseStrokeWidth > 0) {
    clearPaint
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..strokeWidth = style.baseStrokeWidth;
    canvas.drawPath(path, clearPaint);
  }
  canvas.restore();
}
