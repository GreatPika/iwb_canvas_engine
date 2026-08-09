import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../contracts/internal/frame_facts_port.dart';
import '../contracts/internal/text_edit_paint_suppression.dart';
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
    required this.hiddenForSelectedMovePreview,
    required this.textEditSuppression,
    required this.selectionStyle,
    required this.devicePixelRatio,
  }) : selectedElementIds = Set.unmodifiable(selectedElementIds);

  final int selectionRevision;
  final Set<CanvasElementId> selectedElementIds;
  final int structuralRevision;
  final int boundsRevision;
  final bool hiddenForSelectedMovePreview;
  final TextEditPaintSuppression? textEditSuppression;
  final CanvasSelectionStyle selectionStyle;
  final double devicePixelRatio;

  @override
  bool operator ==(Object other) {
    return other is SelectionDecorationKey &&
        other.selectionRevision == selectionRevision &&
        setEquals(other.selectedElementIds, selectedElementIds) &&
        other.structuralRevision == structuralRevision &&
        other.boundsRevision == boundsRevision &&
        other.hiddenForSelectedMovePreview == hiddenForSelectedMovePreview &&
        other.textEditSuppression == textEditSuppression &&
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
      hiddenForSelectedMovePreview,
      textEditSuppression,
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

enum SelectionDecorationStrokePlacement { outsideBox, boundsOutline }

final class SelectionDecorationPrimitive {
  const SelectionDecorationPrimitive({
    required this.boundsWorld,
    required this.selectedElementCount,
    required this.chromeForm,
    required this.strokePlacement,
    required this.color,
    required this.strokeWidth,
    required this.haloWidth,
  });

  final Rect boundsWorld;
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
  return SelectionDecorationKey(
    selectionRevision: frame.snapshot.selection.selectionRevision,
    selectedElementIds: frame.snapshot.selection.selectedElementIds,
    structuralRevision: frame.snapshot.revisions.structuralRevision,
    boundsRevision: frame.snapshot.revisions.boundsRevision,
    hiddenForSelectedMovePreview: frame.selectedMovePreview != null,
    textEditSuppression: frame.snapshot.inputs.textEditSuppression,
    selectionStyle: frame.snapshot.inputs.selectionStyle,
    devicePixelRatio: frame.snapshot.inputs.devicePixelRatio,
  );
}

Iterable<SelectionDecorationPrimitive> _selectionDecorationPrimitivesFor(
  CapturedMainFrame frame,
) {
  if (frame.selectedMovePreview != null) {
    return const [];
  }
  final style = frame.snapshot.inputs.selectionStyle;
  final selectedRecords = _selectedRenderRecords(frame);
  if (selectedRecords.isEmpty) {
    return const [];
  }
  if (selectedRecords.length == 1) {
    final record = selectedRecords.single;

    return [
      SelectionDecorationPrimitive(
        boundsWorld: _selectionDecorationBoundsFor(record),
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
      boundsWorld: _unionSelectionDecorationBounds(selectedRecords),
      selectedElementCount: selectedRecords.length,
      chromeForm: SelectionDecorationChromeForm.groupBox,
      strokePlacement: SelectionDecorationStrokePlacement.outsideBox,
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
    if (_isSuppressedTextEdit(facts, frame)) {
      continue;
    }
    records.add(RenderElementRecord.fromFacts(facts));
  }

  return records;
}

bool _isSuppressedTextEdit(FrameElementFacts facts, CapturedMainFrame frame) {
  return frame.snapshot.inputs.textEditSuppression?.matchesTextElement(
        id: facts.id,
        kind: facts.kind,
        revision: facts.revision,
        generation: facts.generation,
      ) ??
      false;
}

Rect _selectionDecorationBoundsFor(RenderElementRecord record) {
  return record.paintBoundsWorld;
}

Rect _unionSelectionDecorationBounds(List<RenderElementRecord> records) {
  var bounds = _selectionDecorationBoundsFor(records.first);
  for (final record in records.skip(1)) {
    bounds = bounds.expandToInclude(_selectionDecorationBoundsFor(record));
  }

  return bounds;
}

SelectionDecorationStrokePlacement _strokePlacementFor(
  RenderElementFamily family,
) {
  return switch (family) {
    RenderElementFamily.image ||
    RenderElementFamily.vector ||
    RenderElementFamily.rect => SelectionDecorationStrokePlacement.outsideBox,
    RenderElementFamily.line ||
    RenderElementFamily.path ||
    RenderElementFamily.stroke ||
    RenderElementFamily.text =>
      SelectionDecorationStrokePlacement.boundsOutline,
  };
}
