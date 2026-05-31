import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/frame/captured_frame.dart';
import 'package:iwb_canvas_engine/src/frame/ordinary_paint_planner.dart';
import 'package:iwb_canvas_engine/src/frame/static_background_planner.dart';

import 'ordinary_paint_test_support.dart';

// Static-background replacement, disposal, and ordinary-key independence stay
// in one fixture because splitting them would hide the cache ownership proof.
// ignore: halstead-volume
void main() {
  _testStaticBackgroundIdentity();
}

void _testStaticBackgroundIdentity() {
  test('static background cache key and replacement are separate', () {
    final scenario = _buildStaticBackgroundScenario();

    expect(scenario.again, same(scenario.first));
    _expectStaticBackgroundPlan(scenario.first, scenario.frame);
    expect(scenario.changed, isNot(same(scenario.first)));
    expect(scenario.first.picture.isDisposed, isTrue);
    expect(scenario.planner.cache.probe.pictureCount, 1);
    expect(scenario.planner.cache.probe.rebuildCount, 2);
    expect(
      OrdinaryPaintPlanner().paintPlanKeyFor(scenario.changedFrame),
      scenario.ordinaryKey,
    );

    scenario.planner.cache.invalidate();
    expect(scenario.changed.picture.isDisposed, isTrue);
    expect(scenario.planner.cache.probe.pictureCount, 0);
  });
}

({
  CapturedMainFrame frame,
  CapturedMainFrame changedFrame,
  Object ordinaryKey,
  StaticBackgroundPlanner planner,
  StaticBackgroundPlan first,
  StaticBackgroundPlan again,
  StaticBackgroundPlan changed,
})
_buildStaticBackgroundScenario() {
  final frame = _staticFrame(background: 10);
  final planner = StaticBackgroundPlanner();
  final first = planner.build(frame, viewCameraBucket: 7);
  final changedFrame = _staticFrame(background: 11);

  return (
    frame: frame,
    changedFrame: changedFrame,
    ordinaryKey: OrdinaryPaintPlanner().paintPlanKeyFor(frame),
    planner: planner,
    first: first,
    again: planner.build(frame, viewCameraBucket: 7),
    changed: planner.build(changedFrame, viewCameraBucket: 7),
  );
}

CapturedMainFrame _staticFrame({required int background}) {
  return capturedMainFrame(
    frameFacts: frameFactsPort(
      revisions: revisionsFor(background: background, grid: 20),
    ),
    viewport: const Rect.fromLTWH(0, 0, 100, 100),
    devicePixelRatio: 2,
  );
}

void _expectStaticBackgroundPlan(
  StaticBackgroundPlan plan,
  CapturedMainFrame frame,
) {
  expect(plan.key.backgroundRevision, 10);
  expect(plan.key.gridRevision, 20);
  expect(plan.key.gridStrokeWidth, frame.snapshot.inputs.gridStyle.strokeWidth);
  expect(plan.key.viewCameraBucket, 7);
  expect(plan.key.viewportRect, const Rect.fromLTWH(0, 0, 100, 100));
  expect(plan.key.devicePixelRatio, 2);
  expect(plan.primitive.viewportRect, plan.key.viewportRect);
  expect(plan.primitive.gridStrokeWidth, plan.key.gridStrokeWidth);
}
