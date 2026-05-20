import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'canvas_value_validators.dart';

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
    validateCanvasTransform(transform, path: 'transform');

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

  Offset get translation => Offset(tx, ty);
  bool get isFinite =>
      a.isFinite &&
      b.isFinite &&
      c.isFinite &&
      d.isFinite &&
      tx.isFinite &&
      ty.isFinite;
  bool get isInvertible => a * d - b * c != 0;
  CanvasTransform withTranslation(Offset translation) =>
      throw UnimplementedError();
  CanvasTransform multiply(CanvasTransform other) => throw UnimplementedError();
  Offset applyToPoint(Offset point) => throw UnimplementedError();
  Rect applyToRect(Rect rect) => throw UnimplementedError();
  CanvasTransform? invert() => throw UnimplementedError();
  Float64List toCanvasTransform() => throw UnimplementedError();
  void writeToCanvasTransform(Float64List out) => throw UnimplementedError();
  Map<String, double> toJsonMap() => throw UnimplementedError();

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
