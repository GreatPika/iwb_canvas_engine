import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/interactive_draw_path_buffer.dart';

void main() {
  test('buffer soft-caps move samples while preserving endpoints', () {
    final buffer = InteractiveDrawPathBuffer(softLimit: 6, trimTo: 4);

    buffer.start(const Offset(0, 0));
    for (var i = 1; i <= 8; i++) {
      buffer.appendMovePoint(Offset(i.toDouble(), 0));
    }

    expect(buffer.length, lessThanOrEqualTo(6));
    expect(buffer.points.first, const Offset(0, 0));
    expect(buffer.points.last, const Offset(8, 0));
  });

  test('terminal append can apply the same soft cap for eraser paths', () {
    final buffer = InteractiveDrawPathBuffer(softLimit: 5, trimTo: 3);

    buffer.start(const Offset(0, 0));
    for (var i = 1; i <= 4; i++) {
      buffer.appendMovePoint(Offset(i.toDouble(), 0));
    }
    buffer.appendTerminalPoint(const Offset(5, 0), enforceSoftLimit: true);

    expect(buffer.length, lessThanOrEqualTo(5));
    expect(buffer.points.first, const Offset(0, 0));
    expect(buffer.points.last, const Offset(5, 0));
  });
}
