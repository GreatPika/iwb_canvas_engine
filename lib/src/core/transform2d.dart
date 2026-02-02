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

  /// Decodes a transform from a JSON-friendly map.
  ///
  /// This format is shared between JSON serialization and action event payloads:
  /// `{a,b,c,d,tx,ty}`.
  ///
  /// Throws [ArgumentError] when required fields are missing or not numeric.
  factory Transform2D.fromJsonMap(Map<String, Object?> map) {
    double requireNum(String key) {
      final value = map[key];
      if (value is num) return value.toDouble();
      throw ArgumentError.value(value, key, 'Must be a number.');
    }

    return Transform2D(
      a: requireNum('a'),
      b: requireNum('b'),
      c: requireNum('c'),
      d: requireNum('d'),
      tx: requireNum('tx'),
      ty: requireNum('ty'),
    );
  }

  /// Builds a translate * rotate * scale transform.
  ///
  /// The resulting matrix applies scaling first, then rotation, then
  /// translation when transforming a point.
  factory Transform2D.trs({
    Offset translation = Offset.zero,
    double rotationDeg = 0,
    double scaleX = 1,
    double scaleY = 1,
  }) {
    return Transform2D.translation(translation)
        .multiply(Transform2D.rotationDeg(rotationDeg))
        .multiply(Transform2D.scale(scaleX, scaleY));
  }

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

  Offset get translation => Offset(tx, ty);

  /// Encodes this transform into a JSON-friendly map.
  ///
  /// This is shared between JSON serialization and action events payloads.
  Map<String, double> toJsonMap() {
    return <String, double>{'a': a, 'b': b, 'c': c, 'd': d, 'tx': tx, 'ty': ty};
  }

  Transform2D withTranslation(Offset translation) {
    return Transform2D(
      a: a,
      b: b,
      c: c,
      d: d,
      tx: translation.dx,
      ty: translation.dy,
    );
  }

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

  /// Applies the transform to [rect] and returns its axis-aligned world bounds.
  Rect applyToRect(Rect rect) {
    if (rect.isEmpty) return Rect.zero;
    final p1 = applyToPoint(rect.topLeft);
    final p2 = applyToPoint(rect.topRight);
    final p3 = applyToPoint(rect.bottomRight);
    final p4 = applyToPoint(rect.bottomLeft);
    var minX = p1.dx;
    var maxX = p1.dx;
    var minY = p1.dy;
    var maxY = p1.dy;
    void include(Offset p) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    include(p2);
    include(p3);
    include(p4);
    return Rect.fromLTRB(minX, minY, maxX, maxY);
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

  /// Writes this transform into [out] as a 4×4 column-major matrix for Flutter.
  ///
  /// [out] must have length at least 16.
  void writeToCanvasTransform(Float64List out) {
    if (out.length < 16) {
      throw ArgumentError.value(out.length, 'out.length', 'Must be >= 16.');
    }
    out[0] = a;
    out[1] = b;
    out[2] = 0;
    out[3] = 0;
    out[4] = c;
    out[5] = d;
    out[6] = 0;
    out[7] = 0;
    out[8] = 0;
    out[9] = 0;
    out[10] = 1;
    out[11] = 0;
    out[12] = tx;
    out[13] = ty;
    out[14] = 0;
    out[15] = 1;
  }
}
