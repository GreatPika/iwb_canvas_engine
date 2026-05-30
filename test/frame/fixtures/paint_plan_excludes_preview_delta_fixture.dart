import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_preview.dart';
import 'package:iwb_canvas_engine/src/frame/ordinary_paint_planner.dart';

import 'ordinary_paint_test_support.dart';

void main() {
  test(
    'preview state and selected move delta do not affect ordinary plans',
    () {
      final frameFacts = frameFactsPort();
      final planner = OrdinaryPaintPlanner();
      final noPreviewFrame = capturedMainFrame(frameFacts: frameFacts);
      final selectedMoveFrame = capturedMainFrame(
        frameFacts: frameFacts,
        preview: const CanvasSelectedMovePreview(delta: Offset(40, 50)),
        previewRevision: 99,
      );

      expect(
        planner.paintPlanKeyFor(selectedMoveFrame),
        planner.paintPlanKeyFor(noPreviewFrame),
      );

      final first = planner.buildOrdinaryPlan(noPreviewFrame);
      final second = planner.buildOrdinaryPlan(selectedMoveFrame);

      expect(first, isA<OrdinaryPaintPlanReady>());
      expect(
        second,
        isA<OrdinaryPaintPlanReady>().having(
          (result) => result.cacheHit,
          'cacheHit',
          isTrue,
        ),
      );
      final ready = second as OrdinaryPaintPlanReady;
      expect(ready.plan.ordinaryRecords.single.id.value, 'a');
      expect(ready.plan.ordinaryRecords.single.requiresSaveLayer, isFalse);
    },
  );
}
