import 'dart:typed_data';
import 'dart:ui';
import 'dart:math' as math;

/// A 2D affine transform represented as a 2×3 matrix.
///
/// The matrix maps points in the following form:
/// `x' = a*x + c*y + tx`
/// `y' = b*x + d*y + ty`
///
/// This matches Flutter's `Canvas.transform` convention when expanded into a
/// 4×4 column-major matrix via [toCanvasTransform].
class Transform2D {
  const Transform2D({
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.tx,
    required this.ty,
  });

  static const identity = Transform2D(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0);

  factory Transform2D.translation(Offset delta) {
    return Transform2D(a: 1, b: 0, c: 0, d: 1, tx: delta.dx, ty: delta.dy);
  }

  factory Transform2D.scale(double sx, double sy) {
    return Transform2D(a: sx, b: 0, c: 0, d: sy, tx: 0, ty: 0);
  }

  factory Transform2D.rotationDeg(double degrees) {
    final radians = degrees * math.pi / 180.0;
    final cosA = math.cos(radians);
    final sinA = math.sin(radians);
    return Transform2D(a: cosA, b: sinA, c: -sinA, d: cosA, tx: 0, ty: 0);
  }

  final double a;
  final double b;
  final double c;
  final double d;
  final double tx;
  final double ty;

  /// Returns a composition of this transform with [other] (`this * other`).
  ///
  /// When applied to a point, [other] is applied first and this transform
  /// second: `(this * other).apply(p) == this.apply(other.apply(p))`.
  Transform2D multiply(Transform2D other) {
    return Transform2D(
      a: a * other.a + c * other.b,
      b: b * other.a + d * other.b,
      c: a * other.c + c * other.d,
      d: b * other.c + d * other.d,
      tx: a * other.tx + c * other.ty + tx,
      ty: b * other.tx + d * other.ty + ty,
    );
  }

  Offset applyToPoint(Offset point) {
    final x = a * point.dx + c * point.dy + tx;
    final y = b * point.dx + d * point.dy + ty;
    return Offset(x, y);
  }

  /// Returns the inverse transform, or `null` if the matrix is singular.
  Transform2D? invert() {
    final det = a * d - b * c;
    if (det == 0) return null;
    final invDet = 1.0 / det;
    final invA = d * invDet;
    final invB = -b * invDet;
    final invC = -c * invDet;
    final invD = a * invDet;
    final invTx = -(invA * tx + invC * ty);
    final invTy = -(invB * tx + invD * ty);
    return Transform2D(
      a: invA,
      b: invB,
      c: invC,
      d: invD,
      tx: invTx,
      ty: invTy,
    );
  }

  /// Expands this 2×3 matrix into a 4×4 column-major matrix for Flutter.
  ///
  /// Layout (column-major):
  /// `[a,b,0,0,  c,d,0,0,  0,0,1,0,  tx,ty,0,1]`
  Float64List toCanvasTransform() {
    return Float64List.fromList(<double>[
      a,
      b,
      0,
      0,
      c,
      d,
      0,
      0,
      0,
      0,
      1,
      0,
      tx,
      ty,
      0,
      1,
    ]);
  }
}
