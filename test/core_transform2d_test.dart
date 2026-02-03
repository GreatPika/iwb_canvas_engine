import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('Transform2D.multiply composes transforms in the right order', () {
    final scale = Transform2D.scale(2, 3);
    final translate = Transform2D.translation(const Offset(10, 20));

    final translateAfterScale = translate.multiply(scale);
    final result1 = translateAfterScale.applyToPoint(const Offset(1, 1));
    expect(result1.dx, closeTo(12, 0.0001));
    expect(result1.dy, closeTo(23, 0.0001));

    final scaleAfterTranslate = scale.multiply(translate);
    final result2 = scaleAfterTranslate.applyToPoint(const Offset(1, 1));
    expect(result2.dx, closeTo(22, 0.0001));
    expect(result2.dy, closeTo(63, 0.0001));
  });

  test('Transform2D.toCanvasTransform matches applyToPoint', () {
    final transform = Transform2D(
      a: 1.25,
      b: 0.5,
      c: -0.75,
      d: 2.0,
      tx: 4.0,
      ty: -7.0,
    );
    const point = Offset(3, -2);

    final expected = transform.applyToPoint(point);
    final m = transform.toCanvasTransform();

    double at(int row, int col) => m[col * 4 + row];

    final x =
        at(0, 0) * point.dx + at(0, 1) * point.dy + at(0, 2) * 0 + at(0, 3) * 1;
    final y =
        at(1, 0) * point.dx + at(1, 1) * point.dy + at(1, 2) * 0 + at(1, 3) * 1;

    expect(x, closeTo(expected.dx, 0.0001));
    expect(y, closeTo(expected.dy, 0.0001));
  });

  test('Transform2D.writeToCanvasTransform matches toCanvasTransform', () {
    final transform = Transform2D(
      a: 1.25,
      b: 0.5,
      c: -0.75,
      d: 2.0,
      tx: 4.0,
      ty: -7.0,
    );

    final expected = transform.toCanvasTransform();
    final out = Float64List(16);
    transform.writeToCanvasTransform(out);

    for (var i = 0; i < 16; i++) {
      expect(out[i], expected[i]);
    }
  });

  test('Transform2D.writeToCanvasTransform does not overwrite beyond 16', () {
    final transform = Transform2D(a: 1, b: 2, c: 3, d: 4, tx: 5, ty: 6);

    const sentinel = -123456.0;
    final out = Float64List(20);
    for (var i = 0; i < out.length; i++) {
      out[i] = sentinel;
    }

    transform.writeToCanvasTransform(out);

    for (var i = 16; i < out.length; i++) {
      expect(out[i], sentinel);
    }
  });

  test('Transform2D.writeToCanvasTransform throws when out is too small', () {
    final transform = Transform2D.identity;
    expect(
      () => transform.writeToCanvasTransform(Float64List(15)),
      throwsArgumentError,
    );
  });

  test('Transform2D canvas matrix properties (deterministic)', () {
    final rnd = math.Random(424242);
    for (var i = 0; i < 100; i++) {
      final t = Transform2D(
        a: rnd.nextDouble() * 4 - 2,
        b: rnd.nextDouble() * 4 - 2,
        c: rnd.nextDouble() * 4 - 2,
        d: rnd.nextDouble() * 4 - 2,
        tx: rnd.nextDouble() * 200 - 100,
        ty: rnd.nextDouble() * 200 - 100,
      );

      final expected = t.toCanvasTransform();
      final out = Float64List(16);
      t.writeToCanvasTransform(out);
      for (var j = 0; j < 16; j++) {
        expect(out[j], expected[j]);
      }

      final m = out;
      double at(int row, int col) => m[col * 4 + row];

      for (var p = 0; p < 5; p++) {
        final point = Offset(
          rnd.nextDouble() * 200 - 100,
          rnd.nextDouble() * 200 - 100,
        );
        final expectedPoint = t.applyToPoint(point);
        final x =
            at(0, 0) * point.dx +
            at(0, 1) * point.dy +
            at(0, 2) * 0 +
            at(0, 3) * 1;
        final y =
            at(1, 0) * point.dx +
            at(1, 1) * point.dy +
            at(1, 2) * 0 +
            at(1, 3) * 1;
        expect(x, closeTo(expectedPoint.dx, 1e-9));
        expect(y, closeTo(expectedPoint.dy, 1e-9));
      }
    }
  });
}
