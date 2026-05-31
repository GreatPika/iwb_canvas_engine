import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/frame/ordinary_paint_planner.dart';
import 'package:iwb_canvas_engine/src/frame/static_background_planner.dart';

import 'ordinary_paint_test_support.dart';

// Static-background replacement, disposal, and ordinary-key independence stay
// in one fixture because splitting them would hide the cache ownership proof.
// ignore: halstead-volume
void main() {
  test('static background cache key and replacement are separate', () {
    final frameFacts = frameFactsPort(
      revisions: revisionsFor(background: 10, grid: 20),
    );
    final frame = capturedMainFrame(
      frameFacts: frameFacts,
      viewport: const Rect.fromLTWH(0, 0, 100, 100),
      devicePixelRatio: 2,
    );
    final ordinaryKey = OrdinaryPaintPlanner().paintPlanKeyFor(frame);
    final planner = StaticBackgroundPlanner();

    final first = planner.build(frame, viewCameraBucket: 7);
    final again = planner.build(frame, viewCameraBucket: 7);
    final changedFrame = capturedMainFrame(
      frameFacts: frameFactsPort(
        revisions: revisionsFor(background: 11, grid: 20),
      ),
      viewport: const Rect.fromLTWH(0, 0, 100, 100),
      devicePixelRatio: 2,
    );
    final changed = planner.build(changedFrame, viewCameraBucket: 7);

    expect(again, same(first));
    expect(first.key.backgroundRevision, 10);
    expect(first.key.gridRevision, 20);
    expect(
      first.key.gridStrokeWidth,
      frame.snapshot.inputs.gridStyle.strokeWidth,
    );
    expect(first.key.viewCameraBucket, 7);
    expect(first.key.viewportRect, const Rect.fromLTWH(0, 0, 100, 100));
    expect(first.key.devicePixelRatio, 2);
    expect(changed, isNot(same(first)));
    expect(first.picture.isDisposed, isTrue);
    expect(planner.cache.probe.pictureCount, 1);
    expect(planner.cache.probe.rebuildCount, 2);
    expect(OrdinaryPaintPlanner().paintPlanKeyFor(changedFrame), ordinaryKey);

    planner.cache.invalidate();
    expect(changed.picture.isDisposed, isTrue);
    expect(planner.cache.probe.pictureCount, 0);
  });
}
