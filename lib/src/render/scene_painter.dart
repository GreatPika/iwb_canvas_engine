import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../core/geometry.dart';
import '../core/nodes.dart';
import '../core/scene.dart';
import '../input/scene_controller.dart';

/// Resolves an [ImageNode.imageId] to a decoded [Image] instance.
typedef ImageResolver = Image? Function(String imageId);

/// A [CustomPainter] that renders a [Scene] to a Flutter [Canvas].
///
/// The painter expects all node geometry to be in scene coordinates and applies
/// [Scene.camera] offset to render into view coordinates.
class ScenePainter extends CustomPainter {
  static const double _cullPadding = 1.0;

  ScenePainter({
    required this.controller,
    required this.imageResolver,
    this.staticLayerCache,
    this.selectionColor = const Color(0xFF1565C0),
    this.selectionStrokeWidth = 1,
    this.gridStrokeWidth = 1,
  }) : super(repaint: controller);

  final SceneController controller;
  final ImageResolver imageResolver;
  final SceneStaticLayerCache? staticLayerCache;
  final Color selectionColor;
  final double selectionStrokeWidth;
  final double gridStrokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scene = controller.scene;
    final selectedNodeIds = controller.selectedNodeIds;
    final selectionRect = controller.selectionRect;

    if (staticLayerCache != null) {
      staticLayerCache!.draw(
        canvas,
        size,
        background: scene.background,
        cameraOffset: scene.camera.offset,
        gridStrokeWidth: gridStrokeWidth,
      );
    } else {
      _drawBackground(canvas, size, scene.background.color);
      _drawGrid(
        canvas,
        size,
        scene.background.grid,
        scene.camera.offset,
        gridStrokeWidth,
      );
    }
    final viewRect = Rect.fromLTWH(
      scene.camera.offset.dx,
      scene.camera.offset.dy,
      size.width,
      size.height,
    ).inflate(_cullPadding);
    final selectedNodes = _drawLayers(
      canvas,
      scene,
      scene.camera.offset,
      viewRect,
      selectedNodeIds,
    );
    _drawSelection(canvas, selectedNodes, scene.camera.offset, selectionRect);
  }

  @override
  bool shouldRepaint(covariant ScenePainter oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.imageResolver != imageResolver ||
        oldDelegate.staticLayerCache != staticLayerCache ||
        oldDelegate.selectionColor != selectionColor ||
        oldDelegate.selectionStrokeWidth != selectionStrokeWidth ||
        oldDelegate.gridStrokeWidth != gridStrokeWidth;
  }

  List<SceneNode> _drawLayers(
    Canvas canvas,
    Scene scene,
    Offset cameraOffset,
    Rect viewRect,
    Set<NodeId> selectedNodeIds,
  ) {
    final selectedNodes = <SceneNode>[];
    for (final layer in scene.layers) {
      for (final node in layer.nodes) {
        if (!node.isVisible) continue;
        if (!viewRect.overlaps(node.aabb)) continue;
        _drawNode(canvas, node, cameraOffset);
        if (selectedNodeIds.contains(node.id)) {
          selectedNodes.add(node);
        }
      }
    }
    return selectedNodes;
  }

  void _drawSelection(
    Canvas canvas,
    List<SceneNode> selectedNodes,
    Offset cameraOffset,
    Rect? selectionRect,
  ) {
    if (selectedNodes.isNotEmpty && selectionStrokeWidth > 0) {
      for (final node in selectedNodes) {
        _drawSelectionForNode(
          canvas,
          node,
          cameraOffset,
          selectionColor,
          selectionStrokeWidth,
        );
      }
    }

    if (selectionRect != null) {
      final normalized = _normalizeRect(selectionRect);
      final viewRect = normalized.shift(-cameraOffset);
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = _applyOpacity(selectionColor, 0.15);
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selectionStrokeWidth
        ..color = selectionColor;
      canvas.drawRect(viewRect, fillPaint);
      canvas.drawRect(viewRect, strokePaint);
    }
  }

  void _drawSelectionForNode(
    Canvas canvas,
    SceneNode node,
    Offset cameraOffset,
    Color color,
    double haloWidth,
  ) {
    if (node is ImageNode) {
      _drawBoxSelection(
        canvas,
        cameraOffset,
        node.position,
        node.size,
        node.rotationDeg,
        node.scaleX,
        node.scaleY,
        color,
        haloWidth,
        baseStrokeWidth: 0,
        clearFill: true,
      );
    } else if (node is TextNode) {
      _drawBoxSelection(
        canvas,
        cameraOffset,
        node.position,
        node.size,
        node.rotationDeg,
        node.scaleX,
        node.scaleY,
        color,
        haloWidth,
        baseStrokeWidth: 0,
        clearFill: true,
      );
    } else if (node is RectNode) {
      final hasStroke = node.strokeColor != null && node.strokeWidth > 0;
      _drawBoxSelection(
        canvas,
        cameraOffset,
        node.position,
        node.size,
        node.rotationDeg,
        node.scaleX,
        node.scaleY,
        color,
        haloWidth,
        baseStrokeWidth: hasStroke ? node.strokeWidth : 0,
        clearFill: true,
      );
    } else if (node is LineNode) {
      final start = toView(node.start, cameraOffset);
      final end = toView(node.end, cameraOffset);
      canvas.drawLine(
        start,
        end,
        _haloPaint(node.thickness + haloWidth * 2, color, cap: StrokeCap.round),
      );
      canvas.drawLine(
        start,
        end,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = node.thickness
          ..strokeCap = StrokeCap.round
          ..color = _applyOpacity(node.color, node.opacity),
      );
    } else if (node is StrokeNode) {
      if (node.points.isEmpty) return;
      if (node.points.length == 1) {
        final point = toView(node.points.first, cameraOffset);
        _drawDotSelection(
          canvas,
          point,
          node.thickness / 2,
          color,
          _applyOpacity(node.color, node.opacity),
          haloWidth,
        );
        return;
      }
      final path = Path();
      final first = toView(node.points.first, cameraOffset);
      path.moveTo(first.dx, first.dy);
      for (var i = 1; i < node.points.length; i++) {
        final p = toView(node.points[i], cameraOffset);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        _haloPaint(
          node.thickness + haloWidth * 2,
          color,
          cap: StrokeCap.round,
          join: StrokeJoin.round,
        ),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = node.thickness
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = _applyOpacity(node.color, node.opacity),
      );
    } else if (node is PathNode) {
      final localPath = node.buildLocalPath();
      if (localPath == null) return;
      final viewPosition = toView(node.position, cameraOffset);
      canvas.save();
      canvas.translate(viewPosition.dx, viewPosition.dy);
      _applyTransform(canvas, node.rotationDeg, node.scaleX, node.scaleY);
      final hasStroke = node.strokeColor != null && node.strokeWidth > 0;
      final baseStrokeWidth = hasStroke ? node.strokeWidth : 0.0;
      final metrics = localPath.computeMetrics().toList();
      if (metrics.isEmpty) {
        canvas.restore();
        return;
      }

      Path? closedContours;
      final openContours = <Path>[];
      for (final metric in metrics) {
        final contour = metric.extractPath(
          0,
          metric.length,
          startWithMoveTo: true,
        );
        contour.fillType = PathFillType.nonZero;
        if (metric.isClosed) {
          contour.close();
          closedContours ??= Path()..fillType = PathFillType.nonZero;
          closedContours.addPath(contour, Offset.zero);
        } else {
          openContours.add(contour);
        }
      }

      if (closedContours != null) {
        _drawPathHalo(
          canvas,
          closedContours,
          color,
          haloWidth,
          baseStrokeWidth: baseStrokeWidth,
          clearFill: true,
        );
      }

      for (final contour in openContours) {
        canvas.drawPath(
          contour,
          _haloPaint(
            baseStrokeWidth + haloWidth * 2,
            color,
            cap: StrokeCap.round,
            join: StrokeJoin.round,
          ),
        );
        if (baseStrokeWidth > 0) {
          canvas.drawPath(
            contour,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = baseStrokeWidth
              ..strokeJoin = StrokeJoin.round
              ..strokeCap = StrokeCap.round
              ..color = _applyOpacity(node.strokeColor ?? color, node.opacity),
          );
        }
      }
      canvas.restore();
    }
  }

  void _drawBoxSelection(
    Canvas canvas,
    Offset cameraOffset,
    Offset position,
    Size size,
    double rotationDeg,
    double scaleX,
    double scaleY,
    Color color,
    double haloWidth, {
    required double baseStrokeWidth,
    required bool clearFill,
  }) {
    final viewPosition = toView(position, cameraOffset);
    canvas.save();
    canvas.translate(viewPosition.dx, viewPosition.dy);
    _applyTransform(canvas, rotationDeg, scaleX, scaleY);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width,
      height: size.height,
    );
    _drawRectHalo(
      canvas,
      rect,
      color,
      haloWidth,
      baseStrokeWidth: baseStrokeWidth,
      clearFill: clearFill,
    );
    canvas.restore();
  }

  Paint _haloPaint(
    double strokeWidth,
    Color color, {
    StrokeCap cap = StrokeCap.round,
    StrokeJoin join = StrokeJoin.round,
  }) {
    return Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = cap
      ..strokeJoin = join
      ..color = color;
  }

  void _drawDotSelection(
    Canvas canvas,
    Offset center,
    double radius,
    Color haloColor,
    Color baseColor,
    double haloWidth,
  ) {
    final haloPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = haloColor;
    canvas.drawCircle(center, radius + haloWidth, haloPaint);
    final basePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = baseColor;
    canvas.drawCircle(center, radius, basePaint);
  }

  void _drawRectHalo(
    Canvas canvas,
    Rect rect,
    Color color,
    double haloWidth, {
    required double baseStrokeWidth,
    required bool clearFill,
  }) {
    canvas.saveLayer(null, Paint());
    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = baseStrokeWidth + haloWidth * 2
      ..color = color;
    canvas.drawRect(rect, haloPaint);
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    if (clearFill) {
      clearPaint.style = PaintingStyle.fill;
      canvas.drawRect(rect, clearPaint);
    }
    if (baseStrokeWidth > 0) {
      clearPaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = baseStrokeWidth;
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
    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = baseStrokeWidth + haloWidth * 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawPath(path, haloPaint);
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    if (clearFill) {
      clearPaint.style = PaintingStyle.fill;
      canvas.drawPath(path, clearPaint);
    }
    if (baseStrokeWidth > 0) {
      clearPaint
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..strokeWidth = baseStrokeWidth;
      canvas.drawPath(path, clearPaint);
    }
    canvas.restore();
  }

  void _drawNode(Canvas canvas, SceneNode node, Offset cameraOffset) {
    if (node is ImageNode) {
      _drawImageNode(canvas, node, cameraOffset);
    } else if (node is TextNode) {
      _drawTextNode(canvas, node, cameraOffset);
    } else if (node is StrokeNode) {
      _drawStrokeNode(canvas, node, cameraOffset);
    } else if (node is LineNode) {
      _drawLineNode(canvas, node, cameraOffset);
    } else if (node is RectNode) {
      _drawRectNode(canvas, node, cameraOffset);
    } else if (node is PathNode) {
      _drawPathNode(canvas, node, cameraOffset);
    }
  }

  void _drawImageNode(Canvas canvas, ImageNode node, Offset cameraOffset) {
    final viewPosition = toView(node.position, cameraOffset);
    canvas.save();
    canvas.translate(viewPosition.dx, viewPosition.dy);
    _applyTransform(canvas, node.rotationDeg, node.scaleX, node.scaleY);

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: node.size.width,
      height: node.size.height,
    );

    final image = imageResolver(node.imageId);
    if (image != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final paint = Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(255, 255, 255, _clamp01(node.opacity));
      canvas.drawImageRect(image, src, rect, paint);
    } else {
      _drawImagePlaceholder(canvas, rect, node.opacity);
    }

    canvas.restore();
  }

  void _drawImagePlaceholder(Canvas canvas, Rect rect, double opacity) {
    final color = _applyOpacity(const Color(0xFFB0BEC5), opacity);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    canvas.drawRect(rect, paint);
    canvas.drawLine(rect.topLeft, rect.bottomRight, paint);
    canvas.drawLine(rect.topRight, rect.bottomLeft, paint);
  }

  void _drawTextNode(Canvas canvas, TextNode node, Offset cameraOffset) {
    final viewPosition = toView(node.position, cameraOffset);
    canvas.save();
    canvas.translate(viewPosition.dx, viewPosition.dy);
    _applyTransform(canvas, node.rotationDeg, node.scaleX, node.scaleY);

    final textStyle = TextStyle(
      fontSize: node.fontSize,
      color: _applyOpacity(node.color, node.opacity),
      fontWeight: node.isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: node.isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: node.isUnderline ? TextDecoration.underline : null,
      fontFamily: node.fontFamily,
      height: node.lineHeight == null ? null : node.lineHeight! / node.fontSize,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: node.text, style: textStyle),
      textAlign: node.align,
      textDirection: TextDirection.ltr,
      maxLines: null,
    );

    final maxWidth = node.maxWidth ?? node.size.width;
    textPainter.layout(maxWidth: maxWidth);

    final box = Rect.fromCenter(
      center: Offset.zero,
      width: node.size.width,
      height: node.size.height,
    );

    final dx = _textAlignOffset(node.align, box.width, textPainter.width);
    final dy = (box.height - textPainter.height) / 2;
    final offset = Offset(box.left + dx, box.top + dy);
    textPainter.paint(canvas, offset);

    canvas.restore();
  }

  double _textAlignOffset(TextAlign align, double boxWidth, double textWidth) {
    switch (align) {
      case TextAlign.right:
      case TextAlign.end:
        return boxWidth - textWidth;
      case TextAlign.center:
        return (boxWidth - textWidth) / 2;
      case TextAlign.left:
      case TextAlign.start:
      case TextAlign.justify:
        return 0;
    }
  }

  void _drawStrokeNode(Canvas canvas, StrokeNode node, Offset cameraOffset) {
    if (node.points.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = node.thickness
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = _applyOpacity(node.color, node.opacity);

    if (node.points.length == 1) {
      final point = toView(node.points.first, cameraOffset);
      canvas.drawCircle(
        point,
        node.thickness / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    final path = Path();
    final first = toView(node.points.first, cameraOffset);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < node.points.length; i++) {
      final p = toView(node.points[i], cameraOffset);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  void _drawLineNode(Canvas canvas, LineNode node, Offset cameraOffset) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = node.thickness
      ..strokeCap = StrokeCap.round
      ..color = _applyOpacity(node.color, node.opacity);

    final start = toView(node.start, cameraOffset);
    final end = toView(node.end, cameraOffset);
    canvas.drawLine(start, end, paint);
  }

  void _drawRectNode(Canvas canvas, RectNode node, Offset cameraOffset) {
    final viewPosition = toView(node.position, cameraOffset);
    canvas.save();
    canvas.translate(viewPosition.dx, viewPosition.dy);
    _applyTransform(canvas, node.rotationDeg, node.scaleX, node.scaleY);

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: node.size.width,
      height: node.size.height,
    );

    if (node.fillColor != null) {
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = _applyOpacity(node.fillColor!, node.opacity);
      canvas.drawRect(rect, paint);
    }
    if (node.strokeColor != null && node.strokeWidth > 0) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = node.strokeWidth
        ..color = _applyOpacity(node.strokeColor!, node.opacity);
      canvas.drawRect(rect, paint);
    }

    canvas.restore();
  }

  void _drawPathNode(Canvas canvas, PathNode node, Offset cameraOffset) {
    if (node.svgPathData.trim().isEmpty) return;

    final centered = node.buildLocalPath();
    if (centered == null) return;

    final viewPosition = toView(node.position, cameraOffset);
    canvas.save();
    canvas.translate(viewPosition.dx, viewPosition.dy);
    _applyTransform(canvas, node.rotationDeg, node.scaleX, node.scaleY);

    if (node.fillColor != null) {
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = _applyOpacity(node.fillColor!, node.opacity);
      canvas.drawPath(centered, paint);
    }

    if (node.strokeColor != null && node.strokeWidth > 0) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = node.strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = _applyOpacity(node.strokeColor!, node.opacity);
      canvas.drawPath(centered, paint);
    }

    canvas.restore();
  }

  void _applyTransform(
    Canvas canvas,
    double rotationDeg,
    double scaleX,
    double scaleY,
  ) {
    if (rotationDeg != 0) {
      canvas.rotate(rotationDeg * math.pi / 180);
    }
    if (scaleX != 1 || scaleY != 1) {
      canvas.scale(scaleX, scaleY);
    }
  }

  Rect _normalizeRect(Rect rect) {
    return Rect.fromLTRB(
      math.min(rect.left, rect.right),
      math.min(rect.top, rect.bottom),
      math.max(rect.left, rect.right),
      math.max(rect.top, rect.bottom),
    );
  }

  Color _applyOpacity(Color color, double opacity) {
    final combined = (color.a * _clamp01(opacity)).clamp(0.0, 1.0);
    return color.withAlpha((combined * 255.0).round().clamp(0, 255));
  }

  double _clamp01(double value) {
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }
}

