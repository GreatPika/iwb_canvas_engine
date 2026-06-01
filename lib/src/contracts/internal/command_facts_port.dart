import 'dart:ui';

import '../public/canvas_actions.dart';
import '../public/canvas_document.dart';
import '../public/canvas_ids.dart';

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
  SelectionDeleteFacts({required Iterable<CanvasElementId> deletableIds})
    : deletableIds = List.unmodifiable(deletableIds);

  final List<CanvasElementId> deletableIds;
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
