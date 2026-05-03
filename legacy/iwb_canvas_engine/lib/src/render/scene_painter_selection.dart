import 'dart:typed_data';
import 'dart:ui';

import '../contract/snapshot.dart';
import '../core/numeric_clamp.dart';
import 'cache/scene_path_metrics_cache.dart';
import 'canvas_scope.dart';
import 'scene_painter_contract.dart';
import 'scene_painter_shared.dart';
import 'selection_halo_compositing.dart';

class ScenePainterSelectionRenderer {
  ScenePainterSelectionRenderer({
    required ScenePathMetricsCache? pathMetricsCache,
    required Float64List transformBuffer,
  }) : _support = SceneSelectionSupport(
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
    required this.pathMetricsCache,
    required this.transformBuffer,
  });

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
        _drawStrokeSelection(stroke, resolvedNode.strokePath, context);
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
      _drawPathHalo(
        context.canvas,
        Path()
          ..moveTo(node.start.dx, node.start.dy)
          ..lineTo(node.end.dx, node.end.dy),
        style,
        _haloPaint(style, cap: StrokeCap.round),
      );
    },
  );
}

void _drawStrokeSelection(
  StrokeNodeSnapshot node,
  Path? resolvedStrokePath,
  SceneSelectionPaintContext context,
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
        );
        return;
      }
      final path = resolvedStrokePath;
      if (path == null) {
        return;
      }

      _drawStrokePathSelection(
        context: context,
        baseThickness: baseThickness,
        path: path,
      );
    },
  );
}

void _drawStrokePathSelection({
  required SceneSelectionPaintContext context,
  required double baseThickness,
  required Path path,
}) {
  final style = SelectionHaloStyle(
    color: context.style.color,
    haloWidth: context.style.haloWidth,
    baseStrokeWidth: baseThickness,
  );
  _drawPathHalo(
    context.canvas,
    path,
    style,
    _haloPaint(style, cap: StrokeCap.round, join: StrokeJoin.round),
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
      _drawOpenPathSelection(contours.openContours, context, style);
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
  SceneSelectionPaintContext context,
  SelectionHaloStyle style,
) {
  for (final contour in contours) {
    _drawPathHalo(
      context.canvas,
      contour,
      style,
      _haloPaint(style, cap: StrokeCap.round, join: StrokeJoin.round),
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
}) {
  drawBoundedCircleHalo(
    context.canvas,
    center: center,
    radius: radius,
    style: SelectionHaloStyle(
      color: context.style.color,
      haloWidth: context.style.haloWidth,
    ),
  );
}

void _drawRectHalo(Canvas canvas, Rect rect, SelectionHaloStyle style) {
  drawBoundedRectHalo(canvas, rect, style);
}

void _drawPathHalo(
  Canvas canvas,
  Path path,
  SelectionHaloStyle style, [
  Paint? haloPaint,
]) {
  drawBoundedPathHalo(canvas, path, style, haloPaint ?? _haloPaint(style));
}
