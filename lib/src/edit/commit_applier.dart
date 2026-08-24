import 'dart:async';

import '../contracts/internal/commit_delivery.dart';
import '../contracts/internal/commit_action_intent.dart';
import '../contracts/internal/prepared_selection_effect.dart';
import '../contracts/public/canvas_document.dart';
import '../store/committed_document.dart';
import '../store/sparse_store_commit.dart';
import '../store/store_commit_finalization.dart';
import '../store/store_revision_delta.dart';
import 'commit_plan.dart';

typedef DocumentInstall =
    void Function(CommittedDocument document, StoreRevisionDelta delta);
typedef DocumentReplace =
    void Function(CommittedDocument document, StoreRevisionDelta delta);
typedef SparseDocumentInstall = void Function(PreparedSparseStoreCommit commit);
typedef PreparedMaterializedDocumentInstall =
    void Function(PreparedMaterializedStoreCommit commit);
typedef SelectionEffectPrepare =
    PreparedSelectionEffect Function(
      CommitSelectionEffect effect,
      PreparedCommitDocument document,
    );
typedef SelectionEffectInstall = bool Function(PreparedSelectionEffect effect);

final class CommitDocumentInstallers {
  const CommitDocumentInstallers({
    required this.installDocument,
    required this.replaceDocument,
    required this.installSparseCommit,
    required this.installPreparedMaterializedCommit,
  });

  final DocumentInstall installDocument;
  final DocumentReplace replaceDocument;
  final SparseDocumentInstall installSparseCommit;
  final PreparedMaterializedDocumentInstall installPreparedMaterializedCommit;
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

final class AcceptedMaterializedStoreDocument extends AcceptedCommitDocument {
  AcceptedMaterializedStoreDocument({required this.commit})
    : super(revisionDelta: commit.revisionDelta);

  final PreparedMaterializedStoreCommit commit;
}

final class AcceptedUnchangedStoreDocument extends AcceptedCommitDocument {
  const AcceptedUnchangedStoreDocument()
    : super(revisionDelta: const StoreRevisionDelta());
}

sealed class PreparedCommitDocument {
  const PreparedCommitDocument({required this.revisionDelta});

  final StoreRevisionDelta revisionDelta;
}

final class PreparedMaterializedDocument extends PreparedCommitDocument {
  const PreparedMaterializedDocument({
    required this.document,
    required super.revisionDelta,
  });

  final CommittedDocument document;
}

final class PreparedSparseStoreDocument extends PreparedCommitDocument {
  PreparedSparseStoreDocument({required this.commit})
    : super(revisionDelta: commit.revisionDelta);

  final PreparedSparseStoreCommit commit;
}

final class PreparedMaterializedStoreDocument extends PreparedCommitDocument {
  PreparedMaterializedStoreDocument({required this.commit})
    : super(revisionDelta: commit.revisionDelta);

  final PreparedMaterializedStoreCommit commit;
}

final class PreparedUnchangedStoreDocument extends PreparedCommitDocument {
  const PreparedUnchangedStoreDocument()
    : super(revisionDelta: const StoreRevisionDelta());
}

final class CommitApplier {
  const CommitApplier();

  static final Object _deliveryEffectPreparationZoneKey = Object();

  // This test-only observer is assert-gated at the real effect sealing pass,
  // so release commits neither read Zone state nor retain preparation traces.
  static T observeDeliveryEffectPreparation<T>(
    void Function() sink,
    T Function() operation,
  ) => runZoned(
    operation,
    zoneValues: {_deliveryEffectPreparationZoneKey: sink},
  );

