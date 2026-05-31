// This fixture imports the full selected-move staging boundary so stale-row,
// spatial-query, transform, and ordinary-cache probes stay in one proof.
// ignore_for_file: number-of-imports

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/selection_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_geometry.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_ids.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_preview.dart';
import 'package:iwb_canvas_engine/src/frame/ordinary_paint_planner.dart';
import 'package:iwb_canvas_engine/src/frame/selected_move_supplement_planner.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_result.dart';

import 'ordinary_paint_test_support.dart';

// The selected-move staging proof is intentionally end-to-end: splitting the
// assertions would obscure that selected filtering happens after ordinary cache
// lookup and still avoids a global scene sort.
// ignore: halstead-volume, maintainability-index, source-lines-of-code
void main() {
  test('selected move supplement merges by order without ordinary writes', () {
    final selected = SelectionFacts(
      selectedElementIds: [
        CanvasElementId('a'),
        CanvasElementId('c'),
        CanvasElementId('locked'),
        CanvasElementId('stale'),
      ],
      selectionRevision: 3,
    );
    final rows = [
      rectFacts('a', orderToken: 1),
      rectFacts('b', orderToken: 2),
      strokeFacts('c', orderToken: 3, transform: CanvasTransform.scale(2, 2)),
      rectFacts('stale', orderToken: 4),
      rectFacts('locked', orderToken: 5, isLocked: true),
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
    final writesBeforeSupplement = ordinaryPlanner.paintPlanCache.probe.writes;
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
      ordinaryCacheWritesBefore: writesBeforeSupplement,
      ordinaryCacheWritesAfter: ordinaryPlanner.paintPlanCache.probe.writes,
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
  });
}
