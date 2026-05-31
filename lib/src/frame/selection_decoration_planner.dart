import 'package:flutter/foundation.dart';

import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_surface_styles.dart';
import 'captured_frame.dart';

@immutable
final class SelectionDecorationKey {
  SelectionDecorationKey({
    required this.selectionRevision,
    required Iterable<CanvasElementId> selectedElementIds,
    required this.boundsRevision,
    required this.selectionStyle,
    required this.devicePixelRatio,
  }) : selectedElementIds = Set.unmodifiable(selectedElementIds);

  final int selectionRevision;
  final Set<CanvasElementId> selectedElementIds;
  final int boundsRevision;
  final CanvasSelectionStyle selectionStyle;
  final double devicePixelRatio;

  @override
  bool operator ==(Object other) {
    return other is SelectionDecorationKey &&
        other.selectionRevision == selectionRevision &&
        setEquals(other.selectedElementIds, selectedElementIds) &&
        other.boundsRevision == boundsRevision &&
        other.selectionStyle == selectionStyle &&
        other.devicePixelRatio == devicePixelRatio;
  }

  @override
  int get hashCode {
    return Object.hash(
      selectionRevision,
      Object.hashAllUnordered(selectedElementIds),
      boundsRevision,
      selectionStyle,
      devicePixelRatio,
    );
  }
}

final class SelectionDecorationPlan {
  SelectionDecorationPlan({required this.key})
    : selectedCount = key.selectedElementIds.length;

  final SelectionDecorationKey key;
  final int selectedCount;
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
    final key = SelectionDecorationKey(
      selectionRevision: frame.snapshot.selection.selectionRevision,
      selectedElementIds: frame.snapshot.selection.selectedElementIds,
      boundsRevision: frame.snapshot.revisions.boundsRevision,
      selectionStyle: frame.snapshot.inputs.selectionStyle,
      devicePixelRatio: frame.snapshot.inputs.devicePixelRatio,
    );
    final current = _current;
    if (current != null && current.key == key) {
      return current;
    }
    final plan = SelectionDecorationPlan(key: key);
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
