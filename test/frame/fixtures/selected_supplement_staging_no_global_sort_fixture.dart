// This fixture imports the full selected-move staging boundary so stale-row,
// spatial-query, transform, and ordinary-cache probes stay in one proof.
// ignore_for_file: number-of-imports

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/selection_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_geometry.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_ids.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_preview.dart';
import 'package:iwb_canvas_engine/src/frame/captured_frame.dart';
import 'package:iwb_canvas_engine/src/frame/frame_spatial_paint_admission.dart';
import 'package:iwb_canvas_engine/src/frame/ordinary_paint_planner.dart';
import 'package:iwb_canvas_engine/src/frame/paint_plan.dart';
import 'package:iwb_canvas_engine/src/frame/selected_move_supplement_planner.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_result.dart';

import 'ordinary_paint_test_support.dart';

// The selected-move staging proof is intentionally end-to-end: splitting the
// assertions would obscure that selected filtering happens after ordinary cache
// lookup and still avoids a global scene sort.
// ignore: halstead-volume, maintainability-index, source-lines-of-code
void main() {
  _testRejectedShiftedAdmission(
    label: 'budget exceeded',
    result: const SpatialBudgetExceededResult(
      reason: SpatialBudgetExceededReason.queryTileBudgetExceeded,
      budget: 1,
      observed: 2,
    ),
    reason: FrameSpatialPaintRejectionReason.budgetExceeded,
  );
  _testRejectedShiftedAdmission(
    label: 'invalid index',
    result: const SpatialInvalidIndexResult(
      reason: SpatialInvalidIndexReason.rebuildNeeded,
    ),
    reason: FrameSpatialPaintRejectionReason.invalidIndex,
  );
  _testRejectedShiftedAdmission(
    label: 'stale candidate',
    result: const SpatialStaleCandidateResult(
      expectedStructuralRevision: 1,
      observedStructuralRevision: 2,
    ),
    reason: FrameSpatialPaintRejectionReason.staleCandidate,
  );
  _testValidEmptyShiftedAdmission();
  _testZeroDeltaSelectedMoveUsesOrdinaryPlan();
  test('selected move supplement merges by order without ordinary writes', () {
    final selected = SelectionFacts(
      selectedElementIds: [
        CanvasElementId('a'),
        CanvasElementId('c'),
        CanvasElementId('locked'),
        CanvasElementId('stale'),
        CanvasElementId('offscreen'),
      ],
      selectionRevision: 3,
    );
    final rows = [
      rectFacts('a', orderToken: 1),
      rectFacts('b', orderToken: 2),
      strokeFacts('c', orderToken: 3, transform: CanvasTransform.scale(2, 2)),
      rectFacts('stale', orderToken: 4),
      rectFacts('locked', orderToken: 5, isLocked: true),
      rectFacts(
        'offscreen',
        orderToken: 6,
        transform: CanvasTransform.translation(const Offset(150, 0)),
      ),
    ];
    final ascendingFacts = frameFactsPort(elements: rows);
    final descendingCandidates = ascendingFacts.spatialCandidates.reversed
        .toList();
    final frameFacts = frameFactsPort(
      elements: rows,
      spatialCandidates: descendingCandidates,
    );
    final supplementFrameFacts = frameFactsPort(
      elements: rows,
      spatialCandidates: descendingCandidates,
      staleIds: {CanvasElementId('stale')},
    );
    final frame = capturedMainFrame(
      frameFacts: frameFacts,
      selectionFacts: selected,
      preview: const CanvasSelectedMovePreview(delta: Offset(5, 0)),
    );
    final ordinaryPlanner = OrdinaryPaintPlanner();
    final ordinary =
        ordinaryPlanner.buildOrdinaryPlan(frame) as OrdinaryPaintPlanReady;
    final queriedWindows = <SpatialQueryWindow>[];
    final supplementPlanner = SelectedMoveSupplementPlanner(
      frameFacts: supplementFrameFacts,
      queryPaint: (window) {
        queriedWindows.add(window);

        return SpatialCandidatesResult(
          orderedCandidates: supplementFrameFacts.spatialCandidates,
        );
      },
    );

    final supplement = supplementPlanner.build(
      frame: frame,
      ordinaryPlan: ordinary.plan,
    );

    expect(
      queriedWindows.single.boundsWorld,
      const Rect.fromLTWH(-5, 0, 100, 100),
    );
    expect(supplement.mergedRecords.map((record) => record.id), [
      CanvasElementId('locked'),
      CanvasElementId('c'),
      CanvasElementId('b'),
      CanvasElementId('a'),
    ]);
    expect(supplement.mergedRecords.first.transform.translation, Offset.zero);
    expect(
      supplement.mergedRecords[1].transform.translation,
      const Offset(5, 0),
    );
    expect(supplement.probe.selectedFilteredCount, 3);
    expect(supplement.probe.supplementCount, 2);
    expect(supplement.probe.skippedStaleCount, 1);
    expect(supplement.probe.globalSortCount, 0);
    expect(supplement.probe.ordinaryCacheWritesDuringSupplement, 0);
    expect(supplement.probe.rejectedAdmissionReason, isNull);
  });
}

