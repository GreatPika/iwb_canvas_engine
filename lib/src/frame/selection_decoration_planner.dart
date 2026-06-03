import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_surface_styles.dart';
import 'captured_frame.dart';
import 'render_element_record.dart';

@immutable
final class SelectionDecorationKey {
  SelectionDecorationKey({
    required this.selectionRevision,
    required Iterable<CanvasElementId> selectedElementIds,
    required this.structuralRevision,
    required this.boundsRevision,
    required this.selectedTopOrderToken,
    required this.selectedMoveDelta,
    required this.previewRevision,
    required this.selectionStyle,
    required this.devicePixelRatio,
  }) : selectedElementIds = Set.unmodifiable(selectedElementIds);

  final int selectionRevision;
  final Set<CanvasElementId> selectedElementIds;
  final int structuralRevision;
  final int boundsRevision;
  final int? selectedTopOrderToken;
  final Offset selectedMoveDelta;
  final int previewRevision;
  final CanvasSelectionStyle selectionStyle;
  final double devicePixelRatio;

  @override
  bool operator ==(Object other) {
    return other is SelectionDecorationKey &&
        other.selectionRevision == selectionRevision &&
        setEquals(other.selectedElementIds, selectedElementIds) &&
        other.structuralRevision == structuralRevision &&
        other.boundsRevision == boundsRevision &&
        other.selectedTopOrderToken == selectedTopOrderToken &&
        other.selectedMoveDelta == selectedMoveDelta &&
        other.previewRevision == previewRevision &&
        other.selectionStyle == selectionStyle &&
        other.devicePixelRatio == devicePixelRatio;
  }

  @override
  int get hashCode {
    return Object.hash(
      selectionRevision,
      Object.hashAllUnordered(selectedElementIds),
      structuralRevision,
      boundsRevision,
      selectedTopOrderToken,
      selectedMoveDelta,
      previewRevision,
      selectionStyle,
      devicePixelRatio,
    );
  }
}

final class SelectionDecorationPlan {
  SelectionDecorationPlan({
    required this.key,
    required Iterable<SelectionDecorationPrimitive> primitives,
  }) : primitives = List.unmodifiable(primitives),
       selectedCount = key.selectedElementIds.length;

  final SelectionDecorationKey key;
  final List<SelectionDecorationPrimitive> primitives;
  final int selectedCount;
}

enum SelectionDecorationChromeForm { singleElement, groupBox }

enum SelectionDecorationStrokePlacement { insideBox, boundsOutline }

final class SelectionDecorationPrimitive {
  const SelectionDecorationPrimitive({
    required this.boundsWorld,
    required this.paintOrderToken,
    required this.selectedElementCount,
    required this.chromeForm,
    required this.strokePlacement,
    required this.color,
    required this.strokeWidth,
    required this.haloWidth,
  });

  final Rect boundsWorld;
  final int paintOrderToken;
  final int selectedElementCount;
  final SelectionDecorationChromeForm chromeForm;
  final SelectionDecorationStrokePlacement strokePlacement;
  final Color color;
  final double strokeWidth;
  final double haloWidth;
}

final class SelectionDecorationProbe {
  const SelectionDecorationProbe({
    required this.selectedCount,
    required this.rebuildCount,
  });

  final int selectedCount;
  final int rebuildCount;
}

final class SelectionDecorationPlanner {
  SelectionDecorationPlan? _current;
  int _rebuildCount = 0;

  SelectionDecorationPlan build(CapturedMainFrame frame) {
    final key = _selectionDecorationKeyFor(frame);
    final current = _current;
    if (current != null && current.key == key) {
      return current;
    }
    final plan = SelectionDecorationPlan(
      key: key,
      primitives: _selectionDecorationPrimitivesFor(frame),
    );
    _current = plan;
    _rebuildCount += 1;

    return plan;
  }

  SelectionDecorationProbe get probe {
    return SelectionDecorationProbe(
      selectedCount: _current?.selectedCount ?? 0,
      rebuildCount: _rebuildCount,
    );
  }
}

