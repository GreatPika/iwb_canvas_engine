import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_document.dart';
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
  test('static background cache key and replacement are separate', () async {
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
    await _expectCommittedBackgroundPaintFacts(scenario.changed);

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
      background: CanvasBackground(
        color: const Color(0xFF112233),
        grid: CanvasGrid(
          enabled: true,
          cellSize: 24,
          color: const Color(0x33445566),
        ),
      ),
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

Future<void> _expectCommittedBackgroundPaintFacts(
  StaticBackgroundPlan plan,
) async {
  expect(plan.primitive.backgroundColor, const Color(0xFF112233));
  expect(plan.primitive.gridEnabled, isTrue);
  expect(plan.primitive.gridCellSize, 24);
  expect(plan.primitive.gridColor, const Color(0x33445566));
  expect(
    await _pixelColor(plan.picture.picture, 5, 5),
    const Color(0xFF112233),
  );
}

Future<Color> _pixelColor(Picture picture, int x, int y) async {
  final image = await picture.toImage(32, 32);
  final bytes = await image.toByteData(format: ImageByteFormat.rawStraightRgba);
  image.dispose();
  if (bytes == null) {
    throw StateError('static background picture did not produce pixel data');
  }
  final offset = (y * 32 + x) * 4;

  return Color.fromARGB(
    bytes.getUint8(offset + 3),
    bytes.getUint8(offset),
    bytes.getUint8(offset + 1),
    bytes.getUint8(offset + 2),
  );
}
