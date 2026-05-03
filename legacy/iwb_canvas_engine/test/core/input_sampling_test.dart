import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/input_sampling.dart';

void main() {
  test('squaredDistanceBetween computes Euclidean squared distance', () {
    expect(
      squaredDistanceBetween(const Offset(0, 0), const Offset(3, 4)),
      equals(25),
    );
  });

  test('isDistanceAtMost uses inclusive boundary', () {
    expect(isDistanceAtMost(const Offset(0, 0), const Offset(3, 4), 5), isTrue);
    expect(
      isDistanceAtMost(const Offset(0, 0), const Offset(3, 4), 4.99),
      isFalse,
    );
  });

  test('isDistanceAtLeast uses inclusive boundary', () {
    expect(
      isDistanceAtLeast(const Offset(0, 0), const Offset(3, 4), 5),
      isTrue,
    );
    expect(
      isDistanceAtLeast(const Offset(0, 0), const Offset(3, 4), 5.01),
      isFalse,
    );
  });

  test('isDistanceGreaterThan uses strict boundary', () {
    expect(
      isDistanceGreaterThan(const Offset(0, 0), const Offset(3, 4), 5),
      isFalse,
    );
    expect(
      isDistanceGreaterThan(const Offset(0, 0), const Offset(3, 4), 4.99),
      isTrue,
    );
  });

  test('threshold is clamped to non-negative finite values', () {
    expect(
      isDistanceAtMost(const Offset(0, 0), const Offset(0, 0), -1),
      isTrue,
    );
    expect(
      isDistanceAtMost(const Offset(0, 0), const Offset(1, 0), -1),
      isFalse,
    );
    expect(
      isDistanceAtLeast(const Offset(0, 0), const Offset(1, 0), -1),
      isTrue,
    );
    expect(
      isDistanceGreaterThan(const Offset(0, 0), const Offset(1, 0), -1),
      isTrue,
    );
  });
}