SelectionDecorationKey _selectionDecorationKeyFor(CapturedMainFrame frame) {
  final selectedMovePreview = frame.selectedMovePreview;

  return SelectionDecorationKey(
    selectionRevision: frame.snapshot.selection.selectionRevision,
    selectedElementIds: frame.snapshot.selection.selectedElementIds,
    structuralRevision: frame.snapshot.revisions.structuralRevision,
    boundsRevision: frame.snapshot.revisions.boundsRevision,
    selectedTopOrderToken: _selectedTopOrderToken(frame),
    selectedMoveDelta: selectedMovePreview?.delta ?? Offset.zero,
    previewRevision: selectedMovePreview == null
        ? 0
        : frame.snapshot.previewRevision,
    selectionStyle: frame.snapshot.inputs.selectionStyle,
    devicePixelRatio: frame.snapshot.inputs.devicePixelRatio,
  );
}

Iterable<SelectionDecorationPrimitive> _selectionDecorationPrimitivesFor(
  CapturedMainFrame frame,
) {
  final style = frame.snapshot.inputs.selectionStyle;
  final selectedRecords = _selectedRenderRecords(frame);
  if (selectedRecords.isEmpty) {
    return const [];
  }
  if (selectedRecords.length == 1) {
    final record = selectedRecords.single;

    return [
      SelectionDecorationPrimitive(
        boundsWorld: _selectionDecorationBoundsFor(record, frame),
        paintOrderToken: record.orderToken,
        selectedElementCount: 1,
        chromeForm: SelectionDecorationChromeForm.singleElement,
        strokePlacement: _strokePlacementFor(record.family),
        color: style.color,
        strokeWidth: style.strokeWidth,
        haloWidth: style.haloWidth,
      ),
    ];
  }

  return [
    SelectionDecorationPrimitive(
      boundsWorld: _unionSelectionDecorationBounds(selectedRecords, frame),
      paintOrderToken: _topOrderToken(selectedRecords),
      selectedElementCount: selectedRecords.length,
      chromeForm: SelectionDecorationChromeForm.groupBox,
      strokePlacement: SelectionDecorationStrokePlacement.insideBox,
      color: style.color,
      strokeWidth: style.strokeWidth,
      haloWidth: style.haloWidth,
    ),
  ];
}

List<RenderElementRecord> _selectedRenderRecords(CapturedMainFrame frame) {
  final selectedIds = frame.snapshot.selection.selectedElementIds;
  final records = <RenderElementRecord>[];
  for (final facts in frame.snapshot.elements) {
    if (!selectedIds.contains(facts.id)) {
      continue;
    }
    records.add(RenderElementRecord.fromFacts(facts));
  }

  return records;
}

Rect _selectionDecorationBoundsFor(
  RenderElementRecord record,
  CapturedMainFrame frame,
) {
  final delta = frame.selectedMovePreview?.delta ?? Offset.zero;

  return record.paintBoundsWorld.shift(delta);
}

Rect _unionSelectionDecorationBounds(
  List<RenderElementRecord> records,
  CapturedMainFrame frame,
) {
  var bounds = _selectionDecorationBoundsFor(records.first, frame);
  for (final record in records.skip(1)) {
    bounds = bounds.expandToInclude(
      _selectionDecorationBoundsFor(record, frame),
    );
  }

  return bounds;
}

SelectionDecorationStrokePlacement _strokePlacementFor(
  RenderElementFamily family,
) {
  return switch (family) {
    RenderElementFamily.image ||
    RenderElementFamily.rect => SelectionDecorationStrokePlacement.insideBox,
    RenderElementFamily.line ||
    RenderElementFamily.path ||
    RenderElementFamily.stroke ||
    RenderElementFamily.text =>
      SelectionDecorationStrokePlacement.boundsOutline,
  };
}

int _selectedTopOrderToken(CapturedMainFrame frame) {
  return _topOrderToken([
    for (final facts in frame.snapshot.elements)
      if (frame.snapshot.selection.selectedElementIds.contains(facts.id))
        RenderElementRecord.fromFacts(facts),
  ]);
}

int _topOrderToken(Iterable<RenderElementRecord> records) {
  int? topOrderToken;
  for (final record in records) {
    final orderToken = record.orderToken;
    topOrderToken = topOrderToken == null
        ? orderToken
        : (topOrderToken > orderToken ? topOrderToken : orderToken);
  }

  return topOrderToken ?? 0;
}
