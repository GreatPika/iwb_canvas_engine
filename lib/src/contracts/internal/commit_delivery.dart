import '../public/canvas_ids.dart';

final class CommitDeliveryResult {
  CommitDeliveryResult({
    required this.shouldPublishState,
    this.replacedDocument = false,
    Iterable<CommitDeliveryEffect> effects = const [],
  }) : effects = List.unmodifiable(effects);

  final bool shouldPublishState;
  final bool replacedDocument;
  final List<CommitDeliveryEffect> effects;
}

sealed class CommitDeliveryEffect {
  const CommitDeliveryEffect();
}

final class ProjectionDeliveryEffect extends CommitDeliveryEffect {
  const ProjectionDeliveryEffect();
}

final class SpatialDeliveryEffect extends CommitDeliveryEffect {
  const SpatialDeliveryEffect({required this.touchedFacts});

  final CommitDeliveryTouchedFacts touchedFacts;
}

final class ResourceDeliveryEffect extends CommitDeliveryEffect {
  const ResourceDeliveryEffect({required this.touchedFacts});

  final CommitDeliveryTouchedFacts touchedFacts;
}

final class RepaintDeliveryEffect extends CommitDeliveryEffect {
  const RepaintDeliveryEffect({
    required this.mainCanvas,
    this.overlayCanvas = false,
  });

  final bool mainCanvas;
  final bool overlayCanvas;
}

final class SelectionDeliveryEffect extends CommitDeliveryEffect {
  const SelectionDeliveryEffect();
}

final class PublicStateDeliveryEffect extends CommitDeliveryEffect {
  const PublicStateDeliveryEffect();
}

final class CommitDeliveryTouchedFacts {
  CommitDeliveryTouchedFacts({
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
}

typedef CommitEffectObserver =
    void Function(List<CommitDeliveryEffect> effects);

typedef CommitApplyResultDelivery = void Function(CommitDeliveryResult result);
