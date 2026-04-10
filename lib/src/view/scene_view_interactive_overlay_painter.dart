import 'package:flutter/widgets.dart';

import '../contract/scene_view_render_state.dart';
import '../core/geometry.dart';
import '../core/numeric_clamp.dart';

class SceneViewInteractiveOverlayPainter extends CustomPainter {
  SceneViewInteractiveOverlayPainter({
    required this.renderState,
    required this.selectionColor,
    required this.selectionStrokeWidth,
  }) : super(repaint: renderState.overlayRepaintListenable);

  final SceneViewRenderState renderState;
  final Color selectionColor;
  final double selectionStrokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final cameraOffset = sanitizeFiniteOffset(renderState.cameraOffset);
    _paintMarqueeSelection(canvas, cameraOffset);
    _paintStrokePreview(canvas, cameraOffset);
    _paintLinePreview(canvas, cameraOffset);
  }

  @override
  bool shouldRepaint(covariant SceneViewInteractiveOverlayPainter oldDelegate) {
    return oldDelegate.renderState != renderState ||
        oldDelegate.selectionColor != selectionColor ||
        oldDelegate.selectionStrokeWidth != selectionStrokeWidth;
  }

  void _paintMarqueeSelection(Canvas canvas, Offset cameraOffset) {
    final selectionRect = renderState.selectionRect;
    if (selectionRect == null ||
        !selectionRect.left.isFinite ||
        !selectionRect.top.isFinite ||
        !selectionRect.right.isFinite ||
        !selectionRect.bottom.isFinite) {
      return;
    }

    final normalized = Rect.fromLTRB(
      selectionRect.left < selectionRect.right
          ? selectionRect.left
          : selectionRect.right,
      selectionRect.top < selectionRect.bottom
          ? selectionRect.top
          : selectionRect.bottom,
      selectionRect.left < selectionRect.right
          ? selectionRect.right
          : selectionRect.left,
      selectionRect.top < selectionRect.bottom
          ? selectionRect.bottom
          : selectionRect.top,
    );
    final viewRect = normalized.shift(-cameraOffset);
    canvas.drawRect(
      viewRect,
      Paint()
        ..style = PaintingStyle.fill
        ..color = _applyOpacity(selectionColor, 0.15),
    );
    canvas.drawRect(
      viewRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = clampNonNegativeFinite(selectionStrokeWidth)
        ..color = selectionColor,
    );
  }

  void _paintStrokePreview(Canvas canvas, Offset cameraOffset) {
    if (!renderState.hasActiveStrokePreview) {
      return;
    }

    final points = renderState.activeStrokePreviewPoints;
    if (points.isEmpty) {
      return;
    }

    final thickness = renderState.activeStrokePreviewThickness;
    if (!thickness.isFinite || thickness <= 0) {
      return;
    }

    final color = _applyOpacity(
      renderState.activeStrokePreviewColor,
      renderState.activeStrokePreviewOpacity,
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
    if (!renderState.hasActiveLinePreview) {
      return;
    }

    final start = renderState.activeLinePreviewStart;
    final end = renderState.activeLinePreviewEnd;
    if (start == null || end == null) {
      return;
    }

    final thickness = renderState.activeLinePreviewThickness;
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
        ..color = renderState.activeLinePreviewColor,
    );
  }

  Color _applyOpacity(Color color, double opacity) {
    final clamped = opacity.clamp(0.0, 1.0).toDouble();
    return color.withValues(alpha: clamped * color.a);
  }
}
