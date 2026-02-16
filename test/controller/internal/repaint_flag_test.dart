import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/controller/internal/repaint_flag.dart';

void main() {
  test('RepaintFlag marks/takes once and can discard pending', () {
    final slice = RepaintFlag();

    expect(slice.needsNotify, isFalse);
    expect(slice.writeTakeNeedsNotify(), isFalse);

    slice.writeMarkNeedsRepaint();
    expect(slice.needsNotify, isTrue);
    expect(slice.writeTakeNeedsNotify(), isTrue);
    expect(slice.needsNotify, isFalse);

    slice.writeMarkNeedsRepaint();
    slice.writeDiscardPending();
    expect(slice.needsNotify, isFalse);
  });
}
