import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_ids.dart';
import 'package:iwb_canvas_engine/src/frame/selected_order_cache.dart';

void main() {
  test('selected order cache keeps one derived snapshot', () {
    final cache = SelectedOrderCache();
    const firstKey = SelectedOrderKey(
      selectionRevision: 1,
      structuralRevision: 2,
    );
    const changedKey = SelectedOrderKey(
      selectionRevision: 2,
      structuralRevision: 2,
    );

    final first = cache.readOrBuild(
      key: firstKey,
      orderedSelectedIds: [CanvasElementId('b'), CanvasElementId('a')],
    );
    final again = cache.readOrBuild(
      key: firstKey,
      orderedSelectedIds: [CanvasElementId('ignored')],
    );
    final changed = cache.readOrBuild(
      key: changedKey,
      orderedSelectedIds: [CanvasElementId('c')],
    );

    expect(again, same(first));
    expect(first.orderedSelectedIds, [
      CanvasElementId('b'),
      CanvasElementId('a'),
    ]);
    expect(changed, isNot(same(first)));
    expect(cache.probe.selectedCount, 1);
    expect(cache.probe.rebuildCount, 2);
  });
}
