import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_ids.dart';
import 'package:iwb_canvas_engine/src/frame/ordinary_paint_planner.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_result.dart';

import 'ordinary_paint_test_support.dart';

// These rejection cases stay in one fixture because they prove the same
// all-or-nothing cache-write boundary from three failure directions.
// ignore: halstead-volume, source-lines-of-code
void main() {
  test('stale admitted candidate rejects the whole cache write', () {
    final rows = [
      textFacts('accepted', orderToken: 1),
      rectFacts('stale', orderToken: 2),
    ];
    final frameFacts = frameFactsPort(
      elements: rows,
      staleIds: {CanvasElementId('stale')},
    );
    final frame = capturedMainFrame(frameFacts: frameFacts);
    final resolveCallsAfterCapture = frameFacts.resolveElementCalls;
    final planner = OrdinaryPaintPlanner();
    final beforeProbe = planner.paintPlanCache.probe;

    final result = planner.buildOrdinaryPlan(frame);

    expect(result, isA<OrdinaryPaintPlanRejected>());
    expect(planner.rejectedCandidateCount, 1);
    expect(frameFacts.resolveElementCalls, resolveCallsAfterCapture);
    expect(planner.paintPlanCache.probe.entries, beforeProbe.entries);
    expect(planner.paintPlanCache.probe.writes, beforeProbe.writes);
    expect(planner.paintPlanCache.probe.evictions, beforeProbe.evictions);
    expect(planner.textLayoutCache.probe.entries, 0);
    expect(planner.textLayoutCache.probe.writes, 0);
    expect(planner.textLayoutCache.probe.misses, 0);
  });

  test('stale admitted candidate rejects before cache hit', () {
    final row = rectFacts('accepted', orderToken: 1);
    final firstFrameFacts = frameFactsPort(elements: [row]);
    final planner = OrdinaryPaintPlanner();

    final first = planner.buildOrdinaryPlan(
      capturedMainFrame(frameFacts: firstFrameFacts),
    );

    final staleFrameFacts = frameFactsPort(
      elements: [row],
      staleIds: {CanvasElementId('accepted')},
    );
    final stale = planner.buildOrdinaryPlan(
      capturedMainFrame(frameFacts: staleFrameFacts),
    );

    expect(first, isA<OrdinaryPaintPlanReady>());
    expect(stale, isA<OrdinaryPaintPlanRejected>());
    expect(planner.paintPlanCache.probe.hits, 0);
  });

  test('failed spatial admission rejects without empty cache writes', () {
    final frameFacts = frameFactsPort();
    final planner = OrdinaryPaintPlanner();
    final failedAdmissionFrame = capturedMainFrame(
      frameFacts: frameFacts,
      spatialPaintResult: const SpatialBudgetExceededResult(
        reason: SpatialBudgetExceededReason.queryTileBudgetExceeded,
        budget: 1,
        observed: 2,
      ),
    );

    final failed = planner.buildOrdinaryPlan(failedAdmissionFrame);
    final successful = planner.buildOrdinaryPlan(
      capturedMainFrame(frameFacts: frameFacts),
    );

    expect(failed, isA<OrdinaryPaintPlanRejected>());
    expect(planner.paintPlanCache.probe.writes, 1);
    expect(
      successful,
      isA<OrdinaryPaintPlanReady>().having(
        (result) => result.cacheHit,
        'cacheHit',
        isFalse,
      ),
    );
    final ready = successful as OrdinaryPaintPlanReady;
    expect(ready.plan.ordinaryRecords, isNotEmpty);
  });
}