void _testZeroDeltaSelectedMoveUsesOrdinaryPlan() {
  test('zero-delta selected move preview keeps ordinary paint records', () {
    final scenario = _selectedMoveScenario(delta: Offset.zero);
    final ordinaryPlanner = OrdinaryPaintPlanner();
    final ordinary =
        ordinaryPlanner.buildOrdinaryPlan(scenario.frame)
            as OrdinaryPaintPlanReady;
    final queriedWindows = <SpatialQueryWindow>[];
    final supplementPlanner = SelectedMoveSupplementPlanner(
      frameFacts: scenario.frameFacts,
      queryPaint: (window) {
        queriedWindows.add(window);

        return SpatialCandidatesResult(
          orderedCandidates: scenario.frameFacts.spatialCandidates,
        );
      },
    );

    final supplement = supplementPlanner.build(
      frame: scenario.frame,
      ordinaryPlan: ordinary.plan,
    );

    expect(queriedWindows, isEmpty);
    expect(
      supplement.mergedRecords,
      orderedEquals(ordinary.plan.ordinaryRecords),
    );
    expect(supplement.probe.selectedFilteredCount, 0);
    expect(supplement.probe.supplementCount, 0);
    expect(supplement.probe.skippedStaleCount, 0);
    expect(supplement.probe.rejectedAdmissionReason, isNull);
  });
}

void _testRejectedShiftedAdmission({
  required String label,
  required SpatialQueryResult result,
  required FrameSpatialPaintRejectionReason reason,
}) {
  test('rejected shifted admission preserves ordinary records for $label', () {
    final scenario = _selectedMoveScenario();
    final ordinaryPlanner = OrdinaryPaintPlanner();
    final ordinary =
        ordinaryPlanner.buildOrdinaryPlan(scenario.frame)
            as OrdinaryPaintPlanReady;
    final ordinaryWritesBeforeSupplement =
        ordinaryPlanner.ordinaryPaintRecordCache.probe.writes;
    final supplementPlanner = SelectedMoveSupplementPlanner(
      frameFacts: scenario.frameFacts,
      queryPaint: (_) => result,
    );

    final supplement = supplementPlanner.build(
      frame: scenario.frame,
      ordinaryPlan: ordinary.plan,
    );

    _expectRejectedAdmissionFallback(
      supplement: supplement,
      ordinary: ordinary.plan,
      reason: reason,
    );
    expect(
      ordinaryPlanner.ordinaryPaintRecordCache.probe.writes,
      ordinaryWritesBeforeSupplement,
    );
  });
}

void _expectRejectedAdmissionFallback({
  required SelectedMoveSupplementPlan supplement,
  required PaintPlan ordinary,
  required FrameSpatialPaintRejectionReason reason,
}) {
  expect(supplement.mergedRecords, orderedEquals(ordinary.ordinaryRecords));
  expect(supplement.mergedRecords.map((record) => record.id), [
    CanvasElementId('a'),
    CanvasElementId('b'),
  ]);
  expect(supplement.probe.selectedFilteredCount, 0);
  expect(supplement.probe.supplementCount, 0);
  expect(supplement.probe.skippedStaleCount, 0);
  expect(supplement.probe.rejectedAdmissionReason, reason);
  expect(supplement.probe.ordinaryCacheWritesDuringSupplement, 0);
}

void _testValidEmptyShiftedAdmission() {
  test(
    'empty shifted candidates are admitted and selected records are filtered',
    () {
      final scenario = _selectedMoveScenario(delta: const Offset(500, 0));
      final ordinaryPlanner = OrdinaryPaintPlanner();
      final ordinary =
          ordinaryPlanner.buildOrdinaryPlan(scenario.frame)
              as OrdinaryPaintPlanReady;
      final supplementPlanner = SelectedMoveSupplementPlanner(
        frameFacts: scenario.frameFacts,
        queryPaint: (_) => const SpatialCandidatesResult(orderedCandidates: []),
      );

      final supplement = supplementPlanner.build(
        frame: scenario.frame,
        ordinaryPlan: ordinary.plan,
      );

      expect(supplement.mergedRecords.map((record) => record.id), [
        CanvasElementId('b'),
      ]);
      expect(supplement.probe.selectedFilteredCount, 1);
      expect(supplement.probe.supplementCount, 0);
      expect(supplement.probe.rejectedAdmissionReason, isNull);
      expect(supplement.probe.ordinaryCacheWritesDuringSupplement, 0);
    },
  );
}

({TestFrameFactsPort frameFacts, CapturedMainFrame frame})
_selectedMoveScenario({Offset delta = const Offset(5, 0)}) {
  final selected = SelectionFacts(
    selectedElementIds: [CanvasElementId('a')],
    selectionRevision: 3,
  );
  final rows = [rectFacts('a', orderToken: 1), rectFacts('b', orderToken: 2)];
  final frameFacts = frameFactsPort(elements: rows);
  final frame = capturedMainFrame(
    frameFacts: frameFacts,
    selectionFacts: selected,
    preview: CanvasSelectedMovePreview(delta: delta),
  );

  return (frameFacts: frameFacts, frame: frame);
}
