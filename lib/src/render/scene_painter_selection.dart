import 'dart:typed_data';
import 'dart:ui';

import '../contract/snapshot.dart';
import '../core/numeric_clamp.dart';
import 'cache/scene_path_metrics_cache.dart';
import 'cache/scene_stroke_path_cache.dart';
import 'canvas_scope.dart';
import 'scene_painter_contract.dart';
import 'scene_painter_shared.dart';
import 'selection_halo_compositing.dart';

class ScenePainterSelectionRenderer {
  ScenePainterSelectionRenderer({
    required SceneStrokePathCache? strokePathCache,
    required ScenePathMetricsCache? pathMetricsCache,
    required Float64List transformBuffer,
  }) : _support = SceneSelectionSupport(
         strokePathCache: strokePathCache,
         pathMetricsCache: pathMetricsCache,
         transformBuffer: transformBuffer,
       );

  final SceneSelectionSupport _support;

  void drawSceneSelection(Canvas canvas, ScenePainterPaintFrame frame) {
    if (frame.hasNodeSelection) {
      final context = SceneSelectionPaintContext(
        canvas: canvas,
        cameraOffset: frame.cameraOffset,
        style: frame.selectionStyle,
        transformBuffer: _support.transformBuffer,
      );
      for (final node in frame.selectedNodes) {
        _drawSelectionForNode(node, context, _support);
      }
    }
  }
}

class SceneSelectionSupport {
  const SceneSelectionSupport({
    required this.strokePathCache,
    required this.pathMetricsCache,
    required this.transformBuffer,
  });

  final SceneStrokePathCache? strokePathCache;
  final ScenePathMetricsCache? pathMetricsCache;
  final Float64List transformBuffer;
}

class SceneSelectionPaintContext {
  const SceneSelectionPaintContext({
    required this.canvas,
    required this.cameraOffset,
    required this.style,
    required this.transformBuffer,
  });

  final Canvas canvas;
  final Offset cameraOffset;
  final ScenePainterSelectionStyle style;
  final Float64List transformBuffer;
}

void _drawSelectionForNode(
  ScenePainterResolvedNodePaintData resolvedNode,
  SceneSelectionPaintContext context,
  SceneSelectionSupport support,
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
  SceneSelectionPaintContext context,
) {
  if (!node.transform.isFinite ||
      !scenePainterIsFiniteOffset(node.start) ||
      !scenePainterIsFiniteOffset(node.end)) {
    return;
  }
  final baseThickness = clampNonNegativeFinite(node.thickness);
  withTransform(
    context.canvas,
    scenePainterToViewTransform(
      context.transformBuffer,
      node.transform,
      context.cameraOffset,
    ),
    () {
      final style = SelectionHaloStyle(
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
          ..color = scenePainterApplyOpacity(node.color, node.opacity),
      );
    },
  );
}

void _drawStrokeSelection(
  StrokeNodeSnapshot node,
  SceneSelectionPaintContext context,
  SceneStrokePathCache? strokePathCache,
) {
  if (!scenePainterCanPaintStrokeNode(node)) {
    return;
  }
  final baseThickness = clampNonNegativeFinite(node.thickness);
  withTransform(
    context.canvas,
    scenePainterToViewTransform(
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
          baseColor: scenePainterApplyOpacity(node.color, node.opacity),
        );
        return;
      }

      _drawStrokePathSelection(
        node: node,
        context: context,
        baseThickness: baseThickness,
        path: scenePainterResolveStrokePath(node, strokePathCache),
      );
    },
  );
}

void _drawStrokePathSelection({
  required StrokeNodeSnapshot node,
  required SceneSelectionPaintContext context,
  required double baseThickness,
  required Path path,
}) {
  final style = SelectionHaloStyle(
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
      ..color = scenePainterApplyOpacity(node.color, node.opacity),
  );
}

void _drawPathSelection(
  PathNodeSnapshot node,
  Path? localPath,
  SceneSelectionPaintContext context,
  ScenePathMetricsCache? pathMetricsCache,
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
      final safeStrokeWidth = clampNonNegativeFinite(node.strokeWidth);
      final hasStroke = node.strokeColor != null && safeStrokeWidth > 0;
      final baseStrokeWidth = hasStroke ? safeStrokeWidth : 0.0;
      final contours = pathMetricsCache != null
          ? pathMetricsCache.getOrBuild(node: node, localPath: localPath)
          : buildPathSelectionContours(localPath, node.fillRule);
      final style = SelectionHaloStyle(
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
  SelectionHaloStyle style,
) {
  if (closedContours == null) {
    return;
  }
  _drawPathHalo(canvas, closedContours, style);
}

void _drawOpenPathSelection(
  List<Path> contours,
  PathNodeSnapshot node,
  SceneSelectionPaintContext context,
  SelectionHaloStyle style,
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
        ..color = scenePainterApplyOpacity(
          node.strokeColor ?? context.style.color,
          node.opacity,
        ),
    );
  }
}

void _drawWorldBoundsSelection(
  ScenePainterResolvedNodePaintData node,
  SceneSelectionPaintContext context,
) {
  final worldBounds = node.geometry.worldBounds;
  if (!scenePainterIsFiniteRect(worldBounds)) {
    return;
  }
  final viewRect = worldBounds.shift(-context.cameraOffset);
  _drawRectHalo(
    context.canvas,
    viewRect,
    SelectionHaloStyle(
      color: context.style.color,
      haloWidth: context.style.haloWidth,
    ),
  );
}

Paint _haloPaint(
  SelectionHaloStyle style, {
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
  SceneSelectionPaintContext context, {
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

void _drawRectHalo(Canvas canvas, Rect rect, SelectionHaloStyle style) {
  drawBoundedRectHalo(canvas, rect, style);
}

void _drawPathHalo(Canvas canvas, Path path, SelectionHaloStyle style) {
  drawBoundedPathHalo(canvas, path, style, _haloPaint(style));
}
