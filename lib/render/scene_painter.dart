import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../core/geometry.dart';
import '../core/nodes.dart';
import '../core/scene.dart';

/// Resolves an [ImageNode.imageId] to a decoded [Image] instance.
typedef ImageResolver = Image? Function(String imageId);

/// A [CustomPainter] that renders a [Scene] to a Flutter [Canvas].
///
/// The painter expects all node geometry to be in scene coordinates and applies
/// [Scene.camera] offset to render into view coordinates.
class ScenePainter extends CustomPainter {
  static const double _cullPadding = 1.0;

  ScenePainter({
    required this.scene,
    required this.imageResolver,
    this.selectedNodeIds = const <NodeId>{},
    this.selectionRect,
    this.selectionColor = const Color(0xFF1565C0),
    this.selectionStrokeWidth = 1,
    this.gridStrokeWidth = 1,
    super.repaint,
  }) : _repaint = repaint;

  final Scene scene;
  final ImageResolver imageResolver;
  final Set<NodeId> selectedNodeIds;
  final Rect? selectionRect;
  final Color selectionColor;
  final double selectionStrokeWidth;
  final double gridStrokeWidth;
  final Listenable? _repaint;

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size, scene.background.color);
    _drawGrid(canvas, size, scene.background.grid, scene.camera.offset);
    final viewRect = Rect.fromLTWH(
      scene.camera.offset.dx,
      scene.camera.offset.dy,
      size.width,
      size.height,
    ).inflate(_cullPadding);
    _drawLayers(canvas, scene, scene.camera.offset, viewRect);
    _drawSelection(canvas, scene, scene.camera.offset);
  }

  @override
  bool shouldRepaint(covariant ScenePainter oldDelegate) {
    final usesRepaint = _repaint != null || oldDelegate._repaint != null;
    if (!usesRepaint) {
      return true;
    }

    return oldDelegate.scene != scene ||
        oldDelegate.imageResolver != imageResolver ||
        !setEquals(oldDelegate.selectedNodeIds, selectedNodeIds) ||
        oldDelegate.selectionRect != selectionRect ||
        oldDelegate.selectionColor != selectionColor ||
        oldDelegate.selectionStrokeWidth != selectionStrokeWidth ||
        oldDelegate.gridStrokeWidth != gridStrokeWidth;
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

  void _drawLayers(
    Canvas canvas,
    Scene scene,
    Offset cameraOffset,
    Rect viewRect,
  ) {
    for (final layer in scene.layers) {
      for (final node in layer.nodes) {
        if (!node.isVisible) continue;
        if (!viewRect.overlaps(node.aabb)) continue;
        _drawNode(canvas, node, cameraOffset);
      }
    }
  }

  void _drawSelection(Canvas canvas, Scene scene, Offset cameraOffset) {
    final selectionBounds = _selectionBounds(scene);
    if (selectionBounds != null) {
      final viewRect = selectionBounds.shift(-cameraOffset);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selectionStrokeWidth
        ..color = selectionColor;
      canvas.drawRect(viewRect, paint);
    }

    if (selectionRect != null) {
      final normalized = _normalizeRect(selectionRect!);
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

  Rect? _selectionBounds(Scene scene) {
    if (selectedNodeIds.isEmpty) return null;

    Rect? bounds;
    for (final layer in scene.layers) {
      for (final node in layer.nodes) {
        if (!selectedNodeIds.contains(node.id)) continue;
        final aabb = node.aabb;
        if (bounds == null) {
          bounds = aabb;
        } else {
          bounds = bounds.expandToInclude(aabb);
        }
      }
    }
    return bounds;
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

  double _gridStart(double offset, double cell) {
    final remainder = offset % cell;
    return remainder < 0 ? remainder + cell : remainder;
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
