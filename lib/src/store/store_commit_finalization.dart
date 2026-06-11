import '../contracts/public/canvas_ids.dart';
import 'committed_document.dart';
import 'store_revision_delta.dart';

final class PreparedMaterializedStoreCommit {
  const PreparedMaterializedStoreCommit({
    required this.baseDocument,
    required this.document,
    required this.revisionDelta,
    required this.touchedFacts,
  });

  final CommittedDocument baseDocument;
  final CommittedDocument document;
  final StoreRevisionDelta revisionDelta;
  final AcceptedStoreTouchedFacts touchedFacts;

  bool get hasChanges => revisionDelta.hasChanges;
}

final class AcceptedStoreTouchedFacts {
  AcceptedStoreTouchedFacts({
    Iterable<CanvasElementId> addedElementIds = const [],
    Iterable<CanvasElementId> removedElementIds = const [],
    Iterable<CanvasElementId> updatedElementIds = const [],
    Iterable<CanvasElementId> transformedElementIds = const [],
    Iterable<CanvasElementId> geometryElementIds = const [],
    Iterable<CanvasElementId> visualElementIds = const [],
    Iterable<CanvasResourceId> resourceDescriptorChangedIds = const [],
    Iterable<CanvasResourceId> resourceVisualChangedIds = const [],
    Iterable<CanvasLayerId> layerIds = const [],
    this.backgroundLayerChanged = false,
    this.persistedCamera = false,
    this.background = false,
    this.grid = false,
    this.palette = false,
  }) : addedElementIds = Set.unmodifiable(addedElementIds),
       removedElementIds = Set.unmodifiable(removedElementIds),
       updatedElementIds = Set.unmodifiable(updatedElementIds),
       transformedElementIds = Set.unmodifiable(transformedElementIds),
       geometryElementIds = Set.unmodifiable(geometryElementIds),
       visualElementIds = Set.unmodifiable(visualElementIds),
       resourceDescriptorChangedIds = Set.unmodifiable(
         resourceDescriptorChangedIds,
       ),
       resourceVisualChangedIds = Set.unmodifiable(resourceVisualChangedIds),
       layerIds = Set.unmodifiable(layerIds);

  AcceptedStoreTouchedFacts.empty() : this();

  final Set<CanvasElementId> addedElementIds;
  final Set<CanvasElementId> removedElementIds;
  final Set<CanvasElementId> updatedElementIds;
  final Set<CanvasElementId> transformedElementIds;
  final Set<CanvasElementId> geometryElementIds;
  final Set<CanvasElementId> visualElementIds;
  final Set<CanvasResourceId> resourceDescriptorChangedIds;
  final Set<CanvasResourceId> resourceVisualChangedIds;
  final Set<CanvasLayerId> layerIds;
  final bool backgroundLayerChanged;
  final bool persistedCamera;
  final bool background;
  final bool grid;
  final bool palette;

  bool get hasTouches {
    return [
          addedElementIds,
          removedElementIds,
          updatedElementIds,
          transformedElementIds,
          geometryElementIds,
          visualElementIds,
          resourceDescriptorChangedIds,
          resourceVisualChangedIds,
          layerIds,
        ].any((ids) => ids.isNotEmpty) ||
        [
          backgroundLayerChanged,
          persistedCamera,
          background,
          grid,
          palette,
        ].any((flag) => flag);
  }
}
