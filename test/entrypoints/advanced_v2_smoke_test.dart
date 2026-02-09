import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced_v2.dart';

// INV:INV-V2-NO-EXTERNAL-MUTATION

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('advanced_v2.dart re-exports basic_v2.dart symbols', () {
    const patch = PathNodePatch(
      id: 'path-1',
      fillRule: PatchField<V2PathFillRule>.value(V2PathFillRule.nonZero),
    );
    final spec = PathNodeSpec(
      svgPathData: 'M0 0 L1 1',
      fillRule: V2PathFillRule.nonZero,
    );
    const snapshot = PathNodeSnapshot(
      id: 'path-1',
      svgPathData: 'M0 0 L1 1',
      strokeWidth: 2,
      strokeColor: Color(0xFF000000),
    );

    expect(patch.fillRule.value, V2PathFillRule.nonZero);
    expect(spec.svgPathData, 'M0 0 L1 1');
    expect(snapshot.strokeWidth, 2);
  });
}
