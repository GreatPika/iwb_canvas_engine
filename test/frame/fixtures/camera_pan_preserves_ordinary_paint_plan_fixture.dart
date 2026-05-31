import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_geometry.dart';
import 'package:iwb_canvas_engine/src/frame/captured_frame.dart';
import 'package:iwb_canvas_engine/src/frame/ordinary_paint_planner.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_result.dart';

import 'ordinary_paint_test_support.dart';

void main() {
  test('camera-only movement stays outside ordinary paint plan identity', () {
    expect(_cameraOnlyMovementStaysOutsidePlanIdentity(), isTrue);
  });

  test('camera pan rebuilds admission from the effective world window', () {
    expect(_panAdmissionUsesEffectiveWorldWindow(), isTrue);
  });

  test('opacity is represented as primitive alpha without saveLayer', () {
    expect(_opacityUsesPrimitiveAlpha(), isTrue);
  });
}

bool _cameraOnlyMovementStaysOutsidePlanIdentity() {
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

  return true;
}

bool _panAdmissionUsesEffectiveWorldWindow() {
  final scenario = _panAdmissionScenario();
  final planner = OrdinaryPaintPlanner();

  expect(
    planner.paintPlanKeyFor(scenario.afterPan),
    planner.paintPlanKeyFor(scenario.beforePan),
  );

  final first = planner.buildOrdinaryPlan(scenario.beforePan);
  final second = planner.buildOrdinaryPlan(scenario.afterPan);
  final third = planner.buildOrdinaryPlan(scenario.beforePan);

  expect(first, isA<OrdinaryPaintPlanReady>());
  expect(
    (second as OrdinaryPaintPlanReady).plan.ordinaryRecords.single.id.value,
    'after-pan',
  );
  expect(
    third,
    isA<OrdinaryPaintPlanReady>()
        .having((result) => result.cacheHit, 'cacheHit', isTrue)
        .having(
          (result) => result.plan.ordinaryRecords.single.id.value,
          'record id',
          'before-pan',
        ),
  );

  return true;
}

_PanAdmissionScenario _panAdmissionScenario() {
  final frameFacts = frameFactsPort(
    elements: [
      rectFacts('before-pan', orderToken: 1),
      rectFacts(
        'after-pan',
        orderToken: 2,
        transform: CanvasTransform.translation(const Offset(150, 0)),
      ),
    ],
  );
  final beforeHandle = frameFacts.spatialCandidates.first;
  final afterHandle = frameFacts.spatialCandidates.last;
  final beforePan = capturedMainFrame(
    frameFacts: frameFacts,
    viewport: const Rect.fromLTWH(0, 0, 100, 100),
    queryPaint: (_) =>
        SpatialCandidatesResult(orderedCandidates: [beforeHandle]),
  );
  final afterPan = capturedMainFrame(
    frameFacts: frameFacts,
    viewport: const Rect.fromLTWH(0, 0, 100, 100),
    viewCameraOffset: const Offset(140, 0),
    queryPaint: (window) => SpatialCandidatesResult(
      orderedCandidates: window.boundsWorld.left == 140
          ? [afterHandle]
          : [beforeHandle],
    ),
  );

  return _PanAdmissionScenario(beforePan: beforePan, afterPan: afterPan);
}

bool _opacityUsesPrimitiveAlpha() {
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

  return true;
}

final class _PanAdmissionScenario {
  const _PanAdmissionScenario({
    required this.beforePan,
    required this.afterPan,
  });

  final CapturedMainFrame beforePan;
  final CapturedMainFrame afterPan;
}
