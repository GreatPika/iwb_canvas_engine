import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../core/numeric_clamp.dart';
import '../core/text_layout.dart';
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
  }) : _geometryCache = geometryCache ?? RenderGeometryCache(),
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
  final RenderGeometryCache _geometryCache;

  final Float64List _transformBuffer = Float64List(16);

  @override
  void paint(Canvas canvas, Size size) {
    final snapshot = controller.snapshot;
    final frame = _createPaintFrame(snapshot, size);

    final staticLayerCache = this.staticLayerCache;
    if (staticLayerCache != null) {
      staticLayerCache.draw(
        canvas,
        size,
        background: snapshot.background,
        cameraOffset: frame.cameraOffset,
        gridStrokeWidth: gridStrokeWidth,
      );
    } else {
      _drawBackground(canvas, size, snapshot.background.color);
      _gridRenderer.draw(
        canvas,
        snapshot.background.grid,
        size: size,
        cameraOffset: frame.cameraOffset,
        gridStrokeWidth: gridStrokeWidth,
      );
    }

    _drawNodeLayers(canvas, snapshot, frame);
    _drawSelection(canvas, frame);
  }

  _PaintFrame _createPaintFrame(SceneSnapshot snapshot, Size size) {
    final cameraOffset = sanitizeFiniteOffset(snapshot.camera.offset);
    return _PaintFrame(
      cameraOffset: cameraOffset,
      viewRect: Rect.fromLTWH(
        cameraOffset.dx,
        cameraOffset.dy,
        size.width,
        size.height,
      ).inflate(_cullPadding),
      selectedIds: controller.selectedNodeIds,
      selectionRect: selectionRect,
      selectionStyle: _SelectionStyle(
        color: selectionColor,
        haloWidth: clampNonNegativeFinite(selectionStrokeWidth),
      ),
    );
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
      final resolvedNode = _resolveNodePaintData(node);
      if (!_canPaintNodeInFrame(resolvedNode, frame.viewRect)) {
        continue;
      }
      _drawNode(canvas, resolvedNode, frame.cameraOffset);
      if (frame.isSelected(node.id)) {
        frame.selectedNodes.add(resolvedNode);
      }
    }
  }

  _ResolvedNodePaintData _resolveNodePaintData(NodeSnapshot node) {
    return _ResolvedNodePaintData(
      node: node,
      previewDelta: _nodePreviewOffset(node.id),
      geometry: _geometryCache.get(node),
    );
  }

  bool _canPaintNodeInFrame(_ResolvedNodePaintData node, Rect viewRect) {
    final worldBounds = node.worldBounds;
    return _isFiniteRect(worldBounds) && viewRect.overlaps(worldBounds);
  }

  void _drawSelection(Canvas canvas, _PaintFrame frame) {
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
    if (selectionRect == null) {
      return;
    }
    if (!_isFiniteRect(selectionRect)) {
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
    withTransform(canvas, _toViewTransform(node.transform, cameraOffset), () {
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
    });
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
    withTransform(canvas, _toViewTransform(node.transform, cameraOffset), () {
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
    });
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
    withTransform(canvas, _toViewTransform(node.transform, cameraOffset), () {
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
    });
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

  void _drawNode(
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
    withTransform(canvas, _toViewTransform(node.transform, cameraOffset), () {
      final fillColor = node.fillColor;
      if (fillColor != null) {
        canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.fill
            ..color = _applyOpacity(fillColor, node.opacity),
        );
      }
      final strokeWidth = clampNonNegativeFinite(node.strokeWidth);
      final strokeColor = node.strokeColor;
      if (strokeColor != null && strokeWidth > 0) {
        canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..color = _applyOpacity(strokeColor, node.opacity),
        );
      }
    });
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
    withTransform(canvas, _toViewTransform(node.transform, cameraOffset), () {
      canvas.drawLine(
        node.start,
        node.end,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = clampNonNegativeFinite(node.thickness)
          ..strokeCap = StrokeCap.round
          ..color = _applyOpacity(node.color, node.opacity),
      );
    });
  }

  void _drawStrokeNode(
    Canvas canvas,
    StrokeNodeSnapshot node,
    Offset cameraOffset,
  ) {
    if (node.points.isEmpty ||
        !node.transform.isFinite ||
        !_areFiniteOffsets(node.points)) {
      return;
    }

    final thickness = clampNonNegativeFinite(node.thickness);
    withTransform(canvas, _toViewTransform(node.transform, cameraOffset), () {
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

      final strokePathCache = this.strokePathCache;
      final path = strokePathCache != null
          ? strokePathCache.getOrBuild(node)
          : buildStrokePath(node.points);

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = _applyOpacity(node.color, node.opacity),
      );
    });
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
        : _buildTextPainter(
            node,
            buildTextStyleForTextLayout(
              color: _applyOpacity(node.color, node.opacity),
              fontSize: node.fontSize,
              fontFamily: node.fontFamily,
              isBold: node.isBold,
              isItalic: node.isItalic,
              isUnderline: node.isUnderline,
              lineHeight: node.lineHeight,
            ),
            normalizeTextLayoutMaxWidth(node.maxWidth),
          );

    final alignOffset = _textAlignOffset(
      node.align,
      safeSize.width,
      textPainter.width,
      textDirection,
    );

    withTransform(canvas, _toViewTransform(node.transform, cameraOffset), () {
      textPainter.paint(
        canvas,
        Offset(-safeSize.width / 2 + alignOffset, -safeSize.height / 2),
      );
    });
  }

  TextPainter _buildTextPainter(
    TextNodeSnapshot node,
    TextStyle style,
    double? maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: node.text, style: style),
      textAlign: node.align,
      textDirection: textDirection,
      maxLines: null,
    );
    final safeMaxWidth = normalizeTextLayoutMaxWidth(maxWidth);
    if (safeMaxWidth == null) {
      painter.layout();
    } else {
      painter.layout(maxWidth: safeMaxWidth);
    }
    return painter;
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
    withTransform(canvas, _toViewTransform(node.transform, cameraOffset), () {
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
    });
  }

  void _drawPathNode(
    Canvas canvas,
    PathNodeSnapshot node,
    Offset cameraOffset, {
    required Path? localPath,
  }) {
    if (!node.transform.isFinite) {
      return;
    }
    if (localPath == null) {
      return;
    }

    withTransform(canvas, _toViewTransform(node.transform, cameraOffset), () {
      final fillColor = node.fillColor;
      if (fillColor != null) {
        canvas.drawPath(
          localPath,
          Paint()
            ..style = PaintingStyle.fill
            ..color = _applyOpacity(fillColor, node.opacity),
        );
      }

      final strokeWidth = clampNonNegativeFinite(node.strokeWidth);
      final strokeColor = node.strokeColor;
      if (strokeColor != null && strokeWidth > 0) {
        canvas.drawPath(
          localPath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..color = _applyOpacity(strokeColor, node.opacity),
        );
      }
    });
  }

  Offset _nodePreviewOffset(NodeId nodeId) {
    return sanitizeFiniteOffset(
      nodePreviewOffsetResolver?.call(nodeId) ?? Offset.zero,
    );
  }

  Float64List _toViewTransform(Transform2D transform, Offset cameraOffset) {
    _transformBuffer[0] = transform.a;
    _transformBuffer[1] = transform.b;
    _transformBuffer[2] = 0;
    _transformBuffer[3] = 0;
    _transformBuffer[4] = transform.c;
    _transformBuffer[5] = transform.d;
    _transformBuffer[6] = 0;
    _transformBuffer[7] = 0;
    _transformBuffer[8] = 0;
    _transformBuffer[9] = 0;
    _transformBuffer[10] = 1;
    _transformBuffer[11] = 0;
    _transformBuffer[12] = transform.tx - cameraOffset.dx;
    _transformBuffer[13] = transform.ty - cameraOffset.dy;
    _transformBuffer[14] = 0;
    _transformBuffer[15] = 1;
    return _transformBuffer;
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

class _PaintFrame {
  _PaintFrame({
    required this.cameraOffset,
    required this.viewRect,
    required this.selectedIds,
    required this.selectionRect,
    required this.selectionStyle,
  });

  final Offset cameraOffset;
  final Rect viewRect;
  final Set<NodeId> selectedIds;
  final Rect? selectionRect;
  final _SelectionStyle selectionStyle;
  final List<_ResolvedNodePaintData> selectedNodes = <_ResolvedNodePaintData>[];

  bool get hasNodeSelection =>
      selectedNodes.isNotEmpty && selectionStyle.haloWidth > 0;

  bool isSelected(NodeId nodeId) => selectedIds.contains(nodeId);
}

class _SelectionStyle {
  const _SelectionStyle({required this.color, required this.haloWidth});

  final Color color;
  final double haloWidth;
}

class _ResolvedNodePaintData {
  const _ResolvedNodePaintData({
    required this.node,
    required this.previewDelta,
    required this.geometry,
  });

  final NodeSnapshot node;
  final Offset previewDelta;
  final GeometryEntry geometry;

  Rect get worldBounds {
    if (previewDelta == Offset.zero) {
      return geometry.worldBounds;
    }
    return geometry.worldBounds.shift(previewDelta);
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

PathFillType _fillTypeFromSnapshot(PathFillRule rule) {
  return rule == PathFillRule.evenOdd
      ? PathFillType.evenOdd
      : PathFillType.nonZero;
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
