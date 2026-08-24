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
  final CanvasLayerId layerId;
  final int elementIndex;
  final int orderToken;

  CanvasElementId get id => element.id;
}

abstract interface class DeletionEntryProjectionPort {
  List<DeletionEntryFacts> projectDeletionEntries(
    Iterable<CanvasElementId> ids,
  );
}