/// Cache for the static scene layer (background + grid).
///
/// Why: avoid re-drawing the grid every frame when inputs are unchanged.
/// Invariant: the cache key must match size, background, grid, camera offset,
/// and grid stroke width.
/// Validate: `test/render_scene_static_layer_cache_test.dart`.
class SceneStaticLayerCache {
  _StaticLayerKey? _key;
  Picture? _picture;

  @visibleForTesting
  int debugBuildCount = 0;
  @visibleForTesting
  int? get debugKeyHashCode => _key?.hashCode;

  void draw(
    Canvas canvas,
    Size size, {
    required Background background,
    required Offset cameraOffset,
    required double gridStrokeWidth,
  }) {
    final key = _StaticLayerKey(
      size: size,
      backgroundColor: background.color,
      gridEnabled: background.grid.isEnabled,
      gridCellSize: background.grid.cellSize,
      gridColor: background.grid.color,
      gridStrokeWidth: gridStrokeWidth,
      cameraOffset: cameraOffset,
    );

    if (_picture == null || _key != key) {
      _key = key;
      _picture = _recordPicture(
        size,
        background,
        cameraOffset,
        gridStrokeWidth,
      );
      debugBuildCount += 1;
    }

    canvas.drawPicture(_picture!);
  }

  Picture _recordPicture(
    Size size,
    Background background,
    Offset cameraOffset,
    double gridStrokeWidth,
  ) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    _drawBackground(canvas, size, background.color);
    _drawGrid(canvas, size, background.grid, cameraOffset, gridStrokeWidth);
    return recorder.endRecording();
  }
}

