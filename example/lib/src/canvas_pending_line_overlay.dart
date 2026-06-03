import 'package:flutter/material.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

final class CanvasPendingLineOverlay extends StatelessWidget {
  const CanvasPendingLineOverlay({
    required this.preview,
    required this.cameraOffset,
    super.key,
  });

  final CanvasPreviewState preview;
  final Offset cameraOffset;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: CanvasPendingLinePainter(
            marker: PendingLineMarker.fromPreview(preview),
            cameraOffset: cameraOffset,
          ),
        ),
      ),
    );
  }
}

final class PendingLineMarker {
  const PendingLineMarker({
    required this.start,
    required this.color,
    required this.thickness,
  });

  factory PendingLineMarker.fromPreview(CanvasPreviewState preview) {
    if (preview case CanvasPendingLineStartPreview(
      :final start,
      :final color,
      :final thickness,
    )) {
      return PendingLineMarker(
        start: start,
        color: color,
        thickness: thickness,
      );
    }

    return PendingLineMarker.none;
  }

  static const none = PendingLineMarker(
    start: null,
    color: null,
    thickness: null,
  );

  final Offset? start;
  final Color? color;
  final double? thickness;
  bool get isVisible => start != null && color != null && thickness != null;
}

final class CanvasPendingLinePainter extends CustomPainter {
  const CanvasPendingLinePainter({
    required this.marker,
    required this.cameraOffset,
  });

  final PendingLineMarker marker;
  final Offset cameraOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final start = marker.start;
    final color = marker.color;
    final thickness = marker.thickness;
    if (start == null || color == null || thickness == null) {
      return;
    }

    final viewPosition = start - cameraOffset;
    final paint = Paint()
      ..color = color.withAlpha(200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;
    canvas.drawCircle(viewPosition, 12, paint);
    canvas.drawLine(
      viewPosition + const Offset(-15, 0),
      viewPosition + const Offset(15, 0),
      paint,
    );
    canvas.drawLine(
      viewPosition + const Offset(0, -15),
      viewPosition + const Offset(0, 15),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CanvasPendingLinePainter oldDelegate) {
    return oldDelegate.marker != marker ||
        oldDelegate.cameraOffset != cameraOffset;
  }
}
