import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

class CanvasSceneSurface extends StatelessWidget {
  const CanvasSceneSurface({
    super.key,
    required this.controller,
    required this.imageResolver,
    required this.cameraOffset,
    required this.pendingLineStart,
    required this.pendingLineColor,
    required this.pendingLineThickness,
  });

  final SceneController controller;
  final ui.Image? Function(String imageId) imageResolver;
  final Offset cameraOffset;
  final Offset? pendingLineStart;
  final Color? pendingLineColor;
  final double? pendingLineThickness;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SceneView(
          controller: controller,
          imageResolver: imageResolver,
          selectionColor: const Color(0xFFFFFF00),
          selectionStrokeWidth: 4,
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _PendingLineMarkerPainter(
                cameraOffset: cameraOffset,
                start: pendingLineStart,
                color: pendingLineColor,
                thickness: pendingLineThickness,
              ),
            ),
          ),
        ),
        if (pendingLineStart != null)
          Positioned.fill(child: IgnorePointer(child: const SizedBox())),
      ],
    );
  }
}

class _PendingLineMarkerPainter extends CustomPainter {
  const _PendingLineMarkerPainter({
    required this.cameraOffset,
    required this.start,
    required this.color,
    required this.thickness,
  });

  final Offset cameraOffset;
  final Offset? start;
  final Color? color;
  final double? thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final markerStart = start;
    final markerColor = color;
    final markerThickness = thickness;
    if (markerStart == null || markerColor == null || markerThickness == null) {
      return;
    }

    final viewPosition = _toViewPoint(markerStart, cameraOffset);
    final paint = Paint()
      ..color = markerColor.withAlpha(200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = markerThickness;
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
  bool shouldRepaint(covariant _PendingLineMarkerPainter oldDelegate) {
    return oldDelegate.cameraOffset != cameraOffset ||
        oldDelegate.start != start ||
        oldDelegate.color != color ||
        oldDelegate.thickness != thickness;
  }
}

Offset _toViewPoint(Offset scenePoint, Offset cameraOffset) {
  return Offset(
    scenePoint.dx - cameraOffset.dx,
    scenePoint.dy - cameraOffset.dy,
  );
}
