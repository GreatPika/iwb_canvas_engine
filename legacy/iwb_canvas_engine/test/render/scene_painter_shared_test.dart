import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/render/scene_painter_shared.dart';

void main() {
  test('scenePainterNormalizeRect returns axis-aligned bounds', () {
    expect(
      scenePainterNormalizeRect(const Rect.fromLTRB(8, 6, 2, 1)),
      const Rect.fromLTRB(2, 1, 8, 6),
    );
  });
}
