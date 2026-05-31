import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/frame/ordinary_paint_planner.dart';
import 'package:iwb_canvas_engine/src/frame/paint_plan.dart';

import 'ordinary_paint_test_support.dart';

// This fixture compares ordinary key identity across every excluded churn source
// in one place so the cache-boundary invariant is visible.
// ignore: halstead-volume, source-lines-of-code
void main() {
  test('ordinary key contains only next-owned revisions and paint inputs', () {
    final frameFacts = frameFactsPort(
      revisions: revisionsFor(
        document: 10,
        structural: 20,
        bounds: 30,
        visual: 40,
        background: 50,
        grid: 60,
        resource: 70,
      ),
    );
    final planner = OrdinaryPaintPlanner();
    final frame = capturedMainFrame(
      frameFacts: frameFacts,
      viewport: const Rect.fromLTWH(1, 2, 300, 400),
      devicePixelRatio: 2,
    );

    final key = planner.paintPlanKeyFor(frame);

    expect(
      key,
      const PaintPlanKey(
        structuralRevision: 20,
        boundsRevision: 30,
        elementVisualRevision: 40,
        viewportRect: Rect.fromLTWH(1, 2, 300, 400),
        devicePixelRatio: 2,
      ),
    );

    final backgroundOnlyChanged = frameFactsPort(
      revisions: revisionsFor(
        document: 10,
        structural: 20,
        bounds: 30,
        visual: 40,
        background: 999,
        grid: 1000,
        resource: 1001,
      ),
    );
    final sameOrdinaryFrame = capturedMainFrame(
      frameFacts: backgroundOnlyChanged,
      viewport: const Rect.fromLTWH(1, 2, 300, 400),
      devicePixelRatio: 2,
    );

    expect(planner.paintPlanKeyFor(sameOrdinaryFrame), key);
  });

  test(
    'ordinary paint plans include committed background element candidates',
    () {
      final frameFacts = frameFactsPort(
        elements: [
          rectFacts(
            'background',
            orderToken: 0,
            locationKind: FrameElementLocationKind.background,
          ),
          rectFacts('content', orderToken: 1),
        ],
      );
      final planner = OrdinaryPaintPlanner();
      final result = planner.buildOrdinaryPlan(
        capturedMainFrame(frameFacts: frameFacts),
      );

      final ready = result as OrdinaryPaintPlanReady;
      expect(ready.plan.ordinaryRecords.map((record) => record.id.value), [
        'background',
        'content',
      ]);
      expect(planner.ordinaryPaintRecordCache.probe.entries, 1);
    },
  );
}
