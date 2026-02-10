import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';

// INV:INV-V2-NO-EXTERNAL-MUTATION
// INV:INV-G-PUBLIC-ENTRYPOINTS

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('advanced.dart re-exports v2 symbols from basic.dart', () {
    const patch = PathNodePatch(
      id: 'path-1',
      fillRule: PatchField<V2PathFillRule>.value(V2PathFillRule.nonZero),
    );
    expect(patch.fillRule.value, V2PathFillRule.nonZero);
  });
}
