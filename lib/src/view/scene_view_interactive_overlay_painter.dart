import 'package:flutter/widgets.dart';

import '../core/geometry.dart';
import '../core/numeric_clamp.dart';
import '../interactive/scene_controller_interactive.dart';

class SceneViewInteractiveOverlayPainter extends CustomPainter {
  const SceneViewInteractiveOverlayPainter({required this.controller})
    : super(repaint: controller);

  final SceneControllerInteractive controller;

  @override
  void paint(Canvas canvas, Size size) {
    final cameraOffset = sanitizeFiniteOffset(
      controller.snapshot.camera.offset,
    );
    _paintStrokePreview(canvas, cameraOffset);
    _paintLinePreview(canvas, cameraOffset);
  }

  @override
  bool shouldRepaint(covariant SceneViewInteractiveOverlayPainter oldDelegate) {
    return oldDelegate.controller != controller;
  }

  void _paintStrokePreview(Canvas canvas, Offset cameraOffset) {
    if (!controller.hasActiveStrokePreview) {
      return;
    }

    final points = controller.activeStrokePreviewPoints;
    if (points.isEmpty) {
      return;
    }

    final thickness = controller.activeStrokePreviewThickness;
    if (!thickness.isFinite || thickness <= 0) {
      return;
    }

    final color = _applyOpacity(
      controller.activeStrokePreviewColor,
      controller.activeStrokePreviewOpacity,
    );

    if (points.length == 1) {
      _drawSinglePointStrokePreview(
        canvas: canvas,
        viewPoint: toView(points.first, cameraOffset),
        radius: thickness / 2,
        color: color,
      );
      return;
    }

    canvas.drawPath(
      _buildStrokePreviewPath(points, cameraOffset),
      _buildStrokePreviewPaint(thickness, color),
    );
  }

  void _drawSinglePointStrokePreview({
    required Canvas canvas,
    required Offset viewPoint,
    required double radius,
    required Color color,
  }) {
    canvas.drawCircle(
      viewPoint,
      radius,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color,
    );
  }

  Path _buildStrokePreviewPath(List<Offset> points, Offset cameraOffset) {
    final path = Path()
      ..moveTo(
        points.first.dx - cameraOffset.dx,
        points.first.dy - cameraOffset.dy,
      );
    for (var i = 1; i < points.length; i++) {
      final point = points[i];
      path.lineTo(point.dx - cameraOffset.dx, point.dy - cameraOffset.dy);
    }
    return path;
  }

  Paint _buildStrokePreviewPaint(double thickness, Color color) {
    return Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
  }

  void _paintLinePreview(Canvas canvas, Offset cameraOffset) {
    if (!controller.hasActiveLinePreview) {
      return;
    }

    final start = controller.activeLinePreviewStart;
    final end = controller.activeLinePreviewEnd;
    if (start == null || end == null) {
      return;
    }

    final thickness = controller.activeLinePreviewThickness;
    if (!thickness.isFinite || thickness <= 0) {
      return;
    }

    canvas.drawLine(
      toView(start, cameraOffset),
      toView(end, cameraOffset),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round
        ..color = controller.activeLinePreviewColor,
    );
  }

  Color _applyOpacity(Color color, double opacity) {
    final clamped = opacity.clamp(0.0, 1.0).toDouble();
    return color.withValues(alpha: clamped * color.a);
  }
}
