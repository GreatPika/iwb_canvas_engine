import '../contracts/internal/commit_delivery.dart';
import '../contracts/internal/prepared_selection_effect.dart';
import '../contracts/public/canvas_document.dart';
import '../store/sparse_store_commit.dart';
import '../store/store_revision_delta.dart';
import 'commit_plan.dart';

typedef DocumentInstall =
    void Function(CanvasDocument document, StoreRevisionDelta delta);
typedef DocumentReplace =
    void Function(CanvasDocument document, StoreRevisionDelta delta);
typedef SparseDocumentInstall = void Function(PreparedSparseStoreCommit commit);
typedef SelectionEffectPrepare =
    PreparedSelectionEffect Function(
      CommitSelectionEffect effect,
      AcceptedCommitDocument document,
    );
typedef SelectionEffectInstall = bool Function(PreparedSelectionEffect effect);

final class CommitDocumentInstallers {
  const CommitDocumentInstallers({
    required this.installDocument,
    required this.replaceDocument,
    required this.installSparseCommit,
  });

  final DocumentInstall installDocument;
  final DocumentReplace replaceDocument;
  final SparseDocumentInstall installSparseCommit;
}

final class CommitSelectionInstallers {
  const CommitSelectionInstallers({
    required this.prepareSelectionEffect,
    required this.installSelectionEffect,
  });

  final SelectionEffectPrepare prepareSelectionEffect;
  final SelectionEffectInstall installSelectionEffect;
}

sealed class AcceptedCommitDocument {
  const AcceptedCommitDocument({required this.revisionDelta});

  final StoreRevisionDelta revisionDelta;
}

final class AcceptedMaterializedDocument extends AcceptedCommitDocument {
  const AcceptedMaterializedDocument({
    required this.document,
    required super.revisionDelta,
  });

  final CanvasDocument document;
}

final class AcceptedSparseStoreDocument extends AcceptedCommitDocument {
  AcceptedSparseStoreDocument({required this.commit})
    : super(revisionDelta: commit.revisionDelta);

  final PreparedSparseStoreCommit commit;
}

final class AcceptedUnchangedStoreDocument extends AcceptedCommitDocument {
  const AcceptedUnchangedStoreDocument()
    : super(revisionDelta: const StoreRevisionDelta());
}

final class CommitApplier {
  const CommitApplier();

  CommitDeliveryResult apply({
    required AcceptedCommitDocument document,
    required CommitPlan plan,
    required CommitDocumentInstallers documentInstallers,
    required CommitSelectionInstallers selectionInstallers,
  }) {
    if (!plan.hasChanges) {
      return CommitDeliveryResult(shouldPublishState: false);
    }

    final preparedSelectionEffect = _prepareSelectionEffect(
      plan.selectionEffect,
      document,
      selectionInstallers.prepareSelectionEffect,
    );
    if (plan.revisionDelta.hasChanges) {
      _installAcceptedDocument(
        document,
        plan: plan,
        documentInstallers: documentInstallers,
      );
    }
    final didChangeSelection = _installSelectionEffect(
      preparedSelectionEffect,
      selectionInstallers.installSelectionEffect,
    );
    final didAcceptChange = plan.revisionDelta.hasChanges || didChangeSelection;
    final shouldPublishState =
        plan.revisionDelta.document || didChangeSelection;

    return CommitDeliveryResult(
      shouldPublishState: shouldPublishState,
      replacedDocument: plan.documentReplaced,
      effects: didAcceptChange ? _deliveryEffectsFor(plan.effects) : const [],
      actionIntents: shouldPublishState ? plan.actionIntents : const [],
    );
  }
}

void _installAcceptedDocument(
  AcceptedCommitDocument document, {
  required CommitPlan plan,
  required CommitDocumentInstallers documentInstallers,
}) {
  switch (document) {
    case AcceptedMaterializedDocument(:final document, :final revisionDelta):
      if (plan.documentReplaced) {
        documentInstallers.replaceDocument(document, revisionDelta);
      } else {
        documentInstallers.installDocument(document, revisionDelta);
      }
    case AcceptedSparseStoreDocument():
      documentInstallers.installSparseCommit(document.commit);
    case AcceptedUnchangedStoreDocument():
      break;
  }
}

PreparedSelectionEffect? _prepareSelectionEffect(
  CommitSelectionEffect? effect,
  AcceptedCommitDocument document,
  SelectionEffectPrepare prepare,
) {
  if (effect == null) {
    return null;
  }

  return prepare(effect, document);
}

bool _installSelectionEffect(
  PreparedSelectionEffect? effect,
  SelectionEffectInstall install,
) {
  if (effect == null) {
    return false;
  }

  return install(effect);
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