  CommitDeliveryResult apply({
    required AcceptedCommitDocument document,
    required CommitPlan plan,
    required CommitDocumentInstallers documentInstallers,
    required CommitSelectionInstallers selectionInstallers,
  }) {
    if (!plan.hasChanges) {
      return CommitDeliveryResult(shouldPublishState: false);
    }

    final state = _PreparedApplyState.prepare(
      document: document,
      plan: plan,
      prepareSelectionEffect: selectionInstallers.prepareSelectionEffect,
    );
    if (state.installsDocument) {
      _installPreparedDocument(
        state.document,
        documentReplaced: state.documentReplaced,
        documentInstallers: documentInstallers,
      );
    }
    final didChangeSelection = _installSelectionEffect(
      state.selectionEffect,
      selectionInstallers.installSelectionEffect,
    );
    return state.resultFor(didChangeSelection: didChangeSelection);
  }
}

void _installPreparedDocument(
  PreparedCommitDocument document, {
  required bool documentReplaced,
  required CommitDocumentInstallers documentInstallers,
}) {
  switch (document) {
    case PreparedMaterializedDocument(:final document, :final revisionDelta):
      if (documentReplaced) {
        documentInstallers.replaceDocument(document, revisionDelta);
      } else {
        documentInstallers.installDocument(document, revisionDelta);
      }
    case PreparedSparseStoreDocument():
      documentInstallers.installSparseCommit(document.commit);
    case PreparedMaterializedStoreDocument(:final commit):
      documentInstallers.installPreparedMaterializedCommit(commit);
    case PreparedUnchangedStoreDocument():
      break;
  }
}

final class _PreparedApplyState {
  _PreparedApplyState({
    required this.document,
    required this.installsDocument,
    required this.documentRevisionChanged,
    required this.documentReplaced,
    required this.deliveryEffects,
    required this.actionIntents,
    required this.selectionEffect,
  });

  factory _PreparedApplyState.prepare({
    required AcceptedCommitDocument document,
    required CommitPlan plan,
    required SelectionEffectPrepare prepareSelectionEffect,
  }) {
    final preparedDocument = _prepareDocument(document);
    final deliveryEffects = _deliveryEffectsFor(plan.effects);
    final actionIntents = plan.actionIntents;
    final selectionEffect = switch (plan.selectionEffect) {
      null => null,
      final effect => prepareSelectionEffect(effect, preparedDocument),
    };

    return _PreparedApplyState(
      document: preparedDocument,
      installsDocument: plan.revisionDelta.hasChanges,
      documentRevisionChanged: plan.revisionDelta.document,
      documentReplaced: plan.documentReplaced,
      deliveryEffects: deliveryEffects,
      actionIntents: actionIntents,
      selectionEffect: selectionEffect,
    );
  }

  final PreparedCommitDocument document;
  final bool installsDocument;
  final bool documentRevisionChanged;
  final bool documentReplaced;
  final List<CommitDeliveryEffect> deliveryEffects;
  final List<CommitActionIntent> actionIntents;
  final PreparedSelectionEffect? selectionEffect;

  CommitDeliveryResult resultFor({required bool didChangeSelection}) {
    final didAcceptChange = installsDocument || didChangeSelection;
    final shouldPublishState = documentRevisionChanged || didChangeSelection;
    if (!didAcceptChange) {
      return CommitDeliveryResult(shouldPublishState: false);
    }

    return CommitDeliveryResult.sealed(
      shouldPublishState: shouldPublishState,
      replacedDocument: documentReplaced,
      effects: deliveryEffects,
      actionIntents: shouldPublishState ? actionIntents : const [],
    );
  }
}

PreparedCommitDocument _prepareDocument(AcceptedCommitDocument document) {
  return switch (document) {
    AcceptedMaterializedDocument(:final document, :final revisionDelta) =>
      PreparedMaterializedDocument(
        document: CommittedDocument(document),
        revisionDelta: revisionDelta,
      ),
    AcceptedSparseStoreDocument(:final commit) => PreparedSparseStoreDocument(
      commit: commit,
    ),
    AcceptedMaterializedStoreDocument(:final commit) =>
      PreparedMaterializedStoreDocument(commit: commit),
    AcceptedUnchangedStoreDocument() => const PreparedUnchangedStoreDocument(),
  };
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
  _recordDeliveryEffectPreparation();

  return List.unmodifiable(
    effects.map((effect) {
      return _deliveryEffectFor(effect);
    }),
  );
}

void _recordDeliveryEffectPreparation() {
  assert(() {
    final sink = Zone.current[CommitApplier._deliveryEffectPreparationZoneKey];
    if (sink is void Function()) {
      sink();
    }
    return true;
  }(), 'delivery effect preparation observation failed');
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
