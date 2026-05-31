import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/frame/ordinary_paint_planner.dart';
import 'package:iwb_canvas_engine/src/frame/render_primitive_cache_snapshot.dart';

import 'ordinary_paint_test_support.dart';

void main() {
  test('ordinary planning exposes cached primitives for painters', () {
    final snapshot = _renderPrimitiveSnapshotForPainterProof();

    expect(snapshot.textLayouts, hasLength(1));
    expect(snapshot.textLayouts.values.single.painter.width, isNonNegative);
    expect(snapshot.paths, hasLength(1));
    expect(snapshot.paths.values.single.path.getBounds().center, Offset.zero);
    expect(snapshot.strokes, hasLength(1));
    expect(snapshot.strokes.values.single.path, isNotNull);
  });
}

RenderPrimitiveCacheSnapshot _renderPrimitiveSnapshotForPainterProof() {
  final frameFacts = frameFactsPort(
    elements: [
      textFacts('text-a', orderToken: 1),
      pathFacts('path-a', orderToken: 2, svgPathData: 'M0,0 L10,0 L10,10 Z'),
      strokeFacts('stroke-a', orderToken: 3),
    ],
  );
  final planner = OrdinaryPaintPlanner();
  final result = planner.buildOrdinaryPlan(
    capturedMainFrame(frameFacts: frameFacts),
  );
  final ready = result as OrdinaryPaintPlanReady;

  return planner.renderPrimitiveSnapshotFor(ready.plan.ordinaryRecords);
}
