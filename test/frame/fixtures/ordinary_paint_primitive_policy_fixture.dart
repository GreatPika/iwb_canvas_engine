import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/frame/ordinary_paint_planner.dart';

import 'ordinary_paint_test_support.dart';

void main() {
  test('opacity is represented as primitive alpha without saveLayer', () {
    expect(_opacityUsesPrimitiveAlpha(), isTrue);
  });
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
