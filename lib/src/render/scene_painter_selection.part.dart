part of 'scene_painter.dart';

class _ScenePainterSelectionOwner {
  const _ScenePainterSelectionOwner({
    required this.strokePathCache,
    required this.pathMetricsCache,
    required this.transformBuffer,
  });

  final SceneStrokePathCache? strokePathCache;
  final ScenePathMetricsCache? pathMetricsCache;
  final Float64List transformBuffer;

  void draw(Canvas canvas, _PaintFrame frame) {
    if (frame.hasNodeSelection) {
      for (final node in frame.selectedNodes) {
        _drawSelectionForNode(
          canvas,
          node,
          frame.cameraOffset,
          frame.selectionStyle,
        );
      }
    }

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
    Canvas canvas,
    _ResolvedNodePaintData resolvedNode,
    Offset cameraOffset,
    _SelectionStyle style,
  ) {
    withTranslate(canvas, resolvedNode.previewDelta, () {
      switch (resolvedNode.node) {
        case ImageNodeSnapshot():
        case TextNodeSnapshot():
        case RectNodeSnapshot():
          _drawWorldBoundsSelection(canvas, resolvedNode, cameraOffset, style);
        case LineNodeSnapshot line:
          _drawLineSelection(canvas, line, cameraOffset, style);
        case StrokeNodeSnapshot stroke:
          _drawStrokeSelection(canvas, stroke, cameraOffset, style);
        case PathNodeSnapshot pathNode:
          _drawPathSelection(
            canvas,
            pathNode,
            resolvedNode.geometry.localPath,
            cameraOffset,
            style,
          );
      }
    });
  }

