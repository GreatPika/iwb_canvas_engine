import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/numeric_clamp.dart';

void main() {
  test(
    'clamp01Finite clamps out-of-range values and uses fallback for non-finite input',
    () {
      expect(clamp01Finite(-0.5), 0.0);
      expect(clamp01Finite(0.25), 0.25);
      expect(clamp01Finite(2), 1.0);
      expect(clamp01Finite(double.nan, fallback: 0.4), 0.4);
    },
  );
}
