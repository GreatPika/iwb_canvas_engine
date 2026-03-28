import 'package:flutter/widgets.dart';

import '../core/geometry.dart';
import '../core/numeric_clamp.dart';
import '../interactive/scene_controller.dart';
import '../interactive/scene_controller_interaction.dart';

class SceneViewInteractiveOverlayPainter extends CustomPainter {
  const SceneViewInteractiveOverlayPainter({
    required this.controller,
    required this.interaction,
  }) : super(repaint: interaction);

  final SceneController controller;
  final SceneControllerInteraction interaction;

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
    return oldDelegate.controller != controller ||
        oldDelegate.interaction != interaction;
  }

  void _paintStrokePreview(Canvas canvas, Offset cameraOffset) {
    if (!interaction.hasActiveStrokePreview) {
      return;
    }

    final points = interaction.activeStrokePreviewPoints;
    if (points.isEmpty) {
      return;
    }

    final thickness = interaction.activeStrokePreviewThickness;
    if (!thickness.isFinite || thickness <= 0) {
      return;
    }

    final color = _applyOpacity(
      interaction.activeStrokePreviewColor,
      interaction.activeStrokePreviewOpacity,
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
    if (!interaction.hasActiveLinePreview) {
      return;
    }

    final start = interaction.activeLinePreviewStart;
    final end = interaction.activeLinePreviewEnd;
    if (start == null || end == null) {
      return;
    }

    final thickness = interaction.activeLinePreviewThickness;
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
        ..color = interaction.activeLinePreviewColor,
    );
  }

  Color _applyOpacity(Color color, double opacity) {
    final clamped = opacity.clamp(0.0, 1.0).toDouble();
    return color.withValues(alpha: clamped * color.a);
  }
}
