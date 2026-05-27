import '../contracts/internal/commit_delivery.dart';
import '../contracts/public/canvas_document.dart';
import '../store/store_revision_delta.dart';
import 'commit_plan.dart';

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
      touchedSet: touchedSet,
    ),
    ResourceEffect(:final touchedSet) => ResourceDeliveryEffect(
      touchedSet: touchedSet,
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
