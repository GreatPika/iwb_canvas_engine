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
}
