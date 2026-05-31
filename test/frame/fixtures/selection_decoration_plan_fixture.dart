import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/selection_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_ids.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_surface_styles.dart';
import 'package:iwb_canvas_engine/src/frame/ordinary_paint_planner.dart';
import 'package:iwb_canvas_engine/src/frame/selection_decoration_planner.dart';

import 'ordinary_paint_test_support.dart';

// This fixture keeps decoration-key churn and ordinary-key non-churn together
// so selection invalidation cannot accidentally become an ordinary cache input.
// ignore: halstead-volume, source-lines-of-code
void main() {
  test(
    'selection decoration key includes selection, style, DPR, and bounds',
    () {
      final selected = SelectionFacts(
        selectedElementIds: [CanvasElementId('a')],
        selectionRevision: 5,
      );
      final frame = capturedMainFrame(
        frameFacts: frameFactsPort(revisions: revisionsFor(bounds: 10)),
        selectionFacts: selected,
        selectionStyle: CanvasSelectionStyle(
          color: const Color(0xFF00AAFF),
          strokeWidth: 3,
        ),
        devicePixelRatio: 2,
      );
      final changedBounds = capturedMainFrame(
        frameFacts: frameFactsPort(revisions: revisionsFor(bounds: 11)),
        selectionFacts: selected,
        selectionStyle: frame.snapshot.inputs.selectionStyle,
        devicePixelRatio: 2,
      );
      final changedSelectionOnly = capturedMainFrame(
        frameFacts: frameFactsPort(revisions: revisionsFor(bounds: 10)),
        selectionFacts: SelectionFacts(
          selectedElementIds: [CanvasElementId('a'), CanvasElementId('b')],
          selectionRevision: 6,
        ),
        selectionStyle: frame.snapshot.inputs.selectionStyle,
        devicePixelRatio: 2,
      );
      final ordinaryKey = OrdinaryPaintPlanner().paintPlanKeyFor(frame);
      final planner = SelectionDecorationPlanner();

      final first = planner.build(frame);
      final again = planner.build(frame);
      final changed = planner.build(changedBounds);

      expect(again, same(first));
      expect(first.key.selectionRevision, 5);
      expect(first.key.selectedElementIds, {CanvasElementId('a')});
      expect(first.key.boundsRevision, 10);
      expect(first.key.devicePixelRatio, 2);
      expect(first.selectedCount, 1);
      expect(changed, isNot(same(first)));
      expect(planner.probe.selectedCount, 1);
      expect(planner.probe.rebuildCount, 2);
      expect(
        OrdinaryPaintPlanner().paintPlanKeyFor(changedSelectionOnly),
        ordinaryKey,
      );
    },
  );
}
