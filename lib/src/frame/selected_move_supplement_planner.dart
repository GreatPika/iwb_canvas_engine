import 'dart:ui';

import '../contracts/internal/frame_facts_port.dart';
import '../contracts/public/canvas_geometry.dart';
import '../contracts/public/canvas_ids.dart';
import '../geometry/spatial_query_policy.dart';
import '../geometry/spatial_query_result.dart';
import 'captured_frame.dart';
import 'paint_plan.dart';
import 'render_element_record.dart';

typedef SelectedMovePaintQuery =
    SpatialQueryResult Function(SpatialQueryWindow);

final class SelectedMoveSupplementProbe {
  const SelectedMoveSupplementProbe({
    required this.selectedFilteredCount,
    required this.supplementCount,
    required this.skippedStaleCount,
    required this.globalSortCount,
    required this.ordinaryCacheWritesDuringSupplement,
  });

  final int selectedFilteredCount;
  final int supplementCount;
  final int skippedStaleCount;
  final int globalSortCount;
  final int ordinaryCacheWritesDuringSupplement;
}

final class SelectedMoveSupplementPlan {
  SelectedMoveSupplementPlan({
    required Iterable<RenderElementRecord> mergedRecords,
    required this.probe,
  }) : mergedRecords = List.unmodifiable(mergedRecords);

  final List<RenderElementRecord> mergedRecords;
  final SelectedMoveSupplementProbe probe;
}

// This planner intentionally coordinates captured frame state, ordinary records,
// spatial candidates, and current committed facts so the selected-supplement
// stage remains visibly outside ordinary cache writes.
// ignore: coupling-between-object-classes
final class SelectedMoveSupplementPlanner {
  SelectedMoveSupplementPlanner({
    required FrameFactsPort frameFacts,
    required SelectedMovePaintQuery queryPaint,
  }) : _frameFacts = frameFacts,
       _queryPaint = queryPaint;

  final FrameFactsPort _frameFacts;
  final SelectedMovePaintQuery _queryPaint;

  SelectedMoveSupplementPlan build({
    required CapturedMainFrame frame,
    required PaintPlan ordinaryPlan,
  }) {
    final preview = frame.selectedMovePreview;
    if (preview == null) {
      return _withoutSelectedMove(ordinaryPlan);
    }

    final selectedIds = _movableSelectedIds(frame);
    final ordinaryRecords = _unselectedOrdinaryRecords(
      ordinaryPlan,
      selectedIds,
    );
    final selectedFilteredCount =
        ordinaryPlan.ordinaryRecords.length - ordinaryRecords.length;
    final supplement = _buildSupplementRecords(
      frame: frame,
      selectedIds: selectedIds,
      delta: preview.delta,
    );
    final descendingOrder = _usesDescendingRecordOrder(
      ordinaryRecords,
      supplement.records,
    );

    return SelectedMoveSupplementPlan(
      mergedRecords: _mergeByOrderToken(
        ordinaryRecords,
        supplement.records,
        descendingOrder: descendingOrder,
      ),
      probe: SelectedMoveSupplementProbe(
        selectedFilteredCount: selectedFilteredCount,
        supplementCount: supplement.records.length,
        skippedStaleCount: supplement.skippedStaleCount,
        globalSortCount: 0,
        ordinaryCacheWritesDuringSupplement: 0,
      ),
    );
  }

  SelectedMoveSupplementPlan _withoutSelectedMove(PaintPlan ordinaryPlan) {
    return SelectedMoveSupplementPlan(
      mergedRecords: ordinaryPlan.ordinaryRecords,
      probe: const SelectedMoveSupplementProbe(
        selectedFilteredCount: 0,
        supplementCount: 0,
        skippedStaleCount: 0,
        globalSortCount: 0,
        ordinaryCacheWritesDuringSupplement: 0,
      ),
    );
  }

  List<RenderElementRecord> _unselectedOrdinaryRecords(
    PaintPlan ordinaryPlan,
    Set<CanvasElementId> selectedIds,
  ) {
    return ordinaryPlan.ordinaryRecords
        .where((record) => !selectedIds.contains(record.id))
        .toList();
  }

  Set<CanvasElementId> _movableSelectedIds(CapturedMainFrame frame) {
    final selectedIds = frame.snapshot.selection.selectedElementIds;

    return {
      for (final facts in frame.snapshot.elements)
        if (selectedIds.contains(facts.id) &&
            facts.isTransformable &&
            !facts.isLocked)
          facts.id,
    };
  }

