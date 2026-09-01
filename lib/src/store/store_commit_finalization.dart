import '../contracts/public/canvas_ids.dart';
import 'committed_document.dart';
import 'id_admission.dart';
import 'store_revision_delta.dart';

/// Internal bounded inputs for Store's materialized final-facts comparison.
///
/// Callers name draft-local mutation candidates only. Store derives and checks
/// the owning content-layer facts against its base and final registries.
final class MaterializedStoreCommitCandidates {
  MaterializedStoreCommitCandidates({
    Iterable<CanvasLayerId> layerIds = const [],
    Iterable<CanvasElementId> addedElementIds = const [],
    Iterable<CanvasElementId> removedElementIds = const [],
  }) : layerIds = Set.unmodifiable(layerIds),
       addedElementIds = Set.unmodifiable(addedElementIds),
       removedElementIds = Set.unmodifiable(removedElementIds);

  final Set<CanvasLayerId> layerIds;
  final Set<CanvasElementId> addedElementIds;
  final Set<CanvasElementId> removedElementIds;

  bool get isEmpty =>
      layerIds.isEmpty && addedElementIds.isEmpty && removedElementIds.isEmpty;
}

final class PreparedMaterializedStoreCommit {
  const PreparedMaterializedStoreCommit({
    required this.baseDocument,
    required this.document,
    required this.revisionDelta,
    required this.touchedFacts,
    this.idAdmissions,
  });

  final CommittedDocument baseDocument;
  final CommittedDocument document;
  final StoreRevisionDelta revisionDelta;
  final AcceptedStoreTouchedFacts touchedFacts;
  final StoreIdAdmissions? idAdmissions;

  bool get hasChanges => revisionDelta.hasChanges;
}

final class AcceptedStoreTouchedFacts {
  AcceptedStoreTouchedFacts({
    Iterable<CanvasElementId> addedElementIds = const [],
    Iterable<CanvasElementId> removedElementIds = const [],
    Iterable<CanvasElementId> updatedElementIds = const [],
    Iterable<CanvasElementId> placementElementIds = const [],
    Iterable<CanvasElementId> transformedElementIds = const [],
    Iterable<CanvasElementId> geometryElementIds = const [],
    Iterable<CanvasElementId> visualElementIds = const [],
    Iterable<CanvasElementId> selectionPruneElementIds = const [],
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
       placementElementIds = Set.unmodifiable(placementElementIds),
       transformedElementIds = Set.unmodifiable(transformedElementIds),
       geometryElementIds = Set.unmodifiable(geometryElementIds),
       visualElementIds = Set.unmodifiable(visualElementIds),
       selectionPruneElementIds = Set.unmodifiable(selectionPruneElementIds),
       resourceDescriptorChangedIds = Set.unmodifiable(
         resourceDescriptorChangedIds,
       ),
       resourceVisualChangedIds = Set.unmodifiable(resourceVisualChangedIds),
       layerIds = Set.unmodifiable(layerIds);

  AcceptedStoreTouchedFacts.empty() : this();

  final Set<CanvasElementId> addedElementIds;
  final Set<CanvasElementId> removedElementIds;
  final Set<CanvasElementId> updatedElementIds;
  final Set<CanvasElementId> placementElementIds;
  final Set<CanvasElementId> transformedElementIds;
  final Set<CanvasElementId> geometryElementIds;
  final Set<CanvasElementId> visualElementIds;
  final Set<CanvasElementId> selectionPruneElementIds;
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
          placementElementIds,
          transformedElementIds,
          geometryElementIds,
          visualElementIds,
          selectionPruneElementIds,
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
