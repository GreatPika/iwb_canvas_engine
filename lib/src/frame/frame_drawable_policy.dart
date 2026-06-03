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
    canvas.drawPath(_polylinePath(points), _strokePaint(paint));
  }

  void paintLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    if (start == end) {
      _paintPoint(canvas, start, paint);

      return;
    }
    canvas.drawLine(start, end, _strokePaint(paint));
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
    canvas.drawPath(path, _strokePaint(paint));

    return true;
  }

  void _paintPoint(Canvas canvas, Offset point, Paint paint) {
    canvas.drawPoints(PointMode.points, [point], _strokePaint(paint));
  }

  Paint _strokePaint(Paint paint) {
    return paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
  }

  Path _polylinePath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    return path;
  }
}