  void _drawLineSelection(
    Canvas canvas,
    LineNodeSnapshot node,
    Offset cameraOffset,
    _SelectionStyle style,
  ) {
    if (!node.transform.isFinite ||
        !_isFiniteOffset(node.start) ||
        !_isFiniteOffset(node.end)) {
      return;
    }
    final baseThickness = clampNonNegativeFinite(node.thickness);
    withTransform(
      canvas,
      _toViewTransform(transformBuffer, node.transform, cameraOffset),
      () {
        canvas.drawLine(
          node.start,
          node.end,
          _haloPaint(
            baseThickness + style.haloWidth * 2,
            style.color,
            cap: StrokeCap.round,
          ),
        );
        canvas.drawLine(
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
    Canvas canvas,
    StrokeNodeSnapshot node,
    Offset cameraOffset,
    _SelectionStyle style,
  ) {
    if (node.points.isEmpty ||
        !node.transform.isFinite ||
        !_areFiniteOffsets(node.points)) {
      return;
    }
    final baseThickness = clampNonNegativeFinite(node.thickness);
    withTransform(
      canvas,
      _toViewTransform(transformBuffer, node.transform, cameraOffset),
      () {
        if (node.points.length == 1) {
          _drawDotSelection(
            canvas,
            center: node.points.first,
            radius: baseThickness / 2,
            style: style,
            baseColor: _applyOpacity(node.color, node.opacity),
          );
          return;
        }

        final strokePathCache = this.strokePathCache;
        final path = strokePathCache != null
            ? strokePathCache.getOrBuild(node)
            : buildStrokePath(node.points);
        canvas.drawPath(
          path,
          _haloPaint(
            baseThickness + style.haloWidth * 2,
            style.color,
            cap: StrokeCap.round,
            join: StrokeJoin.round,
          ),
        );
        canvas.drawPath(
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
    Canvas canvas,
    PathNodeSnapshot node,
    Path? localPath,
    Offset cameraOffset,
    _SelectionStyle style,
  ) {
    if (!node.transform.isFinite || localPath == null) {
      return;
    }
    withTransform(
      canvas,
      _toViewTransform(transformBuffer, node.transform, cameraOffset),
      () {
        final safeStrokeWidth = clampNonNegativeFinite(node.strokeWidth);
        final hasStroke = node.strokeColor != null && safeStrokeWidth > 0;
        final baseStrokeWidth = hasStroke ? safeStrokeWidth : 0.0;
        final pathMetricsCache = this.pathMetricsCache;
        final contours = pathMetricsCache != null
            ? pathMetricsCache.getOrBuild(node: node, localPath: localPath)
            : _buildPathSelectionContours(pathNode: node, localPath: localPath);
        _drawClosedPathSelection(
          canvas,
          contours.closedContours,
          style,
          baseStrokeWidth: baseStrokeWidth,
        );
        _drawOpenPathSelection(
          canvas,
          contours.openContours,
          node,
          style,
          baseStrokeWidth: baseStrokeWidth,
        );
      },
    );
  }

  void _drawClosedPathSelection(
    Canvas canvas,
    Path? closedContours,
    _SelectionStyle style, {
    required double baseStrokeWidth,
  }) {
    if (closedContours == null) {
      return;
    }
    _drawPathHalo(
      canvas,
      closedContours,
      style.color,
      style.haloWidth,
      baseStrokeWidth: baseStrokeWidth,
      clearFill: true,
    );
  }

  void _drawOpenPathSelection(
    Canvas canvas,
    List<Path> contours,
    PathNodeSnapshot node,
    _SelectionStyle style, {
    required double baseStrokeWidth,
  }) {
    for (final contour in contours) {
      canvas.drawPath(
        contour,
        _haloPaint(
          baseStrokeWidth + style.haloWidth * 2,
          style.color,
          cap: StrokeCap.round,
          join: StrokeJoin.round,
        ),
      );
      if (baseStrokeWidth <= 0) {
        continue;
      }
      canvas.drawPath(
        contour,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = baseStrokeWidth
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = _applyOpacity(
            node.strokeColor ?? style.color,
            node.opacity,
          ),
      );
    }
  }

  PathSelectionContours _buildPathSelectionContours({
    required PathNodeSnapshot pathNode,
    required Path localPath,
  }) {
    final selectionFillType = _fillTypeFromSnapshot(pathNode.fillRule);
    Path? closedContours;
    final openContours = <Path>[];
    for (final metric in localPath.computeMetrics()) {
      final contour = metric.extractPath(
        0,
        metric.length,
        startWithMoveTo: true,
      );
      contour.fillType = selectionFillType;
      if (metric.isClosed) {
        contour.close();
        closedContours ??= Path()..fillType = selectionFillType;
        closedContours.addPath(contour, Offset.zero);
      } else {
        openContours.add(contour);
      }
    }
    return PathSelectionContours(
      closedContours: closedContours,
      openContours: List<Path>.unmodifiable(openContours),
    );
  }

  void _drawWorldBoundsSelection(
    Canvas canvas,
    _ResolvedNodePaintData node,
    Offset cameraOffset,
    _SelectionStyle style,
  ) {
    final worldBounds = node.geometry.worldBounds;
    if (!_isFiniteRect(worldBounds)) {
      return;
    }
    final viewRect = worldBounds.shift(-cameraOffset);
    _drawRectHalo(
      canvas,
      viewRect,
      style.color,
      style.haloWidth,
      clearFill: true,
    );
  }

  Paint _haloPaint(
    double strokeWidth,
    Color color, {
    StrokeCap cap = StrokeCap.round,
    StrokeJoin join = StrokeJoin.round,
  }) {
    return Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = clampNonNegativeFinite(strokeWidth)
      ..strokeCap = cap
      ..strokeJoin = join
      ..color = color;
  }

  void _drawDotSelection(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required _SelectionStyle style,
    required Color baseColor,
  }) {
    canvas.drawCircle(
      center,
      radius + style.haloWidth,
      Paint()
        ..style = PaintingStyle.fill
        ..color = style.color,
    );
    canvas.drawCircle(
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
    Color color,
    double haloWidth, {
    required bool clearFill,
  }) {
    canvas.saveLayer(null, Paint());
    final safeHaloWidth = clampNonNegativeFinite(haloWidth);
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = clampNonNegativeFinite(safeHaloWidth * 2)
        ..color = color,
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
    Color color,
    double haloWidth, {
    required double baseStrokeWidth,
    required bool clearFill,
  }) {
    canvas.saveLayer(null, Paint());
    final safeHaloWidth = clampNonNegativeFinite(haloWidth);
    final safeBaseStrokeWidth = clampNonNegativeFinite(baseStrokeWidth);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = clampNonNegativeFinite(
          safeBaseStrokeWidth + safeHaloWidth * 2,
        )
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    if (clearFill) {
      clearPaint.style = PaintingStyle.fill;
      canvas.drawPath(path, clearPaint);
    }
    if (safeBaseStrokeWidth > 0) {
      clearPaint
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..strokeWidth = safeBaseStrokeWidth;
      canvas.drawPath(path, clearPaint);
    }
    canvas.restore();
  }
}
