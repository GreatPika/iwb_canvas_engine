import '../public/canvas_element.dart';
import '../public/canvas_ids.dart';

// Store-owned deletion facts cross runtime and interaction boundaries without
// exposing Store rows, mutable tables, or a public document projection.
final class DeletionEntryFacts {
  const DeletionEntryFacts({
    required this.element,
    required this.layerId,
    required this.elementIndex,
    required this.orderToken,
  });

  final CanvasElement element;
  final CanvasLayerId? layerId;
  final int elementIndex;
  final int orderToken;

  CanvasElementId get id => element.id;
}

// This value owns the immutable result of one Store projection. Downstream
// deletion routes may retain [entries] without another copy or a mutable-list
// trust convention.
final class DeletionEntryProjection {
  DeletionEntryProjection(Iterable<DeletionEntryFacts> entries)
    : entries = List.unmodifiable(entries);

  const DeletionEntryProjection.empty() : entries = const [];

  final List<DeletionEntryFacts> entries;
}

abstract interface class DeletionEntryProjectionPort {
  DeletionEntryProjection projectDeletionEntries(Iterable<CanvasElementId> ids);
}
