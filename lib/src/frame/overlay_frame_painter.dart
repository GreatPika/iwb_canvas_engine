import 'dart:ui';

import 'package:flutter/rendering.dart';

import 'frame_paint_output.dart';
import 'overlay_preview_planner.dart';

final class OverlayFramePainter extends CustomPainter {
  const OverlayFramePainter({required this.output});

  final OverlayFramePaintOutput output;

  @override
  void paint(Canvas canvas, Size size) {
    final viewport = output.capturedFrame.snapshot.inputs.viewportWorldBounds;
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
    case MarqueeOverlayPrimitive(:final rect):
      canvas.drawRect(rect, Paint()..style = PaintingStyle.stroke);
    case StrokeOverlayPrimitive(:final points, :final thickness, :final color):
      canvas.drawPoints(
        PointMode.polygon,
        points,
        Paint()
          ..strokeWidth = thickness
          ..color = color,
      );
    case PendingLineStartOverlayPrimitive(:final start, :final thickness):
      canvas.drawCircle(start, thickness, Paint());
    case LineOverlayPrimitive(
      :final start,
      :final end,
      :final thickness,
      :final color,
    ):
      canvas.drawLine(
        start,
        end,
        Paint()
          ..strokeWidth = thickness
          ..color = color,
      );
    case EraserOverlayPrimitive(:final corridor, :final thickness):
      canvas.drawPoints(
        PointMode.polygon,
        corridor,
        Paint()
          ..strokeWidth = thickness
          ..blendMode = BlendMode.clear,
      );
  }
}
