import 'internal/selection_normalizer.dart';
import 'mutation_commit_preparer.dart';
import 'committed_store_state.dart';
import '../core/revision_policy.dart';
import 'change_set.dart';
import 'store.dart';
import 'txn_context.dart';

List<String> normalizeControllerCommitInputs({required TxnContext ctx}) {
  final selectionNormalizer = SelectionNormalizer();
  var commitPhases = const <String>[];

  final shouldNormalizeSelection =
      ctx.changeSet.selectionChanged ||
      ctx.changeSet.structuralChanged ||
      ctx.changeSet.documentReplaced;
  if (shouldNormalizeSelection) {
    final selectionResult = selectionNormalizer.writeNormalizeSelection(
      rawSelection: ctx.workingSelection,
      scene: ctx.workingScene,
      nodeLocator: ctx.txnNodeLocatorView(),
    );
    commitPhases = <String>[...commitPhases, 'selection'];
    if (selectionResult.normalizedChanged) {
      ctx.changeSet.txnMarkSelectionChanged();
    }
    if (!identical(selectionResult.normalized, ctx.workingSelection)) {
      ctx.workingSelection
        ..clear()
        ..addAll(selectionResult.normalized);
    }
  }

  return commitPhases;
}

ControllerCommitPlan buildControllerCommitPlan({
  required TxnContext ctx,
  required SceneStore store,
  required List<String> initialPhases,
}) {
  final preparedCommit = prepareMutationPreparedCommitResult(ctx);
  final changeSet = preparedCommit.changeSet;
  final commitCandidate = preparedCommit.commitCandidate;

  if (commitCandidate == null) {
    return ControllerEffectsOnlyCommitPlan(
      changeSet: changeSet,
      initialPhases: initialPhases,
      nextCommitRevision: store.commitRevision + 1,
    );
  }

  final committedSelection = changeSet.selectionChanged
      ? commitCandidate.selection
      : store.selectedNodeIds;
  final committedRevisionState = resolvedCommittedRevisionAllocatorState(
    commitCandidate.revisionState,
  );

  return ControllerStateCommitPlan(
    changeSet: changeSet,
    initialPhases: initialPhases,
    committedStoreState: CommittedStoreState.fromMutationCommitCandidate(
      candidate: commitCandidate,
      selectedNodeIds: committedSelection,
      revisionState: committedRevisionState,
      controllerEpoch: resolveNextControllerEpoch(
        currentEpoch: store.controllerEpoch,
        documentReplaced: changeSet.documentReplaced,
        revisionState: commitCandidate.revisionState,
      ),
      structuralRevision:
          store.structuralRevision + (changeSet.structuralChanged ? 1 : 0),
      boundsRevision: store.boundsRevision + (changeSet.boundsChanged ? 1 : 0),
      visualRevision: store.visualRevision + 1,
      commitRevision: store.commitRevision + 1,
    ),
  );
}

List<String> resolveControllerCommitPhases({
  required ControllerCommitPlan plan,
  required bool hasCommittedSignals,
  required bool needsNotify,
}) {
  var phases = plan.initialPhases;
  if (plan is ControllerStateCommitPlan) {
    phases = <String>[...phases, 'spatial_index', 'signals'];
  } else if (hasCommittedSignals) {
    phases = <String>[...phases, 'signals'];
  }
  if (needsNotify) {
    phases = <String>[...phases, 'repaint'];
  }
  return phases;
}

sealed class ControllerCommitPlan {
  const ControllerCommitPlan({
    required this.changeSet,
    required this.initialPhases,
  });

  final ChangeSet changeSet;
  final List<String> initialPhases;
}

final class ControllerEffectsOnlyCommitPlan extends ControllerCommitPlan {
  const ControllerEffectsOnlyCommitPlan({
    required super.changeSet,
    required super.initialPhases,
    required this.nextCommitRevision,
  });

  final int nextCommitRevision;
}

final class ControllerStateCommitPlan extends ControllerCommitPlan {
  const ControllerStateCommitPlan({
    required super.changeSet,
    required super.initialPhases,
    required this.committedStoreState,
  });

  final CommittedStoreState committedStoreState;
}
