import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../contracts/internal/frame_facts_port.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_surface_styles.dart';
import 'captured_frame.dart';
import 'render_element_record.dart';

@immutable
final class SelectionDecorationKey {
  SelectionDecorationKey({
    required this.selectionRevision,
    required Iterable<CanvasElementId> selectedElementIds,
    required this.boundsRevision,
    required this.selectedMoveDelta,
    required this.previewRevision,
    required this.selectionStyle,
    required this.devicePixelRatio,
  }) : selectedElementIds = Set.unmodifiable(selectedElementIds);

  final int selectionRevision;
  final Set<CanvasElementId> selectedElementIds;
  final int boundsRevision;
  final Offset selectedMoveDelta;
  final int previewRevision;
  final CanvasSelectionStyle selectionStyle;
  final double devicePixelRatio;

  @override
  bool operator ==(Object other) {
    return other is SelectionDecorationKey &&
        other.selectionRevision == selectionRevision &&
        setEquals(other.selectedElementIds, selectedElementIds) &&
        other.boundsRevision == boundsRevision &&
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
      boundsRevision,
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

final class SelectionDecorationPrimitive {
  const SelectionDecorationPrimitive({
    required this.boundsWorld,
    required this.color,
    required this.strokeWidth,
    required this.haloWidth,
  });

  final Rect boundsWorld;
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
      primitives: _primitivesFor(frame),
    );
    _current = plan;
    _rebuildCount += 1;

    return plan;
  }

  Iterable<SelectionDecorationPrimitive> _primitivesFor(
    CapturedMainFrame frame,
  ) sync* {
    final selectedIds = frame.snapshot.selection.selectedElementIds;
    final style = frame.snapshot.inputs.selectionStyle;
    for (final facts in frame.snapshot.elements) {
      if (!selectedIds.contains(facts.id)) {
        continue;
      }
      yield SelectionDecorationPrimitive(
        boundsWorld: _selectionDecorationBoundsFor(facts, frame),
        color: style.color,
        strokeWidth: style.strokeWidth,
        haloWidth: style.haloWidth,
      );
    }
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
    boundsRevision: frame.snapshot.revisions.boundsRevision,
    selectedMoveDelta: selectedMovePreview?.delta ?? Offset.zero,
    previewRevision: selectedMovePreview == null
        ? 0
        : frame.snapshot.previewRevision,
    selectionStyle: frame.snapshot.inputs.selectionStyle,
    devicePixelRatio: frame.snapshot.inputs.devicePixelRatio,
  );
}

Rect _selectionDecorationBoundsFor(
  FrameElementFacts facts,
  CapturedMainFrame frame,
) {
  final boundsWorld = RenderElementRecord.fromFacts(facts).paintBoundsWorld;
  final delta = frame.selectedMovePreview?.delta ?? Offset.zero;

  return boundsWorld.shift(delta);
}
