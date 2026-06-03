import 'package:flutter/rendering.dart';

import '../frame/frame_drawable_policy.dart';
import '../frame/frame_paint_output.dart';
import '../frame/overlay_preview_planner.dart';

const _drawablePolicy = FrameDrawablePolicy();

final class OverlayFramePainter extends CustomPainter {
  const OverlayFramePainter({required this.output});

  final OverlayFramePaintOutput output;

  @override
  void paint(Canvas canvas, Size size) {
    final viewport = output.capturedFrame.snapshot.inputs.effectiveWorldBounds;
    canvas.save();
    canvas.translate(-viewport.left, -viewport.top);
    for (final primitive in output.overlayPreviewPlan.primitives) {
      _paintPrimitive(canvas, primitive);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant OverlayFramePainter oldDelegate) {
    return !identical(oldDelegate.output, output);
  }
}

void _paintPrimitive(Canvas canvas, OverlayPreviewPrimitive primitive) {
  switch (primitive) {
    case final MarqueeOverlayPrimitive primitive:
      _paintMarqueeOverlay(canvas, primitive);
    case final StrokeOverlayPrimitive primitive:
      _paintStrokeOverlay(canvas, primitive);
    case final PendingLineStartOverlayPrimitive primitive:
      _paintPendingLineStartOverlay(canvas, primitive);
    case final LineOverlayPrimitive primitive:
      _paintLineOverlay(canvas, primitive);
    case final EraserOverlayPrimitive primitive:
      _paintEraserOverlay(canvas, primitive);
  }
}

void _paintMarqueeOverlay(Canvas canvas, MarqueeOverlayPrimitive primitive) {
  canvas.drawRect(
    primitive.rect,
    Paint()..color = _withOpacity(primitive.color, primitive.fillOpacity),
  );
  canvas.drawRect(
    primitive.rect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = primitive.strokeWidth
      ..color = primitive.color,
  );
}

void _paintStrokeOverlay(Canvas canvas, StrokeOverlayPrimitive primitive) {
  _drawablePolicy.paintPolyline(
    canvas,
    primitive.points,
    Paint()
      ..strokeWidth = primitive.thickness
      ..color = _withOpacity(primitive.color, primitive.opacity),
  );
}

void _paintPendingLineStartOverlay(
  Canvas canvas,
  PendingLineStartOverlayPrimitive primitive,
) {
  canvas.drawCircle(
    primitive.start,
    primitive.thickness,
    Paint()..color = primitive.color,
  );
}

void _paintLineOverlay(Canvas canvas, LineOverlayPrimitive primitive) {
  _drawablePolicy.paintLine(
    canvas,
    primitive.start,
    primitive.end,
    Paint()
      ..strokeWidth = primitive.thickness
      ..color = primitive.color,
  );
}

void _paintEraserOverlay(Canvas canvas, EraserOverlayPrimitive primitive) {
  _drawablePolicy.paintPolyline(
    canvas,
    primitive.corridor,
    Paint()
      ..strokeWidth = primitive.thickness
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x663366FF),
  );
}

Color _withOpacity(Color color, double opacity) {
  final sourceAlpha = (color.toARGB32() >> 24) & 0xFF;
  final factor = opacity.clamp(0, 1).toDouble();

  return color.withAlpha((sourceAlpha * factor).round());
}
