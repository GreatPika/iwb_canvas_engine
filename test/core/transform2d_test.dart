import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/transform2d.dart';

void main() {
  test('fromJsonMap/toJsonMap parse and encode matrix', () {
    final t = Transform2D.fromJsonMap(const <String, Object?>{
      'a': 1,
      'b': 2,
      'c': 3,
      'd': 4,
      'tx': 5,
      'ty': 6,
    });

    expect(t.toJsonMap(), {
      'a': 1.0,
      'b': 2.0,
      'c': 3.0,
      'd': 4.0,
      'tx': 5.0,
      'ty': 6.0,
    });
  });

  test('fromJsonMap throws when fields are missing/non-numeric', () {
    expect(
      () => Transform2D.fromJsonMap(const <String, Object?>{}),
      throwsArgumentError,
    );
    expect(
      () => Transform2D.fromJsonMap(const <String, Object?>{
        'a': 1,
        'b': 0,
        'c': 0,
        'd': 1,
        'tx': 'x',
        'ty': 0,
      }),
      throwsArgumentError,
    );
  });

  test('trs/translation/scale/rotation composition works', () {
    final trs = Transform2D.trs(
      translation: const Offset(10, 20),
      rotationDeg: 90,
      scaleX: 2,
      scaleY: 3,
    );

    final point = trs.applyToPoint(const Offset(1, 0));
    expect(point.dx, closeTo(10, 1e-9));
    expect(point.dy, closeTo(22, 1e-9));

    expect(trs.translation, const Offset(10, 20));
    expect(
      trs.withTranslation(const Offset(7, 8)).translation,
      const Offset(7, 8),
    );
  });

  test('multiply and applyToRect transform geometry', () {
    final t = Transform2D.translation(
      const Offset(5, 0),
    ).multiply(Transform2D.scale(2, 1));
    expect(t.applyToPoint(const Offset(3, 4)), const Offset(11, 4));

    final rect = t.applyToRect(const Rect.fromLTWH(0, 0, 2, 3));
    expect(rect, const Rect.fromLTRB(5, 0, 9, 3));
  });

  test(
    'invert returns inverse for regular matrix and null for singular/non-finite',
    () {
      const t = Transform2D(a: 2, b: 0, c: 0, d: 4, tx: 10, ty: -8);
      final inv = t.invert();
      expect(inv, isNotNull);

      final p = const Offset(3, 5);
      expect(inv!.applyToPoint(t.applyToPoint(p)).dx, closeTo(p.dx, 1e-9));
      expect(inv.applyToPoint(t.applyToPoint(p)).dy, closeTo(p.dy, 1e-9));

      const singular = Transform2D(a: 1, b: 2, c: 2, d: 4, tx: 0, ty: 0);
      expect(singular.invert(), isNull);

      const nonFinite = Transform2D(
        a: double.nan,
        b: 0,
        c: 0,
        d: 1,
        tx: 0,
        ty: 0,
      );
      expect(nonFinite.invert(), isNull);
    },
  );

  test('canvas transform serialization writes expected slots', () {
    const t = Transform2D(a: 1, b: 2, c: 3, d: 4, tx: 5, ty: 6);

    final matrix = t.toCanvasTransform();
    expect(matrix.length, 16);
    expect(matrix[0], 1);
    expect(matrix[1], 2);
    expect(matrix[4], 3);
    expect(matrix[5], 4);
    expect(matrix[12], 5);
    expect(matrix[13], 6);

    final out = Float64List(16);
    t.writeToCanvasTransform(out);
    expect(out[12], 5);
    expect(out[13], 6);

    expect(
      () => t.writeToCanvasTransform(Float64List(15)),
      throwsArgumentError,
    );
  });

  test('isFinite reflects component finiteness', () {
    const ok = Transform2D(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0);
    const bad = Transform2D(a: double.infinity, b: 0, c: 0, d: 1, tx: 0, ty: 0);
    expect(ok.isFinite, isTrue);
    expect(bad.isFinite, isFalse);
  });
}
