import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';

void main() {
  // INV:INV-CORE-TRANSFORM-APPLYTORECT-DEGENERATE
  test('Transform2D.applyToRect preserves translation for point rect', () {
    final t = Transform2D.translation(const Offset(10, 20));
    final rect = t.applyToRect(const Rect.fromLTWH(0, 0, 0, 0));

    expect(rect.topLeft, const Offset(10, 20));
    expect(rect.size, Size.zero);
  });

  test('Transform2D.applyToRect preserves translation for line rect', () {
    final t = Transform2D.translation(const Offset(10, 20));
    final rect = t.applyToRect(const Rect.fromLTWH(0, 0, 0, 10));

    expect(rect.left, closeTo(10, 1e-9));
    expect(rect.right, closeTo(10, 1e-9));
    expect(rect.top, closeTo(20, 1e-9));
    expect(rect.bottom, closeTo(30, 1e-9));
  });

  test('Transform2D.applyToRect transforms degenerate rect under rotation', () {
    final t = Transform2D.rotationDeg(90);
    final rect = t.applyToRect(const Rect.fromLTWH(0, 0, 10, 0));

    expect(rect, isNot(Rect.zero));
    expect(rect.left, closeTo(0, 1e-9));
    expect(rect.right, closeTo(0, 1e-9));
    expect(rect.top, closeTo(0, 1e-9));
    expect(rect.bottom, closeTo(10, 1e-9));
  });

  test('Transform2D.toCanvasTransform expands into 4x4 matrix', () {
    const t = Transform2D(a: 1, b: 2, c: 3, d: 4, tx: 5, ty: 6);
    final m = t.toCanvasTransform();

    expect(m, hasLength(16));
    expect(m[0], 1);
    expect(m[1], 2);
    expect(m[4], 3);
    expect(m[5], 4);
    expect(m[12], 5);
    expect(m[13], 6);
    expect(m[10], 1);
    expect(m[15], 1);
  });

  test('Transform2D.writeToCanvasTransform validates and writes', () {
    const t = Transform2D(a: 1, b: 2, c: 3, d: 4, tx: 5, ty: 6);

    expect(
      () => t.writeToCanvasTransform(Float64List(15)),
      throwsA(isA<ArgumentError>()),
    );

    final out = Float64List(16);
    t.writeToCanvasTransform(out);
    expect(out, t.toCanvasTransform());
  });
}
