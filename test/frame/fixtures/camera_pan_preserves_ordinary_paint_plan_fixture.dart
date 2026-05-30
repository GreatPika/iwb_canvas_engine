import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/frame/ordinary_paint_planner.dart';

import 'ordinary_paint_test_support.dart';

void main() {
  test('camera-only movement stays outside ordinary paint plan identity', () {
    final frameFacts = frameFactsPort();
    final planner = OrdinaryPaintPlanner();
    final beforePan = capturedMainFrame(
      frameFacts: frameFacts,
      viewport: const Rect.fromLTWH(0, 0, 100, 100),
    );
    final afterPanSameWorldWindow = capturedMainFrame(
      frameFacts: frameFacts,
      viewport: const Rect.fromLTWH(0, 0, 100, 100),
    );

    expect(
      planner.paintPlanKeyFor(afterPanSameWorldWindow),
      planner.paintPlanKeyFor(beforePan),
    );

    final first = planner.buildOrdinaryPlan(beforePan);
    final second = planner.buildOrdinaryPlan(afterPanSameWorldWindow);

    expect(first, isA<OrdinaryPaintPlanReady>());
    expect(
      second,
      isA<OrdinaryPaintPlanReady>().having(
        (result) => result.cacheHit,
        'cacheHit',
        isTrue,
      ),
    );
  });

  test('opacity is represented as primitive alpha without saveLayer', () {
    final frameFacts = frameFactsPort(
      elements: [rectFacts('transparent', orderToken: 1, opacity: 0.5)],
    );
    final planner = OrdinaryPaintPlanner();
    final result = planner.buildOrdinaryPlan(
      capturedMainFrame(frameFacts: frameFacts),
    );

    final ready = result as OrdinaryPaintPlanReady;
    final record = ready.plan.ordinaryRecords.single;
    expect(record.primitiveAlpha, 128);
    expect(record.requiresSaveLayer, isFalse);
  });
}
