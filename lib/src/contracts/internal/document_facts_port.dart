import '../public/canvas_ids.dart';

final class DocumentFacts {
  DocumentFacts({
    required this.elementCount,
    required this.layerCount,
    required this.resourceCount,
    required this.documentRevision,
    required this.structuralRevision,
    required Iterable<CanvasElementId> contentElementIds,
    required Iterable<CanvasElementId> selectableElementIds,
  }) : contentElementIds = Set.unmodifiable(contentElementIds),
       selectableElementIds = Set.unmodifiable(selectableElementIds);

  final int elementCount;
  final int layerCount;
  final int resourceCount;
  final int documentRevision;
  final int structuralRevision;
  final Set<CanvasElementId> contentElementIds;
  final Set<CanvasElementId> selectableElementIds;
}

abstract interface class DocumentFactsPort {
  DocumentFacts get documentFacts;
}
