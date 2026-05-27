import '../public/canvas_ids.dart';

final class TouchedSet {
  TouchedSet({
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
    this.selection = false,
    this.persistedCamera = false,
    this.background = false,
    this.grid = false,
    this.palette = false,
    this.documentReplaced = false,
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
  final bool selection;
  final bool persistedCamera;
  final bool background;
  final bool grid;
  final bool palette;
  final bool documentReplaced;

  Set<CanvasElementId> get elementIds {
    return Set.unmodifiable({
      ...addedElementIds,
      ...removedElementIds,
      ...updatedElementIds,
      ...transformedElementIds,
      ...geometryElementIds,
      ...visualElementIds,
    });
  }

  Set<CanvasResourceId> get resourceIds {
    return Set.unmodifiable({
      ...resourceDescriptorChangedIds,
      ...resourceVisualChangedIds,
    });
  }

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
          selection,
          backgroundLayerChanged,
          persistedCamera,
          background,
          grid,
          palette,
          documentReplaced,
        ].any((flag) => flag);
  }
}
