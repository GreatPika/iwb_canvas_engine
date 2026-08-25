import 'dart:ui';

import '../public/canvas_actions.dart';
import '../public/canvas_document.dart';
import '../public/canvas_deletion.dart';
import '../public/canvas_ids.dart';
import 'deletion_entry_projection_port.dart';

abstract interface class CommandFactsPort {
  SelectionTransformFacts selectionTransformFacts();
  SelectionDeleteFacts selectionDeleteFacts();
  RemoveElementFacts removeElementFacts(CanvasElementId id);
  ClearContentFacts clearContentFacts({required bool removeUnusedResources});
}

final class SelectionTransformFacts {
  SelectionTransformFacts({
    required Iterable<CanvasElementId> selectedIds,
    required Iterable<CanvasElementRead> movableElements,
    required this.selectionBoundsWorld,
  }) : selectedIds = List.unmodifiable(selectedIds),
       movableElements = List.unmodifiable(movableElements);

  final List<CanvasElementId> selectedIds;
  final List<CanvasElementRead> movableElements;
  final Rect selectionBoundsWorld;
}

final class SelectionDeleteFacts {
  SelectionDeleteFacts({
    required this.hasSelection,
    required this.allSelectedElementsDeletable,
    required Iterable<DeletionEntryFacts> deletableEntries,
  }) : deletableEntries = List.unmodifiable(deletableEntries);

  final bool hasSelection;
  final bool allSelectedElementsDeletable;
  final List<DeletionEntryFacts> deletableEntries;

  List<CanvasElementId> get deletableIds =>
      List.unmodifiable(deletableEntries.map((entry) => entry.id));

  CanvasSelectionDeleteAvailability get availability {
    return CanvasSelectionDeleteAvailability(
      hasSelection: hasSelection,
      allSelectedElementsDeletable: allSelectedElementsDeletable,
    );
  }

  List<CanvasElementId> removalIdsFor(CanvasSelectionDeletePolicy policy) {
    return List.unmodifiable(
      removalEntriesFor(policy).map((entry) => entry.id),
    );
  }

  List<DeletionEntryFacts> removalEntriesFor(
    CanvasSelectionDeletePolicy policy,
  ) {
    return switch (policy) {
      CanvasSelectionDeletePolicy.partial => deletableEntries,
      CanvasSelectionDeletePolicy.allOrNone =>
        allSelectedElementsDeletable ? deletableEntries : const [],
    };
  }
}

final class RemoveElementFacts {
  const RemoveElementFacts({required this.canRemove});

  final bool canRemove;
}

final class ClearContentFacts {
  ClearContentFacts({
    required this.summary,
    required Iterable<CanvasElementId> removableElementIds,
    required Iterable<CanvasResourceId> removableResourceIds,
  }) : removableElementIds = List.unmodifiable(removableElementIds),
       removableResourceIds = List.unmodifiable(removableResourceIds);

  final CanvasDocumentSummary summary;
  final List<CanvasElementId> removableElementIds;
  final List<CanvasResourceId> removableResourceIds;
}
