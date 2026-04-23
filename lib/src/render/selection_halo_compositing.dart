import 'dart:ui';

import '../core/numeric_clamp.dart';
import 'scene_painter_shared.dart';

class SelectionHaloStyle {
  const SelectionHaloStyle({
    required this.color,
    required this.haloWidth,
    this.baseStrokeWidth = 0,
  });

  final Color color;
  final double haloWidth;
  final double baseStrokeWidth;
}

void drawBoundedRectHalo(Canvas canvas, Rect rect, SelectionHaloStyle style) {
  final layerBounds = _inflateFiniteBounds(
    rect,
    clampNonNegativeFinite(style.haloWidth),
  );
  if (layerBounds == null) {
    return;
  }

  canvas.saveLayer(layerBounds, Paint());
  canvas.drawRect(
    rect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = clampNonNegativeFinite(style.haloWidth * 2)
      ..color = style.color,
  );
  final clearPaint = Paint()..blendMode = BlendMode.clear;
  clearPaint.style = PaintingStyle.fill;
  canvas.drawRect(rect, clearPaint);
  canvas.restore();
}

void drawBoundedPathHalo(
  Canvas canvas,
  Path path,
  SelectionHaloStyle style,
  Paint haloPaint,
) {
  final layerBounds = _inflateFiniteBounds(
    path.getBounds(),
    clampNonNegativeFinite(style.haloWidth + style.baseStrokeWidth / 2),
  );
  if (layerBounds == null) {
    return;
  }

  canvas.saveLayer(layerBounds, Paint());
  canvas.drawPath(path, haloPaint);
  final clearPaint = Paint()..blendMode = BlendMode.clear;
  clearPaint.style = PaintingStyle.fill;
  canvas.drawPath(path, clearPaint);
  if (style.baseStrokeWidth > 0) {
    clearPaint
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..strokeWidth = style.baseStrokeWidth;
    canvas.drawPath(path, clearPaint);
  }
  canvas.restore();
}

Rect? _inflateFiniteBounds(Rect bounds, double padding) {
  if (!scenePainterIsFiniteRect(bounds)) {
    return null;
  }
  final inflatedBounds = padding > 0 ? bounds.inflate(padding) : bounds;
  return scenePainterIsFiniteRect(inflatedBounds) ? inflatedBounds : null;
}
