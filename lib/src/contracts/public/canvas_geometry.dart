import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'canvas_value_validators.dart';

/// Public API v1 declaration for [CanvasTransform].
@immutable
// This registry-owned public value object stays cohesive so the transform API
// remains visible as one contract surface instead of being split by metric.
// ignore: metrics
final class CanvasTransform {
  factory CanvasTransform({
    required double a,
    required double b,
    required double c,
    required double d,
    required double tx,
    required double ty,
  }) {
    final transform = CanvasTransform._(a: a, b: b, c: c, d: d, tx: tx, ty: ty);
    _validateCanvasTransform(transform, path: 'transform');

    return transform;
  }

  const CanvasTransform._({
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.tx,
    required this.ty,
  });

  static const identity = CanvasTransform._(
    a: 1,
    b: 0,
    c: 0,
    d: 1,
    tx: 0,
    ty: 0,
  );

  factory CanvasTransform.translation(Offset delta) =>
      CanvasTransform(a: 1, b: 0, c: 0, d: 1, tx: delta.dx, ty: delta.dy);
  factory CanvasTransform.scale(double sx, double sy) =>
      CanvasTransform(a: sx, b: 0, c: 0, d: sy, tx: 0, ty: 0);
  factory CanvasTransform.rotationRadians(double radians) {
    validateFiniteDouble(radians, path: 'transform.rotationRadians');

    return CanvasTransform(
      a: math.cos(radians),
      b: math.sin(radians),
      c: -math.sin(radians),
      d: math.cos(radians),
      tx: 0,
      ty: 0,
    );
  }

  factory CanvasTransform.rotationDegrees(double degrees) {
    validateFiniteDouble(degrees, path: 'transform.rotationDegrees');

    return CanvasTransform.rotationRadians(degrees * math.pi / 180);
  }

  factory CanvasTransform.trs({
    Offset translation = Offset.zero,
    double rotationDegrees = 0,
    double scaleX = 1,
    double scaleY = 1,
  }) {
    final translate = CanvasTransform.translation(translation);
    final rotate = CanvasTransform.rotationDegrees(rotationDegrees);
    final scale = CanvasTransform.scale(scaleX, scaleY);

    return translate.multiply(rotate).multiply(scale);
  }

  final double a;
  final double b;
  final double c;
  final double d;
  final double tx;
  final double ty;

  Offset get translation => Offset(tx, ty);
  bool get isFinite =>
      a.isFinite &&
      b.isFinite &&
      c.isFinite &&
      d.isFinite &&
      tx.isFinite &&
      ty.isFinite;
  bool get isInvertible => a * d - b * c != 0;
  CanvasTransform withTranslation(Offset translation) => CanvasTransform(
    a: a,
    b: b,
    c: c,
    d: d,
    tx: translation.dx,
    ty: translation.dy,
  );
  CanvasTransform multiply(CanvasTransform other) {
    return CanvasTransform(
      a: a * other.a + c * other.b,
      b: b * other.a + d * other.b,
      c: a * other.c + c * other.d,
      d: b * other.c + d * other.d,
      tx: a * other.tx + c * other.ty + tx,
      ty: b * other.tx + d * other.ty + ty,
    );
  }

  Offset applyToPoint(Offset point) {
    validateOffset(point, path: 'point');

    return Offset(
      a * point.dx + c * point.dy + tx,
      b * point.dx + d * point.dy + ty,
    );
  }

  Rect applyToRect(Rect rect) {
    final points = [
      applyToPoint(rect.topLeft),
      applyToPoint(rect.topRight),
      applyToPoint(rect.bottomLeft),
      applyToPoint(rect.bottomRight),
    ];
    final xs = points.map((point) => point.dx);
    final ys = points.map((point) => point.dy);

    return Rect.fromLTRB(
      xs.reduce(math.min),
      ys.reduce(math.min),
      xs.reduce(math.max),
      ys.reduce(math.max),
    );
  }

  CanvasTransform? invert() {
    final determinant = a * d - b * c;
    if (!determinant.isFinite || determinant == 0) {
      return null;
    }

    final inverseA = d / determinant;
    final inverseB = -b / determinant;
    final inverseC = -c / determinant;
    final inverseD = a / determinant;
    final inverseTx = -(inverseA * tx + inverseC * ty);
    final inverseTy = -(inverseB * tx + inverseD * ty);

    if (!inverseA.isFinite ||
        !inverseB.isFinite ||
        !inverseC.isFinite ||
        !inverseD.isFinite ||
        !inverseTx.isFinite ||
        !inverseTy.isFinite) {
      return null;
    }

    return CanvasTransform._(
      a: inverseA,
      b: inverseB,
      c: inverseC,
      d: inverseD,
      tx: inverseTx,
      ty: inverseTy,
    );
  }

  Float64List toCanvasTransform() {
    final matrix = Float64List(16);
    writeToCanvasTransform(matrix);

    return matrix;
  }

  void writeToCanvasTransform(Float64List out) {
    if (out.length != 16) {
      throw ArgumentError.value(out.length, 'out.length', 'must be 16');
    }
    out
      ..[0] = a
      ..[1] = b
      ..[2] = 0
      ..[3] = 0
      ..[4] = c
      ..[5] = d
      ..[6] = 0
      ..[7] = 0
      ..[8] = 0
      ..[9] = 0
      ..[10] = 1
      ..[11] = 0
      ..[12] = tx
      ..[13] = ty
      ..[14] = 0
      ..[15] = 1;
  }

  Map<String, double> toJsonMap() {
    return {'a': a, 'b': b, 'c': c, 'd': d, 'tx': tx, 'ty': ty};
  }

  @override
  bool operator ==(Object other) {
    return other is CanvasTransform &&
        other.a == a &&
        other.b == b &&
        other.c == c &&
        other.d == d &&
        other.tx == tx &&
        other.ty == ty;
  }

  @override
  int get hashCode => Object.hash(a, b, c, d, tx, ty);
}

void _validateCanvasTransform(CanvasTransform value, {required String path}) {
  _validateTransformEntries(value, path: path);
  validateOffset(value.translation, path: '$path.translation');
}

void _validateTransformEntries(CanvasTransform value, {required String path}) {
  final entries = {
    'a': value.a,
    'b': value.b,
    'c': value.c,
    'd': value.d,
    'tx': value.tx,
    'ty': value.ty,
  };
  for (final entry in entries.entries) {
    validateFiniteDouble(entry.value, path: '$path.${entry.key}');
  }
}
