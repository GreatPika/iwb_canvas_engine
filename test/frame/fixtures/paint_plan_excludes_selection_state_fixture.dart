import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/selection_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_ids.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_surface_styles.dart';
import 'package:iwb_canvas_engine/src/frame/ordinary_paint_planner.dart';

import 'ordinary_paint_test_support.dart';

void main() {
  test('selection ids, revision, and style do not affect ordinary plans', () {
    final frameFacts = frameFactsPort();
    final planner = OrdinaryPaintPlanner();
    final unselectedFrame = capturedMainFrame(frameFacts: frameFacts);
    final selectedFrame = capturedMainFrame(
      frameFacts: frameFacts,
      selectionFacts: SelectionFacts(
        selectedElementIds: [CanvasElementId('a')],
        selectionRevision: 77,
      ),
      selectionStyle: CanvasSelectionStyle(
        color: const Color(0xFFFF00FF),
        strokeWidth: 3,
      ),
    );

    expect(
      planner.paintPlanKeyFor(selectedFrame),
      planner.paintPlanKeyFor(unselectedFrame),
    );

    final first = planner.buildOrdinaryPlan(unselectedFrame);
    final second = planner.buildOrdinaryPlan(selectedFrame);

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
    expect(ready.plan.ordinaryRecords.single.id, CanvasElementId('a'));
  });
}
