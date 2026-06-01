import 'dart:ui';

final class FrameDrawablePolicy {
  const FrameDrawablePolicy();

  void paintPolyline(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.isEmpty) {
      return;
    }
    if (points.length == 1) {
      _paintPoint(canvas, points.single, paint);

      return;
    }
    canvas.drawPoints(PointMode.polygon, points, paint);
  }

  void paintLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    if (start == end) {
      _paintPoint(canvas, start, paint);

      return;
    }
    canvas.drawLine(start, end, paint);
  }

  bool paintCachedStroke({
    required Canvas canvas,
    required List<Offset> points,
    required Path? path,
    required Paint paint,
  }) {
    if (points.isEmpty) {
      return true;
    }
    if (points.length == 1) {
      _paintPoint(canvas, points.single, paint);

      return true;
    }
    if (path == null) {
      return false;
    }
    canvas.drawPath(path, paint);

    return true;
  }

  void _paintPoint(Canvas canvas, Offset point, Paint paint) {
    canvas.drawPoints(PointMode.points, [
      point,
    ], paint..strokeCap = StrokeCap.round);
  }
}
