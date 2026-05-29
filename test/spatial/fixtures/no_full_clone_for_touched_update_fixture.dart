import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/touched_set.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_kernel.dart';

import 'spatial_kernel_test_support.dart';

void main() {
  test('ordinary update avoids full clone and clear reset empties index', () {
    final kernel = SpatialKernel();
    kernel.rebuild(
      SpatialFrameFactsPortFixture([
        spatialRect('a', order: 1),
        spatialRect('b', order: 2),
      ]),
    );
    final before = kernel.snapshot;
    final updated = SpatialFrameFactsPortFixture([
      spatialRect('a', order: 1),
      spatialRect('b', order: 2, translation: const Offset(300, 0)),
    ]);

    kernel.applyTouched(
      updated,
      TouchedSet(geometryElementIds: [CanvasElementId('b')]),
    );

    expect(updated.elementHandlesCalls, 0);
    expect(kernel.snapshot.entryCount, before.entryCount);

    applyAndExpectSpatialClearReset(kernel);
  });
}
