import '../contracts/internal/commit_delivery.dart';
import '../contracts/public/canvas_document.dart';
import '../store/store_revision_delta.dart';
import 'commit_plan.dart';
import 'touched_set.dart';

typedef DocumentInstall =
    void Function(CanvasDocument document, StoreRevisionDelta delta);
typedef DocumentReplace =
    void Function(CanvasDocument document, StoreRevisionDelta delta);
typedef SelectionEffectInstall = bool Function();

final class CommitDocumentInstallers {
  const CommitDocumentInstallers({
    required this.installDocument,
    required this.replaceDocument,
  });

  final DocumentInstall installDocument;
  final DocumentReplace replaceDocument;
}

final class CommitApplier {
  const CommitApplier();

  CommitDeliveryResult apply({
    required CanvasDocument document,
    required CommitPlan plan,
    required CommitDocumentInstallers documentInstallers,
    required SelectionEffectInstall installSelectionEffects,
  }) {
    if (!plan.hasChanges) {
      return CommitDeliveryResult(shouldPublishState: false);
    }

    if (plan.documentReplaced) {
      documentInstallers.replaceDocument(document, plan.revisionDelta);
    } else {
      documentInstallers.installDocument(document, plan.revisionDelta);
    }
    final didChangeSelection =
        plan.touchedSet.selection && installSelectionEffects();

    return CommitDeliveryResult(
      shouldPublishState: plan.revisionDelta.document || didChangeSelection,
      replacedDocument: plan.documentReplaced,
      effects: _deliveryEffectsFor(plan.effects),
    );
  }
}

List<CommitDeliveryEffect> _deliveryEffectsFor(List<CommitEffect> effects) {
  return List.unmodifiable(effects.map(_deliveryEffectFor));
}

CommitDeliveryEffect _deliveryEffectFor(CommitEffect effect) {
  return switch (effect) {
    ProjectionEffect() => const ProjectionDeliveryEffect(),
    SpatialEffect(:final touchedSet) => SpatialDeliveryEffect(
      touchedFacts: _deliveryTouchedFacts(touchedSet),
    ),
    ResourceEffect(:final touchedSet) => ResourceDeliveryEffect(
      touchedFacts: _deliveryTouchedFacts(touchedSet),
    ),
    RepaintEffect(:final mainCanvas, :final overlayCanvas) =>
      RepaintDeliveryEffect(
        mainCanvas: mainCanvas,
        overlayCanvas: overlayCanvas,
      ),
    SelectionEffect() => const SelectionDeliveryEffect(),
    PublicStateEffect() => const PublicStateDeliveryEffect(),
  };
}

CommitDeliveryTouchedFacts _deliveryTouchedFacts(TouchedSet touchedSet) {
  return CommitDeliveryTouchedFacts(
    addedElementIds: touchedSet.addedElementIds,
    removedElementIds: touchedSet.removedElementIds,
    updatedElementIds: touchedSet.updatedElementIds,
    transformedElementIds: touchedSet.transformedElementIds,
    geometryElementIds: touchedSet.geometryElementIds,
    visualElementIds: touchedSet.visualElementIds,
    resourceDescriptorChangedIds: touchedSet.resourceDescriptorChangedIds,
    resourceVisualChangedIds: touchedSet.resourceVisualChangedIds,
    layerIds: touchedSet.layerIds,
    backgroundLayerChanged: touchedSet.backgroundLayerChanged,
    selection: touchedSet.selection,
    persistedCamera: touchedSet.persistedCamera,
    background: touchedSet.background,
    grid: touchedSet.grid,
    palette: touchedSet.palette,
    documentReplaced: touchedSet.documentReplaced,
  );
}
