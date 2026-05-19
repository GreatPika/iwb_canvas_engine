import 'dart:typed_data';
import 'dart:ui';

enum CanvasElementKind { image, path, text, stroke, line, rect }

enum CanvasPathFillRule { nonZero, evenOdd }

final class CanvasTransform {
  const CanvasTransform({
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.tx,
    required this.ty,
  });

  static const identity = CanvasTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0);

  factory CanvasTransform.translation(Offset delta) =>
      throw UnimplementedError();
  factory CanvasTransform.scale(double sx, double sy) =>
      throw UnimplementedError();
  factory CanvasTransform.rotationRadians(double radians) =>
      throw UnimplementedError();
  factory CanvasTransform.rotationDegrees(double degrees) =>
      throw UnimplementedError();
  factory CanvasTransform.trs({
    Offset translation = Offset.zero,
    double rotationDegrees = 0,
    double scaleX = 1,
    double scaleY = 1,
  }) => throw UnimplementedError();

  final double a;
  final double b;
  final double c;
  final double d;
  final double tx;
  final double ty;

  Offset get translation => throw UnimplementedError();
  bool get isFinite => throw UnimplementedError();
  bool get isInvertible => throw UnimplementedError();
  CanvasTransform withTranslation(Offset translation) =>
      throw UnimplementedError();
  CanvasTransform multiply(CanvasTransform other) => throw UnimplementedError();
  Offset applyToPoint(Offset point) => throw UnimplementedError();
  Rect applyToRect(Rect rect) => throw UnimplementedError();
  CanvasTransform? invert() => throw UnimplementedError();
  Float64List toCanvasTransform() => throw UnimplementedError();
  void writeToCanvasTransform(Float64List out) => throw UnimplementedError();
  Map<String, double> toJsonMap() => throw UnimplementedError();
}