  _SupplementRecords _buildSupplementRecords({
    required CapturedMainFrame frame,
    required Set<CanvasElementId> selectedIds,
    required Offset delta,
  }) {
    final supplement = <RenderElementRecord>[];
    var skippedStaleCount = 0;
    final spatial = _queryPaint(_shiftedWindow(frame, delta));
    for (final handle in spatial.candidates) {
      if (!selectedIds.contains(handle.id)) {
        continue;
      }
      final facts = _currentFacts(
        handle,
        frame.snapshot.revisions.structuralRevision,
      );
      if (facts == null) {
        skippedStaleCount += 1;
        continue;
      }
      supplement.add(_shiftedRecord(facts, delta));
    }

    return _SupplementRecords(
      records: supplement,
      skippedStaleCount: skippedStaleCount,
    );
  }

  SpatialQueryWindow _shiftedWindow(CapturedMainFrame frame, Offset delta) {
    return SpatialQueryWindow(
      boundsWorld: frame.snapshot.inputs.viewportWorldBounds.shift(-delta),
      structuralRevision: frame.snapshot.revisions.structuralRevision,
    );
  }

  FrameElementFacts? _currentFacts(
    FrameElementHandle handle,
    int structuralRevision,
  ) {
    if (handle.structuralRevision != structuralRevision) {
      return null;
    }
    final facts = _frameFacts.resolveElement(handle);
    if (facts == null ||
        facts.id != handle.id ||
        facts.generation != handle.generation ||
        facts.orderToken != handle.orderToken) {
      return null;
    }

    return facts;
  }

  RenderElementRecord _shiftedRecord(FrameElementFacts facts, Offset delta) {
    final record = RenderElementRecord.fromFacts(facts);
    final shiftedTransform = CanvasTransform.translation(
      delta,
    ).multiply(facts.transform);

    return RenderElementRecord(
      id: record.id,
      family: record.family,
      generation: record.generation,
      orderToken: record.orderToken,
      transform: shiftedTransform,
      opacity: record.opacity,
      primitiveAlpha: record.primitiveAlpha,
      paintBoundsWorld: record.paintBoundsWorld.shift(delta),
      hitBoundsWorld: record.hitBoundsWorld.shift(delta),
      resourceId: record.resourceId,
      row: record.row,
    );
  }

  List<RenderElementRecord> _mergeByOrderToken(
    List<RenderElementRecord> ordinary,
    List<RenderElementRecord> supplement, {
    required bool descendingOrder,
  }) {
    final merged = <RenderElementRecord>[];
    var ordinaryIndex = 0;
    var supplementIndex = 0;
    while (ordinaryIndex < ordinary.length ||
        supplementIndex < supplement.length) {
      if (supplementIndex >= supplement.length ||
          ordinaryIndex < ordinary.length &&
              _ordinaryRecordComesFirst(
                ordinary[ordinaryIndex],
                supplement[supplementIndex],
                descendingOrder,
              )) {
        merged.add(ordinary[ordinaryIndex]);
        ordinaryIndex += 1;
      } else {
        merged.add(supplement[supplementIndex]);
        supplementIndex += 1;
      }
    }

    return merged;
  }
}

bool _ordinaryRecordComesFirst(
  RenderElementRecord ordinary,
  RenderElementRecord supplement,
  bool descendingOrder,
) {
  if (descendingOrder) {
    return ordinary.orderToken >= supplement.orderToken;
  }

  return ordinary.orderToken <= supplement.orderToken;
}

bool _usesDescendingRecordOrder(
  List<RenderElementRecord> ordinary,
  List<RenderElementRecord> supplement,
) {
  return _recordStreamIsDescending(ordinary) ??
      _recordStreamIsDescending(supplement) ??
      true;
}

bool? _recordStreamIsDescending(List<RenderElementRecord> records) {
  RenderElementRecord? previous;
  for (final candidate in records) {
    final before = previous;
    previous = candidate;
    if (before == null || before.orderToken == candidate.orderToken) {
      continue;
    }

    return before.orderToken > candidate.orderToken;
  }

  return null;
}

final class _SupplementRecords {
  _SupplementRecords({
    required Iterable<RenderElementRecord> records,
    required this.skippedStaleCount,
  }) : records = List.unmodifiable(records);

  final List<RenderElementRecord> records;
  final int skippedStaleCount;
}
