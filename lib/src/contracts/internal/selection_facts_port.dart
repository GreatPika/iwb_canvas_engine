import '../public/canvas_ids.dart';

final class SelectionFacts {
  SelectionFacts({
    required Iterable<CanvasElementId> selectedElementIds,
    required this.selectionRevision,
  }) : selectedElementIds = Set.unmodifiable(selectedElementIds);

  final Set<CanvasElementId> selectedElementIds;
  final int selectionRevision;
  int get selectedCount => selectedElementIds.length;
}

abstract interface class SelectionFactsPort {
  SelectionFacts get selectionFacts;
}