class _StaticLayerKey {
  const _StaticLayerKey({
    required this.size,
    required this.backgroundColor,
    required this.gridEnabled,
    required this.gridCellSize,
    required this.gridColor,
    required this.gridStrokeWidth,
    required this.cameraOffset,
  });

  final Size size;
  final Color backgroundColor;
  final bool gridEnabled;
  final double gridCellSize;
  final Color gridColor;
  final double gridStrokeWidth;
  final Offset cameraOffset;

  @override
  bool operator ==(Object other) {
    return other is _StaticLayerKey &&
        other.size == size &&
        other.backgroundColor == backgroundColor &&
        other.gridEnabled == gridEnabled &&
        other.gridCellSize == gridCellSize &&
        other.gridColor == gridColor &&
        other.gridStrokeWidth == gridStrokeWidth &&
        other.cameraOffset == cameraOffset;
  }

  @override
  int get hashCode => Object.hash(
    size,
    backgroundColor,
    gridEnabled,
    gridCellSize,
    gridColor,
    gridStrokeWidth,
    cameraOffset,
  );
}

void _drawBackground(Canvas canvas, Size size, Color color) {
  final paint = Paint()..color = color;
  canvas.drawRect(Offset.zero & size, paint);
}

void _drawGrid(
  Canvas canvas,
  Size size,
  GridSettings grid,
  Offset cameraOffset,
  double gridStrokeWidth,
) {
  if (!grid.isEnabled || grid.cellSize <= 0) return;

  final paint = Paint()
    ..color = grid.color
    ..strokeWidth = gridStrokeWidth;

  final cell = grid.cellSize;
  final startX = _gridStart(-cameraOffset.dx, cell);
  final startY = _gridStart(-cameraOffset.dy, cell);

  for (double x = startX; x <= size.width; x += cell) {
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
  }
  for (double y = startY; y <= size.height; y += cell) {
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
}

double _gridStart(double offset, double cell) {
  final remainder = offset % cell;
  return remainder < 0 ? remainder + cell : remainder;
}
